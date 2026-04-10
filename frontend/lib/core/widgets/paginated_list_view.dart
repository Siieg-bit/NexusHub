import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'shimmer_loading.dart';
import '../utils/responsive.dart';
import '../l10n/locale_provider.dart';

/// ============================================================================
/// PaginatedListView — Widget reutilizável de lista com paginação e infinite scroll.
///
/// Melhorias Sprint 3D:
/// - Feedback inline de erro em páginas intermediárias (retry banner)
/// - Debounce de scroll (evita chamadas duplicadas de _loadNextPage)
/// - Prefetch threshold configurável
///
/// Uso:
/// ```dart
/// PaginatedListView<PostModel>(
///   fetchPage: (page, pageSize) async {
///     final res = await supabase.from('posts')
///       .select()
///       .order('created_at')
///       .range(page * pageSize, (page + 1) * pageSize - 1);
///     return res.map((e) => PostModel.fromJson(e)).toList();
///   },
///   itemBuilder: (context, post, index) => PostCard(post: post),
///   emptyMessage: 'Nenhum post encontrado',
///   pageSize: 20,
/// )
/// ```
/// ============================================================================

typedef FetchPage<T> = Future<List<T>> Function(int page, int pageSize);

class PaginatedListView<T> extends ConsumerStatefulWidget {
  final FetchPage<T> fetchPage;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final String emptyMessage;
  final String emptyIcon;
  final int pageSize;
  final Widget? header;
  final Widget? separator;
  final EdgeInsets? padding;
  final ScrollController? scrollController;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Widget Function(BuildContext context)? shimmerBuilder;
  final int shimmerCount;
  final bool enableRefresh;
  final Future<void> Function()? onRefresh;

  /// Distância em pixels antes do final da lista para iniciar prefetch.
  /// Padrão: 300px. Valores maiores iniciam o carregamento mais cedo.
  final double prefetchThreshold;

   PaginatedListView({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    this.emptyMessage = 'No items found',
    this.emptyIcon = '📭',
    this.pageSize = 20,
    this.header,
    this.separator,
    this.padding,
    this.scrollController,
    this.shrinkWrap = false,
    this.physics,
    this.shimmerBuilder,
    this.shimmerCount = 5,
    this.enableRefresh = true,
    this.onRefresh,
    this.prefetchThreshold = 300,
  });

  @override
  ConsumerState<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends ConsumerState<PaginatedListView<T>> {
  final List<T> _items = [];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isFirstLoad = true;

  /// Erro na primeira carga (tela inteira de erro).
  String? _firstLoadError;

  /// Erro em páginas intermediárias (banner inline de retry).
  String? _loadMoreError;

  late ScrollController _scrollController;
  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - widget.prefetchThreshold) {
      // Debounce de 100ms para evitar chamadas duplicadas em scroll rápido
      if (_scrollDebounce?.isActive ?? false) return;
      _scrollDebounce = Timer(const Duration(milliseconds: 100), () {
        _loadNextPage();
      });
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isFirstLoad = true;
      _firstLoadError = null;
      _loadMoreError = null;
    });
    try {
      final items = await widget.fetchPage(0, widget.pageSize);
      if (mounted) {
        setState(() {
          _items.clear();
          _items.addAll(items);
          _currentPage = 1;
          _hasMore = items.length >= widget.pageSize;
          _isFirstLoad = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _firstLoadError = e.toString();
          _isFirstLoad = false;
        });
      }
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore || _loadMoreError != null) return;
    setState(() => _isLoading = true);
    try {
      final items = await widget.fetchPage(_currentPage, widget.pageSize);
      if (mounted) {
        setState(() {
          _items.addAll(items);
          _currentPage++;
          _hasMore = items.length >= widget.pageSize;
          _isLoading = false;
          _loadMoreError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadMoreError = e.toString();
        });
      }
    }
  }

  /// Retry para erro em página intermediária.
  void _retryLoadMore() {
    setState(() => _loadMoreError = null);
    _loadNextPage();
  }

  Future<void> _refresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
    _currentPage = 0;
    _hasMore = true;
    _firstLoadError = null;
    _loadMoreError = null;
    await _loadFirstPage();
  }

  /// Calcula quantos itens extras existem no final da lista:
  /// - 1 para loading spinner (quando carregando)
  /// - 1 para retry banner (quando erro intermediário)
  /// - 1 para spinner de "mais itens" (quando hasMore e sem erro)
  /// - 0 quando não há mais itens e sem erro
  int get _trailingCount {
    if (_isLoading) return 1;
    if (_loadMoreError != null) return 1;
    if (_hasMore) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    // ── First load: shimmer ──
    if (_isFirstLoad) {
      return _buildShimmer();
    }

    // ── Error state (first load failed, no items) ──
    if (_firstLoadError != null && _items.isEmpty) {
      return _buildError();
    }

    // ── Empty state ──
    if (_items.isEmpty) {
      return _buildEmpty();
    }

    // ── List with items ──
    final headerOffset = widget.header != null ? 1 : 0;
    final listView = ListView.builder(
      controller: widget.shrinkWrap ? null : _scrollController,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics ??
          (widget.shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics()),
      padding: widget.padding ?? EdgeInsets.symmetric(vertical: r.s(8)),
      itemCount: _items.length + headerOffset + _trailingCount,
      itemBuilder: (context, index) {
        // Header
        if (widget.header != null && index == 0) {
          return widget.header!;
        }

        final itemIndex = index - headerOffset;

        // Trailing widget (loading / error / prefetch spinner)
        if (itemIndex >= _items.length) {
          return _buildTrailing(r);
        }

        final item = _items[itemIndex];
        final child = widget.itemBuilder(context, item, itemIndex);

        if (widget.separator != null && itemIndex < _items.length - 1) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [child, widget.separator!],
          );
        }
        return child;
      },
    );

    if (widget.enableRefresh && !widget.shrinkWrap) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: listView,
      );
    }

    return listView;
  }

  /// Widget exibido no final da lista: spinner, retry banner, ou nada.
  Widget _buildTrailing(Responsive r) {
    final s = getStrings();
    // Erro em página intermediária → banner de retry inline
    if (_loadMoreError != null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
        child: Container(
          padding: EdgeInsets.all(r.s(12)),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(r.s(10)),
            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: Colors.red[300], size: r.s(20)),
              SizedBox(width: r.s(10)),
              Expanded(
                child: Text(
                  s.loadMoreError,
                  style: TextStyle(
                    color: Colors.red[300],
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _retryLoadMore,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(12), vertical: r.s(6)),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Text(
                    s.retry,
                    style: TextStyle(
                      color: Colors.red[300],
                      fontSize: r.fs(12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Loading spinner
    return Padding(
      padding: EdgeInsets.all(r.s(16)),
      child: Center(
        child: SizedBox(
          width: r.s(24),
          height: r.s(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    if (widget.shimmerBuilder != null) {
      return ListView.builder(
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics ?? const NeverScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: widget.shimmerCount,
        itemBuilder: (context, _) => widget.shimmerBuilder!(context),
      );
    }

    return ListView.builder(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics ?? const NeverScrollableScrollPhysics(),
      padding: widget.padding,
      itemCount: widget.shimmerCount,
      itemBuilder: (_, __) => const PostCardSkeleton(),
    );
  }

  Widget _buildError() {
    final s = getStrings();
    final r = context.r;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.s(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: r.s(48), color: Theme.of(context).colorScheme.error),
            SizedBox(height: r.s(16)),
            Text(s.somethingWentWrong,
                style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: r.s(8)),
            Text(_firstLoadError ?? s.unknownError,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey)),
            SizedBox(height: r.s(16)),
            FilledButton.icon(
              onPressed: _loadFirstPage,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(s.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final r = context.r;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.s(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.emptyIcon, style: TextStyle(fontSize: r.fs(48))),
            SizedBox(height: r.s(16)),
            Text(widget.emptyMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// PaginatedGridView — Grid com paginação e infinite scroll.
///
/// Mesmas melhorias Sprint 3D: error inline, debounce, prefetch configurável.
/// ============================================================================
class PaginatedGridView<T> extends ConsumerStatefulWidget {
  final FetchPage<T> fetchPage;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final String emptyMessage;
  final int pageSize;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final EdgeInsets? padding;
  final ScrollController? scrollController;
  final Widget Function(BuildContext context)? shimmerBuilder;
  final double prefetchThreshold;

   PaginatedGridView({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    this.emptyMessage = 'No items found',
    this.pageSize = 20,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 8,
    this.crossAxisSpacing = 8,
    this.childAspectRatio = 1.0,
    this.padding,
    this.scrollController,
    this.shimmerBuilder,
    this.prefetchThreshold = 300,
  });

  @override
  ConsumerState<PaginatedGridView<T>> createState() => _PaginatedGridViewState<T>();
}

class _PaginatedGridViewState<T> extends ConsumerState<PaginatedGridView<T>> {
  final List<T> _items = [];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isFirstLoad = true;
  String? _firstLoadError;
  String? _loadMoreError;
  late ScrollController _scrollController;
  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - widget.prefetchThreshold) {
      if (_scrollDebounce?.isActive ?? false) return;
      _scrollDebounce = Timer(const Duration(milliseconds: 100), () {
        _loadNextPage();
      });
    }
  }

  Future<void> _loadFirstPage() async {
    try {
      final items = await widget.fetchPage(0, widget.pageSize);
      if (mounted) {
        setState(() {
          _items.addAll(items);
          _currentPage = 1;
          _hasMore = items.length >= widget.pageSize;
          _isFirstLoad = false;
          _firstLoadError = null;
          _loadMoreError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFirstLoad = false;
          _firstLoadError = e.toString();
        });
      }
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore || _loadMoreError != null) return;
    setState(() => _isLoading = true);
    try {
      final items = await widget.fetchPage(_currentPage, widget.pageSize);
      if (mounted) {
        setState(() {
          _items.addAll(items);
          _currentPage++;
          _hasMore = items.length >= widget.pageSize;
          _isLoading = false;
          _loadMoreError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadMoreError = e.toString();
        });
      }
    }
  }

  void _retryLoadMore() {
    setState(() => _loadMoreError = null);
    _loadNextPage();
  }

  int get _trailingCount {
    if (_isLoading) return 1;
    if (_loadMoreError != null) return 1;
    if (_hasMore) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    if (_isFirstLoad) {
      return GridView.builder(
        padding: widget.padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          mainAxisSpacing: widget.mainAxisSpacing,
          crossAxisSpacing: widget.crossAxisSpacing,
          childAspectRatio: widget.childAspectRatio,
        ),
        itemCount: 6,
        itemBuilder: (ctx, _) => widget.shimmerBuilder != null
            ? widget.shimmerBuilder!(ctx)
            : const CommunityCardSkeleton(),
      );
    }

    // Error state (first load)
    if (_firstLoadError != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: r.s(48), color: Theme.of(context).colorScheme.error),
            SizedBox(height: r.s(16)),
            Text(s.somethingWentWrong,
                style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: r.s(8)),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _firstLoadError = null;
                  _isFirstLoad = true;
                });
                _loadFirstPage();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(s.retry),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(widget.emptyMessage,
            style: const TextStyle(color: Colors.grey)),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _items.clear();
        _currentPage = 0;
        _hasMore = true;
        _firstLoadError = null;
        _loadMoreError = null;
        await _loadFirstPage();
        if (!mounted) return;
      },
      child: GridView.builder(
        controller: _scrollController,
        padding: widget.padding ?? EdgeInsets.all(r.s(8)),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          mainAxisSpacing: widget.mainAxisSpacing,
          crossAxisSpacing: widget.crossAxisSpacing,
          childAspectRatio: widget.childAspectRatio,
        ),
        itemCount: _items.length + _trailingCount,
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            // Erro em página intermediária
            if (_loadMoreError != null) {
              return Center(
                child: GestureDetector(
                  onTap: _retryLoadMore,
                  child: Padding(
                    padding: EdgeInsets.all(r.s(8)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: Colors.red[300], size: r.s(20)),
                        SizedBox(height: r.s(4)),
                        Text(s.tapToRetry,
                            style: TextStyle(
                              color: Colors.red[300],
                              fontSize: r.fs(11),
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }
            return Center(
              child: Padding(
                padding: EdgeInsets.all(r.s(8)),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return widget.itemBuilder(context, _items[index], index);
        },
      ),
    );
  }
}
