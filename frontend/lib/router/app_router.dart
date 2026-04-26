import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/supabase_service.dart';
import '../core/models/post_model.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/interest_wizard_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/chat/screens/chat_list_screen.dart';
import '../features/chat/screens/chat_requests_screen.dart';
import '../features/chat/screens/chat_room_screen.dart';
import '../features/chat/screens/chat_details_screen.dart';
import '../features/communities/screens/community_detail_screen.dart';
import '../features/communities/screens/my_community_chats_screen.dart';
import '../features/communities/screens/community_info_screen.dart';
import '../features/communities/screens/community_list_screen.dart';
import '../features/communities/screens/create_community_screen.dart';
import '../features/communities/screens/community_members_screen.dart';
import '../features/communities/screens/acm_screen.dart';
import '../features/communities/screens/member_titles_screen.dart';
import '../features/communities/screens/member_title_picker_screen.dart';
import '../features/communities/screens/rpg_roles_screen.dart';
import '../features/explore/screens/explore_screen.dart';
import '../features/feed/screens/create_blog_screen.dart';
import '../features/feed/screens/create_image_post_screen.dart';
import '../features/feed/screens/create_link_post_screen.dart';
import '../features/feed/screens/create_poll_screen.dart';
import '../features/feed/screens/create_quiz_screen.dart';
import '../features/feed/screens/create_question_screen.dart';
import '../features/wiki/screens/create_wiki_screen.dart';
import '../features/feed/screens/global_feed_screen.dart';
import '../features/feed/screens/post_detail_screen.dart';
import '../features/gamification/screens/check_in_screen.dart';
import '../features/gamification/screens/leaderboard_screen.dart';
import '../features/gamification/screens/wallet_screen.dart';
import '../features/gamification/screens/achievements_screen.dart';
import '../features/gamification/screens/inventory_screen.dart';
import '../features/gamification/screens/all_rankings_screen.dart';
import '../features/moderation/screens/flag_center_screen.dart';
import '../features/moderation/screens/admin_panel_screen.dart';
import '../features/moderation/screens/moderation_actions_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/profile/screens/community_profile_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/referral_screen.dart';
import '../features/profile/screens/verified_badge_request_screen.dart';
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
import '../features/settings/screens/theme_selector_screen.dart';
import '../features/settings/screens/change_email_screen.dart';
import '../features/settings/screens/change_password_screen.dart';
import '../features/settings/screens/two_factor_screen.dart';
import '../features/settings/screens/totp_setup_screen.dart';
import '../features/settings/screens/phone_2fa_screen.dart';
import '../features/auth/screens/mfa_challenge_screen.dart';
import '../features/explore/screens/search_screen.dart';
import '../features/explore/screens/interest_match_screen.dart';
import '../features/profile/screens/user_wall_screen.dart';
import '../features/profile/screens/followers_screen.dart';
import '../features/profile/screens/community_followers_screen.dart';
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
import '../features/moderation/screens/moderation_center_screen.dart';
import '../features/moderation/screens/flag_detail_screen.dart';
import '../features/stories/screens/create_story_screen.dart';
import '../features/stories/screens/community_stories_screen.dart';
// Nova Sala de Projeção refatorada (Fase 1)
import '../features/live/screening/screens/screening_room_screen.dart';
import '../features/feed/screens/drafts_screen.dart';
import '../features/stickers/screens/sticker_gallery_screen.dart';
import '../features/stickers/screens/sticker_pack_screen.dart';
import '../features/stickers/screens/sticker_creator_screen.dart';
import '../features/stickers/screens/create_pack_screen.dart';
import '../features/stickers/screens/sticker_explore_screen.dart';
import '../features/profile/screens/edit_community_profile_screen.dart';
import 'shell_screen.dart';
import '../features/stories/screens/story_viewer_screen.dart';
import '../core/screens/short_code_redirect_screen.dart';
import '../core/utils/page_transitions.dart';

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
          state.matchedLocation == '/interest-wizard' ||
          // Recuperação de senha: o usuário pode não estar autenticado ainda
          state.matchedLocation == '/reset-password';

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
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/auth/mfa-challenge',
        name: 'mfa-challenge',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return MfaChallengeScreen(
            factorId: extra['factorId'] as String? ?? '',
            method:   extra['method']   as String? ?? 'totp',
          );
        },
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
          // NOTIFICAÇÕES (tab 3)
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          // STORE (tab 4)
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
                communityId: extra['communityId'] as String?,
              );
            },
          ),
        ],
      ),

      // ====================================================================
      // ROTAS DE COMUNIDADE
      // ====================================================================
      GoRoute(
        path: '/chat-requests',
        name: 'chat-requests',
        builder: (context, state) => const ChatRequestsScreen(),
      ),
      GoRoute(
        path: '/community/:communityId/rpg-roles',
        name: 'rpg-roles',
        builder: (context, state) {
          final communityId = state.pathParameters['communityId']!;
          final isHost = state.uri.queryParameters['isHost'] == 'true';
          return RpgRolesScreen(communityId: communityId, isHost: isHost);
        },
      ),
      GoRoute(
        path: '/community/create',
        name: 'create-community',
        builder: (context, state) => const CreateCommunityScreen(),
      ),
      GoRoute(
        path: '/community/:id',
        name: 'community-detail',
        pageBuilder: (context, state) => NexusTransitions.scaleFade(
          state: state,
          child: CommunityDetailScreen(
            communityId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/community/:communityId/notifications',
        name: 'community-notifications',
        builder: (context, state) => NotificationsScreen(
          communityId: state.pathParameters['communityId']!,
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
        path: '/community/:communityId/acm/member-titles',
        name: 'member-titles',
        builder: (context, state) => MemberTitlesScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/community/:communityId/my-title',
        name: 'my-title',
        builder: (context, state) => MemberTitlePickerScreen(
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
        pageBuilder: (context, state) => NexusTransitions.scaleFade(
          state: state,
          child: PostDetailScreen(
            postId: state.pathParameters['id']!,
            scrollToComments:
                state.uri.queryParameters['scrollToComments'] == 'true',
          ),
        ),
      ),
      GoRoute(
        path: '/quiz/:id',
        redirect: (context, state) => '/post/${state.pathParameters['id']!}',
      ),
      GoRoute(
        path: '/poll/:id',
        redirect: (context, state) => '/post/${state.pathParameters['id']!}',
      ),
      GoRoute(
        path: '/question/:id',
        redirect: (context, state) => '/post/${state.pathParameters['id']!}',
      ),
      // Rotas de criação dedicadas — cada tipo usa sua tela especializada
      GoRoute(
        path: '/community/:communityId/create-blog',
        name: 'create-blog',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CreateBlogScreen(
            communityId: state.pathParameters['communityId']!,
            editingPost: extra['editingPost'] as PostModel?,
            draftId: extra['draftId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/community/:communityId/create-image',
        name: 'create-image',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CreateImagePostScreen(
            communityId: state.pathParameters['communityId']!,
            editingPost: extra['editingPost'] as PostModel?,
          );
        },
      ),
      GoRoute(
        path: '/community/:communityId/create-link',
        name: 'create-link',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CreateLinkPostScreen(
            communityId: state.pathParameters['communityId']!,
            editingPost: extra['editingPost'] as PostModel?,
          );
        },
      ),
      GoRoute(
        path: '/community/:communityId/create-poll',
        name: 'create-poll',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CreatePollScreen(
            communityId: state.pathParameters['communityId']!,
            editingPost: extra['editingPost'] as PostModel?,
          );
        },
      ),
      GoRoute(
        path: '/community/:communityId/create-quiz',
        name: 'create-quiz',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CreateQuizScreen(
            communityId: state.pathParameters['communityId']!,
            editingPost: extra['editingPost'] as PostModel?,
            draftId: extra['draftId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/community/:communityId/create-question',
        name: 'create-question',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CreateQuestionScreen(
            communityId: state.pathParameters['communityId']!,
            editingPost: extra['editingPost'] as PostModel?,
          );
        },
      ),
      // ====================================================================
      // ROTAS DE CHAT
      // ====================================================================
      GoRoute(
        path: '/chat',
        redirect: (context, state) => '/chats',
      ),
      GoRoute(
        path: '/chat/:id',
        name: 'chat-room',
        pageBuilder: (context, state) => NexusTransitions.slide(
          state: state,
          child: ChatRoomScreen(
            threadId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/chat/:id/details',
        name: 'chat-details',
        builder: (context, state) => ChatDetailsScreen(
          threadId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/thread/:id',
        redirect: (context, state) => '/chat/${state.pathParameters['id']!}',
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
        pageBuilder: (context, state) => NexusTransitions.slide(
          state: state,
          child: ProfileScreen(
            userId: state.pathParameters['id']!,
          ),
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
        path: '/profile/verified-badge',
        name: 'verified-badge-request',
        builder: (context, state) => const VerifiedBadgeRequestScreen(),
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

      // Conexões dentro de uma comunidade (usa perfil de comunidade)
      GoRoute(
        path: '/community/:communityId/profile/:userId/followers',
        name: 'community-followers',
        builder: (context, state) => CommunityFollowersScreen(
          communityId: state.pathParameters['communityId']!,
          userId: state.pathParameters['userId']!,
          showFollowers: state.uri.queryParameters['tab'] != 'following',
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
      // Rotas estáticas de wiki ANTES da rota dinâmica para evitar conflito
      GoRoute(
        path: '/community/:communityId/wiki/create',
        name: 'create-wiki',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CreateWikiScreen(
            communityId: state.pathParameters['communityId']!,
            editingPost: extra['editingPost'] as PostModel?,
            draftId: extra['draftId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/community/:communityId/wiki/review',
        name: 'wiki-curator-review',
        builder: (context, state) => WikiCuratorReviewScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      // Rota dinâmica com contexto de comunidade — usada pela WikiListScreen
      // Declarada DEPOIS das rotas estáticas para evitar que 'create'/'review'
      // sejam interpretados como :wikiId
      GoRoute(
        path: '/community/:communityId/wiki/:wikiId',
        name: 'community-wiki-detail',
        builder: (context, state) => WikiDetailScreen(
          wikiId: state.pathParameters['wikiId']!,
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
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return AchievementsScreen(
            userId: extra['userId'] as String?,
            communityId: extra['communityId'] as String?,
            communityBannerUrl: extra['bannerUrl'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/inventory',
        name: 'inventory',
        builder: (context, state) => const InventoryScreen(),
      ),
      GoRoute(
        path: '/all-rankings',
        name: 'allRankings',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return AllRankingsScreen(
            currentLevel: extra['level'] as int? ?? 1,
            currentReputation: extra['reputation'] as int? ?? 0,
            communityBannerUrl: extra['bannerUrl'] as String?,
          );
        },
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
      // Central de moderação avançada (com bot stats + snapshots)
      GoRoute(
        path: '/community/:communityId/moderation',
        name: 'moderation-center',
        builder: (context, state) => ModerationCenterScreen(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      // Detalhe de uma denúncia (snapshot + bot analysis)
      GoRoute(
        path: '/community/:communityId/flags/:flagId',
        name: 'flag-detail',
        builder: (context, state) => FlagDetailScreen(
          flagId: state.pathParameters['flagId']!,
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
      GoRoute(
        path: '/settings/themes',
        name: 'theme-selector',
        builder: (context, state) => const ThemeSelectorScreen(),
      ),
      GoRoute(
        path: '/settings/change-email',
        name: 'change-email',
        builder: (context, state) => const ChangeEmailScreen(),
      ),
      GoRoute(
        path: '/settings/change-password',
        name: 'change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/settings/2fa',
        name: '2fa',
        builder: (context, state) => const TwoFactorScreen(),
      ),
      GoRoute(
        path: '/settings/2fa/totp-setup',
        name: 'totp-setup',
        builder: (context, state) => const TotpSetupScreen(),
      ),
      GoRoute(
        path: '/settings/2fa/phone-setup',
        name: 'phone-2fa-setup',
        builder: (context, state) => const Phone2faScreen(),
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
      // MATCHING POR INTERESSES
      // ====================================================================
      GoRoute(
        path: '/interest-match',
        name: 'interest-match',
        builder: (context, state) => const InterestMatchScreen(),
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
            communityName: extra['communityName'] as String? ?? 'Community',
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
            // SafeArea garante que o conteúdo não fique atrás da status bar
            // em dispositivos com edge-to-edge (Android 15+).
            body: SafeArea(
              child: Center(child: Text('Sessão de chamada inválida')),
            ),
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
        builder: (context, state) => DraftsScreen(
          communityId: state.uri.queryParameters['communityId'],
        ),
      ),

      // ====================================================================
      // STORIES
      // ====================================================================
      GoRoute(
        path: '/community/:id/stories',
        name: 'community-stories',
        builder: (context, state) => CommunityStoriesScreen(
          communityId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/community/:id/create-story',
        name: 'create-story',
        builder: (context, state) {
          final communityId = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CreateStoryScreen(
            communityId: communityId,
            editingPost: extra['editingPost'] as PostModel?,
          );
        },
      ),
      // ====================================================================
      // ROTAS DE SHORT CODES (URLs curtas)
      // Recebem o código curto e redirecionam para a tela correta.
      // ====================================================================
      GoRoute(
        path: '/p/:code',
        name: 'short-post',
        builder: (context, state) => ShortCodeRedirectScreen(
          type: 'post',
          code: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: '/w/:code',
        name: 'short-wiki',
        builder: (context, state) => ShortCodeRedirectScreen(
          type: 'wiki',
          code: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: '/u/:code',
        name: 'short-user',
        builder: (context, state) => ShortCodeRedirectScreen(
          type: 'user',
          code: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: '/c/:code',
        name: 'short-community',
        builder: (context, state) => ShortCodeRedirectScreen(
          type: 'community',
          code: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: '/s/:code',
        name: 'short-sticker',
        builder: (context, state) => ShortCodeRedirectScreen(
          type: 'sticker_pack',
          code: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: '/invite/:code',
        name: 'short-invite',
        builder: (context, state) => ShortCodeRedirectScreen(
          type: 'invite',
          code: state.pathParameters['code']!,
        ),
      ),
      // Nota: /chat/:id já existe e aceita tanto UUID quanto short code
      // pois ChatRoomScreen recebe o threadId diretamente.
      // O DeepLinkService resolve o short code antes de navegar para /chat/:id.

      // ====================================================================
      // STICKERS
      // ====================================================================
      GoRoute(
        path: '/stickers',
        name: 'sticker-gallery',
        builder: (context, state) => const StickerGalleryScreen(),
      ),
      GoRoute(
        path: '/stickers/explore',
        name: 'sticker-explore',
        builder: (context, state) => const StickerExploreScreen(),
      ),
      GoRoute(
        path: '/stickers/create-pack',
        name: 'create-sticker-pack',
        builder: (context, state) => const CreatePackScreen(),
      ),
      GoRoute(
        path: '/stickers/pack/:packId',
        name: 'sticker-pack',
        builder: (context, state) {
          final packId = state.pathParameters['packId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return StickerPackScreen(
            packId: packId,
            isOwner: extra['isOwner'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/stickers/pack/:packId/add',
        name: 'sticker-creator',
        builder: (context, state) {
          final packId = state.pathParameters['packId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return StickerCreatorScreen(
            packId: packId,
            packName: extra['packName'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/profile/referral',
        name: 'referral',
        builder: (context, state) => const ReferralScreen(),
      ),
    ],
  );
});
