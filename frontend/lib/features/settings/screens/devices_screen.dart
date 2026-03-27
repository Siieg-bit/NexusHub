import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Tela de Dispositivos Conectados — lista sessões ativas e permite revogar.
/// Baseado na tabela device_fingerprints do schema v5.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final res = await SupabaseService.table('device_fingerprints')
          .select()
          .eq('user_id', userId)
          .order('last_seen_at', ascending: false);

      _devices = List<Map<String, dynamic>>.from(res as List);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _revokeDevice(String deviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revogar Dispositivo'),
        content: const Text('Isso encerrará a sessão neste dispositivo. '
            'O usuário precisará fazer login novamente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Revogar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.table('device_fingerprints')
          .delete()
          .eq('id', deviceId);
      setState(() {
        _devices.removeWhere((d) => d['id'] == deviceId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispositivo revogado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  Future<void> _revokeAllOthers() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revogar Todos os Outros'),
        content: const Text('Isso encerrará todas as sessões exceto a atual. '
            'Todos os outros dispositivos precisarão fazer login novamente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Revogar Todos',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.rpc('revoke_all_other_sessions');
      await _loadDevices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Todas as outras sessões foram encerradas')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  IconData _getDeviceIcon(String? deviceType) {
    switch (deviceType?.toLowerCase()) {
      case 'android':
        return Icons.phone_android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'web':
        return Icons.language_rounded;
      case 'desktop':
        return Icons.desktop_mac_rounded;
      default:
        return Icons.devices_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos Conectados',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_devices.length > 1)
            TextButton(
              onPressed: _revokeAllOthers,
              child: const Text('Revogar Outros',
                  style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.devices_rounded,
                          size: 64,
                          color: AppTheme.textHint.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text('Nenhum dispositivo registrado',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _devices.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Info card
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_rounded,
                                color: AppTheme.primaryColor, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Gerencie os dispositivos conectados à sua conta. '
                                'Revogue dispositivos que você não reconhece.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final device = _devices[index - 1];
                    final deviceType =
                        device['device_type'] as String? ?? 'unknown';
                    final deviceName =
                        device['device_name'] as String? ?? 'Dispositivo';
                    final os = device['os'] as String? ?? '';
                    final browser = device['browser'] as String? ?? '';
                    final ipAddress = device['ip_address'] as String? ?? '';
                    final lastSeen = device['last_seen_at'] != null
                        ? DateTime.tryParse(device['last_seen_at'] as String)
                        : null;
                    final isCurrentDevice =
                        device['is_current'] as bool? ?? false;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: isCurrentDevice
                            ? Border.all(
                                color: AppTheme.successColor
                                    .withValues(alpha: 0.5))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: (isCurrentDevice
                                      ? AppTheme.successColor
                                      : AppTheme.primaryColor)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getDeviceIcon(deviceType),
                              color: isCurrentDevice
                                  ? AppTheme.successColor
                                  : AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(deviceName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                    if (isCurrentDevice) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.successColor
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text('Atual',
                                            style: TextStyle(
                                                color: AppTheme.successColor,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [os, browser]
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11),
                                ),
                                if (ipAddress.isNotEmpty)
                                  Text('IP: $ipAddress',
                                      style: const TextStyle(
                                          color: AppTheme.textHint,
                                          fontSize: 10)),
                                if (lastSeen != null)
                                  Text(
                                    'Último acesso: ${lastSeen.day}/${lastSeen.month}/${lastSeen.year} ${lastSeen.hour}:${lastSeen.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                        color: AppTheme.textHint, fontSize: 10),
                                  ),
                              ],
                            ),
                          ),
                          if (!isCurrentDevice)
                            IconButton(
                              onPressed: () =>
                                  _revokeDevice(device['id'] as String),
                              icon: const Icon(Icons.close_rounded,
                                  color: AppTheme.errorColor, size: 20),
                              tooltip: 'Revogar',
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
