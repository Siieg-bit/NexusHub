// =============================================================================
// Phase 3.10 — Bug Fix Validation Tests
// =============================================================================
// Testes estruturais para validar que os 7 bugs foram corrigidos.
// Cada grupo de teste verifica a presença das correções no código-fonte.
//
// Para rodar: dart test test/phase3_10_bugfix_test.dart
// =============================================================================

import 'dart:io';

void main() {
  int passed = 0;
  int failed = 0;

  void expect(bool condition, String description) {
    if (condition) {
      passed++;
      print('  ✅ $description');
    } else {
      failed++;
      print('  ❌ $description');
    }
  }

  // ============================================================================
  // Bug #1: Stories FK join corrigido
  // ============================================================================
  print('\n📋 Bug #1: Stories FK join');
  {
    final src = File('lib/features/profile/providers/profile_providers.dart').readAsStringSync();
    expect(
      src.contains("profiles!author_id("),
      'Usa join genérico profiles!author_id em vez de profiles!stories_author_id_fkey',
    );
    expect(
      src.contains("gte('expires_at'"),
      'Filtra stories expirados com gte(expires_at)',
    );
    expect(
      !src.contains("stories_author_id_fkey"),
      'Não contém mais o FK name incorreto stories_author_id_fkey',
    );
  }

  // ============================================================================
  // Bug #2: Amino+ banner — context.go em vez de context.push
  // ============================================================================
  print('\n📋 Bug #2: Amino+ banner navegação');
  {
    final src = File('lib/features/profile/screens/profile_screen.dart').readAsStringSync();
    expect(
      src.contains("context.go('/store')"),
      'Usa context.go(\'/store\') em vez de context.push para navegar ao store',
    );
    expect(
      !src.contains("context.push('/store')"),
      'Não contém mais context.push(\'/store\') que crashava fora do ShellRoute',
    );
  }

  // ============================================================================
  // Bug #3: Followers/Following rotas corrigidas
  // ============================================================================
  print('\n📋 Bug #3: Followers/Following rotas');
  {
    final profileSrc = File('lib/features/profile/screens/profile_screen.dart').readAsStringSync();
    expect(
      profileSrc.contains("/user/\${widget.userId}/followers"),
      'profile_screen: Usa rota /user/:userId/followers (correta)',
    );
    expect(
      profileSrc.contains("/user/\${widget.userId}/followers?tab=following"),
      'profile_screen: Usa rota /user/:userId/followers?tab=following para Following',
    );
    expect(
      !profileSrc.contains("push('/followers/\${widget.userId}')"),
      'profile_screen: Não contém mais rota incorreta /followers/:id',
    );
    expect(
      !profileSrc.contains("push('/following/\${widget.userId}')"),
      'profile_screen: Não contém mais rota incorreta /following/:id',
    );

    final commProfileSrc = File('lib/features/profile/screens/community_profile_screen.dart').readAsStringSync();
    expect(
      commProfileSrc.contains("/user/\${widget.userId}/followers"),
      'community_profile_screen: Usa rota /user/:userId/followers (correta)',
    );
    expect(
      !commProfileSrc.contains("push('/followers/\${widget.userId}')"),
      'community_profile_screen: Não contém mais rota incorreta /followers/:id',
    );
    expect(
      !commProfileSrc.contains("push('/following/\${widget.userId}')"),
      'community_profile_screen: Não contém mais rota incorreta /following/:id',
    );
  }

  // ============================================================================
  // Bug #4: Formatação de texto — FocusNode persistente
  // ============================================================================
  print('\n📋 Bug #4: Formatação de texto — FocusNode');
  {
    final src = File('lib/features/profile/screens/edit_profile_screen.dart').readAsStringSync();
    expect(
      src.contains('_bioFocusNode'),
      'Declara _bioFocusNode para manter focus no campo de bio',
    );
    expect(
      src.contains('_bioFocusNode.requestFocus()'),
      'Chama requestFocus() após aplicar formatação',
    );
    expect(
      src.contains('focusNode: _bioFocusNode'),
      'Atribui _bioFocusNode ao TextField da bio',
    );
    expect(
      src.contains('_bioFocusNode.dispose()'),
      'Faz dispose do FocusNode no dispose()',
    );
    expect(
      src.contains('splashColor:'),
      'Toolbar tem splashColor visível para feedback',
    );
  }

  // ============================================================================
  // Bug #5: Avatar upload funcional
  // ============================================================================
  print('\n📋 Bug #5: Avatar upload');
  {
    final src = File('lib/features/profile/screens/edit_profile_screen.dart').readAsStringSync();
    expect(
      src.contains('MediaUploadService'),
      'Importa MediaUploadService',
    );
    expect(
      src.contains('_pickAndUploadAvatar'),
      'Declara método _pickAndUploadAvatar',
    );
    expect(
      src.contains('MediaUploadService.uploadAvatar()'),
      'Chama MediaUploadService.uploadAvatar() no método',
    );
    expect(
      src.contains('GestureDetector') && src.contains('_pickAndUploadAvatar'),
      'GestureDetector envolve o avatar com onTap para upload',
    );
    expect(
      src.contains('_isUploadingAvatar'),
      'Tem estado de loading para upload do avatar',
    );
    expect(
      src.contains("CachedNetworkImageProvider(_avatarUrl!)"),
      'Exibe avatar via CachedNetworkImage quando URL disponível',
    );
  }

  // ============================================================================
  // Bug #6: Achievements overflow — _StatCard
  // ============================================================================
  print('\n📋 Bug #6: Achievements overflow');
  {
    final src = File('lib/core/widgets/checkin_heatmap.dart').readAsStringSync();
    expect(
      src.contains('mainAxisSize: MainAxisSize.min'),
      '_StatCard Column tem mainAxisSize: MainAxisSize.min',
    );
    expect(
      src.contains('Flexible('),
      'Stats Row usa Flexible em vez de Expanded',
    );
    expect(
      src.contains('maxLines: 1'),
      'Textos no _StatCard têm maxLines: 1 para evitar overflow',
    );
    expect(
      src.contains('overflow: TextOverflow.ellipsis'),
      'Textos no _StatCard têm overflow: TextOverflow.ellipsis',
    );
  }

  // ============================================================================
  // Bug #7: add_reputation — Migration + Frontend
  // ============================================================================
  print('\n📋 Bug #7: add_reputation — Migration SQL');
  {
    final migrationSrc = File('../backend/supabase/migrations/032_fix_add_reputation_param_order.sql').readAsStringSync();

    // Verificar que a migration corrige a ordem: (user_id, community_id, action_type, amount, ref)
    // Na migration 021 original era: (community_id, author_id, amount, action_type, ref)
    expect(
      migrationSrc.contains("add_reputation(p_author_id, p_community_id, 'create_post', 15, v_post_id)"),
      'create_post_with_reputation: ordem correta (user, community, action, amount, ref)',
    );
    expect(
      migrationSrc.contains("add_reputation(p_author_id, p_community_id, v_action_type, v_rep_amount, v_comment_id)"),
      'create_comment_with_reputation: ordem correta (user, community, action, amount, ref)',
    );
    expect(
      migrationSrc.contains("add_reputation(v_target_author, p_community_id, v_action_type, v_rep_amount,"),
      'toggle_like_with_reputation: ordem correta (target_author, community, action, amount, ref)',
    );
    expect(
      migrationSrc.contains("add_reputation(p_follower_id, p_community_id, 'follow_user', 1, p_following_id)"),
      'toggle_follow_with_reputation: ordem correta (follower, community, action, amount, ref)',
    );
    expect(
      migrationSrc.contains("add_reputation(p_author_id, v_community_id, 'chat_message', 1, v_message_id)"),
      'send_chat_message_with_reputation: ordem correta (author, community, action, amount, ref)',
    );
    expect(
      migrationSrc.contains("add_reputation(p_user_id, v_community_id, 'join_chat', 2, p_thread_id)"),
      'join_public_chat_with_reputation: ordem correta (user, community, action, amount, ref)',
    );

    // Verificar que NÃO contém a ordem errada da migration 021
    expect(
      !migrationSrc.contains("add_reputation(p_community_id, p_author_id, 15,"),
      'Não contém mais a ordem invertida (community, author, INT, TEXT)',
    );
  }

  print('\n📋 Bug #7: add_reputation — Frontend (followers_screen)');
  {
    final src = File('lib/features/profile/screens/followers_screen.dart').readAsStringSync();
    expect(
      src.contains("'p_action_type': 'follow_user'"),
      'followers_screen: Usa p_action_type (nome correto do param)',
    );
    expect(
      src.contains("'p_raw_amount': 1"),
      'followers_screen: Usa p_raw_amount (nome correto do param)',
    );
    expect(
      src.contains("'p_reference_id': widget.targetUserId"),
      'followers_screen: Usa p_reference_id (nome correto do param)',
    );
    expect(
      !src.contains("'p_action': 'follow'"),
      'followers_screen: Não contém mais p_action (nome errado)',
    );
    expect(
      !src.contains("'p_source_id':"),
      'followers_screen: Não contém mais p_source_id (nome errado)',
    );
  }

  // ============================================================================
  // RESULTADO FINAL
  // ============================================================================
  print('\n${'=' * 60}');
  print('RESULTADO: $passed passed, $failed failed, ${passed + failed} total');
  print('${'=' * 60}');

  if (failed > 0) {
    exit(1);
  }
}
