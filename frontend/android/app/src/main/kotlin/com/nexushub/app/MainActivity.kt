package com.nexushub.app

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

/**
 * MainActivity — NexusHub
 *
 * Configura edge-to-edge nativo para garantir compatibilidade com Android 15/16
 * (API 35+), onde o edge-to-edge é enforçado pelo sistema operacional.
 *
 * O Flutter já habilita SystemUiMode.edgeToEdge via main.dart, mas reforçar
 * no lado nativo evita flickering e garante que as barras de sistema sejam
 * transparentes desde o primeiro frame, antes do Flutter inicializar.
 */
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Habilitar edge-to-edge: o conteúdo Flutter se estende por baixo das
        // barras de sistema (status bar e navigation bar).
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // Android 15+ (API 35 / VANILLA_ICE_CREAM): edge-to-edge é enforçado
        // pelo sistema. Garantir barras de sistema transparentes explicitamente
        // para evitar que o sistema aplique cores sólidas automáticas.
        if (Build.VERSION.SDK_INT >= 35) {
            window.statusBarColor = android.graphics.Color.TRANSPARENT
            window.navigationBarColor = android.graphics.Color.TRANSPARENT
        }
    }
}
