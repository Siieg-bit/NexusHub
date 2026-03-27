import 'dart:async';
import 'package:flutter/material.dart';
import 'shimmer_loading.dart';

/// ============================================================================
/// PaginatedListView — Widget reutilizável de lista com paginação e infinite scroll.
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

class PaginatedListView<T> extends StatefulWidget {
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

  const PaginatedListView({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    this.emptyMessage = 'Nenhum item encontrado',
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
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final List<T> _items = [];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isFirstLoad = true;
  String? _error;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isFirstLoad = true;
      _error = null;
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
          _error = e.toString();
          _isFirstLoad = false;
        });
      }
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    try {
      final items = await widget.fetchPage(_currentPage, widget.pageSize);
      if (mounted) {
        setState(() {
          _items.addAll(items);
          _currentPage++;
          _hasMore = items.length >= widget.pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
    _currentPage = 0;
    _hasMore = true;
    _error = null;
    await _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    // ── First load: shimmer ──
    if (_isFirstLoad) {
      return _buildShimmer();
    }

    // ── Error state ──
    if (_error != null && _items.isEmpty) {
      return _buildError();
    }

    // ── Empty state ──
    if (_items.isEmpty) {
      return _buildEmpty();
    }

    // ── List with items ──
    final listView = ListView.builder(
      controller: widget.shrinkWrap ? null : _scrollController,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics ?? (widget.shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics()),
      padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length + (widget.header != null ? 1 : 0) + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Header
        if (widget.header != null && index == 0) {
          return widget.header!;
        }

        final itemIndex = widget.header != null ? index - 1 : index;

        // Loading indicator at bottom
        if (itemIndex >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Algo deu errado',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error ?? 'Erro desconhecido',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadFirstPage,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.emptyIcon, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
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
/// ============================================================================
class PaginatedGridView<T> extends StatefulWidget {
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

  const PaginatedGridView({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    this.emptyMessage = 'Nenhum item encontrado',
    this.pageSize = 20,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 8,
    this.crossAxisSpacing = 8,
    this.childAspectRatio = 1.0,
    this.padding,
    this.scrollController,
    this.shimmerBuilder,
  });

  @override
  State<PaginatedGridView<T>> createState() => _PaginatedGridViewState<T>();
}

class _PaginatedGridViewState<T> extends State<PaginatedGridView<T>> {
  final List<T> _items = [];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isFirstLoad = true;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
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
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isFirstLoad = false);
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    try {
      final items = await widget.fetchPage(_currentPage, widget.pageSize);
      if (mounted) {
        setState(() {
          _items.addAll(items);
          _currentPage++;
          _hasMore = items.length >= widget.pageSize;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        await _loadFirstPage();
      },
      child: GridView.builder(
        controller: _scrollController,
        padding: widget.padding ?? const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          mainAxisSpacing: widget.mainAxisSpacing,
          crossAxisSpacing: widget.crossAxisSpacing,
          childAspectRatio: widget.childAspectRatio,
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
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
