import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Shared Folder — Pasta Compartilhada da Comunidade.
///
/// No Amino original, cada comunidade possui uma "Shared Folder"
/// acessível pelo menu lateral. Membros podem fazer upload de
/// imagens, vídeos e arquivos para uma pasta coletiva.
///
/// Layout:
///   - Grid de thumbnails (imagens) / lista (arquivos)
///   - FAB para upload
///   - Filtros: Todos, Imagens, Vídeos, Arquivos
///   - Contador de itens e espaço usado
///   - Opção de download e delete (para uploader/mods)
class SharedFolderScreen extends StatefulWidget {
  final String communityId;
  const SharedFolderScreen({super.key, required this.communityId});

  @override
  State<SharedFolderScreen> createState() => _SharedFolderScreenState();
}

class _SharedFolderScreenState extends State<SharedFolderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _folderId;
  List<Map<String, dynamic>> _allFiles = [];
  bool _isUploading = false;

  // Filtros
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
      // Buscar ou criar shared folder da comunidade
      final folderRes = await SupabaseService.table('shared_folders')
          .select()
          .eq('community_id', widget.communityId)
          .maybeSingle();

      if (folderRes != null) {
        _folderId = folderRes['id'] as String?;
      } else {
        // Criar folder se não existe
        final newFolder = await SupabaseService.table('shared_folders')
            .insert({
              'community_id': widget.communityId,
              'name': 'Shared Folder',
            })
            .select()
            .single();
        _folderId = newFolder['id'] as String?;
      }

      await _loadFiles();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFiles() async {
    if (_folderId == null) return;
    try {
      final res = await SupabaseService.table('shared_files')
          .select('*, profiles!uploader_id(username, avatar_url)')
          .eq('folder_id', _folderId!)
          .eq('status', 'ok')
          .order('created_at', ascending: false);
      _allFiles = List<Map<String, dynamic>>.from(res as List?);
      if (!mounted) return;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _filteredFiles(int tabIndex) {
    switch (tabIndex) {
      case 1: // Imagens
        return _allFiles
            .where((f) =>
                (f['file_type'] as String? ?? '').startsWith('image/'))
            .toList();
      case 2: // Vídeos
        return _allFiles
            .where((f) =>
                (f['file_type'] as String? ?? '').startsWith('video/'))
            .toList();
      case 3: // Arquivos
        return _allFiles
            .where((f) =>
                !(f['file_type'] as String? ?? '').startsWith('image/') &&
                !(f['file_type'] as String? ?? '').startsWith('video/'))
            .toList();
      default:
        return _allFiles;
    }
  }

  Future<void> _uploadFile() async {

      final r = context.r;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(r.s(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: r.s(40),
              height: r.s(4),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: r.s(16)),
            Text(
              'Upload para Shared Folder',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: r.fs(18),
              ),
            ),
            SizedBox(height: r.s(20)),
            _UploadOption(
              icon: Icons.photo_library_rounded,
              label: 'Imagem da Galeria',
              color: const Color(0xFF4CAF50),
              onTap: () => Navigator.pop(ctx, 'gallery_image'),
            ),
            _UploadOption(
              icon: Icons.camera_alt_rounded,
              label: 'Tirar Foto',
              color: const Color(0xFF2196F3),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            _UploadOption(
              icon: Icons.videocam_rounded,
              label: 'Vídeo da Galeria',
              color: const Color(0xFFE91E63),
              onTap: () => Navigator.pop(ctx, 'gallery_video'),
            ),
            _UploadOption(
              icon: Icons.attach_file_rounded,
              label: 'Arquivo',
              color: const Color(0xFFFF9800),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            SizedBox(height: r.s(8)),
          ],
        ),
      ),
    );

    if (choice == null) return;

    File? file;
    String? fileName;
    String? mimeType;

    switch (choice) {
      case 'gallery_image':
        final picked =
            await ImagePicker().pickImage(source: ImageSource.gallery);
        if (picked != null) {
          file = File(picked.path);
          fileName = picked.name;
          mimeType = 'image/${picked.path.split('.').last}';
        }
        break;
      case 'camera':
        final picked =
            await ImagePicker().pickImage(source: ImageSource.camera);
        if (picked != null) {
          file = File(picked.path);
          fileName = picked.name;
          mimeType = 'image/${picked.path.split('.').last}';
        }
        break;
      case 'gallery_video':
        final picked =
            await ImagePicker().pickVideo(source: ImageSource.gallery);
        if (picked != null) {
          file = File(picked.path);
          fileName = picked.name;
          mimeType = 'video/${picked.path.split('.').last}';
        }
        break;
      case 'file':
        final result = await FilePicker.platform.pickFiles();
        if (result != null && result.files.single.path != null) {
          file = File(result.files.single.path!);
          fileName = result.files.single.name;
          mimeType = result.files.single.extension != null
              ? 'application/${result.files.single.extension}'
              : 'application/octet-stream';
        }
        break;
    }

    if (file == null || fileName == null) return;

    setState(() => _isUploading = true);

    try {
      final storagePath =
          'shared-files/${widget.communityId}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await SupabaseService.client.storage
          .from('media')
          .upload(storagePath, file);
      final url = SupabaseService.client.storage
          .from('media')
          .getPublicUrl(storagePath);

      final fileSize = await file.length();

      await SupabaseService.table('shared_files').insert({
        'folder_id': _folderId,
        'uploader_id': SupabaseService.currentUserId,
        'file_url': url,
        'file_name': fileName,
        'file_type': mimeType,
        'file_size': fileSize,
        'thumbnail_url': mimeType?.startsWith('image/') == true ? url : null,
      });

      await _loadFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arquivo enviado com sucesso!'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no upload. Tente novamente.'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteFile(String fileId) async {

      final r = context.r;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(16))),
        title: Text('Excluir arquivo',
            style: TextStyle(
                color: context.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text('Tem certeza que deseja excluir este arquivo?',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  Text('Cancelar', style: TextStyle(color: Colors.grey[500]))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(10))),
            ),
            child: const Text('Excluir',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.table('shared_files')
          .update({'status': 'removed'}).eq('id', fileId);
      await _loadFiles();
    } catch (e) {
      debugPrint('[shared_folder_screen] Erro: $e');
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}m atrás';
    if (diff.inDays > 0) return '${diff.inDays}d atrás';
    if (diff.inHours > 0) return '${diff.inHours}h atrás';
    if (diff.inMinutes > 0) return '${diff.inMinutes}min atrás';
    return 'agora';
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shared Folder',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
                fontSize: r.fs(18),
              ),
            ),
            Text(
              '${_allFiles.length} ${_allFiles.length == 1 ? 'arquivo' : 'arquivos'}',
              style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentColor,
          indicatorWeight: 3,
          labelColor: AppTheme.accentColor,
          unselectedLabelColor: Colors.grey[600],
          labelStyle: TextStyle(
              fontWeight: FontWeight.w700, fontSize: r.fs(13)),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _uploadFile,
        backgroundColor: AppTheme.aminoPink,
        child: _isUploading
            ? SizedBox(
                width: r.s(24),
                height: r.s(24),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(Icons.add_rounded, color: Colors.white, size: r.s(28)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : TabBarView(
              controller: _tabController,
              children: List.generate(_tabs.length, (tabIndex) {
                final files = _filteredFiles(tabIndex);
                if (files.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open_rounded,
                            color: Colors.grey[700], size: r.s(64)),
                        SizedBox(height: r.s(12)),
                        Text(
                          'Nenhum arquivo',
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: r.fs(16),
                              fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: r.s(4)),
                        Text(
                          'Toque no + para fazer upload',
                          style: TextStyle(
                              color: Colors.grey[700], fontSize: r.fs(13)),
                        ),
                      ],
                    ),
                  );
                }

                // Imagens usam grid, outros usam lista
                final isImageTab = tabIndex == 1;
                final hasImages = tabIndex == 0 &&
                    files.any((f) =>
                        (f['file_type'] as String? ?? '')
                            .startsWith('image/'));

                if (isImageTab || (tabIndex == 0 && hasImages)) {
                  return _buildMixedView(files);
                }
                return _buildListView(files);
              }),
            ),
    );
  }

  Widget _buildMixedView(List<Map<String, dynamic>> files) {
      final r = context.r;
    final images = files
        .where(
            (f) => (f['file_type'] as String? ?? '').startsWith('image/'))
        .toList();
    final others = files
        .where(
            (f) => !(f['file_type'] as String? ?? '').startsWith('image/'))
        .toList();

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        setState(() => _isLoading = true);
        await _loadFolder();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
        // Grid de imagens
        if (images.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.all(r.s(8)),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ImageTile(
                  file: images[i],
                  onDelete: () =>
                      _deleteFile(images[i]['id'] as String?),
                ),
                childCount: images.length,
              ),
            ),
          ),
        ],
        // Lista de outros arquivos
        if (others.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _FileTile(
                file: others[i],
                formatSize: _formatFileSize,
                timeAgo: _timeAgo,
                onDelete: () =>
                    _deleteFile(others[i]['id'] as String?),
              ),
              childCount: others.length,
            ),
          ),
      ],
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> files) {
      final r = context.r;
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        setState(() => _isLoading = true);
        await _loadFolder();
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(r.s(8)),
        itemCount: files.length,
        itemBuilder: (ctx, i) => _FileTile(
          file: files[i],
          formatSize: _formatFileSize,
          timeAgo: _timeAgo,
          onDelete: () => _deleteFile(files[i]['id'] as String?),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════

class _UploadOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _UploadOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: r.s(8)),
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(14)),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Row(
          children: [
            Container(
              width: r.s(40),
              height: r.s(40),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(r.s(10)),
              ),
              child: Icon(icon, color: color, size: r.s(22)),
            ),
            SizedBox(width: r.s(14)),
            Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: r.fs(15),
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[700]),
          ],
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback onDelete;

  const _ImageTile({required this.file, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final url = file['file_url'] as String? ?? '';
    final uploaderName =
        (file['profiles'] as Map?)?['username'] as String? ?? 'Anônimo';

    return GestureDetector(
      onTap: () => _showFullImage(context, url),
      onLongPress: () => _showOptions(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r.s(4)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: context.cardBg,
                child: Icon(Icons.broken_image_rounded,
                    color: Colors.grey[700], size: r.s(32)),
              ),
            ),
            // Gradient overlay com nome do uploader
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(r.s(4)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  uploaderName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.fs(9),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: InteractiveViewer(
            child: Image.network(url),
          ),
        ),
      ),
    ));
  }

  void _showOptions(BuildContext context) {
    final currentUserId = SupabaseService.currentUserId;
    final uploaderId = file['uploader_id'] as String?;
    final canDelete = currentUserId == uploaderId;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_rounded,
                    color: AppTheme.errorColor),
                title: const Text('Excluir',
                    style: TextStyle(color: AppTheme.errorColor)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete();
                },
              ),
            ListTile(
              leading:
                  Icon(Icons.close_rounded, color: Colors.grey[500]),
              title:
                  Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final Map<String, dynamic> file;
  final String Function(int?) formatSize;
  final String Function(String?) timeAgo;
  final VoidCallback onDelete;

  const _FileTile({
    required this.file,
    required this.formatSize,
    required this.timeAgo,
    required this.onDelete,
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
  Widget build(BuildContext context) {
    final r = context.r;
    final name = file['file_name'] as String? ?? 'Arquivo';
    final mimeType = file['file_type'] as String?;
    final size = file['file_size'] as int?;
    final uploaderName =
        (file['profiles'] as Map?)?['username'] as String? ?? 'Anônimo';
    final createdAt = file['created_at'] as String?;
    final color = _colorForType(mimeType);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(8), vertical: r.s(4)),
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                    color: context.textPrimary,
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
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.more_vert_rounded, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
