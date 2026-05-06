import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ============================================================================
// MatchQueueScreen — Fila de matchmaking por interesse
//
// Fluxo:
//   1. Usuário entra na fila chamando enter_match_queue()
//   2. Se já houver alguém compatível, retorna status='matched' com thread_id
//   3. Caso contrário, status='waiting' — polling a cada 5s via get_match_queue_status()
//   4. Ao fazer match, navega para o chat temporário
// ============================================================================

class MatchQueueScreen extends ConsumerStatefulWidget {
  const MatchQueueScreen({super.key});

  @override
  ConsumerState<MatchQueueScreen> createState() => _MatchQueueScreenState();
}

class _MatchQueueScreenState extends ConsumerState<MatchQueueScreen>
    with TickerProviderStateMixin {
  // Estados possíveis: idle, entering, waiting, matched, error
  String _status = 'idle';
  String? _error;
  String? _matchedThreadId;
  List<String> _matchInterests = [];
  int _waitingSeconds = 0;

  late AnimationController _radarCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  Timer? _pollTimer;
  Timer? _waitTimer;

  @override
  void initState() {
    super.initState();
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

    // Verificar se já está em uma fila ou tem match ativo
    _checkCurrentStatus();
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    _pulseCtrl.dispose();
    _pollTimer?.cancel();
    _waitTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkCurrentStatus() async {
    try {
      final res = await SupabaseService.rpc('get_match_queue_status');
      final data = Map<String, dynamic>.from(res as Map);
      final status = data['status'] as String? ?? 'idle';
      if (!mounted) return;
      if (status == 'matched' || status == 'promoted') {
        setState(() {
          _status = 'matched';
          _matchedThreadId = data['thread_id'] as String?;
          _matchInterests = (data['match_interests'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
        });
      } else if (status == 'waiting') {
        setState(() => _status = 'waiting');
        _startPolling();
        _startWaitTimer();
      }
      // else idle — mostrar tela inicial
    } catch (e, st) {
      // Erro não crítico — apenas logar, não bloquear a tela
      debugPrint('[MatchQueue] checkCurrentStatus error: $e');
      debugPrint('[MatchQueue] checkCurrentStatus stacktrace: $st');
    }
  }

  Future<void> _enterQueue() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Verificar se tem interesses
    if (user.selectedInterests.isEmpty) {
      if (mounted) {
        _showNoInterestsDialog();
      }
      return;
    }

    setState(() {
      _status = 'entering';
      _error = null;
    });
    HapticService.action();

    try {
      final res = await SupabaseService.rpc('enter_match_queue');
      final data = Map<String, dynamic>.from(res as Map);
      final status = data['status'] as String? ?? 'waiting';

      if (!mounted) return;

      if (status == 'matched') {
        HapticService.success();
        setState(() {
          _status = 'matched';
          _matchedThreadId = data['thread_id'] as String?;
          _matchInterests = [];
        });
      } else {
        // waiting
        setState(() {
          _status = 'waiting';
          _waitingSeconds = 0;
        });
        _startPolling();
        _startWaitTimer();
      }
    } catch (e, st) {
      debugPrint('[MatchQueue] enterQueue error: $e');
      debugPrint('[MatchQueue] enterQueue stacktrace: $st');
      if (mounted) {
        // Extrair mensagem amigável do PostgrestException (P0001 = RAISE EXCEPTION do banco)
        final raw = e.toString();
        String userMsg;
        if (raw.contains('interesses')) {
          userMsg = 'Adicione interesses ao seu perfil antes de entrar na fila.';
        } else if (raw.contains('chat de match ativo') || raw.contains('match ativo')) {
          userMsg = 'Você já possui um chat de match ativo.';
        } else if (raw.contains('P0001')) {
          // Tentar extrair a mensagem do banco entre aspas ou após 'message:'
          final msgMatch = RegExp(r'message: ([^,}]+)').firstMatch(raw);
          userMsg = msgMatch?.group(1)?.trim() ?? 'Erro ao entrar na fila.';
        } else {
          userMsg = 'Erro ao entrar na fila. Tente novamente.';
        }
        setState(() {
          _status = 'error';
          _error = userMsg;
        });
      }
    }
  }

  Future<void> _leaveQueue() async {
    _pollTimer?.cancel();
    _waitTimer?.cancel();
    try {
      await SupabaseService.rpc('leave_match_queue');
    } catch (e) {
      debugPrint('[MatchQueue] leaveQueue error (non-critical): $e');
    }
    if (mounted) {
      setState(() {
        _status = 'idle';
        _waitingSeconds = 0;
        _error = null;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      try {
        final res = await SupabaseService.rpc('get_match_queue_status');
        final data = Map<String, dynamic>.from(res as Map);
        final status = data['status'] as String? ?? 'idle';
        if (!mounted) return;
        if (status == 'matched' || status == 'promoted') {
          _pollTimer?.cancel();
          _waitTimer?.cancel();
          HapticService.success();
          setState(() {
            _status = 'matched';
            _matchedThreadId = data['thread_id'] as String?;
            _matchInterests = (data['match_interests'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
          });
        } else if (status == 'idle') {
          // Saiu da fila por outro motivo
          _pollTimer?.cancel();
          _waitTimer?.cancel();
          if (mounted) setState(() => _status = 'idle');
        }
      } catch (e, st) {
        debugPrint('[MatchQueue] polling error: $e');
        debugPrint('[MatchQueue] polling stacktrace: $st');
      }
    });
  }

  void _startWaitTimer() {
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _waitingSeconds++);
    });
  }

  void _showNoInterestsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nexusTheme.backgroundSecondary,
        title: Text(
          'Interesses necessários',
          style: TextStyle(color: context.nexusTheme.textPrimary),
        ),
        content: Text(
          'Você precisa adicionar pelo menos 1 interesse ao seu perfil para entrar na fila de matchmaking.',
          style: TextStyle(color: context.nexusTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: TextStyle(color: context.nexusTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/edit-interests');
            },
            child: Text('Adicionar Interesses',
                style: TextStyle(color: context.nexusTheme.accentPrimary)),
          ),
        ],
      ),
    );
  }

  String _formatWaitTime() {
    final m = _waitingSeconds ~/ 60;
    final s = _waitingSeconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.nexusTheme;
    final r = context.r;

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: theme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
          onPressed: () async {
            if (_status == 'waiting') {
              await _leaveQueue();
            }
            if (mounted) context.pop();
          },
        ),
        title: Text(
          'Encontrar Pessoas',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: r.fs(17),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _buildBody(theme, r),
      ),
    );
  }

  Widget _buildBody(dynamic theme, Responsive r) {
    switch (_status) {
      case 'entering':
        return _buildLoadingState(theme, r);
      case 'waiting':
        return _buildWaitingState(theme, r);
      case 'matched':
        return _buildMatchedState(theme, r);
      case 'error':
        return _buildErrorState(theme, r);
      default:
        return _buildIdleState(theme, r);
    }
  }

  // ── Estado inicial ──────────────────────────────────────────────────────────
  Widget _buildIdleState(dynamic theme, Responsive r) {
    final user = ref.watch(currentUserProvider);
    final interests = user?.selectedInterests ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.s(24)),
      child: Column(
        children: [
          SizedBox(height: r.s(24)),
          // Ícone central
          Container(
            width: r.s(100),
            height: r.s(100),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [theme.accentPrimary, theme.accentSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.accentPrimary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(Icons.people_alt_rounded,
                color: Colors.white, size: r.s(48)),
          ),
          SizedBox(height: r.s(24)),
          Text(
            'Encontrar Pessoas',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: r.fs(22),
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: r.s(8)),
          Text(
            'Entre na fila e encontre alguém com os mesmos interesses que você. Se ambos ficarem confortáveis, o chat vira permanente em 24h!',
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: r.fs(14),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.s(24)),
          // Interesses do usuário
          if (interests.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(r.s(16)),
              decoration: BoxDecoration(
                color: theme.backgroundSecondary,
                borderRadius: BorderRadius.circular(r.s(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seus interesses (${interests.length})',
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
                    children: interests
                        .map((i) => Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: r.s(10), vertical: r.s(4)),
                              decoration: BoxDecoration(
                                color: theme.accentPrimary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(r.s(20)),
                              ),
                              child: Text(
                                i,
                                style: TextStyle(
                                  color: theme.accentPrimary,
                                  fontSize: r.fs(12),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(8)),
            GestureDetector(
              onTap: () => context.push('/edit-interests'),
              child: Text(
                'Editar interesses',
                style: TextStyle(
                  color: theme.accentPrimary,
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: EdgeInsets.all(r.s(16)),
              decoration: BoxDecoration(
                color: theme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.s(12)),
                border: Border.all(color: theme.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: theme.error, size: r.s(18)),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nenhum interesse cadastrado',
                          style: TextStyle(
                            color: theme.error,
                            fontSize: r.fs(13),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: r.s(4)),
                        GestureDetector(
                          onTap: () => context.push('/edit-interests'),
                          child: Text(
                            'Adicionar interesses →',
                            style: TextStyle(
                              color: theme.accentPrimary,
                              fontSize: r.fs(12),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: r.s(32)),
          // Como funciona
          _buildHowItWorks(theme, r),
          SizedBox(height: r.s(32)),
          // Botão entrar na fila
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: interests.isNotEmpty ? _enterQueue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentPrimary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: r.s(16)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(14)),
                ),
                elevation: 0,
              ),
              child: Text(
                'Entrar na Fila',
                style: TextStyle(
                  fontSize: r.fs(16),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks(dynamic theme, Responsive r) {
    final steps = [
      (Icons.queue_rounded, 'Entre na fila',
          'Você entra na fila com seus interesses'),
      (Icons.connect_without_contact_rounded, 'Match automático',
          'Encontramos alguém com interesses em comum'),
      (Icons.chat_bubble_rounded, 'Chat temporário',
          'Vocês têm 24h para decidir se querem continuar'),
      (Icons.favorite_rounded, 'Chat permanente',
          'Se ninguém cancelar, o chat vira permanente!'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Como funciona',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: r.fs(15),
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: r.s(12)),
        ...steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: r.s(12)),
            child: Row(
              children: [
                Container(
                  width: r.s(36),
                  height: r.s(36),
                  decoration: BoxDecoration(
                    color: theme.accentPrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(step.$1,
                      color: theme.accentPrimary, size: r.s(18)),
                ),
                SizedBox(width: r.s(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i + 1}. ${step.$2}',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        step.$3,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: r.fs(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Estado: entrando na fila ────────────────────────────────────────────────
  Widget _buildLoadingState(dynamic theme, Responsive r) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: theme.accentPrimary),
          SizedBox(height: r.s(16)),
          Text(
            'Entrando na fila...',
            style: TextStyle(color: theme.textSecondary, fontSize: r.fs(14)),
          ),
        ],
      ),
    );
  }

  // ── Estado: aguardando match ────────────────────────────────────────────────
  Widget _buildWaitingState(dynamic theme, Responsive r) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animação de radar
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
                        colors: [theme.accentPrimary, theme.accentSecondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accentPrimary.withValues(alpha: 0.4),
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
              color: theme.textSecondary,
              fontSize: r.fs(13),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.s(8)),
          Text(
            'Na fila há ${_formatWaitTime()}',
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: r.fs(12),
            ),
          ),
          SizedBox(height: r.s(32)),
          OutlinedButton.icon(
            onPressed: _leaveQueue,
            icon: Icon(Icons.exit_to_app_rounded,
                color: theme.error, size: r.s(16)),
            label: Text(
              'Sair da fila',
              style: TextStyle(color: theme.error, fontSize: r.fs(14)),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.error.withValues(alpha: 0.5)),
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(20), vertical: r.s(12)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Estado: match encontrado ────────────────────────────────────────────────
  Widget _buildMatchedState(dynamic theme, Responsive r) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.s(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone de match
            Container(
              width: r.s(100),
              height: r.s(100),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)],
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
                color: theme.textSecondary,
                fontSize: r.fs(14),
              ),
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
            // Aviso sobre o chat temporário
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
                        color: theme.textSecondary,
                        fontSize: r.fs(12),
                      ),
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

  // ── Estado: erro ────────────────────────────────────────────────────────────
  Widget _buildErrorState(dynamic theme, Responsive r) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.s(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: theme.error, size: r.s(56)),
            SizedBox(height: r.s(16)),
            Text(
              _error ?? 'Erro desconhecido',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: r.fs(15),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.s(24)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_error?.contains('interesses') == true)
                  ElevatedButton(
                    onPressed: () => context.push('/edit-interests'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.s(12)),
                      ),
                    ),
                    child: Text('Adicionar Interesses',
                        style: TextStyle(color: Colors.white)),
                  )
                else
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _status = 'idle';
                      _error = null;
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.s(12)),
                      ),
                    ),
                    child: Text('Tentar novamente',
                        style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
