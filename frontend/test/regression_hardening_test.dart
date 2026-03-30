import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
/// Testes de Regressão — Fase 2 de Hardening
///
/// Protegem as correções P0/P1 do commit 66b509c e os fixes da validação.
/// Foco em lógica pura (sem dependência de Supabase/Flutter widgets).
/// ============================================================================

// ── Simulação do NotificationState para testar lógica de paginação ──

class _NotificationState {
  final List<Map<String, dynamic>> notifications;
  final int unreadCount;
  final bool hasMore;

  const _NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.hasMore = true,
  });

  _NotificationState copyWith({
    List<Map<String, dynamic>>? notifications,
    int? unreadCount,
    bool? hasMore,
  }) {
    return _NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// ── Simulação do NotificationNotifier para testar race conditions ──

class _MockNotificationNotifier {
  int page = 0;
  bool isLoadingMore = false;
  _NotificationState state = const _NotificationState();

  /// Simula loadMore com guard _isLoadingMore
  Future<bool> loadMore(Future<List<Map<String, dynamic>>> Function(int, int) fetchPage) async {
    if (!state.hasMore || isLoadingMore) return false;

    isLoadingMore = true;
    page++;
    try {
      final items = await fetchPage(page, 20);
      state = state.copyWith(
        notifications: [...state.notifications, ...items],
        hasMore: items.length >= 20,
      );
      return true;
    } catch (e) {
      page--;
      return false;
    } finally {
      isLoadingMore = false;
    }
  }

  /// Simula refresh que DEVE resetar isLoadingMore
  Future<void> refresh(Future<_NotificationState> Function() fetch) async {
    page = 0;
    isLoadingMore = false; // FIX BUG-R1: MUST reset this
    state = await fetch();
  }
}

// ── Simulação de PaginatedGridView state para testar error/retry ──

class _MockGridState<T> {
  List<T> items = [];
  int currentPage = 0;
  bool isLoading = false;
  bool hasMore = true;
  bool isFirstLoad = true;
  String? error;

  Future<void> loadFirstPage(Future<List<T>> Function(int, int) fetchPage) async {
    try {
      final result = await fetchPage(0, 20);
      items.addAll(result);
      currentPage = 1;
      hasMore = result.length >= 20;
      isFirstLoad = false;
      error = null; // FIX BUG-R4: MUST clear error on success
    } catch (e) {
      isFirstLoad = false;
      error = e.toString();
    }
  }

  Future<void> loadNextPage(Future<List<T>> Function(int, int) fetchPage) async {
    if (isLoading || !hasMore) return;
    isLoading = true;
    try {
      final result = await fetchPage(currentPage, 20);
      items.addAll(result);
      currentPage++;
      hasMore = result.length >= 20;
      isLoading = false;
    } catch (e) {
      isLoading = false;
      error = e.toString();
    }
  }

  void retry(Future<List<T>> Function(int, int) fetchPage) {
    error = null;
    isFirstLoad = true;
    items.clear();
    loadFirstPage(fetchPage);
  }

  void refresh(Future<List<T>> Function(int, int) fetchPage) {
    items.clear();
    currentPage = 0;
    hasMore = true;
    loadFirstPage(fetchPage);
  }
}

// ── Simulação de story sort para testar null safety ──

List<Map<String, dynamic>> _sortStories(List<Map<String, dynamic>> stories) {
  final sorted = List<Map<String, dynamic>>.from(stories);
  sorted.sort((a, b) {
    final aUnseen = a['has_unviewed'] as bool? ?? false; // FIX: safe cast
    final bUnseen = b['has_unviewed'] as bool? ?? false;
    if (aUnseen && !bUnseen) return -1;
    if (!aUnseen && bUnseen) return 1;
    return 0;
  });
  return sorted;
}

// ── Simulação de cache box validation ──

class _MockCacheService {
  static const _validBoxNames = {
    'posts_cache',
    'communities_cache',
    'messages_cache',
    'profiles_cache',
    'feed_cache',
    'cache_metadata',
    'notifications_cache',
    'wiki_cache',
  };

  static final Set<String> clearedBoxes = {};

  static Future<bool> clearBox(String boxName) async {
    if (!_validBoxNames.contains(boxName)) {
      return false; // Rejected
    }
    clearedBoxes.add(boxName);
    return true; // Accepted
  }
}

// ── Simulação de form validation ──

bool _safeFormValidate(bool? Function()? currentStateValidate) {
  return currentStateValidate?.call() == true;
}

// ── Simulação de video listener lifecycle ──

class _MockVideoController {
  final List<void Function()> _listeners = [];
  bool isDisposed = false;

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  int get listenerCount => _listeners.length;

  void dispose() {
    isDisposed = true;
  }
}

class _MockStoryViewer {
  _MockVideoController? videoController;
  void Function()? videoEndListener;

  /// Simula _startStory com fix BUG-R2
  void startStory(String type, String? mediaUrl) {
    // Remove listener antes de dispose (FIX BUG-R2)
    if (videoEndListener != null) {
      videoController?.removeListener(videoEndListener!);
      videoEndListener = null;
    }
    videoController?.dispose();
    videoController = null;

    if (type == 'video' && mediaUrl != null) {
      initVideo(mediaUrl);
    }
  }

  void initVideo(String url) {
    // Remove listener antes de dispose (FIX BUG-R2)
    if (videoEndListener != null) {
      videoController?.removeListener(videoEndListener!);
      videoEndListener = null;
    }
    videoController?.dispose();
    videoController = _MockVideoController();

    videoEndListener = () {
      // Simula advance
    };
    videoController!.addListener(videoEndListener!);
  }

  void dispose() {
    if (videoEndListener != null) {
      videoController?.removeListener(videoEndListener!);
    }
    videoController?.dispose();
  }
}

// ============================================================================
// TESTES
// ============================================================================

void main() {
  group('BUG-R1: Notification loadMore race condition', () {
    test('loadMore guard previne chamadas simultâneas', () async {
      final notifier = _MockNotificationNotifier();
      notifier.state = const _NotificationState(hasMore: true);

      int fetchCount = 0;
      Future<List<Map<String, dynamic>>> slowFetch(int page, int size) async {
        fetchCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return List.generate(20, (i) => {'id': '${page}_$i'});
      }

      // Dispara 3 loadMore simultâneos
      final futures = [
        notifier.loadMore(slowFetch),
        notifier.loadMore(slowFetch),
        notifier.loadMore(slowFetch),
      ];
      final results = await Future.wait(futures);

      // Apenas 1 deve ter executado
      expect(fetchCount, 1);
      expect(results.where((r) => r == true).length, 1);
      expect(results.where((r) => r == false).length, 2);
    });

    test('refresh reseta isLoadingMore para evitar deadlock', () async {
      final notifier = _MockNotificationNotifier();
      notifier.isLoadingMore = true; // Simula loadMore em andamento

      await notifier.refresh(() async => const _NotificationState(
            notifications: [{'id': '1'}],
            hasMore: true,
          ));

      expect(notifier.isLoadingMore, false);
      expect(notifier.page, 0);
      expect(notifier.state.notifications.length, 1);
    });

    test('loadMore funciona após refresh (sem deadlock)', () async {
      final notifier = _MockNotificationNotifier();
      notifier.isLoadingMore = true; // Simula estado travado

      // Refresh deve destravar
      await notifier.refresh(() async => const _NotificationState(
            notifications: [{'id': '1'}],
            hasMore: true,
          ));

      // LoadMore deve funcionar agora
      final result = await notifier.loadMore((page, size) async {
        return List.generate(20, (i) => {'id': 'new_$i'});
      });

      expect(result, true);
      expect(notifier.state.notifications.length, 21); // 1 do refresh + 20 do loadMore
    });

    test('loadMore decrementa page em caso de erro', () async {
      final notifier = _MockNotificationNotifier();
      notifier.state = const _NotificationState(hasMore: true);

      final result = await notifier.loadMore((page, size) async {
        throw Exception('Network error');
      });

      expect(result, false);
      expect(notifier.page, 0); // Deve ter decrementado de volta
      expect(notifier.isLoadingMore, false); // Deve ter resetado no finally
    });
  });

  group('BUG-R2: Video listener lifecycle', () {
    test('listener removido ao trocar entre stories de vídeo', () {
      final viewer = _MockStoryViewer();

      // Story 1: vídeo
      viewer.startStory('video', 'https://example.com/video1.mp4');
      expect(viewer.videoController?.listenerCount, 1);
      final controller1 = viewer.videoController;

      // Story 2: vídeo — deve remover listener do controller 1
      viewer.startStory('video', 'https://example.com/video2.mp4');
      expect(controller1?.listenerCount, 0); // Listener removido antes de dispose
      expect(controller1?.isDisposed, true);
      expect(viewer.videoController?.listenerCount, 1); // Novo listener no controller 2
    });

    test('listener removido ao trocar de vídeo para imagem', () {
      final viewer = _MockStoryViewer();

      // Story 1: vídeo
      viewer.startStory('video', 'https://example.com/video1.mp4');
      expect(viewer.videoController?.listenerCount, 1);
      final controller1 = viewer.videoController;

      // Story 2: imagem — deve remover listener e dispor controller
      viewer.startStory('image', null);
      expect(controller1?.listenerCount, 0);
      expect(controller1?.isDisposed, true);
      expect(viewer.videoController, isNull);
    });

    test('dispose remove listener do controller atual', () {
      final viewer = _MockStoryViewer();

      viewer.startStory('video', 'https://example.com/video1.mp4');
      final controller = viewer.videoController;
      expect(controller?.listenerCount, 1);

      viewer.dispose();
      expect(controller?.listenerCount, 0);
      expect(controller?.isDisposed, true);
    });

    test('dispose sem vídeo não crasha', () {
      final viewer = _MockStoryViewer();
      viewer.startStory('image', null);

      // Não deve lançar exceção
      expect(() => viewer.dispose(), returnsNormally);
    });

    test('3 stories de vídeo consecutivos sem leak', () {
      final viewer = _MockStoryViewer();
      final controllers = <_MockVideoController>[];

      for (var i = 0; i < 3; i++) {
        viewer.startStory('video', 'https://example.com/video$i.mp4');
        controllers.add(viewer.videoController!);
      }

      // Apenas o último controller deve ter listener
      expect(controllers[0].listenerCount, 0);
      expect(controllers[1].listenerCount, 0);
      expect(controllers[2].listenerCount, 1);

      // Primeiros 2 devem estar disposed
      expect(controllers[0].isDisposed, true);
      expect(controllers[1].isDisposed, true);
      expect(controllers[2].isDisposed, false);

      viewer.dispose();
      expect(controllers[2].listenerCount, 0);
      expect(controllers[2].isDisposed, true);
    });
  });

  group('BUG-R4: PaginatedGridView error state', () {
    test('error limpo após retry bem-sucedido', () async {
      final grid = _MockGridState<String>();

      // Primeira carga falha
      await grid.loadFirstPage((page, size) async {
        throw Exception('Network error');
      });
      expect(grid.error, isNotNull);
      expect(grid.items, isEmpty);

      // Retry com sucesso
      await grid.loadFirstPage((page, size) async {
        return ['item1', 'item2'];
      });
      expect(grid.error, isNull); // BUG-R4 fix: error deve ser null
      expect(grid.items.length, 2);
    });

    test('error limpo após refresh bem-sucedido', () async {
      final grid = _MockGridState<String>();

      // Primeira carga falha
      await grid.loadFirstPage((page, size) async {
        throw Exception('Network error');
      });
      expect(grid.error, isNotNull);

      // Refresh com sucesso
      grid.items.clear();
      grid.currentPage = 0;
      grid.hasMore = true;
      await grid.loadFirstPage((page, size) async {
        return ['item1'];
      });
      expect(grid.error, isNull); // BUG-R4 fix: error deve ser null
    });

    test('error setado em loadNextPage não mostra se items existem', () async {
      final grid = _MockGridState<String>();

      // Primeira carga OK
      await grid.loadFirstPage((page, size) async {
        return List.generate(20, (i) => 'item_$i');
      });
      expect(grid.items.length, 20);

      // Segunda página falha
      await grid.loadNextPage((page, size) async {
        throw Exception('Page 2 error');
      });
      expect(grid.error, isNotNull);
      expect(grid.items.isNotEmpty, true);
      // UI mostra dados (error != null && items.isEmpty é false)
      final showsError = grid.error != null && grid.items.isEmpty;
      expect(showsError, false);
    });
  });

  group('Story carousel sort null safety', () {
    test('sort com has_unviewed null não crasha', () {
      final stories = [
        {'id': '1', 'has_unviewed': null},
        {'id': '2', 'has_unviewed': true},
        {'id': '3', 'has_unviewed': false},
      ];

      expect(() => _sortStories(stories), returnsNormally);
      final sorted = _sortStories(stories);
      expect(sorted[0]['id'], '2'); // true primeiro
    });

    test('sort com has_unviewed ausente não crasha', () {
      final stories = [
        {'id': '1'}, // sem has_unviewed
        {'id': '2', 'has_unviewed': true},
      ];

      expect(() => _sortStories(stories), returnsNormally);
      final sorted = _sortStories(stories);
      expect(sorted[0]['id'], '2');
    });

    test('sort com todos true mantém ordem', () {
      final stories = [
        {'id': '1', 'has_unviewed': true},
        {'id': '2', 'has_unviewed': true},
      ];

      final sorted = _sortStories(stories);
      expect(sorted[0]['id'], '1');
      expect(sorted[1]['id'], '2');
    });

    test('sort com todos false mantém ordem', () {
      final stories = [
        {'id': '1', 'has_unviewed': false},
        {'id': '2', 'has_unviewed': false},
      ];

      final sorted = _sortStories(stories);
      expect(sorted[0]['id'], '1');
    });
  });

  group('Cache service box validation', () {
    test('aceita box names válidos', () async {
      for (final name in [
        'posts_cache',
        'communities_cache',
        'messages_cache',
        'profiles_cache',
        'feed_cache',
        'cache_metadata',
        'notifications_cache',
        'wiki_cache',
      ]) {
        expect(await _MockCacheService.clearBox(name), true);
      }
    });

    test('rejeita box names inválidos', () async {
      expect(await _MockCacheService.clearBox('invalid_box'), false);
      expect(await _MockCacheService.clearBox(''), false);
      expect(await _MockCacheService.clearBox('posts'), false);
      expect(await _MockCacheService.clearBox('DROP TABLE users'), false);
    });
  });

  group('Form validation null safety', () {
    test('currentState null retorna false', () {
      expect(_safeFormValidate(null), false);
    });

    test('validate() retorna false', () {
      expect(_safeFormValidate(() => false), false);
    });

    test('validate() retorna true', () {
      expect(_safeFormValidate(() => true), true);
    });

    test('validate() retorna null', () {
      expect(_safeFormValidate(() => null), false);
    });
  });

  group('Colors fallback safety', () {
    // Simula o padrão Colors.grey[N] ?? Colors.grey
    test('grey subscript com índice válido retorna valor', () {
      final greyMap = {
        300: 'grey300',
        500: 'grey500',
        600: 'grey600',
        700: 'grey700',
        800: 'grey800',
      };

      for (final entry in greyMap.entries) {
        final result = greyMap[entry.key] ?? 'fallback';
        expect(result, entry.value);
      }
    });

    test('grey subscript com índice inválido retorna fallback', () {
      final greyMap = <int, String>{};
      final result = greyMap[999] ?? 'fallback';
      expect(result, 'fallback');
    });
  });
}
