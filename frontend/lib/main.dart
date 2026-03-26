import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'router/app_router.dart';
import 'core/services/device_fingerprint_service.dart';
import 'core/services/deep_link_service.dart';

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

  // Inicializar Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    realtimeClientOptions: const RealtimeClientOptions(
      eventsPerSecond: 10,
    ),
  );

  // Registrar device fingerprint se usuário já estiver logado
  if (Supabase.instance.client.auth.currentUser != null) {
    DeviceFingerprintService.registerDevice();
  }

  // Escutar mudanças de auth para registrar dispositivo após login
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn) {
      DeviceFingerprintService.registerDevice();
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

    // Inicializar Deep Link service com o router
    DeepLinkService.init(router);

    return MaterialApp.router(
      title: 'NexusHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
