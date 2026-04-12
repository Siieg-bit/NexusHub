import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/utils/responsive.dart';
import '../providers/profile_providers.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// =============================================================================
// LINKED COMMUNITIES SECTION
// =============================================================================

class ProfileLinkedCommunities extends ConsumerWidget {
  final String userId;
  const ProfileLinkedCommunities({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final communitiesAsync = ref.watch(userLinkedCommunitiesProvider(userId));

    return communitiesAsync.when(
      loading: () => Padding(
        padding: EdgeInsets.all(r.s(16)),
        child: SizedBox(
          height: r.s(20),
          width: r.s(20),
          child: CircularProgressIndicator(
              color: context.nexusTheme.accentSecondary, strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (communities) {
        if (communities.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), r.s(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Linked Communities',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: r.s(10)),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: communities.map((community) {
                  return GestureDetector(
                    onTap: () => context.push('/community/${community.id}'),
                    child: SizedBox(
                      width: (MediaQuery.of(context).size.width - 48) / 2,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(r.s(8)),
                            child: community.iconUrl != null &&
                                    community.iconUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: community.iconUrl ?? '',
                                    width: r.s(32),
                                    height: r.s(32),
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _communityPlaceholder(
                                            context, community),
                                  )
                                : _communityPlaceholder(context, community),
                          ),
                          SizedBox(width: r.s(8)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  community.name,
                                  style: TextStyle(
                                    color: context.nexusTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: r.fs(13),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (community.endpoint != null)
                                  Text(
                                    'ID:${community.endpoint}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: r.fs(10),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _communityPlaceholder(BuildContext context, CommunityModel community) {
    final r = context.r;
    return Container(
      width: r.s(32),
      height: r.s(32),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(8)),
      ),
      child: Center(
        child: Text(
          community.name.isNotEmpty ? community.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: r.fs(14),
          ),
        ),
      ),
    );
  }
}
