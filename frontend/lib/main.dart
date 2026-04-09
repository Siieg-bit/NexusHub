import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'router/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/device_fingerprint_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/iap_service.dart';
import 'core/services/ad_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/error_handler.dart';
import 'core/widgets/error_boundary.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 120Hz: Solicitar a maior taxa de atualização disponível ────────
  // No Android, o Flutter por padrão roda a 60Hz mesmo em telas 120Hz.
  // GestureBinding.instance.resamplingEnabled melhora a suavidade do
  // toque em telas de alta taxa de atualização.
  GestureBinding.instance.resamplingEnabled = true;

  // Configurar orientação do app (não bloqueia — é rápido)
  unawaited(SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]));

  // Configurar barra de status
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // ── Inicialização PARALELA dos serviços pesados ───────────────────
  // Antes: cada await bloqueava o próximo → ~3-5s de tela branca.
  // Agora: Firebase, Supabase, Cache rodam em paralelo → ~1-2s.
  // Serviços que dependem de Supabase (Push, IAP, Ad) rodam depois.

  // Grupo 1: Serviços independentes (rodam em paralelo)
  await Future.wait([
    // Firebase
    _initFirebase(),
    // Supabase
    Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10,
      ),
    ),
    // Cache Offline-First (Hive)
    _initSafe('CacheService', CacheService.init),
  ]);

  // Grupo 2: Serviços que dependem de Supabase (rodam em paralelo)
  // Estes são não-bloqueantes — o app pode abrir enquanto inicializam.
  unawaited(Future.wait([
    _initSafe('PushNotification', PushNotificationService.initialize),
    _initSafe('IAP', IAPService.initialize),
    _initSafe('AdService', AdService.initialize),
  ]));

  // Registrar device fingerprint se usuário já estiver logado
  if (Supabase.instance.client.auth.currentUser != null) {
    unawaited(DeviceFingerprintService.registerDevice());
  }

  // Escutar mudanças de auth para registrar dispositivo e token FCM
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn) {
      DeviceFingerprintService.registerDevice();
      PushNotificationService.initialize(); // Re-registra token FCM
    }
    if (data.event == AuthChangeEvent.signedOut) {
      PushNotificationService.clearToken();
    }
  });

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

class NexusHubApp extends ConsumerWidget {
  const NexusHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);

    // Inicializar Deep Link service com o router
    DeepLinkService.init(router);

    // Atualizar barra de status conforme o tema
    final isDark = themeMode == ThemeMode.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor:
            isDark ? AppTheme.bottomNavBg : AppTheme.bottomNavBgLight,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp.router(
      title: 'NexusHub',
      debugShowCheckedModeBanner: false,
      // Conectar o scaffoldMessengerKey do ErrorHandler para que
      // SnackBars globais (ErrorHandler.showSuccess/showError/etc) funcionem.
      scaffoldMessengerKey: ErrorHandler.scaffoldKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      // ErrorBoundary agora fica DENTRO do MaterialApp, garantindo que
      // Directionality, Theme, MediaQuery e todos os InheritedWidgets
      // estejam sempre disponíveis — inclusive para o fallback de erro.
      builder: (context, child) {
        return ErrorBoundary(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
