#!/usr/bin/env python3
"""
Pass 8: Handle remaining non-accented Portuguese strings.
Filter out data/technical strings and replace actual UI strings.
"""

import os
import re

PROJECT = "/home/ubuntu/NexusHub/frontend/lib"

# Non-accented Portuguese strings that need localization
SIMPLE = {
    'Adicionar Capa': ('Add Cover', 'addCover'),
    'Adicionar Pergunta': ('Add Question', 'addQuestion'),
    'Adicionar legenda...': ('Add caption...', 'addCaptionHint'),
    'Adicione contexto ou detalhes (opcional)...': ('Add context or details (optional)...', 'addContextHint'),
    'Amino ID': ('Amino ID', 'aminoId'),
    'Apenas Convite': ('Invite Only', 'inviteOnly'),
    'Arquivo enviado com sucesso!': ('File sent successfully!', 'fileSentSuccess'),
    'Banner / Capa': ('Banner / Cover', 'bannerCover'),
    'Banner de Boas-Vindas': ('Welcome Banner', 'welcomeBanner'),
    'Barra Inferior': ('Bottom Bar', 'bottomBar'),
    'Blog publicado com sucesso!': ('Blog published successfully!', 'blogPublishedSuccess'),
    'Broadcast enviado!': ('Broadcast sent!', 'broadcastSent'),
    'Buscar chat...': ('Search chat...', 'searchChatHint'),
    'Busque por comunidades, pessoas ou posts': ('Search communities, people or posts', 'searchEverythingHint'),
    'Carrossel': ('Carousel', 'carousel'),
    'Central de Ajuda': ('Help Center', 'helpCenter'),
    'Chat Privado': ('Private Chat', 'privateChatLabel'),
    'Chat em Grupo': ('Group Chat', 'groupChatLabel'),
    'Chats ao Vivo': ('Live Chats', 'liveChats'),
    'Check-In': ('Check-In', 'checkInLabel'),
    'Comece a conversa!': ('Start the conversation!', 'startConversation'),
    'Como funciona': ('How it works', 'howItWorks'),
    'Compartilhar Link': ('Share Link', 'shareLinkTitle'),
    'Copiado!': ('Copied!', 'copiedMsg'),
    'Copiar Link': ('Copy Link', 'copyLink'),
    'Criar Screening Room': ('Create Screening Room', 'createScreeningRoom'),
    'Deixe vazio para usar a bio global': ('Leave empty to use global bio', 'leaveEmptyBio'),
    'Deixe vazio para usar o global': ('Leave empty to use global', 'leaveEmptyGlobal'),
    'Deletar': ('Delete', 'deleteAction'),
    'Deletar Post': ('Delete Post', 'deletePost'),
    'Descreva o bug encontrado...': ('Describe the bug found...', 'describeBugHint'),
    'Descreva o link (opcional)...': ('Describe the link (optional)...', 'describeLinkHint'),
    'Destaques': ('Highlights', 'highlights'),
    'Detalhes adicionais (opcional)...': ('Additional details (optional)...', 'additionalDetailsHint'),
    'Diga algo...': ('Say something...', 'saySomethingHint'),
    'Digite a mensagem...': ('Type the message...', 'typeMessageHint'),
    'Digite a pergunta...': ('Type the question...', 'typeQuestionHint'),
    'Editar Mensagem': ('Edit Message', 'editMessage'),
    'Editar Post': ('Edit Post', 'editPost'),
    'Editar mensagem...': ('Edit message...', 'editMessageHint'),
    'Enquete criada com sucesso!': ('Poll created successfully!', 'pollCreatedSuccess'),
    'Entrar no Chat': ('Join Chat', 'joinChat'),
    'Entre em uma comunidade e comece a conversar!': ('Join a community and start chatting!', 'joinCommunityStartChat'),
    'Enviando imagem...': ('Sending image...', 'sendingImage'),
    'Enviar Broadcast': ('Send Broadcast', 'sendBroadcast'),
    'Enviar Gorjeta': ('Send Tip', 'sendTip'),
    'Enviar Props': ('Send Props', 'sendProps'),
    'Erro ao carregar posts': ('Error loading posts', 'errorLoadingPosts'),
    'Erro ao criar comunidade. Tente novamente.': ('Error creating community. Try again.', 'errorCreatingCommunity'),
    'Erro ao criar enquete. Tente novamente.': ('Error creating poll. Try again.', 'errorCreatingPoll'),
    'Erro ao criar quiz. Tente novamente.': ('Error creating quiz. Try again.', 'errorCreatingQuiz'),
    'Erro ao criar sala. Tente novamente.': ('Error creating room. Try again.', 'errorCreatingRoom'),
    'Erro ao desvincular. Tente novamente.': ('Error unlinking. Try again.', 'errorUnlinking'),
    'Erro ao encaminhar. Tente novamente.': ('Error forwarding. Try again.', 'errorForwarding'),
    'Erro ao publicar. Tente novamente.': ('Error publishing. Try again.', 'errorPublishing'),
    'Erro no check-in. Tente novamente.': ('Error checking in. Try again.', 'errorCheckIn'),
    'Escreva algo para o story': ('Write something for the story', 'writeStoryHint'),
    'Escreva aqui...': ('Write here...', 'writeHereHint'),
    'Escreva uma legenda...': ('Write a caption...', 'writeCaptionHint'),
    'Estilo dos Destaques': ('Highlights Style', 'highlightsStyle'),
    'Ex: Clique aqui': ('E.g.: Click here', 'clickHereExample'),
    'Excluir Chat': ('Delete Chat', 'deleteChatTitle'),
    'Excluir rascunho?': ('Delete draft?', 'deleteDraftQuestion'),
    'Exibe contagem de online na bottom bar': ('Show online count on bottom bar', 'showOnlineCount'),
    'Fazer Check-in': ('Do Check-in', 'doCheckIn'),
    'Feed Recente': ('Recent Feed', 'recentFeed'),
    'Flags Pendentes': ('Pending Flags', 'pendingFlags'),
    'Fundo do Chat': ('Chat Background', 'chatBackground'),
    'GIF adicionado ao post!': ('GIF added to the post!', 'gifAddedToPost'),
    'Girar': ('Rotate', 'rotate'),
    'Grid': ('Grid', 'grid'),
    'Imagem da Galeria': ('Gallery Image', 'galleryImage'),
    'Inserir Link': ('Insert Link', 'insertLink'),
    'Link ao clicar (opcional)': ('Link on click (optional)', 'linkOnClick'),
    'Link compartilhado com sucesso!': ('Link shared successfully!', 'linkSharedSuccess'),
    'Link copiado!': ('Link copied!', 'linkCopied'),
    'Link removido.': ('Link removed.', 'linkRemoved'),
    'Mais antigos': ('Oldest', 'oldest'),
    'Mais populares': ('Most popular', 'mostPopular'),
    'Mais recentes': ('Most recent', 'mostRecent'),
    'Membros Total': ('Total Members', 'totalMembers'),
    'Membros do Chat': ('Chat Members', 'chatMembers'),
    'Mensagem de Boas-Vindas': ('Welcome Message', 'welcomeMessage'),
    'Mensagens Fixadas': ('Pinned Messages', 'pinnedMessages'),
    'Nada para salvar': ('Nothing to save', 'nothingToSave'),
    'Nenhum GIF encontrado': ('No GIF found', 'noGifFound'),
    'Nenhum membro': ('No members', 'noMembers'),
    'Nenhum post encontrado': ('No post found', 'noPostFound'),
    'Nenhuma mensagem no mural': ('No messages on the wall', 'noWallMessages'),
    'Nome da Comunidade *': ('Community Name *', 'communityNameRequired2'),
    'Nome da sala': ('Room name', 'roomName'),
    'Novos Membros (7d)': ('New Members (7d)', 'newMembers7d'),
    'Oculta': ('Hidden', 'hiddenLabel'),
    'Ocultar Post': ('Hide Post', 'hidePost'),
    'Ordenar por': ('Sort by', 'sortBy'),
    'Ou digite um valor...': ('Or type a value...', 'orTypeValue'),
    'Perfil atualizado com sucesso!': ('Profile updated successfully!', 'profileUpdatedSuccess'),
    'Perfil da comunidade atualizado!': ('Community profile updated!', 'communityProfileUpdated'),
    'Pergunta & Resposta': ('Question & Answer', 'questionAndAnswer'),
    'Pergunta publicada com sucesso!': ('Question published successfully!', 'questionPublishedSuccess'),
    'Post atualizado!': ('Post updated!', 'postUpdated'),
    'Post criado com sucesso!': ('Post created successfully!', 'postCreatedSuccess'),
    'Post deletado': ('Post deleted', 'postDeleted'),
    'Post ocultado do seu feed': ('Post hidden from your feed', 'postHiddenFromFeed'),
    'Post publicado com sucesso!': ('Post published successfully!', 'postPublishedSuccess'),
    'Privado': ('Private', 'privateLabel'),
    'Procurar Meus Chats': ('Search My Chats', 'searchMyChats'),
    'Recompensas': ('Rewards', 'rewards'),
    'Reportar': ('Report', 'reportAction'),
    'Reportar Bug': ('Report Bug', 'reportBug'),
    'Sair da Conta': ('Log Out', 'logOutAction'),
    'Sair do Chat': ('Leave Chat', 'leaveChatTitle'),
    'Segure para favoritar': ('Hold to favorite', 'holdToFavorite'),
    'Selecione a comunidade destino para o crosspost': ('Select the destination community for crosspost', 'selectCrosspostCommunity'),
    'Selecione uma comunidade': ('Select a community', 'selectCommunity'),
    'Selecione uma imagem': ('Select an image', 'selectImage'),
    'Sorteio': ('Lucky Draw', 'luckyDraw'),
    'Story': ('Story', 'storyLabel'),
    'Tagline': ('Tagline', 'taglineLabel'),
    'Tem certeza que deseja sair deste chat?': ('Are you sure you want to leave this chat?', 'confirmLeaveChat'),
    'Tente a sorte por moedas extras!': ('Try your luck for extra coins!', 'tryLuckExtraCoins'),
    'Tipo de post': ('Post type', 'postType'),
    'Tirar Foto': ('Take Photo', 'takePhoto'),
    'Toque para adicionar imagem': ('Tap to add image', 'tapToAddImage'),
    'URL da imagem do banner': ('Banner image URL', 'bannerImageUrl'),
    'URL da imagem do banner (opcional)': ('Banner image URL (optional)', 'bannerImageUrlOptional'),
    'URL personalizada do fundo...': ('Custom background URL...', 'customBgUrlHint'),
    'Um banner customizado exibido no topo da home.': ('A custom banner displayed at the top of the home.', 'customBannerDesc'),
    'Ver Tudo': ('See All', 'seeAll'),
    'ou': ('or', 'orLabel'),
    'Reparar (50 moedas)': ('Repair (50 coins)', 'repairCoins'),
    'Texto do banner (ex: Bem-vindo!)': ('Banner text (e.g.: Welcome!)', 'bannerTextHint'),
    '1 dia': ('1 day', 'oneDay'),
    '1h': ('1h', 'oneHour'),
    '24h': ('24h', 'twentyFourHours'),
    '3 dias': ('3 days', 'threeDays'),
    '30 dias': ('30 days', 'thirtyDays'),
    '6h': ('6h', 'sixHours'),
    '7 dias': ('7 days', 'sevenDays'),
    'Nenhum item disponível': ('No item available', 'noItemAvailable'),
    'Buscar Usuário': ('Search User', 'searchUser'),
    'Configurações Globais': ('Global Settings', 'globalSettings'),
    'Relatórios': ('Reports', 'reportsTitle'),
    'Iniciar conversa com um usuário': ('Start conversation with a user', 'startConversationWithUser'),
    # Interpolated
    'Criar\\nComunidade': ('Create\\nCommunity', 'createCommunityNewline'),
    'Entrada\\nWiki': ('Wiki\\nEntry', 'wikiEntryNewline'),
    'Loja de\\nCoins': ('Coin\\nShop', 'coinShopNewline'),
    'Ranking\\nGlobal': ('Global\\nRanking', 'globalRankingNewline'),
}

# Interpolated strings that need methods
INTERPOLATED = {
    # '$amount coins transferidos!' => method
    'amountCoinsTransferred': {
        'abstract': '  String amountCoinsTransferred(int amount);',
        'pt': "  @override\n  String amountCoinsTransferred(int amount) => '\$amount coins transferidos!';",
        'en': "  @override\n  String amountCoinsTransferred(int amount) => '\$amount coins transferred!';",
        'old': "'$amount coins transferidos!'",
        'new': "s.amountCoinsTransferred(amount)",
    },
    'nicknameUnblocked': {
        'abstract': '  String nicknameUnblocked(String nickname);',
        'pt': "  @override\n  String nicknameUnblocked(String nickname) => '\$nickname desbloqueado';",
        'en': "  @override\n  String nicknameUnblocked(String nickname) => '\$nickname unblocked';",
        'old': "'$nickname desbloqueado'",
        'new': "s.nicknameUnblocked(nickname)",
    },
    'reactionSent': {
        'abstract': '  String reactionSent(String reaction);',
        'pt': "  @override\n  String reactionSent(String reaction) => '\$reaction enviado!';",
        'en': "  @override\n  String reactionSent(String reaction) => '\$reaction sent!';",
        'old': "'$reaction enviado!'",
        'new': "s.reactionSent(reaction)",
    },
    'propsAmountSent': {
        'abstract': '  String propsAmountSent(int amount);',
        'pt': "  @override\n  String propsAmountSent(int amount) => '\$amount props enviados!';",
        'en': "  @override\n  String propsAmountSent(int amount) => '\$amount props sent!';",
        'old': "'$selectedAmount props enviados!'",
        'new': "s.propsAmountSent(selectedAmount)",
    },
    'totalVotesLabel': {
        'abstract': '  String totalVotesLabel(int count);',
        'pt': "  @override\n  String totalVotesLabel(int count) => '\$count votos';",
        'en': "  @override\n  String totalVotesLabel(int count) => '\$count votes';",
        'old': "'$totalVotes votos'",
        'new': "s.totalVotesLabel(totalVotes)",
    },
    'postCommentsCountReplies': {
        'abstract': '  String postCommentsCountReplies(int count);',
        'pt': "  @override\n  String postCommentsCountReplies(int count) => '\$count respostas';",
        'en': "  @override\n  String postCommentsCountReplies(int count) => '\$count replies';",
        'old': "'${_post.commentsCount} respostas'",
        'new': "s.postCommentsCountReplies(_post.commentsCount)",
    },
    'coinsEarned': {
        'abstract': '  String coinsEarnedLabel(int coins);',
        'pt': "  @override\n  String coinsEarnedLabel(int coins) => '+\$coins Moedas';",
        'en': "  @override\n  String coinsEarnedLabel(int coins) => '+\$coins Coins';",
        'old': "'+$_coinsEarned Moedas'",
        'new': "s.coinsEarnedLabel(_coinsEarned)",
    },
    'xpEarned': {
        'abstract': '  String xpEarnedLabel(int xp);',
        'pt': "  @override\n  String xpEarnedLabel(int xp) => '+\$xp XP';",
        'en': "  @override\n  String xpEarnedLabel(int xp) => '+\$xp XP';",
        'old': "'+$_xpEarned XP'",
        'new': "s.xpEarnedLabel(_xpEarned)",
    },
    'rewardCoinsLabel': {
        'abstract': '  String rewardCoinsLabel(int coins);',
        'pt': "  @override\n  String rewardCoinsLabel(int coins) => '+\$coins moedas!';",
        'en': "  @override\n  String rewardCoinsLabel(int coins) => '+\$coins coins!';",
        'old': "'+$rewardCoins moedas!'",
        'new': "s.rewardCoinsLabel(rewardCoins)",
    },
    'providerUnlinked': {
        'abstract': '  String providerUnlinked(String provider);',
        'pt': "  @override\n  String providerUnlinked(String provider) => 'Conta \$provider desvinculada.';",
        'en': "  @override\n  String providerUnlinked(String provider) => '\$provider account unlinked.';",
        'old': "'Conta $provider desvinculada.'",
        'new': "s.providerUnlinked(provider)",
    },
    'costCoinsLabel': {
        'abstract': '  String costCoinsLabel(int amount);',
        'pt': "  @override\n  String costCoinsLabel(int amount) => 'Custo: \$amount coins';",
        'en': "  @override\n  String costCoinsLabel(int amount) => 'Cost: \$amount coins';",
        'old': "'Custo: $selectedAmount coins'",
        'new': "s.costCoinsLabel(selectedAmount)",
    },
    'leftCommunityName': {
        'abstract': '  String leftCommunityName(String name);',
        'pt': "  @override\n  String leftCommunityName(String name) => 'Você saiu de \"\$name\".';",
        'en': "  @override\n  String leftCommunityName(String name) => 'You left \"\$name\".';",
    },
}


def main():
    # Load existing keys
    with open(f"{PROJECT}/core/l10n/app_strings.dart", 'r') as f:
        existing = f.read()
    existing_keys = set(re.findall(r'String (?:get )?(\w+)', existing))
    
    # 1. Add simple strings
    abstract_additions = []
    pt_additions = []
    en_additions = []
    
    new_simple = {}
    for pt_str, (en_str, key) in SIMPLE.items():
        base_key = key
        counter = 2
        while key in existing_keys:
            key = f"{base_key}{counter}"
            counter += 1
        existing_keys.add(key)
        new_simple[pt_str] = (en_str, key)
        abstract_additions.append(f"  String get {key};")
        pt_escaped = pt_str.replace("'", "\\'")
        en_escaped = en_str.replace("'", "\\'")
        pt_additions.append(f"  @override\n  String get {key} => '{pt_escaped}';")
        en_additions.append(f"  @override\n  String get {key} => '{en_escaped}';")
    
    # 2. Add interpolated methods
    for key, data in INTERPOLATED.items():
        method_name = re.search(r'String (?:get )?(\w+)', data['abstract']).group(1)
        if method_name not in existing_keys:
            existing_keys.add(method_name)
            abstract_additions.append(data['abstract'])
            pt_additions.append(data['pt'])
            en_additions.append(data['en'])
    
    # Write to l10n files
    for filepath, additions, comment in [
        (f"{PROJECT}/core/l10n/app_strings.dart", abstract_additions, "// PASS 8 — NON-ACCENTED STRINGS"),
        (f"{PROJECT}/core/l10n/app_strings_pt.dart", pt_additions, "// PASS 8 — NON-ACCENTED STRINGS"),
        (f"{PROJECT}/core/l10n/app_strings_en.dart", en_additions, "// PASS 8 — NON-ACCENTED STRINGS"),
    ]:
        with open(filepath, 'r') as f:
            content = f.read()
        insert_text = f"\n  {comment}\n" + '\n'.join(additions) + '\n'
        content = content.rstrip().rstrip('}') + insert_text + '}\n'
        with open(filepath, 'w') as f:
            f.write(content)
    
    print(f"Added {len(abstract_additions)} new keys/methods to l10n files")
    
    # 3. Replace simple strings in source files
    sorted_replacements = sorted(new_simple.items(), key=lambda x: len(x[0]), reverse=True)
    
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
                
                new_lines.append(line)
            
            content = '\n'.join(new_lines)
        
        if content != original:
            content = re.sub(r'const Text\(s\.', 'Text(s.', content)
            content = re.sub(r'const Tab\(text: s\.', 'Tab(text: s.', content)
            with open(filepath, 'w') as f:
                f.write(content)
            modified += 1
            print(f"  ✓ {os.path.basename(filepath)}")
    
    print(f"\nModified: {modified} files with simple strings")
    
    # 4. Replace interpolated strings
    for key, data in INTERPOLATED.items():
        if 'old' in data and 'new' in data:
            for filepath in all_dart_files:
                with open(filepath, 'r') as f:
                    content = f.read()
                if data['old'] in content:
                    content = content.replace(data['old'], data['new'])
                    with open(filepath, 'w') as f:
                        f.write(content)
                    print(f"  ✓ {os.path.basename(filepath)}: replaced interpolated '{key}'")
    
    # 5. Handle special case: Você saiu de "${community.name}"
    for filepath in all_dart_files:
        with open(filepath, 'r') as f:
            content = f.read()
        old = """'Você saiu de "${community.name}".'"""
        if old in content:
            content = content.replace(old, "s.leftCommunityName(community.name)")
            with open(filepath, 'w') as f:
                f.write(content)
            print(f"  ✓ {os.path.basename(filepath)}: replaced leftCommunityName")
    
    print("\nPass 8 complete!")


if __name__ == '__main__':
    main()
