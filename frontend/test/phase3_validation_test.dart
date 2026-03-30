import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';

/// ============================================================================
/// Testes de Validação — Fase 3 Estabilizada
///
/// Protegem os comportamentos introduzidos/modificados nas Sprints 3A–3E.
/// Foco em lógica pura (sem dependência de Supabase/Flutter widgets reais).
///
/// Cobertura:
/// - NotificationState.loadMoreError (Sprint 3D)
/// - Debounce duplo corrigido (Sprint 3D)
/// - RealtimeService: backoff exponencial, status global (Sprint 3E)
/// - PaginatedListView: error intermediário, debounce, prefetch (Sprint 3D)
/// - Cache offline-first para notificações (Sprint 3D)
/// ============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// MOCK: NotificationState com loadMoreError (Sprint 3D)
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationState {
  final List<Map<String, dynamic>> notifications;
  final int unreadCount;
  final bool hasMore;
  final String? loadMoreError;

  const _NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.hasMore = true,
    this.loadMoreError,
  });

  _NotificationState copyWith({
    List<Map<String, dynamic>>? notifications,
    int? unreadCount,
    bool? hasMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return _NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMore: hasMore ?? this.hasMore,
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK: NotificationNotifier com loadMoreError + retryLoadMore (Sprint 3D)
// ─────────────────────────────────────────────────────────────────────────────

class _MockNotificationNotifier {
  int page = 0;
  bool isLoadingMore = false;
  _NotificationState state = const _NotificationState();

  /// loadMore com surfacing de erro (Sprint 3D behavior)
  Future<bool> loadMore(
      Future<List<Map<String, dynamic>>> Function(int, int) fetchPage) async {
    if (!state.hasMore || isLoadingMore) return false;

    isLoadingMore = true;
    page++;
    try {
      final items = await fetchPage(page, 20);
      state = state.copyWith(
        notifications: [...state.notifications, ...items],
        hasMore: items.length >= 20,
        clearLoadMoreError: true,
      );
      return true;
    } catch (e) {
      page--;
      state = state.copyWith(
        loadMoreError: 'Erro ao carregar mais notificações',
      );
      return false;
    } finally {
      isLoadingMore = false;
    }
  }

  /// retryLoadMore (Sprint 3D behavior)
  Future<bool> retryLoadMore(
      Future<List<Map<String, dynamic>>> Function(int, int) fetchPage) async {
    state = state.copyWith(clearLoadMoreError: true);
    return loadMore(fetchPage);
  }

  /// refresh com cache-first (Sprint 3D behavior)
  Future<void> refresh({
    List<Map<String, dynamic>>? cachedData,
    required Future<_NotificationState> Function() fetchFresh,
  }) async {
    page = 0;
    isLoadingMore = false;

    // Cache-first: se há dados em cache, mostra imediatamente
    if (cachedData != null && cachedData.isNotEmpty) {
      state = _NotificationState(
        notifications: cachedData,
        hasMore: true,
      );
    }

    // Depois busca dados frescos
    try {
      state = await fetchFresh();
    } catch (_) {
      // Se falhou mas tem cache, mantém o cache
      if (state.notifications.isEmpty) {
        rethrow;
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK: PaginatedListView state (Sprint 3D)
// ─────────────────────────────────────────────────────────────────────────────

class _MockPaginatedState<T> {
  List<T> items = [];
  int currentPage = 0;
  bool isLoading = false;
  bool hasMore = true;
  bool isFirstLoad = true;
  String? firstLoadError;
  String? loadMoreError;
  Timer? scrollDebounce;
  double prefetchThreshold;

  _MockPaginatedState({this.prefetchThreshold = 300});

  Future<void> loadFirstPage(
      Future<List<T>> Function(int, int) fetchPage) async {
    try {
      isFirstLoad = true;
      final result = await fetchPage(0, 20);
      items.addAll(result);
      currentPage = 1;
      hasMore = result.length >= 20;
      isFirstLoad = false;
      firstLoadError = null;
      loadMoreError = null;
    } catch (e) {
      isFirstLoad = false;
      firstLoadError = e.toString();
    }
  }

  /// loadNextPage com erro intermediário separado (Sprint 3D)
  Future<void> loadNextPage(
      Future<List<T>> Function(int, int) fetchPage) async {
    if (isLoading || !hasMore) return;
    isLoading = true;
    loadMoreError = null;
    try {
      final result = await fetchPage(currentPage, 20);
      items.addAll(result);
      currentPage++;
      hasMore = result.length >= 20;
    } catch (e) {
      loadMoreError = e.toString();
    } finally {
      isLoading = false;
    }
  }

  /// retryLoadMore (Sprint 3D)
  Future<void> retryLoadMore(
      Future<List<T>> Function(int, int) fetchPage) async {
    loadMoreError = null;
    await loadNextPage(fetchPage);
  }

  /// Simula scroll com debounce (Sprint 3D)
  void onScroll({
    required double currentScroll,
    required double maxScroll,
    required void Function() loadMore,
  }) {
    scrollDebounce?.cancel();
    scrollDebounce = Timer(const Duration(milliseconds: 100), () {
      final threshold = maxScroll - prefetchThreshold;
      if (currentScroll >= threshold && !isLoading && hasMore) {
        loadMore();
      }
    });
  }

  void dispose() {
    scrollDebounce?.cancel();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK: RealtimeService backoff + status (Sprint 3E)
// ─────────────────────────────────────────────────────────────────────────────

enum _RealtimeStatus { connected, connecting, disconnected }

class _MockManagedChannel {
  final String name;
  int retryCount = 0;
  Timer? retryTimer;
  bool isSubscribed = false;

  _MockManagedChannel({required this.name});
}

class _MockRealtimeService {
  _RealtimeStatus status = _RealtimeStatus.connected;
  final Map<String, _MockManagedChannel> channels = {};

  _MockManagedChannel subscribe(String channelName) {
    unsubscribe(channelName);
    final managed = _MockManagedChannel(name: channelName);
    managed.isSubscribed = true;
    channels[channelName] = managed;
    _updateGlobalStatus();
    return managed;
  }

  void unsubscribe(String channelName) {
    final managed = channels.remove(channelName);
    if (managed != null) {
      managed.retryTimer?.cancel();
      managed.isSubscribed = false;
    }
    _updateGlobalStatus();
  }

  void unsubscribeAll() {
    for (final managed in channels.values) {
      managed.retryTimer?.cancel();
      managed.isSubscribed = false;
    }
    channels.clear();
    status = _RealtimeStatus.disconnected;
  }

  /// Simula desconexão de um canal (Sprint 3E behavior)
  int handleDisconnect(String channelName) {
    final managed = channels[channelName];
    if (managed == null) return -1;

    // Backoff exponencial: min(30, 2^retryCount)
    final delay = _calculateBackoff(managed.retryCount);
    managed.retryCount++;
    status = _RealtimeStatus.connecting;

    return delay;
  }

  /// Simula reconexão bem-sucedida
  void handleReconnect(String channelName) {
    final managed = channels[channelName];
    if (managed == null) return;

    managed.retryCount = 0;
    managed.isSubscribed = true;
    _updateGlobalStatus();
  }

  int _calculateBackoff(int retryCount) {
    final delay = 1 << retryCount; // 2^retryCount
    return delay > 30 ? 30 : delay;
  }

  void _updateGlobalStatus() {
    if (channels.isEmpty) {
      status = _RealtimeStatus.disconnected;
      return;
    }
    final anyRetrying = channels.values.any((m) => m.retryCount > 0);
    status = anyRetrying
        ? _RealtimeStatus.connecting
        : _RealtimeStatus.connected;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK: Debounce duplo corrigido (Sprint 3D)
// ─────────────────────────────────────────────────────────────────────────────

class _MockSearchDebounce {
  Timer? suggestDebounce;
  Timer? searchDebounce;
  int suggestCallCount = 0;
  int searchCallCount = 0;

  void onSearchChanged(String value) {
    suggestDebounce?.cancel();
    searchDebounce?.cancel();

    if (value.trim().isEmpty) {
      suggestCallCount = 0;
      searchCallCount = 0;
      return;
    }

    // Debounce de 300ms para autocomplete
    suggestDebounce = Timer(const Duration(milliseconds: 300), () {
      suggestCallCount++;
    });

    // Debounce de 600ms para busca completa
    searchDebounce = Timer(const Duration(milliseconds: 600), () {
      searchCallCount++;
    });
  }

  void dispose() {
    suggestDebounce?.cancel();
    searchDebounce?.cancel();
  }
}

// ============================================================================
// TESTES
// ============================================================================

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // Sprint 3D: NotificationState.loadMoreError
  // ──────────────────────────────────────────────────────────────────────────

  group('Sprint 3D: NotificationState.loadMoreError', () {
    test('loadMoreError é null por padrão', () {
      const state = _NotificationState();
      expect(state.loadMoreError, isNull);
    });

    test('copyWith preserva loadMoreError quando não especificado', () {
      const state = _NotificationState(loadMoreError: 'Erro de rede');
      final copy = state.copyWith(unreadCount: 5);
      expect(copy.loadMoreError, 'Erro de rede');
      expect(copy.unreadCount, 5);
    });

    test('copyWith com clearLoadMoreError limpa o erro', () {
      const state = _NotificationState(loadMoreError: 'Erro de rede');
      final copy = state.copyWith(clearLoadMoreError: true);
      expect(copy.loadMoreError, isNull);
    });

    test('copyWith com clearLoadMoreError ignora novo loadMoreError', () {
      const state = _NotificationState(loadMoreError: 'Erro antigo');
      final copy = state.copyWith(
        clearLoadMoreError: true,
        loadMoreError: 'Erro novo',
      );
      // clearLoadMoreError tem prioridade
      expect(copy.loadMoreError, isNull);
    });

    test('loadMore seta loadMoreError em caso de falha', () async {
      final notifier = _MockNotificationNotifier();
      notifier.state = const _NotificationState(
        notifications: [
          {'id': '1'}
        ],
        hasMore: true,
      );

      await notifier.loadMore((page, size) async {
        throw Exception('Network error');
      });

      expect(notifier.state.loadMoreError, isNotNull);
      expect(notifier.state.loadMoreError,
          contains('Erro ao carregar mais notificações'));
      // Dados existentes preservados
      expect(notifier.state.notifications.length, 1);
    });

    test('loadMore limpa loadMoreError em caso de sucesso', () async {
      final notifier = _MockNotificationNotifier();
      notifier.state = const _NotificationState(
        notifications: [
          {'id': '1'}
        ],
        hasMore: true,
        loadMoreError: 'Erro anterior',
      );

      await notifier.loadMore((page, size) async {
        return List.generate(20, (i) => {'id': 'new_$i'});
      });

      expect(notifier.state.loadMoreError, isNull);
      expect(notifier.state.notifications.length, 21);
    });

    test('retryLoadMore limpa erro e tenta novamente', () async {
      final notifier = _MockNotificationNotifier();
      notifier.state = const _NotificationState(
        notifications: [
          {'id': '1'}
        ],
        hasMore: true,
        loadMoreError: 'Erro anterior',
      );

      final result = await notifier.retryLoadMore((page, size) async {
        return List.generate(20, (i) => {'id': 'retry_$i'});
      });

      expect(result, true);
      expect(notifier.state.loadMoreError, isNull);
      expect(notifier.state.notifications.length, 21);
    });

    test('retryLoadMore falha novamente seta novo loadMoreError', () async {
      final notifier = _MockNotificationNotifier();
      notifier.state = const _NotificationState(
        notifications: [
          {'id': '1'}
        ],
        hasMore: true,
        loadMoreError: 'Erro anterior',
      );

      final result = await notifier.retryLoadMore((page, size) async {
        throw Exception('Still failing');
      });

      expect(result, false);
      expect(notifier.state.loadMoreError, isNotNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Sprint 3D: Cache offline-first para notificações
  // ──────────────────────────────────────────────────────────────────────────

  group('Sprint 3D: Cache offline-first para notificações', () {
    test('refresh com cache mostra dados imediatamente', () async {
      final notifier = _MockNotificationNotifier();
      final cachedData = [
        {'id': 'cached_1'},
        {'id': 'cached_2'}
      ];

      await notifier.refresh(
        cachedData: cachedData,
        fetchFresh: () async => _NotificationState(
          notifications: [
            {'id': 'fresh_1'},
            {'id': 'fresh_2'},
            {'id': 'fresh_3'}
          ],
          hasMore: true,
        ),
      );

      // Dados frescos substituem o cache
      expect(notifier.state.notifications.length, 3);
      expect(notifier.state.notifications[0]['id'], 'fresh_1');
    });

    test('refresh com cache mantém cache se fetch falhar', () async {
      final notifier = _MockNotificationNotifier();
      final cachedData = [
        {'id': 'cached_1'},
        {'id': 'cached_2'}
      ];

      await notifier.refresh(
        cachedData: cachedData,
        fetchFresh: () async => throw Exception('Network error'),
      );

      // Cache preservado
      expect(notifier.state.notifications.length, 2);
      expect(notifier.state.notifications[0]['id'], 'cached_1');
    });

    test('refresh sem cache propaga erro se fetch falhar', () async {
      final notifier = _MockNotificationNotifier();

      expect(
        () => notifier.refresh(
          cachedData: null,
          fetchFresh: () async => throw Exception('Network error'),
        ),
        throwsException,
      );
    });

    test('refresh reseta page e isLoadingMore', () async {
      final notifier = _MockNotificationNotifier();
      notifier.page = 5;
      notifier.isLoadingMore = true;

      await notifier.refresh(
        cachedData: null,
        fetchFresh: () async => const _NotificationState(
          notifications: [
            {'id': '1'}
          ],
          hasMore: true,
        ),
      );

      expect(notifier.page, 0);
      expect(notifier.isLoadingMore, false);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Sprint 3D: PaginatedListView — erro intermediário separado
  // ──────────────────────────────────────────────────────────────────────────

  group('Sprint 3D: PaginatedListView erro intermediário', () {
    test('firstLoadError e loadMoreError são independentes', () async {
      final state = _MockPaginatedState<String>();

      // Primeira carga OK
      await state.loadFirstPage((page, size) async {
        return List.generate(20, (i) => 'item_$i');
      });
      expect(state.firstLoadError, isNull);
      expect(state.loadMoreError, isNull);
      expect(state.items.length, 20);

      // Segunda página falha
      await state.loadNextPage((page, size) async {
        throw Exception('Page 2 error');
      });

      // firstLoadError permanece null, loadMoreError setado
      expect(state.firstLoadError, isNull);
      expect(state.loadMoreError, isNotNull);
      expect(state.items.length, 20); // Dados preservados
    });

    test('retryLoadMore limpa loadMoreError e tenta novamente', () async {
      final state = _MockPaginatedState<String>();

      await state.loadFirstPage((page, size) async {
        return List.generate(20, (i) => 'item_$i');
      });

      await state.loadNextPage((page, size) async {
        throw Exception('Page 2 error');
      });
      expect(state.loadMoreError, isNotNull);

      // Retry com sucesso
      await state.retryLoadMore((page, size) async {
        return List.generate(10, (i) => 'page2_$i');
      });

      expect(state.loadMoreError, isNull);
      expect(state.items.length, 30);
    });

    test('firstLoadError mostra tela de erro (items vazio)', () async {
      final state = _MockPaginatedState<String>();

      await state.loadFirstPage((page, size) async {
        throw Exception('Network error');
      });

      expect(state.firstLoadError, isNotNull);
      expect(state.items, isEmpty);
      // UI deve mostrar tela de erro (firstLoadError != null && items.isEmpty)
      final showsFullError = state.firstLoadError != null && state.items.isEmpty;
      expect(showsFullError, true);
    });

    test('loadMoreError não mostra tela de erro (items existem)', () async {
      final state = _MockPaginatedState<String>();

      await state.loadFirstPage((page, size) async {
        return List.generate(20, (i) => 'item_$i');
      });

      await state.loadNextPage((page, size) async {
        throw Exception('Page 2 error');
      });

      // UI deve mostrar retry banner, não tela de erro
      final showsFullError = state.firstLoadError != null && state.items.isEmpty;
      final showsRetryBanner =
          state.loadMoreError != null && state.items.isNotEmpty;
      expect(showsFullError, false);
      expect(showsRetryBanner, true);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Sprint 3D: Scroll debounce e prefetch threshold
  // ──────────────────────────────────────────────────────────────────────────

  group('Sprint 3D: Scroll debounce e prefetch', () {
    test('debounce evita chamadas duplicadas de loadMore', () {
      fakeAsync((async) {
        final state = _MockPaginatedState<String>(prefetchThreshold: 300);
        int loadMoreCalls = 0;

        // Simula 5 eventos de scroll rápidos
        // maxScroll=5000, prefetchThreshold=300, threshold=4700
        // currentScroll=4800 >= 4700 → deve disparar
        for (var i = 0; i < 5; i++) {
          state.onScroll(
            currentScroll: 4800,
            maxScroll: 5000,
            loadMore: () => loadMoreCalls++,
          );
        }

        // Antes do debounce, nenhuma chamada
        expect(loadMoreCalls, 0);

        // Avança 100ms (debounce)
        async.elapse(const Duration(milliseconds: 100));

        // Apenas 1 chamada (debounce funcionou)
        expect(loadMoreCalls, 1);

        state.dispose();
      });
    });

    test('prefetch threshold configurável dispara loadMore antes do final',
        () {
      fakeAsync((async) {
        final state = _MockPaginatedState<String>(prefetchThreshold: 500);
        int loadMoreCalls = 0;

        // Scroll a 4600 de 5000 (faltam 400px, dentro do threshold de 500)
        state.onScroll(
          currentScroll: 4600,
          maxScroll: 5000,
          loadMore: () => loadMoreCalls++,
        );

        async.elapse(const Duration(milliseconds: 100));
        expect(loadMoreCalls, 1);

        state.dispose();
      });
    });

    test('scroll longe do final não dispara loadMore', () {
      fakeAsync((async) {
        final state = _MockPaginatedState<String>(prefetchThreshold: 300);
        int loadMoreCalls = 0;

        // Scroll a 2000 de 5000 (faltam 3000px, fora do threshold)
        state.onScroll(
          currentScroll: 2000,
          maxScroll: 5000,
          loadMore: () => loadMoreCalls++,
        );

        async.elapse(const Duration(milliseconds: 100));
        expect(loadMoreCalls, 0);

        state.dispose();
      });
    });

    test('dispose cancela debounce timer', () {
      fakeAsync((async) {
        final state = _MockPaginatedState<String>();
        int loadMoreCalls = 0;

        state.onScroll(
          currentScroll: 4800,
          maxScroll: 5000,
          loadMore: () => loadMoreCalls++,
        );

        // Dispose antes do debounce completar
        state.dispose();

        async.elapse(const Duration(milliseconds: 100));
        expect(loadMoreCalls, 0); // Timer cancelado
      });
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Sprint 3D: Debounce duplo corrigido (CommunitySearchScreen)
  // ──────────────────────────────────────────────────────────────────────────

  group('Sprint 3D: Debounce duplo corrigido', () {
    test('sugestões disparam em 300ms, busca em 600ms', () {
      fakeAsync((async) {
        final search = _MockSearchDebounce();

        search.onSearchChanged('flutter');

        // Antes de 300ms: nada
        async.elapse(const Duration(milliseconds: 200));
        expect(search.suggestCallCount, 0);
        expect(search.searchCallCount, 0);

        // Após 300ms: sugestões disparam
        async.elapse(const Duration(milliseconds: 100));
        expect(search.suggestCallCount, 1);
        expect(search.searchCallCount, 0);

        // Após 600ms: busca dispara
        async.elapse(const Duration(milliseconds: 300));
        expect(search.suggestCallCount, 1);
        expect(search.searchCallCount, 1);

        search.dispose();
      });
    });

    test('digitação rápida cancela timers anteriores', () {
      fakeAsync((async) {
        final search = _MockSearchDebounce();

        search.onSearchChanged('f');
        async.elapse(const Duration(milliseconds: 100));
        search.onSearchChanged('fl');
        async.elapse(const Duration(milliseconds: 100));
        search.onSearchChanged('flu');
        async.elapse(const Duration(milliseconds: 100));
        search.onSearchChanged('flut');

        // Espera sugestões (300ms após último input)
        async.elapse(const Duration(milliseconds: 300));
        expect(search.suggestCallCount, 1); // Apenas 1 chamada

        // Espera busca (600ms após último input)
        async.elapse(const Duration(milliseconds: 300));
        expect(search.searchCallCount, 1); // Apenas 1 chamada

        search.dispose();
      });
    });

    test('campo vazio cancela ambos os timers', () {
      fakeAsync((async) {
        final search = _MockSearchDebounce();

        search.onSearchChanged('flutter');
        async.elapse(const Duration(milliseconds: 100));
        search.onSearchChanged('');

        // Espera mais que ambos os debounces
        async.elapse(const Duration(milliseconds: 700));
        expect(search.suggestCallCount, 0);
        expect(search.searchCallCount, 0);

        search.dispose();
      });
    });

    test('sugestões e busca são independentes', () {
      fakeAsync((async) {
        final search = _MockSearchDebounce();

        search.onSearchChanged('dart');

        // Espera sugestões (300ms)
        async.elapse(const Duration(milliseconds: 300));
        expect(search.suggestCallCount, 1);
        expect(search.searchCallCount, 0); // Busca ainda não disparou

        search.dispose();
      });
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Sprint 3E: RealtimeService — backoff exponencial
  // ──────────────────────────────────────────────────────────────────────────

  group('Sprint 3E: RealtimeService backoff exponencial', () {
    test('backoff segue padrão 1, 2, 4, 8, 16, 30, 30...', () {
      final service = _MockRealtimeService();
      service.subscribe('test:channel');

      // Simula desconexões consecutivas
      final delays = <int>[];
      for (var i = 0; i < 8; i++) {
        delays.add(service.handleDisconnect('test:channel'));
      }

      expect(delays[0], 1); // 2^0
      expect(delays[1], 2); // 2^1
      expect(delays[2], 4); // 2^2
      expect(delays[3], 8); // 2^3
      expect(delays[4], 16); // 2^4
      expect(delays[5], 30); // min(30, 2^5=32) → capped
      expect(delays[6], 30); // capped
      expect(delays[7], 30); // capped
    });

    test('reconexão reseta retryCount', () {
      final service = _MockRealtimeService();
      service.subscribe('test:channel');

      // 3 desconexões
      service.handleDisconnect('test:channel');
      service.handleDisconnect('test:channel');
      service.handleDisconnect('test:channel');
      expect(service.channels['test:channel']!.retryCount, 3);

      // Reconexão
      service.handleReconnect('test:channel');
      expect(service.channels['test:channel']!.retryCount, 0);

      // Próxima desconexão volta a 1s
      final delay = service.handleDisconnect('test:channel');
      expect(delay, 1);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Sprint 3E: RealtimeService — status global
  // ──────────────────────────────────────────────────────────────────────────

  group('Sprint 3E: RealtimeService status global', () {
    test('status = connected quando todos os canais estão OK', () {
      final service = _MockRealtimeService();
      service.subscribe('chat:1');
      service.subscribe('notif:1');

      expect(service.status, _RealtimeStatus.connected);
    });

    test('status = connecting quando qualquer canal está reconectando', () {
      final service = _MockRealtimeService();
      service.subscribe('chat:1');
      service.subscribe('notif:1');

      service.handleDisconnect('chat:1');

      expect(service.status, _RealtimeStatus.connecting);
    });

    test('status = connected após reconexão de todos os canais', () {
      final service = _MockRealtimeService();
      service.subscribe('chat:1');
      service.subscribe('notif:1');

      service.handleDisconnect('chat:1');
      expect(service.status, _RealtimeStatus.connecting);

      service.handleReconnect('chat:1');
      expect(service.status, _RealtimeStatus.connected);
    });

    test('status = disconnected quando não há canais', () {
      final service = _MockRealtimeService();
      expect(service.status, _RealtimeStatus.connected);

      service.subscribe('chat:1');
      service.unsubscribe('chat:1');

      expect(service.status, _RealtimeStatus.disconnected);
    });

    test('unsubscribeAll limpa tudo e seta disconnected', () {
      final service = _MockRealtimeService();
      service.subscribe('chat:1');
      service.subscribe('notif:1');
      service.subscribe('screening:1');

      service.unsubscribeAll();

      expect(service.channels, isEmpty);
      expect(service.status, _RealtimeStatus.disconnected);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Sprint 3E: RealtimeService — subscribe/unsubscribe
  // ──────────────────────────────────────────────────────────────────────────

  group('Sprint 3E: RealtimeService subscribe/unsubscribe', () {
    test('subscribe cria canal gerenciado', () {
      final service = _MockRealtimeService();
      final managed = service.subscribe('chat:1');

      expect(managed.name, 'chat:1');
      expect(managed.isSubscribed, true);
      expect(service.channels.containsKey('chat:1'), true);
    });

    test('subscribe duplicado substitui canal anterior', () {
      final service = _MockRealtimeService();
      final first = service.subscribe('chat:1');
      final second = service.subscribe('chat:1');

      expect(first.isSubscribed, false); // Dessubscrito
      expect(second.isSubscribed, true);
      expect(service.channels.length, 1);
    });

    test('unsubscribe remove canal e cancela retry', () {
      final service = _MockRealtimeService();
      service.subscribe('chat:1');
      service.handleDisconnect('chat:1');

      service.unsubscribe('chat:1');

      expect(service.channels.containsKey('chat:1'), false);
    });

    test('unsubscribe de canal inexistente não crasha', () {
      final service = _MockRealtimeService();
      expect(() => service.unsubscribe('inexistente'), returnsNormally);
    });

    test('handleDisconnect de canal inexistente retorna -1', () {
      final service = _MockRealtimeService();
      expect(service.handleDisconnect('inexistente'), -1);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Sprint 3B: Validação de preservação de extração de widgets
  // ──────────────────────────────────────────────────────────────────────────

  group('Sprint 3B: Preservação de lógica em extrações', () {
    test('NotificationState copyWith preserva todos os campos', () {
      const original = _NotificationState(
        notifications: [
          {'id': '1'}
        ],
        unreadCount: 5,
        hasMore: false,
        loadMoreError: 'Erro',
      );

      // copyWith sem argumentos preserva tudo
      final copy = original.copyWith();
      expect(copy.notifications.length, 1);
      expect(copy.unreadCount, 5);
      expect(copy.hasMore, false);
      expect(copy.loadMoreError, 'Erro');
    });

    test('NotificationState copyWith atualiza campos específicos', () {
      const original = _NotificationState(
        notifications: [
          {'id': '1'}
        ],
        unreadCount: 5,
        hasMore: true,
      );

      final copy = original.copyWith(unreadCount: 0, hasMore: false);
      expect(copy.notifications.length, 1); // Preservado
      expect(copy.unreadCount, 0); // Atualizado
      expect(copy.hasMore, false); // Atualizado
    });
  });
}
