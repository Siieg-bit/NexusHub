import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Picker de comunidade destino para Crosspost — estilo Amino.
///
/// Mostra uma lista das comunidades que o usuário é membro,
/// permitindo selecionar a comunidade destino para o crosspost.
class CrosspostPicker extends StatefulWidget {
  /// ID da comunidade de origem (será excluída da lista).
  final String currentCommunityId;

  /// Callback quando uma comunidade é selecionada.
  final ValueChanged<Map<String, dynamic>> onCommunitySelected;

  /// Comunidade atualmente selecionada (se houver).
  final Map<String, dynamic>? selectedCommunity;

  const CrosspostPicker({
    super.key,
    required this.currentCommunityId,
    required this.onCommunitySelected,
    this.selectedCommunity,
  });

  @override
  State<CrosspostPicker> createState() => _CrosspostPickerState();
}

class _CrosspostPickerState extends State<CrosspostPicker> {
  List<Map<String, dynamic>> _communities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  Future<void> _loadCommunities() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      // Buscar comunidades que o usuário é membro
      final result = await SupabaseService.table('community_members')
          .select('community_id, communities!community_members_community_id_fkey(id, name, icon_url, members_count)')
          .eq('user_id', userId)
          .neq('community_id', widget.currentCommunityId);

      final list = <Map<String, dynamic>>[];
      for (final item in (result as List)) {
        final community = item['communities'] as Map<String, dynamic>?;
        if (community != null) {
          list.add(Map<String, dynamic>.from(community));
        }
      }

      if (mounted) {
        setState(() {
          _communities = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.share_rounded, color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Crosspost para:',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (widget.selectedCommunity != null)
                GestureDetector(
                  onTap: () => _showCommunityPicker(),
                  child: Text(
                    'Alterar',
                    style: TextStyle(
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Selected community or picker button
          if (widget.selectedCommunity != null)
            _buildSelectedCommunity(widget.selectedCommunity!)
          else
            _buildPickerButton(),
        ],
      ),
    );
  }

  Widget _buildSelectedCommunity(Map<String, dynamic> community) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Community icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              image: community['icon_url'] != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(
                          community['icon_url'] as String),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: community['icon_url'] == null
                ? const Icon(Icons.groups_rounded,
                    color: AppTheme.accentColor, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  community['name'] as String? ?? 'Comunidade',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${community['members_count'] ?? 0} membros',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded,
              color: AppTheme.accentColor, size: 22),
        ],
      ),
    );
  }

  Widget _buildPickerButton() {
    return GestureDetector(
      onTap: _showCommunityPicker,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.accentColor.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded,
                color: AppTheme.accentColor, size: 22),
            const SizedBox(width: 8),
            Text(
              'Selecionar comunidade destino',
              style: TextStyle(
                color: AppTheme.accentColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommunityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Selecionar Comunidade',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1A2A3A)),
            // List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.accentColor))
                  : _communities.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.groups_rounded,
                                  size: 48, color: Colors.grey[600]),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhuma outra comunidade encontrada',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Entre em mais comunidades para fazer crosspost',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _communities.length,
                          itemBuilder: (_, index) {
                            final c = _communities[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: ListTile(
                                onTap: () {
                                  widget.onCommunitySelected(c);
                                  Navigator.pop(ctx);
                                },
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.2),
                                    image: c['icon_url'] != null
                                        ? DecorationImage(
                                            image:
                                                CachedNetworkImageProvider(
                                                    c['icon_url'] as String),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: c['icon_url'] == null
                                      ? const Icon(Icons.groups_rounded,
                                          color: AppTheme.accentColor,
                                          size: 22)
                                      : null,
                                ),
                                title: Text(
                                  c['name'] as String? ?? '',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${c['members_count'] ?? 0} membros',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 12),
                                ),
                                trailing: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: AppTheme.textHint),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
