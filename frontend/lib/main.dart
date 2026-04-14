import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:go_router/go_router.dart';

import 'config/app_config.dart';
import 'package:amino_clone/config/nexus_theme_data.dart';
import 'package:amino_clone/config/nexus_theme_scope.dart';
import 'router/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'package:amino_clone/core/providers/nexus_theme_provider.dart';
import 'core/services/device_fingerprint_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/iap_service.dart';
import 'core/services/ad_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/error_handler.dart';
import 'core/widgets/error_boundary.dart';
import 'core/l10n/locale_provider.dart';
import 'firebase_options.dart';
import 'package:timeago/timeago.dart' as timeago;

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // ── 120Hz: Solicitar a maior taxa de atualização disponível ────────
  binding.resamplingEnabled = true;

  // Configurar orientação do app (não bloqueia — é rápido)
  unawaited(SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]));

  // Ativar edge-to-edge globalmente e manter as barras do sistema transparentes.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // ── Inicialização PARALELA dos serviços pesados ───────────────────
  // Grupo 1: Serviços independentes (rodam em paralelo)
  await Future.wait([
    _initFirebase(),
    Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10,
      ),
    ),
    _initSafe('cacheService', CacheService.init),
  ]);

  // Grupo 2: Serviços que dependem de Supabase (não-bloqueantes)
  unawaited(Future.wait([
    _initSafe('pushNotification', PushNotificationService.initialize),
    _initSafe('iap', IAPService.initialize),
    _initSafe('adService', AdService.initialize),
  ]));

  // Registrar device fingerprint se usuário já estiver logado
  if (Supabase.instance.client.auth.currentUser != null) {
    unawaited(DeviceFingerprintService.registerDevice());
  }

  // Escutar mudanças de auth para registrar dispositivo e token FCM
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn) {
      DeviceFingerprintService.registerDevice();
      PushNotificationService.initialize();
    }
    if (data.event == AuthChangeEvent.signedOut) {
      PushNotificationService.clearToken();
    }
  });

  // ── Captura global de erros assíncronos ──────────────────────────
  // PlatformDispatcher captura erros que escapam de Futures/Streams
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint(
      '\n\x1B[31m══════ FLUTTER ERROR ══════\x1B[0m\n'
      '${details.exceptionAsString()}\n'
      '${details.stack ?? "(sem stack trace)"}\n'
      '\x1B[31m═══════════════════════════\x1B[0m\n',
    );
    // Repassa para o ErrorBoundary tratar visualmente
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint(
      '\n\x1B[31m══════ ASYNC ERROR ══════\x1B[0m\n'
      '$error\n'
      '$stack\n'
      '\x1B[31m═════════════════════════\x1B[0m\n',
    );
    return true;
  };

  // Registrar locale pt_BR para o pacote timeago
  timeago.setLocaleMessages('pt_BR', timeago.PtBrMessages());

  runApp(
    const ProviderScope(
      child: NexusHubApp(),
    ),
  );
}

/// Inicializa Firebase + Analytics com tratamento de erro.
Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await AnalyticsService.init();
  } catch (e) {
    debugPrint('[Main] Firebase init error (pode ignorar em dev): $e');
  }
}

/// Wrapper seguro para inicialização de serviços — nunca lança exceção.
Future<void> _initSafe(String name, Future<void> Function() init) async {
  try {
    await init();
  } catch (e) {
    debugPrint('[Main] $name init error: $e');
  }
}

// =============================================================================
// NexusHubApp — StatefulConsumerWidget para gerenciar o push notification stream
// =============================================================================

class NexusHubApp extends ConsumerStatefulWidget {
  const NexusHubApp({super.key});

  @override
  ConsumerState<NexusHubApp> createState() => _NexusHubAppState();
}

class _NexusHubAppState extends ConsumerState<NexusHubApp> {
  StreamSubscription<Map<String, dynamic>>? _pushSubscription;

  @override
  void dispose() {
    _pushSubscription?.cancel();
    super.dispose();
  }

  /// Conecta o stream de notificações push ao router para navegação.
  void _setupPushNotificationListener(GoRouter router) {
    _pushSubscription?.cancel();
    _pushSubscription =
        PushNotificationService.notificationStream.listen((data) {
      _handlePushNotificationTap(router, data);
    });
  }

  /// Navega para a tela correta baseado no payload da notificação push.
  void _handlePushNotificationTap(
      GoRouter router, Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    final postId = data['post_id'] as String?;
    final communityId = data['community_id'] as String?;
    final userId = data['user_id'] as String? ?? data['actor_id'] as String?;
    final chatId = data['chat_id'] as String? ?? data['thread_id'] as String?;

    switch (type) {
      case 'like':
      case 'comment':
      case 'mention':
        if (postId != null) {
          router.push('/post/$postId');
        } else if (communityId != null) {
          router.push('/community/$communityId');
        }
        break;
      case 'follow':
        if (userId != null) {
          router.push('/user/$userId');
        }
        break;
      case 'community_invite':
      case 'community_update':
        if (communityId != null) {
          router.push('/community/$communityId');
        }
        break;
      case 'chat_message':
      case 'chat_mention':
        final target = chatId ?? communityId;
        if (target != null) router.push('/chat/$target');
        break;
      case 'dm_invite':
        router.push('/chats');
        break;
      case 'level_up':
      case 'achievement':
      case 'check_in_streak':
        router.push('/profile');
        break;
      case 'wall_post':
        if (userId != null) {
          router.push('/user/$userId');
        }
        break;
      case 'moderation':
      case 'strike':
      case 'ban':
        if (communityId != null) {
          router.push('/community/$communityId');
        }
        break;
      default:
        // Fallback: tentar navegar para o recurso mais relevante
        if (postId != null) {
          router.push('/post/$postId');
        } else if (communityId != null) {
          router.push('/community/$communityId');
        } else if (userId != null) {
          router.push('/user/$userId');
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final router = ref.watch(appRouterProvider);
    // ignore: unused_local_variable
    final themeMode = ref.watch(themeProvider);
    final nexusTheme = ref.watch(nexusThemeProvider);
    final currentLocale = ref.watch(localeProvider);

    // Inicializar Deep Link service com o router
    DeepLinkService.init(router);

    // Conectar push notification stream ao router para navegação
    _setupPushNotificationListener(router);

    // Manter edge-to-edge com contraste e legibilidade adequados em Android 15/16.
    // O SystemUiOverlayStyle é derivado do baseMode do tema NexusHub ativo,
    // garantindo que os ícones da status bar sejam legíveis em qualquer tema.
    final isDark = nexusTheme.baseMode == NexusThemeMode.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
    );

    return MaterialApp.router(
      title: s.nexusHub,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: ErrorHandler.scaffoldKey,
      // O ThemeData é gerado dinamicamente a partir do NexusThemeData ativo.
      // Isso garante que todos os widgets nativos do Material (BottomSheet,
      // Dialog, SnackBar, etc.) herdem as cores corretas do tema escolhido.
      theme: nexusTheme.toMaterialTheme(),
      darkTheme: nexusTheme.toMaterialTheme(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(currentLocale.code),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocale.values.map((l) => Locale(l.code)),
      routerConfig: router,
      builder: (context, child) {
        // NexusThemeScope propaga o tema ativo via InheritedWidget,
        // tornando context.nexusTheme reativo em toda a árvore de widgets.
        // Quando o nexusThemeProvider notifica uma mudança, o MaterialApp
        // reconstrói o builder com o novo nexusTheme, e o NexusThemeScope
        // atualiza todos os widgets dependentes automaticamente.
        //
        // Fix SafeArea/edgeToEdge: com SystemUiMode.edgeToEdge ativo no Android,
        // a navigation bar do sistema sobrepõe o conteúdo. Garantimos que o
        // MediaQuery propaga os padding corretos para que SafeArea funcione.
        final mediaQuery = MediaQuery.of(context);
        return NexusThemeScope(
          theme: nexusTheme,
          child: MediaQuery(
            data: mediaQuery.copyWith(
              padding: mediaQuery.padding,
              viewPadding: mediaQuery.viewPadding,
              viewInsets: mediaQuery.viewInsets,
              systemGestureInsets: mediaQuery.systemGestureInsets,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: ErrorBoundary(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}
