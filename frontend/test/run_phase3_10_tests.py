#!/usr/bin/env python3
"""Phase 3.10 — Bug Fix Validation Tests (Python runner)"""
import os, sys

os.chdir(os.path.dirname(os.path.abspath(__file__)) + '/..')

passed = 0
failed = 0

def expect(condition, desc):
    global passed, failed
    if condition:
        passed += 1
        print(f"  PASS: {desc}")
    else:
        failed += 1
        print(f"  FAIL: {desc}")

# Bug #1: Stories FK join
print("\nBug #1: Stories FK join")
src = open("lib/features/profile/providers/profile_providers.dart").read()
expect("profiles!author_id(" in src, "Usa join generico profiles!author_id")
expect("gte('expires_at'" in src, "Filtra stories expirados")
expect("stories_author_id_fkey" not in src, "Sem FK name incorreto")

# Bug #2: Amino+ banner
print("\nBug #2: Amino+ banner navegacao")
src = open("lib/features/profile/screens/profile_screen.dart").read()
expect("context.go('/store')" in src, "Usa context.go('/store')")
expect("context.push('/store')" not in src, "Sem context.push('/store')")

# Bug #3: Followers/Following rotas
print("\nBug #3: Followers/Following rotas")
src = open("lib/features/profile/screens/profile_screen.dart").read()
expect("/user/${widget.userId}/followers" in src, "profile: rota correta followers")
expect("/user/${widget.userId}/followers?tab=following" in src, "profile: rota correta following")
expect("push('/followers/${widget.userId}')" not in src, "profile: sem rota errada followers")
expect("push('/following/${widget.userId}')" not in src, "profile: sem rota errada following")
src2 = open("lib/features/profile/screens/community_profile_screen.dart").read()
expect("/user/${widget.userId}/followers" in src2, "community_profile: rota correta")
expect("push('/followers/${widget.userId}')" not in src2, "community_profile: sem rota errada followers")

# Bug #4: Formatacao texto FocusNode
print("\nBug #4: Formatacao texto FocusNode")
src = open("lib/features/profile/screens/edit_profile_screen.dart").read()
expect("_bioFocusNode" in src, "Declara _bioFocusNode")
expect("_bioFocusNode.requestFocus()" in src, "Chama requestFocus()")
expect("focusNode: _bioFocusNode" in src, "Atribui ao TextField")
expect("splashColor:" in src, "Toolbar com splashColor")

# Bug #5: Avatar upload
print("\nBug #5: Avatar upload")
expect("MediaUploadService" in src, "Importa MediaUploadService")
expect("_pickAndUploadAvatar" in src, "Declara metodo upload")
expect("MediaUploadService.uploadAvatar()" in src, "Chama uploadAvatar()")
expect("_isUploadingAvatar" in src, "Estado de loading")

# Bug #6: Achievements overflow
print("\nBug #6: Achievements overflow")
src = open("lib/core/widgets/checkin_heatmap.dart").read()
expect("mainAxisSize: MainAxisSize.min" in src, "Column com MainAxisSize.min")
expect("Flexible(" in src, "Usa Flexible")
expect("maxLines: 1" in src, "maxLines: 1")
expect("overflow: TextOverflow.ellipsis" in src, "TextOverflow.ellipsis")

# Bug #7 SQL
print("\nBug #7: add_reputation Migration SQL")
src = open("../backend/supabase/migrations/032_fix_add_reputation_param_order.sql").read()
expect("add_reputation(p_author_id, p_community_id, 'create_post', 15, v_post_id)" in src, "create_post ordem correta")
expect("add_reputation(p_author_id, p_community_id, v_action_type, v_rep_amount, v_comment_id)" in src, "create_comment ordem correta")
expect("add_reputation(v_target_author, p_community_id, v_action_type, v_rep_amount," in src, "toggle_like ordem correta")
expect("add_reputation(p_follower_id, p_community_id, 'follow_user', 1, p_following_id)" in src, "toggle_follow ordem correta")
expect("add_reputation(p_author_id, v_community_id, 'chat_message', 1, v_message_id)" in src, "send_chat_message ordem correta")
expect("add_reputation(p_user_id, v_community_id, 'join_chat', 2, p_thread_id)" in src, "join_public_chat ordem correta")
expect("add_reputation(p_community_id, p_author_id, 15," not in src, "Sem ordem invertida")

# Bug #7 Frontend
print("\nBug #7: add_reputation Frontend (followers_screen)")
src = open("lib/features/profile/screens/followers_screen.dart").read()
expect("'p_action_type': 'follow_user'" in src, "p_action_type correto")
expect("'p_raw_amount': 1" in src, "p_raw_amount correto")
expect("'p_reference_id': widget.targetUserId" in src, "p_reference_id correto")
expect("'p_action': 'follow'" not in src, "Sem p_action errado")
expect("'p_source_id':" not in src, "Sem p_source_id errado")

print(f"\n{'='*60}")
print(f"RESULTADO: {passed} passed, {failed} failed, {passed+failed} total")
print(f"{'='*60}")
if failed > 0:
    sys.exit(1)
