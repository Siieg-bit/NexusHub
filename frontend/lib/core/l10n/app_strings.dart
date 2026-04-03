/// Interface abstrata para todas as strings do app.
/// Cada idioma implementa esta interface com suas traduções.
abstract class AppStrings {
  // GERAL
  String get appName;
  String get ok;
  String get cancel;
  String get save;
  String get delete;
  String get edit;
  String get close;
  String get back;
  String get next;
  String get done;
  String get loading;
  String get error;
  String get retry;
  String get search;
  String get seeAll;
  String get share;
  String get report;
  String get block;
  String get confirm;
  String get yes;
  String get no;
  String get noResults;
  String get somethingWentWrong;
  String get tryAgainLater;
  String get copiedToClipboard;

  // AUTENTICAÇÃO
  String get login;
  String get signUp;
  String get logout;
  String get email;
  String get password;
  String get forgotPassword;
  String get resetPassword;
  String get createAccount;
  String get alreadyHaveAccount;
  String get dontHaveAccount;
  String get loginWithGoogle;
  String get loginWithApple;
  String get orContinueWith;
  String get welcomeBack;
  String get getStarted;

  // NAVEGAÇÃO
  String get home;
  String get explore;
  String get communities;
  String get chats;
  String get profile;
  String get notifications;
  String get settings;
  String get feed;
  String get latest;
  String get popular;
  String get online;
  String get me;

  // COMUNIDADES
  String get joinCommunity;
  String get leaveCommunity;
  String get createCommunity;
  String get communityName;
  String get communityDescription;
  String get members;
  String get onlineMembers;
  String get guidelines;
  String get editGuidelines;
  String get joined;
  String get pending;
  String get myCommunities;
  String get discoverCommunities;
  String get newCommunities;
  String get forYou;
  String get trendingNow;
  String get categories;
  String get inviteLink;

  // POSTS
  String get createPost;
  String get writePost;
  String get title;
  String get content;
  String get addImage;
  String get addPoll;
  String get addQuiz;
  String get tags;
  String get publish;
  String get draft;
  String get like;
  String get comment;
  String get comments;
  String get bookmark;
  String get bookmarked;
  String get featured;
  String get pinned;
  String get crosspost;
  String get crosspostTo;
  String get selectCommunity;
  String get writeComment;
  String get noPostsYet;
  String get deletePost;
  String get deletePostConfirm;
  String get reportPost;
  String get featurePost;
  String get pinPost;

  // CHAT
  String get newChat;
  String get newGroupChat;
  String get privateChat;
  String get groupChat;
  String get typeMessage;
  String get sendMessage;
  String get voiceMessage;
  String get stickers;
  String get gifs;
  String get attachImage;
  String get reply;
  String get typing;
  String get isTyping;
  String get groupName;
  String get addMembers;
  String get leaveGroup;
  String get noChatsYet;
  String get startConversation;

  // PERFIL
  String get editProfile;
  String get nickname;
  String get bio;
  String get level;
  String get reputation;
  String get followers;
  String get following;
  String get follow;
  String get unfollow;
  String get posts;
  String get wall;
  String get stories;
  String get linkedCommunities;
  String get pinnedWikis;
  String get achievements;
  String get checkIn;
  String get dailyCheckIn;
  String get streak;

  // WIKI
  String get wiki;
  String get createWiki;
  String get wikiEntries;
  String get curatorReview;
  String get approve;
  String get reject;
  String get pendingReview;
  String get approved;
  String get rejected;
  String get pinToProfile;
  String get unpinFromProfile;
  String get rating;
  String get whatILike;

  // NOTIFICAÇÕES
  String get markAllAsRead;
  String get noNotifications;
  String get likedYourPost;
  String get commentedOnYourPost;
  String get followedYou;
  String get mentionedYou;
  String get invitedYou;
  String get levelUp;
  String get newAchievement;

  // MODERAÇÃO
  String get moderation;
  String get adminPanel;
  String get flagCenter;
  String get ban;
  String get unban;
  String get kick;
  String get mute;
  String get warn;
  String get strike;
  String get reason;
  String get duration;
  String get permanent;
  String get executeAction;
  String get leader;
  String get curator;
  String get member;

  // CONFIGURAÇÕES
  String get generalSettings;
  String get darkMode;
  String get lightMode;
  String get language;
  String get pushNotifications;
  String get privacy;
  String get blockedUsers;
  String get clearCache;
  String get cacheCleared;
  String get about;
  String get version;
  String get termsOfService;
  String get privacyPolicy;
  String get deleteAccount;
  String get deleteAccountConfirm;
  String get logoutConfirm;

  // TEMPO
  String get justNow;
  String get minutesAgo;
  String get hoursAgo;
  String get daysAgo;
  String get yesterday;
  String get today;

  // ERROS
  String get networkError;
  String get sessionExpired;
  String get permissionDenied;
  String get notFound;
  String get serverError;

  // ══════════════════════════════════════════════════════════════════════════
  // STRINGS ADICIONAIS (migração i18n)
  // ══════════════════════════════════════════════════════════════════════════
  String get accept;
  String get acceptTerms;
  String get actionError;
  String get actionSuccess;
  String get active;
  String get addAtLeastOneImage;
  String get addAtLeastOneQuestion;
  String get addAtLeastTwoOptions;
  String get addCover;
  String get addMusic;
  String get addOption;
  String get addQuestion;
  String get addVideo;
  String get advancedOptions;
  String get allSessionsRevoked;
  String get alreadyCheckedIn;
  String get appPermissions;
  String get appearance;
  String get apply;
  String get audio;
  String get change;
  String get changeEmail;
  String get checkInError;
  String get coins;
  String get confirmPassword;
  String get current;
  String get dailyReward;
  String get deleteChat;
  String get deleteChatError;
  String get deleteDraft;
  String get deleteError;
  String get deletePermanently;
  String get enableBanner;
  String get enterGroupName;
  String get fileSentSuccess;
  String get genericError;
  String get insertLink;
  String get insufficientBalance;
  String get joinedChat;
  String get leaveChat;
  String get leaveChatConfirm;
  String get leaveChatError;
  String get leaveCommunityError;
  String get linkCopied;
  String get loadChatsError;
  String get loginRequired;
  String get messageForwarded;
  String get moderationAction;
  String get nameLink;
  String get newWikiEntry;
  String get noCommunityFound;
  String get noMemberFound;
  String get noWallComments;
  String get openSettings;
  String get or;
  String get permissionDeniedTitle;
  String get pinChatError;
  String get pollQuestionRequired;
  String get private;
  String get profileLinkCopied;
  String get public;
  String get publishError;
  String get questionRequired;
  String get rejectionReason;
  String get reorderCommunities;
  String get reportBug;
  String get revokeAllOthers;
  String get revokeDevice;
  String get saveError;
  String get sendError;
  String get settingsSaved;
  String get showOnlineCount;
  String get startConversationWith;
  String get titleRequired;
  String get uploadError;
  String get visibility;
  String get waitingParticipants;
  String get welcomeBanner;
  String get writeOnWall;
}
