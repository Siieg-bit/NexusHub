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
  // AUTH (NOVOS)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get account => 'Conta';
  @override
  String get checkYourEmail => 'Verifique seu email';
  @override
  String get confirmYourPassword => 'Confirme sua senha';
  @override
  String get createAPassword => 'Crie uma senha';
  @override
  String get currentPassword => 'Senha atual';
  @override
  String get emailHint => 'E-mail';
  @override
  String get enterYourEmail => 'Informe seu email';
  @override
  String get incorrectPassword => 'Senha incorreta';
  @override
  String get logInAction => 'Fazer login';
  @override
  String get passwordsDoNotMatch => 'As senhas não coincidem';
  @override
  String get sessionExpiredPleaseLogInAgain => 'Sessão expirada. Faça login novamente.';

  // ══════════════════════════════════════════════════════════════════════════
  // COMUNIDADES (NOVOS)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get access => 'Acesso';
  @override
  String get community => 'Comunidade';
  @override
  String get createCommunityTitle => 'Criar Comunidade';
  @override
  String get modules => 'Módulos';
  @override
  String get myCommunitiesTitle => 'Minhas Comunidades';
  @override
  String get noCommunitiesFound => 'Nenhuma comunidade encontrada';
  @override
  String get noPostsInThisCommunity => 'Nenhum post nesta comunidade';
  @override
  String get recommendedCommunities => 'Comunidades Recomendadas';

  // ══════════════════════════════════════════════════════════════════════════
  // POSTS / FEED (NOVOS)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get addOption => 'Adicionar opção';
  @override
  String get addQuestion => 'Adicionar pergunta';
  @override
  String get blog => 'Blog';
  @override
  String get createPoll => 'Criar Enquete';
  @override
  String get divider => 'Divisor';
  @override
  String get drafts => 'Rascunhos';
  @override
  String get list => 'Lista';
  @override
  String get listed => 'Listada';
  @override
  String get newBlog => 'Novo Blog';
  @override
  String get newPoll => 'Nova Enquete';
  @override
  String get newQuiz => 'Novo Quiz';
  @override
  String get noSavedPosts => 'Nenhum post salvo';
  @override
  String get poll => 'Enquete';
  @override
  String get post => 'Post';
  @override
  String get question => 'Pergunta';
  @override
  String get quiz => 'Quiz';
  @override
  String get savedPosts => 'Posts Salvos';
  @override
  String get savedPostsArePrivate => 'Posts salvos são privados';
  @override
  String get tapTheBookmarkIconOnPostsToSaveThem => 'Toque no ícone de bookmark nos posts para salvá-los';

  // ══════════════════════════════════════════════════════════════════════════
  // CHAT (NOVOS)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get camera => 'Câmera';
  @override
  String get chat => 'Chat';
  @override
  String get end => 'Encerrar';
  @override
  String get errorLoadingChats => 'Erro ao carregar chats';
  @override
  String get errorOpeningChatTryAgain => 'Erro ao abrir chat. Tente novamente.';
  @override
  String get errorPinningMessage => 'Erro ao fixar mensagem';
  @override
  String get leaveChat => 'Sair do chat';
  @override
  String get messagePinned => 'Mensagem fixada';
  @override
  String get mic => 'Mic';
  @override
  String get muted => 'Mudo';
  @override
  String get noMessages => 'Sem mensagens';
  @override
  String get onlyTheHostCanPinMessages => 'Apenas o host pode fixar mensagens';
  @override
  String get pendingInvites => 'Convites pendentes';
  @override
  String get sendCoinsToThisChat => 'Envie moedas para este chat';
  @override
  String get speaker => 'Alto-falante';
  @override
  String get stickersLabel => 'Figurinhas';
  @override
  String get switchCamera => 'Trocar';
  @override
  String get thisUserDoesNotAcceptDirectMessages => 'Este usuário não aceita mensagens diretas.';
  @override
  String get thisUserOnlyAcceptsMessagesFromAllowedProfiles => 'Este usuário só aceita mensagens de perfis permitidos.';
  @override
  String get youCannotOpenAChatWithYourself => 'Você não pode abrir um chat consigo mesmo.';

  // ══════════════════════════════════════════════════════════════════════════
  // PERFIL (NOVOS)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get errorLoadingProfile => 'Erro ao carregar perfil';
  @override
  String get followingNow => 'Seguindo!';
  @override
  String get profileLinkCopied => 'Link do perfil copiado!';
  @override
  String get removeBanner => 'Remover banner';
  @override
  String get shareProfile => 'Compartilhar Perfil';
  @override
  String get unfollowed => 'Deixou de seguir';
  @override
  String get writeOnTheWall => 'Escreva no mural...';

  // ══════════════════════════════════════════════════════════════════════════
  // WIKI (NOVOS)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get entryType => 'Tipo de Entrada';
  @override
  String get myWikiEntries => 'Minhas Entradas Wiki';

  // ══════════════════════════════════════════════════════════════════════════
  // MODERAÇÃO (NOVOS)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get noPendingReports => 'Nenhuma denúncia pendente';
  @override
  String get reports => 'Denúncias';
  @override
  String get spam => 'Spam';

  // ══════════════════════════════════════════════════════════════════════════
  // CONFIGURAÇÕES (NOVOS)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get appearance => 'Aparência';
  @override
  String get noBlockedUsers => 'Nenhum usuário bloqueado';
  @override
  String get primaryLanguage => 'Idioma Principal';
  @override
  String get privacyPolicyTitle => 'Política de Privacidade';
  @override
  String get security => 'Segurança';
  @override
  String get themeColor => 'Cor do Tema';

  // ══════════════════════════════════════════════════════════════════════════
  // GAMIFICAÇÃO (NOVOS)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get insufficientBalance => 'Saldo insuficiente';
  @override
  String get inventory => 'Inventário';
  @override
  String get ranking => 'Ranking';
  @override
  String get wallet => 'Carteira';

  // ══════════════════════════════════════════════════════════════════════════
  // LOJA (NOVOS)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get backgrounds => 'Fundos';
  @override
  String get buy => 'Comprar';
  @override
  String get errorRestoringPurchases => 'Erro ao restaurar compras';
  @override
  String get store => 'Loja';
  @override
  String get untitled => 'Sem título';

  // ══════════════════════════════════════════════════════════════════════════
  // STORIES (NOVOS)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get storyPublished => 'Story publicado!';

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPO / MESES (NOVOS)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get april => 'abril';
  @override
  String get august => 'agosto';
  @override
  String get december => 'dezembro';
  @override
  String get february => 'fevereiro';
  @override
  String get january => 'janeiro';
  @override
  String get july => 'julho';
  @override
  String get june => 'junho';
  @override
  String get march => 'março';
  @override
  String get may => 'maio';
  @override
  String get november => 'novembro';
  @override
  String get now => 'agora';
  @override
  String get october => 'outubro';
  @override
  String get september => 'setembro';
  @override
  String get todayLabel => 'Hoje';

  // ══════════════════════════════════════════════════════════════════════════
  // ERROS (NOVOS)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get anErrorOccurredTryAgain => 'Ocorreu um erro. Tente novamente.';
  @override
  String get errorLoadingNotifications => 'Erro ao carregar notificações';
  @override
  String get unknownError => 'Erro desconhecido';

  // ══════════════════════════════════════════════════════════════════════════
  // GERAL (NOVOS)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get accept => 'Aceitar';
  @override
  String get active => 'Ativo';
  @override
  String get anonymous => 'Anônimo';
  @override
  String get apple => 'Apple';
  @override
  String get apply => 'Aplicar';
  @override
  String get bold => 'Negrito';
  @override
  String get chooseANickname => 'Escolha um nickname';
  @override
  String get connected => 'Conectado';
  @override
  String get connections => 'Conexões';
  @override
  String get continueAction => 'Continuar';
  @override
  String get copy => 'Copiar';
  @override
  String get couldNotStartAConversationWithThisUser => 'Não foi possível iniciar conversa com este usuário.';
  @override
  String get create => 'Criar';
  @override
  String get decline => 'Recusar';
  @override
  String get deleteAction => 'Apagar';
  @override
  String get deleteConversation => 'Apagar conversa';
  @override
  String get deleteFile => 'Excluir arquivo';
  @override
  String get editor => 'Editor';
  @override
  String get everyone => 'Todos';
  @override
  String get files => 'Arquivos';
  @override
  String get general => 'Geral';
  @override
  String get global => 'Global';
  @override
  String get google => 'Google';
  @override
  String get history => 'Histórico';
  @override
  String get image => 'Imagem';
  @override
  String get images => 'Imagens';
  @override
  String get italic => 'Itálico';
  @override
  String get less => 'Menos';
  @override
  String get link => 'Link';
  @override
  String get minimum6Characters => 'Mínimo 6 caracteres';
  @override
  String get more => 'Mais';
  @override
  String get music => 'Música';
  @override
  String get nicknameHint => 'Apelido';
  @override
  String get noFiles => 'Nenhum arquivo';
  @override
  String get noItems => 'Nenhum item';
  @override
  String get nobody => 'Ninguém';
  @override
  String get offline => 'Offline';
  @override
  String get open => 'Aberta';
  @override
  String get openAction => 'Abrir';
  @override
  String get other => 'Outro';
  @override
  String get pinToTop => 'Fixar no topo';
  @override
  String get preview => 'Prévia';
  @override
  String get recent => 'Recente';
  @override
  String get recommended => 'Recomendados';
  @override
  String get refresh => 'Atualizar';
  @override
  String get remove => 'Remover';
  @override
  String get selectAnAmount => 'Selecione um valor';
  @override
  String get send => 'Enviar';
  @override
  String get sharedFolder => 'Pasta compartilhada';
  @override
  String get sharedScreenWillAppearHere => 'Tela compartilhada aparecerá aqui';
  @override
  String get strikethrough => 'Tachado';
  @override
  String get termsOfUse => 'Termos de Uso';
  @override
  String get text => 'Texto';
  @override
  String get unblock => 'Desbloquear';
  @override
  String get unpinFromTop => 'Desafixar do topo';
  @override
  String get user => 'Usuário';
  @override
  String get videos => 'Vídeos';
  @override
  String get visibility => 'Visibilidade';
  @override
  String get visual => 'Visual';
  @override
  String get yesDelete => 'Sim, excluir';
  @override
  String get you => 'Você';

  // PASS 2 — STRINGS ADICIONAIS
  @override
  String get acceptTermsToContinue => 'Aceite os termos de uso para continuar';
  @override
  String get accessLabel => 'Acesso';
  @override
  String get accountLabel => 'Conta';
  @override
  String get achievementUnlocked => 'Conquista desbloqueada!';
  @override
  String get actionExecuted => 'Ação executada';
  @override
  String get activeChats => 'Chats ativos';
  @override
  String get addBlock => 'Adicionar bloco';
  @override
  String get addLink => 'Adicionar link';
  @override
  String get addMusic => 'Adicionar música';
  @override
  String get addOptionAction => 'Adicionar opção';
  @override
  String get addQuestionAction => 'Adicionar pergunta';
  @override
  String get addSticker => 'Adicionar sticker';
  @override
  String get addText => 'Adicionar texto';
  @override
  String get administration => 'Administração';
  @override
  String get allFiles => 'Todos os arquivos';
  @override
  String get allowGroupInvites => 'Permitir convites de grupo';
  @override
  String get alreadyCheckedIn => 'Você já fez check-in hoje';
  @override
  String get alreadyHaveAccountShort => 'Já tenho conta';
  @override
  String get anonymousLabel => 'Anônimo';
  @override
  String get appPermissions => 'Permissões do app';
  @override
  String get appearanceLabel => 'Aparência';
  @override
  String get approval => 'Aprovação';
  @override
  String get audio => 'Áudio';
  @override
  String get backgroundsLabel => 'Fundos';
  @override
  String get balance => 'Saldo';
  @override
  String get boldFormat => 'Negrito';
  @override
  String get buyAction => 'Comprar';
  @override
  String get buyCoins => 'Comprar moedas';
  @override
  String get cameraAction => 'Câmera';
  @override
  String get changeAvatar => 'Alterar avatar';
  @override
  String get changeBanner => 'Alterar banner';
  @override
  String get changesSaved => 'Alterações salvas';
  @override
  String get chatBubbles => 'Bolhas de chat';
  @override
  String get chatDescription => 'Descrição do chat';
  @override
  String get chatName => 'Nome do chat';
  @override
  String get checkInDone => 'Check-in realizado!';
  @override
  String get checkInHeatmap => 'Heatmap de check-in';
  @override
  String get chooseFromGallery => 'Escolher da galeria';
  @override
  String get closed => 'Encerrada';
  @override
  String get code => 'Código';
  @override
  String get coinShop => 'Loja de moedas';
  @override
  String get coinsSent => 'Moedas enviadas!';
  @override
  String get comingSoon => 'Em breve';
  @override
  String get communityChats => 'Chats da comunidade';
  @override
  String get communityGuidelines => 'Regras da comunidade';
  @override
  String get confirmDeleteMessage => 'Tem certeza que deseja excluir esta mensagem?';
  @override
  String get confirmPassword => 'Confirmar senha';
  @override
  String get confirmRemoveLink => 'Tem certeza que deseja remover este link?';
  @override
  String get connectionError => 'Erro de conexão. Verifique sua internet.';
  @override
  String get connectionsLabel => 'Conexões';
  @override
  String get contact => 'Contato';
  @override
  String get copyMessage => 'Copiar mensagem';
  @override
  String get correct => 'Correto!';
  @override
  String get correctAnswer => 'Resposta correta';
  @override
  String get createGroup => 'Criar Grupo';
  @override
  String get createGroupAction => 'Criar grupo';
  @override
  String get createPublicChat => 'Criar Chat Público';
  @override
  String get createPublicChatAction => 'Criar chat público';
  @override
  String get createStory => 'Criar story';
  @override
  String get curators => 'Curadores';
  @override
  String get currentDevice => 'Dispositivo atual';
  @override
  String get customizeProfile => 'Personalize seu perfil e suba de nível';
  @override
  String get dailyReward => 'Recompensa diária';
  @override
  String get dataExported => 'Dados exportados com sucesso';
  @override
  String get date => 'Data';
  @override
  String get day => 'Dia';
  @override
  String get dayStreak => 'Dias na Sequência';
  @override
  String get days => 'Dias';
  @override
  @override
  String get deleteMessage => 'Excluir mensagem';
  @override
  String get deleting => 'Excluindo...';
  @override
  String get describeReason => 'Descreva o motivo...';
  @override
  String get deviceRemoved => 'Dispositivo removido';
  @override
  String get devices => 'Dispositivos';
  @override
  String get dividerBlock => 'Divisor';
  @override
  String get doCheckIn => 'Fazer check-in';
  @override
  String get document => 'Documento';
  @override
  String get documents => 'Documentos';
  @override
  String get draftDeleted => 'Rascunho excluído';
  @override
  String get draftSaved => 'Rascunho salvo';
  @override
  String get draftsWillAppearHere => 'Seus rascunhos aparecerão aqui';
  @override
  String get editCommunityGuidelines => 'Editar regras da comunidade';
  @override
  String get editCommunityProfile => 'Editar perfil da comunidade';
  @override
  String get editLink => 'Editar link';
  @override
  String get editorLabel => 'Editor';
  @override
  String get endLive => 'Encerrar live';
  @override
  String get enterGroupName => 'Digite um nome para o grupo';
  @override
  String get enterYourEmailFirst => 'Digite seu email primeiro';
  @override
  String get enterYourPassword => 'Informe sua senha';
  @override
  String get entryApproved => 'Entrada aprovada';
  @override
  String get entryRejected => 'Entrada rejeitada';
  @override
  String get entryTypeLabel => 'Tipo de entrada';
  @override
  String get equip => 'Equipar';
  @override
  String get equipped => 'Equipado';
  @override
  String get errorAppleLogin => 'Erro no login com Apple. Tente novamente.';
  @override
  String get errorCreatingAccount => 'Erro ao criar conta. Tente novamente.';
  @override
  String get errorCreatingChat => 'Erro ao criar chat. Tente novamente.';
  @override
  String get errorCreatingGroup => 'Erro ao criar grupo. Tente novamente.';
  @override
  String get errorDeletingChat => 'Erro ao excluir o chat. Tente novamente.';
  @override
  String get errorDeletingTryAgain => 'Erro ao apagar. Tente novamente.';
  @override
  String get errorEditingTryAgain => 'Erro ao editar. Tente novamente.';
  @override
  String get errorExecutingAction => 'Erro ao executar ação';
  @override
  String get errorExportingData => 'Erro ao exportar dados';
  @override
  String get errorGoogleLogin => 'Erro no login com Google. Tente novamente.';
  @override
  String get errorJoiningChat => 'Erro ao entrar no chat. Tente novamente.';
  @override
  String get errorLeavingChat => 'Erro ao sair do chat. Tente novamente.';
  @override
  String get errorLoadingImage => 'Erro ao carregar imagem';
  @override
  String get errorLoadingProfileMsg => 'Erro ao carregar perfil';
  @override
  String get errorLoadingProfileRetry => 'Erro ao carregar perfil. Tente novamente.';
  @override
  String get errorLoggingOut => 'Erro ao sair. Tente novamente.';
  @override
  String get errorLoginCredentials => 'Erro ao fazer login. Verifique suas credenciais.';
  @override
  String get errorPublishing => 'Erro ao publicar';
  @override
  String get errorSaving => 'Erro ao salvar';
  @override
  String get errorSavingTryAgain => 'Erro ao salvar. Tente novamente.';
  @override
  String get errorSendingAudio => 'Erro ao enviar áudio. Tente novamente.';
  @override
  String get errorSendingCoins => 'Erro ao enviar moedas';
  @override
  String get errorSendingLink => 'Erro ao enviar link. Tente novamente.';
  @override
  String get errorSendingTryAgain => 'Erro ao enviar. Tente novamente.';
  @override
  String get errorUpdatingGuidelines => 'Erro ao atualizar regras';
  @override
  String get errorUpdatingImage => 'Erro ao atualizar imagem';
  @override
  String get errorUpdatingProfile => 'Erro ao atualizar perfil';
  @override
  String get errorUploadTryAgain => 'Erro no upload. Tente novamente.';
  @override
  String get errorUploadingFile => 'Erro ao enviar arquivo';
  @override
  String get errorVideoUpload => 'Erro no upload do vídeo. Tente novamente.';
  @override
  String get explanation => 'Explicação';
  @override
  String get exportData => 'Exportar dados';
  @override
  String get favorites => 'Favoritos';
  @override
  String get featureUnderDev => 'Funcionalidade em desenvolvimento';
  @override
  String get file => 'Arquivo';
  @override
  String get fileDeleted => 'Arquivo excluído';
  @override
  String get fileUploaded => 'Arquivo enviado';
  @override
  String get filter => 'Filtrar';
  @override
  String get frames => 'Molduras';
  @override
  String get freeCoins => 'Moedas grátis';
  @override
  String get gallery => 'Galeria';
  @override
  String get generalLabel => 'Geral';
  @override
  String get grid => 'Grade';
  @override
  String get groupDescription => 'Descrição do grupo';
  @override
  String get guidelinesUpdated => 'Regras atualizadas';
  @override
  String get harassment => 'Assédio';
  @override
  String get hateSpeech => 'Discurso de ódio';
  @override
  String get header => 'Cabeçalho';
  @override
  String get historyLabel => 'Histórico';
  @override
  String get ignore => 'Ignorar';
  @override
  String get imageUpdated => 'Imagem atualizada';
  @override
  String get imagesLabel => 'Imagens';
  @override
  String get inappropriateContent => 'Conteúdo impróprio';
  @override
  String get incorrect => 'Incorreto';
  @override
  String get info => 'Info';
  @override
  String get information => 'Informações';
  @override
  String get insertImage => 'Inserir imagem';
  @override
  String get insertLink => 'Inserir link';
  @override
  String get insufficientBalanceMsg => 'Saldo insuficiente';
  @override
  String get interestAnime => 'Anime';
  @override
  String get interestComics => 'Quadrinhos';
  @override
  String get interestCooking => 'Culinária';
  @override
  String get interestCosplay => 'Cosplay';
  @override
  String get interestDance => 'Dança';
  @override
  String get interestFashion => 'Moda';
  @override
  String get interestHorror => 'Terror';
  @override
  String get interestKpop => 'K-Pop';
  @override
  String get interestLanguages => 'Idiomas';
  @override
  String get interestManga => 'Manga';
  @override
  String get interestNature => 'Natureza';
  @override
  String get interestPhotography => 'Fotografia';
  @override
  String get interestScience => 'Ciência';
  @override
  String get interestSpirituality => 'Espiritualidade';
  @override
  String get interestSports => 'Esportes';
  @override
  String get interestTechnology => 'Tecnologia';
  @override
  String get interestTravel => 'Viagem';
  @override
  String get invalidEmail => 'Email inválido';
  @override
  String get invalidLink => 'Link inválido';
  @override
  String get invite => 'Convite';
  @override
  String get inviteFriends => 'Convidar amigos';
  @override
  String get italicFormat => 'Itálico';
  @override
  String get items => 'Itens';
  @override
  String get joinCommunityFirst => 'Entre em uma comunidade primeiro';
  @override
  String get joinLive => 'Entrar na live';
  @override
  String get lastAccess => 'Último acesso';
  @override
  String get layout => 'Layout';
  @override
  String get leaderboard => 'Classificação';
  @override
  String get leaders => 'Líderes';
  @override
  String get linkAdded => 'Link adicionado';
  @override
  String get linkPreview => 'Prévia do link';
  @override
  String get linkRemoved => 'Link removido';
  @override
  String get linkTitle => 'Título do link';
  @override
  String get linkUpdated => 'Link atualizado';
  @override
  String get linkUrl => 'URL do link';
  @override
  String get linkedAccounts => 'Contas vinculadas';
  @override
  String get listedVisibility => 'Listada';
  @override
  String get live => 'Ao vivo';
  @override
  String get liveChats => 'Chats ao vivo';
  @override
  String get liveProjections => 'Projeções ao vivo';
  @override
  String get localBio => 'Bio local';
  @override
  String get localNickname => 'Apelido local';
  @override
  String get location => 'Localização';
  @override
  String get logInToContinue => 'Faça login para continuar';
  @override
  String get manage => 'Gerenciar';
  @override
  String get markAllRead => 'Marcar tudo como lido';
  @override
  String get markdown => 'Markdown';
  @override
  String get media => 'Mídia';
  @override
  String get memberSince => 'Membro desde';
  @override
  String get membersCount => 'membros';
  @override
  String get messageCopied => 'Mensagem copiada';
  @override
  String get messageDeleted => 'Mensagem apagada';
  @override
  String get messageDeletedConfirm => 'Mensagem excluída';
  @override
  String get messagePinnedMsg => 'Mensagem fixada';
  @override
  String get messageUnpinned => 'Mensagem desafixada';
  @override
  String get minimum2Options => 'Mínimo de 2 opções';
  @override
  String get minimum6Chars => 'Mínimo 6 caracteres';
  @override
  String get moderationActions => 'Ações de moderação';
  @override
  String get moderators => 'Moderadores';
  @override
  String get modulesLabel => 'Módulos';
  @override
  String get moveDown => 'Mover para baixo';
  @override
  String get moveUp => 'Mover para cima';
  @override
  String get musicLabel => 'Música';
  @override
  String get myWikiEntriesTitle => 'Minhas Entradas Wiki';
  @override
  String get name => 'Nome';
  @override
  String get nameLink => 'Nomear link';
  @override
  String get newChatTitle => 'Novo Chat';
  @override
  String get newMembersThisWeek => 'Novos membros esta semana';
  @override
  String get noAchievementsYet => 'Nenhuma conquista ainda';
  @override
  String get noBlockedUsersMsg => 'Nenhum usuário bloqueado';
  @override
  String get noChatsInCommunity => 'Nenhum chat nesta comunidade';
  @override
  String get noCheckIns => 'Nenhum check-in';
  @override
  String get noDevicesFound => 'Nenhum dispositivo encontrado';
  @override
  String get noDrafts => 'Sem rascunhos';
  @override
  String get noEntriesToReview => 'Nenhuma entrada para revisar';
  @override
  String get noFilesMsg => 'Nenhum arquivo';
  @override
  String get noGuidelinesDefined => 'Nenhuma regra definida';
  @override
  String get noLiveChats => 'Nenhum chat ao vivo';
  @override
  String get noLiveStreams => 'Nenhuma live no momento';
  @override
  String get noMemberFound => 'Nenhum membro encontrado';
  @override
  String get noMembersOnline => 'Nenhum membro online';
  @override
  String get noMembersSelected => 'Nenhum membro selecionado';
  @override
  String get noMessagesYet => 'Nenhuma mensagem ainda';
  @override
  String get noMusicFound => 'Nenhuma música encontrada';
  @override
  String get noNotificationsMsg => 'Nenhuma notificação';
  @override
  String get noPendingReportsMsg => 'Nenhuma denúncia pendente';
  @override
  String get noPermissionAction => 'Sem permissão para esta ação';
  @override
  String get noPostsInCommunity => 'Nenhum post nesta comunidade';
  @override
  String get noProjections => 'Nenhuma projeção';
  @override
  String get noRecentEmoji => 'Nenhum emoji recente';
  @override
  String get noStories => 'Nenhum story';
  @override
  String get noTransactions => 'Nenhuma transação';
  @override
  String get notFoundMsg => 'Não encontrado.';
  @override
  String get notificationSettings => 'Configurações de notificação';
  @override
  String get openEntry => 'Aberta';
  @override
  String get others => 'Outros';
  @override
  String get packages => 'Pacotes';
  @override
  String get paragraph => 'Parágrafo';
  @override
  String get pasteLinkHere => 'Cole o link aqui';
  @override
  String get people => 'Pessoas';
  @override
  String get permissionDeniedMsg => 'Permissão negada.';
  @override
  String get pleaseWait => 'Aguarde...';
  @override
  String get points => 'Pontos';
  @override
  String get position => 'Posição';
  @override
  String get postDeleted => 'Post excluído';
  @override
  String get postPublished => 'Post publicado!';
  @override
  String get postsThisWeek => 'Posts esta semana';
  @override
  String get previewLabel => 'Prévia';
  @override
  String get primaryLanguageLabel => 'Idioma Principal';
  @override
  String get privacyPolicyTitle2 => 'Política de Privacidade';
  @override
  String get privacySettings => 'Configurações de privacidade';
  @override
  String get privateVisibility => 'Privada';
  @override
  String get processing => 'Processando...';
  @override
  String get profileLinkCopiedMsg => 'Link do perfil copiado!';
  @override
  String get profileUpdated => 'Perfil atualizado!';
  @override
  String get progress => 'Progresso';
  @override
  String get publicVisibility => 'Pública';
  @override
  String get publishStory => 'Publicar story';
  @override
  String get publishing => 'Publicando...';
  @override
  String get purchaseComplete => 'Compra realizada!';
  @override
  String get purchaseError => 'Erro na compra';
  @override
  String get quote => 'Citação';
  @override
  String get realTimeChat => 'Chat em tempo real com seus amigos';
  @override
  String get recentLabel => 'Recentes';
  @override
  String get recoverySent => 'Enviamos um link de recuperação para seu email.';
  @override
  String get removeAvatar => 'Remover avatar';
  @override
  String get removeBlock => 'Remover bloco';
  @override
  String get removeDevice => 'Remover dispositivo';
  @override
  String get reportContent => 'Denunciar conteúdo';
  @override
  String get reportReason => 'Motivo da denúncia';
  @override
  String get reportSubmitted => 'Denúncia enviada';
  @override
  String get resolve => 'Resolver';
  @override
  String get resolved => 'Resolvido';
  @override
  String get reward => 'Recompensa';
  @override
  String get saveChanges => 'Salvar alterações';
  @override
  String get savedPostsPrivate => 'Posts salvos são privados';
  @override
  String get saving => 'Salvando...';
  @override
  String get screeningRoom => 'Sala de exibição';
  @override
  String get searchMembers => 'Buscar membros...';
  @override
  String get searchMusic => 'Buscar música...';
  @override
  String get searchPlaceholder => 'Buscar comunidades, pessoas...';
  @override
  String get securityLabel => 'Segurança';
  @override
  String get selectAtLeast1Member => 'Selecione pelo menos 1 membro';
  @override
  String get selectImage => 'Selecionar imagem';
  @override
  String get selectMembers => 'Selecionar membros';
  @override
  String get selected => 'selecionados';
  @override
  String get sending => 'Enviando...';
  @override
  String get serverErrorMsg => 'Erro no servidor. Tente novamente mais tarde.';
  @override
  String get sessionExpiredMsg => 'Sessão expirada. Faça login novamente.';
  @override
  String get shareProfileAction => 'Compartilhar Perfil';
  @override
  String get sharedFolderTitle => 'Pasta compartilhada';
  @override
  String get showOnlineStatus => 'Mostrar status online';
  @override
  String get size => 'Tamanho';
  @override
  String get skip => 'Pular';
  @override
  String get skipForNow => 'Pular por enquanto';
  @override
  String get sort => 'Ordenar';
  @override
  String get startLive => 'Iniciar live';
  @override
  String get statistics => 'Estatísticas';
  @override
  String get stickersTab => 'Figurinhas';
  @override
  String get storyPublishedMsg => 'Story publicado!';
  @override
  String get strikethroughFormat => 'Tachado';
  @override
  String get takePhoto => 'Tirar foto';
  @override
  String get tapBookmarkToSave => 'Toque no ícone de bookmark nos posts para salvá-los';
  @override
  String get termsOfUseTitle => 'Termos de Uso';
  @override
  String get thankYouForReporting => 'Obrigado por reportar';
  @override
  String get themeColorLabel => 'Cor do Tema';
  @override
  String get thousandsOfCommunities => 'Milhares de comunidades para explorar';
  @override
  String get titles => 'Títulos';
  @override
  String get totalMembers => 'Total de membros';
  @override
  String get transactions => 'Transações';
  @override
  String get type => 'Tipo';
  @override
  String get unblockAction => 'Desbloquear';
  @override
  String get underline => 'Sublinhado';
  @override
  String get unequip => 'Desequipar';
  @override
  String get unlistedVisibility => 'Não listada';
  @override
  String get uploadFile => 'Enviar arquivo';
  @override
  String get userUnblocked => 'Usuário desbloqueado';
  @override
  String get videosLabel => 'Vídeos';
  @override
  String get viewers => 'Espectadores';
  @override
  String get views => 'Visualizações';
  @override
  String get violence => 'Violência';
  @override
  String get visualLabel => 'Visual';
  @override
  String get vote => 'Votar';
  @override
  String get votes => 'votos';
  @override
  String get walletTitle => 'Carteira';
  @override
  String get watchAd => 'Assistir anúncio';
  @override
  String get weWillReviewReport => 'Analisaremos sua denúncia';
  @override
  String get whoCanMessageMe => 'Quem pode me enviar mensagens';
  @override
  String get whoCanSeeProfile => 'Quem pode ver meu perfil';
  @override
  String get writeCommunityGuidelines => 'Escreva as regras da comunidade...';
  @override
  String get writeOnWall => 'Escreva no mural...';

  // PASS 3 — AUTO-GENERATED
  @override
  String get accountLinked => 'Contavinculada com sucesso!';
  @override
  String get active2 => 'Ativas';
  @override
  String get adService => 'AdService';
  @override
  String get addCoverOptional => 'Adicionar capa (opcional)';
  @override
  String get allSessionsRevoked => 'Todas as outras sessões foram encerradas';
  @override
  String get allSubmissionsReviewed => 'Todas as submissões foram revisadas.';
  @override
  String get allow => 'Permitir';
  @override
  String get allowFindByName => 'Permitir que encontrem você por nome';
  @override
  String get allowGroupChatInvitations => 'Permitir convites para chats em grupo';
  @override
  String get allowMentions => 'Permitir que outros mencionem você';
  @override
  String get allowOthersToSendDms => 'Permitir que outros enviem DMs';
  @override
  String get allowed => 'Permitido';
  @override
  String get allowedContent => 'Conteúdo Permitido';
  @override
  String get allowedContentDetails => '• Posts relacionados ao tema da comunidade\n• Fan arts e criações originais\n• Discussões construtivas\n• Memes relacionados ao tema';
  @override
  String get aminoPlus => 'Amino+';
  @override
  String get aminoPlusRate => 'Taxa Amino+';
  @override
  String get aminoPlusSubscribers => 'Assinantes Amino+';
  @override
  String get android => 'Android';
  @override
  String get androidVersion => 'Android';
  @override
  String get animeManga => 'Anime & Mangá';
  @override
  String get anonymous2 => 'Anonimo';
  @override
  String get anyMemberCanJoin => 'Qualquer membro da comunidade pode entrar';
  @override
  String get anyMemberCanParticipate => 'Qualquer membro pode entrar e participar.';
  @override
  String get apiKey => 'AIzaSyAVrtW0plFDgkxfZCDE-FrKzNbKGb0ev1k';
  @override
  String get appPermissions2 => 'Permissões do App';
  @override
  String get approved2 => 'Aprovada';
  @override
  String get artDesign => 'Arte & Design';
  @override
  String get artTheft => 'Art Theft';
  @override
  String get audio2 => 'Áudio';
  @override
  String get authError => 'Erro de autenticação:';
  @override
  String get averageRating => 'Average rating';
  @override
  String get bannedUsers => 'Banidos';
  @override
  String get bannedUsersCount => 'Usuários banidos';
  @override
  String get blockedOnDate => 'Bloqueado em';
  @override
  String get blockedUsers2 => 'Usuários Bloqueados';
  @override
  String get blockedUsersInfo => 'Usuários bloqueados não podem ver seu perfil\nnem enviar mensagens para você.';
  @override
  String get booksWriting => 'Livros & Escrita';
  @override
  String get browser => 'Browser';
  @override
  String get bullying => 'Bullying';
  @override
  String get byAuthor => 'By ';
  @override
  String get cacheCleared2 => 'Cache limpo com sucesso!';
  @override
  String get cacheService => 'CacheService';
  @override
  String get cameraMicrophoneNotifications => 'C e2mera, microfone, notifica e7 f5es';
  @override
  String get cancel2 => 'Cancelar';
  @override
  String get cannotUnlinkLastLogin => 'Não é possível desvincular a única forma de login.';
  @override
  String get catalog => 'Catálogo';
  @override
  String get change => 'Alterar';
  @override
  String get changeEmail => 'Alterar Email';
  @override
  String get chat2 => 'Chat';
  @override
  String get chatInvitations => 'Convites para Chat';
  @override
  String get chatName2 => 'Nome do Chat';
  @override
  String get chatNameIsRequired => 'O nome do chat é obrigatório';
  @override
  String get chatNameRequired => 'O nome do chat é obrigatório.';
  @override
  String get chats2 => 'Chats';
  @override
  String get checkInHistory => 'Histórico de Check-in';
  @override
  String get checkInSequence => 'Sequência de Check-in';
  @override
  String get clear => 'Limpar';
  @override
  String get clearCache2 => 'Limpar Cache';
  @override
  String get clearTempData => 'Isso vai limpar dados tempor e1rios salvos localmente. ';
  @override
  String get closingBracket => ']}';
  @override
  String get cloudDataUnaffected => 'Seus dados na nuvem n e3o ser e3o afetados.';
  @override
  String get coinsInCirculation => 'Coins em circulação';
  @override
  String get coinsPerUserAverage => 'Coins por usuário (média)';
  @override
  String get communitiesList => 'Lista de Comunidades';
  @override
  String get community2 => 'Comunidade';
  @override
  String get communityLabel => 'Comunidade:...';
  @override
  String get communityNameRequired => 'Nome da comunidade é obrigatório';
  @override
  String get confirmContinue => 'Tem certeza que deseja continuar?';
  @override
  String get confirmDeletion => 'Tem certeza? Esta ação é irreversível e todos os seus dados serão apagados.';
  @override
  String get confirmDeletionButton => 'Confirmar Exclus e3o';
  @override
  String get confirmUnblockUser => 'Deseja desbloquear ...?';
  @override
  String get confirmUnlinkAccount => 'Tem certeza que deseja desvincular sua conta ...?';
  @override
  String get confirmationEmailSent => 'Email de confirma e7 e3o enviado!';
  @override
  String get connectWithYourCommunities => 'Conecte-se com suas comunidades favoritas';
  @override
  String get connectedDevices => 'Dispositivos Conectados';
  @override
  String get contributor => 'Contribuidor';
  @override
  String get coverImageUrl => 'URL da imagem de capa';
  @override
  String get curator2 => 'Curador';
  @override
  String get currencyBrl => 'BRL';
  @override
  String get current => 'Atual';
  @override
  String get currentCacheSize => 'Tamanho atual do cache: ...\n\n';
  @override
  String get currentStreak => 'Streak Atual';
  @override
  String get customizePrompt => 'Vamos personalizar sua experiência. Em poucos passos, ';
  @override
  String get data => 'Dados';
  @override
  String get dedicated => 'Dedicado';
  @override
  String get defaultFirebaseOptionsIosNotConfigured => 'DefaultFirebaseOptions não foram configuradas para iOS - ';
  @override
  String get defaultFirebaseOptionsLinuxNotConfigured => 'DefaultFirebaseOptions não foram configuradas para Linux - ';
  @override
  String get defaultFirebaseOptionsMacosNotConfigured => 'DefaultFirebaseOptions não foram configuradas para macOS - ';
  @override
  String get defaultFirebaseOptionsNotSupported => 'DefaultFirebaseOptions não são suportadas para esta plataforma.';
  @override
  String get defaultFirebaseOptionsWebNotConfigured => 'DefaultFirebaseOptions não foram configuradas para web - ';
  @override
  String get defaultFirebaseOptionsWindowsNotConfigured => 'DefaultFirebaseOptions não foram configuradas para Windows - ';
  @override
  String get deleteAccount2 => 'Excluir Conta';
  @override
  String get deleteAccountError => 'Erro ao excluir conta. Tente novamente.';
  @override
  String get deleteButton => 'EXCLUIR';
  @override
  String get describeChatPurpose => 'Descreva o propósito deste chat...';
  @override
  String get describeCorrections => 'Descreva o que precisa ser corrigido...';
  @override
  String get describeGroup => 'Descreva o grupo...';
  @override
  String get descriptionOptional => 'Descrição (opcional)';
  @override
  String get descriptionOptional2 => 'Descrição (opcional)';
  @override
  String get detailedContent => 'Conteúdo detalhado...';
  @override
  String get device => 'Dispositivo';
  @override
  String get deviceRevoked => 'Dispositivo revogado';
  @override
  String get directMessages => 'Mensagens Diretas';
  @override
  String get discover => 'Descubra';
  @override
  String get diy => 'Faça Você Mesmo';
  @override
  String get downloadDataCopy => 'Baixar uma cópia dos seus dados';
  @override
  String get economy => 'Economia';
  @override
  String get editGuidelines2 => 'Editar Guidelines';
  @override
  String get emailAlreadyRegistered => 'Este email já está cadastrado.';
  @override
  String get emailAndPassword => 'Email e Senha';
  @override
  String get entryNotFound => 'Entrada não encontrada';
  @override
  String get entrySentForReview => 'Entrada enviada para revisão dos curadores!';
  @override
  String get entryTitle => 'Título da entrada...';
  @override
  String get errorDetails => 'Detalhes do erro';
  @override
  String get errorLoadingMoreNotifications => 'Erro ao carregar mais notificações';
  @override
  String get errorLoadingStories => 'Erro ao carregar stories.';
  @override
  String get exampleChatName => 'Ex: Discussão de Episódios';
  @override
  String get exampleGroupName => 'Ex: Fan Club do Anime';
  @override
  String get expert => 'Expert';
  @override
  String get exportData2 => 'Exportar Dados';
  @override
  String get exportInProgress => 'Exportação em desenvolvimento';
  @override
  String get exportMyData => 'Exportar Meus Dados';
  @override
  String get failedToLoadData => 'Falha ao carregar dados.';
  @override
  String get ffH => 'FF';
  @override
  String get field => 'Campo';
  @override
  String get finalConfirmation => 'Confirmação Final';
  @override
  String get followersList => 'Lista de Seguidores';
  @override
  String get freeStorage => 'Liberar espa e7o de armazenamento';
  @override
  String get friday => 'Sex';
  @override
  String get games => 'Jogos';
  @override
  String get gamification => 'Gamificação';
  @override
  String get generalRules => 'Regras Gerais';
  @override
  String get generalRulesDetails => '1. Seja respeitoso com todos os membros\n2. Não faça spam ou flood\n3. Mantenha o conteúdo relevante à comunidade\n4. Não compartilhe informações pessoais';
  @override
  String get gif => 'GIF';
  @override
  String get googleApple => 'Google, Apple';
  @override
  String get googleTokenError => 'Não foi possível obter o token do Google.';
  @override
  String get groupCreatedSuccessfully => 'Grupo criado com sucesso!';
  @override
  String get groupName2 => 'Nome do Grupo *';
  @override
  String get guidelinesSaved => 'Guidelines salvas com sucesso!';
  @override
  String get guru => 'Guru';
  @override
  String get highestStreak => 'Maior Streak';
  @override
  String get home2 => 'Início';
  @override
  String get iap => 'IAP';
  @override
  String get image2 => 'Imagem';
  @override
  String get inappropriateContent2 => 'Conteúdo Impróprio';
  @override
  String get incorrectEmailOrPassword => 'Email ou senha incorretos.';
  @override
  String get incredible => 'Incrível!';
  @override
  String get infobox => 'Infobox';
  @override
  String get invalidCallSession => 'Sess 3 de chamada inv 1lida';
  @override
  String get invalidEmail2 => 'Email inválido.';
  @override
  String get invalidUrl => 'URL inválida';
  @override
  String get invitedMembersOnly => 'Apenas membros convidados podem entrar';
  @override
  String get ipAddress => 'IP: $ipAddress';
  @override
  String get irreversibleActionWarning => 'Esta ação é IRREVERSÍVEL. Todos os seus dados, posts, comentários, ';
  @override
  String get joinedChannelInMs => 'Agora: Joined channel ... in ...ms';
  @override
  String get languageChanged => 'Idioma alterado para ...';
  @override
  String get lastAccess2 => 'Último acesso: dd/mm/yyyy';
  @override
  String get lastSevenDays => 'Últimos 7 dias';
  @override
  String get leader2 => 'Líder';
  @override
  String get levelLabel => 'Nível ...';
  @override
  String get levelUp2 => 'Subiu de Nível';
  @override
  String get levelUpAlert => 'SUBIU DE NÍVEL!';
  @override
  String get linkProviderError => 'Erro ao vincular. Tente novamente.';
  @override
  String get linux => 'Linux';
  @override
  String get linuxVersion => 'Linux';
  @override
  String get loadMoreError => 'Erro ao carregar mais itens';
  @override
  String get manageConnectedDevices => 'Gerencie os dispositivos conectados à sua conta. ';
  @override
  String get managePermissions => 'Gerencie as permissões que o NexusHub precisa para funcionar corretamente.';
  @override
  String get maxStreakRecord => 'Recorde: ... dias';
  @override
  String get memesHumor => 'Memes e Humor';
  @override
  String get messageDeleted2 => 'Mensagem apagada';
  @override
  String get messageLikeCommentAlerts => 'Receba alertas de mensagens, curtidas e comentários';
  @override
  String get messagePlaceholder => 'Mensagem...';
  @override
  String get messagesToday => 'Mensagens hoje';
  @override
  String get microphone => 'Microfone';
  @override
  String get monday => 'Seg';
  @override
  String get monetizationRate => 'Taxa de Monetização';
  @override
  String get moviesSeries => 'Filmes & Séries';
  @override
  String get mustBeCommunityMember => 'Você precisa ser membro da comunidade.';
  @override
  String get myRating => 'Minha Avaliação';
  @override
  String get nameMaxLength => 'Nome deve ter no máximo 50 caracteres';
  @override
  String get nameMinLength => 'Nome deve ter no mínimo 3 caracteres';
  @override
  String get nameMinLength2 => 'O nome deve ter pelo menos 3 caracteres';
  @override
  String get newEmail => 'Novo email';
  @override
  String get newPublicChat => 'Novo Chat Público';
  @override
  String get newTitleUnlocked => 'Novo título desbloqueado!';
  @override
  String get newWikiEntry => 'Nova Entrada Wiki';
  @override
  String get nexusHub => 'NexusHub';
  @override
  String get nicknameInUse => 'Este nickname já está em uso.';
  @override
  String get nicknameMaxLength => 'Nickname deve ter no máximo 20 caracteres';
  @override
  String get nicknameMinLength => 'Nickname deve ter no mínimo 3 caracteres';
  @override
  String get nicknameRequired => 'Nickname é obrigatório';
  @override
  String get nicknameValidChars => 'Nickname pode conter apenas letras, números e _';
  @override
  String get noCategoriesAvailable => 'Nenhuma categoria dispon vel';
  @override
  String get noContentToDisplay => 'Nenhum conteúdo para visualizar';
  @override
  String get noEntriesFound => 'Nenhuma entrada encontrada';
  @override
  String get noInternetConnection => 'Sem conexão com a internet. Verifique sua rede.';
  @override
  String get noItemsFound => 'Nenhum item encontrado';
  @override
  String get noPendingWiki => 'Nenhuma wiki pendente';
  @override
  String get noPermission => 'Você não tem permissão para realizar esta ação.';
  @override
  String get noReason => 'Sem motivo';
  @override
  String get noReasonSpecified => 'Sem motivo especificado';
  @override
  String get noRecentReports => 'Nenhuma denúncia recente';
  @override
  String get noRegisteredDevices => 'Nenhum dispositivo registrado';
  @override
  String get noResolvedReports => 'Nenhuma denúncia resolvida';
  @override
  String get noStoriesYet => 'Nenhum story ainda';
  @override
  String get noTitle => 'Sem titulo';
  @override
  String get notRequested => 'Não solicitado';
  @override
  String get notificationWhenReady => 'Você receberá uma notificação quando estiver pronto.';
  @override
  String get offTopic => 'Fora do Tópico';
  @override
  String get onlyFollowBack => 'Apenas quem eu sigo de volta';
  @override
  String get openSettings => 'Abrir Configurações';
  @override
  String get openSystemSettings => 'Abra as configurações do sistema para habilitá-la.';
  @override
  String get operationTimeout => 'A operação demorou muito. Tente novamente.';
  @override
  String get otherDevicesReLogin => 'Todos os outros dispositivos precisarão fazer login novamente.';
  @override
  String get passwordsDoNotMatch2 => 'As senhas não coincidem';
  @override
  String get pending2 => 'Pendentes';
  @override
  String get pendingFlagsCount => 'Pendentes (...)';
  @override
  String get pendingReview2 => 'Pendente de revisao';
  @override
  String get permanentDelete => 'Excluir Permanentemente';
  @override
  String get permanentDeletionNotice => 'mensagens e itens comprados serão permanentemente deletados.\n\n';
  @override
  String get permanentlyDenied => 'Negado permanentemente';
  @override
  String get permissionDenied2 => 'Permissão negada';
  @override
  String get permissionPermanentlyDenied => 'A permissão de ... foi negada permanentemente. ';
  @override
  String get petsAnimals => 'Pets & Animais';
  @override
  String get photosAndMedia => 'Fotos e Mídia';
  @override
  String get plusJakartaSans => 'PlusJakartaSans';
  @override
  String get poll2 => 'Poll';
  @override
  String get positiveNumber => 'Deve ser um número positivo';
  @override
  String get postsToday => 'Posts hoje';
  @override
  String get preferences => 'Prefer eancias';
  @override
  String get prepareDataFile => 'Vamos preparar um arquivo com todos os seus dados (perfil, posts, comentários, mensagens). ';
  @override
  String get preview2 => 'Prévia';
  @override
  String get profileLevel => 'Nível ...';
  @override
  String get profilePicture => 'Foto de perfil';
  @override
  String get prohibitedContent => 'Conteúdo Proibido';
  @override
  String get prohibitedContentDetails => '• NSFW / Conteúdo explícito\n• Bullying ou assédio\n• Roubo de arte (art theft)\n• Propaganda não autorizada\n• Conteúdo discriminatório';
  @override
  String get publicChat => 'Chat Publico';
  @override
  String get publicChatCreated => 'Chat público criado!';
  @override
  String get publicChatsVisible => 'Chats públicos são visíveis para todos os membros da comunidade. ';
  @override
  String get pushNotification => 'PushNotification';
  @override
  String get recentReports => 'Denúncias Recentes';
  @override
  String get regular => 'Regular';
  @override
  String get rejected2 => 'Rejeitada';
  @override
  String get rejectionReason => 'Motivo da rejeição';
  @override
  String get renderFlex => 'Um RenderFlex';
  @override
  String get renderFlexOverflowed => 'RenderFlex transbordou';
  @override
  String get reportedBy => 'Reportado por ...';
  @override
  String get requestButton => 'Solicitar';
  @override
  String get requestSentNotification => 'Solicitação enviada! Você receberá uma notificação.';
  @override
  String get resolved2 => 'Resolvidas';
  @override
  String get response => 'Resposta';
  @override
  String get revoke => 'Revogar';
  @override
  String get revokeAll => 'Revogar Todos';
  @override
  String get revokeAllOthers => 'Revogar Todos os Outros';
  @override
  String get revokeDevice => 'Revogar Dispositivo';
  @override
  String get revokeDeviceConfirmation => 'Isso encerrará a sessão neste dispositivo. ';
  @override
  String get revokeOtherSessions => 'Isso encerrará todas as sessões exceto a atual. ';
  @override
  String get revokeOthers => 'Revogar Outros';
  @override
  String get revokeUnrecognizedDevices => 'Revogue dispositivos que você não reconhece.';
  @override
  String get rolesResponsibilities => 'Cargos e Responsabilidades';
  @override
  String get rolesResponsibilitiesDetails => '• Leader: Gerencia a comunidade e modera conteúdo\n• Curator: Auxilia na moderação e curadoria de wikis\n• Member: Participa ativamente da comunidade';
  @override
  String get saturday => 'Sáb';
  @override
  String get saveFilesAndMedia => 'Necessário para salvar arquivos e mídia';
  @override
  String get screening => 'Screening';
  @override
  String get searchByName => 'Busca por Nome';
  @override
  String get searchCatalog => 'Buscar no catálogo...';
  @override
  String get securityCheck => 'Verificação de Segurança';
  @override
  String get selectCategory => 'Selecione a categoria';
  @override
  String get selectCommunityForGroup => 'Selecione a comunidade para o grupo:';
  @override
  String get selectMembers2 => 'Selecionar Membros';
  @override
  String get sendGalleryImages => 'Necessário para enviar imagens da galeria';
  @override
  String get sendWarning => 'Enviar um aviso ao usuário';
  @override
  String get sessionExpired2 => 'Sua sessão expirou. Faça login novamente.';
  @override
  String get shop => 'Loja';
  @override
  String get showFollowersFollowing => 'Mostrar seus seguidores/seguindo';
  @override
  String get showParticipatedCommunities => 'Mostrar comunidades que você participa';
  @override
  String get solveToContinue => 'Resolva para continuar';
  @override
  String get somethingWentWrong2 => 'Algo deu errado. Tente novamente.';
  @override
  String get stepProgress => 'Passo';
  @override
  String get sticker => 'Sticker';
  @override
  String get storage => 'Armazenamento';
  @override
  String get strikeSystem => 'Sistema de Strikes';
  @override
  String get strikeSystemDetails => '• 1º Strike: Aviso formal\n• 2º Strike: Silenciamento temporário (24h)\n• 3º Strike: Ban permanente da comunidade';
  @override
  String get sunday => 'Dom';
  @override
  String get supportsMarkdown => 'Suporta formatação Markdown';
  @override
  String get takeAction => 'Tomar Ação';
  @override
  String get tapToRetry => 'Toque para tentar novamente';
  @override
  String get temporarilyPreventUser => 'Impedir o usuário de postar/comentar temporariamente';
  @override
  String get textOverflowEllipsis => '║  TextOverflow.ellipsis no widget de texto responsável.   ║\n';
  @override
  String get thursday => 'Qui';
  @override
  String get tip => 'Tip';
  @override
  String get titleRequired => 'Título é obrigatório';
  @override
  String get tooManyAttempts => 'Muitas tentativas. Aguarde alguns minutos.';
  @override
  String get total => 'Total';
  @override
  String get totalCheckIns => 'Total:check-ins';
  @override
  String get totalCheckIns2 => 'Check-ins totais';
  @override
  String get totalMessages => 'Mensagens totais';
  @override
  String get totalPosts => 'Posts totais';
  @override
  String get tuesday => 'Ter';
  @override
  String get typeDeleteConfirm => 'Digite "EXCLUIR" para confirmar a exclusão permanente da sua conta.';
  @override
  String get typeDeleteToConfirm => 'Digite "EXCLUIR" para confirmar:';
  @override
  String get typeDeleteToConfirmAlt => 'Digite EXCLUIR para confirmar';
  @override
  String get unblockUser => 'Desbloquear Usuário';
  @override
  String get unexpectedError => 'Ocorreu um erro inesperado. Tente novamente ou reinicie o app.';
  @override
  String get unexpectedErrorRetry => 'Ocorreu um erro inesperado. Tente novamente.';
  @override
  String get unknown => 'Desconhecido';
  @override
  String get unlinkAccount => 'Desvincular conta';
  @override
  String get untitledDraft => 'Rascunho sem título';
  @override
  String get user2 => 'Usuário';
  @override
  String get user3 => 'Usuario';
  @override
  String get userReLogin => 'O usuário precisará fazer login novamente.';
  @override
  String get value => 'Valor';
  @override
  String get valueRange => 'Deve ser entre';
  @override
  String get valueRequired => 'Valor é obrigatório';
  @override
  String get verify => 'Verificar';
  @override
  String get verifyEmailBeforeLogin => 'Confirme seu email antes de fazer login.';
  @override
  String get video => 'Vídeo';
  @override
  String get videoCallAndPhotoUpload => 'Necessária para chamadas de vídeo e envio de fotos';
  @override
  String get voice => 'Voice';
  @override
  String get voiceCallAndAudioRecording => 'Necessário para chamadas de voz e gravação de áudio';
  @override
  String get weakPassword => 'Senha muito fraca. Use pelo menos 8 caracteres com letras e números.';
  @override
  String get web => 'Web';
  @override
  String get webBrowser => 'Navegador Web';
  @override
  String get wednesday => 'Qua';
  @override
  String get welcomeMessage => 'Bem-vindo ao NexusHub!';
  @override
  String get whoCanFollow => 'Quem pode te seguir';
  @override
  String get wikiApprovalSuccess => 'Wiki aprovada com sucesso!';
  @override
  String get wikiApproved => 'Wiki aprovada!';
  @override
  String get wikiApprovedStatus => 'Wiki aprovada';
  @override
  String get wikiNeedsChanges => 'Wiki precisa de alterações';
  @override
  String get wikiPinned => 'Wiki fixada no seu perfil!';
  @override
  String get wikiRejected => 'Wiki rejeitada';
  @override
  String get wikiRemoved => 'Wiki removida do perfil';
  @override
  String get wikiReview => 'Revisão de Wiki';
  @override
  String get windows => 'Windows';
  @override
  String get windowsVersion => 'Windows';
  @override
  String get wise => 'Sábio';
  @override
  String get writeGuidelines => 'Escreva as guidelines da sua comunidade aqui...\n\nUse ## para títulos de seção\nUse • ou - para listas\nUse ** para negrito';
  @override
  String get writeGuidelinesTab => 'Escreva as guidelines na aba Editor';
  @override
  String get writeWhatYouLike => 'Escreva o que você gosta...';
  @override
  String get yourEntry => 'Your entry';
  @override
  String get yourStory => 'Seu Story';

  // PASS 4 — FINAL CLEANUP
  @override
  String get acceptInvite => 'Aceitar convite';
  @override
  String get accessibleByDirectLink => 'Acessível apenas por link direto';
  @override
  String get actionExecutedSuccess => 'Ação executada com sucesso';
  @override
  String get actionLabel => 'Ação';
  @override
  String get actionsLabel => 'Ações';
  @override
  String get activeLabel2 => 'Ativas';
  @override
  String get adNotAvailable => 'Anúncio não disponível no momento';
  @override
  String get addAtLeastOneImage => 'Adicione pelo menos uma imagem';
  @override
  String get addAtLeastOneQuestion => 'Adicione pelo menos uma pergunta';
  @override
  String get addedToFavorites => 'Adicionado aos favoritos';
  @override
  String get adventurer => 'Aventureiro';
  @override
  String get alerts => 'Alertas';
  @override
  String get allowComments => 'Permitir comentários';
  @override
  String get allowContentHighlight => 'Permitir destaque de conteúdo';
  @override
  String get appearOfflineDesc => 'Apareça como offline para todos os usuários';
  @override
  String get apprentice => 'Aprendiz';
  @override
  String get askCommunity => 'Pergunte à comunidade';
  @override
  String get banUserFromCommunity => 'Banir o usuário da comunidade';
  @override
  String get bioInCommunity => 'Bio nesta comunidade';
  @override
  String get biography => 'Biografia';
  @override
  String get bubble => 'Bolha';
  @override
  String get bubbles => 'Bolhas';
  @override
  String get cannotMessageUser => 'Não é possível enviar mensagem para este usuário';
  @override
  String get centralButtonCreatePosts => 'Botão central para criar posts';
  @override
  String get changeAction => 'Alterar';
  @override
  String get commentsBlocked => 'Comentários bloqueados';
  @override
  String get communication => 'Comunicação';
  @override
  String get communityPublicChatsTab => 'Aba de chats públicos da comunidade';
  @override
  String get completelyInvisible => 'Completamente invisível';
  @override
  String get createNewPost => 'Criar nova publicação';
  @override
  String get currentLabel => 'Atual';
  @override
  String get directMessage => 'Mensagem direta';
  @override
  String get disableProfileComments => 'Desabilitar comentários no perfil';
  @override
  String get downloadYourData => 'Baixar uma cópia dos seus dados';
  @override
  String get earlyAccess => 'Acesso antecipado a novidades';
  @override
  String get earnCoinsLevelUp => 'Ganhe moedas ao subir de nível';
  @override
  String get exclusiveBadge => 'Badge exclusiva no perfil';
  @override
  String get featuredPostsTab => 'Aba de posts em destaque';
  @override
  String get feedEmpty => 'Seu feed está vazio';
  @override
  String get fillTitleOrContent => 'Preencha o título ou conteúdo';
  @override
  String get forwardTo => 'Encaminhar para';
  @override
  String get forwarded => 'Encaminhada';
  @override
  String get freeUpStorage => 'Liberar espaço de armazenamento';
  @override
  String get frenchLang => 'Français';
  @override
  String get friendsOnly => 'Apenas amigos';
  @override
  String get fromFriendsOnly => 'Apenas de amigos';
  @override
  String get getCommunityQuizzes => 'Acerte quizzes da comunidade';
  @override
  String get informActionReason => 'Informe o motivo da ação';
  @override
  String get invalidData => 'Dados inválidos';
  @override
  String get joinDiscussions => 'Participe das discussões';
  @override
  String get layoutResetToDefault => 'Layout resetado para o padrão';
  @override
  String get legendary => 'Lendário';
  @override
  String get mentions => 'Menções';
  @override
  String get moderationActionLabel => 'Ação da moderação';
  @override
  String get moderationWarning => 'Aviso da moderação';
  @override
  String get mythical => 'Mítico';
  @override
  String get nameRequired => 'Nome é obrigatório';
  @override
  String get newMembersNeedApproval => 'Novos membros precisam de aprovação';
  @override
  String get noAchievementsAvailable => 'Nenhuma conquista disponível';
  @override
  String get noAds => 'Sem anúncios';
  @override
  String get noChatFound => 'Nenhum chat encontrado';
  @override
  String get noComments => 'Nenhum comentário';
  @override
  String get noConnections => 'Nenhuma conexão';
  @override
  String get noModerationActions => 'Nenhuma ação de moderação registrada';
  @override
  String get noOneCanCommentWall => 'Ninguém pode comentar no seu mural';
  @override
  String get noSectionsEnabled => 'Nenhuma seção habilitada';
  @override
  String get noTransactionsYet => 'Nenhuma transação ainda';
  @override
  String get noUserFound => 'Nenhum usuário encontrado';
  @override
  String get noWallComments => 'Nenhum comentário no mural';
  @override
  String get notAuthenticated => 'Não autenticado';
  @override
  String get notLinked => 'Não vinculado';
  @override
  String get notificationLabel => 'Notificação';
  @override
  String get notificationSoundsInApp => 'Sons de notificação dentro do app';
  @override
  String get offersNotAvailable => 'Ofertas não disponíveis no momento';
  @override
  String get onlyInvitedMembers => 'Apenas membros convidados podem entrar';
  @override
  String get optionsLabel => 'Opções';
  @override
  String get packageNotFound => 'Pacote não encontrado';
  @override
  String get pauseNotifications => 'Pausar todas as notificações temporariamente';
  @override
  String get pollQuestionRequired => 'A pergunta da enquete é obrigatória';
  @override
  String get portugueseLang => 'Português';
  @override
  String get postDraftsAppearHere => 'Seus rascunhos de posts aparecerão aqui';
  @override
  String get postNotFoundOrNoPermission => 'Post não encontrado ou sem permissão';
  @override
  String get preventNewUsersConversations => 'Impede que novos usuários iniciem conversas';
  @override
  String get projection => 'Projeção';
  @override
  String get publicLabel => 'Público';
  @override
  String get publishContentCommunity => 'Publique conteúdo na comunidade';
  @override
  String get questionRequired => 'A pergunta é obrigatória';
  @override
  String get quizTitleRequired => 'O título do quiz é obrigatório';
  @override
  String get recentPostsTab => 'Aba de posts mais recentes';
  @override
  String get recentSearches => 'Buscas recentes';
  @override
  String get recognizeMember => 'Reconheça um membro';
  @override
  String get removeUserBan => 'Remover o ban do usuário';
  @override
  String get reportsLabel => 'Relatórios';
  @override
  String get requiredField => 'Obrigatório';
  @override
  String get searchCommunityMembers => 'Busque membros desta comunidade';
  @override
  String get searchWikiArticles => 'Busque artigos wiki desta comunidade';
  @override
  String get selectReportReason => 'Selecione o motivo da denúncia';
  @override
  String get selectReportType => 'Selecione o tipo de denúncia';
  @override
  String get sendMessageToAll => 'Enviar mensagem para todos os usuários';
  @override
  String get sharedProfile => 'Perfil compartilhado';
  @override
  String get showWhenOnline => 'Mostrar quando você está online';
  @override
  String get someone => 'Alguém';
  @override
  String get spanishLang => 'Español';
  @override
  String get subscribe => 'Assinar';
  @override
  String get subscriptions => 'Assinaturas';
  @override
  String get tapToDownload => 'Toque para baixar';
  @override
  String get topicCategories => 'Categorias de tópicos';
  @override
  String get uniqueIdentifier => 'Seu identificador único';
  @override
  String get unpinPost => 'Remover a fixação do post';
  @override
  String get userNotAuthenticated => 'Usuário não autenticado';
  @override
  String get usersLabel => 'Usuários';
  @override
  String get vibrateOnNotifications => 'Vibrar ao receber notificações';
  @override
  String get vibration => 'Vibração';
  @override
  String get videoLabel => 'Vídeo';
  @override
  String get watchAction => 'Assistir';
  @override
  String get whenLevelUp => 'Quando sobe de nível';
  @override
  String get whenSomeoneComments => 'Quando alguém comenta no seu post';
  @override
  String get whenSomeoneFollows => 'Quando alguém começa a te seguir';
  @override
  String get whenSomeoneLikes => 'Quando alguém curte seu post';
  @override
  String get whenSomeoneMentions => 'Quando alguém menciona você';

  // PASS 5 — COMPREHENSIVE FINAL
  @override
  String get acceptInviteAction => 'Aceitar convite';
  @override
  String get acceptTermsAndPrivacy => 'Aceito os Termos de Uso e Política de Privacidade';
  @override
  String get accessibleByDirectLinkDesc => 'Acessível apenas por link direto';
  @override
  String get actionAlreadyPerformed => 'Esta ação já foi realizada.';
  @override
  String get actionCannotBeUndone => 'Esta ação não pode ser desfeita.';
  @override
  String get actionLabelGeneral => 'Ação';
  @override
  String get actionType => 'Tipo de Ação';
  @override
  String get actionsLabelGeneral => 'Ações';
  @override
  String get activeLabelFem => 'Ativas';
  @override
  String get activeModules => 'Módulos Ativos';
  @override
  String get adNotAvailableMsg => 'Anúncio não disponível no momento';
  @override
  String get addAtLeast2Options => 'Adicione pelo menos 2 opções';
  @override
  String get addAtLeastOneImageMsg => 'Adicione pelo menos uma imagem';
  @override
  String get addAtLeastOneQuestionMsg => 'Adicione pelo menos uma pergunta';
  @override
  String get addBioDesc => 'Adicione uma bio para que outros membros te conheçam:';
  @override
  String get addMusicAction => 'Adicionar Música';
  @override
  String get addOptionLabel => 'Adicionar Opção';
  @override
  String get addUsefulLinks => 'Adicione links úteis para os membros\nda sua comunidade.';
  @override
  String get addVideoAction => 'Adicionar Vídeo';
  @override
  String get addedToFavoritesMsg => 'Adicionado aos favoritos';
  @override
  String get advancedOptions => 'Opções Avançadas';
  @override
  String get adventurerLabel => 'Aventureiro';
  @override
  String get agreeTermsAndPrivacy => 'Ao continuar, você concorda com os Termos de Uso\ne Política de Privacidade.';
  @override
  String get alertsLabel => 'Alertas';
  @override
  String get allowCommentsLabel => 'Permitir comentários';
  @override
  String get allowContentHighlightSetting => 'Permitir destaque de conteúdo';
  @override
  String get alreadyCheckedInCommunity => 'Você já fez check-in hoje nesta comunidade!';
  @override
  String get alreadyCheckedInToday => 'Você já fez check-in hoje!';
  @override
  String get alreadyHaveAccountQuestion => 'Já tem conta? ';
  @override
  String get alreadyInCommunity => 'Você já faz parte desta comunidade.';
  @override
  String get alreadyMemberCommunity => 'Você já é membro desta comunidade.';
  @override
  String get appearOfflineAllUsers => 'Apareça como offline para todos os usuários';
  @override
  String get applyStrikeDesc => 'Aplicar um strike (3 strikes = ban automático)';
  @override
  String get apprenticeLabel => 'Aprendiz';
  @override
  String get artTheftPlagiarism => 'Art Theft / Plágio';
  @override
  String get askCommunityHint => 'Pergunte à comunidade';
  @override
  String get audioFileUrl => 'URL do arquivo de áudio (.mp3, .ogg)';
  @override
  String get banUserDesc => 'Banir o usuário da comunidade';
  @override
  String get bestCommunitiesForYou => 'as melhores comunidades para você!';
  @override
  String get bestValue => 'Melhor custo-benefício!';
  @override
  String get betterLuckNextTime => 'Mais sorte na próxima vez!';
  @override
  String get bioInCommunityLabel => 'Bio nesta comunidade';
  @override
  String get biographyLabel => 'Biografia';
  @override
  String get blockedUsersCannotSeeProfile => 'Usuários bloqueados não podem ver seu perfil\n';
  @override
  String get blogTitleHint => 'Título do blog...';
  @override
  String get bubbleLabel => 'Bolha';
  @override
  String get bubblesLabel => 'Bolhas';
  @override
  String get bullyingHarassment => 'Bullying / Assédio';
  @override
  String get cameraPermissionsDesc => 'Câmera, microfone, notificações';
  @override
  String get cannotDmYourself => 'Não é possível enviar DM para si mesmo';
  @override
  String get cannotMessageUserMsg => 'Não é possível enviar mensagem para este usuário';
  @override
  String get centralButtonDesc => 'Botão central para criar posts';
  @override
  String get changeLabel => 'Alterar';
  @override
  String get chatDeletedMsg => 'Chat excluído.';
  @override
  String get chatSettingsTitle => 'Configurações do Chat';
  @override
  String get checkInComplete => 'Check-in Completo!';
  @override
  String get checkInEarnReputation => 'Faça check-in e ganhe reputação para aparecer aqui!';
  @override
  String get checkInEveryDay => 'Faça check-in todos os dias';
  @override
  String get checkInForRewards => 'Faça check-in para ganhar recompensas';
  @override
  String get checkInKeepStreak => 'Faça check-in todos os dias para manter sua sequência';
  @override
  String get chooseSections => 'Escolha quais seções serão exibidas na home da comunidade.';
  @override
  String get chooseSomethingMemorable => 'Escolha algo memorável!';
  @override
  String get clearTempDataDesc => 'Isso vai limpar dados temporários salvos localmente. ';
  @override
  String get communicationLabel => 'Comunicação';
  @override
  String get communityIcon => 'Ícone da Comunidade';
  @override
  String get communityNotFound => 'Comunidade não encontrada.';
  @override
  String get communityPublicChatsTabDesc => 'Aba de chats públicos da comunidade';
  @override
  String get communityStatistics => 'Estatísticas da Comunidade';
  @override
  String get communityUpdates => 'Atualizações das suas comunidades';
  @override
  String get completelyInvisibleDesc => 'Completamente invisível';
  @override
  String get configureBottomNav => 'Configure a barra de navegação inferior da comunidade.';
  @override
  String get confirmDeleteChat => 'Tem certeza que deseja apagar este chat? Esta ação não pode ser desfeita.';
  @override
  String get confirmDeleteChat2 => 'Tem certeza que deseja excluir este chat? Esta ação não pode ser desfeita.';
  @override
  String get confirmDeletePost => 'Tem certeza que deseja deletar este post? Esta ação não pode ser desfeita.';
  @override
  String get connectedWithCommunities => 'você estará conectado com comunidades incríveis!';
  @override
  String get connectionsLabelGeneral => 'Conexões';
  @override
  String get consecutiveDaysBonus => '7 dias consecutivos = bônus especial!';
  @override
  String get contentCannotBeEmpty => 'Conteúdo não pode estar vazio';
  @override
  String get conversationRemovedFromList => 'A conversa será removida da sua lista.';
  @override
  String get couldNotAcceptInvite => 'Não foi possível aceitar o convite agora.';
  @override
  String get couldNotConfirmParticipation => 'Não foi possível confirmar sua participação neste chat.';
  @override
  String get couldNotProcessSubscription => 'Não foi possível processar a assinatura.';
  @override
  String get createNewPostLabel => 'Criar nova publicação';
  @override
  String get currentConfiguration => 'Configuração Atual';
  @override
  String get currentLabelGeneral => 'Atual';
  @override
  String get dailyActivities => 'Atividades Diárias';
  @override
  String get dailyAdLimitReached => 'Limite diário de anúncios atingido. Tente amanhã!';
  @override
  String get dailyCheckIn2 => 'Check-in Diário';
  @override
  String get dailyCheckInBarDesc => 'Barra de check-in diário com streak';
  @override
  String get describeActionReason => 'Descreva o motivo da ação...';
  @override
  String get disableProfileCommentsSetting => 'Desabilitar comentários no perfil';
  @override
  String get discussionsAndDebates => 'Discussões e Debates';
  @override
  String get doNotDisturb => 'Não Perturbe';
  @override
  String get doesNotAcceptDMs => 'não aceita mensagens diretas';
  @override
  String get dontHaveAccount2 => 'Não tem conta? ';
  @override
  String get downloadDataDesc => 'Baixar uma cópia dos seus dados';
  @override
  String get earlyAccessDesc => 'Acesso antecipado a novidades';
  @override
  String get earnCoinsLevelUpDesc => 'Ganhe moedas ao subir de nível';
  @override
  String get emptyFieldsGlobal => 'Campos vazios usarão seu perfil global.';
  @override
  String get enableWikiCatalog => 'Habilitar wiki/catálogo';
  @override
  String get enterValidLink => 'Insira um link válido (https://...)';
  @override
  String get errorChangingPin => 'Erro ao alterar fixação.';
  @override
  String get errorExecutingActionRetry => 'Erro ao executar ação. Tente novamente.';
  @override
  String get errorLoadingAd => 'Erro ao carregar anúncio. Tente novamente.';
  @override
  String get exclusiveBadgeDesc => 'Badge exclusiva no perfil';
  @override
  String get executeAction2 => 'Executar Ação';
  @override
  String get exploreCommunities => 'Explore e entre em comunidades para começar!';
  @override
  String get featureTemporarilyUnavailable => 'Funcionalidade temporariamente indisponível.';
  @override
  String get featuredPostsTabDesc => 'Aba de posts em destaque';
  @override
  String get feedEmptyMsg => 'Seu feed está vazio';
  @override
  String get fileNotFoundMsg => 'Arquivo não encontrado.';
  @override
  String get fileTypeNotAllowed => 'Tipo de arquivo não permitido.';
  @override
  String get fillTitleAndUrl => 'Preencha título e URL';
  @override
  String get fillTitleOrContentMsg => 'Preencha o título ou conteúdo';
  @override
  String get freeCoinsMonth => '200 moedas/mês grátis';
  @override
  String get freeUpStorageDesc => 'Liberar espaço de armazenamento';
  @override
  String get friendsOnlyLabel => 'Apenas amigos';
  @override
  String get fromFriendsOnlyLabel => 'Apenas de amigos';
  @override
  String get galleryVideo => 'Vídeo da Galeria';
  @override
  String get generalNotifications => 'Notificações gerais do NexusHub';
  @override
  String get getCommunityQuizzesDesc => 'Acerte quizzes da comunidade';
  @override
  String get hidePostDesc => 'Ocultar o post sem deletá-lo';
  @override
  String get higherStreakDesc => 'Sequência maior = mais XP e moedas';
  @override
  String get highlightDuration => 'Duração do Destaque';
  @override
  String get homePageSections => 'Seções da Página Inicial';
  @override
  String get iconImageUrl => 'URL da imagem do ícone';
  @override
  String get identityFraud => 'Falsidade Ideológica';
  @override
  String get informActionReasonLabel => 'Informe o motivo da ação';
  @override
  String get interactionsAppearHere => 'Quando alguém interagir com você,\naparecerá aqui';
  @override
  String get invalidDataMsg => 'Dados inválidos';
  @override
  String get invalidReference => 'Referência inválida. O item pode ter sido removido.';
  @override
  String get invalidValue => 'Valor inválido.';
  @override
  String get inviteInvalidOrExpired => 'Este convite é inválido ou expirou.';
  @override
  String get itemAlreadyExists => 'Este item já existe.';
  @override
  String get joinDiscussionsDesc => 'Participe das discussões';
  @override
  String get joinedChat => 'Você entrou no chat!';
  @override
  String get joinedCommunity => 'Você entrou na comunidade!';
  @override
  String get layoutResetMsg => 'Layout resetado para o padrão';
  @override
  String get leftChat => 'Você saiu do chat.';
  @override
  String get leftGroup => 'Você saiu do grupo.';
  @override
  String get legendaryLabel => 'Lendário';
  @override
  String get letsGo => 'Vamos Começar!';
  @override
  String get levelUpAction => 'Subir de Nível';
  @override
  String get leveledUp => 'Subiu de Nível';
  @override
  String get likesCommentsFollowers => 'Curtidas, comentários e seguidores';
  @override
  String get linksInGeneralSection => 'Esses links aparecem na seção "General" do menu lateral da comunidade. Arraste para reordenar.';
  @override
  String get loginToAcceptInvite => 'Faça login para aceitar o convite.';
  @override
  String get max10000Chars => 'Máximo 10.000 caracteres';
  @override
  String get max24Chars => 'Máximo 24 caracteres';
  @override
  String get max30Chars => 'Máximo 30 caracteres';
  @override
  String get max500Chars => 'Máximo 500 caracteres';
  @override
  String get mentionsLabel => 'Menções';
  @override
  String get messageToAllMembers => 'Esta mensagem será enviada para todos os membros da comunidade.';
  @override
  String get min3Chars => 'Mínimo 3 caracteres';
  @override
  String get moderationActionLower => 'Ação de moderação';
  @override
  String get moderationActionTitle => 'Ação de Moderação';
  @override
  String get moderationActionsTitle => 'Ações de Moderação';
  @override
  String get moderationAlerts => 'Alertas de moderação';
  @override
  String get moderationLabel => 'Moderação';
  @override
  String get moderationWarningLabel => 'Aviso da moderação';
  @override
  String get musicAddedToPost => 'Música adicionada ao post!';
  @override
  String get musicRecommendations => 'Recomendações Musicais';
  @override
  String get mythicalLabel => 'Mítico';
  @override
  String get nameLinkOptional => 'Dê um nome ao link (opcional):';
  @override
  String get nameRequiredMsg => 'Nome é obrigatório';
  @override
  String get needLoginToComment => 'Você precisa estar logado para comentar.';
  @override
  String get needLoginToCreateCommunity => 'Você precisa estar logado para criar uma comunidade.';
  @override
  String get needNewInvite => 'Para voltar, você precisará de um novo convite.';
  @override
  String get needToBeLoggedIn => 'Você precisa estar logado.';
  @override
  String get newMembersNeedApprovalDesc => 'Novos membros precisam de aprovação';
  @override
  String get newMessageNotifications => 'Notificações de novas mensagens';
  @override
  String get nextPost => 'Próximo Post';
  @override
  String get noAchievementsAvailableMsg => 'Nenhuma conquista disponível';
  @override
  String get noAdsLabel => 'Sem anúncios';
  @override
  String get noChatsJoinedYet => 'Você ainda não entrou em nenhum chat nesta comunidade.';
  @override
  String get noCommentsLabel => 'Nenhum comentário';
  @override
  String get noConnectionsMsg => 'Nenhuma conexão';
  @override
  String get noContentYet => 'Nenhum conteúdo ainda...';
  @override
  String get noModerationActionsMsg => 'Nenhuma ação de moderação registrada';
  @override
  String get noOneCanCommentWallDesc => 'Ninguém pode comentar no seu mural';
  @override
  String get noPermissionEditPost => 'Você não tem permissão para editar este post.';
  @override
  String get noGuidelinesYet => 'Nenhuma diretriz foi definida para esta comunidade ainda.';
  @override
  String get noPublicChatsYet => 'Nenhum chat público ainda.';
  @override
  String get noPublicChatsYetShort => 'Nenhum chat público ainda';
  @override
  String get noSectionsEnabledMsg => 'Nenhuma seção habilitada';
  @override
  String get noTransactionsYetMsg => 'Nenhuma transação ainda';
  @override
  String get noUploadPermission => 'Sem permissão para fazer upload neste local.';
  @override
  String get noUserFoundMsg => 'Nenhum usuário encontrado';
  @override
  String get noWallCommentsMsg => 'Nenhum comentário no mural';
  @override
  String get notAuthenticatedMsg => 'Não autenticado';
  @override
  String get notLinkedLabel => 'Não vinculado';
  @override
  String get notMemberChat => 'Você não é membro deste chat.';
  @override
  String get notMemberChatRetry => 'Você não é membro deste chat. Tente sair e entrar novamente.';
  @override
  String get notMemberCommunity => 'Você não é membro desta comunidade.';
  @override
  String get notificationSettingsComingSoon => 'Configurações de notificação em breve!';
  @override
  String get notificationSingle => 'Notificação';
  @override
  String get notificationSoundsDesc => 'Sons de notificação dentro do app';
  @override
  String get offersNotAvailableMsg => 'Ofertas não disponíveis no momento';
  @override
  String get onlyAcceptsDMs => 'só aceita DMs';
  @override
  String get onlyFollowBackLabel => 'Apenas quem eu sigo de volta';
  @override
  String get onlyInvitedMembersDesc => 'Apenas membros convidados podem entrar';
  @override
  String get optionsLabelGeneral => 'Opções';
  @override
  String get optionsMarkCorrect => 'Opções (marque a correta)';
  @override
  String get orSendMessages => 'nem enviar mensagens para você.';
  @override
  String get packageNotFoundMsg => 'Pacote não encontrado';
  @override
  String get pasteVideoLink => 'Cole o link do vídeo (YouTube, etc.)';
  @override
  String get pauseNotifications2 => 'Pausar Notificações';
  @override
  String get pauseNotificationsDesc => 'Pausar todas as notificações temporariamente';
  @override
  String get pendingReports => 'Denúncias Pendentes';
  @override
  String get pinPostDesc => 'Fixar o post no topo do feed (máx 3 fixados)';
  @override
  String get pollExampleHint => 'Ex: Qual é o melhor anime da temporada?';
  @override
  String get pollQuestionRequiredMsg => 'A pergunta da enquete é obrigatória';
  @override
  String get portugueseBrazil => 'Português (Brasil)';
  @override
  String get postDraftsHere => 'Seus rascunhos de posts aparecerão aqui';
  @override
  String get postNotFoundMsg => 'Post não encontrado.';
  @override
  String get postNotFoundPermission => 'Post não encontrado ou sem permissão';
  @override
  String get postTitleHint => 'Título do post...';
  @override
  String get postingTooFast => 'Você está postando muito rápido. Aguarde um pouco antes de criar outro post.';
  @override
  String get preferencesLabel => 'Preferências';
  @override
  String get preventNewUsersDesc => 'Impede que novos usuários iniciem conversas';
  @override
  String get projectionLabel => 'Projeção';
  @override
  String get publicChatLabel => 'Chat Público';
  @override
  String get publicChatsLabel => 'Chats Públicos';
  @override
  String get publicLabelGeneral => 'Público';
  @override
  String get publicProfile => 'Perfil Público';
  @override
  String get publishContentDesc => 'Publique conteúdo na comunidade';
  @override
  String get pushNotificationSettings => 'Configurações de Notificação Push';
  @override
  String get pushNotifications2 => 'Notificações Push';
  @override
  String get questionRequiredMsg => 'A pergunta é obrigatória';
  @override
  String get quizExampleHint => 'Ex: Quanto você sabe sobre Naruto?';
  @override
  String get quizTitle => 'Título do Quiz';
  @override
  String get quizTitleRequiredMsg => 'O título do quiz é obrigatório';
  @override
  String get recentPostsTabDesc => 'Aba de posts mais recentes';
  @override
  String get recentSearchesLabel => 'Buscas recentes';
  @override
  String get recipientAminoId => 'Amino ID do destinatário';
  @override
  String get recognizeMemberDesc => 'Reconheça um membro';
  @override
  String get removeUserBanAction => 'Remover o ban do usuário';
  @override
  String get removeUserDesc => 'Remover o usuário da comunidade (pode voltar a entrar)';
  @override
  String get reportContentTitle => 'Reportar Conteúdo';
  @override
  String get reportSubmittedThankYou => 'Denúncia enviada. Obrigado!';
  @override
  String get reportSubmittedThanks => 'Denúncia enviada. Obrigado por reportar!';
  @override
  String get reportsLabelGeneral => 'Relatórios';
  @override
  String get requiredLabel => 'Obrigatório';
  @override
  String get requiresApproval => 'Requer Aprovação';
  @override
  String get resetToDefault => 'Resetar para Padrão';
  @override
  String get saveChangesAction => 'Salvar Alterações';
  @override
  String get searchCommunityMembersHint => 'Busque membros desta comunidade';
  @override
  String get searchWikiArticlesHint => 'Busque artigos wiki desta comunidade';
  @override
  String get selectReportReasonLabel => 'Selecione o motivo da denúncia';
  @override
  String get selectReportTypeLabel => 'Selecione o tipo de denúncia';
  @override
  String get selfHarmSuicide => 'Autolesão / Suicídio';
  @override
  String get sendMessageAllUsers => 'Enviar mensagem para todos os usuários';
  @override
  String get settingsApplyOnlyCommunity => 'Estas configurações se aplicam apenas a esta comunidade. ';
  @override
  String get settingsSaved => 'Configurações salvas!';
  @override
  String get showCreateButton => 'Mostrar Botão Criar (+)';
  @override
  String get showWhenOnlineDesc => 'Mostrar quando você está online';
  @override
  String get songNameHint => 'Nome da música (ex: Artist - Song)';
  @override
  String get storageLabel => 'Armazenamento';
  @override
  String get streakLost => 'Sequência Perdida';
  @override
  String get streakLostRecoverMsg => 'Você perdeu sua sequência! Gaste moedas para recuperá-la.';
  @override
  String get streakResetsDesc => 'Perca um dia e a sequência volta para 1';
  @override
  String get submitReport => 'Enviar Denúncia';
  @override
  String get subscribeAction => 'Assinar';
  @override
  String get subscribePrice => 'Assinar por R\$ 14,90/mês';
  @override
  String get subscriptionsLabel => 'Assinaturas';
  @override
  String get subtitleHint => 'Subtítulo...';
  @override
  String get tapToAddVideo => 'Toque em + para adicionar um vídeo';
  @override
  String get tellAboutYourself => 'Conte um pouco sobre você...';
  @override
  String get thisMonth => 'Este Mês';
  @override
  String get titleHint => 'Título...';
  @override
  String get titleOptionalHint => 'Título (opcional)...';
  @override
  String get titleRequiredMsg => 'O título é obrigatório';
  @override
  String get tooManyComments => 'Muitos comentários em pouco tempo. Aguarde um momento.';
  @override
  String get tooManyReports => 'Você já enviou muitas denúncias recentemente. Tente novamente mais tarde.';
  @override
  String get tooManyTransfers => 'Muitas transferências em pouco tempo. Aguarde antes de transferir novamente.';
  @override
  String get topicCategoriesLabel => 'Categorias de tópicos';
  @override
  String get transactionHistory => 'Histórico de Transações';
  @override
  String get uniqueIdentifierLabel => 'Seu identificador único';
  @override
  String get unlistedLabel => 'Não Listada';
  @override
  String get unpinPostAction => 'Remover a fixação do post';
  @override
  String get useButtonToCreate => 'Use o botão + para criar um!';
  @override
  String get userAminoId => 'Amino ID do usuário';
  @override
  String get usernameCharsAllowed => 'Apenas letras, números, _, . e -';
  @override
  String get usernameNotAllowed => 'Nome de usuário não permitido';
  @override
  String get usersLabelGeneral => 'Usuários';
  @override
  String get vibrateOnNotificationsDesc => 'Vibrar ao receber notificações';
  @override
  String get vibrationLabel => 'Vibração';
  @override
  String get videoLabelGeneral => 'Vídeo';
  @override
  String get videoTitleOptional => 'Título do vídeo (opcional)';
  @override
  String get visualCustomization => 'Customização Visual';
  @override
  String get waitingForHostVideo => 'Aguardando o host adicionar um vídeo...';
  @override
  String get warningsStrikesActions => 'Avisos, strikes e ações sobre seu conteúdo';
  @override
  String get watchAdAction => 'Assistir Anúncio';
  @override
  String get watchAdsAction => 'Assistir Anúncios';
  @override
  String get watchLabel => 'Assistir';
  @override
  String get watchVideoAction => 'Assistir Vídeo';
  @override
  String get welcomeToCommunity => 'Bem-vindo à comunidade!';
  @override
  String get whatDoYouWantToKnow => 'O que você quer saber?';
  @override
  String get whenLevelUpNotif => 'Quando sobe de nível';
  @override
  String get whenSomeoneCommentsNotif => 'Quando alguém comenta no seu post';
  @override
  String get whenSomeoneFollowsNotif => 'Quando alguém começa a te seguir';
  @override
  String get whenSomeoneLikesNotif => 'Quando alguém curte seu post';
  @override
  String get whenSomeoneMentionsNotif => 'Quando alguém menciona você';
  @override
  String get writeBioHint => 'Escreva sua bio... Use **negrito**, *itálico*, ~~tachado~~';
  @override
  String get writeContentHere => 'Escreva seu conteúdo aqui...';

  // PASS 6 — INTERPOLATED METHODS
  @override
  String streakDaysLabel(int streak)=>'$streak Dias na Sequência';
  @override
  String timeAgoMonths(int months)=>'${months}m atrás';
  @override
  String timeAgoDays(int days)=>'${days}d atrás';
  @override
  String timeAgoHours(int hours)=>'${hours}h atrás';
  @override
  String timeAgoMinutes(int minutes)=>'${minutes}min atrás';
  @override
  String viewsCountLabel(int count)=>'$count visualizações';
  @override
  String optionNumber(int number)=>'Opção $number';
  @override
  String viewCommentsCount(int count)=>'Ver $count comentários';
  @override
  String replyInComments(int count)=>'Responda nos comentários abaixo • $count respostas';
  @override
  String dayOfStreak(int days)=>'Dia $days de sequência!';
  @override
  String wonExtraCoins(int coins)=>'Você ganhou $coins moedas extras!';
  @override
  String freeCoinsRemaining(int remaining)=>'Ganhe 5 moedas grátis ($remaining restantes)';
  @override
  String get checkInDaily => 'Check-in\nDiário';
  @override
  String get quizDaily => 'Quiz\nDiário';
  @override
  String get chatPublicNewline => 'Chat\nPúblico';
  @override
  String get defaultAllowedContent => '• Posts relacionados ao tema da comunidade\n• Fan arts e criações originais\n• Discussões construtivas\n• Memes relacionados ao tema';
  @override
  String get defaultGuidelines => '1. Seja respeitoso com todos os membros\n2. Não faça spam ou flood\n3. Mantenha o conteúdo relevante à comunidade\n4. Não compartilhe informações pessoais';
  @override
  String get defaultProhibitedContent => '• NSFW / Conteúdo explícito\n• Bullying ou assédio\n• Roubo de arte (art theft)\n• Propaganda não autorizada\n• Conteúdo discriminatório';
  @override
  String get defaultRoles => '• Leader: Gerencia a comunidade e modera conteúdo\n• Curator: Auxilia na moderação e curadoria de wikis\n• Member: Participa ativamente da comunidade';
  @override
  String get defaultStrikePolicy => '• 1º Strike: Aviso formal\n• 2º Strike: Silenciamento temporário (24h)\n• 3º Strike: Ban permanente da comunidade';
  @override
  String get guidelinesEditorHint => 'Escreva as guidelines da sua comunidade aqui...\n\nUse ## para títulos de seção\nUse • ou - para listas\nUse ** para negrito';

  // PASS 7 — FINAL INTERPOLATED
  @override
  String get yourUniqueIdDesc => 'Seu ID único é como outros membros vão te encontrar. ';
  @override
  @override
  String get mediaLabel => 'mídia';
  @override
  String get moderationActions30d => 'Ações de Moderação (30d)';
  @override
  String joinedCommunityName(String name)=>'Você entrou em "$name"!';
  @override
  String checkInStreakMsg(int streak, int coins)=>'Check-in feito! Sequência: $streak dia${streak > 1 ? "s" : ""} (+$coins moedas)';
  @override
  String get leadersTitle => 'LÍDERES';
  @override
  String levelAndRep(int level, int reputation)=>'Nível $level • $reputation rep';
  @override
  @override
  String timeAgoMonthsShort(int months)=>'${months}m atrás';
  @override
  String timeAgoDaysShort(int days)=>'${days}d atrás';
  @override
  String timeAgoHoursShort(int hours)=>'${hours}h atrás';
  @override
  String timeAgoMinutesShort(int minutes)=>'${minutes}min atrás';
  @override
  @override
  String receivedWarning(String reason)=>'Você recebeu um aviso: $reason';
  @override
  String removedFromCommunity(String reason)=>'Você foi removido da comunidade: $reason';
  @override
  String get aminoIdInUse => 'Esse Amino ID já está em uso.';
  @override
  String get tryAgainGeneric => 'Tente novamente.';
  @override
  String pausedUntil(String dateTime)=>'Pausado até $dateTime';
  @override
  String entryApprovedMsg(String title)=>'Sua entrada "$title" foi aprovada e está visível no catálogo.';
  @override
  String entryNeedsChanges(String title, String reason)=>'Sua entrada "$title" precisa de alterações: $reason';
  @override
  String get textOverflowHint => '║  TextOverflow.ellipsis no widget de texto responsável.   ║\n';

  // PASS 8 — NON-ACCENTED STRINGS
  @override
  String get addCover => 'Adicionar Capa';
  @override
  String get addQuestion2 => 'Adicionar Pergunta';
  @override
  String get addCaptionHint => 'Adicionar legenda...';
  @override
  String get addContextHint => 'Adicione contexto ou detalhes (opcional)...';
  @override
  String get aminoId => 'Amino ID';
  @override
  String get inviteOnly => 'Apenas Convite';
  @override
  String get fileSentSuccess => 'Arquivo enviado com sucesso!';
  @override
  String get bannerCover => 'Banner / Capa';
  @override
  String get welcomeBanner => 'Banner de Boas-Vindas';
  @override
  String get bottomBar => 'Barra Inferior';
  @override
  String get blogPublishedSuccess => 'Blog publicado com sucesso!';
  @override
  String get broadcastSent => 'Broadcast enviado!';
  @override
  String get searchChatHint => 'Buscar chat...';
  @override
  String get searchEverythingHint => 'Busque por comunidades, pessoas ou posts';
  @override
  String get carousel => 'Carrossel';
  @override
  String get helpCenter => 'Central de Ajuda';
  @override
  String get privateChatLabel => 'Chat Privado';
  @override
  String get groupChatLabel => 'Chat em Grupo';
  @override
  String get liveChats2 => 'Chats ao Vivo';
  @override
  String get checkInLabel => 'Check-in';
  @override
  String get startConversation2 => 'Comece a conversa!';
  @override
  String get howItWorks => 'Como funciona';
  @override
  String get shareLinkTitle => 'Compartilhar Link';
  @override
  String get copiedMsg => 'Copiado!';
  @override
  String get copyLink => 'Copiar Link';
  @override
  String get createScreeningRoom => 'Criar Screening Room';
  @override
  String get leaveEmptyBio => 'Deixe vazio para usar a bio global';
  @override
  String get leaveEmptyGlobal => 'Deixe vazio para usar o global';
  @override
  String get deleteAction2 => 'Deletar';
  @override
  String get deletePost2 => 'Deletar Post';
  @override
  String get describeBugHint => 'Descreva o bug encontrado...';
  @override
  String get describeLinkHint => 'Descreva o link (opcional)...';
  @override
  String get highlights => 'Destaques';
  @override
  String get additionalDetailsHint => 'Detalhes adicionais (opcional)...';
  @override
  String get saySomethingHint => 'Diga algo...';
  @override
  String get typeMessageHint => 'Digite a mensagem...';
  @override
  String get typeQuestionHint => 'Digite a pergunta...';
  @override
  String get editMessage => 'Editar Mensagem';
  @override
  String get editPost => 'Editar Post';
  @override
  String get editMessageHint => 'Editar mensagem...';
  @override
  String get pollCreatedSuccess => 'Enquete criada com sucesso!';
  @override
  String get joinChat => 'Entrar no Chat';
  @override
  String get joinCommunityStartChat => 'Entre em uma comunidade e comece a conversar!';
  @override
  String get sendingImage => 'Enviando imagem...';
  @override
  String get sendBroadcast => 'Enviar Broadcast';
  @override
  String get sendTip => 'Enviar Gorjeta';
  @override
  String get sendProps => 'Enviar Props';
  @override
  String get errorLoadingPosts => 'Erro ao carregar posts';
  @override
  String get errorCreatingCommunity => 'Erro ao criar comunidade. Tente novamente.';
  @override
  String get errorCreatingPoll => 'Erro ao criar enquete. Tente novamente.';
  @override
  String get errorCreatingQuiz => 'Erro ao criar quiz. Tente novamente.';
  @override
  String get errorCreatingRoom => 'Erro ao criar sala. Tente novamente.';
  @override
  String get errorUnlinking => 'Erro ao desvincular. Tente novamente.';
  @override
  String get errorForwarding => 'Erro ao encaminhar. Tente novamente.';
  @override
  String get errorPublishing2 => 'Erro ao publicar. Tente novamente.';
  @override
  String get errorCheckIn => 'Erro no check-in. Tente novamente.';
  @override
  String get writeStoryHint => 'Escreva algo para o story';
  @override
  String get writeHereHint => 'Escreva aqui...';
  @override
  String get writeCaptionHint => 'Escreva uma legenda...';
  @override
  String get highlightsStyle => 'Estilo dos Destaques';
  @override
  String get clickHereExample => 'Ex: Clique aqui';
  @override
  String get deleteChatTitle => 'Excluir Chat';
  @override
  String get deleteDraftQuestion => 'Excluir rascunho?';
  @override
  String get showOnlineCount => 'Exibe contagem de online na bottom bar';
  @override
  String get doCheckIn2 => 'Fazer Check-in';
  @override
  String get recentFeed => 'Feed Recente';
  @override
  String get pendingFlags => 'Flags Pendentes';
  @override
  String get chatBackground => 'Fundo do Chat';
  @override
  String get gifAddedToPost => 'GIF adicionado ao post!';
  @override
  String get rotate => 'Girar';
  @override
  String get grid2 => 'Grade';
  @override
  String get galleryImage => 'Imagem da Galeria';
  @override
  String get insertLink2 => 'Inserir Link';
  @override
  String get linkOnClick => 'Link ao clicar (opcional)';
  @override
  String get linkSharedSuccess => 'Link compartilhado com sucesso!';
  @override
  String get linkCopied => 'Link copiado!';
  @override
  String get linkRemoved2 => 'Link removido.';
  @override
  String get oldest => 'Mais antigos';
  @override
  String get mostPopular => 'Mais populares';
  @override
  String get mostRecent => 'Mais recentes';
  @override
  String get totalMembers2 => 'Membros Total';
  @override
  String get chatMembers => 'Membros do Chat';
  @override
  String get welcomeMessage2 => 'Mensagem de Boas-Vindas';
  @override
  String get pinnedMessages => 'Mensagens Fixadas';
  @override
  String get nothingToSave => 'Nada para salvar';
  @override
  String get noGifFound => 'Nenhum GIF encontrado';
  @override
  String get noMembers => 'Nenhum membro';
  @override
  String get noPostFound => 'Nenhum post encontrado';
  @override
  String get noWallMessages => 'Nenhuma mensagem no mural';
  @override
  String get communityNameRequired2 => 'Nome da Comunidade *';
  @override
  String get roomName => 'Nome da sala';
  @override
  String get newMembers7d => 'Novos Membros (7d)';
  @override
  String get hiddenLabel => 'Oculta';
  @override
  String get hidePost => 'Ocultar Post';
  @override
  String get sortBy => 'Ordenar por';
  @override
  String get orTypeValue => 'Ou digite um valor...';
  @override
  String get profileUpdatedSuccess => 'Perfil atualizado com sucesso!';
  @override
  String get communityProfileUpdated => 'Perfil da comunidade atualizado!';
  @override
  String get questionAndAnswer => 'Pergunta & Resposta';
  @override
  String get questionPublishedSuccess => 'Pergunta publicada com sucesso!';
  @override
  String get postUpdated => 'Post atualizado!';
  @override
  String get postCreatedSuccess => 'Post criado com sucesso!';
  @override
  String get postDeleted2 => 'Post deletado';
  @override
  String get postHiddenFromFeed => 'Post ocultado do seu feed';
  @override
  String get postPublishedSuccess => 'Post publicado com sucesso!';
  @override
  String get privateLabel => 'Privado';
  @override
  String get searchMyChats => 'Procurar Meus Chats';
  @override
  String get rewards => 'Recompensas';
  @override
  String get reportAction => 'Reportar';
  @override
  String get reportBug => 'Reportar Bug';
  @override
  String get logOutAction => 'Sair da Conta';
  @override
  String get leaveChatTitle => 'Sair do Chat';
  @override
  String get holdToFavorite => 'Segure para favoritar';
  @override
  String get selectCrosspostCommunity => 'Selecione a comunidade destino para o crosspost';
  @override
  String get selectCommunity2 => 'Selecione uma comunidade';
  @override
  String get selectImage2 => 'Selecione uma imagem';
  @override
  String get luckyDraw => 'Sorteio';
  @override
  String get storyLabel => 'Story';
  @override
  String get taglineLabel => 'Tagline';
  @override
  String get confirmLeaveChat => 'Tem certeza que deseja sair deste chat?';
  @override
  String get tryLuckExtraCoins => 'Tente a sorte por moedas extras!';
  @override
  String get postType => 'Tipo de post';
  @override
  String get takePhoto2 => 'Tirar Foto';
  @override
  String get tapToAddImage => 'Toque para adicionar imagem';
  @override
  String get bannerImageUrl => 'URL da imagem do banner';
  @override
  String get bannerImageUrlOptional => 'URL da imagem do banner (opcional)';
  @override
  String get customBgUrlHint => 'URL personalizada do fundo...';
  @override
  String get customBannerDesc => 'Um banner customizado exibido no topo da home.';
  @override
  String get seeAll2 => 'Ver Tudo';
  @override
  String get orLabel => 'ou';
  @override
  String get repairCoins => 'Reparar (50 moedas)';
  @override
  String get bannerTextHint => 'Texto do banner (ex: Bem-vindo!)';
  @override
  String get oneDay => '1 dia';
  @override
  String get oneHour => '1h';
  @override
  String get twentyFourHours => '24h';
  @override
  String get threeDays => '3 dias';
  @override
  String get thirtyDays => '30 dias';
  @override
  String get sixHours => '6h';
  @override
  String get sevenDays => '7 dias';
  @override
  String get noItemAvailable => 'Nenhum item disponível';
  @override
  String get searchUser => 'Buscar Usuário';
  @override
  String get globalSettings => 'Configurações Globais';
  @override
  String get reportsTitle => 'Relatórios';
  @override
  String get startConversationWithUser => 'Iniciar conversa com um usuário';
  @override
  String get createCommunityNewline => 'Criar\nComunidade';
  @override
  String get wikiEntryNewline => 'Entrada\nWiki';
  @override
  String get coinShopNewline => 'Loja de\nCoins';
  @override
  String get globalRankingNewline => 'Ranking\nGlobal';
  @override
  String amountCoinsTransferred(int amount)=>'$amount coins transferidos!';
  @override
  String nicknameUnblocked(String nickname)=>'$nickname desbloqueado';
  @override
  String reactionSent(String reaction)=>'$reaction enviado!';
  @override
  String propsAmountSent(int amount)=>'$amount props enviados!';
  @override
  String totalVotesLabel(int count)=>'$count votos';
  @override
  String postCommentsCountReplies(int count)=>'$count respostas';
  @override
  String coinsEarnedLabel(int coins)=>'+$coins Moedas';
  @override
  String xpEarnedLabel(int xp)=>'+$xp XP';
  @override
  String rewardCoinsLabel(int coins)=>'+$coins moedas!';
  @override
  String providerUnlinked(String provider)=>'Conta $provider desvinculada.';
  @override
  String costCoinsLabel(int amount)=>'Custo: $amount coins';
  @override
  String leftCommunityName(String name)=>'Você saiu de "$name".';

  // PASS 9 — FINAL
  @override
  String get quizCreatedSuccess => 'Quiz criado com sucesso!';
  @override
  String get errorPrefix => 'Erro: ';
  @override
  String get startConversationUser => 'Iniciar conversa com um usuário';
  @override
  String get noItemAvailableMsg => 'Nenhum item disponível';

  // FINAL CLEANUP
  @override
  String memberCountMembers(int count)=>'$count members';
  @override
  String errorPurchase(String error)=>'Erro na compra: $error';
  @override
  String errorGeneric(String error)=>'Erro: $error';
  @override
  String currentBalanceCoins(String coins)=>'Saldo atual: $coins coins';
  @override
  String leftCommunityMsg(String name)=>'Você saiu de "$name".';
  @override
  String pollQuestion(String question)=>'📊 $question';
  @override
  String get pinnedLabel => '📌 Fixado';
  @override
  String get externalLink => 'Link Externo';
  @override
  String get pollOptionsLabel => 'Opções da Enquete';
  @override
  String get quizQuestionsLabel => 'Perguntas do Quiz';
  @override
  String get optionLabel => 'Opção';
  @override
  String optionN(int n)=>'Opção $n';
  @override
  String questionN(int n)=>'Pergunta $n';
  @override
  String amountCoins(int amount)=>'$amount coins';

  // SISTEMA DE NÍVEIS — Nomes dos 20 níveis
  @override
  String get levelTitleNovice => 'Novato';
  @override
  String get levelTitleBeginner => 'Iniciante';
  @override
  String get levelTitleApprentice => 'Aprendiz';
  @override
  String get levelTitleExplorer => 'Explorador';
  @override
  String get levelTitleWarrior => 'Guerreiro';
  @override
  String get levelTitleVeteran => 'Veterano';
  @override
  String get levelTitleSpecialist => 'Especialista';
  @override
  String get levelTitleMaster => 'Mestre';
  @override
  String get levelTitleGrandMaster => 'Grão-Mestre';
  @override
  String get levelTitleChampion => 'Campeão';
  @override
  String get levelTitleHero => 'Herói';
  @override
  String get levelTitleGuardian => 'Guardião';
  @override
  String get levelTitleSentinel => 'Sentinela';
  @override
  String get levelTitleLegendary => 'Lendário';
  @override
  String get levelTitleMythical => 'Mítico';
  @override
  String get levelTitleDivine => 'Divino';
  @override
  String get levelTitleCelestial => 'Celestial';
  @override
  String get levelTitleTranscendent => 'Transcendente';
  @override
  String get levelTitleSupreme => 'Supremo';
  @override
  String get levelTitleUltimate => 'Supremo Final';
  @override
  String get allRankings => 'Todos os Rankings';
  @override
  String get viewAllRankings => 'Ver Todos os Rankings';
  @override
  String get beActiveMemberMsg => 'Ser um membro ativo desta Comunidade ajuda você a ganhar reputação e a subir de nível!';
  @override
  String get levelMaxReached => 'Nível máximo alcançado!';
  @override
  String get currentLevel => 'Nível Atual';
  @override
  String get nextLevel => 'Próximo Nível';
  @override
  String get repToNextLevel => 'Reputação para o próximo nível';

  // TELA DE RANKINGS / NÍVEL
  @override
  String reputationPointsLabel(int points)=>'$points Pontos de Reputação';
  @override
  String repProgressLabel(int current, int total)=>'$current/$total REP';
  @override
  String daysToLevelUp(int days)=>'~$days dias para subir de nível';


  // ── Achievements screen (layout Amino) ──
  @override
  String get myStatistics => 'Minhas Estatísticas';
  @override
  String get statsUpdatedWithDelay => 'Números são atualizados com atraso';
  @override
  String get checkInActivity => 'Atividade de Check-In';
  @override
  String get minutesLabel => 'Minutos';
  @override
  String get last24Hours => 'Últimas 24 Horas';
  @override
  String get achievementsUnlocked => 'Conquistas desbloqueadas';
  @override
  String get inProgress => 'Em progresso';
  @override
  String get newAchievementsUnlocked => 'Novas conquistas desbloqueadas';

  // CHECK-IN MESSAGES
  @override
  String checkInSuccessMsg(int rep, int streak)=>'Check-in! +$rep rep | Sequência: $streak dias';
  @override
  String plusReputationLabel(int amount)=>'+$amount reputação';

  @override
  String get holdAndDragToReorder => 'Segure e arraste os cards para reordenar';

  @override
  String streakRestoredMsg(int days)=>'Streak restaurada! $days dias consecutivos.';
  @override
  String get insufficientCoins => 'Moedas insuficientes';
  @override
  String get noBio => 'Sem biografia';
  @override
  String get tapToAddBio => 'Clique aqui para adicionar sua biografia!';
  @override
  String memberSinceLabel(String month, int year, int days)=>'Membro desde $month $year ($days dias)';
  // DRAWER MENU ITEMS
  @override
  String get drawerExit => 'Sair';
  @override
  String get drawerMyChats => 'Meus Chats';
  @override
  String get drawerPublicChatrooms => 'Salas Públicas';
  @override
  String get drawerLeaderboards => 'Ranking';
  @override
  String get drawerMembers => 'Membros';
  @override
  String get drawerEditCommunity => 'Editar Comunidade';
  @override
  String get drawerFlagCenter => 'Central de Denúncias';
  @override
  String get drawerStatistics => 'Estatísticas';
  @override
  String get drawerVisitor => 'Visitante';
  @override
  String get drawerLvLabel => 'Nv';
  // LEADERBOARD
  @override
  String get thisWeek => 'Esta Semana';
  @override
  String lvBadge(int level)=>'Nv.$level';
  // LEAVE COMMUNITY CONFIRM
  @override
  String leaveCommunityConfirmMsg(String communityName)=>'Tem certeza que deseja sair de "$communityName"? Você poderá entrar novamente depois.';
  @override
  String dayLabel(int n)=>'D$n';

  // BLOCK USER
  @override
  String get blockConfirmTitle => 'Bloquear este usuário?';
  @override
  String get blockConfirmMsg => 'Ele não poderá ver seu perfil, posts ou entrar em contato com você.';
  @override
  String get blockSuccess => 'Usuário bloqueado com sucesso.';
  // EMAIL CHANGE
  @override
  String get emailChangeReauthInfo => 'Confirme sua senha atual para continuar.';
  @override
  String get emailChangeDualConfirmInfo => 'Um link de confirmação será enviado para o seu email atual e para o novo. A troca só será efetivada após ambos serem confirmados.';
  @override
  String get emailChangeSentBoth => 'Links de confirmação enviados! Verifique a caixa de entrada do seu email atual e do novo.';
  @override
  String get emailSameAsCurrent => 'Este já é o seu email atual.';
  // AMINO ID VALIDATION
  @override
  String get aminoIdInvalidChars => 'Apenas letras, números e underscores são permitidos.';
    // REPOST
  @override
  String get repost => 'Repostar';
  @override
  String get repostAction => 'Republicar';
  @override
  String get repostSuccess => 'Republicado com sucesso!';
  @override
  String get repostAlreadyExists => 'Você já republicou este post.';
  @override
  String get repostConfirmTitle => 'Republicar post?';
  @override
  String get repostConfirmMsg => 'Este post aparecerá no seu perfil e no feed da comunidade como um repost.';
  @override
  String get repostNotificationTitle => 'Novo Repost';
  @override
  String repostNotificationBody(String username)=>'$username republicou seu post.';
  String repostedBy(String username) => '$username repostou';

  // Wiki create screen strings
  @override
  String get wikiTitleRequired => 'O título é obrigatório';
  @override
  String get wikiNeedOneSection => 'É necessário pelo menos uma seção';
  @override
  String get wikiPublishedSuccess => 'Entrada wiki publicada com sucesso!';
  @override
  String get wikiEntry => 'Entrada Wiki';
  @override
  String get wikiDescription => 'Descrição...';
}
