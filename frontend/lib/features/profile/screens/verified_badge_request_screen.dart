import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/nexus_loading_button.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Provider para verificar o status da solicitação de verificação do usuário atual.
final verifiedBadgeRequestStatusProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return null;
  final res = await SupabaseService.table('verified_badge_requests')
      .select('id, status, reason, created_at, reviewer_note')
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  return res as Map<String, dynamic>?;
});

/// Tela de solicitação de Verified Badge (selo de verificação de nickname).
class VerifiedBadgeRequestScreen extends ConsumerStatefulWidget {
  const VerifiedBadgeRequestScreen({super.key});

  @override
  ConsumerState<VerifiedBadgeRequestScreen> createState() =>
      _VerifiedBadgeRequestScreenState();
}

class _VerifiedBadgeRequestScreenState
    extends ConsumerState<VerifiedBadgeRequestScreen> {
  final _reasonController = TextEditingController();
  final _linksController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _linksController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor, descreva o motivo da solicitação.'),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final linksRaw = _linksController.text.trim();
      final links = linksRaw.isEmpty
          ? <String>[]
          : linksRaw
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();

      await SupabaseService.client.rpc('submit_verified_badge_request', params: {
        'p_reason': reason,
        'p_links': links,
      });

      HapticService.success();
      if (mounted) {
        ref.invalidate(verifiedBadgeRequestStatusProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Solicitação enviada! Aguarde a análise da equipe.'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      HapticService.error();
      if (mounted) {
        String msg = 'Erro ao enviar solicitação. Tente novamente.';
        if (e.toString().contains('already_pending')) {
          msg = 'Você já tem uma solicitação pendente.';
        } else if (e.toString().contains('already_verified')) {
          msg = 'Seu nickname já está verificado!';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final statusAsync = ref.watch(verifiedBadgeRequestStatusProvider);

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
          tooltip: 'Voltar',
        ),
        title: Row(
          children: [
            Icon(
              Icons.verified_rounded,
              color: context.nexusTheme.accentSecondary,
              size: r.s(22),
            ),
            SizedBox(width: r.s(8)),
            Text(
              'Verificação de Nickname',
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(17),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Erro ao carregar status.',
            style: TextStyle(color: context.nexusTheme.error),
          ),
        ),
        data: (existingRequest) {
          // Se já tem solicitação pendente ou aprovada, mostrar status
          if (existingRequest != null) {
            final status = existingRequest['status'] as String? ?? 'pending';
            return _buildStatusView(r, status, existingRequest);
          }
          // Formulário de nova solicitação
          return _buildForm(r);
        },
      ),
    );
  }

  Widget _buildStatusView(
      Responsive r, String status, Map<String, dynamic> request) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusTitle;
    final String statusSubtitle;

    switch (status) {
      case 'approved':
        statusColor = Colors.green[600]!;
        statusIcon = Icons.verified_rounded;
        statusTitle = 'Solicitação Aprovada!';
        statusSubtitle =
            'Parabéns! Seu nickname agora está verificado no NexusHub.';
        break;
      case 'rejected':
        statusColor = context.nexusTheme.error;
        statusIcon = Icons.cancel_rounded;
        statusTitle = 'Solicitação Recusada';
        statusSubtitle = request['reviewer_note'] != null
            ? 'Motivo: ${request['reviewer_note']}'
            : 'Sua solicitação foi recusada pela equipe.';
        break;
      default:
        statusColor = Colors.amber[600]!;
        statusIcon = Icons.hourglass_top_rounded;
        statusTitle = 'Solicitação em Análise';
        statusSubtitle =
            'Sua solicitação está sendo analisada pela equipe. Aguarde.';
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.s(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(r.s(24)),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: r.s(48)),
            ),
            SizedBox(height: r.s(20)),
            Text(
              statusTitle,
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(20),
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.s(10)),
            Text(
              statusSubtitle,
              style: TextStyle(
                color: context.nexusTheme.textSecondary,
                fontSize: r.fs(14),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (status == 'rejected') ...[
              SizedBox(height: r.s(24)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.nexusTheme.accentPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(12)),
                  ),
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(24), vertical: r.s(12)),
                ),
                onPressed: () {
                  // Permitir nova solicitação após rejeição
                  ref.invalidate(verifiedBadgeRequestStatusProvider);
                },
                child: Text(
                  'Enviar nova solicitação',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.fs(14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForm(Responsive r) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(r.s(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header informativo
          Container(
            padding: EdgeInsets.all(r.s(16)),
            decoration: BoxDecoration(
              color: context.nexusTheme.accentSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(
                color: context.nexusTheme.accentSecondary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: context.nexusTheme.accentSecondary,
                      size: r.s(18),
                    ),
                    SizedBox(width: r.s(8)),
                    Text(
                      'O que é o Verified Badge?',
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.s(8)),
                Text(
                  'O selo de verificação confirma que seu nickname é autêntico e pertence a uma pessoa, marca ou organização de destaque na comunidade. A aprovação é feita pela equipe do NexusHub.',
                  style: TextStyle(
                    color: context.nexusTheme.textSecondary,
                    fontSize: r.fs(13),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.s(24)),

          // Campo de motivo
          Text(
            'Por que você merece ser verificado? *',
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(14),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: r.s(8)),
          TextField(
            controller: _reasonController,
            maxLines: 5,
            maxLength: 1000,
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(14),
            ),
            decoration: InputDecoration(
              hintText:
                  'Descreva sua relevância na comunidade, conquistas, seguidores, etc.',
              hintStyle: TextStyle(
                color: context.nexusTheme.textSecondary.withValues(alpha: 0.6),
                fontSize: r.fs(13),
              ),
              filled: true,
              fillColor: context.nexusTheme.backgroundSecondary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(12)),
                borderSide: BorderSide(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(12)),
                borderSide: BorderSide(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(12)),
                borderSide: BorderSide(
                  color: context.nexusTheme.accentPrimary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          SizedBox(height: r.s(16)),

          // Campo de links (opcional)
          Text(
            'Links de referência (opcional)',
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(14),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: r.s(4)),
          Text(
            'Um link por linha (redes sociais, portfólio, etc.)',
            style: TextStyle(
              color: context.nexusTheme.textSecondary,
              fontSize: r.fs(12),
            ),
          ),
          SizedBox(height: r.s(8)),
          TextField(
            controller: _linksController,
            maxLines: 3,
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(14),
            ),
            decoration: InputDecoration(
              hintText: 'https://instagram.com/seu_perfil\nhttps://...',
              hintStyle: TextStyle(
                color: context.nexusTheme.textSecondary.withValues(alpha: 0.6),
                fontSize: r.fs(13),
              ),
              filled: true,
              fillColor: context.nexusTheme.backgroundSecondary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(12)),
                borderSide: BorderSide(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(12)),
                borderSide: BorderSide(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(12)),
                borderSide: BorderSide(
                  color: context.nexusTheme.accentPrimary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          SizedBox(height: r.s(32)),

          // Botão de envio
          NexusLoadingButton(
            label: 'Enviar Solicitação',
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
          SizedBox(height: r.s(16)),
          Text(
            'Ao enviar, você concorda que a equipe do NexusHub analisará sua solicitação e poderá aprová-la ou recusá-la sem obrigação de justificativa detalhada.',
            style: TextStyle(
              color: context.nexusTheme.textSecondary.withValues(alpha: 0.6),
              fontSize: r.fs(11),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
