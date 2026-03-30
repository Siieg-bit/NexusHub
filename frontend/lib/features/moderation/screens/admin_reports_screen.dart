import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Tela de Relatórios do Admin — estatísticas reais de uso e moderação.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Estatísticas de uso
  int _totalUsers = 0;
  int _newUsersToday = 0;
  int _newUsersWeek = 0;
  int _totalPosts = 0;
  int _postsToday = 0;
  int _totalMessages = 0;
  int _messagesToday = 0;
  int _totalCommunities = 0;
  int _activeCommunities = 0;

  // Estatísticas de moderação
  int _totalFlags = 0;
  int _pendingFlags = 0;
  int _resolvedFlags = 0;
  int _bannedUsers = 0;
  List<Map<String, dynamic>> _recentFlags = [];

  // Estatísticas de gamificação
  int _totalCoinsCirculating = 0;
  int _totalCheckIns = 0;
  int _aminoPlusUsers = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadUsageStats(),
      _loadModerationStats(),
      _loadGamificationStats(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUsageStats() async {
    try {
      final now = DateTime.now().toUtc();
      final todayStart =
          DateTime(now.year, now.month, now.day).toIso8601String();
      final weekStart =
          now.subtract(const Duration(days: 7)).toIso8601String();

      final users =
          await SupabaseService.table('profiles').select('id').count();
      _totalUsers = users.count;

      final newToday = await SupabaseService.table('profiles')
          .select('id')
          .gte('created_at', todayStart)
          .count();
      _newUsersToday = newToday.count;

      final newWeek = await SupabaseService.table('profiles')
          .select('id')
          .gte('created_at', weekStart)
          .count();
      _newUsersWeek = newWeek.count;

      final posts =
          await SupabaseService.table('posts').select('id').count();
      _totalPosts = posts.count;

      final postsToday = await SupabaseService.table('posts')
          .select('id')
          .gte('created_at', todayStart)
          .count();
      _postsToday = postsToday.count;

      final messages =
          await SupabaseService.table('chat_messages').select('id').count();
      _totalMessages = messages.count;

      final msgsToday = await SupabaseService.table('chat_messages')
          .select('id')
          .gte('created_at', todayStart)
          .count();
      _messagesToday = msgsToday.count;

      final communities =
          await SupabaseService.table('communities').select('id').count();
      _totalCommunities = communities.count;

      final active = await SupabaseService.table('communities')
          .select('id')
          .eq('status', 'active')
          .count();
      _activeCommunities = active.count;
    } catch (e) {
      debugPrint('[AdminReports] Erro ao carregar uso: $e');
    }
  }

  Future<void> _loadModerationStats() async {
    try {
      final total =
          await SupabaseService.table('flags').select('id').count();
      _totalFlags = total.count;

      final pending = await SupabaseService.table('flags')
          .select('id')
          .eq('status', 'pending')
          .count();
      _pendingFlags = pending.count;

      final resolved = await SupabaseService.table('flags')
          .select('id')
          .eq('status', 'resolved')
          .count();
      _resolvedFlags = resolved.count;

      final banned = await SupabaseService.table('profiles')
          .select('id')
          .eq('is_banned', true)
          .count();
      _bannedUsers = banned.count;

      final recent = await SupabaseService.table('flags')
          .select('id, reason, status, created_at, reporter_id')
          .order('created_at', ascending: false)
          .limit(10);
      _recentFlags = List<Map<String, dynamic>>.from(recent as List);
    } catch (e) {
      debugPrint('[AdminReports] Erro ao carregar moderação: $e');
    }
  }

  Future<void> _loadGamificationStats() async {
    try {
      final checkIns =
          await SupabaseService.table('check_ins').select('id').count();
      _totalCheckIns = checkIns.count;

      final aminoPlus = await SupabaseService.table('profiles')
          .select('id')
          .eq('is_amino_plus', true)
          .count();
      _aminoPlusUsers = aminoPlus.count;

      // Total de coins em circulação
      final coinsData = await SupabaseService.table('profiles')
          .select('coin_balance');
      int total = 0;
      for (final row in (coinsData as List)) {
        total += (row['coin_balance'] as int? ?? 0);
      }
      _totalCoinsCirculating = total;
    } catch (e) {
      debugPrint('[AdminReports] Erro ao carregar gamificação: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          'Relatórios',
          style: TextStyle(
              color: context.textPrimary, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.textPrimary),
            onPressed: _loadAll,
            tooltip: 'Atualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Uso'),
            Tab(text: 'Moderação'),
            Tab(text: 'Gamificação'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUsageTab(r),
                _buildModerationTab(r),
                _buildGamificationTab(r),
              ],
            ),
    );
  }

  Widget _buildUsageTab(Responsive r) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(r.s(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Usuários', r),
          _statsGrid([
            _StatData('Total', _totalUsers.toString(), Icons.people_rounded,
                AppTheme.primaryColor),
            _StatData('Hoje', _newUsersToday.toString(),
                Icons.person_add_rounded, Colors.green),
            _StatData('Últimos 7 dias', _newUsersWeek.toString(),
                Icons.trending_up_rounded, Colors.orange),
            _StatData('Banidos', _bannedUsers.toString(),
                Icons.block_rounded, Colors.red),
          ], r),
          SizedBox(height: r.s(20)),
          _sectionTitle('Conteúdo', r),
          _statsGrid([
            _StatData('Posts totais', _totalPosts.toString(),
                Icons.article_rounded, AppTheme.accentColor),
            _StatData('Posts hoje', _postsToday.toString(),
                Icons.post_add_rounded, Colors.teal),
            _StatData('Mensagens totais', _totalMessages.toString(),
                Icons.chat_rounded, Colors.purple),
            _StatData('Mensagens hoje', _messagesToday.toString(),
                Icons.message_rounded, Colors.indigo),
          ], r),
          SizedBox(height: r.s(20)),
          _sectionTitle('Comunidades', r),
          _statsGrid([
            _StatData('Total', _totalCommunities.toString(),
                Icons.groups_rounded, Colors.amber),
            _StatData('Ativas', _activeCommunities.toString(),
                Icons.check_circle_rounded, Colors.green),
          ], r),
        ],
      ),
    );
  }

  Widget _buildModerationTab(Responsive r) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(r.s(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Denúncias', r),
          _statsGrid([
            _StatData('Total', _totalFlags.toString(),
                Icons.flag_rounded, Colors.orange),
            _StatData('Pendentes', _pendingFlags.toString(),
                Icons.pending_rounded, Colors.red),
            _StatData('Resolvidas', _resolvedFlags.toString(),
                Icons.check_circle_rounded, Colors.green),
            _StatData('Usuários banidos', _bannedUsers.toString(),
                Icons.block_rounded, Colors.red[900]!),
          ], r),
          SizedBox(height: r.s(20)),
          _sectionTitle('Denúncias Recentes', r),
          if (_recentFlags.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(r.s(24)),
                child: Text('Nenhuma denúncia recente',
                    style: TextStyle(color: Colors.grey[600])),
              ),
            )
          else
            ...(_recentFlags.map((flag) => _buildFlagTile(flag, r))),
        ],
      ),
    );
  }

  Widget _buildGamificationTab(Responsive r) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(r.s(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Economia', r),
          _statsGrid([
            _StatData('Coins em circulação',
                _totalCoinsCirculating.toString(),
                Icons.monetization_on_rounded, Colors.amber),
            _StatData('Assinantes Amino+', _aminoPlusUsers.toString(),
                Icons.star_rounded, AppTheme.primaryColor),
            _StatData('Check-ins totais', _totalCheckIns.toString(),
                Icons.calendar_today_rounded, Colors.teal),
          ], r),
          SizedBox(height: r.s(20)),
          _sectionTitle('Taxa de Monetização', r),
          Container(
            padding: EdgeInsets.all(r.s(16)),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(r.s(16)),
            ),
            child: Column(
              children: [
                _buildRateRow(
                  'Taxa Amino+',
                  _totalUsers > 0
                      ? (_aminoPlusUsers / _totalUsers * 100)
                          .toStringAsFixed(1)
                      : '0.0',
                  '%',
                  AppTheme.primaryColor,
                  r,
                ),
                SizedBox(height: r.s(12)),
                _buildRateRow(
                  'Coins por usuário (média)',
                  _totalUsers > 0
                      ? (_totalCoinsCirculating / _totalUsers)
                          .toStringAsFixed(0)
                      : '0',
                  'coins',
                  Colors.amber,
                  r,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagTile(Map<String, dynamic> flag, Responsive r) {
    final status = flag['status'] as String? ?? 'pending';
    final reason = flag['reason'] as String? ?? 'Sem motivo';
    final createdAt = flag['created_at'] as String?;
    final date = createdAt != null
        ? DateTime.tryParse(createdAt)?.toLocal()
        : null;
    final statusColor = status == 'pending'
        ? Colors.orange
        : status == 'resolved'
            ? Colors.green
            : Colors.grey;

    return Container(
      margin: EdgeInsets.only(bottom: r.s(8)),
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(12)),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, color: statusColor, size: r.s(20)),
          SizedBox(width: r.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason,
                  style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: r.fs(13)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (date != null)
                  Text(
                    '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: r.fs(11)),
                  ),
              ],
            ),
          ),
          Container(
            padding:
                EdgeInsets.symmetric(horizontal: r.s(8), vertical: r.s(4)),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(r.s(8)),
            ),
            child: Text(
              status,
              style: TextStyle(
                  color: statusColor,
                  fontSize: r.fs(11),
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateRow(String label, String value, String unit, Color color,
      Responsive r) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: context.textPrimary, fontSize: r.fs(14))),
        ),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                    color: color,
                    fontSize: r.fs(20),
                    fontWeight: FontWeight.w800),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                    color: Colors.grey[500], fontSize: r.fs(12)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, Responsive r) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.s(12)),
      child: Text(
        title,
        style: TextStyle(
          color: context.textPrimary,
          fontSize: r.fs(16),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _statsGrid(List<_StatData> stats, Responsive r) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: r.s(12),
      mainAxisSpacing: r.s(12),
      childAspectRatio: 1.6,
      children: stats.map((s) => _buildStatCard(s, r)).toList(),
    );
  }

  Widget _buildStatCard(_StatData stat, Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(stat.icon, color: stat.color, size: r.s(18)),
              const Spacer(),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.value,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: r.fs(22),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                stat.label,
                style: TextStyle(
                    color: Colors.grey[500], fontSize: r.fs(11)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatData(this.label, this.value, this.icon, this.color);
}
