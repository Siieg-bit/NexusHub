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
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        title: const Text('Revogar Dispositivo', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        content: Text('Isso encerrará a sessão neste dispositivo. '
            'O usuário precisará fazer login novamente.', style: TextStyle(color: Colors.grey[500])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[500]))),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.errorColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text('Revogar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
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
          SnackBar(
            content: const Text('Dispositivo revogado', style: TextStyle(color: AppTheme.textPrimary)),
            backgroundColor: AppTheme.surfaceColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _revokeAllOthers() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        title: const Text('Revogar Todos os Outros', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        content: Text('Isso encerrará todas as sessões exceto a atual. '
            'Todos os outros dispositivos precisarão fazer login novamente.', style: TextStyle(color: Colors.grey[500])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[500]))),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.errorColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text('Revogar Todos',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
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
          SnackBar(
            content: const Text('Todas as outras sessões foram encerradas', style: TextStyle(color: AppTheme.textPrimary)),
            backgroundColor: AppTheme.surfaceColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
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
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        title: const Text('Dispositivos Conectados',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        actions: [
          if (_devices.length > 1)
            GestureDetector(
              onTap: _revokeAllOthers,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                ),
                child: const Text('Revogar Outros',
                    style: TextStyle(color: AppTheme.errorColor, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.devices_rounded,
                          size: 64,
                          color: Colors.grey[600]?.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('Nenhum dispositivo registrado',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 16)),
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
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.info_rounded,
                                  color: AppTheme.primaryColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Gerencie os dispositivos conectados à sua conta. '
                                'Revogue dispositivos que você não reconhece.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[500],
                                    height: 1.4),
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
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isCurrentDevice
                                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.05)),
                        boxShadow: isCurrentDevice
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: isCurrentDevice
                                  ? LinearGradient(
                                      colors: [
                                        AppTheme.primaryColor.withValues(alpha: 0.2),
                                        AppTheme.accentColor.withValues(alpha: 0.2),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isCurrentDevice
                                  ? null
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getDeviceIcon(deviceType),
                              color: isCurrentDevice
                                  ? AppTheme.primaryColor
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(deviceName,
                                          style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15)),
                                    ),
                                    if (isCurrentDevice) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              AppTheme.primaryColor,
                                              AppTheme.accentColor,
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Text('Atual',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [os, browser]
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12),
                                ),
                                if (ipAddress.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text('IP: $ipAddress',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 11)),
                                ],
                                if (lastSeen != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Último acesso: ${lastSeen.day.toString().padLeft(2, '0')}/${lastSeen.month.toString().padLeft(2, '0')}/${lastSeen.year} ${lastSeen.hour.toString().padLeft(2, '0')}:${lastSeen.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!isCurrentDevice) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () =>
                                  _revokeDevice(device['id'] as String),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded,
                                    color: AppTheme.errorColor, size: 20),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
