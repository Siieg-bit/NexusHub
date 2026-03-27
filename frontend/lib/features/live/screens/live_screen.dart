import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

/// Tela Live — exibe transmissões ao vivo e Voice/Video Chats ativos.
class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded),
            onPressed: () {/* TODO: Iniciar live */},
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF4081).withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.live_tv_rounded,
                size: 48,
                color: Color(0xFFFF4081),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma Live Ativa',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Voice Chats, Video Chats e Screening Rooms\naparecerão aqui quando estiverem ativos.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {/* TODO: Criar Voice Chat */},
              icon: const Icon(Icons.mic_rounded),
              label: const Text('Iniciar Voice Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4081),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
