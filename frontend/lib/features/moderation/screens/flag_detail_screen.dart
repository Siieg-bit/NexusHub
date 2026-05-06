import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ============================================================================
// FLAG DETAIL SCREEN
// Exibe os detalhes completos de uma denúncia, incluindo:
// • Snapshot imutável do conteúdo (mesmo após exclusão)
// • Resultado da análise do bot de moderação
// • Histórico de ações do bot
// • Botões de ação para staff (aprovar/rejeitar + ação sobre conteúdo)
// ============================================================================
class FlagDetailScreen extends ConsumerStatefulWidget {
  final String flagId;
  const FlagDetailScreen({super.key, required this.flagId});

  @override
  ConsumerState<FlagDetailScreen> createState() => _FlagDetailScreenState();
}

class _FlagDetailScreenState extends ConsumerState<FlagDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _isLoading = true;
  bool _isActing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    debugPrint('[FlagDetail] _load() flagId=${widget.flagId}');
    try {
      debugPrint('[FlagDetail] chamando get_flag_detail...');
      final result = await SupabaseService.rpc('get_flag_detail', params: {
        'p_flag_id': widget.flagId,
      });
      debugPrint('[FlagDetail] result runtimeType=${result.runtimeType}');
      debugPrint('[FlagDetail] result=$result');
      if (mounted) {
        setState(() {
          _detail = result as Map<String, dynamic>?;
          _isLoading = false;
        });
        debugPrint('[FlagDetail] ✅ _detail carregado. keys=${_detail?.keys.toList()}');
      }
    } catch (e, stack) {
      debugPrint('[FlagDetail] ❌ _load ERROR: $e');
      debugPrint('[FlagDetail] stack: $stack');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resolve(String action, {
    String? note,
    bool moderateContent = false,
    String? moderateAction,
  }) async {
    final s = getStrings();
    debugPrint('[FlagDetail] _resolve() flagId=${widget.flagId} action=$action moderateContent=$moderateContent moderateAction=$moderateAction note=$note');
    setState(() => _isActing = true);
    try {
      final resolveResult = await SupabaseService.rpc('resolve_flag', params: {
        'p_flag_id':          widget.flagId,
        'p_action':           action,
        'p_resolution_note':  note,
        'p_moderate_content': moderateContent,
        'p_moderate_action':  moderateAction,
      });
      debugPrint('[FlagDetail] ✅ resolve_flag result=$resolveResult');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'approved'
                ? 'Denúncia aprovada e ação tomada'
                : 'Denúncia rejeitada'),
            backgroundColor: action == 'approved'
                ? context.nexusTheme.error
                : context.nexusTheme.success,
          ),
        );
        Navigator.pop(context, true); // retorna true para atualizar a lista
      }
    } catch (e, stack) {
      debugPrint('[FlagDetail] ❌ _resolve ERROR: $e');
      debugPrint('[FlagDetail] stack: $stack');
      if (mounted) {
        // Extrair mensagem real do erro para facilitar diagnóstico
        String errorMsg = s.anErrorOccurredTryAgain;
        if (e is PostgrestException) {
          final detail = e.message.isNotEmpty ? e.message : (e.code ?? 'erro desconhecido');
          debugPrint('[FlagDetail] PostgrestException code=${e.code} message=${e.message} details=${e.details}');
          errorMsg = 'Erro: $detail';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  void _showResolveDialog(String action) {
    // Determinar o tipo de conteúdo denunciado a partir do snapshot ou da flag
    final snap = _detail?['snapshot'] as Map<String, dynamic>?;
    final flag = _detail?['flag'] as Map<String, dynamic>? ?? {};
    final contentType = (snap?['content_type'] as String?)?.trim() ?? '';

    // Derivar tipo a partir dos campos target_* da flag quando snapshot não tem content_type
    final String resolvedType;
    if (contentType.isNotEmpty) {
      resolvedType = contentType;
    } else if ((flag['target_comment_id'] as String?) != null) {
      resolvedType = 'comment';
    } else if ((flag['target_chat_message_id'] as String?) != null) {
      resolvedType = 'chat_message';
    } else if ((flag['target_post_id'] as String?) != null) {
      resolvedType = 'post';
    } else if ((flag['target_user_id'] as String?) != null) {
      resolvedType = 'user';
    } else {
      resolvedType = 'post'; // fallback
    }

    final noteController = TextEditingController();
    bool moderateContent = false;
    String? moderateAction;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final r = ctx.r;

          // ── Chips contextuais por tipo de conteúdo ──────────────────────
          List<Widget> contentActionChips() {
            switch (resolvedType) {
              case 'post':
                return [
                  _ActionChip(
                    label: 'Apenas registrar',
                    selected: !moderateContent,
                    onTap: () => setS(() { moderateContent = false; moderateAction = null; }),
                  ),
                  SizedBox(height: r.s(6)),
                  _ActionChip(
                    label: 'Desabilitar post',
                    selected: moderateContent && moderateAction == 'delete_content',
                    color: ctx.nexusTheme.error,
                    onTap: () => setS(() { moderateContent = true; moderateAction = 'delete_content'; }),
                  ),
                  SizedBox(height: r.s(6)),
                  _ActionChip(
                    label: 'Advertir usuário',
                    selected: moderateContent && moderateAction == 'warn',
                    color: ctx.nexusTheme.warning,
                    onTap: () => setS(() { moderateContent = true; moderateAction = 'warn'; }),
                  ),
                  SizedBox(height: r.s(6)),
                  _ActionChip(
                    label: 'Banir usuário',
                    selected: moderateContent && moderateAction == 'ban',
                    color: ctx.nexusTheme.error,
                    onTap: () => setS(() { moderateContent = true; moderateAction = 'ban'; }),
                  ),
                ];
              case 'comment':
                return [
                  _ActionChip(
                    label: 'Apenas registrar',
                    selected: !moderateContent,
                    onTap: () => setS(() { moderateContent = false; moderateAction = null; }),
                  ),
                  SizedBox(height: r.s(6)),
                  _ActionChip(
                    label: 'Deletar comentário',
                    selected: moderateContent && moderateAction == 'delete_comment',
                    color: ctx.nexusTheme.error,
                    onTap: () => setS(() { moderateContent = true; moderateAction = 'delete_comment'; }),
                  ),
                  SizedBox(height: r.s(6)),
                  _ActionChip(
                    label: 'Advertir usuário',
                    selected: moderateContent && moderateAction == 'warn',
                    color: ctx.nexusTheme.warning,
                    onTap: () => setS(() { moderateContent = true; moderateAction = 'warn'; }),
                  ),
                  SizedBox(height: r.s(6)),
                  _ActionChip(
                    label: 'Silenciar usuário',
                    selected: moderateContent && moderateAction == 'silence_member',
                    color: ctx.nexusTheme.warning,
                    onTap: () => setS(() { moderateContent = true; moderateAction = 'silence_member'; }),
                  ),
                ];
              case 'chat_message':
                return [
                  _ActionChip(
                    label: 'Apenas registrar',
                    selected: !moderateContent,
                    onTap: () => setS(() { moderateContent = false; moderateAction = null; }),
                  ),
                  SizedBox(height: r.s(6)),
                  _ActionChip(
                    label: 'Remover mensagem',
                    selected: moderateContent && moderateAction == 'delete_chat_message',
                    color: ctx.nexusTheme.error,
                    onTap: () => setS(() { moderateContent = true; moderateAction = 'delete_chat_message'; }),
                  ),
                  SizedBox(height: r.s(6)),
                  _ActionChip(
                    label: 'Silenciar usuário',
                    selected: moderateContent && moderateAction == 'silence_member',
                    color: ctx.nexusTheme.warning,
                    onTap: () => setS(() { moderateContent = true; moderateAction = 'silence_member'; }),
                  ),
                  SizedBox(height: r.s(6)),
                  _ActionChip(
                    label: 'Banir usuário',
                    selected: moderateContent && moderateAction == 'ban',
                    color: ctx.nexusTheme.error,
                    onTap: () => setS(() { moderateContent = true; moderateAction = 'ban'; }),
                  ),
                ];
              case 'user':
                return [
                  _ActionChip(
                    label: 'Apenas registrar',
                    selected: !moderateContent,
                    onTap: () => setS(() { moderateContent = false; moderateAction = null; }),
                  ),
                  SizedBox(height: r.s(6)),
                  _ActionChip(
                    label: 'Advertir usuário',
                    selected: moderateContent && moderateAction == 'warn',
                    color: ctx.nexusTheme.warning,
                    onTap: () => setS(() { moderateContent = true; moderateAction = 'warn'; }),
                  ),
                  SizedBox(height: r.s(6)),
                  _ActionChip(
                    label: 'Silenciar usuário',
                    selected: moderateContent && moderateAction == 'silence_member',
                    color: ctx.nexusTheme.warning,
                    onTap: () => setS(() { moderateContent = true; moderateAction = 'silence_member'; }),
                  ),
                  SizedBox(height: r.s(6)),
                  _ActionChip(
                    label: 'Banir usuário',
                    selected: moderateContent && moderateAction == 'ban',
                    color: ctx.nexusTheme.error,
                    onTap: () => setS(() { moderateContent = true; moderateAction = 'ban'; }),
                  ),
                ];
              default: // wiki, story, etc.
                return [
                  _ActionChip(
                    label: 'Apenas registrar',
                    selected: !moderateContent,
                    onTap: () => setS(() { moderateContent = false; moderateAction = null; }),
                  ),
                  SizedBox(height: r.s(6)),
                  _ActionChip(
                    label: 'Remover conteúdo',
                    selected: moderateContent && moderateAction == 'delete_content',
                    color: ctx.nexusTheme.error,
                    onTap: () => setS(() { moderateContent = true; moderateAction = 'delete_content'; }),
                  ),
                  SizedBox(height: r.s(6)),
                  _ActionChip(
                    label: 'Advertir usuário',
                    selected: moderateContent && moderateAction == 'warn',
                    color: ctx.nexusTheme.warning,
                    onTap: () => setS(() { moderateContent = true; moderateAction = 'warn'; }),
                  ),
                ];
            }
          }

          return AlertDialog(
            backgroundColor: ctx.surfaceColor,
            title: Text(
              action == 'approved' ? 'Tomar Ação' : 'Rejeitar Denúncia',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Nota de resolução (opcional)',
                      filled: true,
                      fillColor: ctx.cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(r.s(10)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (action == 'approved') ...[
                    SizedBox(height: r.s(16)),
                    Text('Ação sobre o conteúdo:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: r.fs(13))),
                    SizedBox(height: r.s(8)),
                    ...contentActionChips(),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: action == 'approved'
                      ? context.nexusTheme.error
                      : context.nexusTheme.success,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _resolve(
                    action,
                    note: noteController.text.trim().isNotEmpty
                        ? noteController.text.trim()
                        : null,
                    moderateContent: moderateContent,
                    moderateAction: moderateAction,
                  );
                },
                child: Text(action == 'approved' ? 'Confirmar Ação' : 'Rejeitar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: context.nexusTheme.backgroundPrimary,
          title: const Text('Detalhes da Denúncia'),
        ),
        body: SafeArea(
          bottom: true,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null || _detail == null) {
      return Scaffold(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: context.nexusTheme.backgroundPrimary,
          title: const Text('Detalhes da Denúncia'),
        ),
        body: Center(
          child: Text(_error ?? 'Erro ao carregar denúncia',
              style: TextStyle(color: context.nexusTheme.textSecondary)),
        ),
      );
    }

    final flag     = _detail!['flag']     as Map<String, dynamic>;
    final snapshot = _detail!['snapshot'] as Map<String, dynamic>?;
    final botActions = (_detail!['bot_actions'] as List?) ?? [];
    final isPending  = flag['status'] == 'pending';
    final reporter   = flag['reporter'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        title: const Text('Detalhes da Denúncia'),
        actions: [
          if (isPending) ...[
            TextButton(
              onPressed: _isActing ? null : () => _showResolveDialog('rejected'),
              child: Text('Rejeitar',
                  style: TextStyle(color: context.nexusTheme.textSecondary)),
            ),
            Padding(
              padding: EdgeInsets.only(right: r.s(8)),
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: context.nexusTheme.error),
                onPressed: _isActing ? null : () => _showResolveDialog('approved'),
                child: const Text('Tomar Ação'),
              ),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status badge ──
            _StatusBanner(flag: flag),
            SizedBox(height: r.s(16)),

            // ── Informações da denúncia ──
            _SectionCard(
              title: 'Denúncia',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: 'Tipo', value: _flagTypeLabel(flag['flag_type'] as String? ?? '')),
                  if ((flag['reason'] as String?)?.isNotEmpty == true)
                    _InfoRow(label: 'Motivo', value: flag['reason'] as String),
                  _InfoRow(
                    label: 'Data',
                    value: _formatDate(flag['created_at'] as String?),
                  ),
                  if (reporter != null) ...[
                    SizedBox(height: r.s(8)),
                    Row(
                      children: [
                        CosmeticAvatar(
                          userId: reporter['id'] as String?,
                          avatarUrl: reporter['avatar'] as String?,
                          size: r.s(28),
                        ),
                        SizedBox(width: r.s(8)),
                        Text(
                          'Denunciado por: ${reporter['nickname'] ?? 'Anônimo'}',
                          style: TextStyle(
                            color: context.nexusTheme.textSecondary,
                            fontSize: r.fs(13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: r.s(12)),

            // ── Snapshot do conteúdo ──
            if (snapshot != null) ...[
              _SnapshotCard(snapshot: snapshot),
              SizedBox(height: r.s(12)),
            ] else ...[
              _SectionCard(
                title: 'Conteúdo Denunciado',
                child: Text(
                  'Snapshot não disponível para este conteúdo.',
                  style: TextStyle(
                      color: context.nexusTheme.textSecondary, fontSize: r.fs(13)),
                ),
              ),
              SizedBox(height: r.s(12)),
            ],

            // ── Análise do bot ──
            if (flag['bot_verdict'] != null) ...[
              _BotAnalysisCard(flag: flag),
              SizedBox(height: r.s(12)),
            ],

            // ── Histórico de ações do bot ──
            if (botActions.isNotEmpty) ...[
              _SectionCard(
                title: 'Histórico do Bot (${botActions.length})',
                child: Column(
                  children: botActions.map((a) {
                    final action = a as Map<String, dynamic>;
                    return _BotActionTile(action: action);
                  }).toList(),
                ),
              ),
              SizedBox(height: r.s(12)),
            ],

            // ── Botões de ação (mobile-friendly) ──
            if (isPending) ...[
              SizedBox(height: r.s(8)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isActing
                          ? null
                          : () => _showResolveDialog('rejected'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: r.s(14)),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Text('Rejeitar',
                          style: TextStyle(color: context.nexusTheme.textSecondary)),
                    ),
                  ),
                  SizedBox(width: r.s(12)),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isActing
                          ? null
                          : () => _showResolveDialog('approved'),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.nexusTheme.error,
                        padding: EdgeInsets.symmetric(vertical: r.s(14)),
                      ),
                      child: _isActing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Tomar Ação'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.s(32)),
            ],
          ],
        ),
      ),
    );
  }

  String _flagTypeLabel(String type) {
    const labels = {
      'spam':         'Spam',
      'hate_speech':  'Discurso de Ódio',
      'harassment':   'Assédio',
      'art_theft':    'Roubo de Arte',
      'nsfw':         'Conteúdo Adulto',
      'misinformation': 'Desinformação',
      'other':        'Outro',
    };
    return labels[type] ?? type;
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ============================================================================
// WIDGETS AUXILIARES
// ============================================================================

class _StatusBanner extends StatelessWidget {
  final Map<String, dynamic> flag;
  const _StatusBanner({required this.flag});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final status = flag['status'] as String? ?? 'pending';
    final autoActioned = flag['auto_actioned'] as bool? ?? false;

    Color color;
    String label;
    IconData icon;

    if (autoActioned) {
      color = context.nexusTheme.error;
      label = 'Removido automaticamente pelo Bot';
      icon = Icons.smart_toy_rounded;
    } else {
      switch (status) {
        case 'pending':
          color = context.nexusTheme.warning;
          label = 'Aguardando revisão';
          icon = Icons.hourglass_empty_rounded;
          break;
        case 'approved':
          color = context.nexusTheme.error;
          label = 'Ação tomada';
          icon = Icons.gavel_rounded;
          break;
        case 'rejected':
          color = context.nexusTheme.success;
          label = 'Denúncia rejeitada (conteúdo ok)';
          icon = Icons.check_circle_rounded;
          break;
        default:
          color = Colors.grey;
          label = status;
          icon = Icons.info_rounded;
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(10)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(r.s(10)),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: r.s(18)),
          SizedBox(width: r.s(8)),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: r.fs(13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: r.fs(13),
              color: context.nexusTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: r.s(10)),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(bottom: r.s(4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: r.s(80),
            child: Text(
              label,
              style: TextStyle(
                color: context.nexusTheme.textSecondary,
                fontSize: r.fs(12),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(13),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  final Map<String, dynamic> snapshot;
  const _SnapshotCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final data = snapshot['snapshot_data'] as Map<String, dynamic>? ?? {};
    final type = snapshot['content_type'] as String? ?? '';
    final botVerdict = snapshot['bot_verdict'] as String?;
    final botScore = snapshot['bot_score'] as num?;
    final hasError = data.containsKey('error');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(
          color: hasError
              ? context.nexusTheme.warning.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: r.s(14), vertical: r.s(10)),
            decoration: BoxDecoration(
              color: hasError
                  ? context.nexusTheme.warning.withValues(alpha: 0.08)
                  : context.nexusTheme.accentPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(r.s(12)),
                topRight: Radius.circular(r.s(12)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasError
                      ? Icons.warning_rounded
                      : Icons.camera_alt_rounded,
                  size: r.s(16),
                  color: hasError
                      ? context.nexusTheme.warning
                      : context.nexusTheme.accentPrimary,
                ),
                SizedBox(width: r.s(6)),
                Text(
                  hasError
                      ? 'Snapshot parcial — conteúdo excluído antes da captura'
                      : 'Snapshot do Conteúdo (${_typeLabel(type)})',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(12),
                    color: hasError
                        ? context.nexusTheme.warning
                        : context.nexusTheme.accentPrimary,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                if (botVerdict != null)
                  _BotVerdictBadge(verdict: botVerdict, score: botScore),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(r.s(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasError) ...[
                  Text(
                    data['note'] as String? ??
                        'O conteúdo foi excluído antes do snapshot ser capturado.',
                    style: TextStyle(
                      color: context.nexusTheme.warning,
                      fontSize: r.fs(13),
                    ),
                  ),
                ] else ...[
                  // Autor
                  if (data['author_nickname'] != null ||
                      data['sender_nickname'] != null) ...[
                    Row(
                      children: [
                        _SnapshotAvatar(
                          avatarUrl: (data['author_avatar'] ?? data['sender_avatar']) as String?,
                          size: r.s(28),
                        ),
                        SizedBox(width: r.s(8)),
                        Text(
                          data['author_nickname'] as String? ??
                              data['sender_nickname'] as String? ??
                              'Desconhecido',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: r.fs(13),
                          ),
                        ),
                        SizedBox(width: r.s(8)),
                        Text(
                          _formatDate(
                              data['created_at'] as String?),
                          style: TextStyle(
                            color: context.nexusTheme.textSecondary,
                            fontSize: r.fs(11),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.s(10)),
                  ],

                  // Título (posts)
                  if ((data['title'] as String?)?.isNotEmpty == true) ...[
                    Text(
                      data['title'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(15),
                      ),
                    ),
                    SizedBox(height: r.s(6)),
                  ],

                  // Corpo / conteúdo
                  if ((data['body'] as String?)?.isNotEmpty == true)
                    Text(
                      data['body'] as String,
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(14),
                        height: 1.4,
                      ),
                    ),
                  if ((data['content'] as String?)?.isNotEmpty == true)
                    Text(
                      data['content'] as String,
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(14),
                        height: 1.4,
                      ),
                    ),

                  // Conteúdo de texto de story
                  if (type == 'story' &&
                      (data['text_content'] as String?)?.isNotEmpty == true) ...[  
                    SizedBox(height: r.s(6)),
                    Text(
                      data['text_content'] as String,
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(14),
                        height: 1.4,
                      ),
                    ),
                  ],
                  // Imagem de capa (wiki)
                  if ((data['cover_image_url'] as String?)?.isNotEmpty == true) ...[  
                    SizedBox(height: r.s(10)),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(r.s(8)),
                      child: CachedNetworkImage(
                        imageUrl: data['cover_image_url'] as String,
                        width: double.infinity,
                        height: r.s(140),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  // Mídia de story
                  if (type == 'story' &&
                      (data['media_url'] as String?)?.isNotEmpty == true) ...[  
                    SizedBox(height: r.s(10)),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(r.s(8)),
                      child: CachedNetworkImage(
                        imageUrl: data['media_url'] as String,
                        width: double.infinity,
                        height: r.s(200),
                        fit: BoxFit.cover,
                        errorWidget: (ctx, url, err) => Container(
                          height: r.s(200),
                          color: Colors.black26,
                          child: const Center(
                            child: Icon(Icons.broken_image_rounded,
                                color: Colors.white54),
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Imagens
                  if ((data['image_urls'] as List?)?.isNotEmpty == true) ...[
                    SizedBox(height: r.s(10)),
                    SizedBox(
                      height: r.s(120),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount:
                            (data['image_urls'] as List).length,
                        separatorBuilder: (_, __) =>
                            SizedBox(width: r.s(8)),
                        itemBuilder: (ctx, i) {
                          final url =
                              (data['image_urls'] as List)[i] as String;
                          return ClipRRect(
                            borderRadius:
                                BorderRadius.circular(r.s(8)),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              width: r.s(120),
                              height: r.s(120),
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],

                // Data de captura
                SizedBox(height: r.s(10)),
                Text(
                  'Capturado em: ${_formatDate(snapshot['captured_at'] as String?)}',
                  style: TextStyle(
                    color: context.nexusTheme.textSecondary,
                    fontSize: r.fs(11),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    const m = {
      'post': 'Post',
      'comment': 'Comentário',
      'chat_message': 'Mensagem de Chat',
      'profile': 'Perfil',
      'wiki': 'Wiki',
      'story': 'Story',
    };
    return m[type] ?? type;
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _BotVerdictBadge extends StatelessWidget {
  final String verdict;
  final num? score;
  const _BotVerdictBadge({required this.verdict, this.score});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    Color color;
    String label;
    switch (verdict) {
      case 'clean':
        color = context.nexusTheme.success;
        label = 'Limpo';
        break;
      case 'suspicious':
        color = context.nexusTheme.warning;
        label = 'Suspeito';
        break;
      case 'auto_removed':
        color = context.nexusTheme.error;
        label = 'Auto-removido';
        break;
      case 'escalated':
        color = context.nexusTheme.accentPrimary;
        label = 'Escalado';
        break;
      default:
        color = Colors.grey;
        label = verdict;
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.s(8), vertical: r.s(3)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(r.s(8)),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        score != null
            ? '$label (${(score! * 100).toStringAsFixed(0)}%)'
            : label,
        style: TextStyle(
          color: color,
          fontSize: r.fs(10),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BotAnalysisCard extends StatelessWidget {
  final Map<String, dynamic> flag;
  const _BotAnalysisCard({required this.flag});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final verdict = flag['bot_verdict'] as String? ?? '';
    final score = flag['bot_score'] as num?;

    Color verdictColor;
    switch (verdict) {
      case 'clean':
        verdictColor = context.nexusTheme.success;
        break;
      case 'suspicious':
        verdictColor = context.nexusTheme.warning;
        break;
      case 'auto_removed':
        verdictColor = context.nexusTheme.error;
        break;
      default:
        verdictColor = context.nexusTheme.accentPrimary;
    }

    return Container(
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: verdictColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(color: verdictColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_rounded,
                  color: verdictColor, size: r.s(18)),
              SizedBox(width: r.s(8)),
              Text(
                'Análise do Bot',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: r.fs(13),
                  color: verdictColor,
                ),
              ),
              const Spacer(),
              _BotVerdictBadge(verdict: verdict, score: score),
            ],
          ),
          if (score != null) ...[
            SizedBox(height: r.s(10)),
            ClipRRect(
              borderRadius: BorderRadius.circular(r.s(4)),
              child: LinearProgressIndicator(
                value: score.toDouble(),
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(verdictColor),
                minHeight: r.s(6),
              ),
            ),
            SizedBox(height: r.s(4)),
            Text(
              'Confiança: ${(score * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: context.nexusTheme.textSecondary,
                fontSize: r.fs(11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BotActionTile extends StatelessWidget {
  final Map<String, dynamic> action;
  const _BotActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final verdict = action['verdict'] as String? ?? '';
    final reasoning = action['reasoning'] as String?;
    final createdAt = action['created_at'] as String?;

    Color color;
    switch (verdict) {
      case 'clean':         color = context.nexusTheme.success; break;
      case 'suspicious':    color = context.nexusTheme.warning; break;
      case 'auto_removed':  color = context.nexusTheme.error;   break;
      default:              color = context.nexusTheme.accentPrimary;
    }

    return Container(
      margin: EdgeInsets.only(bottom: r.s(8)),
      padding: EdgeInsets.all(r.s(10)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(r.s(8)),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_rounded, size: r.s(14), color: color),
              SizedBox(width: r.s(6)),
              Text(
                action['action_type'] as String? ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: r.fs(12),
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(createdAt),
                style: TextStyle(
                  color: context.nexusTheme.textSecondary,
                  fontSize: r.fs(10),
                ),
              ),
            ],
          ),
          if (reasoning?.isNotEmpty == true) ...[
            SizedBox(height: r.s(6)),
            Text(
              reasoning!,
              style: TextStyle(
                color: context.nexusTheme.textSecondary,
                fontSize: r.fs(12),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  const _ActionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final c = color ?? context.nexusTheme.accentPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(12), vertical: r.s(8)),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.12) : context.nexusTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(8)),
          border: Border.all(
            color: selected
                ? c.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: r.s(16),
              color: selected ? c : context.nexusTheme.textSecondary,
            ),
            SizedBox(width: r.s(8)),
            Text(
              label,
              style: TextStyle(
                color: selected ? c : context.nexusTheme.textPrimary,
                fontSize: r.fs(13),
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Avatar estático do snapshot — exibe apenas o avatar salvo no momento da denúncia,
// sem buscar o perfil atual do usuário (evita mostrar frame/avatar atualizados).
class _SnapshotAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double size;
  const _SnapshotAvatar({this.avatarUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: context.nexusTheme.surfaceSecondary,
      backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
          ? CachedNetworkImageProvider(avatarUrl!)
          : null,
      child: avatarUrl == null || avatarUrl!.isEmpty
          ? Icon(Icons.person_rounded,
              size: size * 0.55,
              color: context.nexusTheme.textSecondary)
          : null,
    );
  }
}
