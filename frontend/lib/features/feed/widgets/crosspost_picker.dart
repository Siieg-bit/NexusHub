import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

/// Picker de comunidade destino para Crosspost — estilo Amino.
///
/// Mostra uma lista das comunidades que o usuário é membro,
/// permitindo selecionar a comunidade destino para o crosspost.
class CrosspostPicker extends ConsumerStatefulWidget {
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
  ConsumerState<CrosspostPicker> createState() => _CrosspostPickerState();
}

class _CrosspostPickerState extends ConsumerState<CrosspostPicker> {
  List<Map<String, dynamic>> _communities = [];
  bool _loading = true;
  String? _loadError;

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
          .select(
              'community_id, communities!community_members_community_id_fkey(id, name, icon_url, members_count)')
          .eq('user_id', userId)
          .neq('community_id', widget.currentCommunityId);
      if (!mounted) return;

      final list = <Map<String, dynamic>>[];
      for (final item in ((result as List? ?? []))) {
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
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Container(
      margin: EdgeInsets.symmetric(vertical: r.s(8)),
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.share_rounded,
                  color: context.nexusTheme.accentSecondary, size: r.s(20)),
              SizedBox(width: r.s(8)),
              Text(
                'Crosspost para:',
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: r.fs(15),
                ),
              ),
              const Spacer(),
              if (widget.selectedCommunity != null)
                GestureDetector(
                  onTap: () => _showCommunityPicker(),
                  child: Text(
                    s.change,
                    style: TextStyle(
                      color: context.nexusTheme.accentSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: r.fs(13),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: r.s(12)),

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
    final s = ref.read(stringsProvider);
    final r = context.r;
    return Container(
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: context.nexusTheme.accentSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(color: context.nexusTheme.accentSecondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Community icon
          Container(
            width: r.s(40),
            height: r.s(40),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r.s(10)),
              color: context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
              image: community['icon_url'] != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(
                          community['icon_url'] as String? ?? ''),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: community['icon_url'] == null
                ? Icon(Icons.groups_rounded,
                    color: context.nexusTheme.accentSecondary, size: r.s(20))
                : null,
          ),
          SizedBox(width: r.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  community['name'] as String? ?? s.community,
                  style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(14),
                  ),
                ),
                Text(
                  '${community['members_count'] ?? 0} membros',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: r.fs(12),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded,
              color: context.nexusTheme.accentSecondary, size: r.s(22)),
        ],
      ),
    );
  }

  Widget _buildPickerButton() {
    final r = context.r;
    return GestureDetector(
      onTap: _showCommunityPicker,
      child: Container(
        padding: EdgeInsets.all(r.s(16)),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(
            color: context.nexusTheme.accentSecondary.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded,
                color: context.nexusTheme.accentSecondary, size: r.s(22)),
            SizedBox(width: r.s(8)),
            Text(
              'Selecionar comunidade destino',
              style: TextStyle(
                color: context.nexusTheme.accentSecondary,
                fontWeight: FontWeight.w600,
                fontSize: r.fs(14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommunityPicker() {
    final s = ref.read(stringsProvider);
    final r = context.r;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.nexusTheme.backgroundPrimary,
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
              margin: EdgeInsets.only(top: r.s(12), bottom: r.s(8)),
              width: r.s(40),
              height: r.s(4),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: EdgeInsets.all(r.s(16)),
              child: Text(
                'Selecionar Comunidade',
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: r.fs(18),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1A2A3A)),
            // List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: context.nexusTheme.accentSecondary))
                  : _loadError != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  size: r.s(48), color: Colors.redAccent),
                              SizedBox(height: r.s(12)),
                              Text(
                                'Erro ao carregar comunidades',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                              SizedBox(height: r.s(8)),
                              FilledButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _loading = true;
                                    _loadError = null;
                                  });
                                  _loadCommunities();
                                },
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(s.retry),
                              ),
                            ],
                          ),
                        )
                      : _communities.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.groups_rounded,
                                      size: r.s(48), color: Colors.grey[600]),
                                  SizedBox(height: r.s(12)),
                                  Text(
                                    'Nenhuma outra comunidade encontrada',
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                  SizedBox(height: r.s(4)),
                                  Text(
                                    'Entre em mais comunidades para fazer crosspost',
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: r.fs(12)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.all(r.s(16)),
                              itemCount: _communities.length,
                              itemBuilder: (_, index) {
                                final c = _communities[index];
                                return Container(
                                  margin: EdgeInsets.only(bottom: r.s(8)),
                                  decoration: BoxDecoration(
                                    color: context.surfaceColor,
                                    borderRadius:
                                        BorderRadius.circular(r.s(12)),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.05)),
                                  ),
                                  child: ListTile(
                                    onTap: () {
                                      widget.onCommunitySelected(c);
                                      Navigator.pop(ctx);
                                    },
                                    leading: Container(
                                      width: r.s(44),
                                      height: r.s(44),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(r.s(10)),
                                        color: context.nexusTheme.accentPrimary
                                            .withValues(alpha: 0.2),
                                        image: c['icon_url'] != null
                                            ? DecorationImage(
                                                image:
                                                    CachedNetworkImageProvider(
                                                        c['icon_url']
                                                                as String? ??
                                                            ''),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: c['icon_url'] == null
                                          ? Icon(Icons.groups_rounded,
                                              color: context.nexusTheme.accentSecondary,
                                              size: r.s(22))
                                          : null,
                                    ),
                                    title: Text(
                                      c['name'] as String? ?? '',
                                      style: TextStyle(
                                        color: context.nexusTheme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${c['members_count'] ?? 0} membros',
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: r.fs(12)),
                                    ),
                                    trailing: Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: r.s(16),
                                        color: context.nexusTheme.textHint),
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
