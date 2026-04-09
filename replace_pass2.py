#!/usr/bin/env python3
"""
Second pass: Replace remaining hardcoded Portuguese strings that weren't
in the original mapping. This handles SnackBar messages, error strings,
validation messages, and other UI text.

Strategy:
1. Add new keys to the i18n files for all remaining strings
2. Replace them in the source files
"""

import json
import re
import os

PROJECT = "/home/ubuntu/NexusHub/frontend/lib"

# Additional strings found in second pass
# Format: 'Portuguese string' -> ('english_translation', 'keyName')
ADDITIONAL_STRINGS = {
    # Auth
    'Faça login para continuar': ('Log in to continue', 'logInToContinue'),
    'Email inválido': ('Invalid email', 'invalidEmail'),
    'Informe sua senha': ('Enter your password', 'enterYourPassword'),
    'Digite seu email primeiro': ('Enter your email first', 'enterYourEmailFirst'),
    'Aceite os termos de uso para continuar': ('Accept the terms of use to continue', 'acceptTermsToContinue'),
    'Pular': ('Skip', 'skip'),
    'Pular por enquanto': ('Skip for now', 'skipForNow'),
    'Milhares de comunidades para explorar': ('Thousands of communities to explore', 'thousandsOfCommunities'),
    'Chat em tempo real com seus amigos': ('Real-time chat with your friends', 'realTimeChat'),
    'Personalize seu perfil e suba de nível': ('Customize your profile and level up', 'customizeProfile'),
    'Já tenho conta': ('I already have an account', 'alreadyHaveAccountShort'),
    'Erro ao salvar. Tente novamente.': ('Error saving. Try again.', 'errorSavingTryAgain'),
    'Erro ao criar conta. Tente novamente.': ('Error creating account. Try again.', 'errorCreatingAccount'),
    'Erro ao fazer login. Verifique suas credenciais.': ('Login error. Check your credentials.', 'errorLoginCredentials'),
    'Confirmar senha': ('Confirm password', 'confirmPassword'),
    'Mínimo 6 caracteres': ('Minimum 6 characters', 'minimum6Chars'),
    
    # Interest categories
    'Anime': ('Anime', 'interestAnime'),
    'Manga': ('Manga', 'interestManga'),
    'K-Pop': ('K-Pop', 'interestKpop'),
    'Moda': ('Fashion', 'interestFashion'),
    'Fotografia': ('Photography', 'interestPhotography'),
    'Ciência': ('Science', 'interestScience'),
    'Esportes': ('Sports', 'interestSports'),
    'Tecnologia': ('Technology', 'interestTechnology'),
    'Cosplay': ('Cosplay', 'interestCosplay'),
    'Espiritualidade': ('Spirituality', 'interestSpirituality'),
    'Culinária': ('Cooking', 'interestCooking'),
    'Viagem': ('Travel', 'interestTravel'),
    'Terror': ('Horror', 'interestHorror'),
    'Idiomas': ('Languages', 'interestLanguages'),
    'Quadrinhos': ('Comics', 'interestComics'),
    'Dança': ('Dance', 'interestDance'),
    'Natureza': ('Nature', 'interestNature'),
    
    # Chat
    'Nenhuma mensagem ainda': ('No messages yet', 'noMessagesYet'),
    'Nenhum emoji recente': ('No recent emoji', 'noRecentEmoji'),
    'Nomear link': ('Name link', 'nameLink'),
    'Nenhum membro encontrado': ('No member found', 'noMemberFound'),
    'Digite um nome para o grupo': ('Enter a group name', 'enterGroupName'),
    'Mensagem apagada': ('Message deleted', 'messageDeleted'),
    'Entre em uma comunidade primeiro': ('Join a community first', 'joinCommunityFirst'),
    'Erro ao enviar. Tente novamente.': ('Error sending. Try again.', 'errorSendingTryAgain'),
    'Erro ao sair do chat. Tente novamente.': ('Error leaving chat. Try again.', 'errorLeavingChat'),
    'Erro ao excluir o chat. Tente novamente.': ('Error deleting chat. Try again.', 'errorDeletingChat'),
    'Erro no upload. Tente novamente.': ('Upload error. Try again.', 'errorUploadTryAgain'),
    'Erro no upload do vídeo. Tente novamente.': ('Video upload error. Try again.', 'errorVideoUpload'),
    'Erro ao editar. Tente novamente.': ('Error editing. Try again.', 'errorEditingTryAgain'),
    'Erro ao apagar. Tente novamente.': ('Error deleting. Try again.', 'errorDeletingTryAgain'),
    'Erro ao entrar no chat. Tente novamente.': ('Error joining chat. Try again.', 'errorJoiningChat'),
    'Erro ao enviar áudio. Tente novamente.': ('Error sending audio. Try again.', 'errorSendingAudio'),
    'Info': ('Info', 'info'),
    'Novo Chat': ('New Chat', 'newChatTitle'),
    'Criar Grupo': ('Create Group', 'createGroup'),
    'Criar Chat Público': ('Create Public Chat', 'createPublicChat'),
    'Selecionar membros': ('Select members', 'selectMembers'),
    'Buscar membros...': ('Search members...', 'searchMembers'),
    'Nenhum membro selecionado': ('No members selected', 'noMembersSelected'),
    'selecionados': ('selected', 'selected'),
    'Descrição do grupo': ('Group description', 'groupDescription'),
    'Descrição do chat': ('Chat description', 'chatDescription'),
    'Nome do chat': ('Chat name', 'chatName'),
    'Criar chat público': ('Create public chat', 'createPublicChatAction'),
    'Criar grupo': ('Create group', 'createGroupAction'),
    'Erro ao criar grupo. Tente novamente.': ('Error creating group. Try again.', 'errorCreatingGroup'),
    'Erro ao criar chat. Tente novamente.': ('Error creating chat. Try again.', 'errorCreatingChat'),
    'Selecione pelo menos 1 membro': ('Select at least 1 member', 'selectAtLeast1Member'),
    'Mídia': ('Media', 'media'),
    'Documento': ('Document', 'document'),
    'Galeria': ('Gallery', 'gallery'),
    'Câmera': ('Camera', 'cameraAction'),
    'Arquivo': ('File', 'file'),
    'Localização': ('Location', 'location'),
    'Contato': ('Contact', 'contact'),
    
    # Communities
    'Nenhum chat nesta comunidade': ('No chats in this community', 'noChatsInCommunity'),
    'Chats da comunidade': ('Community chats', 'communityChats'),
    'Nenhum membro online': ('No members online', 'noMembersOnline'),
    'Projeções ao vivo': ('Live Projections', 'liveProjections'),
    'Nenhuma projeção': ('No projections', 'noProjections'),
    'Chats ao vivo': ('Live Chats', 'liveChats'),
    'Nenhum chat ao vivo': ('No live chats', 'noLiveChats'),
    'Fazer check-in': ('Do check-in', 'doCheckIn'),
    'Check-in realizado!': ('Check-in done!', 'checkInDone'),
    'Você já fez check-in hoje': ('You already checked in today', 'alreadyCheckedIn'),
    'Gerenciar': ('Manage', 'manage'),
    'Administração': ('Administration', 'administration'),
    'Informações': ('Information', 'information'),
    'Tipo de entrada': ('Entry type', 'entryTypeLabel'),
    'Aberta': ('Open', 'openEntry'),
    'Aprovação': ('Approval', 'approval'),
    'Convite': ('Invite', 'invite'),
    'Pública': ('Public', 'publicVisibility'),
    'Privada': ('Private', 'privateVisibility'),
    'Listada': ('Listed', 'listedVisibility'),
    'Não listada': ('Unlisted', 'unlistedVisibility'),
    'Cor do Tema': ('Theme Color', 'themeColorLabel'),
    'Idioma Principal': ('Primary Language', 'primaryLanguageLabel'),
    'Salvar alterações': ('Save changes', 'saveChanges'),
    'Alterações salvas': ('Changes saved', 'changesSaved'),
    'Erro ao salvar': ('Error saving', 'errorSaving'),
    'Total de membros': ('Total members', 'totalMembers'),
    'Posts esta semana': ('Posts this week', 'postsThisWeek'),
    'Chats ativos': ('Active chats', 'activeChats'),
    'Novos membros esta semana': ('New members this week', 'newMembersThisWeek'),
    'Módulos': ('Modules', 'modulesLabel'),
    'Acesso': ('Access', 'accessLabel'),
    'Visual': ('Visual', 'visualLabel'),
    'Layout': ('Layout', 'layout'),
    'Estatísticas': ('Statistics', 'statistics'),
    'Adicionar link': ('Add Link', 'addLink'),
    'Editar link': ('Edit Link', 'editLink'),
    'Título do link': ('Link Title', 'linkTitle'),
    'URL do link': ('Link URL', 'linkUrl'),
    'Link adicionado': ('Link added', 'linkAdded'),
    'Link atualizado': ('Link updated', 'linkUpdated'),
    'Link removido': ('Link removed', 'linkRemoved'),
    'Tem certeza que deseja remover este link?': ('Are you sure you want to remove this link?', 'confirmRemoveLink'),
    'Editar regras da comunidade': ('Edit Community Guidelines', 'editCommunityGuidelines'),
    'Regras da comunidade': ('Community Guidelines', 'communityGuidelines'),
    'Regras atualizadas': ('Guidelines updated', 'guidelinesUpdated'),
    'Erro ao atualizar regras': ('Error updating guidelines', 'errorUpdatingGuidelines'),
    'Nenhuma regra definida': ('No guidelines defined', 'noGuidelinesDefined'),
    'Escreva as regras da comunidade...': ('Write the community guidelines...', 'writeCommunityGuidelines'),
    'Líderes': ('Leaders', 'leaders'),
    'Curadores': ('Curators', 'curators'),
    'Moderadores': ('Moderators', 'moderators'),
    
    # Feed / Posts
    'Nenhum post nesta comunidade': ('No posts in this community', 'noPostsInCommunity'),
    'Post publicado!': ('Post published!', 'postPublished'),
    'Erro ao publicar': ('Error publishing', 'errorPublishing'),
    'Rascunho salvo': ('Draft saved', 'draftSaved'),
    'Post excluído': ('Post deleted', 'postDeleted'),
    'Rascunho excluído': ('Draft deleted', 'draftDeleted'),
    'Sem rascunhos': ('No drafts', 'noDrafts'),
    'Seus rascunhos aparecerão aqui': ('Your drafts will appear here', 'draftsWillAppearHere'),
    'Adicionar bloco': ('Add block', 'addBlock'),
    'Mover para cima': ('Move up', 'moveUp'),
    'Mover para baixo': ('Move down', 'moveDown'),
    'Remover bloco': ('Remove block', 'removeBlock'),
    'Parágrafo': ('Paragraph', 'paragraph'),
    'Cabeçalho': ('Header', 'header'),
    'Citação': ('Quote', 'quote'),
    'Código': ('Code', 'code'),
    'Divisor': ('Divider', 'dividerBlock'),
    'Cole o link aqui': ('Paste the link here', 'pasteLinkHere'),
    'Link inválido': ('Invalid link', 'invalidLink'),
    'Prévia do link': ('Link preview', 'linkPreview'),
    'Mínimo de 2 opções': ('Minimum 2 options', 'minimum2Options'),
    'Adicionar opção': ('Add option', 'addOptionAction'),
    'Resposta correta': ('Correct answer', 'correctAnswer'),
    'Explicação': ('Explanation', 'explanation'),
    'Adicionar pergunta': ('Add question', 'addQuestionAction'),
    'Correto!': ('Correct!', 'correct'),
    'Incorreto': ('Incorrect', 'incorrect'),
    'Encerrada': ('Closed', 'closed'),
    'votos': ('votes', 'votes'),
    'Votar': ('Vote', 'vote'),
    
    # Profile
    'Membro desde': ('Member since', 'memberSince'),
    'Dias na Sequência': ('Day Streak', 'dayStreak'),
    'Posts salvos são privados': ('Saved posts are private', 'savedPostsPrivate'),
    'Toque no ícone de bookmark nos posts para salvá-los': ('Tap the bookmark icon on posts to save them', 'tapBookmarkToSave'),
    'Escreva no mural...': ('Write on the wall...', 'writeOnWall'),
    'Compartilhar Perfil': ('Share Profile', 'shareProfileAction'),
    'Link do perfil copiado!': ('Profile link copied!', 'profileLinkCopiedMsg'),
    'Minhas Entradas Wiki': ('My Wiki Entries', 'myWikiEntriesTitle'),
    'Editar perfil da comunidade': ('Edit Community Profile', 'editCommunityProfile'),
    'Apelido local': ('Local nickname', 'localNickname'),
    'Bio local': ('Local bio', 'localBio'),
    'Perfil atualizado!': ('Profile updated!', 'profileUpdated'),
    'Erro ao atualizar perfil': ('Error updating profile', 'errorUpdatingProfile'),
    'Erro ao carregar perfil': ('Error loading profile', 'errorLoadingProfileMsg'),
    'Conexões': ('Connections', 'connectionsLabel'),
    
    # Gamification
    'Carteira': ('Wallet', 'walletTitle'),
    'Saldo': ('Balance', 'balance'),
    'Histórico': ('History', 'historyLabel'),
    'Transações': ('Transactions', 'transactions'),
    'Nenhuma transação': ('No transactions', 'noTransactions'),
    'Moedas grátis': ('Free Coins', 'freeCoins'),
    'Assistir anúncio': ('Watch Ad', 'watchAd'),
    'Recompensa diária': ('Daily Reward', 'dailyReward'),
    'Convidar amigos': ('Invite Friends', 'inviteFriends'),
    'Equipar': ('Equip', 'equip'),
    'Desequipar': ('Unequip', 'unequip'),
    'Equipado': ('Equipped', 'equipped'),
    'Classificação': ('Leaderboard', 'leaderboard'),
    'Posição': ('Position', 'position'),
    'Pontos': ('Points', 'points'),
    'Conquista desbloqueada!': ('Achievement unlocked!', 'achievementUnlocked'),
    'Nenhuma conquista ainda': ('No achievements yet', 'noAchievementsYet'),
    'Progresso': ('Progress', 'progress'),
    'Dia': ('Day', 'day'),
    'Dias': ('Days', 'days'),
    'Recompensa': ('Reward', 'reward'),
    
    # Store
    'Loja de moedas': ('Coin Shop', 'coinShop'),
    'Comprar': ('Buy', 'buyAction'),
    'Comprar moedas': ('Buy Coins', 'buyCoins'),
    'Pacotes': ('Packages', 'packages'),
    'Itens': ('Items', 'items'),
    'Molduras': ('Frames', 'frames'),
    'Títulos': ('Titles', 'titles'),
    'Fundos': ('Backgrounds', 'backgroundsLabel'),
    'Bolhas de chat': ('Chat Bubbles', 'chatBubbles'),
    'Compra realizada!': ('Purchase complete!', 'purchaseComplete'),
    'Saldo insuficiente': ('Insufficient balance', 'insufficientBalanceMsg'),
    'Erro na compra': ('Purchase error', 'purchaseError'),
    
    # Stories
    'Criar story': ('Create Story', 'createStory'),
    'Adicionar texto': ('Add text', 'addText'),
    'Adicionar sticker': ('Add sticker', 'addSticker'),
    'Publicar story': ('Publish story', 'publishStory'),
    'Story publicado!': ('Story published!', 'storyPublishedMsg'),
    'Nenhum story': ('No stories', 'noStories'),
    'Visualizações': ('Views', 'views'),
    
    # Live
    'Ao vivo': ('Live', 'live'),
    'Iniciar live': ('Start Live', 'startLive'),
    'Entrar na live': ('Join Live', 'joinLive'),
    'Encerrar live': ('End Live', 'endLive'),
    'Sala de exibição': ('Screening Room', 'screeningRoom'),
    'Nenhuma live no momento': ('No live streams right now', 'noLiveStreams'),
    'Espectadores': ('Viewers', 'viewers'),
    
    # Moderation
    'Ações de moderação': ('Moderation Actions', 'moderationActions'),
    'Nenhuma denúncia pendente': ('No pending reports', 'noPendingReportsMsg'),
    'Resolver': ('Resolve', 'resolve'),
    'Resolvido': ('Resolved', 'resolved'),
    'Ignorar': ('Ignore', 'ignore'),
    'Ação executada': ('Action executed', 'actionExecuted'),
    'Erro ao executar ação': ('Error executing action', 'errorExecutingAction'),
    'Conteúdo impróprio': ('Inappropriate content', 'inappropriateContent'),
    'Assédio': ('Harassment', 'harassment'),
    'Discurso de ódio': ('Hate speech', 'hateSpeech'),
    'Violência': ('Violence', 'violence'),
    'Descreva o motivo...': ('Describe the reason...', 'describeReason'),
    'Denúncia enviada': ('Report submitted', 'reportSubmitted'),
    'Obrigado por reportar': ('Thank you for reporting', 'thankYouForReporting'),
    'Analisaremos sua denúncia': ('We will review your report', 'weWillReviewReport'),
    'Motivo da denúncia': ('Report reason', 'reportReason'),
    'Denunciar conteúdo': ('Report content', 'reportContent'),
    
    # Settings
    'Conta': ('Account', 'accountLabel'),
    'Aparência': ('Appearance', 'appearanceLabel'),
    'Geral': ('General', 'generalLabel'),
    'Segurança': ('Security', 'securityLabel'),
    'Dispositivos': ('Devices', 'devices'),
    'Contas vinculadas': ('Linked Accounts', 'linkedAccounts'),
    'Permissões do app': ('App Permissions', 'appPermissions'),
    'Configurações de notificação': ('Notification Settings', 'notificationSettings'),
    'Configurações de privacidade': ('Privacy Settings', 'privacySettings'),
    'Dispositivo atual': ('Current device', 'currentDevice'),
    'Último acesso': ('Last access', 'lastAccess'),
    'Remover dispositivo': ('Remove device', 'removeDevice'),
    'Dispositivo removido': ('Device removed', 'deviceRemoved'),
    'Nenhum dispositivo encontrado': ('No devices found', 'noDevicesFound'),
    'Nenhum usuário bloqueado': ('No blocked users', 'noBlockedUsersMsg'),
    'Desbloquear': ('Unblock', 'unblockAction'),
    'Usuário desbloqueado': ('User unblocked', 'userUnblocked'),
    'Quem pode me enviar mensagens': ('Who can message me', 'whoCanMessageMe'),
    'Quem pode ver meu perfil': ('Who can see my profile', 'whoCanSeeProfile'),
    'Mostrar status online': ('Show online status', 'showOnlineStatus'),
    'Permitir convites de grupo': ('Allow group invites', 'allowGroupInvites'),
    'Exportar dados': ('Export Data', 'exportData'),
    'Dados exportados com sucesso': ('Data exported successfully', 'dataExported'),
    'Erro ao exportar dados': ('Error exporting data', 'errorExportingData'),
    'Termos de Uso': ('Terms of Use', 'termsOfUseTitle'),
    'Política de Privacidade': ('Privacy Policy', 'privacyPolicyTitle2'),
    
    # Notifications
    'Marcar tudo como lido': ('Mark all as read', 'markAllRead'),
    'Nenhuma notificação': ('No notifications', 'noNotificationsMsg'),
    
    # Wiki
    'Entrada aprovada': ('Entry approved', 'entryApproved'),
    'Entrada rejeitada': ('Entry rejected', 'entryRejected'),
    'Nenhuma entrada para revisar': ('No entries to review', 'noEntriesToReview'),
    
    # Shared folder
    'Pasta compartilhada': ('Shared Folder', 'sharedFolderTitle'),
    'Enviar arquivo': ('Upload file', 'uploadFile'),
    'Arquivo enviado': ('File uploaded', 'fileUploaded'),
    'Erro ao enviar arquivo': ('Error uploading file', 'errorUploadingFile'),
    'Excluir arquivo': ('Delete file', 'deleteFile'),
    'Arquivo excluído': ('File deleted', 'fileDeleted'),
    'Nenhum arquivo': ('No files', 'noFilesMsg'),
    'Tamanho': ('Size', 'size'),
    'Data': ('Date', 'date'),
    'Tipo': ('Type', 'type'),
    'Nome': ('Name', 'name'),
    'Filtrar': ('Filter', 'filter'),
    'Ordenar': ('Sort', 'sort'),
    'Grade': ('Grid', 'grid'),
    'Todos os arquivos': ('All files', 'allFiles'),
    'Imagens': ('Images', 'imagesLabel'),
    'Vídeos': ('Videos', 'videosLabel'),
    'Documentos': ('Documents', 'documents'),
    'Áudio': ('Audio', 'audio'),
    'Outros': ('Others', 'others'),
    
    # Music
    'Música': ('Music', 'musicLabel'),
    'Adicionar música': ('Add music', 'addMusic'),
    'Buscar música...': ('Search music...', 'searchMusic'),
    'Nenhuma música encontrada': ('No music found', 'noMusicFound'),
    
    # Search
    'Pessoas': ('People', 'people'),
    'membros': ('members', 'membersCount'),
    'Buscar comunidades, pessoas...': ('Search communities, people...', 'searchPlaceholder'),
    'Anônimo': ('Anonymous', 'anonymousLabel'),
    
    # Error messages from providers
    'Erro ao carregar perfil. Tente novamente.': ('Error loading profile. Try again.', 'errorLoadingProfileRetry'),
    'Erro no login com Google. Tente novamente.': ('Google login error. Try again.', 'errorGoogleLogin'),
    'Erro no login com Apple. Tente novamente.': ('Apple login error. Try again.', 'errorAppleLogin'),
    'Erro ao sair. Tente novamente.': ('Error logging out. Try again.', 'errorLoggingOut'),
    
    # Misc
    'Copiar mensagem': ('Copy message', 'copyMessage'),
    'Mensagem copiada': ('Message copied', 'messageCopied'),
    'Excluir mensagem': ('Delete message', 'deleteMessage'),
    'Tem certeza que deseja excluir esta mensagem?': ('Are you sure you want to delete this message?', 'confirmDeleteMessage'),
    'Mensagem excluída': ('Message deleted', 'messageDeletedConfirm'),
    'Moedas enviadas!': ('Coins sent!', 'coinsSent'),
    'Erro ao enviar moedas': ('Error sending coins', 'errorSendingCoins'),
    'Mensagem fixada': ('Message pinned', 'messagePinnedMsg'),
    'Mensagem desafixada': ('Message unpinned', 'messageUnpinned'),
    'Figurinhas': ('Stickers', 'stickersTab'),
    'Favoritos': ('Favorites', 'favorites'),
    'Recentes': ('Recent', 'recentLabel'),
    'Enviando...': ('Sending...', 'sending'),
    'Salvando...': ('Saving...', 'saving'),
    'Publicando...': ('Publishing...', 'publishing'),
    'Excluindo...': ('Deleting...', 'deleting'),
    'Processando...': ('Processing...', 'processing'),
    'Aguarde...': ('Please wait...', 'pleaseWait'),
    'Negrito': ('Bold', 'boldFormat'),
    'Itálico': ('Italic', 'italicFormat'),
    'Sublinhado': ('Underline', 'underline'),
    'Tachado': ('Strikethrough', 'strikethroughFormat'),
    'Inserir imagem': ('Insert image', 'insertImage'),
    'Inserir link': ('Insert link', 'insertLink'),
    'Escolher da galeria': ('Choose from gallery', 'chooseFromGallery'),
    'Tirar foto': ('Take photo', 'takePhoto'),
    'Alterar avatar': ('Change avatar', 'changeAvatar'),
    'Alterar banner': ('Change banner', 'changeBanner'),
    'Remover avatar': ('Remove avatar', 'removeAvatar'),
    'Imagem atualizada': ('Image updated', 'imageUpdated'),
    'Erro ao atualizar imagem': ('Error updating image', 'errorUpdatingImage'),
    'Erro ao carregar imagem': ('Error loading image', 'errorLoadingImage'),
    'Selecionar imagem': ('Select image', 'selectImage'),
    'Markdown': ('Markdown', 'markdown'),
    'Prévia': ('Preview', 'previewLabel'),
    'Editor': ('Editor', 'editorLabel'),
    'Heatmap de check-in': ('Check-in Heatmap', 'checkInHeatmap'),
    'Nenhum check-in': ('No check-ins', 'noCheckIns'),
    'Erro de conexão. Verifique sua internet.': ('Connection error. Check your internet.', 'connectionError'),
    'Sessão expirada. Faça login novamente.': ('Session expired. Please log in again.', 'sessionExpiredMsg'),
    'Permissão negada.': ('Permission denied.', 'permissionDeniedMsg'),
    'Não encontrado.': ('Not found.', 'notFoundMsg'),
    'Erro no servidor. Tente novamente mais tarde.': ('Server error. Please try again later.', 'serverErrorMsg'),
    'Sem permissão para esta ação': ('No permission for this action', 'noPermissionAction'),
    'Funcionalidade em desenvolvimento': ('Feature under development', 'featureUnderDev'),
    'Em breve': ('Coming soon', 'comingSoon'),
    'Enviamos um link de recuperação para seu email.': ('We sent a recovery link to your email.', 'recoverySent'),
    'Erro ao enviar link. Tente novamente.': ('Error sending link. Try again.', 'errorSendingLink'),
}

def main():
    # 1. Generate new keys for app_strings.dart, app_strings_pt.dart, app_strings_en.dart
    abstract_additions = []
    pt_additions = []
    en_additions = []
    
    for pt_str, (en_str, key) in sorted(ADDITIONAL_STRINGS.items(), key=lambda x: x[1][1]):
        abstract_additions.append(f"  String get {key};")
        pt_escaped = pt_str.replace("'", "\\'")
        en_escaped = en_str.replace("'", "\\'")
        pt_additions.append(f"  @override\n  String get {key} => '{pt_escaped}';")
        en_additions.append(f"  @override\n  String get {key} => '{en_escaped}';")
    
    # Append to the three files
    for filepath, additions, comment in [
        (f"{PROJECT}/core/l10n/app_strings.dart", abstract_additions, "// PASS 2 — STRINGS ADICIONAIS"),
        (f"{PROJECT}/core/l10n/app_strings_pt.dart", pt_additions, "// PASS 2 — STRINGS ADICIONAIS"),
        (f"{PROJECT}/core/l10n/app_strings_en.dart", en_additions, "// PASS 2 — ADDITIONAL STRINGS"),
    ]:
        with open(filepath, 'r') as f:
            content = f.read()
        
        # Insert before the closing brace
        insert_text = f"\n  {comment}\n" + '\n'.join(additions) + '\n'
        content = content.rstrip().rstrip('}') + insert_text + '}\n'
        
        with open(filepath, 'w') as f:
            f.write(content)
    
    print(f"Added {len(ADDITIONAL_STRINGS)} new keys to l10n files")
    
    # 2. Replace strings in all Dart files
    all_dart_files = []
    for root, dirs, files in os.walk(f"{PROJECT}/features"):
        for f in files:
            if f.endswith('.dart'):
                all_dart_files.append(os.path.join(root, f))
    for root, dirs, files in os.walk(f"{PROJECT}/core/widgets"):
        for f in files:
            if f.endswith('.dart'):
                all_dart_files.append(os.path.join(root, f))
    # Also include providers
    for root, dirs, files in os.walk(f"{PROJECT}/features"):
        for f in files:
            fp = os.path.join(root, f)
            if f.endswith('.dart') and '/providers/' in fp and fp not in all_dart_files:
                all_dart_files.append(fp)
    
    # Sort strings by length (longest first) for replacement
    sorted_strings = sorted(ADDITIONAL_STRINGS.items(), key=lambda x: len(x[0]), reverse=True)
    
    modified = 0
    for filepath in sorted(all_dart_files):
        with open(filepath, 'r') as f:
            content = f.read()
        
        original = content
        
        for pt_str, (en_str, key) in sorted_strings:
            replacement = f's.{key}'
            
            # Skip if this file doesn't contain this string
            if pt_str not in content:
                continue
            
            lines = content.split('\n')
            new_lines = []
            for line in lines:
                stripped = line.strip()
                if stripped.startswith('//') or stripped.startswith('///') or 'debugPrint' in line:
                    new_lines.append(line)
                    continue
                
                # Replace single-quoted
                escaped = pt_str.replace("'", "\\'")
                line = line.replace(f"'{escaped}'", replacement)
                line = line.replace(f"'{pt_str}'", replacement)
                
                # Replace double-quoted
                escaped_dq = pt_str.replace('"', '\\"')
                line = line.replace(f'"{escaped_dq}"', replacement)
                line = line.replace(f'"{pt_str}"', replacement)
                
                new_lines.append(line)
            
            content = '\n'.join(new_lines)
        
        if content != original:
            # Ensure the file has stringsProvider import and declaration
            if 'locale_provider.dart' not in content and 's.' in content:
                # Need to add import
                rel = filepath.split('/frontend/lib/')[-1]
                parts = rel.split('/')
                depth = len(parts) - 1
                prefix = '../' * depth
                locale_import = f"import '{prefix}core/l10n/locale_provider.dart';"
                
                lines = content.split('\n')
                last_import_idx = -1
                for i, line in enumerate(lines):
                    if line.strip().startswith('import '):
                        last_import_idx = i
                if last_import_idx >= 0:
                    lines.insert(last_import_idx + 1, locale_import)
                content = '\n'.join(lines)
            
            # Ensure riverpod import
            if 'flutter_riverpod' not in content and 'ref.watch' in content:
                lines = content.split('\n')
                for i, line in enumerate(lines):
                    if line.strip().startswith('import '):
                        lines.insert(i, "import 'package:flutter_riverpod/flutter_riverpod.dart';")
                        break
                content = '\n'.join(lines)
            
            with open(filepath, 'w') as f:
                f.write(content)
            modified += 1
            print(f"  ✓ {os.path.basename(filepath)}")
    
    print(f"\nModified: {modified} files in pass 2")


if __name__ == '__main__':
    main()
