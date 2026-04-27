import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Shared Folder — Pasta Compartilhada da Comunidade.
///
/// Membros podem fazer upload de imagens, vídeos e arquivos.
/// Líderes/co-líderes/curadores podem ativar aprovação obrigatória
/// e aprovar/rejeitar arquivos pendentes.
class SharedFolderScreen extends ConsumerStatefulWidget {
  final String communityId;
  const SharedFolderScreen({super.key, required this.communityId});

  @override
  ConsumerState<SharedFolderScreen> createState() => _SharedFolderScreenState();
}

class _SharedFolderScreenState extends ConsumerState<SharedFolderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _folderId;
  bool _requiresApproval = false;
  List<Map<String, dynamic>> _allFiles = [];
  List<Map<String, dynamic>> _pendingFiles = [];
  bool _isUploading = false;
  String? _userRole;
  bool _showPending = false;

  bool get _isStaff =>
      _userRole == 'leader' ||
      _userRole == 'co_leader' ||
      _userRole == 'curator';

  static const _tabs = ['Todos', 'Imagens', 'Vídeos', 'Arquivos'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadFolder();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFolder() async {
    try {
      // Buscar role do usuário na comunidade
      final memberRes = await SupabaseService.table('community_members')
          .select('role')
          .eq('community_id', widget.communityId)
          .eq('user_id', SupabaseService.currentUserId ?? '')
          .maybeSingle();
      _userRole = memberRes?['role'] as String?;

      // Buscar ou criar shared folder da comunidade
      final folderRes = await SupabaseService.table('shared_folders')
          .select()
          .eq('community_id', widget.communityId)
          .maybeSingle();

      if (folderRes != null) {
        _folderId = folderRes['id'] as String?;
        _requiresApproval = folderRes['requires_approval'] as bool? ?? false;
      } else {
        final newFolder = await SupabaseService.table('shared_folders')
            .insert({
              'community_id': widget.communityId,
              'name': 'Shared Folder',
              'requires_approval': false,
            })
            .select()
            .single();
        _folderId = newFolder['id'] as String?;
        _requiresApproval = false;
      }

      await _loadFiles();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFiles() async {
    if (_folderId == null) return;
    try {
      // Buscar arquivos aprovados
      final res = await SupabaseService.table('shared_files')
          .select('*, profiles!uploader_id(nickname, icon_url)')
          .eq('folder_id', _folderId!)
          .eq('approval_status', 'approved')
          .order('created_at', ascending: false);
      _allFiles = List<Map<String, dynamic>>.from(res as List? ?? []);

      // Buscar pendentes (apenas para staff)
      if (_isStaff) {
        final pending = await SupabaseService.rpc(
          'get_pending_shared_files',
          params: {'p_community_id': widget.communityId},
        );
        _pendingFiles =
            List<Map<String, dynamic>>.from(pending as List? ?? []);
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _filteredFiles(int tabIndex) {
    final source = _showPending ? _pendingFiles : _allFiles;
    switch (tabIndex) {
      case 1:
        return source
            .where((f) => (f['file_type'] as String? ?? '').startsWith('image/'))
            .toList();
      case 2:
        return source
            .where((f) => (f['file_type'] as String? ?? '').startsWith('video/'))
            .toList();
      case 3:
        return source
            .where((f) =>
                !(f['file_type'] as String? ?? '').startsWith('image/') &&
                !(f['file_type'] as String? ?? '').startsWith('video/'))
            .toList();
      default:
        return source;
    }
  }

  Future<void> _uploadFile() async {
    final s = getStrings();
    String? mimeType;
    Uint8List? fileBytes;
    String? fileName;

    // Escolher fonte
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_rounded, color: Colors.blue),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.green),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded, color: Colors.orange),
              title: const Text('Arquivo'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'gallery' || choice == 'camera') {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      fileBytes = await picked.readAsBytes();
      fileName = picked.name;
      mimeType = 'image/${picked.name.split('.').last.toLowerCase()}';
    } else {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      fileBytes = f.bytes;
      fileName = f.name;
      mimeType = f.extension != null ? 'application/${f.extension}' : 'application/octet-stream';
    }

    if (fileBytes == null || fileName == null) return;

    setState(() => _isUploading = true);
    try {
      final storagePath =
          '${widget.communityId}/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      // Upload para o bucket correto: shared-files
      await SupabaseService.client.storage
          .from('shared-files')
          .uploadBinary(storagePath, fileBytes!);

      final url = SupabaseService.client.storage
          .from('shared-files')
          .getPublicUrl(storagePath);

      // Usar RPC que respeita requires_approval
      final result = await SupabaseService.rpc('submit_shared_file', params: {
        'p_folder_id': _folderId,
        'p_file_url': url,
        'p_file_name': fileName,
        'p_file_type': mimeType,
        'p_file_size': fileBytes!.length,
        'p_thumbnail_url': mimeType!.startsWith('image/') ? url : null,
      });

      await _loadFiles();

      if (mounted) {
        final approvalStatus = result?['approval_status'] as String?;
        final isPending = approvalStatus == 'pending';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPending
                ? 'Imagem enviada! Aguardando aprovação dos líderes.'
                : s.fileSentSuccess),
            backgroundColor: isPending
                ? Colors.orange
                : context.nexusTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorUploadTryAgain),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteFile(String fileId) async {
    final s = getStrings();
    final r = context.r;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(16))),
        title: Text(s.deleteFile,
            style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontWeight: FontWeight.w700)),
        content: const Text('Tem certeza que deseja excluir este arquivo?',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel, style: TextStyle(color: Colors.grey[500]))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.nexusTheme.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(10))),
            ),
            child: Text(s.delete,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.table('shared_files')
          .update({'approval_status': 'rejected'}).eq('id', fileId);
      await _loadFiles();
    } catch (e) {
      debugPrint('[shared_folder_screen] Erro: $e');
    }
  }

  Future<void> _reviewFile(String fileId, String action) async {
    final r = context.r;
    String? reason;

    if (action == 'reject') {
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController();
          return AlertDialog(
            backgroundColor: context.surfaceColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(16))),
            title: Text('Rejeitar imagem',
                style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontWeight: FontWeight.w700)),
            content: TextField(
              controller: ctrl,
              style: TextStyle(color: context.nexusTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Motivo (opcional)',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(10))),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancelar',
                      style: TextStyle(color: Colors.grey[500]))),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                style: ElevatedButton.styleFrom(
                    backgroundColor: context.nexusTheme.error),
                child: const Text('Rejeitar',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
      if (reason == null) return; // cancelou
    }

    try {
      await SupabaseService.rpc('review_shared_file', params: {
        'p_file_id': fileId,
        'p_action': action,
        if (reason != null && reason.isNotEmpty) 'p_reason': reason,
      });
      await _loadFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'approve'
                ? 'Imagem aprovada!'
                : 'Imagem rejeitada.'),
            backgroundColor: action == 'approve'
                ? context.nexusTheme.success
                : context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[shared_folder_screen] Erro ao revisar: $e');
    }
  }

  Future<void> _toggleRequiresApproval(bool value) async {
    if (_folderId == null) return;
    try {
      await SupabaseService.table('shared_folders')
          .update({'requires_approval': value}).eq('id', _folderId!);
      setState(() => _requiresApproval = value);
    } catch (e) {
      debugPrint('[shared_folder_screen] Erro ao alterar aprovação: $e');
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _timeAgo(String? dateStr) {
    final s = getStrings();
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return s.timeAgoMonthsShort(diff.inDays ~/ 30);
    if (diff.inDays > 0) return s.timeAgoDaysShort(diff.inDays);
    if (diff.inHours > 0) return s.timeAgoHoursShort(diff.inHours);
    if (diff.inMinutes > 0) return s.timeAgoMinutesShort(diff.inMinutes);
    return s.now;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final displayFiles = _filteredFiles(_tabController.index);

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shared Folder',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(18),
              ),
            ),
            Text(
              '${_allFiles.length} ${_allFiles.length == 1 ? 'arquivo' : 'arquivos'}',
              style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
            ),
          ],
        ),
        actions: [
          // Botão de pendentes para staff
          if (_isStaff && _pendingFiles.isNotEmpty)
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.pending_actions_rounded,
                    color: _showPending
                        ? context.nexusTheme.accentPrimary
                        : Colors.orange,
                  ),
                  tooltip: 'Aprovações pendentes',
                  onPressed: () =>
                      setState(() => _showPending = !_showPending),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Colors.orange, shape: BoxShape.circle),
                    child: Text(
                      _pendingFiles.length > 9
                          ? '9+'
                          : '${_pendingFiles.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          // Configurações de aprovação para staff
          if (_isStaff)
            IconButton(
              icon: Icon(Icons.settings_rounded,
                  color: context.nexusTheme.textSecondary),
              tooltip: 'Configurações da pasta',
              onPressed: () => _showFolderSettings(context, r),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.nexusTheme.accentSecondary,
          indicatorWeight: 3,
          labelColor: context.nexusTheme.accentSecondary,
          unselectedLabelColor: Colors.grey[600],
          labelStyle:
              TextStyle(fontWeight: FontWeight.w700, fontSize: r.fs(13)),
          onTap: (_) => setState(() {}),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      floatingActionButton: _showPending
          ? null
          : FloatingActionButton(
              onPressed: _isUploading ? null : _uploadFile,
              backgroundColor: context.nexusTheme.accentSecondary,
              child: _isUploading
                  ? SizedBox(
                      width: r.s(24),
                      height: r.s(24),
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.add_rounded, color: Colors.white, size: r.s(28)),
            ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: context.nexusTheme.accentPrimary))
          : Column(
              children: [
                // Banner de modo pendente
                if (_showPending)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(16), vertical: r.s(10)),
                    color: Colors.orange.withValues(alpha: 0.15),
                    child: Row(
                      children: [
                        Icon(Icons.pending_actions_rounded,
                            color: Colors.orange, size: r.s(18)),
                        SizedBox(width: r.s(8)),
                        Text(
                          '${_pendingFiles.length} imagem(ns) aguardando aprovação',
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                              fontSize: r.fs(13)),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _showPending = false),
                          child: Icon(Icons.close_rounded,
                              color: Colors.orange, size: r.s(18)),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: displayFiles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _showPending
                                    ? Icons.check_circle_rounded
                                    : Icons.folder_open_rounded,
                                size: r.s(64),
                                color: Colors.grey[700],
                              ),
                              SizedBox(height: r.s(12)),
                              Text(
                                _showPending
                                    ? 'Nenhuma imagem pendente!'
                                    : s.noFiles,
                                style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: r.fs(15)),
                              ),
                            ],
                          ),
                        )
                      : _buildFileList(displayFiles, r),
                ),
              ],
            ),
    );
  }

  Widget _buildFileList(List<Map<String, dynamic>> files, Responsive r) {
    // Imagens em grid, outros em lista
    final tabIndex = _tabController.index;
    final isImageTab = tabIndex == 1 ||
        (tabIndex == 0 &&
            files.every((f) =>
                (f['file_type'] as String? ?? '').startsWith('image/')));

    if (isImageTab && files.every(
        (f) => (f['file_type'] as String? ?? '').startsWith('image/'))) {
      return GridView.builder(
        padding: EdgeInsets.all(r.s(8)),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: r.s(4),
          mainAxisSpacing: r.s(4),
        ),
        itemCount: files.length,
        itemBuilder: (ctx, i) => _ImageGridTile(
          file: files[i],
          isStaff: _isStaff,
          isPending: _showPending,
          onDelete: () => _deleteFile(files[i]['id'] as String),
          onApprove: () =>
              _reviewFile(files[i]['id'] as String, 'approve'),
          onReject: () =>
              _reviewFile(files[i]['id'] as String, 'reject'),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: r.s(8)),
      itemCount: files.length,
      itemBuilder: (ctx, i) => _FileTile(
        file: files[i],
        isStaff: _isStaff,
        isPending: _showPending,
        formatSize: _formatFileSize,
        timeAgo: _timeAgo,
        onDelete: () => _deleteFile(files[i]['id'] as String),
        onApprove: () =>
            _reviewFile(files[i]['id'] as String, 'approve'),
        onReject: () =>
            _reviewFile(files[i]['id'] as String, 'reject'),
      ),
    );
  }

  void _showFolderSettings(BuildContext context, Responsive r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.all(r.s(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configurações da Pasta',
                  style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: r.fs(18)),
                ),
                SizedBox(height: r.s(16)),
                SwitchListTile(
                  value: _requiresApproval,
                  onChanged: (v) async {
                    await _toggleRequiresApproval(v);
                    setModalState(() {});
                  },
                  title: Text(
                    'Aprovação obrigatória',
                    style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Imagens enviadas por membros precisam ser aprovadas por líderes antes de aparecer.',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: r.fs(12)),
                  ),
                  activeColor: context.nexusTheme.accentPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widget: Grid de imagens
// ─────────────────────────────────────────────────────────────
class _ImageGridTile extends StatelessWidget {
  final Map<String, dynamic> file;
  final bool isStaff;
  final bool isPending;
  final VoidCallback onDelete;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ImageGridTile({
    required this.file,
    required this.isStaff,
    required this.isPending,
    required this.onDelete,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final url = file['file_url'] as String? ?? file['thumbnail_url'] as String?;
    final r = context.r;

    return GestureDetector(
      onTap: () => _openImage(context, url),
      onLongPress: () => _showOptions(context, r),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(r.s(6)),
            child: url != null
                ? Image.network(url, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.broken_image_rounded,
                              color: Colors.grey),
                        ))
                : Container(color: Colors.grey[800]),
          ),
          // Overlay para pendentes
          if (isPending)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: r.s(4)),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(r.s(6)),
                    bottomRight: Radius.circular(r.s(6)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: onApprove,
                      child: const Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 22),
                    ),
                    GestureDetector(
                      onTap: onReject,
                      child: const Icon(Icons.cancel_rounded,
                          color: Colors.red, size: 22),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openImage(BuildContext context, String? url) {
    if (url == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(child: Image.network(url)),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, Responsive r) {
    final currentUserId = SupabaseService.currentUserId;
    final uploaderId = file['uploader_id'] as String?;
    final canDelete = currentUserId == uploaderId || isStaff;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPending && isStaff) ...[
              ListTile(
                leading:
                    const Icon(Icons.check_circle_rounded, color: Colors.green),
                title: const Text('Aprovar',
                    style: TextStyle(color: Colors.green)),
                onTap: () {
                  Navigator.pop(ctx);
                  onApprove();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.cancel_rounded, color: Colors.red),
                title: const Text('Rejeitar',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  onReject();
                },
              ),
            ],
            if (canDelete)
              ListTile(
                leading: Icon(Icons.delete_rounded,
                    color: context.nexusTheme.error),
                title: Text('Excluir',
                    style: TextStyle(color: context.nexusTheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete();
                },
              ),
            ListTile(
              leading: Icon(Icons.close_rounded, color: Colors.grey[500]),
              title: Text('Cancelar',
                  style: TextStyle(color: Colors.grey[500])),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widget: Tile de arquivo (lista)
// ─────────────────────────────────────────────────────────────
class _FileTile extends ConsumerWidget {
  final Map<String, dynamic> file;
  final bool isStaff;
  final bool isPending;
  final String Function(int?) formatSize;
  final String Function(String?) timeAgo;
  final VoidCallback onDelete;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _FileTile({
    required this.file,
    required this.isStaff,
    required this.isPending,
    required this.formatSize,
    required this.timeAgo,
    required this.onDelete,
    required this.onApprove,
    required this.onReject,
  });

  IconData _iconForType(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file_rounded;
    if (mimeType.startsWith('video/')) return Icons.videocam_rounded;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack_rounded;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (mimeType.contains('zip') || mimeType.contains('rar')) {
      return Icons.folder_zip_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _colorForType(String? mimeType) {
    if (mimeType == null) return Colors.grey;
    if (mimeType.startsWith('video/')) return const Color(0xFFE91E63);
    if (mimeType.startsWith('audio/')) return const Color(0xFF9C27B0);
    if (mimeType.contains('pdf')) return const Color(0xFFFF5722);
    return const Color(0xFF2196F3);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final name = file['file_name'] as String? ?? s.file;
    final mimeType = file['file_type'] as String?;
    final size = file['file_size'] as int?;
    final uploaderName =
        (file['profiles'] as Map?)?['nickname'] as String? ??
        file['uploader_nickname'] as String? ??
        s.anonymous;
    final createdAt = file['created_at'] as String?;
    final color = _colorForType(mimeType);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(8), vertical: r.s(4)),
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(
          color: isPending
              ? Colors.orange.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: r.s(44),
            height: r.s(44),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(r.s(10)),
            ),
            child: Icon(_iconForType(mimeType), color: color, size: r.s(24)),
          ),
          SizedBox(width: r.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: r.fs(14),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$uploaderName  •  ${formatSize(size)}  •  ${timeAgo(createdAt)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: r.fs(11)),
                ),
              ],
            ),
          ),
          // Ações para pendentes
          if (isPending && isStaff) ...[
            IconButton(
              icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
              onPressed: onApprove,
              tooltip: 'Aprovar',
            ),
            IconButton(
              icon: const Icon(Icons.cancel_rounded, color: Colors.red),
              onPressed: onReject,
              tooltip: 'Rejeitar',
            ),
          ] else
            GestureDetector(
              onTap: () => _showOptions(context, r),
              child: Icon(Icons.more_vert_rounded, color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context, Responsive r) {
    final s = getStrings();
    final currentUserId = SupabaseService.currentUserId;
    final uploaderId = file['uploader_id'] as String?;
    final canDelete = currentUserId == uploaderId || isStaff;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canDelete)
              ListTile(
                leading: Icon(Icons.delete_rounded,
                    color: context.nexusTheme.error),
                title: Text(s.delete,
                    style: TextStyle(color: context.nexusTheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete();
                },
              ),
            ListTile(
              leading: Icon(Icons.close_rounded, color: Colors.grey[500]),
              title: Text(s.cancel,
                  style: TextStyle(color: Colors.grey[500])),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}
