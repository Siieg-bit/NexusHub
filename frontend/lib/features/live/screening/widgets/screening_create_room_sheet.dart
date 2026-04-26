import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../screens/screening_room_screen.dart';

// =============================================================================
// ScreeningCreateRoomSheet — Bottom sheet moderno para criar a Sala de Projeção
//
// Substitui o AlertDialog simples atual por uma experiência premium com:
// - Campo de URL com validação em tempo real
// - Preview automático do vídeo (thumbnail + título via OG tags)
// - Campo de nome da sala (pré-preenchido com título do vídeo)
// - Opção de "Iniciar sem vídeo" (adicionar depois)
// - Animações de entrada e feedback visual
// =============================================================================

/// Exibe o bottom sheet de criação da sala e navega para ela ao confirmar.
Future<void> showScreeningCreateRoomSheet({
  required BuildContext context,
  required String communityId,
  required String threadId,
  required VoidCallback onRoomCreated,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProviderScope(
      child: _ScreeningCreateRoomSheet(
        communityId: communityId,
        threadId: threadId,
        onRoomCreated: onRoomCreated,
      ),
    ),
  );
}

class _ScreeningCreateRoomSheet extends ConsumerStatefulWidget {
  final String communityId;
  final String threadId;
  final VoidCallback onRoomCreated;

  const _ScreeningCreateRoomSheet({
    required this.communityId,
    required this.threadId,
    required this.onRoomCreated,
  });

  @override
  ConsumerState<_ScreeningCreateRoomSheet> createState() =>
      _ScreeningCreateRoomSheetState();
}

class _ScreeningCreateRoomSheetState
    extends ConsumerState<_ScreeningCreateRoomSheet> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController(text: 'Sala de Projeção');
  final _urlFocus = FocusNode();

  bool _isCreating = false;
  bool _isLoadingPreview = false;
  _VideoPreview? _preview;
  String? _urlError;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _urlFocus.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ── Validação e preview de URL ────────────────────────────────────────────

  void _onUrlChanged() {
    final url = _urlController.text.trim();
    setState(() => _urlError = null);

    if (url.isEmpty) {
      setState(() => _preview = null);
      return;
    }

    // Debounce de 800ms para não chamar a API a cada tecla
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (url == _urlController.text.trim()) {
        _fetchVideoPreview(url);
      }
    });
  }

  Future<void> _fetchVideoPreview(String url) async {
    if (!_isValidUrl(url)) {
      setState(() {
        _urlError = 'URL inválida. Use um link do YouTube, Twitch, Vimeo, etc.';
        _preview = null;
      });
      return;
    }

    setState(() {
      _isLoadingPreview = true;
      _preview = null;
    });

    try {
      // Usar a Edge Function fetch-og-tags existente no NexusHub
      final result = await SupabaseService.client.functions.invoke(
        'fetch-og-tags',
        body: {'url': url},
      );

      final data = result.data as Map<String, dynamic>?;
      if (data != null && mounted) {
        final title = data['title'] as String? ?? '';
        final thumbnail = data['image'] as String? ?? '';
        final siteName = data['site_name'] as String? ?? _extractDomain(url);

        setState(() {
          _preview = _VideoPreview(
            title: title,
            thumbnailUrl: thumbnail,
            siteName: siteName,
            url: url,
          );
          _isLoadingPreview = false;
          // Pré-preencher o nome da sala com o título do vídeo
          if (title.isNotEmpty && _titleController.text == 'Sala de Projeção') {
            _titleController.text = title.length > 50
                ? '${title.substring(0, 47)}...'
                : title;
          }
        });
      } else {
        setState(() => _isLoadingPreview = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPreview = false;
          // Preview não disponível mas URL pode ser válida
          _preview = _VideoPreview(
            title: '',
            thumbnailUrl: '',
            siteName: _extractDomain(url),
            url: url,
          );
        });
      }
    }
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  String _extractDomain(String url) {
    try {
      return Uri.parse(url).host.replaceAll('www.', '');
    } catch (_) {
      return 'Link';
    }
  }

  // ── Criação da sala ────────────────────────────────────────────────────────

  Future<void> _createRoom({bool withoutVideo = false}) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final videoUrl = withoutVideo ? '' : _urlController.text.trim();
    final videoTitle = withoutVideo ? '' : (_preview?.title ?? '');
    final videoThumbnail = withoutVideo ? '' : (_preview?.thumbnailUrl ?? '');

    setState(() => _isCreating = true);
    HapticFeedback.mediumImpact();

    try {
      // Criar o thread da sala de projeção
      final thread = await SupabaseService.table('chat_threads')
          .insert({
            'community_id': widget.communityId,
            'type': 'screening_room',
            'title': title,
            'host_id': SupabaseService.currentUserId,
          })
          .select()
          .single();

      // Adicionar o criador como membro
      await SupabaseService.table('chat_members').insert({
        'thread_id': thread['id'] as String,
        'user_id': SupabaseService.currentUserId,
        'status': 'active',
      });

      if (!mounted) return;
      Navigator.of(context).pop(); // Fechar o bottom sheet

      // Navegar para a sala
      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => ScreeningRoomScreen(
            threadId: thread['id'] as String? ?? '',
            initialVideoUrl: videoUrl,
            initialVideoTitle: videoTitle,
            initialVideoThumbnail: videoThumbnail,
          ),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );

      widget.onRoomCreated();
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar sala: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NexusThemeExtension>()!;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + bottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Título do sheet
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.accentPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.movie_creation_rounded,
                  color: theme.accentPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Nova Sala de Projeção',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 24),

          // Campo de URL do vídeo
          _buildUrlField(theme),
          const SizedBox(height: 12),

          // Preview do vídeo (aparece ao digitar URL válida)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _buildVideoPreview(theme),
          ),

          // Campo de nome da sala
          _buildTitleField(theme),
          const SizedBox(height: 24),

          // Botões de ação
          _buildActionButtons(theme),
        ],
      ),
    );
  }

  Widget _buildUrlField(NexusThemeExtension theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'URL do vídeo',
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _urlController,
          focusNode: _urlFocus,
          keyboardType: TextInputType.url,
          autocorrect: false,
          style: TextStyle(color: theme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'youtube.com/watch?v=... ou qualquer URL de vídeo',
            hintStyle: TextStyle(color: theme.textSecondary.withOpacity(0.5), fontSize: 13),
            prefixIcon: Icon(
              Icons.link_rounded,
              color: _urlError != null ? Colors.red[400] : theme.accentSecondary,
              size: 20,
            ),
            suffixIcon: _isLoadingPreview
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.accentPrimary,
                      ),
                    ),
                  )
                : _urlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        color: theme.textSecondary,
                        onPressed: () {
                          _urlController.clear();
                          setState(() => _preview = null);
                        },
                      )
                    : null,
            filled: true,
            fillColor: theme.surfacePrimary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _urlError != null
                    ? Colors.red.withOpacity(0.5)
                    : Colors.white.withOpacity(0.06),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _urlError != null
                    ? Colors.red
                    : theme.accentPrimary,
                width: 1.5,
              ),
            ),
            errorText: _urlError,
            errorStyle: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPreview(NexusThemeExtension theme) {
    if (_preview == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.surfacePrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.accentPrimary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
              child: _preview!.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      _preview!.thumbnailUrl,
                      width: 90,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildThumbnailPlaceholder(theme),
                    )
                  : _buildThumbnailPlaceholder(theme),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_preview!.siteName.isNotEmpty)
                      Text(
                        _preview!.siteName.toUpperCase(),
                        style: TextStyle(
                          color: theme.accentPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    if (_preview!.title.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _preview!.title,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else
                      Text(
                        'Vídeo encontrado',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Ícone de check
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.greenAccent[400],
                size: 18,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.05, end: 0),
    );
  }

  Widget _buildThumbnailPlaceholder(NexusThemeExtension theme) {
    return Container(
      width: 90,
      height: 60,
      color: theme.surfaceSecondary,
      child: Icon(
        Icons.play_circle_outline_rounded,
        color: theme.textSecondary,
        size: 24,
      ),
    );
  }

  Widget _buildTitleField(NexusThemeExtension theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nome da sala',
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          maxLength: 60,
          style: TextStyle(color: theme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Ex: Maratona de filmes de terror',
            hintStyle: TextStyle(color: theme.textSecondary.withOpacity(0.5), fontSize: 13),
            prefixIcon: Icon(
              Icons.edit_rounded,
              color: theme.accentSecondary,
              size: 18,
            ),
            counterText: '',
            filled: true,
            fillColor: theme.surfacePrimary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.06),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.accentPrimary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(NexusThemeExtension theme) {
    final hasUrl = _urlController.text.trim().isNotEmpty && _urlError == null;

    return Column(
      children: [
        // Botão principal: Criar sala (com ou sem vídeo)
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isCreating ? null : () => _createRoom(withoutVideo: !hasUrl),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentPrimary,
              disabledBackgroundColor: theme.accentPrimary.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasUrl
                            ? Icons.play_circle_filled_rounded
                            : Icons.add_circle_outline_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasUrl ? 'Criar sala e iniciar vídeo' : 'Criar sala',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        // Botão secundário: Criar sem vídeo (só aparece se há URL)
        if (hasUrl) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              onPressed: _isCreating ? null : () => _createRoom(withoutVideo: true),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Text(
                'Criar sala sem vídeo',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Model de preview ──────────────────────────────────────────────────────────

class _VideoPreview {
  final String title;
  final String thumbnailUrl;
  final String siteName;
  final String url;

  const _VideoPreview({
    required this.title,
    required this.thumbnailUrl,
    required this.siteName,
    required this.url,
  });
}
