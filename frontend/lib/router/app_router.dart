import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/supabase_service.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/communities/screens/community_detail_screen.dart';
import '../features/communities/screens/community_list_screen.dart';
import '../features/communities/screens/create_community_screen.dart';
import '../features/feed/screens/create_post_screen.dart';
import '../features/feed/screens/post_detail_screen.dart';
import '../features/chat/screens/chat_room_screen.dart';
import '../features/chat/screens/chat_list_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/wiki/screens/wiki_list_screen.dart';
import '../features/wiki/screens/wiki_detail_screen.dart';
import '../features/wiki/screens/create_wiki_screen.dart';
import '../features/gamification/screens/check_in_screen.dart';
import '../features/gamification/screens/leaderboard_screen.dart';
import 'shell_screen.dart';

/// Provider do router principal do aplicativo.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: SupabaseService.isAuthenticated ? '/' : '/onboarding',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = SupabaseService.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/onboarding';

      if (!isAuthenticated && !isAuthRoute) {
        return '/onboarding';
      }
      if (isAuthenticated && isAuthRoute) {
        return '/';
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

      // ====================================================================
      // SHELL (BOTTOM NAVIGATION)
      // ====================================================================
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          // HOME / COMUNIDADES
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const CommunityListScreen(),
          ),

          // EXPLORAR
          GoRoute(
            path: '/explore',
            name: 'explore',
            builder: (context, state) => const CommunityListScreen(isExplore: true),
          ),

          // CHATS
          GoRoute(
            path: '/chats',
            name: 'chats',
            builder: (context, state) => const ChatListScreen(),
          ),

          // PERFIL
          GoRoute(
            path: '/profile',
            name: 'my-profile',
            builder: (context, state) => ProfileScreen(
              userId: SupabaseService.currentUserId ?? '',
            ),
          ),
        ],
      ),

      // ====================================================================
      // ROTAS DE COMUNIDADE
      // ====================================================================
      GoRoute(
        path: '/community/:id',
        name: 'community-detail',
        builder: (context, state) => CommunityDetailScreen(
          communityId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/community/create',
        name: 'create-community',
        builder: (context, state) => const CreateCommunityScreen(),
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
        builder: (context, state) => CreatePostScreen(
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
          chatRoomId: state.pathParameters['id']!,
        ),
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
        path: '/profile/edit',
        name: 'edit-profile',
        builder: (context, state) => const EditProfileScreen(),
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
    ],
  );
});
