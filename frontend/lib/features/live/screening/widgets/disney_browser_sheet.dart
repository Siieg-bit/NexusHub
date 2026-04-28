import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/screening_room_provider.dart';
import '../services/disney/disney_auth_service.dart';
import '../services/disney/disney_api_service.dart';
import '../services/disney/disney_playback_service.dart';
import '../services/disney/disney_models.dart';

// =============================================================================
// DisneyBrowserSheet — Catálogo nativo Disney+ integrado via API BAMGrid
//
// Abre como página cheia após o login no WebView do Disney+.
// Funcionalidades:
// - Grid de conteúdo (filmes e séries) do catálogo Disney+
// - Busca integrada via API BAMGrid
// - Navegação de temporadas e episódios
// - Seleção de conteúdo com resolução de stream DRM
// =============================================================================

class DisneyBrowserSheet extends ConsumerStatefulWidget {
  final String sessionId;
  final String threadId;
  final bool addToQueue;

  const DisneyBrowserSheet({
    super.key,
    required this.sessionId,
    required this.threadId,
    required this.addToQueue,
  });

  @override
  ConsumerState<DisneyBrowserSheet> createState() => _DisneyBrowserSheetState();
}

class _DisneyBrowserSheetState extends ConsumerState<DisneyBrowserSheet>
    with SingleTickerProviderStateMixin {
  // ── Estado ────────────────────────────────────────────────────────────────
  DisneyPage? _homePage;
  List<DisneyContentItem> _searchResults = [];
  // Continue Watching e Minha Lista (carregados em paralelo com a home)
  List<DisneyContentItem> _continueWatching = [];
  List<DisneyContentItem> _myList = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isCapturing = false;
  String? _error;
  String _searchQuery = '';

  // Navegação de série
  DisneyContentItem? _selectedSeries;
  List<DisneySeason> _seasons = [];
  DisneySeason? _selectedSeason;
  bool _loadingSeasons = false;

  // Controladores
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  // Cor de destaque Disney+
  static const _disneyBlue = Color(0xFF0063E5);
  static const _disneyBg = Color(0xFF040714);

  @override
  void initState() {
    super.initState();
    _loadHomePage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Carregamento de dados ─────────────────────────────────────────────────

  Future<void> _loadHomePage() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      // Carregar home, continue watching e my list em paralelo (igual ao Rave)
      final results = await Future.wait([
        DisneyApiService.fetchHomePage(),
        DisneyApiService.fetchContinueWatching(),
        DisneyApiService.fetchMyList(),
      ]);
      if (mounted) {
        setState(() {
          _homePage = results[0] as DisneyPage;
          _continueWatching = results[1] as List<DisneyContentItem>;
          _myList = results[2] as List<DisneyContentItem>;
          _isLoading = false;
        });
      }
    } on DisneyAuthException catch (e) {
      if (mounted) {
        setState(() { _error = e.message; _isLoading = false; });
        if (e.isExpired) _handleSessionExpired();
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _searchResults = []; _isSearching = false; _searchQuery = ''; });
      return;
    }
    setState(() { _searchQuery = query; _isSearching = true; });
    _searchDebounce = Timer(const Duration(milliseconds: 600), () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);
    try {
      final result = await DisneyApiService.search(query);
      if (mounted && _searchQuery == query) {
        setState(() { _searchResults = result.hits; _isSearching = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _isSearching = false; });
    }
  }

  Future<void> _openSeries(DisneyContentItem series) async {
    setState(() { _selectedSeries = series; _seasons = []; _selectedSeason = null; _loadingSeasons = true; });
    try {
      final seasons = await DisneyApiService.fetchSeasons(series.contentId);
      if (mounted) {
        setState(() { _seasons = seasons; _loadingSeasons = false; });
        if (seasons.isNotEmpty) _selectSeason(seasons.first);
      }
    } catch (e) {
      if (mounted) setState(() { _loadingSeasons = false; });
    }
  }

  Future<void> _selectSeason(DisneySeason season) async {
    setState(() { _selectedSeason = null; _loadingSeasons = true; });
    try {
      final fullSeason = await DisneyApiService.fetchEpisodes(season.seasonId);
      if (mounted) setState(() { _selectedSeason = fullSeason; _loadingSeasons = false; });
    } catch (e) {
      if (mounted) setState(() { _selectedSeason = season; _loadingSeasons = false; });
    }
  }

  // ── Seleção e resolução de stream ─────────────────────────────────────────

  Future<void> _selectContent(DisneyContentItem item) async {
    if (_isCapturing) return;

    // Se é uma série, abrir navegação de temporadas
    if (item.isSeries) {
      await _openSeries(item);
      return;
    }

    // É um filme ou episódio — resolver o stream
    await _resolveAndCapture(item);
  }

  Future<void> _resolveAndCapture(DisneyContentItem item) async {
    setState(() => _isCapturing = true);
    HapticFeedback.mediumImpact();

    try {
      final stream = await DisneyPlaybackService.resolveStream(item.contentId);

      final notifier = ref.read(screeningRoomProvider(widget.threadId).notifier);
      final title = item.title;
      final thumbnail = item.imageUrl;

      if (widget.addToQueue) {
        await notifier.addToQueue(
          url: stream.manifestUrl,
          title: title,
          thumbnail: thumbnail,
        );
      } else {
        await notifier.updateVideo(
          videoUrl: stream.manifestUrl,
          videoTitle: title,
        );
      }

      HapticFeedback.lightImpact();
      if (mounted) {
        // Fechar toda a pilha de navegação Disney+
        Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/screening');
      }
    } on DisneyAuthException catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        if (e.isExpired) {
          _handleSessionExpired();
        } else {
          _showError(e.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        _showError('Erro ao carregar vídeo: $e');
      }
    }
  }

  void _handleSessionExpired() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A1A),
        title: const Text('Sessão expirada', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Sua sessão Disney+ expirou. Você precisa fazer login novamente.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // Volta para o WebView de login
            },
            child: const Text('Fazer login', style: TextStyle(color: _disneyBlue)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _disneyBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                Expanded(child: _buildBody()),
              ],
            ),
            if (_isCapturing) _buildCapturingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Botão voltar (ou fechar se não há série selecionada)
          GestureDetector(
            onTap: () {
              if (_selectedSeries != null) {
                setState(() { _selectedSeries = null; _seasons = []; _selectedSeason = null; });
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _selectedSeries != null ? Icons.arrow_back_rounded : Icons.close_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Logo Disney+
          if (_selectedSeries == null) ...[
            _buildDisneyLogo(),
            const Spacer(),
            // Botão de logout
            GestureDetector(
              onTap: _confirmLogout,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Text(
                  'Sair',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: Text(
                _selectedSeries!.title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisneyLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _disneyBlue,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Disney+',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    if (_selectedSeries != null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Buscar filmes e séries...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.4), size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    _searchFocusNode.unfocus();
                  },
                  child: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.4), size: 18),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Navegação de série selecionada
    if (_selectedSeries != null) {
      return _buildSeriesView();
    }

    // Resultados de busca
    if (_searchQuery.isNotEmpty) {
      return _buildSearchResults();
    }

    // Catálogo principal
    if (_isLoading) return _buildLoadingState();
    if (_error != null) return _buildErrorState();
    if (_homePage == null) return const SizedBox.shrink();
    return _buildCatalog();
  }

  Widget _buildCatalog() {
    final containers = _homePage!.containers
        .where((c) => c.items.isNotEmpty)
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      // +2 para as seções fixas: Continue Watching e Minha Lista (se não vazias)
      itemCount: containers.length
          + (_continueWatching.isNotEmpty ? 1 : 0)
          + (_myList.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        int offset = 0;
        // Seção "Continue Assistindo" — sempre no topo se não vazia
        if (_continueWatching.isNotEmpty) {
          if (index == 0) {
            return _buildFixedSection(
              title: 'Continue Assistindo',
              items: _continueWatching,
              icon: Icons.play_circle_outline_rounded,
            );
          }
          offset++;
        }
        // Seção "Minha Lista" — logo abaixo do Continue Watching
        if (_myList.isNotEmpty) {
          if (index == offset) {
            return _buildFixedSection(
              title: 'Minha Lista',
              items: _myList,
              icon: Icons.bookmark_outline_rounded,
            );
          }
          offset++;
        }
        // Restante do catálogo home
        final container = containers[index - offset];
        return _buildSection(container);
      },
    );
  }

  /// Seção fixa com ícone (Continue Watching / Minha Lista).
  Widget _buildFixedSection({
    required String title,
    required List<DisneyContentItem> items,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Icon(icon, color: _disneyBlue, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, i) => _buildContentCard(items[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(DisneyContainer container) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (container.title != null && container.title!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Text(
              container.title!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
        ],
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: container.items.length,
            itemBuilder: (context, i) => _buildContentCard(container.items[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildContentCard(DisneyContentItem item) {
    return GestureDetector(
      onTap: () => _selectContent(item),
      child: Container(
        width: 110,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: item.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) => Container(
                          color: Colors.white.withValues(alpha: 0.05),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white30,
                            ),
                          ),
                        ),
                        errorWidget: (ctx, url, err) => _buildPlaceholder(item),
                      )
                    : _buildPlaceholder(item),
              ),
            ),
            const SizedBox(height: 6),
            // Título
            Text(
              item.title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.isSeries) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.tv_rounded, size: 10, color: Colors.white.withValues(alpha: 0.35)),
                  const SizedBox(width: 3),
                  Text(
                    'Série',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(DisneyContentItem item) {
    return Container(
      color: Colors.white.withValues(alpha: 0.05),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.isSeries ? Icons.tv_rounded : Icons.movie_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  // ── Busca ─────────────────────────────────────────────────────────────────

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: _disneyBlue, strokeWidth: 2),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: Colors.white.withValues(alpha: 0.2), size: 48),
            const SizedBox(height: 12),
            Text(
              'Nenhum resultado para "$_searchQuery"',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, i) => _buildContentCard(_searchResults[i]),
    );
  }

  // ── Navegação de série ────────────────────────────────────────────────────

  Widget _buildSeriesView() {
    if (_loadingSeasons && _seasons.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _disneyBlue, strokeWidth: 2),
      );
    }

    return Column(
      children: [
        // Seletor de temporada
        if (_seasons.length > 1) _buildSeasonSelector(),
        // Lista de episódios
        Expanded(child: _buildEpisodeList()),
      ],
    );
  }

  Widget _buildSeasonSelector() {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _seasons.length,
        itemBuilder: (context, i) {
          final season = _seasons[i];
          final isSelected = _selectedSeason?.seasonId == season.seasonId;
          return GestureDetector(
            onTap: () => _selectSeason(season),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _disneyBlue : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected ? _disneyBlue : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                season.title ?? 'Temporada ${season.seasonNumber}',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEpisodeList() {
    if (_loadingSeasons) {
      return const Center(
        child: CircularProgressIndicator(color: _disneyBlue, strokeWidth: 2),
      );
    }

    final episodes = _selectedSeason?.episodes ?? [];
    if (episodes.isEmpty) {
      return Center(
        child: Text(
          'Nenhum episódio disponível',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: episodes.length,
      itemBuilder: (context, i) => _buildEpisodeTile(episodes[i]),
    );
  }

  Widget _buildEpisodeTile(DisneyContentItem episode) {
    return GestureDetector(
      onTap: () => _resolveAndCapture(episode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            // Thumbnail do episódio
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 96,
                height: 54,
                child: episode.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: episode.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (ctx, url, err) => Container(
                          color: Colors.white.withValues(alpha: 0.05),
                          child: Icon(Icons.play_circle_outline_rounded,
                              color: Colors.white.withValues(alpha: 0.3), size: 24),
                        ),
                      )
                    : Container(
                        color: Colors.white.withValues(alpha: 0.05),
                        child: Icon(Icons.play_circle_outline_rounded,
                            color: Colors.white.withValues(alpha: 0.3), size: 24),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (episode.episodeNumber != null)
                    Text(
                      'Ep. ${episode.episodeNumber}',
                      style: TextStyle(color: _disneyBlue.withValues(alpha: 0.8), fontSize: 11),
                    ),
                  Text(
                    episode.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (episode.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      episode.description!,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (episode.runtimeFormatted.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      episode.runtimeFormatted,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.play_arrow_rounded, color: Colors.white.withValues(alpha: 0.3), size: 22),
          ],
        ),
      ),
    );
  }

  // ── Estados de loading/erro ───────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _disneyBlue, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text(
            'Carregando catálogo Disney+...',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 48),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar catálogo',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Erro desconhecido',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadHomePage,
              style: ElevatedButton.styleFrom(backgroundColor: _disneyBlue),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapturingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _disneyBlue, strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              'Carregando vídeo...',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              'Disney+',
              style: TextStyle(color: _disneyBlue, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A1A),
        title: const Text('Sair do Disney+', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Deseja desconectar sua conta Disney+? Você precisará fazer login novamente.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DisneyAuthService.logout();
      if (mounted) Navigator.of(context).pop();
    }
  }
}
