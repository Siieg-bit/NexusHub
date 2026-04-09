#!/usr/bin/env python3
"""
Pass 5: Handle remaining Portuguese strings including:
- Simple strings that were missed
- Strings with interpolation ($variable) - convert to methods with parameters
- Long template strings
"""

import os
import re
import json

PROJECT = "/home/ubuntu/NexusHub/frontend/lib"

# Simple strings (no interpolation) - direct replacement
SIMPLE_STRINGS = {
    'Adicionar Música': ('Add Music', 'addMusicAction'),
    'Adicionar Opção': ('Add Option', 'addOptionLabel'),
    'Adicionar Vídeo': ('Add Video', 'addVideoAction'),
    'Adicione pelo menos 2 opções': ('Add at least 2 options', 'addAtLeast2Options'),
    'Alertas de moderação': ('Moderation alerts', 'moderationAlerts'),
    'Amino ID do destinatário': ('Recipient Amino ID', 'recipientAminoId'),
    'Amino ID do usuário': ('User Amino ID', 'userAminoId'),
    'Aplicar um strike (3 strikes = ban automático)': ('Apply a strike (3 strikes = auto ban)', 'applyStrikeDesc'),
    'Arquivo não encontrado.': ('File not found.', 'fileNotFoundMsg'),
    'Assistir Anúncio': ('Watch Ad', 'watchAdAction'),
    'Assistir Anúncios': ('Watch Ads', 'watchAdsAction'),
    'Assistir Vídeo': ('Watch Video', 'watchVideoAction'),
    'Atividades Diárias': ('Daily Activities', 'dailyActivities'),
    'Ação de Moderação': ('Moderation Action', 'moderationActionTitle'),
    'Ação de moderação': ('Moderation action', 'moderationActionLower'),
    'Ações de Moderação': ('Moderation Actions', 'moderationActionsTitle'),
    'Bem-vindo à comunidade!': ('Welcome to the community!', 'welcomeToCommunity'),
    'Campos vazios usarão seu perfil global.': ('Empty fields will use your global profile.', 'emptyFieldsGlobal'),
    'Chat Público': ('Public Chat', 'publicChatLabel'),
    'Chat excluído.': ('Chat deleted.', 'chatDeletedMsg'),
    'Chats Públicos': ('Public Chats', 'publicChatsLabel'),
    'Check-in Completo!': ('Check-in Complete!', 'checkInComplete'),
    'Check-in Diário': ('Daily Check-in', 'dailyCheckIn'),
    'Comunidade não encontrada.': ('Community not found.', 'communityNotFound'),
    'Configurações de Notificação Push': ('Push Notification Settings', 'pushNotificationSettings'),
    'Configurações do Chat': ('Chat Settings', 'chatSettingsTitle'),
    'Configurações salvas!': ('Settings saved!', 'settingsSaved'),
    'Conteúdo não pode estar vazio': ('Content cannot be empty', 'contentCannotBeEmpty'),
    'Customização Visual': ('Visual Customization', 'visualCustomization'),
    'Denúncias Pendentes': ('Pending Reports', 'pendingReports'),
    'Discussões e Debates': ('Discussions and Debates', 'discussionsAndDebates'),
    'Duração do Destaque': ('Highlight Duration', 'highlightDuration'),
    'Enviar Denúncia': ('Submit Report', 'submitReport'),
    'Erro ao alterar fixação.': ('Error changing pin.', 'errorChangingPin'),
    'Erro ao carregar anúncio. Tente novamente.': ('Error loading ad. Try again.', 'errorLoadingAd'),
    'Erro ao executar ação. Tente novamente.': ('Error executing action. Try again.', 'errorExecutingActionRetry'),
    'Esta ação já foi realizada.': ('This action has already been performed.', 'actionAlreadyPerformed'),
    'Esta ação não pode ser desfeita.': ('This action cannot be undone.', 'actionCannotBeUndone'),
    'Estatísticas da Comunidade': ('Community Statistics', 'communityStatistics'),
    'Este Mês': ('This Month', 'thisMonth'),
    'Este convite é inválido ou expirou.': ('This invite is invalid or expired.', 'inviteInvalidOrExpired'),
    'Este item já existe.': ('This item already exists.', 'itemAlreadyExists'),
    'Executar Ação': ('Execute Action', 'executeAction'),
    'Falsidade Ideológica': ('Identity Fraud', 'identityFraud'),
    'Funcionalidade temporariamente indisponível.': ('Feature temporarily unavailable.', 'featureTemporarilyUnavailable'),
    'Habilitar wiki/catálogo': ('Enable wiki/catalog', 'enableWikiCatalog'),
    'Histórico de Transações': ('Transaction History', 'transactionHistory'),
    'Já tem conta? ': ('Already have an account? ', 'alreadyHaveAccountQuestion'),
    'Moderação': ('Moderation', 'moderationLabel'),
    'Mostrar Botão Criar (+)': ('Show Create Button (+)', 'showCreateButton'),
    'Módulos Ativos': ('Active Modules', 'activeModules'),
    'Nenhum chat público ainda.': ('No public chats yet.', 'noPublicChatsYet'),
    'Nenhum conteúdo ainda...': ('No content yet...', 'noContentYet'),
    'Nome de usuário não permitido': ('Username not allowed', 'usernameNotAllowed'),
    'Notificações Push': ('Push Notifications', 'pushNotifications'),
    'Não Listada': ('Unlisted', 'unlistedLabel'),
    'Não Perturbe': ('Do Not Disturb', 'doNotDisturb'),
    'Opções Avançadas': ('Advanced Options', 'advancedOptions'),
    'Pausar Notificações': ('Pause Notifications', 'pauseNotifications2'),
    'Perfil Público': ('Public Profile', 'publicProfile'),
    'Post não encontrado.': ('Post not found.', 'postNotFoundMsg'),
    'Preencha título e URL': ('Fill in title and URL', 'fillTitleAndUrl'),
    'Próximo Post': ('Next Post', 'nextPost'),
    'Recomendações Musicais': ('Music Recommendations', 'musicRecommendations'),
    'Reportar Conteúdo': ('Report Content', 'reportContentTitle'),
    'Requer Aprovação': ('Requires Approval', 'requiresApproval'),
    'Resetar para Padrão': ('Reset to Default', 'resetToDefault'),
    'Salvar Alterações': ('Save Changes', 'saveChangesAction'),
    'Sequência Perdida': ('Streak Lost', 'streakLost'),
    'Seções da Página Inicial': ('Home Page Sections', 'homePageSections'),
    'Subir de Nível': ('Level Up', 'levelUpAction'),
    'Subiu de Nível': ('Leveled Up', 'leveledUp'),
    'Tipo de Ação': ('Action Type', 'actionType'),
    'Tipo de arquivo não permitido.': ('File type not allowed.', 'fileTypeNotAllowed'),
    'Título (opcional)...': ('Title (optional)...', 'titleOptionalHint'),
    'Título do Quiz': ('Quiz Title', 'quizTitle'),
    'Título do blog...': ('Blog title...', 'blogTitleHint'),
    'Título do post...': ('Post title...', 'postTitleHint'),
    'Título do vídeo (opcional)': ('Video title (optional)', 'videoTitleOptional'),
    'Título...': ('Title...', 'titleHint'),
    'Valor inválido.': ('Invalid value.', 'invalidValue'),
    'Vamos Começar!': ('Let\'s Go!', 'letsGo'),
    'Vídeo da Galeria': ('Gallery Video', 'galleryVideo'),
    'Ícone da Comunidade': ('Community Icon', 'communityIcon'),
    'Subtítulo...': ('Subtitle...', 'subtitleHint'),
    'Configuração Atual': ('Current Configuration', 'currentConfiguration'),
    'Art Theft / Plágio': ('Art Theft / Plagiarism', 'artTheftPlagiarism'),
    'Autolesão / Suicídio': ('Self-harm / Suicide', 'selfHarmSuicide'),
    'Bullying / Assédio': ('Bullying / Harassment', 'bullyingHarassment'),
    'Português (Brasil)': ('Portuguese (Brazil)', 'portugueseBrazil'),
    'URL da imagem do ícone': ('Icon image URL', 'iconImageUrl'),
    'Escreva seu conteúdo aqui...': ('Write your content here...', 'writeContentHere'),
    'Não tem conta? ': ('Don\'t have an account? ', 'dontHaveAccount'),
    'Você entrou na comunidade!': ('You joined the community!', 'joinedCommunity'),
    'Você entrou no chat!': ('You joined the chat!', 'joinedChat'),
    'Você saiu do chat.': ('You left the chat.', 'leftChat'),
    'Você saiu do grupo.': ('You left the group.', 'leftGroup'),
    'Você já faz parte desta comunidade.': ('You are already part of this community.', 'alreadyInCommunity'),
    'Você já é membro desta comunidade.': ('You are already a member of this community.', 'alreadyMemberCommunity'),
    'Você não é membro desta comunidade.': ('You are not a member of this community.', 'notMemberCommunity'),
    'Você precisa estar logado.': ('You need to be logged in.', 'needToBeLoggedIn'),
    'Você precisa estar logado para comentar.': ('You need to be logged in to comment.', 'needLoginToComment'),
    'Você precisa estar logado para criar uma comunidade.': ('You need to be logged in to create a community.', 'needLoginToCreateCommunity'),
    'Não é possível enviar DM para si mesmo': ('Cannot send DM to yourself', 'cannotDmYourself'),
    'Você não é membro deste chat.': ('You are not a member of this chat.', 'notMemberChat'),
    'Mais sorte na próxima vez!': ('Better luck next time!', 'betterLuckNextTime'),
    'Melhor custo-benefício!': ('Best value!', 'bestValue'),
    'O que você quer saber?': ('What do you want to know?', 'whatDoYouWantToKnow'),
    'Ocultar o post sem deletá-lo': ('Hide the post without deleting it', 'hidePostDesc'),
    'Configurações de notificação em breve!': ('Notification settings coming soon!', 'notificationSettingsComingSoon'),
    'Denúncia enviada. Obrigado!': ('Report submitted. Thank you!', 'reportSubmittedThankYou'),
    'Denúncia enviada. Obrigado por reportar!': ('Report submitted. Thank you for reporting!', 'reportSubmittedThanks'),
    'Explore e entre em comunidades para começar!': ('Explore and join communities to get started!', 'exploreCommunities'),
    'Seu feed está vazio': ('Your feed is empty', 'feedEmptyMsg'),
    'Curtidas, comentários e seguidores': ('Likes, comments and followers', 'likesCommentsFollowers'),
    'Notificações de novas mensagens': ('New message notifications', 'newMessageNotifications'),
    'Notificações gerais do NexusHub': ('General NexusHub notifications', 'generalNotifications'),
    'Atualizações das suas comunidades': ('Updates from your communities', 'communityUpdates'),
    'Avisos, strikes e ações sobre seu conteúdo': ('Warnings, strikes and actions on your content', 'warningsStrikesActions'),
    'Câmera, microfone, notificações': ('Camera, microphone, notifications', 'cameraPermissionsDesc'),
    'Permitir destaque de conteúdo': ('Allow content highlight', 'allowContentHighlightSetting'),
    'Desabilitar comentários no perfil': ('Disable profile comments', 'disableProfileCommentsSetting'),
    'Apenas letras, números, _, . e -': ('Only letters, numbers, _, . and -', 'usernameCharsAllowed'),
    'Opções (marque a correta)': ('Options (mark the correct one)', 'optionsMarkCorrect'),
    'Insira um link válido (https://...)': ('Enter a valid link (https://...)', 'enterValidLink'),
    'Máximo 10.000 caracteres': ('Maximum 10,000 characters', 'max10000Chars'),
    'Máximo 24 caracteres': ('Maximum 24 characters', 'max24Chars'),
    'Máximo 30 caracteres': ('Maximum 30 characters', 'max30Chars'),
    'Máximo 500 caracteres': ('Maximum 500 characters', 'max500Chars'),
    'Mínimo 3 caracteres': ('Minimum 3 characters', 'min3Chars'),
    'Nome da música (ex: Artist - Song)': ('Song name (e.g.: Artist - Song)', 'songNameHint'),
    'Música adicionada ao post!': ('Music added to the post!', 'musicAddedToPost'),
    'Nenhum comentário': ('No comments', 'noCommentsLabel'),
    'Referência inválida. O item pode ter sido removido.': ('Invalid reference. The item may have been removed.', 'invalidReference'),
    'Sem permissão para fazer upload neste local.': ('No permission to upload in this location.', 'noUploadPermission'),
    'Você não tem permissão para editar este post.': ('You do not have permission to edit this post.', 'noPermissionEditPost'),
    'Faça check-in para ganhar recompensas': ('Check in to earn rewards', 'checkInForRewards'),
    'Faça check-in todos os dias para manter sua sequência': ('Check in every day to keep your streak', 'checkInKeepStreak'),
    'Faça check-in todos os dias': ('Check in every day', 'checkInEveryDay'),
    'Faça login para aceitar o convite.': ('Log in to accept the invite.', 'loginToAcceptInvite'),
    'Não foi possível aceitar o convite agora.': ('Could not accept the invite now.', 'couldNotAcceptInvite'),
    'Não foi possível confirmar sua participação neste chat.': ('Could not confirm your participation in this chat.', 'couldNotConfirmParticipation'),
    'Não foi possível processar a assinatura.': ('Could not process the subscription.', 'couldNotProcessSubscription'),
    'Perca um dia e a sequência volta para 1': ('Miss a day and the streak resets to 1', 'streakResetsDesc'),
    'Sequência maior = mais XP e moedas': ('Higher streak = more XP and coins', 'higherStreakDesc'),
    'Toque em + para adicionar um vídeo': ('Tap + to add a video', 'tapToAddVideo'),
    'Use o botão + para criar um!': ('Use the + button to create one!', 'useButtonToCreate'),
    'Aguardando o host adicionar um vídeo...': ('Waiting for the host to add a video...', 'waitingForHostVideo'),
    'Você ainda não entrou em nenhum chat nesta comunidade.': ('You haven\'t joined any chats in this community yet.', 'noChatsJoinedYet'),
    'Conte um pouco sobre você...': ('Tell us a bit about yourself...', 'tellAboutYourself'),
    'Escolha algo memorável!': ('Choose something memorable!', 'chooseSomethingMemorable'),
    'Descreva o motivo da ação...': ('Describe the reason for the action...', 'describeActionReason'),
    'Informe o motivo da ação': ('Inform the reason for the action', 'informActionReasonLabel'),
    'Limite diário de anúncios atingido. Tente amanhã!': ('Daily ad limit reached. Try tomorrow!', 'dailyAdLimitReached'),
    'Não autenticado': ('Not authenticated', 'notAuthenticatedMsg'),
    'não aceita mensagens diretas': ('does not accept direct messages', 'doesNotAcceptDMs'),
    'Ninguém pode comentar no seu mural': ('No one can comment on your wall', 'noOneCanCommentWallDesc'),
    'Apareça como offline para todos os usuários': ('Appear offline to all users', 'appearOfflineAllUsers'),
    'Mostrar quando você está online': ('Show when you are online', 'showWhenOnlineDesc'),
    'Apenas amigos': ('Friends only', 'friendsOnlyLabel'),
    'Apenas de amigos': ('From friends only', 'fromFriendsOnlyLabel'),
    'Apenas quem eu sigo de volta': ('Only those I follow back', 'onlyFollowBackLabel'),
    'Apenas membros convidados podem entrar': ('Only invited members can join', 'onlyInvitedMembersDesc'),
    'Novos membros precisam de aprovação': ('New members need approval', 'newMembersNeedApprovalDesc'),
    'Acessível apenas por link direto': ('Accessible only by direct link', 'accessibleByDirectLinkDesc'),
    'Impede que novos usuários iniciem conversas': ('Prevents new users from starting conversations', 'preventNewUsersDesc'),
    'Enviar mensagem para todos os usuários': ('Send message to all users', 'sendMessageAllUsers'),
    'Banir o usuário da comunidade': ('Ban user from community', 'banUserDesc'),
    'Remover o usuário da comunidade (pode voltar a entrar)': ('Remove user from community (can rejoin)', 'removeUserDesc'),
    'Fixar o post no topo do feed (máx 3 fixados)': ('Pin post to top of feed (max 3 pinned)', 'pinPostDesc'),
    'Reconheça um membro': ('Recognize a member', 'recognizeMemberDesc'),
    'Selecione o motivo da denúncia': ('Select the report reason', 'selectReportReasonLabel'),
    'Selecione o tipo de denúncia': ('Select the report type', 'selectReportTypeLabel'),
    'Cole o link do vídeo (YouTube, etc.)': ('Paste the video link (YouTube, etc.)', 'pasteVideoLink'),
    'URL do arquivo de áudio (.mp3, .ogg)': ('Audio file URL (.mp3, .ogg)', 'audioFileUrl'),
    'Faça check-in e ganhe reputação para aparecer aqui!': ('Check in and earn reputation to appear here!', 'checkInEarnReputation'),
    'Participe das discussões': ('Join the discussions', 'joinDiscussionsDesc'),
    'Publique conteúdo na comunidade': ('Publish content in the community', 'publishContentDesc'),
    'Acerte quizzes da comunidade': ('Get community quizzes right', 'getCommunityQuizzesDesc'),
    'Ganhe moedas ao subir de nível': ('Earn coins when leveling up', 'earnCoinsLevelUpDesc'),
    'Liberar espaço de armazenamento': ('Free up storage space', 'freeUpStorageDesc'),
    'Baixar uma cópia dos seus dados': ('Download a copy of your data', 'downloadDataDesc'),
    'Sons de notificação dentro do app': ('Notification sounds within the app', 'notificationSoundsDesc'),
    'Vibrar ao receber notificações': ('Vibrate on notifications', 'vibrateOnNotificationsDesc'),
    'Pausar todas as notificações temporariamente': ('Pause all notifications temporarily', 'pauseNotificationsDesc'),
    'Sem anúncios': ('No ads', 'noAdsLabel'),
    'Acesso antecipado a novidades': ('Early access to new features', 'earlyAccessDesc'),
    'Badge exclusiva no perfil': ('Exclusive profile badge', 'exclusiveBadgeDesc'),
    '200 moedas/mês grátis': ('200 coins/month free', 'freeCoinsMonth'),
    '7 dias consecutivos = bônus especial!': ('7 consecutive days = special bonus!', 'consecutiveDaysBonus'),
    'Completamente invisível': ('Completely invisible', 'completelyInvisibleDesc'),
    'Categorias de tópicos': ('Topic categories', 'topicCategoriesLabel'),
    'Comunicação': ('Communication', 'communicationLabel'),
    'Criar nova publicação': ('Create new post', 'createNewPostLabel'),
    'Dados inválidos': ('Invalid data', 'invalidDataMsg'),
    'Nenhuma ação de moderação registrada': ('No moderation actions recorded', 'noModerationActionsMsg'),
    'Nenhuma conexão': ('No connections', 'noConnectionsMsg'),
    'Nenhuma conquista disponível': ('No achievements available', 'noAchievementsAvailableMsg'),
    'Nenhuma seção habilitada': ('No sections enabled', 'noSectionsEnabledMsg'),
    'Nenhuma transação ainda': ('No transactions yet', 'noTransactionsYetMsg'),
    'Nome é obrigatório': ('Name is required', 'nameRequiredMsg'),
    'Não vinculado': ('Not linked', 'notLinkedLabel'),
    'O título do quiz é obrigatório': ('The quiz title is required', 'quizTitleRequiredMsg'),
    'O título é obrigatório': ('The title is required', 'titleRequiredMsg'),
    'Obrigatório': ('Required', 'requiredLabel'),
    'Ofertas não disponíveis no momento': ('Offers not available at the moment', 'offersNotAvailableMsg'),
    'Opções': ('Options', 'optionsLabelGeneral'),
    'Pacote não encontrado': ('Package not found', 'packageNotFoundMsg'),
    'Preferências': ('Preferences', 'preferencesLabel'),
    'Projeção': ('Projection', 'projectionLabel'),
    'Público': ('Public', 'publicLabelGeneral'),
    'Relatórios': ('Reports', 'reportsLabelGeneral'),
    'Armazenamento': ('Storage', 'storageLabel'),
    'Assinar': ('Subscribe', 'subscribeAction'),
    'Assinaturas': ('Subscriptions', 'subscriptionsLabel'),
    'Assistir': ('Watch', 'watchLabel'),
    'Menções': ('Mentions', 'mentionsLabel'),
    'Notificação': ('Notification', 'notificationSingle'),
    'Alertas': ('Alerts', 'alertsLabel'),
    'Alterar': ('Change', 'changeLabel'),
    'Biografia': ('Biography', 'biographyLabel'),
    'Bolha': ('Bubble', 'bubbleLabel'),
    'Bolhas': ('Bubbles', 'bubblesLabel'),
    'Buscas recentes': ('Recent searches', 'recentSearchesLabel'),
    'Busque artigos wiki desta comunidade': ('Search wiki articles in this community', 'searchWikiArticlesHint'),
    'Busque membros desta comunidade': ('Search members of this community', 'searchCommunityMembersHint'),
    'Bio nesta comunidade': ('Bio in this community', 'bioInCommunityLabel'),
    'Ativas': ('Active', 'activeLabelFem'),
    'Atual': ('Current', 'currentLabelGeneral'),
    'Lendário': ('Legendary', 'legendaryLabel'),
    'Mítico': ('Mythical', 'mythicalLabel'),
    'Aprendiz': ('Apprentice', 'apprenticeLabel'),
    'Aventureiro': ('Adventurer', 'adventurerLabel'),
    'Vibração': ('Vibration', 'vibrationLabel'),
    'Vídeo': ('Video', 'videoLabelGeneral'),
    'Usuários': ('Users', 'usersLabelGeneral'),
    'Ação': ('Action', 'actionLabelGeneral'),
    'Ações': ('Actions', 'actionsLabelGeneral'),
    'Aviso da moderação': ('Moderation warning', 'moderationWarningLabel'),
    'A pergunta da enquete é obrigatória': ('The poll question is required', 'pollQuestionRequiredMsg'),
    'A pergunta é obrigatória': ('The question is required', 'questionRequiredMsg'),
    'Anúncio não disponível no momento': ('Ad not available at the moment', 'adNotAvailableMsg'),
    'Layout resetado para o padrão': ('Layout reset to default', 'layoutResetMsg'),
    'Nenhum comentário no mural': ('No comments on the wall', 'noWallCommentsMsg'),
    'Nenhum usuário encontrado': ('No user found', 'noUserFoundMsg'),
    'Post não encontrado ou sem permissão': ('Post not found or no permission', 'postNotFoundPermission'),
    'Preencha o título ou conteúdo': ('Fill in the title or content', 'fillTitleOrContentMsg'),
    'Seu identificador único': ('Your unique identifier', 'uniqueIdentifierLabel'),
    'Seus rascunhos de posts aparecerão aqui': ('Your post drafts will appear here', 'postDraftsHere'),
    'Remover a fixação do post': ('Unpin the post', 'unpinPostAction'),
    'Remover o ban do usuário': ('Remove user ban', 'removeUserBanAction'),
    'Não é possível enviar mensagem para este usuário': ('Cannot send message to this user', 'cannotMessageUserMsg'),
    'Conexões': ('Connections', 'connectionsLabelGeneral'),
    'Pergunte à comunidade': ('Ask the community', 'askCommunityHint'),
    'Permitir comentários': ('Allow comments', 'allowCommentsLabel'),
    'Aceitar convite': ('Accept invite', 'acceptInviteAction'),
    'Adicionado aos favoritos': ('Added to favorites', 'addedToFavoritesMsg'),
    'Adicione pelo menos uma imagem': ('Add at least one image', 'addAtLeastOneImageMsg'),
    'Adicione pelo menos uma pergunta': ('Add at least one question', 'addAtLeastOneQuestionMsg'),
    'Escreva sua bio... Use **negrito**, *itálico*, ~~tachado~~': ('Write your bio... Use **bold**, *italic*, ~~strikethrough~~', 'writeBioHint'),
    'Ex: Qual é o melhor anime da temporada?': ('E.g.: What is the best anime of the season?', 'pollExampleHint'),
    'Ex: Quanto você sabe sobre Naruto?': ('E.g.: How much do you know about Naruto?', 'quizExampleHint'),
    'Aceito os Termos de Uso e Política de Privacidade': ('I accept the Terms of Use and Privacy Policy', 'acceptTermsAndPrivacy'),
    'Ao continuar, você concorda com os Termos de Uso\ne Política de Privacidade.': ('By continuing, you agree to the Terms of Use\nand Privacy Policy.', 'agreeTermsAndPrivacy'),
    'Quando alguém comenta no seu post': ('When someone comments on your post', 'whenSomeoneCommentsNotif'),
    'Quando alguém começa a te seguir': ('When someone starts following you', 'whenSomeoneFollowsNotif'),
    'Quando alguém curte seu post': ('When someone likes your post', 'whenSomeoneLikesNotif'),
    'Quando alguém menciona você': ('When someone mentions you', 'whenSomeoneMentionsNotif'),
    'Quando sobe de nível': ('When you level up', 'whenLevelUpNotif'),
    'Quando alguém interagir com você,\naparecerá aqui': ('When someone interacts with you,\nit will appear here', 'interactionsAppearHere'),
    'Você perdeu sua sequência! Gaste moedas para recuperá-la.': ('You lost your streak! Spend coins to recover it.', 'streakLostRecoverMsg'),
    'Você está postando muito rápido. Aguarde um pouco antes de criar outro post.': ('You are posting too fast. Wait a bit before creating another post.', 'postingTooFast'),
    'Você já enviou muitas denúncias recentemente. Tente novamente mais tarde.': ('You have sent too many reports recently. Try again later.', 'tooManyReports'),
    'Você já fez check-in hoje nesta comunidade!': ('You already checked in today in this community!', 'alreadyCheckedInCommunity'),
    'Você já fez check-in hoje!': ('You already checked in today!', 'alreadyCheckedInToday'),
    'Muitas transferências em pouco tempo. Aguarde antes de transferir novamente.': ('Too many transfers in a short time. Wait before transferring again.', 'tooManyTransfers'),
    'Muitos comentários em pouco tempo. Aguarde um momento.': ('Too many comments in a short time. Wait a moment.', 'tooManyComments'),
    'Esta mensagem será enviada para todos os membros da comunidade.': ('This message will be sent to all community members.', 'messageToAllMembers'),
    'Estas configurações se aplicam apenas a esta comunidade. ': ('These settings apply only to this community. ', 'settingsApplyOnlyCommunity'),
    'Usuários bloqueados não podem ver seu perfil\n': ('Blocked users cannot see your profile\n', 'blockedUsersCannotSeeProfile'),
    'Isso vai limpar dados temporários salvos localmente. ': ('This will clear temporary data saved locally. ', 'clearTempDataDesc'),
    'A conversa será removida da sua lista.': ('The conversation will be removed from your list.', 'conversationRemovedFromList'),
    'Para voltar, você precisará de um novo convite.': ('To come back, you will need a new invite.', 'needNewInvite'),
    'Tem certeza que deseja apagar este chat? Esta ação não pode ser desfeita.': ('Are you sure you want to delete this chat? This action cannot be undone.', 'confirmDeleteChat'),
    'Tem certeza que deseja deletar este post? Esta ação não pode ser desfeita.': ('Are you sure you want to delete this post? This action cannot be undone.', 'confirmDeletePost'),
    'Tem certeza que deseja excluir este chat? Esta ação não pode ser desfeita.': ('Are you sure you want to delete this chat? This action cannot be undone.', 'confirmDeleteChat2'),
    'Adicione uma bio para que outros membros te conheçam:': ('Add a bio so other members can get to know you:', 'addBioDesc'),
    'você estará conectado com comunidades incríveis!': ('you will be connected with amazing communities!', 'connectedWithCommunities'),
    'as melhores comunidades para você!': ('the best communities for you!', 'bestCommunitiesForYou'),
    'Assinar por R\\$ 14,90/mês': ('Subscribe for $14.90/month', 'subscribePrice'),
    'Aba de chats públicos da comunidade': ('Community public chats tab', 'communityPublicChatsTabDesc'),
    'Aba de posts em destaque': ('Featured posts tab', 'featuredPostsTabDesc'),
    'Aba de posts mais recentes': ('Most recent posts tab', 'recentPostsTabDesc'),
    'Botão central para criar posts': ('Central button to create posts', 'centralButtonDesc'),
    'Barra de check-in diário com streak': ('Daily check-in bar with streak', 'dailyCheckInBarDesc'),
    'Configure a barra de navegação inferior da comunidade.': ('Configure the community bottom navigation bar.', 'configureBottomNav'),
    'Escolha quais seções serão exibidas na home da comunidade.': ('Choose which sections will be displayed on the community home.', 'chooseSections'),
    'Esses links aparecem na seção "General" do menu lateral da comunidade. Arraste para reordenar.': ('These links appear in the "General" section of the community side menu. Drag to reorder.', 'linksInGeneralSection'),
    'Dê um nome ao link (opcional):': ('Name the link (optional):', 'nameLinkOptional'),
    'Adicione links úteis para os membros\nda sua comunidade.': ('Add useful links for the members\nof your community.', 'addUsefulLinks'),
    'nem enviar mensagens para você.': ('or send you messages.', 'orSendMessages'),
    'só aceita DMs': ('only accepts DMs', 'onlyAcceptsDMs'),
    'Nenhum chat público ainda': ('No public chats yet', 'noPublicChatsYetShort'),
    'Você não é membro deste chat. Tente sair e entrar novamente.': ('You are not a member of this chat. Try leaving and joining again.', 'notMemberChatRetry'),
}

def main():
    # Load existing keys
    existing_keys = set()
    with open(f"{PROJECT}/core/l10n/app_strings.dart", 'r') as f:
        for line in f:
            m = re.search(r'String get (\w+)', line)
            if m:
                existing_keys.add(m.group(1))
    
    # Filter out already existing keys
    new_strings = {}
    for pt_str, (en_str, key) in SIMPLE_STRINGS.items():
        base_key = key
        counter = 2
        while key in existing_keys:
            key = f"{base_key}{counter}"
            counter += 1
        existing_keys.add(key)
        new_strings[pt_str] = (en_str, key)
    
    # Generate l10n additions
    abstract_additions = []
    pt_additions = []
    en_additions = []
    
    for pt_str, (en_str, key) in sorted(new_strings.items(), key=lambda x: x[1][1]):
        abstract_additions.append(f"  String get {key};")
        pt_escaped = pt_str.replace("'", "\\'")
        en_escaped = en_str.replace("'", "\\'")
        pt_additions.append(f"  @override\n  String get {key} => '{pt_escaped}';")
        en_additions.append(f"  @override\n  String get {key} => '{en_escaped}';")
    
    for filepath, additions, comment in [
        (f"{PROJECT}/core/l10n/app_strings.dart", abstract_additions, "// PASS 5 — COMPREHENSIVE FINAL"),
        (f"{PROJECT}/core/l10n/app_strings_pt.dart", pt_additions, "// PASS 5 — COMPREHENSIVE FINAL"),
        (f"{PROJECT}/core/l10n/app_strings_en.dart", en_additions, "// PASS 5 — COMPREHENSIVE FINAL"),
    ]:
        if not additions:
            continue
        with open(filepath, 'r') as f:
            content = f.read()
        insert_text = f"\n  {comment}\n" + '\n'.join(additions) + '\n'
        content = content.rstrip().rstrip('}') + insert_text + '}\n'
        with open(filepath, 'w') as f:
            f.write(content)
    
    print(f"Added {len(new_strings)} new keys to l10n files")
    
    # Replace in source files
    sorted_replacements = sorted(new_strings.items(), key=lambda x: len(x[0]), reverse=True)
    
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
            # Fix const issues
            content = re.sub(r'const Text\(s\.', 'Text(s.', content)
            content = re.sub(r'const Tab\(text: s\.', 'Tab(text: s.', content)
            
            with open(filepath, 'w') as f:
                f.write(content)
            modified += 1
            print(f"  ✓ {os.path.basename(filepath)}")
    
    print(f"\nModified: {modified} files in pass 5")


if __name__ == '__main__':
    main()
