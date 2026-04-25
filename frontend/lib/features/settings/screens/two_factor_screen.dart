import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Provider que carrega o status do 2FA do usuário.
final _twoFaStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final data = await SupabaseService.rpc('get_2fa_status');
  return Map<String, dynamic>.from(data as Map);
});

/// Hub central de configuração de 2FA.
class TwoFactorScreen extends ConsumerWidget {
  const TwoFactorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;
    final statusAsync = ref.watch(_twoFaStatusProvider);

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: r.s(20)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Verificação em 2 Etapas',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: r.s(18),
          ),
        ),
      ),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erro ao carregar: $e',
              style: TextStyle(color: theme.error)),
        ),
        data: (status) => _TwoFaBody(status: status, onRefresh: () => ref.refresh(_twoFaStatusProvider)),
      ),
    );
  }
}

class _TwoFaBody extends ConsumerWidget {
  final Map<String, dynamic> status;
  final VoidCallback onRefresh;

  const _TwoFaBody({required this.status, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;

    final totpEnabled  = status['totp_enabled']  as bool? ?? false;
    final phoneEnabled = status['phone_enabled']  as bool? ?? false;
    final phoneNumber  = status['phone_number']   as String?;
    final backupRemain = status['backup_codes_remaining'] as int? ?? 0;
    final hasBackup    = status['has_backup_codes'] as bool? ?? false;
    final anyEnabled   = totpEnabled || phoneEnabled;

    return ListView(
      padding: EdgeInsets.all(r.s(20)),
      children: [
        // ── Banner de status ─────────────────────────────
        Container(
          padding: EdgeInsets.all(r.s(16)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: anyEnabled
                  ? [const Color(0xFF00C853), const Color(0xFF1DE9B6)]
                  : [theme.surfacePrimary, theme.surfacePrimary],
            ),
            borderRadius: BorderRadius.circular(r.s(16)),
            border: anyEnabled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(r.s(10)),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: anyEnabled ? 0.2 : 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  anyEnabled ? Icons.verified_user_rounded : Icons.security_rounded,
                  color: anyEnabled ? Colors.white : theme.textSecondary,
                  size: r.s(24),
                ),
              ),
              SizedBox(width: r.s(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anyEnabled ? '2FA Ativado' : '2FA Desativado',
                      style: TextStyle(
                        color: anyEnabled ? Colors.white : theme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: r.s(16),
                      ),
                    ),
                    SizedBox(height: r.s(2)),
                    Text(
                      anyEnabled
                          ? 'Sua conta está protegida com verificação extra.'
                          : 'Ative para proteger sua conta contra acessos não autorizados.',
                      style: TextStyle(
                        color: anyEnabled
                            ? Colors.white.withValues(alpha: 0.85)
                            : theme.textSecondary,
                        fontSize: r.s(12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: r.s(24)),

        // ── Seção: Métodos de verificação ────────────────
        _SectionLabel(label: 'MÉTODOS DE VERIFICAÇÃO'),
        SizedBox(height: r.s(8)),

        // TOTP
        _TwoFaMethodCard(
          icon: Icons.qr_code_rounded,
          title: 'App Autenticador',
          subtitle: totpEnabled
              ? 'Ativo — Google Authenticator, Authy, etc.'
              : 'Use um app autenticador para gerar códigos TOTP',
          enabled: totpEnabled,
          onTap: () async {
            if (totpEnabled) {
              await _confirmDisableTotp(context);
              onRefresh();
            } else {
              await context.push('/settings/2fa/totp-setup');
              onRefresh();
            }
          },
          badgeLabel: totpEnabled ? 'Ativo' : null,
          badgeColor: const Color(0xFF00C853),
        ),

        SizedBox(height: r.s(12)),

        // SMS / Telefone
        _TwoFaMethodCard(
          icon: Icons.phone_android_rounded,
          title: 'Número de Telefone',
          subtitle: phoneEnabled && phoneNumber != null
              ? 'Ativo — ${_maskPhone(phoneNumber)}'
              : 'Receba um código por SMS ao fazer login',
          enabled: phoneEnabled,
          onTap: () async {
            if (phoneEnabled) {
              await _confirmDisablePhone(context);
              onRefresh();
            } else {
              await context.push('/settings/2fa/phone-setup');
              onRefresh();
            }
          },
          badgeLabel: phoneEnabled ? 'Ativo' : null,
          badgeColor: const Color(0xFF2979FF),
        ),

        SizedBox(height: r.s(24)),

        // ── Seção: Backup codes ──────────────────────────
        if (anyEnabled) ...[
          _SectionLabel(label: 'CÓDIGOS DE RECUPERAÇÃO'),
          SizedBox(height: r.s(8)),
          _BackupCodesCard(
            remaining: backupRemain,
            hasBackup: hasBackup,
            onRegenerate: () async {
              await context.push('/settings/2fa/backup-codes');
              onRefresh();
            },
          ),
          SizedBox(height: r.s(24)),
        ],

        // ── Seção: Informações ───────────────────────────
        _SectionLabel(label: 'COMO FUNCIONA'),
        SizedBox(height: r.s(8)),
        _InfoCard(
          items: const [
            _InfoItem(
              icon: Icons.login_rounded,
              title: 'No login',
              description: 'Após inserir e-mail e senha, você precisará confirmar sua identidade com um código extra.',
            ),
            _InfoItem(
              icon: Icons.lock_reset_rounded,
              title: 'Troca de e-mail ou senha',
              description: 'Operações sensíveis exigem verificação em 2 etapas quando o 2FA está ativo.',
            ),
            _InfoItem(
              icon: Icons.backup_rounded,
              title: 'Códigos de recuperação',
              description: 'Guarde os 8 códigos de recuperação em local seguro. Cada um pode ser usado uma única vez.',
            ),
          ],
        ),
      ],
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 6) return phone;
    return '${phone.substring(0, 3)}••••${phone.substring(phone.length - 3)}';
  }

  Future<void> _confirmDisableTotp(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
        title: Row(children: [
          Icon(Icons.warning_rounded, color: context.nexusTheme.error),
          const SizedBox(width: 8),
          const Text('Desativar App Autenticador',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        content: const Text(
          'Isso removerá o app autenticador da sua conta.\n\nSua conta ficará menos segura. Tem certeza?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: context.nexusTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desativar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.rpc('disable_totp_2fa');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App autenticador desativado.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDisablePhone(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
        title: Row(children: [
          Icon(Icons.warning_rounded, color: context.nexusTheme.error),
          const SizedBox(width: 8),
          const Text('Desativar SMS',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        content: const Text(
          'Isso removerá o número de telefone da verificação em 2 etapas. Tem certeza?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: context.nexusTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desativar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.rpc('disable_phone_2fa');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS desativado.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e')),
          );
        }
      }
    }
  }
}

// ── Widgets auxiliares ────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: context.nexusTheme.textSecondary,
        fontSize: context.r.s(11),
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _TwoFaMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
  final String? badgeLabel;
  final Color badgeColor;

  const _TwoFaMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.badgeLabel,
    this.badgeColor = Colors.green,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(r.s(16)),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(
            color: enabled
                ? badgeColor.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(r.s(10)),
              decoration: BoxDecoration(
                color: (enabled ? badgeColor : theme.textSecondary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(r.s(12)),
              ),
              child: Icon(icon,
                  color: enabled ? badgeColor : theme.textSecondary,
                  size: r.s(22)),
            ),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: r.s(15),
                          )),
                      if (badgeLabel != null) ...[
                        SizedBox(width: r.s(8)),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(8), vertical: r.s(2)),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(r.s(20)),
                          ),
                          child: Text(badgeLabel!,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: r.s(10),
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: r.s(3)),
                  Text(subtitle,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: r.s(12),
                      )),
                ],
              ),
            ),
            Icon(
              enabled
                  ? Icons.settings_rounded
                  : Icons.arrow_forward_ios_rounded,
              color: theme.textSecondary,
              size: r.s(16),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupCodesCard extends StatelessWidget {
  final int remaining;
  final bool hasBackup;
  final VoidCallback onRegenerate;

  const _BackupCodesCard({
    required this.remaining,
    required this.hasBackup,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    final isLow = remaining <= 2;

    return Container(
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(
          color: isLow
              ? Colors.orange.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(r.s(10)),
            decoration: BoxDecoration(
              color: (isLow ? Colors.orange : theme.accentPrimary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Icon(Icons.backup_rounded,
                color: isLow ? Colors.orange : theme.accentPrimary,
                size: r.s(22)),
          ),
          SizedBox(width: r.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Códigos de Recuperação',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: r.s(15),
                    )),
                SizedBox(height: r.s(3)),
                Text(
                  hasBackup
                      ? '$remaining de 8 códigos restantes'
                      : 'Nenhum código gerado ainda',
                  style: TextStyle(
                    color: isLow ? Colors.orange : theme.textSecondary,
                    fontSize: r.s(12),
                  ),
                ),
                if (isLow) ...[
                  SizedBox(height: r.s(4)),
                  Text('⚠️ Gere novos códigos antes que acabem.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: r.s(11),
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onRegenerate,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(12), vertical: r.s(6)),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  theme.accentPrimary,
                  theme.accentSecondary,
                ]),
                borderRadius: BorderRadius.circular(r.s(20)),
              ),
              child: Text(
                hasBackup ? 'Regenerar' : 'Gerar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.s(12),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String title;
  final String description;
  const _InfoItem({required this.icon, required this.title, required this.description});
}

class _InfoCard extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;

    return Container(
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: items.map((item) {
          final isLast = item == items.last;
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.icon,
                      color: theme.accentPrimary, size: r.s(18)),
                  SizedBox(width: r.s(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: r.s(13),
                            )),
                        SizedBox(height: r.s(2)),
                        Text(item.description,
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: r.s(12),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isLast) ...[
                SizedBox(height: r.s(12)),
                Divider(
                    color: Colors.white.withValues(alpha: 0.05), height: 1),
                SizedBox(height: r.s(12)),
              ],
            ],
          );
        }).toList(),
      ),
    );
  }
}
