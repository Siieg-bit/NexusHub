import 'app_strings.dart';

/// Strings em Português Brasileiro (pt-BR).
class AppStringsPt implements AppStrings {
  const AppStringsPt();

  // ══════════════════════════════════════════════════════════════════════════
  // GERAL
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get appName => 'NexusHub';
  @override
  String get ok => 'OK';
  @override
  String get cancel => 'Cancelar';
  @override
  String get save => 'Salvar';
  @override
  String get delete => 'Excluir';
  @override
  String get edit => 'Editar';
  @override
  String get close => 'Fechar';
  @override
  String get back => 'Voltar';
  @override
  String get next => 'Próximo';
  @override
  String get done => 'Concluído';
  @override
  String get loading => 'Carregando...';
  @override
  String get error => 'Erro';
  @override
  String get retry => 'Tentar novamente';
  @override
  String get search => 'Buscar';
  @override
  String get seeAll => 'Ver tudo';
  @override
  String get share => 'Compartilhar';
  @override
  String get report => 'Denunciar';
  @override
  String get block => 'Bloquear';
  @override
  String get confirm => 'Confirmar';
  @override
  String get yes => 'Sim';
  @override
  String get no => 'Não';
  @override
  String get noResults => 'Nenhum resultado encontrado';
  @override
  String get somethingWentWrong => 'Algo deu errado';
  @override
  String get tryAgainLater => 'Tente novamente mais tarde';
  @override
  String get copiedToClipboard => 'Copiado para a área de transferência';

  // ══════════════════════════════════════════════════════════════════════════
  // AUTENTICAÇÃO
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get login => 'Entrar';
  @override
  String get signUp => 'Cadastrar';
  @override
  String get logout => 'Sair';
  @override
  String get email => 'E-mail';
  @override
  String get password => 'Senha';
  @override
  String get forgotPassword => 'Esqueceu a senha?';
  @override
  String get resetPassword => 'Redefinir senha';
  @override
  String get createAccount => 'Criar conta';
  @override
  String get alreadyHaveAccount => 'Já tem uma conta?';
  @override
  String get dontHaveAccount => 'Não tem uma conta?';
  @override
  String get loginWithGoogle => 'Entrar com Google';
  @override
  String get loginWithApple => 'Entrar com Apple';
  @override
  String get orContinueWith => 'Ou continue com';
  @override
  String get welcomeBack => 'Bem-vindo de volta!';
  @override
  String get getStarted => 'Começar';

  // ══════════════════════════════════════════════════════════════════════════
  // NAVEGAÇÃO
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get home => 'Início';
  @override
  String get explore => 'Explorar';
  @override
  String get communities => 'Comunidades';
  @override
  String get chats => 'Chats';
  @override
  String get profile => 'Perfil';
  @override
  String get notifications => 'Notificações';
  @override
  String get settings => 'Configurações';
  @override
  String get feed => 'Feed';
  @override
  String get latest => 'Recentes';
  @override
  String get popular => 'Popular';
  @override
  String get online => 'Online';
  @override
  String get me => 'Eu';

  // ══════════════════════════════════════════════════════════════════════════
  // COMUNIDADES
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get joinCommunity => 'Entrar na comunidade';
  @override
  String get leaveCommunity => 'Sair da comunidade';
  @override
  String get createCommunity => 'Criar comunidade';
  @override
  String get communityName => 'Nome da comunidade';
  @override
  String get communityDescription => 'Descrição';
  @override
  String get members => 'Membros';
  @override
  String get onlineMembers => 'Membros online';
  @override
  String get guidelines => 'Regras';
  @override
  String get editGuidelines => 'Editar regras';
  @override
  String get joined => 'Entrou';
  @override
  String get pending => 'Pendente';
  @override
  String get myCommunities => 'Minhas comunidades';
  @override
  String get discoverCommunities => 'Descobrir comunidades';
  @override
  String get newCommunities => 'Novas comunidades';
  @override
  String get forYou => 'Para você';
  @override
  String get trendingNow => 'Em alta';
  @override
  String get categories => 'Categorias';
  @override
  String get inviteLink => 'Link de convite';

  // ══════════════════════════════════════════════════════════════════════════
  // POSTS
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get createPost => 'Criar post';
  @override
  String get writePost => 'Escreva algo...';
  @override
  String get title => 'Título';
  @override
  String get content => 'Conteúdo';
  @override
  String get addImage => 'Adicionar imagem';
  @override
  String get addPoll => 'Adicionar enquete';
  @override
  String get addQuiz => 'Adicionar quiz';
  @override
  String get tags => 'Tags';
  @override
  String get publish => 'Publicar';
  @override
  String get draft => 'Rascunho';
  @override
  String get like => 'Curtir';
  @override
  String get comment => 'Comentar';
  @override
  String get comments => 'Comentários';
  @override
  String get bookmark => 'Salvar';
  @override
  String get bookmarked => 'Salvo';
  @override
  String get featured => 'Destaque';
  @override
  String get pinned => 'Fixado';
  @override
  String get crosspost => 'Crosspost';
  @override
  String get crosspostTo => 'Crosspost para';
  @override
  String get selectCommunity => 'Selecionar comunidade';
  @override
  String get writeComment => 'Escreva um comentário...';
  @override
  String get noPostsYet => 'Nenhum post ainda';
  @override
  String get deletePost => 'Excluir post';
  @override
  String get deletePostConfirm => 'Tem certeza que deseja excluir este post?';
  @override
  String get reportPost => 'Denunciar post';
  @override
  String get featurePost => 'Destacar post';
  @override
  String get pinPost => 'Fixar post';

  // ══════════════════════════════════════════════════════════════════════════
  // CHAT
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get newChat => 'Novo chat';
  @override
  String get newGroupChat => 'Novo chat em grupo';
  @override
  String get privateChat => 'Chat privado';
  @override
  String get groupChat => 'Chat em grupo';
  @override
  String get typeMessage => 'Digite uma mensagem...';
  @override
  String get sendMessage => 'Enviar mensagem';
  @override
  String get voiceMessage => 'Mensagem de voz';
  @override
  String get stickers => 'Stickers';
  @override
  String get gifs => 'GIFs';
  @override
  String get attachImage => 'Anexar imagem';
  @override
  String get reply => 'Responder';
  @override
  String get typing => 'digitando...';
  @override
  String get isTyping => 'está digitando...';
  @override
  String get groupName => 'Nome do grupo';
  @override
  String get addMembers => 'Adicionar membros';
  @override
  String get leaveGroup => 'Sair do grupo';
  @override
  String get noChatsYet => 'Nenhum chat ainda';
  @override
  String get startConversation => 'Iniciar conversa';

  // ══════════════════════════════════════════════════════════════════════════
  // PERFIL
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get editProfile => 'Editar perfil';
  @override
  String get nickname => 'Apelido';
  @override
  String get bio => 'Bio';
  @override
  String get level => 'Nível';
  @override
  String get reputation => 'Reputação';
  @override
  String get followers => 'Seguidores';
  @override
  String get following => 'Seguindo';
  @override
  String get follow => 'Seguir';
  @override
  String get unfollow => 'Deixar de seguir';
  @override
  String get posts => 'Posts';
  @override
  String get wall => 'Mural';
  @override
  String get stories => 'Stories';
  @override
  String get linkedCommunities => 'Comunidades vinculadas';
  @override
  String get pinnedWikis => 'Wikis fixadas';
  @override
  String get achievements => 'Conquistas';
  @override
  String get checkIn => 'Check-in';
  @override
  String get dailyCheckIn => 'Check-in diário';
  @override
  String get streak => 'Sequência';

  // ══════════════════════════════════════════════════════════════════════════
  // WIKI
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get wiki => 'Wiki';
  @override
  String get createWiki => 'Criar wiki';
  @override
  String get wikiEntries => 'Entradas da wiki';
  @override
  String get curatorReview => 'Revisão de curadores';
  @override
  String get approve => 'Aprovar';
  @override
  String get reject => 'Rejeitar';
  @override
  String get pendingReview => 'Aguardando revisão';
  @override
  String get approved => 'Aprovado';
  @override
  String get rejected => 'Rejeitado';
  @override
  String get pinToProfile => 'Fixar no perfil';
  @override
  String get unpinFromProfile => 'Desafixar do perfil';
  @override
  String get rating => 'Avaliação';
  @override
  String get whatILike => 'O que eu gosto';

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICAÇÕES
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get markAllAsRead => 'Marcar tudo como lido';
  @override
  String get noNotifications => 'Nenhuma notificação';
  @override
  String get likedYourPost => 'curtiu seu post';
  @override
  String get commentedOnYourPost => 'comentou no seu post';
  @override
  String get followedYou => 'seguiu você';
  @override
  String get mentionedYou => 'mencionou você';
  @override
  String get invitedYou => 'convidou você';
  @override
  String get levelUp => 'Subiu de nível!';
  @override
  String get newAchievement => 'Nova conquista!';

  // ══════════════════════════════════════════════════════════════════════════
  // MODERAÇÃO
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get moderation => 'Moderação';
  @override
  String get adminPanel => 'Painel admin';
  @override
  String get flagCenter => 'Central de denúncias';
  @override
  String get ban => 'Banir';
  @override
  String get unban => 'Desbanir';
  @override
  String get kick => 'Expulsar';
  @override
  String get mute => 'Silenciar';
  @override
  String get warn => 'Avisar';
  @override
  String get strike => 'Strike';
  @override
  String get reason => 'Motivo';
  @override
  String get duration => 'Duração';
  @override
  String get permanent => 'Permanente';
  @override
  String get executeAction => 'Executar ação';
  @override
  String get leader => 'Líder';
  @override
  String get curator => 'Curador';
  @override
  String get member => 'Membro';

  // ══════════════════════════════════════════════════════════════════════════
  // CONFIGURAÇÕES
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get generalSettings => 'Configurações gerais';
  @override
  String get darkMode => 'Modo escuro';
  @override
  String get lightMode => 'Modo claro';
  @override
  String get language => 'Idioma';
  @override
  String get pushNotifications => 'Notificações push';
  @override
  String get privacy => 'Privacidade';
  @override
  String get blockedUsers => 'Usuários bloqueados';
  @override
  String get clearCache => 'Limpar cache';
  @override
  String get cacheCleared => 'Cache limpo com sucesso';
  @override
  String get about => 'Sobre';
  @override
  String get version => 'Versão';
  @override
  String get termsOfService => 'Termos de serviço';
  @override
  String get privacyPolicy => 'Política de privacidade';
  @override
  String get deleteAccount => 'Excluir conta';
  @override
  String get deleteAccountConfirm =>
      'Tem certeza que deseja excluir sua conta? Esta ação é irreversível.';
  @override
  String get logoutConfirm => 'Tem certeza que deseja sair?';

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPO
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get justNow => 'Agora mesmo';
  @override
  String get minutesAgo => 'min atrás';
  @override
  String get hoursAgo => 'h atrás';
  @override
  String get daysAgo => 'd atrás';
  @override
  String get yesterday => 'Ontem';
  @override
  String get today => 'Hoje';

  // ══════════════════════════════════════════════════════════════════════════
  // ERROS
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get networkError => 'Erro de conexão. Verifique sua internet.';
  @override
  String get sessionExpired => 'Sessão expirada. Faça login novamente.';
  @override
  String get permissionDenied => 'Permissão negada.';
  @override
  String get notFound => 'Não encontrado.';
  @override
  String get serverError => 'Erro no servidor. Tente novamente mais tarde.';

  // ══════════════════════════════════════════════════════════════════════════
  // STRINGS ADICIONAIS (migração i18n)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get accept => 'Aceitar';
  @override
  String get acceptTerms => 'Aceite os termos de uso para continuar';
  @override
  String get actionError => 'Erro ao executar ação. Tente novamente.';
  @override
  String get actionSuccess => 'Ação executada com sucesso';
  @override
  String get active => 'Ativo';
  @override
  String get addAtLeastOneImage => 'Adicione pelo menos uma imagem';
  @override
  String get addAtLeastOneQuestion => 'Adicione pelo menos uma pergunta';
  @override
  String get addAtLeastTwoOptions => 'Adicione pelo menos 2 opções';
  @override
  String get addCover => 'Adicionar Capa';
  @override
  String get addMusic => 'Adicionar Música';
  @override
  String get addOption => 'Adicionar Opção';
  @override
  String get addQuestion => 'Adicionar Pergunta';
  @override
  String get addVideo => 'Adicionar Vídeo';
  @override
  String get advancedOptions => 'Opções Avançadas';
  @override
  String get allSessionsRevoked => 'Todas as outras sessões foram encerradas';
  @override
  String get alreadyCheckedIn => 'Você já fez check-in hoje nesta comunidade!';
  @override
  String get appPermissions => 'Permissões do App';
  @override
  String get appearance => 'Aparência';
  @override
  String get apply => 'Aplicar';
  @override
  String get audio => 'Audio';
  @override
  String get change => 'Alterar';
  @override
  String get changeEmail => 'Alterar Email';
  @override
  String get checkInError => 'Erro no check-in. Tente novamente.';
  @override
  String get coins => 'moedas';
  @override
  String get confirmPassword => 'Confirmar Senha';
  @override
  String get current => 'Atual';
  @override
  String get dailyReward => 'Recompensa diária';
  @override
  String get deleteChat => 'Excluir Chat';
  @override
  String get deleteChatError => 'Erro ao excluir o chat. Tente novamente.';
  @override
  String get deleteDraft => 'Excluir rascunho?';
  @override
  String get deleteError => 'Erro ao apagar. Tente novamente.';
  @override
  String get deletePermanently => 'Excluir Permanentemente';
  @override
  String get enableBanner => 'Ativar Banner';
  @override
  String get enterGroupName => 'Digite um nome para o grupo';
  @override
  String get fileSentSuccess => 'Arquivo enviado com sucesso!';
  @override
  String get genericError => 'Ocorreu um erro. Tente novamente.';
  @override
  String get insertLink => 'Inserir Link';
  @override
  String get insufficientBalance => 'Saldo insuficiente';
  @override
  String get joinedChat => 'Você entrou no chat!';
  @override
  String get leaveChat => 'Sair do Chat';
  @override
  String get leaveChatConfirm => 'Tem certeza que deseja sair deste chat?';
  @override
  String get leaveChatError => 'Erro ao sair do chat. Tente novamente.';
  @override
  String get leaveCommunityError => 'Erro ao sair da comunidade. Tente novamente.';
  @override
  String get linkCopied => 'Link copiado!';
  @override
  String get loadChatsError => 'Erro ao carregar chats';
  @override
  String get loginRequired => 'Você precisa estar logado para comentar.';
  @override
  String get messageForwarded => 'Mensagem encaminhada!';
  @override
  String get moderationAction => 'Ação de Moderação';
  @override
  String get nameLink => 'Nomear link';
  @override
  String get newWikiEntry => 'Nova Entrada Wiki';
  @override
  String get noCommunityFound => 'Nenhuma comunidade encontrada';
  @override
  String get noMemberFound => 'Nenhum membro encontrado';
  @override
  String get noWallComments => 'Nenhum comentário no mural';
  @override
  String get openSettings => 'Abrir Configurações';
  @override
  String get or => 'ou';
  @override
  String get permissionDeniedTitle => 'Permissão negada';
  @override
  String get pinChatError => 'Erro ao fixar/desafixar chat.';
  @override
  String get pollQuestionRequired => 'A pergunta da enquete é obrigatória';
  @override
  String get private => 'Privado';
  @override
  String get profileLinkCopied => 'Link do perfil copiado!';
  @override
  String get public => 'Público';
  @override
  String get publishError => 'Erro ao publicar. Tente novamente.';
  @override
  String get questionRequired => 'A pergunta é obrigatória';
  @override
  String get rejectionReason => 'Motivo da rejeição';
  @override
  String get reorderCommunities => 'Segure e arraste os cards para reordenar suas comunidades.';
  @override
  String get reportBug => 'Reportar Bug';
  @override
  String get revokeAllOthers => 'Revogar Todos os Outros';
  @override
  String get revokeDevice => 'Revogar Dispositivo';
  @override
  String get saveError => 'Erro ao salvar. Tente novamente.';
  @override
  String get sendError => 'Erro ao enviar. Tente novamente.';
  @override
  String get settingsSaved => 'Configurações salvas!';
  @override
  String get showOnlineCount => 'Exibe contagem de online na bottom bar';
  @override
  String get startConversationWith => 'Iniciar conversa com um usuário';
  @override
  String get titleRequired => 'O título é obrigatório';
  @override
  String get uploadError => 'Erro no upload. Tente novamente.';
  @override
  String get visibility => 'Visibilidade';
  @override
  String get waitingParticipants => 'Aguardando participantes...';
  @override
  String get welcomeBanner => 'Banner de Boas-Vindas';
  @override
  String get writeOnWall => 'Escreva no mural...';
}
