import 'package:flutter_dotenv/flutter_dotenv.dart';
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
import 'core/providers/cosmetics_provider.dart';
import 'package:amino_clone/core/providers/nexus_theme_provider.dart';
import 'core/services/device_fingerprint_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/app_navigation_helper.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/iap_service.dart';
import 'core/services/ad_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/error_handler.dart';
import 'core/widgets/error_boundary.dart';
import 'core/widgets/mini_room_overlay.dart';
import 'package:media_kit/media_kit.dart';
import 'core/widgets/connectivity_banner.dart';
import 'core/l10n/locale_provider.dart';
import 'firebase_options.dart';
import 'package:timeago/timeago.dart' as timeago;

void main() async {
  // Carrega variáveis de ambiente do arquivo .env se ele existir.
  // O arquivo é opcional: em produção e em builds sem .env, o app usa
  // os valores padrão definidos em AppConfig. O mergeWith({}) garante
  // que dotenv.env fique inicializado mesmo sem arquivo, evitando
  // LateInitializationError ao acessar dotenv.env nos getters.
  try {
    await dotenv.load(fileName: ".env", mergeWith: {});
  } catch (_) {
    // Arquivo .env ausente ou ilegível — comportamento esperado em produção.
    // Inicializa dotenv com mapa vazio para que dotenv.env esteja disponível.
    dotenv.testLoad(mergeWith: {});
  }
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // Inicializar media_kit (player nativo HLS para Twitch, Tubi, Pluto TV)
  MediaKit.ensureInitialized();

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
  GoRouter? _initializedRouter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inicializa deep link e push apenas quando o router mudar de instância.
    // Usar didChangeDependencies (em vez de build) garante que side effects
    // não sejam recriados a cada rebuild causado por tema, locale ou auth.
    final router = ref.read(appRouterProvider);
    if (_initializedRouter != router) {
      _initializedRouter = router;
      DeepLinkService.init(router);
      _setupPushNotificationListener(router);
    }
  }

  @override
  void dispose() {
    _pushSubscription?.cancel();
    DeepLinkService.dispose();
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
  /// Delega ao AppNavigationHelper para manter a lógica centralizada.
  void _handlePushNotificationTap(
      GoRouter router, Map<String, dynamic> data) {
    AppNavigationHelper.navigateFromNotificationPayload(router, data);
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final router = ref.watch(appRouterProvider);
    // ignore: unused_local_variable
    final themeMode = ref.watch(themeProvider);
    // Inicializa o invalidador de cache de cosméticos via Supabase Realtime.
    // Escuta mudanças em user_purchases e store_items para invalidar
    // o userCosmeticsProvider sem reiniciar o app.
    // ignore: unused_local_variable
    ref.watch(cosmeticsInvalidatorProvider);
    final nexusTheme = ref.watch(nexusThemeProvider);
    final currentLocale = ref.watch(localeProvider);
    // Sincroniza o cache global de strings sempre que o idioma muda.
    // Isso garante que getStrings() retorne as strings corretas em services,
    // models e widgets StatefulWidget que não usam ref.watch(stringsProvider).
    updateGlobalStrings(currentLocale);

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
                child: ConnectivityBanner(
                  child: MiniRoomOverlayWrapper(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
