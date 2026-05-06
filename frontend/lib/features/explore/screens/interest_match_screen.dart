import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/match_queue_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/widgets/user_status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import 'package:amino_clone/config/nexus_theme_data.dart';

// ============================================================================
// InterestMatchScreen — Encontrar pessoas com interesses similares (unificada)
//
// Fluxo:
//   1. Busca estática via find_interest_matches → exibe cards de sugestões
//   2. Se não houver sugestões → entra automaticamente na fila de matchmaking
//   3. Fila em background (MatchQueueService) → ao fazer match, exibe resultado
// ============================================================================

// ── Modelo ───────────────────────────────────────────────────────────────────
class MatchedUser {
  final String userId;
  final String nickname;
  final String? iconUrl;
  final String? bio;
  final String? statusEmoji;
  final String? statusText;
  final List<String> commonInterests;
  final int score;
  bool isFollowing;

  MatchedUser({
    required this.userId,
    required this.nickname,
    this.iconUrl,
    this.bio,
    this.statusEmoji,
    this.statusText,
    required this.commonInterests,
    required this.score,
    required this.isFollowing,
  });

  factory MatchedUser.fromJson(Map<String, dynamic> j) => MatchedUser(
        userId: j['user_id'] as String,
        nickname: j['nickname'] as String? ?? 'Usuário',
        iconUrl: j['icon_url'] as String?,
        bio: j['bio'] as String?,
        statusEmoji: j['status_emoji'] as String?,
        statusText: j['status_text'] as String?,
        commonInterests:
            List<String>.from(j['common_interests'] as List? ?? []),
        score: (j['score'] as num?)?.toInt() ?? 0,
        isFollowing: j['is_following'] as bool? ?? false,
      );
}

// ── Enum de fase ──────────────────────────────────────────────────────────────
enum _Phase { suggestions, queue }

// ── Tela ─────────────────────────────────────────────────────────────────────
class InterestMatchScreen extends ConsumerStatefulWidget {
  const InterestMatchScreen({super.key});

  static void show(BuildContext context) => context.push('/interest-match');

  @override
  ConsumerState<InterestMatchScreen> createState() =>
      _InterestMatchScreenState();
}

class _InterestMatchScreenState extends ConsumerState<InterestMatchScreen>
    with TickerProviderStateMixin {
  // ── Estado de sugestões estáticas ─────────────────────────────────────────
  List<MatchedUser> _matches = [];
  bool _isLoadingSuggestions = true;
  bool _hasInterests = true;
  String? _suggestionsError;

  // ── Estado da fila (espelha MatchQueueService) ────────────────────────────
  late MatchQueueState _queueState;
  StreamSubscription<MatchQueueState>? _stateSub;

  // ── Fase atual da tela ────────────────────────────────────────────────────
  _Phase _phase = _Phase.suggestions;

  // ── Animações ─────────────────────────────────────────────────────────────
  late AnimationController _radarCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Getters de conveniência para a fila ──────────────────────────────────
  String get _queueStatus {
    switch (_queueState.status) {
      case MatchQueueStatus.idle:
        return 'idle';
      case MatchQueueStatus.waiting:
        return 'waiting';
      case MatchQueueStatus.matched:
        return 'matched';
      case MatchQueueStatus.error:
        return 'error';
    }
  }

  String? get _queueError => _queueState.error;
  String? get _matchedThreadId => _queueState.threadId;
  List<String> get _matchInterests => _queueState.matchInterests;
  int get _waitingSeconds => _queueState.waitingSeconds;

  @override
  void initState() {
    super.initState();

    _queueState = MatchQueueService.instance.state;

    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Ouvir mudanças do MatchQueueService
    _stateSub = MatchQueueService.instance.stateStream.listen((s) {
      if (mounted) setState(() => _queueState = s);
    });

    // Sincronizar estado da fila ao abrir (pode já estar em fila/matched)
    MatchQueueService.instance.syncStatus().then((_) {
      if (!mounted) return;
      final status = MatchQueueService.instance.state.status;
      if (status == MatchQueueStatus.waiting ||
          status == MatchQueueStatus.matched) {
        setState(() => _phase = _Phase.queue);
      } else {
        _loadSuggestions();
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _radarCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Busca estática de sugestões ───────────────────────────────────────────
  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoadingSuggestions = true;
      _suggestionsError = null;
      _phase = _Phase.suggestions;
    });

    try {
      final res = await SupabaseService.rpc(
        'find_interest_matches',
        params: {'p_limit': 20},
      );
      final rows = res as List? ?? [];
      if (!mounted) return;

      if (rows.isEmpty) {
        final profile = await SupabaseService.table('profiles')
            .select('selected_interests')
            .eq('id', SupabaseService.currentUserId ?? '')
            .maybeSingle();
        final interests =
            (profile?['selected_interests'] as List?)?.length ?? 0;

        if (!mounted) return;

        if (interests == 0) {
          setState(() {
            _hasInterests = false;
            _isLoadingSuggestions = false;
          });
        } else {
          // Tem interesses mas não achou ninguém → entrar na fila automaticamente
          setState(() {
            _hasInterests = true;
            _matches = [];
            _isLoadingSuggestions = false;
            _phase = _Phase.queue;
          });
          _enterQueueAuto();
        }
      } else {
        setState(() {
          _matches = rows
              .map((e) => MatchedUser.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      debugPrint('[InterestMatch] loadSuggestions error: $e');
      if (mounted) {
        setState(() {
          _suggestionsError = 'Erro ao carregar sugestões';
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  // ── Entrar na fila automaticamente ───────────────────────────────────────
  Future<void> _enterQueueAuto() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (user.selectedInterests.isEmpty) return;
    await MatchQueueService.instance.enter();
  }

  Future<void> _leaveQueue() => MatchQueueService.instance.leave();

  // ── Ações nos cards de sugestões ─────────────────────────────────────────
  Future<void> _toggleFollow(MatchedUser user) async {
    HapticService.action();
    final wasFollowing = user.isFollowing;
    setState(() => user.isFollowing = !wasFollowing);
    try {
      if (wasFollowing) {
        await SupabaseService.table('follows').delete().match({
          'follower_id': SupabaseService.currentUserId ?? '',
          'following_id': user.userId,
        });
      } else {
        await SupabaseService.table('follows').insert({
          'follower_id': SupabaseService.currentUserId ?? '',
          'following_id': user.userId,
        });
      }
    } catch (e) {
      debugPrint('[InterestMatch] toggleFollow error: $e');
      if (mounted) setState(() => user.isFollowing = wasFollowing);
    }
  }

  Future<void> _openDm(MatchedUser user) async {
    HapticService.action();
    try {
      final res = await SupabaseService.rpc(
        'send_dm_invite',
        params: {'p_target_user_id': user.userId},
      );
      final data = Map<String, dynamic>.from(res as Map);
      final success = data['success'] as bool? ?? false;
      final threadId = data['thread_id'] as String?;

      if (!success) {
        final errCode = data['error'] as String? ?? 'unknown';
        if (mounted) {
          final msg = switch (errCode) {
            'cannot_dm_yourself' => 'Você não pode enviar DM para si mesmo',
            'unauthenticated' => 'Você precisa estar logado',
            _ => 'Erro ao abrir conversa ($errCode)',
          };
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }

      if (threadId != null && mounted) {
        context.push('/chat/$threadId');
      }
    } catch (e, st) {
      debugPrint('[InterestMatch] openDm exception: $e');
      debugPrint('[InterestMatch] openDm stacktrace: $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Erro ao abrir conversa: ${e.toString().split('\n').first}'),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Formatação do tempo de espera ─────────────────────────────────────────
  String _formatWaitTime() {
    final s = _waitingSeconds;
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final rem = s % 60;
    return rem == 0 ? '${m}min' : '${m}min ${rem}s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = context.nexusTheme;
    final r = context.r;
    final isWaiting = _queueStatus == 'waiting';

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: theme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.people_alt_rounded,
                color: theme.accentPrimary, size: r.s(20)),
            SizedBox(width: r.s(8)),
            Flexible(
              child: Text(
                'Encontrar Pessoas',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: r.fs(16),
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (isWaiting)
            Padding(
              padding: EdgeInsets.only(right: r.s(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: r.s(10),
                    height: r.s(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.accentPrimary,
                    ),
                  ),
                  SizedBox(width: r.s(6)),
                  Text(
                    'Na fila',
                    style: TextStyle(
                      color: theme.accentPrimary,
                      fontSize: r.fs(12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: r.s(8)),
                ],
              ),
            ),
          if (_phase == _Phase.suggestions) ...[
            IconButton(
              icon: Icon(Icons.tune_rounded, color: theme.textSecondary),
              onPressed: () => context.push('/edit-interests'),
              tooltip: 'Editar interesses',
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: theme.textSecondary),
              onPressed: _loadSuggestions,
              tooltip: 'Atualizar',
            ),
          ],
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _buildBody(theme, r),
      ),
    );
  }

  Widget _buildBody(NexusThemeData theme, Responsive r) {
    if (_phase == _Phase.queue) {
      return _buildQueueBody(theme, r);
    }
    return _buildSuggestionsBody(theme, r);
  }

  // ── FASE 1: Sugestões estáticas ───────────────────────────────────────────
  Widget _buildSuggestionsBody(NexusThemeData theme, Responsive r) {
    if (_isLoadingSuggestions) {
      return Center(
        key: const ValueKey('loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ...List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, child) {
                      final progress = (_pulseCtrl.value + index / 3) % 1.0;
                      return Container(
                        width: r.s(72 + (progress * 120)),
                        height: r.s(72 + (progress * 120)),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.accentPrimary
                                .withValues(alpha: 1 - progress),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  );
                }),
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: r.s(80),
                    height: r.s(80),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [theme.accentPrimary, theme.accentSecondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accentPrimary.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(Icons.people_alt_rounded,
                        color: Colors.white, size: r.s(40)),
                  ),
                ),
              ],
            ),
            SizedBox(height: r.s(48)),
            Text(
              'Sintonizando interesses...',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: r.s(8)),
            Text(
              'Encontrando pessoas que curtem o mesmo que você',
              style: TextStyle(
                  color: theme.textSecondary, fontSize: r.fs(13)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_suggestionsError != null) {
      return Center(
        key: const ValueKey('error_suggestions'),
        child: Padding(
          padding: EdgeInsets.all(r.s(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: theme.error, size: r.s(48)),
              SizedBox(height: r.s(12)),
              Text(_suggestionsError!,
                  style: TextStyle(
                      color: theme.textSecondary, fontSize: r.fs(14))),
              SizedBox(height: r.s(16)),
              ElevatedButton(
                onPressed: _loadSuggestions,
                style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentPrimary),
                child: const Text('Tentar novamente',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasInterests) {
      return Center(
        key: const ValueKey('no_interests'),
        child: Padding(
          padding: EdgeInsets.all(r.s(32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(r.s(24)),
                decoration: BoxDecoration(
                  color: theme.accentPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.interests_rounded,
                    color: theme.accentPrimary, size: r.s(56)),
              ),
              SizedBox(height: r.s(24)),
              Text(
                'Personalize seu perfil',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: r.fs(20),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: r.s(12)),
              Text(
                'Adicione seus interesses para que possamos encontrar pessoas que curtem o mesmo que você!',
                style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: r.fs(14),
                    height: 1.4),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: r.s(32)),
              ElevatedButton.icon(
                onPressed: () => context.push('/edit-profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentPrimary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(32), vertical: r.s(14)),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(32))),
                ),
                icon: const Icon(Icons.edit_rounded, size: 20),
                label: Text('ADICIONAR INTERESSES',
                    style: TextStyle(
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1)),
              ),
            ],
          ),
        ),
      );
    }

    // Lista de sugestões
    return RefreshIndicator(
      key: const ValueKey('suggestions_list'),
      onRefresh: _loadSuggestions,
      color: theme.accentPrimary,
      child: ListView.separated(
        padding:
            EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
        itemCount: _matches.length,
        separatorBuilder: (_, __) => SizedBox(height: r.s(8)),
        itemBuilder: (_, i) => _buildMatchCard(_matches[i], theme, r),
      ),
    );
  }

  // ── FASE 2 e 3: Fila de matchmaking ──────────────────────────────────────
  Widget _buildQueueBody(NexusThemeData theme, Responsive r) {
    switch (_queueStatus) {
      case 'entering':
        return _buildQueueEntering(theme, r);
      case 'waiting':
        return _buildQueueWaiting(theme, r);
      case 'matched':
        return _buildQueueMatched(theme, r);
      case 'error':
        return _buildQueueError(theme, r);
      default:
        return _buildQueueWaiting(theme, r);
    }
  }

  Widget _buildQueueEntering(NexusThemeData theme, Responsive r) {
    return Center(
      key: const ValueKey('queue_entering'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: theme.accentPrimary),
          SizedBox(height: r.s(16)),
          Text(
            'Entrando na fila...',
            style:
                TextStyle(color: theme.textSecondary, fontSize: r.fs(14)),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueWaiting(NexusThemeData theme, Responsive r) {
    return Center(
      key: const ValueKey('queue_waiting'),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: r.s(200),
              height: r.s(200),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ...List.generate(3, (index) {
                    return AnimatedBuilder(
                      animation: _radarCtrl,
                      builder: (context, child) {
                        final progress =
                            (_radarCtrl.value + index / 3) % 1.0;
                        return Container(
                          width: r.s(60 + (progress * 140)),
                          height: r.s(60 + (progress * 140)),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.accentPrimary
                                  .withValues(alpha: (1 - progress) * 0.7),
                              width: 2,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: Container(
                      width: r.s(72),
                      height: r.s(72),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            theme.accentPrimary,
                            theme.accentSecondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.accentPrimary
                                .withValues(alpha: 0.4),
                            blurRadius: 16,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(Icons.people_alt_rounded,
                          color: Colors.white, size: r.s(36)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(24)),
            Text(
              'Procurando alguém...',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: r.fs(18),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: r.s(8)),
            Text(
              'Aguardando alguém com interesses em comum',
              style: TextStyle(
                  color: theme.textSecondary, fontSize: r.fs(13)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.s(8)),
            Text(
              'Na fila há ${_formatWaitTime()}',
              style: TextStyle(
                  color: theme.textSecondary, fontSize: r.fs(12)),
            ),
            SizedBox(height: r.s(32)),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(14), vertical: r.s(10)),
              decoration: BoxDecoration(
                color: theme.accentPrimary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(r.s(12)),
                border: Border.all(
                    color: theme.accentPrimary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: theme.accentPrimary, size: r.s(16)),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Text(
                      'Você pode sair desta tela. A fila continua em background e você será notificado quando encontrar alguém.',
                      style: TextStyle(
                          color: theme.textSecondary, fontSize: r.fs(12)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(16)),
            OutlinedButton.icon(
              onPressed: () async {
                await _leaveQueue();
                if (mounted) {
                  setState(() => _phase = _Phase.suggestions);
                  _loadSuggestions();
                }
              },
              icon: Icon(Icons.exit_to_app_rounded,
                  color: theme.error, size: r.s(16)),
              label: Text(
                'Sair da fila',
                style:
                    TextStyle(color: theme.error, fontSize: r.fs(14)),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: theme.error.withValues(alpha: 0.5)),
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(20), vertical: r.s(12)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueMatched(NexusThemeData theme, Responsive r) {
    return Center(
      key: const ValueKey('queue_matched'),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: r.s(100),
              height: r.s(100),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(Icons.favorite_rounded,
                  color: Colors.white, size: r.s(48)),
            ),
            SizedBox(height: r.s(24)),
            Text(
              '🎉 Match encontrado!',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: r.fs(22),
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: r.s(8)),
            Text(
              'Encontramos alguém com interesses em comum!\nVocês têm 24h para decidir se querem continuar.',
              style: TextStyle(
                  color: theme.textSecondary, fontSize: r.fs(14)),
              textAlign: TextAlign.center,
            ),
            if (_matchInterests.isNotEmpty) ...[
              SizedBox(height: r.s(16)),
              Text(
                'Interesses em comum:',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: r.s(8)),
              Wrap(
                spacing: r.s(6),
                runSpacing: r.s(6),
                alignment: WrapAlignment.center,
                children: _matchInterests
                    .map((i) => Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(10), vertical: r.s(4)),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(r.s(20)),
                          ),
                          child: Text(
                            i,
                            style: TextStyle(
                              color: const Color(0xFFFF6B6B),
                              fontSize: r.fs(12),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
            SizedBox(height: r.s(32)),
            Container(
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: theme.backgroundSecondary,
                borderRadius: BorderRadius.circular(r.s(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined,
                      color: theme.accentPrimary, size: r.s(18)),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Text(
                      'Este chat é temporário. Se nenhum dos dois cancelar em 24h, ele vira permanente.',
                      style: TextStyle(
                          color: theme.textSecondary, fontSize: r.fs(12)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(24)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _matchedThreadId != null
                    ? () => context.push('/chat/$_matchedThreadId')
                    : null,
                icon: Icon(Icons.chat_bubble_rounded,
                    color: Colors.white, size: r.s(18)),
                label: Text(
                  'Abrir Chat',
                  style: TextStyle(
                    fontSize: r.fs(16),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentPrimary,
                  padding: EdgeInsets.symmetric(vertical: r.s(16)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(14)),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueError(NexusThemeData theme, Responsive r) {
    return Center(
      key: const ValueKey('queue_error'),
      child: Padding(
        padding: EdgeInsets.all(r.s(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: theme.error, size: r.s(56)),
            SizedBox(height: r.s(16)),
            Text(
              _queueError ?? 'Erro desconhecido',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: r.fs(15),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.s(24)),
            if (_queueError?.contains('interesses') == true)
              ElevatedButton(
                onPressed: () => context.push('/edit-interests'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(12))),
                ),
                child: const Text('Adicionar Interesses',
                    style: TextStyle(color: Colors.white)),
              )
            else
              ElevatedButton(
                onPressed: () {
                  MatchQueueService.instance.clearError();
                  setState(() => _phase = _Phase.suggestions);
                  _loadSuggestions();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(12))),
                ),
                child: const Text('Tentar novamente',
                    style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  // ── Card de sugestão ──────────────────────────────────────────────────────
  Widget _buildMatchCard(
      MatchedUser user, NexusThemeData theme, Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: theme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/profile/${user.userId}'),
                child: CosmeticAvatar(
                  userId: user.userId,
                  imageUrl: user.iconUrl,
                  radius: r.s(24),
                ),
              ),
              SizedBox(width: r.s(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () =>
                          context.push('/profile/${user.userId}'),
                      child: Text(
                        user.nickname,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: r.fs(14),
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.statusEmoji != null || user.statusText != null)
                      Padding(
                        padding: EdgeInsets.only(top: r.s(2)),
                        child: UserStatusBadge(
                          emoji: user.statusEmoji,
                          text: user.statusText,
                          compact: false,
                        ),
                      )
                    else if (user.bio != null && user.bio!.isNotEmpty)
                      Text(
                        user.bio!,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: r.fs(12),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              SizedBox(width: r.s(8)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    icon: user.isFollowing
                        ? Icons.person_remove_rounded
                        : Icons.person_add_rounded,
                    label: user.isFollowing ? 'Seguindo' : 'Seguir',
                    color: user.isFollowing
                        ? theme.textSecondary
                        : theme.accentPrimary,
                    onTap: () => _toggleFollow(user),
                    r: r,
                  ),
                  SizedBox(width: r.s(6)),
                  _ActionButton(
                    icon: Icons.chat_bubble_rounded,
                    label: 'DM',
                    color: theme.accentSecondary,
                    onTap: () => _openDm(user),
                    r: r,
                  ),
                ],
              ),
            ],
          ),
          if (user.commonInterests.isNotEmpty) ...[
            SizedBox(height: r.s(10)),
            Row(
              children: [
                Icon(Icons.interests_rounded,
                    color: theme.accentPrimary, size: r.s(12)),
                SizedBox(width: r.s(4)),
                Text(
                  '${user.score} interesse${user.score > 1 ? 's' : ''} em comum:',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: r.fs(11),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: r.s(6)),
            Wrap(
              spacing: r.s(4),
              runSpacing: r.s(4),
              children: user.commonInterests
                  .take(5)
                  .map((interest) => Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(8), vertical: r.s(3)),
                        decoration: BoxDecoration(
                          color: theme.accentPrimary
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(r.s(20)),
                        ),
                        child: Text(
                          interest,
                          style: TextStyle(
                            color: theme.accentPrimary,
                            fontSize: r.fs(11),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Botão de ação compacto ────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Responsive r;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(6)),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(r.s(20)),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: r.s(13)),
            SizedBox(width: r.s(4)),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: r.fs(11),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
