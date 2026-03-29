import 'package:flutter/material.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar orientação do app
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configurar barra de status
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Inicializar Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[Main] Firebase init error (pode ignorar em dev): $e');
  }

  // Inicializar Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    realtimeClientOptions: const RealtimeClientOptions(
      eventsPerSecond: 10,
    ),
  );

  // Inicializar Push Notifications
  try {
    await PushNotificationService.initialize();
  } catch (e) {
    debugPrint('[Main] Push init error: $e');
  }

  // Inicializar In-App Purchases (RevenueCat)
  try {
    await IAPService.initialize();
  } catch (e) {
    debugPrint('[Main] IAP init error: $e');
  }

  // Inicializar Ad Network (AdMob)
  try {
    await AdService.initialize();
  } catch (e) {
    debugPrint('[Main] AdService init error: $e');
  }

  // Inicializar Cache Offline-First (Hive)
  try {
    await CacheService.init();
  } catch (e) {
    debugPrint('[Main] CacheService init error: $e');
  }

  // Registrar device fingerprint se usuário já estiver logado
  if (Supabase.instance.client.auth.currentUser != null) {
    DeviceFingerprintService.registerDevice();
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
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
