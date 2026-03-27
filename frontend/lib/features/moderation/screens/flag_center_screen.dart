import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

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
      _pendingFlags = List<Map<String, dynamic>>.from(pending as List);

      final resolved = await SupabaseService.table('flags')
          .select('*, profiles!flags_reporter_id_fkey(*)')
          .eq('community_id', widget.communityId)
          .neq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(50);
      _resolvedFlags = List<Map<String, dynamic>>.from(resolved as List);

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
          SnackBar(content: Text('Erro: $e')),
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
      appBar: AppBar(
        title: const Text('Flag Center',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: [
            Tab(text: 'Pendentes (${_pendingFlags.length})'),
            const Tab(text: 'Resolvidas'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
    if (flags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.check_circle_rounded : Icons.history_rounded,
              size: 64,
              color: AppTheme.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              isPending
                  ? 'Nenhuma denúncia pendente'
                  : 'Nenhuma denúncia resolvida',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFlags,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
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
        return Colors.red;
      case 'art_theft':
        return Colors.orange;
      case 'inappropriate_content':
        return Colors.purple;
      case 'spam':
        return Colors.amber;
      case 'off_topic':
        return Colors.blue;
      default:
        return AppTheme.textSecondary;
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
    final type = flag['type'] as String? ?? 'other';
    final reason = flag['reason'] as String? ?? '';
    final reporter = flag['profiles'] as Map<String, dynamic>?;
    final status = flag['status'] as String? ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending
              ? AppTheme.warningColor.withValues(alpha: 0.3)
              : AppTheme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _flagTypeColor(type).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _flagTypeLabel(type),
                  style: TextStyle(
                    color: _flagTypeColor(type),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (!isPending)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status == 'approved'
                        ? AppTheme.successColor.withValues(alpha: 0.15)
                        : AppTheme.errorColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status == 'approved' ? 'Aprovada' : 'Rejeitada',
                    style: TextStyle(
                      color: status == 'approved'
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Reporter
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: reporter?['avatar_url'] != null
                    ? CachedNetworkImageProvider(
                        reporter!['avatar_url'] as String)
                    : null,
                child: reporter?['avatar_url'] == null
                    ? const Icon(Icons.person_rounded, size: 14)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                'Reportado por ${reporter?['nickname'] ?? 'Anônimo'}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(reason, style: const TextStyle(fontSize: 13)),
          ],
          // Ações
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.dividerColor),
                    ),
                    child: const Text('Rejeitar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                    ),
                    child: const Text('Tomar Ação'),
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
