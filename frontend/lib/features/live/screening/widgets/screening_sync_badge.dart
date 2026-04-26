// =============================================================================
// ScreeningSyncBadge — Badge de status de sincronização
//
// Exibe um indicador discreto quando o sync não está em idle/stable.
// Extraído da ScreeningRoomScreen para ser reutilizável no landscape.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_sync_provider.dart';

class ScreeningSyncBadge extends ConsumerWidget {
  final String sessionId;

  const ScreeningSyncBadge({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(screeningSyncProvider(sessionId));

    final (label, color) = switch (syncState.status) {
      SyncStatus.syncing => ('Sincronizando...', Colors.amberAccent),
      SyncStatus.adjusting => ('Ajustando...', Colors.lightBlueAccent),
      SyncStatus.reconnecting => ('Reconectando...', Colors.orangeAccent),
      _ => (null, null),
    };

    if (label == null) return const SizedBox.shrink();

    return Center(
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color!.withOpacity(0.4), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
