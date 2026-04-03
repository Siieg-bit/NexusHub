import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/supabase_service.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/interest_wizard_screen.dart';
import '../features/chat/screens/chat_list_screen.dart';
import '../features/chat/screens/chat_room_screen.dart';
import '../features/communities/screens/community_detail_screen.dart';
import '../features/communities/screens/my_community_chats_screen.dart';
import '../features/communities/screens/community_info_screen.dart';
import '../features/communities/screens/community_list_screen.dart';
import '../features/communities/screens/create_community_screen.dart';
import '../features/communities/screens/community_members_screen.dart';
import '../features/communities/screens/acm_screen.dart';
import '../features/explore/screens/explore_screen.dart';
import '../features/feed/screens/create_post_screen.dart';
import '../features/feed/screens/create_blog_screen.dart';
import '../features/feed/screens/create_image_post_screen.dart';
import '../features/feed/screens/create_link_post_screen.dart';
import '../features/feed/screens/create_poll_screen.dart';
import '../features/feed/screens/create_quiz_screen.dart';
import '../features/feed/screens/create_question_screen.dart';
import '../features/feed/screens/global_feed_screen.dart';
import '../features/feed/screens/post_detail_screen.dart';
import '../features/gamification/screens/check_in_screen.dart';
import '../features/gamification/screens/leaderboard_screen.dart';
import '../features/gamification/screens/wallet_screen.dart';
import '../features/gamification/screens/achievements_screen.dart';
import '../features/gamification/screens/inventory_screen.dart';
import '../features/moderation/screens/flag_center_screen.dart';
import '../features/moderation/screens/admin_panel_screen.dart';
import '../features/moderation/screens/moderation_actions_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/profile/screens/community_profile_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/privacy_settings_screen.dart';
import '../features/settings/screens/notification_settings_screen.dart';
import '../features/settings/screens/blocked_users_screen.dart';
import '../features/settings/screens/devices_screen.dart';
import '../features/settings/screens/app_permissions_screen.dart';
import '../features/settings/screens/privacy_policy_screen.dart';
import '../features/settings/screens/terms_of_use_screen.dart';
import '../features/settings/screens/linked_accounts_screen.dart';
import '../features/explore/screens/search_screen.dart';
import '../features/profile/screens/user_wall_screen.dart';
import '../features/profile/screens/followers_screen.dart';
import '../features/store/screens/store_screen.dart';
import '../features/store/screens/coin_shop_screen.dart';
import '../features/gamification/screens/free_coins_screen.dart';
import '../features/chat/screens/call_screen.dart';
import '../features/chat/screens/create_group_chat_screen.dart';
import '../features/chat/screens/create_public_chat_screen.dart';
import '../core/services/call_service.dart';
import '../features/wiki/screens/wiki_screen.dart';
import '../features/wiki/screens/wiki_curator_review_screen.dart';
import '../features/communities/screens/shared_folder_screen.dart';
import '../features/communities/screens/community_search_screen.dart';
import '../features/communities/screens/community_general_links_screen.dart';
import '../features/moderation/screens/edit_guidelines_screen.dart';
import '../features/moderation/screens/admin_reports_screen.dart';
import '../features/live/screens/screening_room_screen.dart';
import '../features/stories/screens/create_story_screen.dart';
import '../features/feed/screens/drafts_screen.dart';
import '../features/profile/screens/edit_community_profile_screen.dart';
import 'shell_screen.dart';
import '../features/stories/screens/story_viewer_screen.dart';

/// Router principal do app com GoRouter.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation:
        SupabaseService.isAuthenticated ? '/explore' : '/onboarding',
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isAuth = auth.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/onboarding' ||
          state.matchedLocation == '/interest-wizard';

      if (!isAuth && !isAuthRoute) return '/onboarding';
      if (isAuth &&
          isAuthRoute &&
          state.matchedLocation != '/interest-wizard') {
        return '/explore';
      }
      return null;
    },
    routes: [
      // ====================================================================
      // ROTAS DE AUTENTICAÇÃO
      // ====================================================================
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/interest-wizard',
        name: 'interest-wizard',
        builder: (context, state) => const InterestWizardScreen(),
      ),

      // ====================================================================
      // SHELL (BOTTOM NAVIGATION — 4 TABS: Descubra, Comunidades, Chats, Loja)
      // ====================================================================
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          // DISCOVER (tab 0)
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const ExploreScreen(),
          ),
          GoRoute(
            path: '/explore',
            name: 'explore',
            builder: (context, state) => const ExploreScreen(),
          ),
          // COMMUNITIES (tab 1)
          GoRoute(
            path: '/communities',
            name: 'communities',
            builder: (context, state) => const CommunityListScreen(),
          ),
          // CHATS (tab 2)
          GoRoute(
            path: '/chats',
            name: 'chats',
            builder: (context, state) => const ChatListScreen(),
          ),
          // STORE (tab 3)
          GoRoute(
            path: '/store',
            name: 'store',
            builder: (context, state) => const StoreScreen(),
          ),
          GoRoute(
            path: '/story-viewer',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return StoryViewerScreen(
                stories: (extra['stories'] as List<dynamic>? ?? [])
                    .cast<Map<String, dynamic>>(),
                authorProfile:
                    extra['authorProfile'] as Map<String, dynamic>? ?? {},
              );
            },
          ),
        ],
      ),

      // ====================================================================
      // ROTAS DE COMUNIDADE
      // ====================================================================
      GoRoute(
        path: '/community/create',
        name: 'create-community',
        builder: (context, state) => const CreateCommunityScreen(),
      ),
      GoRoute(
        path: '/community/:id',
        name: 'community-detail',
        builder: (context, state) => CommunityDetailScreen(
          communityId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/community/:communityId/acm',
        name: 'acm',
        builder: (context, state) => AcmScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/screening-room/:threadId',
        builder: (ctx, state) => ScreeningRoomScreen(
          threadId: state.pathParameters['threadId']!,
          callSessionId: state.uri.queryParameters['sessionId'],
        ),
      ),
      GoRoute(
        path: '/community/:communityId/shared-folder',
        builder: (ctx, state) => SharedFolderScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/community/:communityId/members',
        name: 'community-members',
        builder: (context, state) => CommunityMembersScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/community/:communityId/info',
        name: 'community-info',
        builder: (context, state) => CommunityInfoScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/community/:communityId/my-chats',
        name: 'community-my-chats',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return MyCommunityChatsScreen(
            communityId: state.pathParameters['communityId']!,
            communityName: extra['communityName'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/community/:communityId/my-profile',
        name: 'community-my-profile',
        builder: (context, state) => CommunityProfileScreen(
          communityId: state.pathParameters['communityId']!,
          userId: SupabaseService.currentUserId ?? '',
        ),
      ),

      // ====================================================================
      // ROTAS DE POSTS
      // ====================================================================
      GoRoute(
        path: '/post/:id',
        name: 'post-detail',
        builder: (context, state) => PostDetailScreen(
          postId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/community/:communityId/create-post',
        name: 'create-post',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CreatePostScreen(
            communityId: state.pathParameters['communityId']!,
            initialType: extra['initialType'] as String?,
          );
        },
      ),

      // Rotas de criação dedicadas (menu + da comunidade)
      GoRoute(
        path: '/community/:communityId/create-blog',
        name: 'create-blog',
        builder: (context, state) => CreateBlogScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/community/:communityId/create-image',
        name: 'create-image',
        builder: (context, state) => CreateImagePostScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/community/:communityId/create-link',
        name: 'create-link',
        builder: (context, state) => CreateLinkPostScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/community/:communityId/create-poll',
        name: 'create-poll',
        builder: (context, state) => CreatePollScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/community/:communityId/create-quiz',
        name: 'create-quiz',
        builder: (context, state) => CreateQuizScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/community/:communityId/create-question',
        name: 'create-question',
        builder: (context, state) => CreateQuestionScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      // ====================================================================
      // ROTAS DE CHAT
      // ====================================================================
      GoRoute(
        path: '/chat/:id',
        name: 'chat-room',
        builder: (context, state) => ChatRoomScreen(
          threadId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/create-group-chat',
        name: 'create-group-chat',
        builder: (context, state) => const CreateGroupChatScreen(),
      ),
      GoRoute(
        path: '/create-public-chat',
        name: 'create-public-chat',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CreatePublicChatScreen(
            communityId: extra['communityId'] as String? ?? '',
            communityName: extra['communityName'] as String? ?? '',
          );
        },
      ),

      // ====================================================================
      // ROTAS DE PERFIL
      // ====================================================================
      GoRoute(
        path: '/user/:id',
        name: 'user-profile',
        builder: (context, state) => ProfileScreen(
          userId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/profile',
        name: 'my-profile',
        builder: (context, state) => ProfileScreen(
          userId: SupabaseService.currentUserId ?? '',
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        name: 'edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/community/:communityId/profile/edit',
        name: 'edit-community-profile',
        builder: (context, state) {
          final communityId = state.pathParameters['communityId']!;
          return EditCommunityProfileScreen(communityId: communityId);
        },
      ),
      GoRoute(
        path: '/community/:communityId/profile/:userId',
        name: 'community-profile',
        builder: (context, state) => CommunityProfileScreen(
          communityId: state.pathParameters['communityId']!,
          userId: state.pathParameters['userId']!,
        ),
      ),

      // ====================================================================
      // ROTAS DE WIKI
      // ====================================================================
      GoRoute(
        path: '/community/:communityId/wiki',
        name: 'wiki-list',
        builder: (context, state) => WikiListScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/wiki/:id',
        name: 'wiki-detail',
        builder: (context, state) => WikiDetailScreen(
          wikiId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/community/:communityId/wiki/create',
        name: 'create-wiki',
        builder: (context, state) => CreateWikiScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/community/:communityId/wiki/review',
        name: 'wiki-curator-review',
        builder: (context, state) => WikiCuratorReviewScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),

      // ====================================================================
      // ROTAS DE GAMIFICAÇÃO
      // ====================================================================
      GoRoute(
        path: '/check-in',
        name: 'check-in',
        builder: (context, state) => const CheckInScreen(),
      ),
      GoRoute(
        path: '/community/:communityId/leaderboard',
        name: 'leaderboard',
        builder: (context, state) => LeaderboardScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/achievements',
        name: 'achievements',
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/inventory',
        name: 'inventory',
        builder: (context, state) => const InventoryScreen(),
      ),

      // ====================================================================
      // ROTAS DE MODERAÇÃO
      // ====================================================================
      GoRoute(
        path: '/community/:communityId/flags',
        name: 'flag-center',
        builder: (context, state) => FlagCenterScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/community/:communityId/mod-action',
        name: 'mod-action',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ModerationActionsScreen(
            communityId: state.pathParameters['communityId']!,
            targetUserId: extra['targetUserId'] as String?,
            targetPostId: extra['targetPostId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/community/:communityId/edit-guidelines',
        name: 'edit-guidelines',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return EditGuidelinesScreen(
            communityId: state.pathParameters['communityId']!,
            currentGuidelines: extra['guidelines'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/admin',
        name: 'admin-panel',
        redirect: (context, state) {
          final user = ref.read(currentUserProvider);
          if (user == null || !user.isTeamMember) return '/explore';
          return null;
        },
        builder: (context, state) => const AdminPanelScreen(),
      ),
      GoRoute(
        path: '/admin/reports',
        name: 'admin-reports',
        redirect: (context, state) {
          final user = ref.read(currentUserProvider);
          if (user == null || !user.isTeamMember) return '/explore';
          return null;
        },
        builder: (context, state) => const AdminReportsScreen(),
      ),

      // ====================================================================
      // NOTIFICAÇÕES
      // ====================================================================
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // ====================================================================
      // CONFIGURAÇÕES
      // ====================================================================
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        name: 'privacy-settings',
        builder: (context, state) => const PrivacySettingsScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        name: 'notification-settings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/blocked-users',
        name: 'blocked-users',
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: '/settings/devices',
        name: 'devices',
        builder: (context, state) => const DevicesScreen(),
      ),
      GoRoute(
        path: '/settings/permissions',
        name: 'app-permissions',
        builder: (context, state) => const AppPermissionsScreen(),
      ),
      GoRoute(
        path: '/settings/privacy-policy',
        name: 'privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/settings/terms-of-use',
        name: 'terms-of-use',
        builder: (context, state) => const TermsOfUseScreen(),
      ),
      GoRoute(
        path: '/settings/linked-accounts',
        name: 'linked-accounts',
        builder: (context, state) => const LinkedAccountsScreen(),
      ),

      // ====================================================================
      // BUSCA GLOBAL
      // ====================================================================
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),

      // ====================================================================
      // LINKS GERAIS DA COMUNIDADE (ADMIN)
      // ====================================================================
      GoRoute(
        path: '/community/:communityId/general-links',
        name: 'community-general-links',
        builder: (context, state) => CommunityGeneralLinksScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),

      // ====================================================================
      // BUSCA DENTRO DA COMUNIDADE
      // ====================================================================
      GoRoute(
        path: '/community/:communityId/search',
        name: 'community-search',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CommunitySearchScreen(
            communityId: state.pathParameters['communityId']!,
            communityName: extra['communityName'] as String? ?? 'Comunidade',
          );
        },
      ),

      // ====================================================================
      // MURAL E SEGUIDORES
      // ====================================================================
      GoRoute(
        path: '/user/:userId/wall',
        name: 'user-wall',
        builder: (context, state) => UserWallScreen(
          userId: state.pathParameters['userId']!,
        ),
      ),
      GoRoute(
        path: '/user/:userId/followers',
        name: 'followers',
        builder: (context, state) => FollowersScreen(
          userId: state.pathParameters['userId']!,
          showFollowers: state.uri.queryParameters['tab'] != 'following',
        ),
      ),

      // ====================================================================
      // MOEDAS E LOJA
      // ====================================================================
      GoRoute(
        path: '/free-coins',
        name: 'free-coins',
        builder: (context, state) => const FreeCoinsScreen(),
      ),
      GoRoute(
        path: '/coin-shop',
        name: 'coin-shop',
        builder: (context, state) => const CoinShopScreen(),
      ),

      // ====================================================================
      // CHAMADAS
      // ====================================================================
      GoRoute(
        path: '/call/:sessionId',
        name: 'call',
        builder: (context, state) {
          final session = state.extra as CallSession?;
          if (session != null) {
            return CallScreen(session: session);
          }
          // Fallback: redirecionar para home se não houver sessão
          return const Scaffold(
            body: Center(child: Text('Sessão de chamada inválida')),
          );
        },
      ),

      // ====================================================================
      // FEED GLOBAL
      // ====================================================================
      GoRoute(
        path: '/feed',
        name: 'global-feed',
        builder: (context, state) => const GlobalFeedScreen(),
      ),

      // ====================================================================
      // EDITAR PERFIL
      // ====================================================================
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile-alt',
        builder: (context, state) => const EditProfileScreen(),
      ),
      // ====================================================================
      // RASCUNHOS
      // ====================================================================
      GoRoute(
        path: '/drafts',
        name: 'drafts',
        builder: (context, state) => const DraftsScreen(),
      ),

      // ====================================================================
      // STORIES
      // ====================================================================
      GoRoute(
        path: '/community/:id/create-story',
        name: 'create-story',
        builder: (context, state) {
          final communityId = state.pathParameters['id']!;
          return CreateStoryScreen(communityId: communityId);
        },
      ),
    ],
  );
});
