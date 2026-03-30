import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/utils/responsive.dart';

/// Flag Center — Centro de denúncias para Leaders/Curators.
/// Permite revisar denúncias (Art Theft, Bullying, etc.) e tomar ações.
class FlagCenterScreen extends StatefulWidget {
  final String communityId;
  const FlagCenterScreen({super.key, required this.communityId});

  @override
  State<FlagCenterScreen> createState() => _FlagCenterScreenState();
}

class _FlagCenterScreenState extends State<FlagCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _pendingFlags = [];
  List<Map<String, dynamic>> _resolvedFlags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFlags();
  }

  Future<void> _loadFlags() async {
    try {
      final pending = await SupabaseService.table('flags')
          .select('*, profiles!flags_reporter_id_fkey(*)')
          .eq('community_id', widget.communityId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      _pendingFlags = List<Map<String, dynamic>>.from(pending as List?);

      final resolved = await SupabaseService.table('flags')
          .select('*, profiles!flags_reporter_id_fkey(*)')
          .eq('community_id', widget.communityId)
          .neq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(50);
      _resolvedFlags = List<Map<String, dynamic>>.from(resolved as List?);

      if (!mounted) return;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveFlag(String flagId, String action) async {
    try {
      await SupabaseService.table('flags').update({
        'status': action,
        'resolved_by': SupabaseService.currentUserId,
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', flagId);
      await _loadFlags();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocorreu um erro. Tente novamente.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Flag Center',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: context.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: AppTheme.primaryColor,
          dividerColor: Colors.white.withValues(alpha: 0.05),
          tabs: [
            Tab(text: 'Pendentes (${_pendingFlags.length})'),
            const Tab(text: 'Resolvidas'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFlagList(_pendingFlags, isPending: true),
                _buildFlagList(_resolvedFlags, isPending: false),
              ],
            ),
    );
  }

  Widget _buildFlagList(List<Map<String, dynamic>> flags,
      {required bool isPending}) {

      final r = context.r;
    if (flags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.check_circle_rounded : Icons.history_rounded,
              size: r.s(64),
              color: Colors.grey[600],
            ),
            SizedBox(height: r.s(16)),
            Text(
              isPending
                  ? 'Nenhuma denúncia pendente'
                  : 'Nenhuma denúncia resolvida',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: r.fs(16),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFlags,
      color: AppTheme.primaryColor,
      backgroundColor: context.surfaceColor,
      child: ListView.builder(
        padding: EdgeInsets.all(r.s(16)),
        itemCount: flags.length,
        itemBuilder: (context, index) {
          final flag = flags[index];
          return _FlagCard(
            flag: flag,
            isPending: isPending,
            onApprove: () => _resolveFlag(flag['id'], 'approved'),
            onReject: () => _resolveFlag(flag['id'], 'rejected'),
          );
        },
      ),
    );
  }
}

class _FlagCard extends StatelessWidget {
  final Map<String, dynamic> flag;
  final bool isPending;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _FlagCard({
    required this.flag,
    required this.isPending,
    required this.onApprove,
    required this.onReject,
  });

  Color _flagTypeColor(String type) {
    switch (type) {
      case 'bullying':
        return AppTheme.errorColor;
      case 'art_theft':
        return AppTheme.warningColor;
      case 'inappropriate_content':
        return Colors.purpleAccent;
      case 'spam':
        return Colors.amber;
      case 'off_topic':
        return AppTheme.accentColor;
      default:
        return Colors.grey[500]!;
    }
  }

  String _flagTypeLabel(String type) {
    switch (type) {
      case 'bullying':
        return 'Bullying';
      case 'art_theft':
        return 'Art Theft';
      case 'inappropriate_content':
        return 'Conteúdo Impróprio';
      case 'spam':
        return 'Spam';
      case 'off_topic':
        return 'Off-Topic';
      default:
        return 'Outro';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final type = flag['type'] as String? ?? 'other';
    final reason = flag['reason'] as String? ?? '';
    final reporter = flag['profiles'] as Map<String, dynamic>?;
    final status = flag['status'] as String? ?? 'pending';

    return Container(
      margin: EdgeInsets.only(bottom: r.s(16)),
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(
          color: isPending
              ? AppTheme.warningColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: isPending
            ? [
                BoxShadow(
                  color: AppTheme.warningColor.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(4)),
                decoration: BoxDecoration(
                  color: _flagTypeColor(type).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.s(12)),
                  border: Border.all(
                    color: _flagTypeColor(type).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _flagTypeLabel(type),
                  style: TextStyle(
                    color: _flagTypeColor(type),
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (!isPending)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(4)),
                  decoration: BoxDecoration(
                    color: status == 'approved'
                        ? AppTheme.primaryColor.withValues(alpha: 0.15)
                        : AppTheme.errorColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(r.s(12)),
                    border: Border.all(
                      color: status == 'approved'
                          ? AppTheme.primaryColor.withValues(alpha: 0.3)
                          : AppTheme.errorColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    status == 'approved' ? 'Aprovada' : 'Rejeitada',
                    style: TextStyle(
                      color: status == 'approved'
                          ? AppTheme.primaryColor
                          : AppTheme.errorColor,
                      fontSize: r.fs(12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: r.s(16)),
          // Reporter
          Row(
            children: [
              CosmeticAvatar(
                userId: reporter?['id'] as String?,
                avatarUrl: reporter?['avatar_url'] as String?,
                size: r.s(32),
              ),
              SizedBox(width: r.s(12)),
              Expanded(
                child: Text(
                  'Reportado por ${reporter?['nickname'] ?? 'Anônimo'}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            SizedBox(height: r.s(12)),
            Text(
              reason,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: r.fs(14),
                height: 1.4,
              ),
            ),
          ],
          // Ações
          if (isPending) ...[
            SizedBox(height: r.s(16)),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onReject,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: r.s(12)),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(r.s(20)),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Rejeitar',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(14),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: r.s(12)),
                Expanded(
                  child: GestureDetector(
                    onTap: onApprove,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: r.s(12)),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.errorColor,
                            AppTheme.errorColor.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(r.s(20)),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.errorColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Tomar Ação',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
