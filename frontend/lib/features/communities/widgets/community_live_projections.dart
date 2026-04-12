import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/amino_animations.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

// =============================================================================
// LIVE PROJECTIONS SECTION
// Exibe chats públicos com projeção de tela ativa (is_screen_room_enabled = true
// e status = 'active'). Aparece acima das abas na tela da comunidade.
// Fica oculto quando não há projeções ativas.
// =============================================================================

class CommunityLiveProjections extends ConsumerStatefulWidget {
  final String communityId;

  const CommunityLiveProjections({
    super.key,
    required this.communityId,
  });

  @override
  ConsumerState<CommunityLiveProjections> createState() =>
      _CommunityLiveProjectionsState();
}

class _CommunityLiveProjectionsState extends ConsumerState<CommunityLiveProjections> {
  List<Map<String, dynamic>> _projections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProjections();
  }

  Future<void> _loadProjections() async {
    try {
      final response = await SupabaseService.table('chat_threads')
          .select()
          .eq('community_id', widget.communityId)
          .eq('type', 'public')
          .eq('is_screen_room_enabled', true)
          .order('members_count', ascending: false)
          .limit(10);
      if (mounted) {
        setState(() {
          _projections =
              List<Map<String, dynamic>>.from(response as List? ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[community_live_projections] Erro: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    if (_loading || _projections.isEmpty) return const SizedBox.shrink();

    final r = context.r;

    return Padding(
      padding: EdgeInsets.only(
          left: r.s(12), right: r.s(12), top: r.s(4), bottom: r.s(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho ──────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(bottom: r.s(8)),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(6), vertical: r.s(2)),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(r.s(6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: r.s(6),
                        height: r.s(6),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: r.s(4)),
                      Text(
                        'AO VIVO',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: r.fs(9),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: r.s(8)),
                Expanded(
                  child: Text(
                    'Projeções em Andamento',
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // ── Lista horizontal de cards ───────────────────────────────────
          SizedBox(
            height: r.s(130),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _projections.length,
              itemBuilder: (context, index) {
                final chat = _projections[index];
                final membersCount = chat['members_count'] as int? ?? 0;

                return AminoAnimations.cardPress(
                  onTap: () => context.push('/chat/${chat['id']}'),
                  child: Container(
                    width: r.s(160),
                    margin: EdgeInsets.only(right: r.s(8)),
                    decoration: BoxDecoration(
                      color: context.nexusTheme.surfacePrimary,
                      borderRadius: BorderRadius.circular(r.s(12)),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(r.s(12))),
                                child: chat['background_url'] != null
                                    ? CachedNetworkImage(
                                        imageUrl:
                                            chat['background_url'] as String,
                                        fit: BoxFit.cover,
                                      )
                                    : chat['icon_url'] != null
                                        ? CachedNetworkImage(
                                            imageUrl:
                                                chat['icon_url'] as String,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            color: Colors.red
                                                .withValues(alpha: 0.15),
                                            child: Icon(Icons.cast_rounded,
                                                color: Colors.red
                                                    .withValues(alpha: 0.6),
                                                size: r.s(28)),
                                          ),
                              ),
                              // Overlay escuro
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(r.s(12))),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.4),
                                    ],
                                  ),
                                ),
                              ),
                              // Badge AO VIVO
                              Positioned(
                                top: r.s(6),
                                left: r.s(6),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(5), vertical: r.s(2)),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(r.s(4)),
                                  ),
                                  child: Text(
                                    'AO VIVO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: r.fs(8),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              // Badge de membros
                              Positioned(
                                top: r.s(6),
                                right: r.s(6),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(5), vertical: r.s(2)),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius:
                                        BorderRadius.circular(r.s(10)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.people_rounded,
                                          color: Colors.white, size: r.s(10)),
                                      SizedBox(width: r.s(3)),
                                      Text(
                                        '$membersCount',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: r.fs(9),
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Título
                        Padding(
                          padding: EdgeInsets.all(r.s(8)),
                          child: Text(
                            chat['title'] as String? ?? s.projection,
                            style: TextStyle(
                                color: context.nexusTheme.textPrimary,
                                fontSize: r.fs(11),
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
