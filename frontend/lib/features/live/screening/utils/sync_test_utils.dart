// =============================================================================
// sync_test_utils.dart — Utilitário de Teste do Algoritmo de Sincronização
//
// Uso: Adicione o widget SyncDebugOverlay sobre a ScreeningRoomScreen em modo
// debug para visualizar o drift em tempo real e validar o comportamento do
// Macrosync e Microsync.
//
// Ative com: kDebugMode && const bool.fromEnvironment('SYNC_DEBUG', defaultValue: false)
// Execute: flutter run --dart-define=SYNC_DEBUG=true
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_sync_provider.dart';

// ─── Thresholds recomendados (baseados na engenharia reversa do Rave APK) ─────
//
// Rave usa (confirmado via strings nos DEX files):
//   Macrosync: seek direto quando drift > 2000ms
//   Microsync: ajuste de velocidade quando drift entre 300ms e 2000ms
//   Dead zone: < 300ms é ignorado
//
// NexusHub usa thresholds mais agressivos (80ms dead zone) por ter latência
// menor via Supabase Broadcast vs WebSocket proprietário do Rave.
//
// AJUSTE RECOMENDADO por tipo de rede:
//   Rede rápida (< 50ms RTT):  dead zone = 80ms,  micro = 150ms, macro = 2000ms
//   Rede média  (50-150ms RTT): dead zone = 120ms, micro = 250ms, macro = 2500ms
//   Rede lenta  (> 150ms RTT): dead zone = 200ms, micro = 400ms, macro = 3000ms

class SyncThresholdPreset {
  final String name;
  final int deadZoneMs;
  final int microsyncThresholdMs;
  final int macrosyncThresholdMs;
  final double maxRate;
  final double minRate;

  const SyncThresholdPreset({
    required this.name,
    required this.deadZoneMs,
    required this.microsyncThresholdMs,
    required this.macrosyncThresholdMs,
    required this.maxRate,
    required this.minRate,
  });

  static const fastNetwork = SyncThresholdPreset(
    name: 'Rede Rápida (< 50ms)',
    deadZoneMs: 80,
    microsyncThresholdMs: 150,
    macrosyncThresholdMs: 2000,
    maxRate: 1.08,
    minRate: 0.92,
  );

  static const mediumNetwork = SyncThresholdPreset(
    name: 'Rede Média (50-150ms)',
    deadZoneMs: 120,
    microsyncThresholdMs: 250,
    macrosyncThresholdMs: 2500,
    maxRate: 1.06,
    minRate: 0.94,
  );

  static const slowNetwork = SyncThresholdPreset(
    name: 'Rede Lenta (> 150ms)',
    deadZoneMs: 200,
    microsyncThresholdMs: 400,
    macrosyncThresholdMs: 3000,
    maxRate: 1.05,
    minRate: 0.95,
  );

  /// Preset que replica o comportamento do Rave (confirmado via APK)
  static const raveEquivalent = SyncThresholdPreset(
    name: 'Rave Equivalent',
    deadZoneMs: 300,
    microsyncThresholdMs: 300,
    macrosyncThresholdMs: 2000,
    maxRate: 1.05,
    minRate: 0.95,
  );
}

// ─── Widget de Debug ──────────────────────────────────────────────────────────

/// Overlay de debug que mostra o estado de sincronização em tempo real.
/// Visível apenas em modo debug com SYNC_DEBUG=true.
class SyncDebugOverlay extends ConsumerWidget {
  final String sessionId;

  const SyncDebugOverlay({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Só mostra em modo debug
    if (!kDebugMode) return const SizedBox.shrink();
    if (!const bool.fromEnvironment('SYNC_DEBUG', defaultValue: false)) {
      return const SizedBox.shrink();
    }

    final syncState = ref.watch(screeningSyncProvider(sessionId));

    return Positioned(
      top: 80,
      right: 12,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _statusColor(syncState.status).withOpacity(0.6),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DebugRow(
                label: 'Status',
                value: syncState.status.name.toUpperCase(),
                color: _statusColor(syncState.status),
              ),
              _DebugRow(
                label: 'Drift',
                value: '${syncState.lastDriftMs}ms',
                color: _driftColor(syncState.lastDriftMs),
              ),
              _DebugRow(
                label: 'Rate',
                value: syncState.currentPlaybackRate.toStringAsFixed(3),
                color: syncState.currentPlaybackRate == 1.0
                    ? Colors.white70
                    : Colors.amber,
              ),
              _DebugRow(
                label: 'Reconnects',
                value: '${syncState.reconnectAttempts}',
                color: syncState.reconnectAttempts > 0
                    ? Colors.orange
                    : Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.stable:
        return Colors.greenAccent;
      case SyncStatus.adjusting:
        return Colors.amber;
      case SyncStatus.syncing:
        return Colors.blueAccent;
      case SyncStatus.reconnecting:
        return Colors.redAccent;
      case SyncStatus.idle:
        return Colors.white54;
    }
  }

  Color _driftColor(int driftMs) {
    final abs = driftMs.abs();
    if (abs < 80) return Colors.greenAccent;
    if (abs < 500) return Colors.amber;
    if (abs < 2000) return Colors.orange;
    return Colors.redAccent;
  }
}

class _DebugRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DebugRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Simulador de Drift (para testes unitários) ───────────────────────────────

/// Simula cenários de drift para testar o algoritmo de sync sem dispositivos reais.
class SyncDriftSimulator {
  /// Simula o comportamento esperado do algoritmo para um dado drift.
  static SyncAction predictAction(int driftMs) {
    final abs = driftMs.abs();

    if (abs <= 80) {
      return SyncAction(
        type: SyncActionType.ignore,
        description: 'Dead zone — drift ignorado (< 80ms)',
        expectedStatus: SyncStatus.stable,
      );
    }

    if (abs > 2000) {
      return SyncAction(
        type: SyncActionType.macrosync,
        description: 'Macrosync — seek direto (drift > 2s)',
        expectedStatus: SyncStatus.syncing,
        seekOffsetMs: driftMs,
      );
    }

    final rate = driftMs > 0
        ? (abs > 150 ? 1.08 : 1.03)
        : (abs > 150 ? 0.92 : 0.97);

    return SyncAction(
      type: SyncActionType.microsync,
      description: 'Microsync — ajuste de velocidade (${driftMs}ms)',
      expectedStatus: SyncStatus.adjusting,
      playbackRate: rate,
    );
  }

  /// Gera um relatório de teste para todos os cenários de drift.
  static String generateReport() {
    final scenarios = [-5000, -2500, -2001, -2000, -1999, -500, -150, -80, -79,
        0, 79, 80, 150, 500, 1999, 2000, 2001, 2500, 5000];

    final buffer = StringBuffer();
    buffer.writeln('=== Relatório de Simulação de Sync ===\n');

    for (final drift in scenarios) {
      final action = predictAction(drift);
      buffer.writeln('Drift: ${drift}ms → ${action.type.name.toUpperCase()}');
      buffer.writeln('  ${action.description}');
      if (action.seekOffsetMs != null) {
        buffer.writeln('  Seek: ${action.seekOffsetMs}ms');
      }
      if (action.playbackRate != null) {
        buffer.writeln('  Rate: ${action.playbackRate!.toStringAsFixed(3)}x');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}

enum SyncActionType { ignore, microsync, macrosync }

class SyncAction {
  final SyncActionType type;
  final String description;
  final SyncStatus expectedStatus;
  final int? seekOffsetMs;
  final double? playbackRate;

  const SyncAction({
    required this.type,
    required this.description,
    required this.expectedStatus,
    this.seekOffsetMs,
    this.playbackRate,
  });
}
