import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

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
    if (!mounted) return;
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _revokeDevice(String deviceId) async {

      final r = context.r;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.s(16)),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        title: Text('Revogar Dispositivo', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w800)),
        content: Text('Isso encerrará a sessão neste dispositivo. '
            'O usuário precisará fazer login novamente.', style: TextStyle(color: Colors.grey[500])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[500]))),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(r.s(20)),
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
      if (!mounted) return;
      setState(() {
        _devices.removeWhere((d) => d['id'] == deviceId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dispositivo revogado', style: TextStyle(color: context.textPrimary)),
            backgroundColor: context.surfaceColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(12)), side: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(12))),
          ),
        );
      }
    }
  }

  Future<void> _revokeAllOthers() async {

      final r = context.r;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.s(16)),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        title: Text('Revogar Todos os Outros', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w800)),
        content: Text('Isso encerrará todas as sessões exceto a atual. '
            'Todos os outros dispositivos precisarão fazer login novamente.', style: TextStyle(color: Colors.grey[500])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[500]))),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(r.s(20)),
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
            content: Text('Todas as outras sessões foram encerradas', style: TextStyle(color: context.textPrimary)),
            backgroundColor: context.surfaceColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(12)), side: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(12))),
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
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text('Dispositivos Conectados',
            style: TextStyle(fontWeight: FontWeight.w800, color: context.textPrimary)),
        actions: [
          if (_devices.length > 1)
            GestureDetector(
              onTap: _revokeAllOthers,
              child: Container(
                margin: EdgeInsets.only(right: r.s(16)),
                padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(r.s(20)),
                  border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                ),
                child: Text('Revogar Outros',
                    style: TextStyle(color: AppTheme.errorColor, fontSize: r.fs(12), fontWeight: FontWeight.w700)),
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
                          size: r.s(64),
                          color: Colors.grey[600]?.withValues(alpha: 0.3)),
                      SizedBox(height: r.s(16)),
                      Text('Nenhum dispositivo registrado',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: r.fs(16))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(r.s(16)),
                  itemCount: _devices.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Info card
                      return Container(
                        margin: EdgeInsets.only(bottom: r.s(16)),
                        padding: EdgeInsets.all(r.s(14)),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(r.s(16)),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(r.s(8)),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.info_rounded,
                                  color: AppTheme.primaryColor, size: r.s(20)),
                            ),
                            SizedBox(width: r.s(12)),
                            Expanded(
                              child: Text(
                                'Gerencie os dispositivos conectados à sua conta. '
                                'Revogue dispositivos que você não reconhece.',
                                style: TextStyle(
                                    fontSize: r.fs(13),
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
                      margin: EdgeInsets.only(bottom: r.s(12)),
                      padding: EdgeInsets.all(r.s(16)),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(r.s(16)),
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
                            width: r.s(48),
                            height: r.s(48),
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
                              borderRadius: BorderRadius.circular(r.s(12)),
                            ),
                            child: Icon(
                              _getDeviceIcon(deviceType),
                              color: isCurrentDevice
                                  ? AppTheme.primaryColor
                                  : context.textPrimary,
                            ),
                          ),
                          SizedBox(width: r.s(16)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(deviceName,
                                          style: TextStyle(
                                              color: context.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: r.fs(15))),
                                    ),
                                    if (isCurrentDevice) ...[
                                      SizedBox(width: r.s(8)),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: r.s(8), vertical: r.s(4)),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              AppTheme.primaryColor,
                                              AppTheme.accentColor,
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(r.s(20)),
                                        ),
                                        child: Text('Atual',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: r.fs(10),
                                                fontWeight: FontWeight.w800)),
                                      ),
                                    ],
                                  ],
                                ),
                                SizedBox(height: r.s(4)),
                                Text(
                                  [os, browser]
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: r.fs(12)),
                                ),
                                if (ipAddress.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text('IP: $ipAddress',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: r.fs(11))),
                                ],
                                if (lastSeen != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Último acesso: ${lastSeen.day.toString().padLeft(2, '0')}/${lastSeen.month.toString().padLeft(2, '0')}/${lastSeen.year} ${lastSeen.hour.toString().padLeft(2, '0')}:${lastSeen.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: r.fs(11)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!isCurrentDevice) ...[
                            SizedBox(width: r.s(12)),
                            GestureDetector(
                              onTap: () =>
                                  _revokeDevice(device['id'] as String),
                              child: Container(
                                padding: EdgeInsets.all(r.s(8)),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close_rounded,
                                    color: AppTheme.errorColor, size: r.s(20)),
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
