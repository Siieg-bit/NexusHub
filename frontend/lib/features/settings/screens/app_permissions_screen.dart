import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';

/// Tela de Permissões do App — exibe e gerencia permissões de sistema.
class AppPermissionsScreen extends ConsumerStatefulWidget {
  const AppPermissionsScreen({super.key});

  @override
  State<AppPermissionsScreen> createState() => _AppPermissionsScreenState();
}

class _AppPermissionsScreenState extends ConsumerState<AppPermissionsScreen>
    with WidgetsBindingObserver {
  Map<Permission, PermissionStatus> _statuses = {};

  final _permissions = [
    _PermissionInfo(
      permission: Permission.camera,
      icon: Icons.camera_alt_rounded,
      title: s.camera,
      description: s.videoCallAndPhotoUpload,
    ),
    _PermissionInfo(
      permission: Permission.microphone,
      icon: Icons.mic_rounded,
      title: s.microphone,
      description: s.voiceCallAndAudioRecording,
    ),
    _PermissionInfo(
      permission: Permission.notification,
      icon: Icons.notifications_rounded,
      title: s.notifications,
      description: s.messageLikeCommentAlerts,
    ),
    _PermissionInfo(
      permission: Permission.photos,
      icon: Icons.photo_library_rounded,
      title: s.photosAndMedia,
      description: s.sendGalleryImages,
    ),
    _PermissionInfo(
      permission: Permission.storage,
      icon: Icons.folder_rounded,
      title: s.storage,
      description: s.saveFilesAndMedia,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStatuses();
    }
  }

  Future<void> _loadStatuses() async {
    final statuses = <Permission, PermissionStatus>{};
    for (final info in _permissions) {
      statuses[info.permission] = await info.permission.status;
    }
    if (mounted) setState(() => _statuses = statuses);
  }

  Future<void> _requestPermission(_PermissionInfo info) async {
    final status = await info.permission.request();
    if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.surfaceColor,
            title: Text(s.permissionDenied2,
                style: TextStyle(
                    color: context.textPrimary, fontWeight: FontWeight.w700)),
            content: Text(
              '${s.permissionPermanentlyDenied}\n${s.openSystemSettings}',
              style: TextStyle(color: context.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: Text(s.openSettings,
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }
    } else {
      if (mounted) setState(() => _statuses[info.permission] = status);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(s.appPermissions2,
            style: TextStyle(
                fontWeight: FontWeight.w800, color: context.textPrimary)),
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: ListView(
        padding: EdgeInsets.all(r.s(16)),
        children: [
          Container(
            padding: EdgeInsets.all(r.s(12)),
            margin: EdgeInsets.only(bottom: r.s(20)),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppTheme.primaryColor, size: r.s(18)),
                SizedBox(width: r.s(10)),
                Expanded(
                  child: Text(
                    s.managePermissions,
                    style: TextStyle(
                        color: context.textSecondary, fontSize: r.fs(12)),
                  ),
                ),
              ],
            ),
          ),
          ..._permissions.map((info) {
            final status = _statuses[info.permission];
            final isGranted = status?.isGranted ?? false;
            final isDenied = status?.isPermanentlyDenied ?? false;
            return Container(
              margin: EdgeInsets.only(bottom: r.s(8)),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(r.s(14)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ListTile(
                leading: Container(
                  width: r.s(40),
                  height: r.s(40),
                  decoration: BoxDecoration(
                    color: (isGranted
                            ? AppTheme.primaryColor
                            : (Colors.grey[700] ?? Colors.grey))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(r.s(10)),
                  ),
                  child: Icon(
                    info.icon,
                    color: isGranted ? AppTheme.primaryColor : Colors.grey[500],
                    size: r.s(20),
                  ),
                ),
                title: Text(info.title,
                    style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(14))),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.description,
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: r.fs(11))),
                    SizedBox(height: r.s(2)),
                    Text(
                      isGranted
                          ? s.allowed
                          : isDenied
                              ? s.permanentlyDenied
                              : s.notRequested,
                      style: TextStyle(
                        color: isGranted
                            ? Colors.green[400]
                            : isDenied
                                ? AppTheme.errorColor
                                : Colors.orange[400],
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                trailing: status == null
                    ? SizedBox(
                        width: r.s(20),
                        height: r.s(20),
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primaryColor),
                      )
                    : isGranted
                        ? Icon(Icons.check_circle_rounded,
                            color: Colors.green[400], size: r.s(22))
                        : TextButton(
                            onPressed: () => _requestPermission(info),
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                              padding: EdgeInsets.symmetric(
                                  horizontal: r.s(12), vertical: r.s(4)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(r.s(8))),
                            ),
                            child: Text(
                              isDenied ? s.settings : s.allow,
                              style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: r.fs(12),
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PermissionInfo {
  final Permission permission;
  final IconData icon;
  final String title;
  final String description;

  const _PermissionInfo({
    required this.permission,
    required this.icon,
    required this.title,
    required this.description,
  });
}
