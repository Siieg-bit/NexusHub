#!/usr/bin/env python3
"""
Pass 4: Final cleanup of remaining Portuguese strings with accents.
"""

import os
import re
import json

PROJECT = "/home/ubuntu/NexusHub/frontend/lib"

# Remaining strings with their translations and keys
FINAL_STRINGS = {
    'A pergunta da enquete é obrigatória': ('The poll question is required', 'pollQuestionRequired'),
    'A pergunta é obrigatória': ('The question is required', 'questionRequired'),
    'Aba de chats públicos da comunidade': ('Community public chats tab', 'communityPublicChatsTab'),
    'Acessível apenas por link direto': ('Accessible only by direct link', 'accessibleByDirectLink'),
    'Alguém': ('Someone', 'someone'),
    'Anúncio não disponível no momento': ('Ad not available at the moment', 'adNotAvailable'),
    'Apareça como offline para todos os usuários': ('Appear offline to all users', 'appearOfflineDesc'),
    'Aviso da moderação': ('Moderation warning', 'moderationWarning'),
    'Ação': ('Action', 'actionLabel'),
    'Ação da moderação': ('Moderation action', 'moderationActionLabel'),
    'Ação executada com sucesso': ('Action executed successfully', 'actionExecutedSuccess'),
    'Ações': ('Actions', 'actionsLabel'),
    'Banir o usuário da comunidade': ('Ban user from community', 'banUserFromCommunity'),
    'Botão central para criar posts': ('Central button to create posts', 'centralButtonCreatePosts'),
    'Categorias de tópicos': ('Topic categories', 'topicCategories'),
    'Comentários bloqueados': ('Comments blocked', 'commentsBlocked'),
    'Completamente invisível': ('Completely invisible', 'completelyInvisible'),
    'Comunicação': ('Communication', 'communication'),
    'Criar nova publicação': ('Create new post', 'createNewPost'),
    'Dados inválidos': ('Invalid data', 'invalidData'),
    'Desabilitar comentários no perfil': ('Disable profile comments', 'disableProfileComments'),
    'Enviar mensagem para todos os usuários': ('Send message to all users', 'sendMessageToAll'),
    'Español': ('Español', 'spanishLang'),
    'Français': ('Français', 'frenchLang'),
    'Ganhe moedas ao subir de nível': ('Earn coins when leveling up', 'earnCoinsLevelUp'),
    'Impede que novos usuários iniciem conversas': ('Prevents new users from starting conversations', 'preventNewUsersConversations'),
    'Informe o motivo da ação': ('Inform the reason for the action', 'informActionReason'),
    'Layout resetado para o padrão': ('Layout reset to default', 'layoutResetToDefault'),
    'Lendário': ('Legendary', 'legendary'),
    'Liberar espaço de armazenamento': ('Free up storage space', 'freeUpStorage'),
    'Menções': ('Mentions', 'mentions'),
    'Mostrar quando você está online': ('Show when you are online', 'showWhenOnline'),
    'Mítico': ('Mythical', 'mythical'),
    'Nenhum comentário': ('No comments', 'noComments'),
    'Nenhum comentário no mural': ('No comments on the wall', 'noWallComments'),
    'Nenhum usuário encontrado': ('No user found', 'noUserFound'),
    'Nenhuma ação de moderação registrada': ('No moderation actions recorded', 'noModerationActions'),
    'Nenhuma conexão': ('No connections', 'noConnections'),
    'Nenhuma conquista disponível': ('No achievements available', 'noAchievementsAvailable'),
    'Nenhuma seção habilitada': ('No sections enabled', 'noSectionsEnabled'),
    'Nenhuma transação ainda': ('No transactions yet', 'noTransactionsYet'),
    'Ninguém pode comentar no seu mural': ('No one can comment on your wall', 'noOneCanCommentWall'),
    'Nome é obrigatório': ('Name is required', 'nameRequired'),
    'Notificação': ('Notification', 'notificationLabel'),
    'Novos membros precisam de aprovação': ('New members need approval', 'newMembersNeedApproval'),
    'Não autenticado': ('Not authenticated', 'notAuthenticated'),
    'Não vinculado': ('Not linked', 'notLinked'),
    'Não é possível enviar mensagem para este usuário': ('Cannot send message to this user', 'cannotMessageUser'),
    'O título do quiz é obrigatório': ('The quiz title is required', 'quizTitleRequired'),
    'O título é obrigatório': ('The title is required', 'titleRequired'),
    'Obrigatório': ('Required', 'requiredField'),
    'Ofertas não disponíveis no momento': ('Offers not available at the moment', 'offersNotAvailable'),
    'Opções': ('Options', 'optionsLabel'),
    'Pacote não encontrado': ('Package not found', 'packageNotFound'),
    'Participe das discussões': ('Join the discussions', 'joinDiscussions'),
    'Pausar todas as notificações temporariamente': ('Pause all notifications temporarily', 'pauseNotifications'),
    'Pergunte à comunidade': ('Ask the community', 'askCommunity'),
    'Permitir comentários': ('Allow comments', 'allowComments'),
    'Permitir destaque de conteúdo': ('Allow content highlight', 'allowContentHighlight'),
    'Português': ('Portuguese', 'portugueseLang'),
    'Post não encontrado ou sem permissão': ('Post not found or no permission', 'postNotFoundOrNoPermission'),
    'Preencha o título ou conteúdo': ('Fill in the title or content', 'fillTitleOrContent'),
    'Preferências': ('Preferences', 'preferences'),
    'Projeção': ('Projection', 'projection'),
    'Publique conteúdo na comunidade': ('Publish content in the community', 'publishContentCommunity'),
    'Público': ('Public', 'publicLabel'),
    'Quando alguém comenta no seu post': ('When someone comments on your post', 'whenSomeoneComments'),
    'Quando alguém começa a te seguir': ('When someone starts following you', 'whenSomeoneFollows'),
    'Quando alguém curte seu post': ('When someone likes your post', 'whenSomeoneLikes'),
    'Quando alguém menciona você': ('When someone mentions you', 'whenSomeoneMentions'),
    'Quando sobe de nível': ('When you level up', 'whenLevelUp'),
    'Reconheça um membro': ('Recognize a member', 'recognizeMember'),
    'Relatórios': ('Reports', 'reportsLabel'),
    'Remover a fixação do post': ('Unpin the post', 'unpinPost'),
    'Remover o ban do usuário': ('Remove user ban', 'removeUserBan'),
    'Selecione o motivo da denúncia': ('Select the report reason', 'selectReportReason'),
    'Selecione o tipo de denúncia': ('Select the report type', 'selectReportType'),
    'Sem anúncios': ('No ads', 'noAds'),
    'Seu feed está vazio': ('Your feed is empty', 'feedEmpty'),
    'Seu identificador único': ('Your unique identifier', 'uniqueIdentifier'),
    'Seus rascunhos de posts aparecerão aqui': ('Your post drafts will appear here', 'postDraftsAppearHere'),
    'Sons de notificação dentro do app': ('Notification sounds within the app', 'notificationSoundsInApp'),
    'Usuário não autenticado': ('User not authenticated', 'userNotAuthenticated'),
    'Usuários': ('Users', 'usersLabel'),
    'Vibrar ao receber notificações': ('Vibrate on notifications', 'vibrateOnNotifications'),
    'Vibração': ('Vibration', 'vibration'),
    'Vídeo': ('Video', 'videoLabel'),
    # Additional strings found in widgets
    'Encaminhar para': ('Forward to', 'forwardTo'),
    'Nenhum chat encontrado': ('No chat found', 'noChatFound'),
    'Mensagem direta': ('Direct message', 'directMessage'),
    'Toque para baixar': ('Tap to download', 'tapToDownload'),
    'Encaminhada': ('Forwarded', 'forwarded'),
    'Perfil compartilhado': ('Shared profile', 'sharedProfile'),
    'Aba de posts em destaque': ('Featured posts tab', 'featuredPostsTab'),
    'Aba de posts mais recentes': ('Most recent posts tab', 'recentPostsTab'),
    'Aceitar convite': ('Accept invite', 'acceptInvite'),
    'Acerte quizzes da comunidade': ('Get community quizzes right', 'getCommunityQuizzes'),
    'Acesso antecipado a novidades': ('Early access to new features', 'earlyAccess'),
    'Adicionado aos favoritos': ('Added to favorites', 'addedToFavorites'),
    'Adicione pelo menos uma imagem': ('Add at least one image', 'addAtLeastOneImage'),
    'Adicione pelo menos uma pergunta': ('Add at least one question', 'addAtLeastOneQuestion'),
    'Alertas': ('Alerts', 'alerts'),
    'Alterar': ('Change', 'changeAction'),
    'Apenas amigos': ('Friends only', 'friendsOnly'),
    'Apenas de amigos': ('From friends only', 'fromFriendsOnly'),
    'Apenas membros convidados podem entrar': ('Only invited members can join', 'onlyInvitedMembers'),
    'Apenas quem eu sigo de volta': ('Only those I follow back', 'onlyFollowBack'),
    'Aprendiz': ('Apprentice', 'apprentice'),
    'Armazenamento': ('Storage', 'storage'),
    'Assinar': ('Subscribe', 'subscribe'),
    'Assinaturas': ('Subscriptions', 'subscriptions'),
    'Assistir': ('Watch', 'watchAction'),
    'Ativas': ('Active', 'activeLabel2'),
    'Atual': ('Current', 'currentLabel'),
    'Aventureiro': ('Adventurer', 'adventurer'),
    'Badge exclusiva no perfil': ('Exclusive profile badge', 'exclusiveBadge'),
    'Baixar uma cópia dos seus dados': ('Download a copy of your data', 'downloadYourData'),
    'Bio nesta comunidade': ('Bio in this community', 'bioInCommunity'),
    'Biografia': ('Biography', 'biography'),
    'Bolha': ('Bubble', 'bubble'),
    'Bolhas': ('Bubbles', 'bubbles'),
    'Busque artigos wiki desta comunidade': ('Search wiki articles in this community', 'searchWikiArticles'),
    'Busque membros desta comunidade': ('Search members of this community', 'searchCommunityMembers'),
    'Buscas recentes': ('Recent searches', 'recentSearches'),
}

def main():
    # 1. Add keys to l10n files
    abstract_additions = []
    pt_additions = []
    en_additions = []
    
    # Load existing keys to avoid duplicates
    existing_keys = set()
    with open(f"{PROJECT}/core/l10n/app_strings.dart", 'r') as f:
        for line in f:
            m = re.search(r'String get (\w+)', line)
            if m:
                existing_keys.add(m.group(1))
    
    new_count = 0
    for pt_str, (en_str, key) in sorted(FINAL_STRINGS.items(), key=lambda x: x[1][1]):
        if key in existing_keys:
            continue
        existing_keys.add(key)
        new_count += 1
        abstract_additions.append(f"  String get {key};")
        pt_escaped = pt_str.replace("'", "\\'")
        en_escaped = en_str.replace("'", "\\'")
        pt_additions.append(f"  @override\n  String get {key} => '{pt_escaped}';")
        en_additions.append(f"  @override\n  String get {key} => '{en_escaped}';")
    
    for filepath, additions, comment in [
        (f"{PROJECT}/core/l10n/app_strings.dart", abstract_additions, "// PASS 4 — FINAL CLEANUP"),
        (f"{PROJECT}/core/l10n/app_strings_pt.dart", pt_additions, "// PASS 4 — FINAL CLEANUP"),
        (f"{PROJECT}/core/l10n/app_strings_en.dart", en_additions, "// PASS 4 — FINAL CLEANUP"),
    ]:
        if not additions:
            continue
        with open(filepath, 'r') as f:
            content = f.read()
        insert_text = f"\n  {comment}\n" + '\n'.join(additions) + '\n'
        content = content.rstrip().rstrip('}') + insert_text + '}\n'
        with open(filepath, 'w') as f:
            f.write(content)
    
    print(f"Added {new_count} new keys to l10n files")
    
    # 2. Replace in all Dart files
    sorted_replacements = sorted(FINAL_STRINGS.items(), key=lambda x: len(x[0]), reverse=True)
    
    all_dart_files = []
    for root, dirs, files in os.walk(PROJECT):
        for f in files:
            if f.endswith('.dart') and '/l10n/' not in os.path.join(root, f):
                all_dart_files.append(os.path.join(root, f))
    
    modified = 0
    for filepath in sorted(all_dart_files):
        with open(filepath, 'r') as f:
            content = f.read()
        
        original = content
        
        for pt_str, (en_str, key) in sorted_replacements:
            if pt_str not in content:
                continue
            
            replacement = f's.{key}'
            lines = content.split('\n')
            new_lines = []
            for line in lines:
                stripped = line.strip()
                if stripped.startswith('//') or stripped.startswith('///') or 'debugPrint' in line:
                    new_lines.append(line)
                    continue
                
                escaped = pt_str.replace("'", "\\'")
                line = line.replace(f"'{escaped}'", replacement)
                line = line.replace(f"'{pt_str}'", replacement)
                escaped_dq = pt_str.replace('"', '\\"')
                line = line.replace(f'"{escaped_dq}"', replacement)
                line = line.replace(f'"{pt_str}"', replacement)
                
                new_lines.append(line)
            
            content = '\n'.join(new_lines)
        
        if content != original:
            with open(filepath, 'w') as f:
                f.write(content)
            modified += 1
            print(f"  ✓ {os.path.basename(filepath)}")
    
    print(f"\nModified: {modified} files in pass 4")
    
    # 3. Fix any const issues
    for filepath in all_dart_files:
        with open(filepath, 'r') as f:
            content = f.read()
        original = content
        content = re.sub(r'const Text\(s\.', 'Text(s.', content)
        content = re.sub(r'const Tab\(text: s\.', 'Tab(text: s.', content)
        if content != original:
            with open(filepath, 'w') as f:
                f.write(content)


if __name__ == '__main__':
    main()
