import 'app_strings.dart';
import 'package:amino_clone/core/services/ota_translation_service.dart';

/// Camada OTA para traduções remotas com fallback local.
///
/// Esta classe evita alterar os arquivos `app_strings_*.dart` existentes.
/// Getters simples podem ser sobrescritos pelo servidor; métodos com
/// parâmetros permanecem delegados ao fallback local para preservar
/// interpolação, pluralização e regras gramaticais por idioma.
class OtaAppStrings implements AppStrings {
  const OtaAppStrings({
    required this.locale,
    required this.fallback,
  });

  final String locale;
  final AppStrings fallback;

  @override
  String get appName => OtaTranslationService.translate(locale, 'appName', fallback.appName);

  @override
  String get ok => OtaTranslationService.translate(locale, 'ok', fallback.ok);

  @override
  String get cancel => OtaTranslationService.translate(locale, 'cancel', fallback.cancel);

  @override
  String get save => OtaTranslationService.translate(locale, 'save', fallback.save);

  @override
  String get delete => OtaTranslationService.translate(locale, 'delete', fallback.delete);

  @override
  String get edit => OtaTranslationService.translate(locale, 'edit', fallback.edit);

  @override
  String get close => OtaTranslationService.translate(locale, 'close', fallback.close);

  @override
  String get back => OtaTranslationService.translate(locale, 'back', fallback.back);

  @override
  String get next => OtaTranslationService.translate(locale, 'next', fallback.next);

  @override
  String get done => OtaTranslationService.translate(locale, 'done', fallback.done);

  @override
  String get loading => OtaTranslationService.translate(locale, 'loading', fallback.loading);

  @override
  String get error => OtaTranslationService.translate(locale, 'error', fallback.error);

  @override
  String get retry => OtaTranslationService.translate(locale, 'retry', fallback.retry);

  @override
  String get search => OtaTranslationService.translate(locale, 'search', fallback.search);

  @override
  String get seeAll => OtaTranslationService.translate(locale, 'seeAll', fallback.seeAll);

  @override
  String get share => OtaTranslationService.translate(locale, 'share', fallback.share);

  @override
  String get report => OtaTranslationService.translate(locale, 'report', fallback.report);

  @override
  String get block => OtaTranslationService.translate(locale, 'block', fallback.block);

  @override
  String get confirm => OtaTranslationService.translate(locale, 'confirm', fallback.confirm);

  @override
  String get yes => OtaTranslationService.translate(locale, 'yes', fallback.yes);

  @override
  String get no => OtaTranslationService.translate(locale, 'no', fallback.no);

  @override
  String get noResults => OtaTranslationService.translate(locale, 'noResults', fallback.noResults);

  @override
  String get somethingWentWrong => OtaTranslationService.translate(locale, 'somethingWentWrong', fallback.somethingWentWrong);

  @override
  String get tryAgainLater => OtaTranslationService.translate(locale, 'tryAgainLater', fallback.tryAgainLater);

  @override
  String get copiedToClipboard => OtaTranslationService.translate(locale, 'copiedToClipboard', fallback.copiedToClipboard);

  @override
  String get login => OtaTranslationService.translate(locale, 'login', fallback.login);

  @override
  String get signUp => OtaTranslationService.translate(locale, 'signUp', fallback.signUp);

  @override
  String get logout => OtaTranslationService.translate(locale, 'logout', fallback.logout);

  @override
  String get email => OtaTranslationService.translate(locale, 'email', fallback.email);

  @override
  String get password => OtaTranslationService.translate(locale, 'password', fallback.password);

  @override
  String get forgotPassword => OtaTranslationService.translate(locale, 'forgotPassword', fallback.forgotPassword);

  @override
  String get resetPassword => OtaTranslationService.translate(locale, 'resetPassword', fallback.resetPassword);

  @override
  String get createAccount => OtaTranslationService.translate(locale, 'createAccount', fallback.createAccount);

  @override
  String get alreadyHaveAccount => OtaTranslationService.translate(locale, 'alreadyHaveAccount', fallback.alreadyHaveAccount);

  @override
  String get dontHaveAccount => OtaTranslationService.translate(locale, 'dontHaveAccount', fallback.dontHaveAccount);

  @override
  String get loginWithGoogle => OtaTranslationService.translate(locale, 'loginWithGoogle', fallback.loginWithGoogle);

  @override
  String get loginWithApple => OtaTranslationService.translate(locale, 'loginWithApple', fallback.loginWithApple);

  @override
  String get orContinueWith => OtaTranslationService.translate(locale, 'orContinueWith', fallback.orContinueWith);

  @override
  String get welcomeBack => OtaTranslationService.translate(locale, 'welcomeBack', fallback.welcomeBack);

  @override
  String get getStarted => OtaTranslationService.translate(locale, 'getStarted', fallback.getStarted);

  @override
  String get home => OtaTranslationService.translate(locale, 'home', fallback.home);

  @override
  String get explore => OtaTranslationService.translate(locale, 'explore', fallback.explore);

  @override
  String get communities => OtaTranslationService.translate(locale, 'communities', fallback.communities);

  @override
  String get chats => OtaTranslationService.translate(locale, 'chats', fallback.chats);

  @override
  String get profile => OtaTranslationService.translate(locale, 'profile', fallback.profile);

  @override
  String get notifications => OtaTranslationService.translate(locale, 'notifications', fallback.notifications);

  @override
  String get settings => OtaTranslationService.translate(locale, 'settings', fallback.settings);

  @override
  String get feed => OtaTranslationService.translate(locale, 'feed', fallback.feed);

  @override
  String get latest => OtaTranslationService.translate(locale, 'latest', fallback.latest);

  @override
  String get popular => OtaTranslationService.translate(locale, 'popular', fallback.popular);

  @override
  String get online => OtaTranslationService.translate(locale, 'online', fallback.online);

  @override
  String get me => OtaTranslationService.translate(locale, 'me', fallback.me);

  @override
  String get joinCommunity => OtaTranslationService.translate(locale, 'joinCommunity', fallback.joinCommunity);

  @override
  String get leaveCommunity => OtaTranslationService.translate(locale, 'leaveCommunity', fallback.leaveCommunity);

  @override
  String get createCommunity => OtaTranslationService.translate(locale, 'createCommunity', fallback.createCommunity);

  @override
  String get communityName => OtaTranslationService.translate(locale, 'communityName', fallback.communityName);

  @override
  String get communityDescription => OtaTranslationService.translate(locale, 'communityDescription', fallback.communityDescription);

  @override
  String get members => OtaTranslationService.translate(locale, 'members', fallback.members);

  @override
  String get onlineMembers => OtaTranslationService.translate(locale, 'onlineMembers', fallback.onlineMembers);

  @override
  String get guidelines => OtaTranslationService.translate(locale, 'guidelines', fallback.guidelines);

  @override
  String get editGuidelines => OtaTranslationService.translate(locale, 'editGuidelines', fallback.editGuidelines);

  @override
  String get joined => OtaTranslationService.translate(locale, 'joined', fallback.joined);

  @override
  String get pending => OtaTranslationService.translate(locale, 'pending', fallback.pending);

  @override
  String get myCommunities => OtaTranslationService.translate(locale, 'myCommunities', fallback.myCommunities);

  @override
  String get discoverCommunities => OtaTranslationService.translate(locale, 'discoverCommunities', fallback.discoverCommunities);

  @override
  String get newCommunities => OtaTranslationService.translate(locale, 'newCommunities', fallback.newCommunities);

  @override
  String get forYou => OtaTranslationService.translate(locale, 'forYou', fallback.forYou);

  @override
  String get trendingNow => OtaTranslationService.translate(locale, 'trendingNow', fallback.trendingNow);

  @override
  String get categories => OtaTranslationService.translate(locale, 'categories', fallback.categories);

  @override
  String get inviteLink => OtaTranslationService.translate(locale, 'inviteLink', fallback.inviteLink);

  @override
  String get createPost => OtaTranslationService.translate(locale, 'createPost', fallback.createPost);

  @override
  String get writePost => OtaTranslationService.translate(locale, 'writePost', fallback.writePost);

  @override
  String get title => OtaTranslationService.translate(locale, 'title', fallback.title);

  @override
  String get content => OtaTranslationService.translate(locale, 'content', fallback.content);

  @override
  String get addImage => OtaTranslationService.translate(locale, 'addImage', fallback.addImage);

  @override
  String get addPoll => OtaTranslationService.translate(locale, 'addPoll', fallback.addPoll);

  @override
  String get addQuiz => OtaTranslationService.translate(locale, 'addQuiz', fallback.addQuiz);

  @override
  String get tags => OtaTranslationService.translate(locale, 'tags', fallback.tags);

  @override
  String get publish => OtaTranslationService.translate(locale, 'publish', fallback.publish);

  @override
  String get draft => OtaTranslationService.translate(locale, 'draft', fallback.draft);

  @override
  String get like => OtaTranslationService.translate(locale, 'like', fallback.like);

  @override
  String get comment => OtaTranslationService.translate(locale, 'comment', fallback.comment);

  @override
  String get comments => OtaTranslationService.translate(locale, 'comments', fallback.comments);

  @override
  String get bookmark => OtaTranslationService.translate(locale, 'bookmark', fallback.bookmark);

  @override
  String get bookmarked => OtaTranslationService.translate(locale, 'bookmarked', fallback.bookmarked);

  @override
  String get featured => OtaTranslationService.translate(locale, 'featured', fallback.featured);

  @override
  String get pinned => OtaTranslationService.translate(locale, 'pinned', fallback.pinned);

  @override
  String get crosspost => OtaTranslationService.translate(locale, 'crosspost', fallback.crosspost);

  @override
  String get crosspostTo => OtaTranslationService.translate(locale, 'crosspostTo', fallback.crosspostTo);

  @override
  String get selectCommunity => OtaTranslationService.translate(locale, 'selectCommunity', fallback.selectCommunity);

  @override
  String get writeComment => OtaTranslationService.translate(locale, 'writeComment', fallback.writeComment);

  @override
  String get noPostsYet => OtaTranslationService.translate(locale, 'noPostsYet', fallback.noPostsYet);

  @override
  String get deletePost => OtaTranslationService.translate(locale, 'deletePost', fallback.deletePost);

  @override
  String get deletePostConfirm => OtaTranslationService.translate(locale, 'deletePostConfirm', fallback.deletePostConfirm);

  @override
  String get reportPost => OtaTranslationService.translate(locale, 'reportPost', fallback.reportPost);

  @override
  String get featurePost => OtaTranslationService.translate(locale, 'featurePost', fallback.featurePost);

  @override
  String get pinPost => OtaTranslationService.translate(locale, 'pinPost', fallback.pinPost);

  @override
  String get newChat => OtaTranslationService.translate(locale, 'newChat', fallback.newChat);

  @override
  String get newGroupChat => OtaTranslationService.translate(locale, 'newGroupChat', fallback.newGroupChat);

  @override
  String get privateChat => OtaTranslationService.translate(locale, 'privateChat', fallback.privateChat);

  @override
  String get groupChat => OtaTranslationService.translate(locale, 'groupChat', fallback.groupChat);

  @override
  String get typeMessage => OtaTranslationService.translate(locale, 'typeMessage', fallback.typeMessage);

  @override
  String get sendMessage => OtaTranslationService.translate(locale, 'sendMessage', fallback.sendMessage);

  @override
  String get voiceMessage => OtaTranslationService.translate(locale, 'voiceMessage', fallback.voiceMessage);

  @override
  String get stickers => OtaTranslationService.translate(locale, 'stickers', fallback.stickers);

  @override
  String get gifs => OtaTranslationService.translate(locale, 'gifs', fallback.gifs);

  @override
  String get attachImage => OtaTranslationService.translate(locale, 'attachImage', fallback.attachImage);

  @override
  String get reply => OtaTranslationService.translate(locale, 'reply', fallback.reply);

  @override
  String get typing => OtaTranslationService.translate(locale, 'typing', fallback.typing);

  @override
  String get isTyping => OtaTranslationService.translate(locale, 'isTyping', fallback.isTyping);

  @override
  String get groupName => OtaTranslationService.translate(locale, 'groupName', fallback.groupName);

  @override
  String get addMembers => OtaTranslationService.translate(locale, 'addMembers', fallback.addMembers);

  @override
  String get leaveGroup => OtaTranslationService.translate(locale, 'leaveGroup', fallback.leaveGroup);

  @override
  String get noChatsYet => OtaTranslationService.translate(locale, 'noChatsYet', fallback.noChatsYet);

  @override
  String get startConversation => OtaTranslationService.translate(locale, 'startConversation', fallback.startConversation);

  @override
  String get editProfile => OtaTranslationService.translate(locale, 'editProfile', fallback.editProfile);

  @override
  String get nickname => OtaTranslationService.translate(locale, 'nickname', fallback.nickname);

  @override
  String get bio => OtaTranslationService.translate(locale, 'bio', fallback.bio);

  @override
  String get level => OtaTranslationService.translate(locale, 'level', fallback.level);

  @override
  String get reputation => OtaTranslationService.translate(locale, 'reputation', fallback.reputation);

  @override
  String get followers => OtaTranslationService.translate(locale, 'followers', fallback.followers);

  @override
  String get following => OtaTranslationService.translate(locale, 'following', fallback.following);

  @override
  String get follow => OtaTranslationService.translate(locale, 'follow', fallback.follow);

  @override
  String get unfollow => OtaTranslationService.translate(locale, 'unfollow', fallback.unfollow);

  @override
  String get posts => OtaTranslationService.translate(locale, 'posts', fallback.posts);

  @override
  String get wall => OtaTranslationService.translate(locale, 'wall', fallback.wall);

  @override
  String get stories => OtaTranslationService.translate(locale, 'stories', fallback.stories);

  @override
  String get linkedCommunities => OtaTranslationService.translate(locale, 'linkedCommunities', fallback.linkedCommunities);

  @override
  String get pinnedWikis => OtaTranslationService.translate(locale, 'pinnedWikis', fallback.pinnedWikis);

  @override
  String get achievements => OtaTranslationService.translate(locale, 'achievements', fallback.achievements);

  @override
  String get checkIn => OtaTranslationService.translate(locale, 'checkIn', fallback.checkIn);

  @override
  String get dailyCheckIn => OtaTranslationService.translate(locale, 'dailyCheckIn', fallback.dailyCheckIn);

  @override
  String get streak => OtaTranslationService.translate(locale, 'streak', fallback.streak);

  @override
  String get wiki => OtaTranslationService.translate(locale, 'wiki', fallback.wiki);

  @override
  String get createWiki => OtaTranslationService.translate(locale, 'createWiki', fallback.createWiki);

  @override
  String get wikiEntries => OtaTranslationService.translate(locale, 'wikiEntries', fallback.wikiEntries);

  @override
  String get curatorReview => OtaTranslationService.translate(locale, 'curatorReview', fallback.curatorReview);

  @override
  String get approve => OtaTranslationService.translate(locale, 'approve', fallback.approve);

  @override
  String get reject => OtaTranslationService.translate(locale, 'reject', fallback.reject);

  @override
  String get pendingReview => OtaTranslationService.translate(locale, 'pendingReview', fallback.pendingReview);

  @override
  String get approved => OtaTranslationService.translate(locale, 'approved', fallback.approved);

  @override
  String get rejected => OtaTranslationService.translate(locale, 'rejected', fallback.rejected);

  @override
  String get pinToProfile => OtaTranslationService.translate(locale, 'pinToProfile', fallback.pinToProfile);

  @override
  String get unpinFromProfile => OtaTranslationService.translate(locale, 'unpinFromProfile', fallback.unpinFromProfile);

  @override
  String get rating => OtaTranslationService.translate(locale, 'rating', fallback.rating);

  @override
  String get whatILike => OtaTranslationService.translate(locale, 'whatILike', fallback.whatILike);

  @override
  String get markAllAsRead => OtaTranslationService.translate(locale, 'markAllAsRead', fallback.markAllAsRead);

  @override
  String get noNotifications => OtaTranslationService.translate(locale, 'noNotifications', fallback.noNotifications);

  @override
  String get likedYourPost => OtaTranslationService.translate(locale, 'likedYourPost', fallback.likedYourPost);

  @override
  String get commentedOnYourPost => OtaTranslationService.translate(locale, 'commentedOnYourPost', fallback.commentedOnYourPost);

  @override
  String get followedYou => OtaTranslationService.translate(locale, 'followedYou', fallback.followedYou);

  @override
  String get mentionedYou => OtaTranslationService.translate(locale, 'mentionedYou', fallback.mentionedYou);

  @override
  String get invitedYou => OtaTranslationService.translate(locale, 'invitedYou', fallback.invitedYou);

  @override
  String get levelUp => OtaTranslationService.translate(locale, 'levelUp', fallback.levelUp);

  @override
  String get newAchievement => OtaTranslationService.translate(locale, 'newAchievement', fallback.newAchievement);

  @override
  String get moderation => OtaTranslationService.translate(locale, 'moderation', fallback.moderation);

  @override
  String get adminPanel => OtaTranslationService.translate(locale, 'adminPanel', fallback.adminPanel);

  @override
  String get flagCenter => OtaTranslationService.translate(locale, 'flagCenter', fallback.flagCenter);

  @override
  String get ban => OtaTranslationService.translate(locale, 'ban', fallback.ban);

  @override
  String get unban => OtaTranslationService.translate(locale, 'unban', fallback.unban);

  @override
  String get kick => OtaTranslationService.translate(locale, 'kick', fallback.kick);

  @override
  String get mute => OtaTranslationService.translate(locale, 'mute', fallback.mute);

  @override
  String get warn => OtaTranslationService.translate(locale, 'warn', fallback.warn);

  @override
  String get strike => OtaTranslationService.translate(locale, 'strike', fallback.strike);

  @override
  String get reason => OtaTranslationService.translate(locale, 'reason', fallback.reason);

  @override
  String get duration => OtaTranslationService.translate(locale, 'duration', fallback.duration);

  @override
  String get permanent => OtaTranslationService.translate(locale, 'permanent', fallback.permanent);

  @override
  String get executeAction => OtaTranslationService.translate(locale, 'executeAction', fallback.executeAction);

  @override
  String get leader => OtaTranslationService.translate(locale, 'leader', fallback.leader);

  @override
  String get curator => OtaTranslationService.translate(locale, 'curator', fallback.curator);

  @override
  String get member => OtaTranslationService.translate(locale, 'member', fallback.member);

  @override
  String get generalSettings => OtaTranslationService.translate(locale, 'generalSettings', fallback.generalSettings);

  @override
  String get darkMode => OtaTranslationService.translate(locale, 'darkMode', fallback.darkMode);

  @override
  String get lightMode => OtaTranslationService.translate(locale, 'lightMode', fallback.lightMode);

  @override
  String get language => OtaTranslationService.translate(locale, 'language', fallback.language);

  @override
  String get pushNotifications => OtaTranslationService.translate(locale, 'pushNotifications', fallback.pushNotifications);

  @override
  String get privacy => OtaTranslationService.translate(locale, 'privacy', fallback.privacy);

  @override
  String get blockedUsers => OtaTranslationService.translate(locale, 'blockedUsers', fallback.blockedUsers);

  @override
  String get clearCache => OtaTranslationService.translate(locale, 'clearCache', fallback.clearCache);

  @override
  String get cacheCleared => OtaTranslationService.translate(locale, 'cacheCleared', fallback.cacheCleared);

  @override
  String get about => OtaTranslationService.translate(locale, 'about', fallback.about);

  @override
  String get version => OtaTranslationService.translate(locale, 'version', fallback.version);

  @override
  String get termsOfService => OtaTranslationService.translate(locale, 'termsOfService', fallback.termsOfService);

  @override
  String get privacyPolicy => OtaTranslationService.translate(locale, 'privacyPolicy', fallback.privacyPolicy);

  @override
  String get deleteAccount => OtaTranslationService.translate(locale, 'deleteAccount', fallback.deleteAccount);

  @override
  String get deleteAccountConfirm => OtaTranslationService.translate(locale, 'deleteAccountConfirm', fallback.deleteAccountConfirm);

  @override
  String get logoutConfirm => OtaTranslationService.translate(locale, 'logoutConfirm', fallback.logoutConfirm);

  @override
  String get justNow => OtaTranslationService.translate(locale, 'justNow', fallback.justNow);

  @override
  String get minutesAgo => OtaTranslationService.translate(locale, 'minutesAgo', fallback.minutesAgo);

  @override
  String get hoursAgo => OtaTranslationService.translate(locale, 'hoursAgo', fallback.hoursAgo);

  @override
  String get daysAgo => OtaTranslationService.translate(locale, 'daysAgo', fallback.daysAgo);

  @override
  String get yesterday => OtaTranslationService.translate(locale, 'yesterday', fallback.yesterday);

  @override
  String get today => OtaTranslationService.translate(locale, 'today', fallback.today);

  @override
  String get networkError => OtaTranslationService.translate(locale, 'networkError', fallback.networkError);

  @override
  String get sessionExpired => OtaTranslationService.translate(locale, 'sessionExpired', fallback.sessionExpired);

  @override
  String get permissionDenied => OtaTranslationService.translate(locale, 'permissionDenied', fallback.permissionDenied);

  @override
  String get notFound => OtaTranslationService.translate(locale, 'notFound', fallback.notFound);

  @override
  String get serverError => OtaTranslationService.translate(locale, 'serverError', fallback.serverError);

  @override
  String get account => OtaTranslationService.translate(locale, 'account', fallback.account);

  @override
  String get checkYourEmail => OtaTranslationService.translate(locale, 'checkYourEmail', fallback.checkYourEmail);

  @override
  String get confirmYourPassword => OtaTranslationService.translate(locale, 'confirmYourPassword', fallback.confirmYourPassword);

  @override
  String get createAPassword => OtaTranslationService.translate(locale, 'createAPassword', fallback.createAPassword);

  @override
  String get currentPassword => OtaTranslationService.translate(locale, 'currentPassword', fallback.currentPassword);

  @override
  String get emailHint => OtaTranslationService.translate(locale, 'emailHint', fallback.emailHint);

  @override
  String get enterYourEmail => OtaTranslationService.translate(locale, 'enterYourEmail', fallback.enterYourEmail);

  @override
  String get incorrectPassword => OtaTranslationService.translate(locale, 'incorrectPassword', fallback.incorrectPassword);

  @override
  String get logInAction => OtaTranslationService.translate(locale, 'logInAction', fallback.logInAction);

  @override
  String get passwordsDoNotMatch => OtaTranslationService.translate(locale, 'passwordsDoNotMatch', fallback.passwordsDoNotMatch);

  @override
  String get sessionExpiredPleaseLogInAgain => OtaTranslationService.translate(locale, 'sessionExpiredPleaseLogInAgain', fallback.sessionExpiredPleaseLogInAgain);

  @override
  String get access => OtaTranslationService.translate(locale, 'access', fallback.access);

  @override
  String get community => OtaTranslationService.translate(locale, 'community', fallback.community);

  @override
  String get createCommunityTitle => OtaTranslationService.translate(locale, 'createCommunityTitle', fallback.createCommunityTitle);

  @override
  String get modules => OtaTranslationService.translate(locale, 'modules', fallback.modules);

  @override
  String get myCommunitiesTitle => OtaTranslationService.translate(locale, 'myCommunitiesTitle', fallback.myCommunitiesTitle);

  @override
  String get noCommunitiesFound => OtaTranslationService.translate(locale, 'noCommunitiesFound', fallback.noCommunitiesFound);

  @override
  String get noPostsInThisCommunity => OtaTranslationService.translate(locale, 'noPostsInThisCommunity', fallback.noPostsInThisCommunity);

  @override
  String get recommendedCommunities => OtaTranslationService.translate(locale, 'recommendedCommunities', fallback.recommendedCommunities);

  @override
  String get addOption => OtaTranslationService.translate(locale, 'addOption', fallback.addOption);

  @override
  String get addQuestion => OtaTranslationService.translate(locale, 'addQuestion', fallback.addQuestion);

  @override
  String get blog => OtaTranslationService.translate(locale, 'blog', fallback.blog);

  @override
  String get createPoll => OtaTranslationService.translate(locale, 'createPoll', fallback.createPoll);

  @override
  String get divider => OtaTranslationService.translate(locale, 'divider', fallback.divider);

  @override
  String get drafts => OtaTranslationService.translate(locale, 'drafts', fallback.drafts);

  @override
  String get list => OtaTranslationService.translate(locale, 'list', fallback.list);

  @override
  String get listed => OtaTranslationService.translate(locale, 'listed', fallback.listed);

  @override
  String get newBlog => OtaTranslationService.translate(locale, 'newBlog', fallback.newBlog);

  @override
  String get newPoll => OtaTranslationService.translate(locale, 'newPoll', fallback.newPoll);

  @override
  String get newQuiz => OtaTranslationService.translate(locale, 'newQuiz', fallback.newQuiz);

  @override
  String get noSavedPosts => OtaTranslationService.translate(locale, 'noSavedPosts', fallback.noSavedPosts);

  @override
  String get poll => OtaTranslationService.translate(locale, 'poll', fallback.poll);

  @override
  String get post => OtaTranslationService.translate(locale, 'post', fallback.post);

  @override
  String get question => OtaTranslationService.translate(locale, 'question', fallback.question);

  @override
  String get quiz => OtaTranslationService.translate(locale, 'quiz', fallback.quiz);

  @override
  String get savedPosts => OtaTranslationService.translate(locale, 'savedPosts', fallback.savedPosts);

  @override
  String get savedPostsArePrivate => OtaTranslationService.translate(locale, 'savedPostsArePrivate', fallback.savedPostsArePrivate);

  @override
  String get tapTheBookmarkIconOnPostsToSaveThem => OtaTranslationService.translate(locale, 'tapTheBookmarkIconOnPostsToSaveThem', fallback.tapTheBookmarkIconOnPostsToSaveThem);

  @override
  String get camera => OtaTranslationService.translate(locale, 'camera', fallback.camera);

  @override
  String get chat => OtaTranslationService.translate(locale, 'chat', fallback.chat);

  @override
  String get end => OtaTranslationService.translate(locale, 'end', fallback.end);

  @override
  String get errorLoadingChats => OtaTranslationService.translate(locale, 'errorLoadingChats', fallback.errorLoadingChats);

  @override
  String get errorOpeningChatTryAgain => OtaTranslationService.translate(locale, 'errorOpeningChatTryAgain', fallback.errorOpeningChatTryAgain);

  @override
  String get errorPinningMessage => OtaTranslationService.translate(locale, 'errorPinningMessage', fallback.errorPinningMessage);

  @override
  String get leaveChat => OtaTranslationService.translate(locale, 'leaveChat', fallback.leaveChat);

  @override
  String get messagePinned => OtaTranslationService.translate(locale, 'messagePinned', fallback.messagePinned);

  @override
  String get mic => OtaTranslationService.translate(locale, 'mic', fallback.mic);

  @override
  String get muted => OtaTranslationService.translate(locale, 'muted', fallback.muted);

  @override
  String get noMessages => OtaTranslationService.translate(locale, 'noMessages', fallback.noMessages);

  @override
  String get onlyTheHostCanPinMessages => OtaTranslationService.translate(locale, 'onlyTheHostCanPinMessages', fallback.onlyTheHostCanPinMessages);

  @override
  String get pendingInvites => OtaTranslationService.translate(locale, 'pendingInvites', fallback.pendingInvites);

  @override
  String get sendCoinsToThisChat => OtaTranslationService.translate(locale, 'sendCoinsToThisChat', fallback.sendCoinsToThisChat);

  @override
  String get speaker => OtaTranslationService.translate(locale, 'speaker', fallback.speaker);

  @override
  String get stickersLabel => OtaTranslationService.translate(locale, 'stickersLabel', fallback.stickersLabel);

  @override
  String get switchCamera => OtaTranslationService.translate(locale, 'switchCamera', fallback.switchCamera);

  @override
  String get thisUserDoesNotAcceptDirectMessages => OtaTranslationService.translate(locale, 'thisUserDoesNotAcceptDirectMessages', fallback.thisUserDoesNotAcceptDirectMessages);

  @override
  String get thisUserOnlyAcceptsMessagesFromAllowedProfiles => OtaTranslationService.translate(locale, 'thisUserOnlyAcceptsMessagesFromAllowedProfiles', fallback.thisUserOnlyAcceptsMessagesFromAllowedProfiles);

  @override
  String get youCannotOpenAChatWithYourself => OtaTranslationService.translate(locale, 'youCannotOpenAChatWithYourself', fallback.youCannotOpenAChatWithYourself);

  @override
  String get errorLoadingProfile => OtaTranslationService.translate(locale, 'errorLoadingProfile', fallback.errorLoadingProfile);

  @override
  String get followingNow => OtaTranslationService.translate(locale, 'followingNow', fallback.followingNow);

  @override
  String get profileLinkCopied => OtaTranslationService.translate(locale, 'profileLinkCopied', fallback.profileLinkCopied);

  @override
  String get removeBanner => OtaTranslationService.translate(locale, 'removeBanner', fallback.removeBanner);

  @override
  String get shareProfile => OtaTranslationService.translate(locale, 'shareProfile', fallback.shareProfile);

  @override
  String get unfollowed => OtaTranslationService.translate(locale, 'unfollowed', fallback.unfollowed);

  @override
  String get writeOnTheWall => OtaTranslationService.translate(locale, 'writeOnTheWall', fallback.writeOnTheWall);

  @override
  String get entryType => OtaTranslationService.translate(locale, 'entryType', fallback.entryType);

  @override
  String get myWikiEntries => OtaTranslationService.translate(locale, 'myWikiEntries', fallback.myWikiEntries);

  @override
  String get noPendingReports => OtaTranslationService.translate(locale, 'noPendingReports', fallback.noPendingReports);

  @override
  String get reports => OtaTranslationService.translate(locale, 'reports', fallback.reports);

  @override
  String get spam => OtaTranslationService.translate(locale, 'spam', fallback.spam);

  @override
  String get appearance => OtaTranslationService.translate(locale, 'appearance', fallback.appearance);

  @override
  String get noBlockedUsers => OtaTranslationService.translate(locale, 'noBlockedUsers', fallback.noBlockedUsers);

  @override
  String get primaryLanguage => OtaTranslationService.translate(locale, 'primaryLanguage', fallback.primaryLanguage);

  @override
  String get privacyPolicyTitle => OtaTranslationService.translate(locale, 'privacyPolicyTitle', fallback.privacyPolicyTitle);

  @override
  String get security => OtaTranslationService.translate(locale, 'security', fallback.security);

  @override
  String get themeColor => OtaTranslationService.translate(locale, 'themeColor', fallback.themeColor);

  @override
  String get insufficientBalance => OtaTranslationService.translate(locale, 'insufficientBalance', fallback.insufficientBalance);

  @override
  String get inventory => OtaTranslationService.translate(locale, 'inventory', fallback.inventory);

  @override
  String get ranking => OtaTranslationService.translate(locale, 'ranking', fallback.ranking);

  @override
  String get wallet => OtaTranslationService.translate(locale, 'wallet', fallback.wallet);

  @override
  String get backgrounds => OtaTranslationService.translate(locale, 'backgrounds', fallback.backgrounds);

  @override
  String get buy => OtaTranslationService.translate(locale, 'buy', fallback.buy);

  @override
  String get errorRestoringPurchases => OtaTranslationService.translate(locale, 'errorRestoringPurchases', fallback.errorRestoringPurchases);

  @override
  String get store => OtaTranslationService.translate(locale, 'store', fallback.store);

  @override
  String get untitled => OtaTranslationService.translate(locale, 'untitled', fallback.untitled);

  @override
  String get storyPublished => OtaTranslationService.translate(locale, 'storyPublished', fallback.storyPublished);

  @override
  String get april => OtaTranslationService.translate(locale, 'april', fallback.april);

  @override
  String get august => OtaTranslationService.translate(locale, 'august', fallback.august);

  @override
  String get december => OtaTranslationService.translate(locale, 'december', fallback.december);

  @override
  String get february => OtaTranslationService.translate(locale, 'february', fallback.february);

  @override
  String get january => OtaTranslationService.translate(locale, 'january', fallback.january);

  @override
  String get july => OtaTranslationService.translate(locale, 'july', fallback.july);

  @override
  String get june => OtaTranslationService.translate(locale, 'june', fallback.june);

  @override
  String get march => OtaTranslationService.translate(locale, 'march', fallback.march);

  @override
  String get may => OtaTranslationService.translate(locale, 'may', fallback.may);

  @override
  String get november => OtaTranslationService.translate(locale, 'november', fallback.november);

  @override
  String get now => OtaTranslationService.translate(locale, 'now', fallback.now);

  @override
  String get october => OtaTranslationService.translate(locale, 'october', fallback.october);

  @override
  String get september => OtaTranslationService.translate(locale, 'september', fallback.september);

  @override
  String get todayLabel => OtaTranslationService.translate(locale, 'todayLabel', fallback.todayLabel);

  @override
  String get anErrorOccurredTryAgain => OtaTranslationService.translate(locale, 'anErrorOccurredTryAgain', fallback.anErrorOccurredTryAgain);

  @override
  String get errorLoadingNotifications => OtaTranslationService.translate(locale, 'errorLoadingNotifications', fallback.errorLoadingNotifications);

  @override
  String get unknownError => OtaTranslationService.translate(locale, 'unknownError', fallback.unknownError);

  @override
  String get accept => OtaTranslationService.translate(locale, 'accept', fallback.accept);

  @override
  String get active => OtaTranslationService.translate(locale, 'active', fallback.active);

  @override
  String get anonymous => OtaTranslationService.translate(locale, 'anonymous', fallback.anonymous);

  @override
  String get apple => OtaTranslationService.translate(locale, 'apple', fallback.apple);

  @override
  String get apply => OtaTranslationService.translate(locale, 'apply', fallback.apply);

  @override
  String get bold => OtaTranslationService.translate(locale, 'bold', fallback.bold);

  @override
  String get chooseANickname => OtaTranslationService.translate(locale, 'chooseANickname', fallback.chooseANickname);

  @override
  String get connected => OtaTranslationService.translate(locale, 'connected', fallback.connected);

  @override
  String get connections => OtaTranslationService.translate(locale, 'connections', fallback.connections);

  @override
  String get continueAction => OtaTranslationService.translate(locale, 'continueAction', fallback.continueAction);

  @override
  String get copy => OtaTranslationService.translate(locale, 'copy', fallback.copy);

  @override
  String get couldNotStartAConversationWithThisUser => OtaTranslationService.translate(locale, 'couldNotStartAConversationWithThisUser', fallback.couldNotStartAConversationWithThisUser);

  @override
  String get create => OtaTranslationService.translate(locale, 'create', fallback.create);

  @override
  String get decline => OtaTranslationService.translate(locale, 'decline', fallback.decline);

  @override
  String get deleteAction => OtaTranslationService.translate(locale, 'deleteAction', fallback.deleteAction);

  @override
  String get deleteConversation => OtaTranslationService.translate(locale, 'deleteConversation', fallback.deleteConversation);

  @override
  String get deleteFile => OtaTranslationService.translate(locale, 'deleteFile', fallback.deleteFile);

  @override
  String get editor => OtaTranslationService.translate(locale, 'editor', fallback.editor);

  @override
  String get everyone => OtaTranslationService.translate(locale, 'everyone', fallback.everyone);

  @override
  String get files => OtaTranslationService.translate(locale, 'files', fallback.files);

  @override
  String get general => OtaTranslationService.translate(locale, 'general', fallback.general);

  @override
  String get global => OtaTranslationService.translate(locale, 'global', fallback.global);

  @override
  String get google => OtaTranslationService.translate(locale, 'google', fallback.google);

  @override
  String get history => OtaTranslationService.translate(locale, 'history', fallback.history);

  @override
  String get image => OtaTranslationService.translate(locale, 'image', fallback.image);

  @override
  String get images => OtaTranslationService.translate(locale, 'images', fallback.images);

  @override
  String get italic => OtaTranslationService.translate(locale, 'italic', fallback.italic);

  @override
  String get less => OtaTranslationService.translate(locale, 'less', fallback.less);

  @override
  String get link => OtaTranslationService.translate(locale, 'link', fallback.link);

  @override
  String get minimum6Characters => OtaTranslationService.translate(locale, 'minimum6Characters', fallback.minimum6Characters);

  @override
  String get more => OtaTranslationService.translate(locale, 'more', fallback.more);

  @override
  String get music => OtaTranslationService.translate(locale, 'music', fallback.music);

  @override
  String get nicknameHint => OtaTranslationService.translate(locale, 'nicknameHint', fallback.nicknameHint);

  @override
  String get noFiles => OtaTranslationService.translate(locale, 'noFiles', fallback.noFiles);

  @override
  String get noItems => OtaTranslationService.translate(locale, 'noItems', fallback.noItems);

  @override
  String get nobody => OtaTranslationService.translate(locale, 'nobody', fallback.nobody);

  @override
  String get offline => OtaTranslationService.translate(locale, 'offline', fallback.offline);

  @override
  String get open => OtaTranslationService.translate(locale, 'open', fallback.open);

  @override
  String get openAction => OtaTranslationService.translate(locale, 'openAction', fallback.openAction);

  @override
  String get other => OtaTranslationService.translate(locale, 'other', fallback.other);

  @override
  String get pinToTop => OtaTranslationService.translate(locale, 'pinToTop', fallback.pinToTop);

  @override
  String get preview => OtaTranslationService.translate(locale, 'preview', fallback.preview);

  @override
  String get recent => OtaTranslationService.translate(locale, 'recent', fallback.recent);

  @override
  String get recommended => OtaTranslationService.translate(locale, 'recommended', fallback.recommended);

  @override
  String get refresh => OtaTranslationService.translate(locale, 'refresh', fallback.refresh);

  @override
  String get remove => OtaTranslationService.translate(locale, 'remove', fallback.remove);

  @override
  String get selectAnAmount => OtaTranslationService.translate(locale, 'selectAnAmount', fallback.selectAnAmount);

  @override
  String get send => OtaTranslationService.translate(locale, 'send', fallback.send);

  @override
  String get sharedFolder => OtaTranslationService.translate(locale, 'sharedFolder', fallback.sharedFolder);

  @override
  String get sharedScreenWillAppearHere => OtaTranslationService.translate(locale, 'sharedScreenWillAppearHere', fallback.sharedScreenWillAppearHere);

  @override
  String get strikethrough => OtaTranslationService.translate(locale, 'strikethrough', fallback.strikethrough);

  @override
  String get termsOfUse => OtaTranslationService.translate(locale, 'termsOfUse', fallback.termsOfUse);

  @override
  String get text => OtaTranslationService.translate(locale, 'text', fallback.text);

  @override
  String get unblock => OtaTranslationService.translate(locale, 'unblock', fallback.unblock);

  @override
  String get unpinFromTop => OtaTranslationService.translate(locale, 'unpinFromTop', fallback.unpinFromTop);

  @override
  String get user => OtaTranslationService.translate(locale, 'user', fallback.user);

  @override
  String get videos => OtaTranslationService.translate(locale, 'videos', fallback.videos);

  @override
  String get visibility => OtaTranslationService.translate(locale, 'visibility', fallback.visibility);

  @override
  String get visual => OtaTranslationService.translate(locale, 'visual', fallback.visual);

  @override
  String get yesDelete => OtaTranslationService.translate(locale, 'yesDelete', fallback.yesDelete);

  @override
  String get you => OtaTranslationService.translate(locale, 'you', fallback.you);

  @override
  String get acceptTermsToContinue => OtaTranslationService.translate(locale, 'acceptTermsToContinue', fallback.acceptTermsToContinue);

  @override
  String get accessLabel => OtaTranslationService.translate(locale, 'accessLabel', fallback.accessLabel);

  @override
  String get accountLabel => OtaTranslationService.translate(locale, 'accountLabel', fallback.accountLabel);

  @override
  String get achievementUnlocked => OtaTranslationService.translate(locale, 'achievementUnlocked', fallback.achievementUnlocked);

  @override
  String get actionExecuted => OtaTranslationService.translate(locale, 'actionExecuted', fallback.actionExecuted);

  @override
  String get activeChats => OtaTranslationService.translate(locale, 'activeChats', fallback.activeChats);

  @override
  String get addBlock => OtaTranslationService.translate(locale, 'addBlock', fallback.addBlock);

  @override
  String get addLink => OtaTranslationService.translate(locale, 'addLink', fallback.addLink);

  @override
  String get addMusic => OtaTranslationService.translate(locale, 'addMusic', fallback.addMusic);

  @override
  String get addOptionAction => OtaTranslationService.translate(locale, 'addOptionAction', fallback.addOptionAction);

  @override
  String get addQuestionAction => OtaTranslationService.translate(locale, 'addQuestionAction', fallback.addQuestionAction);

  @override
  String get addSticker => OtaTranslationService.translate(locale, 'addSticker', fallback.addSticker);

  @override
  String get addText => OtaTranslationService.translate(locale, 'addText', fallback.addText);

  @override
  String get administration => OtaTranslationService.translate(locale, 'administration', fallback.administration);

  @override
  String get allFiles => OtaTranslationService.translate(locale, 'allFiles', fallback.allFiles);

  @override
  String get allowGroupInvites => OtaTranslationService.translate(locale, 'allowGroupInvites', fallback.allowGroupInvites);

  @override
  String get alreadyCheckedIn => OtaTranslationService.translate(locale, 'alreadyCheckedIn', fallback.alreadyCheckedIn);

  @override
  String get alreadyHaveAccountShort => OtaTranslationService.translate(locale, 'alreadyHaveAccountShort', fallback.alreadyHaveAccountShort);

  @override
  String get anonymousLabel => OtaTranslationService.translate(locale, 'anonymousLabel', fallback.anonymousLabel);

  @override
  String get appPermissions => OtaTranslationService.translate(locale, 'appPermissions', fallback.appPermissions);

  @override
  String get appearanceLabel => OtaTranslationService.translate(locale, 'appearanceLabel', fallback.appearanceLabel);

  @override
  String get approval => OtaTranslationService.translate(locale, 'approval', fallback.approval);

  @override
  String get audio => OtaTranslationService.translate(locale, 'audio', fallback.audio);

  @override
  String get backgroundsLabel => OtaTranslationService.translate(locale, 'backgroundsLabel', fallback.backgroundsLabel);

  @override
  String get balance => OtaTranslationService.translate(locale, 'balance', fallback.balance);

  @override
  String get boldFormat => OtaTranslationService.translate(locale, 'boldFormat', fallback.boldFormat);

  @override
  String get buyAction => OtaTranslationService.translate(locale, 'buyAction', fallback.buyAction);

  @override
  String get buyCoins => OtaTranslationService.translate(locale, 'buyCoins', fallback.buyCoins);

  @override
  String get cameraAction => OtaTranslationService.translate(locale, 'cameraAction', fallback.cameraAction);

  @override
  String get changeAvatar => OtaTranslationService.translate(locale, 'changeAvatar', fallback.changeAvatar);

  @override
  String get changeBanner => OtaTranslationService.translate(locale, 'changeBanner', fallback.changeBanner);

  @override
  String get changesSaved => OtaTranslationService.translate(locale, 'changesSaved', fallback.changesSaved);

  @override
  String get chatBubbles => OtaTranslationService.translate(locale, 'chatBubbles', fallback.chatBubbles);

  @override
  String get chatDescription => OtaTranslationService.translate(locale, 'chatDescription', fallback.chatDescription);

  @override
  String get chatName => OtaTranslationService.translate(locale, 'chatName', fallback.chatName);

  @override
  String get checkInDone => OtaTranslationService.translate(locale, 'checkInDone', fallback.checkInDone);

  @override
  String get checkInHeatmap => OtaTranslationService.translate(locale, 'checkInHeatmap', fallback.checkInHeatmap);

  @override
  String get chooseFromGallery => OtaTranslationService.translate(locale, 'chooseFromGallery', fallback.chooseFromGallery);

  @override
  String get closed => OtaTranslationService.translate(locale, 'closed', fallback.closed);

  @override
  String get code => OtaTranslationService.translate(locale, 'code', fallback.code);

  @override
  String get coinShop => OtaTranslationService.translate(locale, 'coinShop', fallback.coinShop);

  @override
  String get coinsSent => OtaTranslationService.translate(locale, 'coinsSent', fallback.coinsSent);

  @override
  String get comingSoon => OtaTranslationService.translate(locale, 'comingSoon', fallback.comingSoon);

  @override
  String get communityChats => OtaTranslationService.translate(locale, 'communityChats', fallback.communityChats);

  @override
  String get communityGuidelines => OtaTranslationService.translate(locale, 'communityGuidelines', fallback.communityGuidelines);

  @override
  String get confirmDeleteMessage => OtaTranslationService.translate(locale, 'confirmDeleteMessage', fallback.confirmDeleteMessage);

  @override
  String get confirmPassword => OtaTranslationService.translate(locale, 'confirmPassword', fallback.confirmPassword);

  @override
  String get confirmRemoveLink => OtaTranslationService.translate(locale, 'confirmRemoveLink', fallback.confirmRemoveLink);

  @override
  String get connectionError => OtaTranslationService.translate(locale, 'connectionError', fallback.connectionError);

  @override
  String get connectionsLabel => OtaTranslationService.translate(locale, 'connectionsLabel', fallback.connectionsLabel);

  @override
  String get contact => OtaTranslationService.translate(locale, 'contact', fallback.contact);

  @override
  String get copyMessage => OtaTranslationService.translate(locale, 'copyMessage', fallback.copyMessage);

  @override
  String get correct => OtaTranslationService.translate(locale, 'correct', fallback.correct);

  @override
  String get correctAnswer => OtaTranslationService.translate(locale, 'correctAnswer', fallback.correctAnswer);

  @override
  String get createGroup => OtaTranslationService.translate(locale, 'createGroup', fallback.createGroup);

  @override
  String get createGroupAction => OtaTranslationService.translate(locale, 'createGroupAction', fallback.createGroupAction);

  @override
  String get createPublicChat => OtaTranslationService.translate(locale, 'createPublicChat', fallback.createPublicChat);

  @override
  String get createPublicChatAction => OtaTranslationService.translate(locale, 'createPublicChatAction', fallback.createPublicChatAction);

  @override
  String get createStory => OtaTranslationService.translate(locale, 'createStory', fallback.createStory);

  @override
  String get curators => OtaTranslationService.translate(locale, 'curators', fallback.curators);

  @override
  String get currentDevice => OtaTranslationService.translate(locale, 'currentDevice', fallback.currentDevice);

  @override
  String get customizeProfile => OtaTranslationService.translate(locale, 'customizeProfile', fallback.customizeProfile);

  @override
  String get dailyReward => OtaTranslationService.translate(locale, 'dailyReward', fallback.dailyReward);

  @override
  String get dataExported => OtaTranslationService.translate(locale, 'dataExported', fallback.dataExported);

  @override
  String get date => OtaTranslationService.translate(locale, 'date', fallback.date);

  @override
  String get day => OtaTranslationService.translate(locale, 'day', fallback.day);

  @override
  String get dayStreak => OtaTranslationService.translate(locale, 'dayStreak', fallback.dayStreak);

  @override
  String get days => OtaTranslationService.translate(locale, 'days', fallback.days);

  @override
  String get deleteMessage => OtaTranslationService.translate(locale, 'deleteMessage', fallback.deleteMessage);

  @override
  String get deleting => OtaTranslationService.translate(locale, 'deleting', fallback.deleting);

  @override
  String get describeReason => OtaTranslationService.translate(locale, 'describeReason', fallback.describeReason);

  @override
  String get deviceRemoved => OtaTranslationService.translate(locale, 'deviceRemoved', fallback.deviceRemoved);

  @override
  String get devices => OtaTranslationService.translate(locale, 'devices', fallback.devices);

  @override
  String get dividerBlock => OtaTranslationService.translate(locale, 'dividerBlock', fallback.dividerBlock);

  @override
  String get doCheckIn => OtaTranslationService.translate(locale, 'doCheckIn', fallback.doCheckIn);

  @override
  String get document => OtaTranslationService.translate(locale, 'document', fallback.document);

  @override
  String get documents => OtaTranslationService.translate(locale, 'documents', fallback.documents);

  @override
  String get draftDeleted => OtaTranslationService.translate(locale, 'draftDeleted', fallback.draftDeleted);

  @override
  String get draftSaved => OtaTranslationService.translate(locale, 'draftSaved', fallback.draftSaved);

  @override
  String get draftsWillAppearHere => OtaTranslationService.translate(locale, 'draftsWillAppearHere', fallback.draftsWillAppearHere);

  @override
  String get editCommunityGuidelines => OtaTranslationService.translate(locale, 'editCommunityGuidelines', fallback.editCommunityGuidelines);

  @override
  String get editCommunityProfile => OtaTranslationService.translate(locale, 'editCommunityProfile', fallback.editCommunityProfile);

  @override
  String get editLink => OtaTranslationService.translate(locale, 'editLink', fallback.editLink);

  @override
  String get editorLabel => OtaTranslationService.translate(locale, 'editorLabel', fallback.editorLabel);

  @override
  String get endLive => OtaTranslationService.translate(locale, 'endLive', fallback.endLive);

  @override
  String get enterGroupName => OtaTranslationService.translate(locale, 'enterGroupName', fallback.enterGroupName);

  @override
  String get enterYourEmailFirst => OtaTranslationService.translate(locale, 'enterYourEmailFirst', fallback.enterYourEmailFirst);

  @override
  String get enterYourPassword => OtaTranslationService.translate(locale, 'enterYourPassword', fallback.enterYourPassword);

  @override
  String get entryApproved => OtaTranslationService.translate(locale, 'entryApproved', fallback.entryApproved);

  @override
  String get entryRejected => OtaTranslationService.translate(locale, 'entryRejected', fallback.entryRejected);

  @override
  String get entryTypeLabel => OtaTranslationService.translate(locale, 'entryTypeLabel', fallback.entryTypeLabel);

  @override
  String get equip => OtaTranslationService.translate(locale, 'equip', fallback.equip);

  @override
  String get equipped => OtaTranslationService.translate(locale, 'equipped', fallback.equipped);

  @override
  String get errorAppleLogin => OtaTranslationService.translate(locale, 'errorAppleLogin', fallback.errorAppleLogin);

  @override
  String get errorCreatingAccount => OtaTranslationService.translate(locale, 'errorCreatingAccount', fallback.errorCreatingAccount);

  @override
  String get errorCreatingChat => OtaTranslationService.translate(locale, 'errorCreatingChat', fallback.errorCreatingChat);

  @override
  String get errorCreatingGroup => OtaTranslationService.translate(locale, 'errorCreatingGroup', fallback.errorCreatingGroup);

  @override
  String get errorDeletingChat => OtaTranslationService.translate(locale, 'errorDeletingChat', fallback.errorDeletingChat);

  @override
  String get errorDeletingTryAgain => OtaTranslationService.translate(locale, 'errorDeletingTryAgain', fallback.errorDeletingTryAgain);

  @override
  String get errorEditingTryAgain => OtaTranslationService.translate(locale, 'errorEditingTryAgain', fallback.errorEditingTryAgain);

  @override
  String get errorExecutingAction => OtaTranslationService.translate(locale, 'errorExecutingAction', fallback.errorExecutingAction);

  @override
  String get errorExportingData => OtaTranslationService.translate(locale, 'errorExportingData', fallback.errorExportingData);

  @override
  String get errorGoogleLogin => OtaTranslationService.translate(locale, 'errorGoogleLogin', fallback.errorGoogleLogin);

  @override
  String get errorJoiningChat => OtaTranslationService.translate(locale, 'errorJoiningChat', fallback.errorJoiningChat);

  @override
  String get errorLeavingChat => OtaTranslationService.translate(locale, 'errorLeavingChat', fallback.errorLeavingChat);

  @override
  String get errorLoadingImage => OtaTranslationService.translate(locale, 'errorLoadingImage', fallback.errorLoadingImage);

  @override
  String get errorLoadingProfileMsg => OtaTranslationService.translate(locale, 'errorLoadingProfileMsg', fallback.errorLoadingProfileMsg);

  @override
  String get errorLoadingProfileRetry => OtaTranslationService.translate(locale, 'errorLoadingProfileRetry', fallback.errorLoadingProfileRetry);

  @override
  String get errorLoggingOut => OtaTranslationService.translate(locale, 'errorLoggingOut', fallback.errorLoggingOut);

  @override
  String get errorLoginCredentials => OtaTranslationService.translate(locale, 'errorLoginCredentials', fallback.errorLoginCredentials);

  @override
  String get errorPublishing => OtaTranslationService.translate(locale, 'errorPublishing', fallback.errorPublishing);

  @override
  String get errorSaving => OtaTranslationService.translate(locale, 'errorSaving', fallback.errorSaving);

  @override
  String get errorSavingTryAgain => OtaTranslationService.translate(locale, 'errorSavingTryAgain', fallback.errorSavingTryAgain);

  @override
  String get errorSendingAudio => OtaTranslationService.translate(locale, 'errorSendingAudio', fallback.errorSendingAudio);

  @override
  String get errorSendingCoins => OtaTranslationService.translate(locale, 'errorSendingCoins', fallback.errorSendingCoins);

  @override
  String get errorSendingLink => OtaTranslationService.translate(locale, 'errorSendingLink', fallback.errorSendingLink);

  @override
  String get errorSendingTryAgain => OtaTranslationService.translate(locale, 'errorSendingTryAgain', fallback.errorSendingTryAgain);

  @override
  String get errorUpdatingGuidelines => OtaTranslationService.translate(locale, 'errorUpdatingGuidelines', fallback.errorUpdatingGuidelines);

  @override
  String get errorUpdatingImage => OtaTranslationService.translate(locale, 'errorUpdatingImage', fallback.errorUpdatingImage);

  @override
  String get errorUpdatingProfile => OtaTranslationService.translate(locale, 'errorUpdatingProfile', fallback.errorUpdatingProfile);

  @override
  String get errorUploadTryAgain => OtaTranslationService.translate(locale, 'errorUploadTryAgain', fallback.errorUploadTryAgain);

  @override
  String get errorUploadingFile => OtaTranslationService.translate(locale, 'errorUploadingFile', fallback.errorUploadingFile);

  @override
  String get errorVideoUpload => OtaTranslationService.translate(locale, 'errorVideoUpload', fallback.errorVideoUpload);

  @override
  String get explanation => OtaTranslationService.translate(locale, 'explanation', fallback.explanation);

  @override
  String get exportData => OtaTranslationService.translate(locale, 'exportData', fallback.exportData);

  @override
  String get favorites => OtaTranslationService.translate(locale, 'favorites', fallback.favorites);

  @override
  String get featureUnderDev => OtaTranslationService.translate(locale, 'featureUnderDev', fallback.featureUnderDev);

  @override
  String get file => OtaTranslationService.translate(locale, 'file', fallback.file);

  @override
  String get fileDeleted => OtaTranslationService.translate(locale, 'fileDeleted', fallback.fileDeleted);

  @override
  String get fileUploaded => OtaTranslationService.translate(locale, 'fileUploaded', fallback.fileUploaded);

  @override
  String get filter => OtaTranslationService.translate(locale, 'filter', fallback.filter);

  @override
  String get frames => OtaTranslationService.translate(locale, 'frames', fallback.frames);

  @override
  String get freeCoins => OtaTranslationService.translate(locale, 'freeCoins', fallback.freeCoins);

  @override
  String get gallery => OtaTranslationService.translate(locale, 'gallery', fallback.gallery);

  @override
  String get generalLabel => OtaTranslationService.translate(locale, 'generalLabel', fallback.generalLabel);

  @override
  String get grid => OtaTranslationService.translate(locale, 'grid', fallback.grid);

  @override
  String get groupDescription => OtaTranslationService.translate(locale, 'groupDescription', fallback.groupDescription);

  @override
  String get guidelinesUpdated => OtaTranslationService.translate(locale, 'guidelinesUpdated', fallback.guidelinesUpdated);

  @override
  String get harassment => OtaTranslationService.translate(locale, 'harassment', fallback.harassment);

  @override
  String get hateSpeech => OtaTranslationService.translate(locale, 'hateSpeech', fallback.hateSpeech);

  @override
  String get header => OtaTranslationService.translate(locale, 'header', fallback.header);

  @override
  String get historyLabel => OtaTranslationService.translate(locale, 'historyLabel', fallback.historyLabel);

  @override
  String get ignore => OtaTranslationService.translate(locale, 'ignore', fallback.ignore);

  @override
  String get imageUpdated => OtaTranslationService.translate(locale, 'imageUpdated', fallback.imageUpdated);

  @override
  String get imagesLabel => OtaTranslationService.translate(locale, 'imagesLabel', fallback.imagesLabel);

  @override
  String get inappropriateContent => OtaTranslationService.translate(locale, 'inappropriateContent', fallback.inappropriateContent);

  @override
  String get incorrect => OtaTranslationService.translate(locale, 'incorrect', fallback.incorrect);

  @override
  String get info => OtaTranslationService.translate(locale, 'info', fallback.info);

  @override
  String get information => OtaTranslationService.translate(locale, 'information', fallback.information);

  @override
  String get insertImage => OtaTranslationService.translate(locale, 'insertImage', fallback.insertImage);

  @override
  String get insertLink => OtaTranslationService.translate(locale, 'insertLink', fallback.insertLink);

  @override
  String get insufficientBalanceMsg => OtaTranslationService.translate(locale, 'insufficientBalanceMsg', fallback.insufficientBalanceMsg);

  @override
  String get interestAnime => OtaTranslationService.translate(locale, 'interestAnime', fallback.interestAnime);

  @override
  String get interestComics => OtaTranslationService.translate(locale, 'interestComics', fallback.interestComics);

  @override
  String get interestCooking => OtaTranslationService.translate(locale, 'interestCooking', fallback.interestCooking);

  @override
  String get interestCosplay => OtaTranslationService.translate(locale, 'interestCosplay', fallback.interestCosplay);

  @override
  String get interestDance => OtaTranslationService.translate(locale, 'interestDance', fallback.interestDance);

  @override
  String get interestFashion => OtaTranslationService.translate(locale, 'interestFashion', fallback.interestFashion);

  @override
  String get interestHorror => OtaTranslationService.translate(locale, 'interestHorror', fallback.interestHorror);

  @override
  String get interestKpop => OtaTranslationService.translate(locale, 'interestKpop', fallback.interestKpop);

  @override
  String get interestLanguages => OtaTranslationService.translate(locale, 'interestLanguages', fallback.interestLanguages);

  @override
  String get interestManga => OtaTranslationService.translate(locale, 'interestManga', fallback.interestManga);

  @override
  String get interestNature => OtaTranslationService.translate(locale, 'interestNature', fallback.interestNature);

  @override
  String get interestPhotography => OtaTranslationService.translate(locale, 'interestPhotography', fallback.interestPhotography);

  @override
  String get interestScience => OtaTranslationService.translate(locale, 'interestScience', fallback.interestScience);

  @override
  String get interestSpirituality => OtaTranslationService.translate(locale, 'interestSpirituality', fallback.interestSpirituality);

  @override
  String get interestSports => OtaTranslationService.translate(locale, 'interestSports', fallback.interestSports);

  @override
  String get interestTechnology => OtaTranslationService.translate(locale, 'interestTechnology', fallback.interestTechnology);

  @override
  String get interestTravel => OtaTranslationService.translate(locale, 'interestTravel', fallback.interestTravel);

  @override
  String get invalidEmail => OtaTranslationService.translate(locale, 'invalidEmail', fallback.invalidEmail);

  @override
  String get invalidLink => OtaTranslationService.translate(locale, 'invalidLink', fallback.invalidLink);

  @override
  String get invite => OtaTranslationService.translate(locale, 'invite', fallback.invite);

  @override
  String get inviteFriends => OtaTranslationService.translate(locale, 'inviteFriends', fallback.inviteFriends);

  @override
  String get italicFormat => OtaTranslationService.translate(locale, 'italicFormat', fallback.italicFormat);

  @override
  String get items => OtaTranslationService.translate(locale, 'items', fallback.items);

  @override
  String get joinCommunityFirst => OtaTranslationService.translate(locale, 'joinCommunityFirst', fallback.joinCommunityFirst);

  @override
  String get joinLive => OtaTranslationService.translate(locale, 'joinLive', fallback.joinLive);

  @override
  String get lastAccess => OtaTranslationService.translate(locale, 'lastAccess', fallback.lastAccess);

  @override
  String get layout => OtaTranslationService.translate(locale, 'layout', fallback.layout);

  @override
  String get leaderboard => OtaTranslationService.translate(locale, 'leaderboard', fallback.leaderboard);

  @override
  String get leaders => OtaTranslationService.translate(locale, 'leaders', fallback.leaders);

  @override
  String get linkAdded => OtaTranslationService.translate(locale, 'linkAdded', fallback.linkAdded);

  @override
  String get linkPreview => OtaTranslationService.translate(locale, 'linkPreview', fallback.linkPreview);

  @override
  String get linkRemoved => OtaTranslationService.translate(locale, 'linkRemoved', fallback.linkRemoved);

  @override
  String get linkTitle => OtaTranslationService.translate(locale, 'linkTitle', fallback.linkTitle);

  @override
  String get linkUpdated => OtaTranslationService.translate(locale, 'linkUpdated', fallback.linkUpdated);

  @override
  String get linkUrl => OtaTranslationService.translate(locale, 'linkUrl', fallback.linkUrl);

  @override
  String get linkedAccounts => OtaTranslationService.translate(locale, 'linkedAccounts', fallback.linkedAccounts);

  @override
  String get listedVisibility => OtaTranslationService.translate(locale, 'listedVisibility', fallback.listedVisibility);

  @override
  String get live => OtaTranslationService.translate(locale, 'live', fallback.live);

  @override
  String get liveChats => OtaTranslationService.translate(locale, 'liveChats', fallback.liveChats);

  @override
  String get liveProjections => OtaTranslationService.translate(locale, 'liveProjections', fallback.liveProjections);

  @override
  String get localBio => OtaTranslationService.translate(locale, 'localBio', fallback.localBio);

  @override
  String get localNickname => OtaTranslationService.translate(locale, 'localNickname', fallback.localNickname);

  @override
  String get location => OtaTranslationService.translate(locale, 'location', fallback.location);

  @override
  String get logInToContinue => OtaTranslationService.translate(locale, 'logInToContinue', fallback.logInToContinue);

  @override
  String get manage => OtaTranslationService.translate(locale, 'manage', fallback.manage);

  @override
  String get markAllRead => OtaTranslationService.translate(locale, 'markAllRead', fallback.markAllRead);

  @override
  String get markdown => OtaTranslationService.translate(locale, 'markdown', fallback.markdown);

  @override
  String get media => OtaTranslationService.translate(locale, 'media', fallback.media);

  @override
  String get memberSince => OtaTranslationService.translate(locale, 'memberSince', fallback.memberSince);

  @override
  String get membersCount => OtaTranslationService.translate(locale, 'membersCount', fallback.membersCount);

  @override
  String get messageCopied => OtaTranslationService.translate(locale, 'messageCopied', fallback.messageCopied);

  @override
  String get messageDeleted => OtaTranslationService.translate(locale, 'messageDeleted', fallback.messageDeleted);

  @override
  String get messageDeletedConfirm => OtaTranslationService.translate(locale, 'messageDeletedConfirm', fallback.messageDeletedConfirm);

  @override
  String get messagePinnedMsg => OtaTranslationService.translate(locale, 'messagePinnedMsg', fallback.messagePinnedMsg);

  @override
  String get messageUnpinned => OtaTranslationService.translate(locale, 'messageUnpinned', fallback.messageUnpinned);

  @override
  String get minimum2Options => OtaTranslationService.translate(locale, 'minimum2Options', fallback.minimum2Options);

  @override
  String get minimum6Chars => OtaTranslationService.translate(locale, 'minimum6Chars', fallback.minimum6Chars);

  @override
  String get moderationActions => OtaTranslationService.translate(locale, 'moderationActions', fallback.moderationActions);

  @override
  String get moderators => OtaTranslationService.translate(locale, 'moderators', fallback.moderators);

  @override
  String get modulesLabel => OtaTranslationService.translate(locale, 'modulesLabel', fallback.modulesLabel);

  @override
  String get moveDown => OtaTranslationService.translate(locale, 'moveDown', fallback.moveDown);

  @override
  String get moveUp => OtaTranslationService.translate(locale, 'moveUp', fallback.moveUp);

  @override
  String get musicLabel => OtaTranslationService.translate(locale, 'musicLabel', fallback.musicLabel);

  @override
  String get myWikiEntriesTitle => OtaTranslationService.translate(locale, 'myWikiEntriesTitle', fallback.myWikiEntriesTitle);

  @override
  String get name => OtaTranslationService.translate(locale, 'name', fallback.name);

  @override
  String get nameLink => OtaTranslationService.translate(locale, 'nameLink', fallback.nameLink);

  @override
  String get newChatTitle => OtaTranslationService.translate(locale, 'newChatTitle', fallback.newChatTitle);

  @override
  String get newMembersThisWeek => OtaTranslationService.translate(locale, 'newMembersThisWeek', fallback.newMembersThisWeek);

  @override
  String get noAchievementsYet => OtaTranslationService.translate(locale, 'noAchievementsYet', fallback.noAchievementsYet);

  @override
  String get noBlockedUsersMsg => OtaTranslationService.translate(locale, 'noBlockedUsersMsg', fallback.noBlockedUsersMsg);

  @override
  String get noChatsInCommunity => OtaTranslationService.translate(locale, 'noChatsInCommunity', fallback.noChatsInCommunity);

  @override
  String get noCheckIns => OtaTranslationService.translate(locale, 'noCheckIns', fallback.noCheckIns);

  @override
  String get noDevicesFound => OtaTranslationService.translate(locale, 'noDevicesFound', fallback.noDevicesFound);

  @override
  String get noDrafts => OtaTranslationService.translate(locale, 'noDrafts', fallback.noDrafts);

  @override
  String get noEntriesToReview => OtaTranslationService.translate(locale, 'noEntriesToReview', fallback.noEntriesToReview);

  @override
  String get noFilesMsg => OtaTranslationService.translate(locale, 'noFilesMsg', fallback.noFilesMsg);

  @override
  String get noGuidelinesDefined => OtaTranslationService.translate(locale, 'noGuidelinesDefined', fallback.noGuidelinesDefined);

  @override
  String get noLiveChats => OtaTranslationService.translate(locale, 'noLiveChats', fallback.noLiveChats);

  @override
  String get noLiveStreams => OtaTranslationService.translate(locale, 'noLiveStreams', fallback.noLiveStreams);

  @override
  String get noMemberFound => OtaTranslationService.translate(locale, 'noMemberFound', fallback.noMemberFound);

  @override
  String get noMembersOnline => OtaTranslationService.translate(locale, 'noMembersOnline', fallback.noMembersOnline);

  @override
  String get noMembersSelected => OtaTranslationService.translate(locale, 'noMembersSelected', fallback.noMembersSelected);

  @override
  String get noMessagesYet => OtaTranslationService.translate(locale, 'noMessagesYet', fallback.noMessagesYet);

  @override
  String get noMusicFound => OtaTranslationService.translate(locale, 'noMusicFound', fallback.noMusicFound);

  @override
  String get noNotificationsMsg => OtaTranslationService.translate(locale, 'noNotificationsMsg', fallback.noNotificationsMsg);

  @override
  String get noPendingReportsMsg => OtaTranslationService.translate(locale, 'noPendingReportsMsg', fallback.noPendingReportsMsg);

  @override
  String get noPermissionAction => OtaTranslationService.translate(locale, 'noPermissionAction', fallback.noPermissionAction);

  @override
  String get noPostsInCommunity => OtaTranslationService.translate(locale, 'noPostsInCommunity', fallback.noPostsInCommunity);

  @override
  String get noProjections => OtaTranslationService.translate(locale, 'noProjections', fallback.noProjections);

  @override
  String get noRecentEmoji => OtaTranslationService.translate(locale, 'noRecentEmoji', fallback.noRecentEmoji);

  @override
  String get noStories => OtaTranslationService.translate(locale, 'noStories', fallback.noStories);

  @override
  String get noTransactions => OtaTranslationService.translate(locale, 'noTransactions', fallback.noTransactions);

  @override
  String get notFoundMsg => OtaTranslationService.translate(locale, 'notFoundMsg', fallback.notFoundMsg);

  @override
  String get notificationSettings => OtaTranslationService.translate(locale, 'notificationSettings', fallback.notificationSettings);

  @override
  String get openEntry => OtaTranslationService.translate(locale, 'openEntry', fallback.openEntry);

  @override
  String get others => OtaTranslationService.translate(locale, 'others', fallback.others);

  @override
  String get packages => OtaTranslationService.translate(locale, 'packages', fallback.packages);

  @override
  String get paragraph => OtaTranslationService.translate(locale, 'paragraph', fallback.paragraph);

  @override
  String get pasteLinkHere => OtaTranslationService.translate(locale, 'pasteLinkHere', fallback.pasteLinkHere);

  @override
  String get people => OtaTranslationService.translate(locale, 'people', fallback.people);

  @override
  String get permissionDeniedMsg => OtaTranslationService.translate(locale, 'permissionDeniedMsg', fallback.permissionDeniedMsg);

  @override
  String get pleaseWait => OtaTranslationService.translate(locale, 'pleaseWait', fallback.pleaseWait);

  @override
  String get points => OtaTranslationService.translate(locale, 'points', fallback.points);

  @override
  String get position => OtaTranslationService.translate(locale, 'position', fallback.position);

  @override
  String get postDeleted => OtaTranslationService.translate(locale, 'postDeleted', fallback.postDeleted);

  @override
  String get postPublished => OtaTranslationService.translate(locale, 'postPublished', fallback.postPublished);

  @override
  String get postsThisWeek => OtaTranslationService.translate(locale, 'postsThisWeek', fallback.postsThisWeek);

  @override
  String get previewLabel => OtaTranslationService.translate(locale, 'previewLabel', fallback.previewLabel);

  @override
  String get primaryLanguageLabel => OtaTranslationService.translate(locale, 'primaryLanguageLabel', fallback.primaryLanguageLabel);

  @override
  String get privacyPolicyTitle2 => OtaTranslationService.translate(locale, 'privacyPolicyTitle2', fallback.privacyPolicyTitle2);

  @override
  String get privacySettings => OtaTranslationService.translate(locale, 'privacySettings', fallback.privacySettings);

  @override
  String get privateVisibility => OtaTranslationService.translate(locale, 'privateVisibility', fallback.privateVisibility);

  @override
  String get processing => OtaTranslationService.translate(locale, 'processing', fallback.processing);

  @override
  String get profileLinkCopiedMsg => OtaTranslationService.translate(locale, 'profileLinkCopiedMsg', fallback.profileLinkCopiedMsg);

  @override
  String get profileUpdated => OtaTranslationService.translate(locale, 'profileUpdated', fallback.profileUpdated);

  @override
  String get progress => OtaTranslationService.translate(locale, 'progress', fallback.progress);

  @override
  String get publicVisibility => OtaTranslationService.translate(locale, 'publicVisibility', fallback.publicVisibility);

  @override
  String get publishStory => OtaTranslationService.translate(locale, 'publishStory', fallback.publishStory);

  @override
  String get publishing => OtaTranslationService.translate(locale, 'publishing', fallback.publishing);

  @override
  String get purchaseComplete => OtaTranslationService.translate(locale, 'purchaseComplete', fallback.purchaseComplete);

  @override
  String get purchaseError => OtaTranslationService.translate(locale, 'purchaseError', fallback.purchaseError);

  @override
  String get quote => OtaTranslationService.translate(locale, 'quote', fallback.quote);

  @override
  String get realTimeChat => OtaTranslationService.translate(locale, 'realTimeChat', fallback.realTimeChat);

  @override
  String get recentLabel => OtaTranslationService.translate(locale, 'recentLabel', fallback.recentLabel);

  @override
  String get recoverySent => OtaTranslationService.translate(locale, 'recoverySent', fallback.recoverySent);

  @override
  String get removeAvatar => OtaTranslationService.translate(locale, 'removeAvatar', fallback.removeAvatar);

  @override
  String get removeBlock => OtaTranslationService.translate(locale, 'removeBlock', fallback.removeBlock);

  @override
  String get removeDevice => OtaTranslationService.translate(locale, 'removeDevice', fallback.removeDevice);

  @override
  String get reportContent => OtaTranslationService.translate(locale, 'reportContent', fallback.reportContent);

  @override
  String get reportReason => OtaTranslationService.translate(locale, 'reportReason', fallback.reportReason);

  @override
  String get reportSubmitted => OtaTranslationService.translate(locale, 'reportSubmitted', fallback.reportSubmitted);

  @override
  String get resolve => OtaTranslationService.translate(locale, 'resolve', fallback.resolve);

  @override
  String get resolved => OtaTranslationService.translate(locale, 'resolved', fallback.resolved);

  @override
  String get reward => OtaTranslationService.translate(locale, 'reward', fallback.reward);

  @override
  String get saveChanges => OtaTranslationService.translate(locale, 'saveChanges', fallback.saveChanges);

  @override
  String get savedPostsPrivate => OtaTranslationService.translate(locale, 'savedPostsPrivate', fallback.savedPostsPrivate);

  @override
  String get saving => OtaTranslationService.translate(locale, 'saving', fallback.saving);

  @override
  String get screeningRoom => OtaTranslationService.translate(locale, 'screeningRoom', fallback.screeningRoom);

  @override
  String get searchMembers => OtaTranslationService.translate(locale, 'searchMembers', fallback.searchMembers);

  @override
  String get searchMusic => OtaTranslationService.translate(locale, 'searchMusic', fallback.searchMusic);

  @override
  String get searchPlaceholder => OtaTranslationService.translate(locale, 'searchPlaceholder', fallback.searchPlaceholder);

  @override
  String get securityLabel => OtaTranslationService.translate(locale, 'securityLabel', fallback.securityLabel);

  @override
  String get selectAtLeast1Member => OtaTranslationService.translate(locale, 'selectAtLeast1Member', fallback.selectAtLeast1Member);

  @override
  String get selectImage => OtaTranslationService.translate(locale, 'selectImage', fallback.selectImage);

  @override
  String get selectMembers => OtaTranslationService.translate(locale, 'selectMembers', fallback.selectMembers);

  @override
  String get selected => OtaTranslationService.translate(locale, 'selected', fallback.selected);

  @override
  String get sending => OtaTranslationService.translate(locale, 'sending', fallback.sending);

  @override
  String get serverErrorMsg => OtaTranslationService.translate(locale, 'serverErrorMsg', fallback.serverErrorMsg);

  @override
  String get sessionExpiredMsg => OtaTranslationService.translate(locale, 'sessionExpiredMsg', fallback.sessionExpiredMsg);

  @override
  String get shareProfileAction => OtaTranslationService.translate(locale, 'shareProfileAction', fallback.shareProfileAction);

  @override
  String get sharedFolderTitle => OtaTranslationService.translate(locale, 'sharedFolderTitle', fallback.sharedFolderTitle);

  @override
  String get showOnlineStatus => OtaTranslationService.translate(locale, 'showOnlineStatus', fallback.showOnlineStatus);

  @override
  String get size => OtaTranslationService.translate(locale, 'size', fallback.size);

  @override
  String get skip => OtaTranslationService.translate(locale, 'skip', fallback.skip);

  @override
  String get skipForNow => OtaTranslationService.translate(locale, 'skipForNow', fallback.skipForNow);

  @override
  String get sort => OtaTranslationService.translate(locale, 'sort', fallback.sort);

  @override
  String get startLive => OtaTranslationService.translate(locale, 'startLive', fallback.startLive);

  @override
  String get statistics => OtaTranslationService.translate(locale, 'statistics', fallback.statistics);

  @override
  String get stickersTab => OtaTranslationService.translate(locale, 'stickersTab', fallback.stickersTab);

  @override
  String get storyPublishedMsg => OtaTranslationService.translate(locale, 'storyPublishedMsg', fallback.storyPublishedMsg);

  @override
  String get strikethroughFormat => OtaTranslationService.translate(locale, 'strikethroughFormat', fallback.strikethroughFormat);

  @override
  String get takePhoto => OtaTranslationService.translate(locale, 'takePhoto', fallback.takePhoto);

  @override
  String get tapBookmarkToSave => OtaTranslationService.translate(locale, 'tapBookmarkToSave', fallback.tapBookmarkToSave);

  @override
  String get termsOfUseTitle => OtaTranslationService.translate(locale, 'termsOfUseTitle', fallback.termsOfUseTitle);

  @override
  String get thankYouForReporting => OtaTranslationService.translate(locale, 'thankYouForReporting', fallback.thankYouForReporting);

  @override
  String get themeColorLabel => OtaTranslationService.translate(locale, 'themeColorLabel', fallback.themeColorLabel);

  @override
  String get thousandsOfCommunities => OtaTranslationService.translate(locale, 'thousandsOfCommunities', fallback.thousandsOfCommunities);

  @override
  String get titles => OtaTranslationService.translate(locale, 'titles', fallback.titles);

  @override
  String get totalMembers => OtaTranslationService.translate(locale, 'totalMembers', fallback.totalMembers);

  @override
  String get transactions => OtaTranslationService.translate(locale, 'transactions', fallback.transactions);

  @override
  String get type => OtaTranslationService.translate(locale, 'type', fallback.type);

  @override
  String get unblockAction => OtaTranslationService.translate(locale, 'unblockAction', fallback.unblockAction);

  @override
  String get underline => OtaTranslationService.translate(locale, 'underline', fallback.underline);

  @override
  String get unequip => OtaTranslationService.translate(locale, 'unequip', fallback.unequip);

  @override
  String get unlistedVisibility => OtaTranslationService.translate(locale, 'unlistedVisibility', fallback.unlistedVisibility);

  @override
  String get uploadFile => OtaTranslationService.translate(locale, 'uploadFile', fallback.uploadFile);

  @override
  String get userUnblocked => OtaTranslationService.translate(locale, 'userUnblocked', fallback.userUnblocked);

  @override
  String get videosLabel => OtaTranslationService.translate(locale, 'videosLabel', fallback.videosLabel);

  @override
  String get viewers => OtaTranslationService.translate(locale, 'viewers', fallback.viewers);

  @override
  String get views => OtaTranslationService.translate(locale, 'views', fallback.views);

  @override
  String get violence => OtaTranslationService.translate(locale, 'violence', fallback.violence);

  @override
  String get visualLabel => OtaTranslationService.translate(locale, 'visualLabel', fallback.visualLabel);

  @override
  String get vote => OtaTranslationService.translate(locale, 'vote', fallback.vote);

  @override
  String get votes => OtaTranslationService.translate(locale, 'votes', fallback.votes);

  @override
  String get walletTitle => OtaTranslationService.translate(locale, 'walletTitle', fallback.walletTitle);

  @override
  String get watchAd => OtaTranslationService.translate(locale, 'watchAd', fallback.watchAd);

  @override
  String get weWillReviewReport => OtaTranslationService.translate(locale, 'weWillReviewReport', fallback.weWillReviewReport);

  @override
  String get whoCanMessageMe => OtaTranslationService.translate(locale, 'whoCanMessageMe', fallback.whoCanMessageMe);

  @override
  String get whoCanSeeProfile => OtaTranslationService.translate(locale, 'whoCanSeeProfile', fallback.whoCanSeeProfile);

  @override
  String get writeCommunityGuidelines => OtaTranslationService.translate(locale, 'writeCommunityGuidelines', fallback.writeCommunityGuidelines);

  @override
  String get writeOnWall => OtaTranslationService.translate(locale, 'writeOnWall', fallback.writeOnWall);

  @override
  String get accountLinked => OtaTranslationService.translate(locale, 'accountLinked', fallback.accountLinked);

  @override
  String get active2 => OtaTranslationService.translate(locale, 'active2', fallback.active2);

  @override
  String get adService => OtaTranslationService.translate(locale, 'adService', fallback.adService);

  @override
  String get addCoverOptional => OtaTranslationService.translate(locale, 'addCoverOptional', fallback.addCoverOptional);

  @override
  String get allSessionsRevoked => OtaTranslationService.translate(locale, 'allSessionsRevoked', fallback.allSessionsRevoked);

  @override
  String get allSubmissionsReviewed => OtaTranslationService.translate(locale, 'allSubmissionsReviewed', fallback.allSubmissionsReviewed);

  @override
  String get allow => OtaTranslationService.translate(locale, 'allow', fallback.allow);

  @override
  String get allowFindByName => OtaTranslationService.translate(locale, 'allowFindByName', fallback.allowFindByName);

  @override
  String get allowGroupChatInvitations => OtaTranslationService.translate(locale, 'allowGroupChatInvitations', fallback.allowGroupChatInvitations);

  @override
  String get allowMentions => OtaTranslationService.translate(locale, 'allowMentions', fallback.allowMentions);

  @override
  String get allowOthersToSendDms => OtaTranslationService.translate(locale, 'allowOthersToSendDms', fallback.allowOthersToSendDms);

  @override
  String get allowed => OtaTranslationService.translate(locale, 'allowed', fallback.allowed);

  @override
  String get allowedContent => OtaTranslationService.translate(locale, 'allowedContent', fallback.allowedContent);

  @override
  String get allowedContentDetails => OtaTranslationService.translate(locale, 'allowedContentDetails', fallback.allowedContentDetails);

  @override
  String get aminoPlus => OtaTranslationService.translate(locale, 'aminoPlus', fallback.aminoPlus);

  @override
  String get aminoPlusRate => OtaTranslationService.translate(locale, 'aminoPlusRate', fallback.aminoPlusRate);

  @override
  String get aminoPlusSubscribers => OtaTranslationService.translate(locale, 'aminoPlusSubscribers', fallback.aminoPlusSubscribers);

  @override
  String get android => OtaTranslationService.translate(locale, 'android', fallback.android);

  @override
  String get androidVersion => OtaTranslationService.translate(locale, 'androidVersion', fallback.androidVersion);

  @override
  String get animeManga => OtaTranslationService.translate(locale, 'animeManga', fallback.animeManga);

  @override
  String get anonymous2 => OtaTranslationService.translate(locale, 'anonymous2', fallback.anonymous2);

  @override
  String get anyMemberCanJoin => OtaTranslationService.translate(locale, 'anyMemberCanJoin', fallback.anyMemberCanJoin);

  @override
  String get anyMemberCanParticipate => OtaTranslationService.translate(locale, 'anyMemberCanParticipate', fallback.anyMemberCanParticipate);

  @override
  String get apiKey => OtaTranslationService.translate(locale, 'apiKey', fallback.apiKey);

  @override
  String get appPermissions2 => OtaTranslationService.translate(locale, 'appPermissions2', fallback.appPermissions2);

  @override
  String get approved2 => OtaTranslationService.translate(locale, 'approved2', fallback.approved2);

  @override
  String get artDesign => OtaTranslationService.translate(locale, 'artDesign', fallback.artDesign);

  @override
  String get artTheft => OtaTranslationService.translate(locale, 'artTheft', fallback.artTheft);

  @override
  String get audio2 => OtaTranslationService.translate(locale, 'audio2', fallback.audio2);

  @override
  String get authError => OtaTranslationService.translate(locale, 'authError', fallback.authError);

  @override
  String get averageRating => OtaTranslationService.translate(locale, 'averageRating', fallback.averageRating);

  @override
  String get bannedUsers => OtaTranslationService.translate(locale, 'bannedUsers', fallback.bannedUsers);

  @override
  String get bannedUsersCount => OtaTranslationService.translate(locale, 'bannedUsersCount', fallback.bannedUsersCount);

  @override
  String get blockedOnDate => OtaTranslationService.translate(locale, 'blockedOnDate', fallback.blockedOnDate);

  @override
  String get blockedUsers2 => OtaTranslationService.translate(locale, 'blockedUsers2', fallback.blockedUsers2);

  @override
  String get blockedUsersInfo => OtaTranslationService.translate(locale, 'blockedUsersInfo', fallback.blockedUsersInfo);

  @override
  String get booksWriting => OtaTranslationService.translate(locale, 'booksWriting', fallback.booksWriting);

  @override
  String get browser => OtaTranslationService.translate(locale, 'browser', fallback.browser);

  @override
  String get bullying => OtaTranslationService.translate(locale, 'bullying', fallback.bullying);

  @override
  String get byAuthor => OtaTranslationService.translate(locale, 'byAuthor', fallback.byAuthor);

  @override
  String get cacheCleared2 => OtaTranslationService.translate(locale, 'cacheCleared2', fallback.cacheCleared2);

  @override
  String get cacheService => OtaTranslationService.translate(locale, 'cacheService', fallback.cacheService);

  @override
  String get cameraMicrophoneNotifications => OtaTranslationService.translate(locale, 'cameraMicrophoneNotifications', fallback.cameraMicrophoneNotifications);

  @override
  String get cancel2 => OtaTranslationService.translate(locale, 'cancel2', fallback.cancel2);

  @override
  String get cannotUnlinkLastLogin => OtaTranslationService.translate(locale, 'cannotUnlinkLastLogin', fallback.cannotUnlinkLastLogin);

  @override
  String get catalog => OtaTranslationService.translate(locale, 'catalog', fallback.catalog);

  @override
  String get change => OtaTranslationService.translate(locale, 'change', fallback.change);

  @override
  String get changeEmail => OtaTranslationService.translate(locale, 'changeEmail', fallback.changeEmail);

  @override
  String get chat2 => OtaTranslationService.translate(locale, 'chat2', fallback.chat2);

  @override
  String get chatInvitations => OtaTranslationService.translate(locale, 'chatInvitations', fallback.chatInvitations);

  @override
  String get chatName2 => OtaTranslationService.translate(locale, 'chatName2', fallback.chatName2);

  @override
  String get chatNameIsRequired => OtaTranslationService.translate(locale, 'chatNameIsRequired', fallback.chatNameIsRequired);

  @override
  String get chatNameRequired => OtaTranslationService.translate(locale, 'chatNameRequired', fallback.chatNameRequired);

  @override
  String get chats2 => OtaTranslationService.translate(locale, 'chats2', fallback.chats2);

  @override
  String get checkInHistory => OtaTranslationService.translate(locale, 'checkInHistory', fallback.checkInHistory);

  @override
  String get checkInSequence => OtaTranslationService.translate(locale, 'checkInSequence', fallback.checkInSequence);

  @override
  String get clear => OtaTranslationService.translate(locale, 'clear', fallback.clear);

  @override
  String get clearCache2 => OtaTranslationService.translate(locale, 'clearCache2', fallback.clearCache2);

  @override
  String get clearTempData => OtaTranslationService.translate(locale, 'clearTempData', fallback.clearTempData);

  @override
  String get closingBracket => OtaTranslationService.translate(locale, 'closingBracket', fallback.closingBracket);

  @override
  String get cloudDataUnaffected => OtaTranslationService.translate(locale, 'cloudDataUnaffected', fallback.cloudDataUnaffected);

  @override
  String get coinsInCirculation => OtaTranslationService.translate(locale, 'coinsInCirculation', fallback.coinsInCirculation);

  @override
  String get coinsPerUserAverage => OtaTranslationService.translate(locale, 'coinsPerUserAverage', fallback.coinsPerUserAverage);

  @override
  String get communitiesList => OtaTranslationService.translate(locale, 'communitiesList', fallback.communitiesList);

  @override
  String get community2 => OtaTranslationService.translate(locale, 'community2', fallback.community2);

  @override
  String get communityLabel => OtaTranslationService.translate(locale, 'communityLabel', fallback.communityLabel);

  @override
  String get communityNameRequired => OtaTranslationService.translate(locale, 'communityNameRequired', fallback.communityNameRequired);

  @override
  String get confirmContinue => OtaTranslationService.translate(locale, 'confirmContinue', fallback.confirmContinue);

  @override
  String get confirmDeletion => OtaTranslationService.translate(locale, 'confirmDeletion', fallback.confirmDeletion);

  @override
  String get confirmDeletionButton => OtaTranslationService.translate(locale, 'confirmDeletionButton', fallback.confirmDeletionButton);

  @override
  String get confirmUnblockUser => OtaTranslationService.translate(locale, 'confirmUnblockUser', fallback.confirmUnblockUser);

  @override
  String get confirmUnlinkAccount => OtaTranslationService.translate(locale, 'confirmUnlinkAccount', fallback.confirmUnlinkAccount);

  @override
  String get confirmationEmailSent => OtaTranslationService.translate(locale, 'confirmationEmailSent', fallback.confirmationEmailSent);

  @override
  String get connectWithYourCommunities => OtaTranslationService.translate(locale, 'connectWithYourCommunities', fallback.connectWithYourCommunities);

  @override
  String get connectedDevices => OtaTranslationService.translate(locale, 'connectedDevices', fallback.connectedDevices);

  @override
  String get contributor => OtaTranslationService.translate(locale, 'contributor', fallback.contributor);

  @override
  String get coverImageUrl => OtaTranslationService.translate(locale, 'coverImageUrl', fallback.coverImageUrl);

  @override
  String get curator2 => OtaTranslationService.translate(locale, 'curator2', fallback.curator2);

  @override
  String get currencyBrl => OtaTranslationService.translate(locale, 'currencyBrl', fallback.currencyBrl);

  @override
  String get current => OtaTranslationService.translate(locale, 'current', fallback.current);

  @override
  String get currentCacheSize => OtaTranslationService.translate(locale, 'currentCacheSize', fallback.currentCacheSize);

  @override
  String get currentStreak => OtaTranslationService.translate(locale, 'currentStreak', fallback.currentStreak);

  @override
  String get customizePrompt => OtaTranslationService.translate(locale, 'customizePrompt', fallback.customizePrompt);

  @override
  String get data => OtaTranslationService.translate(locale, 'data', fallback.data);

  @override
  String get dedicated => OtaTranslationService.translate(locale, 'dedicated', fallback.dedicated);

  @override
  String get defaultFirebaseOptionsIosNotConfigured => OtaTranslationService.translate(locale, 'defaultFirebaseOptionsIosNotConfigured', fallback.defaultFirebaseOptionsIosNotConfigured);

  @override
  String get defaultFirebaseOptionsLinuxNotConfigured => OtaTranslationService.translate(locale, 'defaultFirebaseOptionsLinuxNotConfigured', fallback.defaultFirebaseOptionsLinuxNotConfigured);

  @override
  String get defaultFirebaseOptionsMacosNotConfigured => OtaTranslationService.translate(locale, 'defaultFirebaseOptionsMacosNotConfigured', fallback.defaultFirebaseOptionsMacosNotConfigured);

  @override
  String get defaultFirebaseOptionsNotSupported => OtaTranslationService.translate(locale, 'defaultFirebaseOptionsNotSupported', fallback.defaultFirebaseOptionsNotSupported);

  @override
  String get defaultFirebaseOptionsWebNotConfigured => OtaTranslationService.translate(locale, 'defaultFirebaseOptionsWebNotConfigured', fallback.defaultFirebaseOptionsWebNotConfigured);

  @override
  String get defaultFirebaseOptionsWindowsNotConfigured => OtaTranslationService.translate(locale, 'defaultFirebaseOptionsWindowsNotConfigured', fallback.defaultFirebaseOptionsWindowsNotConfigured);

  @override
  String get deleteAccount2 => OtaTranslationService.translate(locale, 'deleteAccount2', fallback.deleteAccount2);

  @override
  String get deleteAccountError => OtaTranslationService.translate(locale, 'deleteAccountError', fallback.deleteAccountError);

  @override
  String get deleteButton => OtaTranslationService.translate(locale, 'deleteButton', fallback.deleteButton);

  @override
  String get describeChatPurpose => OtaTranslationService.translate(locale, 'describeChatPurpose', fallback.describeChatPurpose);

  @override
  String get describeCorrections => OtaTranslationService.translate(locale, 'describeCorrections', fallback.describeCorrections);

  @override
  String get describeGroup => OtaTranslationService.translate(locale, 'describeGroup', fallback.describeGroup);

  @override
  String get descriptionOptional => OtaTranslationService.translate(locale, 'descriptionOptional', fallback.descriptionOptional);

  @override
  String get descriptionOptional2 => OtaTranslationService.translate(locale, 'descriptionOptional2', fallback.descriptionOptional2);

  @override
  String get detailedContent => OtaTranslationService.translate(locale, 'detailedContent', fallback.detailedContent);

  @override
  String get device => OtaTranslationService.translate(locale, 'device', fallback.device);

  @override
  String get deviceRevoked => OtaTranslationService.translate(locale, 'deviceRevoked', fallback.deviceRevoked);

  @override
  String get directMessages => OtaTranslationService.translate(locale, 'directMessages', fallback.directMessages);

  @override
  String get discover => OtaTranslationService.translate(locale, 'discover', fallback.discover);

  @override
  String get diy => OtaTranslationService.translate(locale, 'diy', fallback.diy);

  @override
  String get downloadDataCopy => OtaTranslationService.translate(locale, 'downloadDataCopy', fallback.downloadDataCopy);

  @override
  String get economy => OtaTranslationService.translate(locale, 'economy', fallback.economy);

  @override
  String get editGuidelines2 => OtaTranslationService.translate(locale, 'editGuidelines2', fallback.editGuidelines2);

  @override
  String get emailAlreadyRegistered => OtaTranslationService.translate(locale, 'emailAlreadyRegistered', fallback.emailAlreadyRegistered);

  @override
  String get emailAndPassword => OtaTranslationService.translate(locale, 'emailAndPassword', fallback.emailAndPassword);

  @override
  String get entryNotFound => OtaTranslationService.translate(locale, 'entryNotFound', fallback.entryNotFound);

  @override
  String get entrySentForReview => OtaTranslationService.translate(locale, 'entrySentForReview', fallback.entrySentForReview);

  @override
  String get entryTitle => OtaTranslationService.translate(locale, 'entryTitle', fallback.entryTitle);

  @override
  String get errorDetails => OtaTranslationService.translate(locale, 'errorDetails', fallback.errorDetails);

  @override
  String get errorLoadingMoreNotifications => OtaTranslationService.translate(locale, 'errorLoadingMoreNotifications', fallback.errorLoadingMoreNotifications);

  @override
  String get errorLoadingStories => OtaTranslationService.translate(locale, 'errorLoadingStories', fallback.errorLoadingStories);

  @override
  String get exampleChatName => OtaTranslationService.translate(locale, 'exampleChatName', fallback.exampleChatName);

  @override
  String get exampleGroupName => OtaTranslationService.translate(locale, 'exampleGroupName', fallback.exampleGroupName);

  @override
  String get expert => OtaTranslationService.translate(locale, 'expert', fallback.expert);

  @override
  String get exportData2 => OtaTranslationService.translate(locale, 'exportData2', fallback.exportData2);

  @override
  String get exportInProgress => OtaTranslationService.translate(locale, 'exportInProgress', fallback.exportInProgress);

  @override
  String get exportMyData => OtaTranslationService.translate(locale, 'exportMyData', fallback.exportMyData);

  @override
  String get failedToLoadData => OtaTranslationService.translate(locale, 'failedToLoadData', fallback.failedToLoadData);

  @override
  String get ffH => OtaTranslationService.translate(locale, 'ffH', fallback.ffH);

  @override
  String get field => OtaTranslationService.translate(locale, 'field', fallback.field);

  @override
  String get finalConfirmation => OtaTranslationService.translate(locale, 'finalConfirmation', fallback.finalConfirmation);

  @override
  String get followersList => OtaTranslationService.translate(locale, 'followersList', fallback.followersList);

  @override
  String get freeStorage => OtaTranslationService.translate(locale, 'freeStorage', fallback.freeStorage);

  @override
  String get friday => OtaTranslationService.translate(locale, 'friday', fallback.friday);

  @override
  String get games => OtaTranslationService.translate(locale, 'games', fallback.games);

  @override
  String get gamification => OtaTranslationService.translate(locale, 'gamification', fallback.gamification);

  @override
  String get generalRules => OtaTranslationService.translate(locale, 'generalRules', fallback.generalRules);

  @override
  String get generalRulesDetails => OtaTranslationService.translate(locale, 'generalRulesDetails', fallback.generalRulesDetails);

  @override
  String get gif => OtaTranslationService.translate(locale, 'gif', fallback.gif);

  @override
  String get googleApple => OtaTranslationService.translate(locale, 'googleApple', fallback.googleApple);

  @override
  String get googleTokenError => OtaTranslationService.translate(locale, 'googleTokenError', fallback.googleTokenError);

  @override
  String get groupCreatedSuccessfully => OtaTranslationService.translate(locale, 'groupCreatedSuccessfully', fallback.groupCreatedSuccessfully);

  @override
  String get groupName2 => OtaTranslationService.translate(locale, 'groupName2', fallback.groupName2);

  @override
  String get guidelinesSaved => OtaTranslationService.translate(locale, 'guidelinesSaved', fallback.guidelinesSaved);

  @override
  String get guru => OtaTranslationService.translate(locale, 'guru', fallback.guru);

  @override
  String get highestStreak => OtaTranslationService.translate(locale, 'highestStreak', fallback.highestStreak);

  @override
  String get home2 => OtaTranslationService.translate(locale, 'home2', fallback.home2);

  @override
  String get iap => OtaTranslationService.translate(locale, 'iap', fallback.iap);

  @override
  String get image2 => OtaTranslationService.translate(locale, 'image2', fallback.image2);

  @override
  String get inappropriateContent2 => OtaTranslationService.translate(locale, 'inappropriateContent2', fallback.inappropriateContent2);

  @override
  String get incorrectEmailOrPassword => OtaTranslationService.translate(locale, 'incorrectEmailOrPassword', fallback.incorrectEmailOrPassword);

  @override
  String get incredible => OtaTranslationService.translate(locale, 'incredible', fallback.incredible);

  @override
  String get infobox => OtaTranslationService.translate(locale, 'infobox', fallback.infobox);

  @override
  String get invalidCallSession => OtaTranslationService.translate(locale, 'invalidCallSession', fallback.invalidCallSession);

  @override
  String get invalidEmail2 => OtaTranslationService.translate(locale, 'invalidEmail2', fallback.invalidEmail2);

  @override
  String get invalidUrl => OtaTranslationService.translate(locale, 'invalidUrl', fallback.invalidUrl);

  @override
  String get invitedMembersOnly => OtaTranslationService.translate(locale, 'invitedMembersOnly', fallback.invitedMembersOnly);

  @override
  String get ipAddress => OtaTranslationService.translate(locale, 'ipAddress', fallback.ipAddress);

  @override
  String get irreversibleActionWarning => OtaTranslationService.translate(locale, 'irreversibleActionWarning', fallback.irreversibleActionWarning);

  @override
  String get joinedChannelInMs => OtaTranslationService.translate(locale, 'joinedChannelInMs', fallback.joinedChannelInMs);

  @override
  String get languageChanged => OtaTranslationService.translate(locale, 'languageChanged', fallback.languageChanged);

  @override
  String get lastAccess2 => OtaTranslationService.translate(locale, 'lastAccess2', fallback.lastAccess2);

  @override
  String get lastSevenDays => OtaTranslationService.translate(locale, 'lastSevenDays', fallback.lastSevenDays);

  @override
  String get leader2 => OtaTranslationService.translate(locale, 'leader2', fallback.leader2);

  @override
  String get levelLabel => OtaTranslationService.translate(locale, 'levelLabel', fallback.levelLabel);

  @override
  String get levelUp2 => OtaTranslationService.translate(locale, 'levelUp2', fallback.levelUp2);

  @override
  String get levelUpAlert => OtaTranslationService.translate(locale, 'levelUpAlert', fallback.levelUpAlert);

  @override
  String get linkProviderError => OtaTranslationService.translate(locale, 'linkProviderError', fallback.linkProviderError);

  @override
  String get linux => OtaTranslationService.translate(locale, 'linux', fallback.linux);

  @override
  String get linuxVersion => OtaTranslationService.translate(locale, 'linuxVersion', fallback.linuxVersion);

  @override
  String get loadMoreError => OtaTranslationService.translate(locale, 'loadMoreError', fallback.loadMoreError);

  @override
  String get manageConnectedDevices => OtaTranslationService.translate(locale, 'manageConnectedDevices', fallback.manageConnectedDevices);

  @override
  String get managePermissions => OtaTranslationService.translate(locale, 'managePermissions', fallback.managePermissions);

  @override
  String get maxStreakRecord => OtaTranslationService.translate(locale, 'maxStreakRecord', fallback.maxStreakRecord);

  @override
  String get memesHumor => OtaTranslationService.translate(locale, 'memesHumor', fallback.memesHumor);

  @override
  String get messageDeleted2 => OtaTranslationService.translate(locale, 'messageDeleted2', fallback.messageDeleted2);

  @override
  String get messageLikeCommentAlerts => OtaTranslationService.translate(locale, 'messageLikeCommentAlerts', fallback.messageLikeCommentAlerts);

  @override
  String get messagePlaceholder => OtaTranslationService.translate(locale, 'messagePlaceholder', fallback.messagePlaceholder);

  @override
  String get messagesToday => OtaTranslationService.translate(locale, 'messagesToday', fallback.messagesToday);

  @override
  String get microphone => OtaTranslationService.translate(locale, 'microphone', fallback.microphone);

  @override
  String get monday => OtaTranslationService.translate(locale, 'monday', fallback.monday);

  @override
  String get monetizationRate => OtaTranslationService.translate(locale, 'monetizationRate', fallback.monetizationRate);

  @override
  String get moviesSeries => OtaTranslationService.translate(locale, 'moviesSeries', fallback.moviesSeries);

  @override
  String get mustBeCommunityMember => OtaTranslationService.translate(locale, 'mustBeCommunityMember', fallback.mustBeCommunityMember);

  @override
  String get myRating => OtaTranslationService.translate(locale, 'myRating', fallback.myRating);

  @override
  String get nameMaxLength => OtaTranslationService.translate(locale, 'nameMaxLength', fallback.nameMaxLength);

  @override
  String get nameMinLength => OtaTranslationService.translate(locale, 'nameMinLength', fallback.nameMinLength);

  @override
  String get nameMinLength2 => OtaTranslationService.translate(locale, 'nameMinLength2', fallback.nameMinLength2);

  @override
  String get newEmail => OtaTranslationService.translate(locale, 'newEmail', fallback.newEmail);

  @override
  String get newPublicChat => OtaTranslationService.translate(locale, 'newPublicChat', fallback.newPublicChat);

  @override
  String get newTitleUnlocked => OtaTranslationService.translate(locale, 'newTitleUnlocked', fallback.newTitleUnlocked);

  @override
  String get newWikiEntry => OtaTranslationService.translate(locale, 'newWikiEntry', fallback.newWikiEntry);

  @override
  String get nexusHub => OtaTranslationService.translate(locale, 'nexusHub', fallback.nexusHub);

  @override
  String get nicknameInUse => OtaTranslationService.translate(locale, 'nicknameInUse', fallback.nicknameInUse);

  @override
  String get nicknameMaxLength => OtaTranslationService.translate(locale, 'nicknameMaxLength', fallback.nicknameMaxLength);

  @override
  String get nicknameMinLength => OtaTranslationService.translate(locale, 'nicknameMinLength', fallback.nicknameMinLength);

  @override
  String get nicknameRequired => OtaTranslationService.translate(locale, 'nicknameRequired', fallback.nicknameRequired);

  @override
  String get nicknameValidChars => OtaTranslationService.translate(locale, 'nicknameValidChars', fallback.nicknameValidChars);

  @override
  String get noCategoriesAvailable => OtaTranslationService.translate(locale, 'noCategoriesAvailable', fallback.noCategoriesAvailable);

  @override
  String get noContentToDisplay => OtaTranslationService.translate(locale, 'noContentToDisplay', fallback.noContentToDisplay);

  @override
  String get noEntriesFound => OtaTranslationService.translate(locale, 'noEntriesFound', fallback.noEntriesFound);

  @override
  String get noInternetConnection => OtaTranslationService.translate(locale, 'noInternetConnection', fallback.noInternetConnection);

  @override
  String get noItemsFound => OtaTranslationService.translate(locale, 'noItemsFound', fallback.noItemsFound);

  @override
  String get noPendingWiki => OtaTranslationService.translate(locale, 'noPendingWiki', fallback.noPendingWiki);

  @override
  String get noPermission => OtaTranslationService.translate(locale, 'noPermission', fallback.noPermission);

  @override
  String get noReason => OtaTranslationService.translate(locale, 'noReason', fallback.noReason);

  @override
  String get noReasonSpecified => OtaTranslationService.translate(locale, 'noReasonSpecified', fallback.noReasonSpecified);

  @override
  String get noRecentReports => OtaTranslationService.translate(locale, 'noRecentReports', fallback.noRecentReports);

  @override
  String get noRegisteredDevices => OtaTranslationService.translate(locale, 'noRegisteredDevices', fallback.noRegisteredDevices);

  @override
  String get noResolvedReports => OtaTranslationService.translate(locale, 'noResolvedReports', fallback.noResolvedReports);

  @override
  String get noStoriesYet => OtaTranslationService.translate(locale, 'noStoriesYet', fallback.noStoriesYet);

  @override
  String get noTitle => OtaTranslationService.translate(locale, 'noTitle', fallback.noTitle);

  @override
  String get notRequested => OtaTranslationService.translate(locale, 'notRequested', fallback.notRequested);

  @override
  String get notificationWhenReady => OtaTranslationService.translate(locale, 'notificationWhenReady', fallback.notificationWhenReady);

  @override
  String get offTopic => OtaTranslationService.translate(locale, 'offTopic', fallback.offTopic);

  @override
  String get onlyFollowBack => OtaTranslationService.translate(locale, 'onlyFollowBack', fallback.onlyFollowBack);

  @override
  String get openSettings => OtaTranslationService.translate(locale, 'openSettings', fallback.openSettings);

  @override
  String get openSystemSettings => OtaTranslationService.translate(locale, 'openSystemSettings', fallback.openSystemSettings);

  @override
  String get operationTimeout => OtaTranslationService.translate(locale, 'operationTimeout', fallback.operationTimeout);

  @override
  String get otherDevicesReLogin => OtaTranslationService.translate(locale, 'otherDevicesReLogin', fallback.otherDevicesReLogin);

  @override
  String get passwordsDoNotMatch2 => OtaTranslationService.translate(locale, 'passwordsDoNotMatch2', fallback.passwordsDoNotMatch2);

  @override
  String get pending2 => OtaTranslationService.translate(locale, 'pending2', fallback.pending2);

  @override
  String get pendingFlagsCount => OtaTranslationService.translate(locale, 'pendingFlagsCount', fallback.pendingFlagsCount);

  @override
  String get pendingReview2 => OtaTranslationService.translate(locale, 'pendingReview2', fallback.pendingReview2);

  @override
  String get permanentDelete => OtaTranslationService.translate(locale, 'permanentDelete', fallback.permanentDelete);

  @override
  String get permanentDeletionNotice => OtaTranslationService.translate(locale, 'permanentDeletionNotice', fallback.permanentDeletionNotice);

  @override
  String get permanentlyDenied => OtaTranslationService.translate(locale, 'permanentlyDenied', fallback.permanentlyDenied);

  @override
  String get permissionDenied2 => OtaTranslationService.translate(locale, 'permissionDenied2', fallback.permissionDenied2);

  @override
  String get permissionPermanentlyDenied => OtaTranslationService.translate(locale, 'permissionPermanentlyDenied', fallback.permissionPermanentlyDenied);

  @override
  String get petsAnimals => OtaTranslationService.translate(locale, 'petsAnimals', fallback.petsAnimals);

  @override
  String get photosAndMedia => OtaTranslationService.translate(locale, 'photosAndMedia', fallback.photosAndMedia);

  @override
  String get plusJakartaSans => OtaTranslationService.translate(locale, 'plusJakartaSans', fallback.plusJakartaSans);

  @override
  String get poll2 => OtaTranslationService.translate(locale, 'poll2', fallback.poll2);

  @override
  String get positiveNumber => OtaTranslationService.translate(locale, 'positiveNumber', fallback.positiveNumber);

  @override
  String get postsToday => OtaTranslationService.translate(locale, 'postsToday', fallback.postsToday);

  @override
  String get preferences => OtaTranslationService.translate(locale, 'preferences', fallback.preferences);

  @override
  String get prepareDataFile => OtaTranslationService.translate(locale, 'prepareDataFile', fallback.prepareDataFile);

  @override
  String get preview2 => OtaTranslationService.translate(locale, 'preview2', fallback.preview2);

  @override
  String get profileLevel => OtaTranslationService.translate(locale, 'profileLevel', fallback.profileLevel);

  @override
  String get profilePicture => OtaTranslationService.translate(locale, 'profilePicture', fallback.profilePicture);

  @override
  String get prohibitedContent => OtaTranslationService.translate(locale, 'prohibitedContent', fallback.prohibitedContent);

  @override
  String get prohibitedContentDetails => OtaTranslationService.translate(locale, 'prohibitedContentDetails', fallback.prohibitedContentDetails);

  @override
  String get publicChat => OtaTranslationService.translate(locale, 'publicChat', fallback.publicChat);

  @override
  String get publicChatCreated => OtaTranslationService.translate(locale, 'publicChatCreated', fallback.publicChatCreated);

  @override
  String get publicChatsVisible => OtaTranslationService.translate(locale, 'publicChatsVisible', fallback.publicChatsVisible);

  @override
  String get pushNotification => OtaTranslationService.translate(locale, 'pushNotification', fallback.pushNotification);

  @override
  String get recentReports => OtaTranslationService.translate(locale, 'recentReports', fallback.recentReports);

  @override
  String get regular => OtaTranslationService.translate(locale, 'regular', fallback.regular);

  @override
  String get rejected2 => OtaTranslationService.translate(locale, 'rejected2', fallback.rejected2);

  @override
  String get rejectionReason => OtaTranslationService.translate(locale, 'rejectionReason', fallback.rejectionReason);

  @override
  String get renderFlex => OtaTranslationService.translate(locale, 'renderFlex', fallback.renderFlex);

  @override
  String get renderFlexOverflowed => OtaTranslationService.translate(locale, 'renderFlexOverflowed', fallback.renderFlexOverflowed);

  @override
  String get reportedBy => OtaTranslationService.translate(locale, 'reportedBy', fallback.reportedBy);

  @override
  String get requestButton => OtaTranslationService.translate(locale, 'requestButton', fallback.requestButton);

  @override
  String get requestSentNotification => OtaTranslationService.translate(locale, 'requestSentNotification', fallback.requestSentNotification);

  @override
  String get resolved2 => OtaTranslationService.translate(locale, 'resolved2', fallback.resolved2);

  @override
  String get response => OtaTranslationService.translate(locale, 'response', fallback.response);

  @override
  String get revoke => OtaTranslationService.translate(locale, 'revoke', fallback.revoke);

  @override
  String get revokeAll => OtaTranslationService.translate(locale, 'revokeAll', fallback.revokeAll);

  @override
  String get revokeAllOthers => OtaTranslationService.translate(locale, 'revokeAllOthers', fallback.revokeAllOthers);

  @override
  String get revokeDevice => OtaTranslationService.translate(locale, 'revokeDevice', fallback.revokeDevice);

  @override
  String get revokeDeviceConfirmation => OtaTranslationService.translate(locale, 'revokeDeviceConfirmation', fallback.revokeDeviceConfirmation);

  @override
  String get revokeOtherSessions => OtaTranslationService.translate(locale, 'revokeOtherSessions', fallback.revokeOtherSessions);

  @override
  String get revokeOthers => OtaTranslationService.translate(locale, 'revokeOthers', fallback.revokeOthers);

  @override
  String get revokeUnrecognizedDevices => OtaTranslationService.translate(locale, 'revokeUnrecognizedDevices', fallback.revokeUnrecognizedDevices);

  @override
  String get rolesResponsibilities => OtaTranslationService.translate(locale, 'rolesResponsibilities', fallback.rolesResponsibilities);

  @override
  String get rolesResponsibilitiesDetails => OtaTranslationService.translate(locale, 'rolesResponsibilitiesDetails', fallback.rolesResponsibilitiesDetails);

  @override
  String get saturday => OtaTranslationService.translate(locale, 'saturday', fallback.saturday);

  @override
  String get saveFilesAndMedia => OtaTranslationService.translate(locale, 'saveFilesAndMedia', fallback.saveFilesAndMedia);

  @override
  String get screening => OtaTranslationService.translate(locale, 'screening', fallback.screening);

  @override
  String get searchByName => OtaTranslationService.translate(locale, 'searchByName', fallback.searchByName);

  @override
  String get searchCatalog => OtaTranslationService.translate(locale, 'searchCatalog', fallback.searchCatalog);

  @override
  String get securityCheck => OtaTranslationService.translate(locale, 'securityCheck', fallback.securityCheck);

  @override
  String get selectCategory => OtaTranslationService.translate(locale, 'selectCategory', fallback.selectCategory);

  @override
  String get selectCommunityForGroup => OtaTranslationService.translate(locale, 'selectCommunityForGroup', fallback.selectCommunityForGroup);

  @override
  String get selectMembers2 => OtaTranslationService.translate(locale, 'selectMembers2', fallback.selectMembers2);

  @override
  String get sendGalleryImages => OtaTranslationService.translate(locale, 'sendGalleryImages', fallback.sendGalleryImages);

  @override
  String get sendWarning => OtaTranslationService.translate(locale, 'sendWarning', fallback.sendWarning);

  @override
  String get sessionExpired2 => OtaTranslationService.translate(locale, 'sessionExpired2', fallback.sessionExpired2);

  @override
  String get shop => OtaTranslationService.translate(locale, 'shop', fallback.shop);

  @override
  String get showFollowersFollowing => OtaTranslationService.translate(locale, 'showFollowersFollowing', fallback.showFollowersFollowing);

  @override
  String get showParticipatedCommunities => OtaTranslationService.translate(locale, 'showParticipatedCommunities', fallback.showParticipatedCommunities);

  @override
  String get solveToContinue => OtaTranslationService.translate(locale, 'solveToContinue', fallback.solveToContinue);

  @override
  String get somethingWentWrong2 => OtaTranslationService.translate(locale, 'somethingWentWrong2', fallback.somethingWentWrong2);

  @override
  String get stepProgress => OtaTranslationService.translate(locale, 'stepProgress', fallback.stepProgress);

  @override
  String get sticker => OtaTranslationService.translate(locale, 'sticker', fallback.sticker);

  @override
  String get storage => OtaTranslationService.translate(locale, 'storage', fallback.storage);

  @override
  String get strikeSystem => OtaTranslationService.translate(locale, 'strikeSystem', fallback.strikeSystem);

  @override
  String get strikeSystemDetails => OtaTranslationService.translate(locale, 'strikeSystemDetails', fallback.strikeSystemDetails);

  @override
  String get sunday => OtaTranslationService.translate(locale, 'sunday', fallback.sunday);

  @override
  String get supportsMarkdown => OtaTranslationService.translate(locale, 'supportsMarkdown', fallback.supportsMarkdown);

  @override
  String get takeAction => OtaTranslationService.translate(locale, 'takeAction', fallback.takeAction);

  @override
  String get tapToRetry => OtaTranslationService.translate(locale, 'tapToRetry', fallback.tapToRetry);

  @override
  String get temporarilyPreventUser => OtaTranslationService.translate(locale, 'temporarilyPreventUser', fallback.temporarilyPreventUser);

  @override
  String get textOverflowEllipsis => OtaTranslationService.translate(locale, 'textOverflowEllipsis', fallback.textOverflowEllipsis);

  @override
  String get thursday => OtaTranslationService.translate(locale, 'thursday', fallback.thursday);

  @override
  String get tip => OtaTranslationService.translate(locale, 'tip', fallback.tip);

  @override
  String get titleRequired => OtaTranslationService.translate(locale, 'titleRequired', fallback.titleRequired);

  @override
  String get tooManyAttempts => OtaTranslationService.translate(locale, 'tooManyAttempts', fallback.tooManyAttempts);

  @override
  String get total => OtaTranslationService.translate(locale, 'total', fallback.total);

  @override
  String get totalCheckIns => OtaTranslationService.translate(locale, 'totalCheckIns', fallback.totalCheckIns);

  @override
  String get totalCheckIns2 => OtaTranslationService.translate(locale, 'totalCheckIns2', fallback.totalCheckIns2);

  @override
  String get totalMessages => OtaTranslationService.translate(locale, 'totalMessages', fallback.totalMessages);

  @override
  String get totalPosts => OtaTranslationService.translate(locale, 'totalPosts', fallback.totalPosts);

  @override
  String get tuesday => OtaTranslationService.translate(locale, 'tuesday', fallback.tuesday);

  @override
  String get typeDeleteConfirm => OtaTranslationService.translate(locale, 'typeDeleteConfirm', fallback.typeDeleteConfirm);

  @override
  String get typeDeleteToConfirm => OtaTranslationService.translate(locale, 'typeDeleteToConfirm', fallback.typeDeleteToConfirm);

  @override
  String get typeDeleteToConfirmAlt => OtaTranslationService.translate(locale, 'typeDeleteToConfirmAlt', fallback.typeDeleteToConfirmAlt);

  @override
  String get unblockUser => OtaTranslationService.translate(locale, 'unblockUser', fallback.unblockUser);

  @override
  String get unexpectedError => OtaTranslationService.translate(locale, 'unexpectedError', fallback.unexpectedError);

  @override
  String get unexpectedErrorRetry => OtaTranslationService.translate(locale, 'unexpectedErrorRetry', fallback.unexpectedErrorRetry);

  @override
  String get unknown => OtaTranslationService.translate(locale, 'unknown', fallback.unknown);

  @override
  String get unlinkAccount => OtaTranslationService.translate(locale, 'unlinkAccount', fallback.unlinkAccount);

  @override
  String get untitledDraft => OtaTranslationService.translate(locale, 'untitledDraft', fallback.untitledDraft);

  @override
  String get user2 => OtaTranslationService.translate(locale, 'user2', fallback.user2);

  @override
  String get user3 => OtaTranslationService.translate(locale, 'user3', fallback.user3);

  @override
  String get userReLogin => OtaTranslationService.translate(locale, 'userReLogin', fallback.userReLogin);

  @override
  String get value => OtaTranslationService.translate(locale, 'value', fallback.value);

  @override
  String get valueRange => OtaTranslationService.translate(locale, 'valueRange', fallback.valueRange);

  @override
  String get valueRequired => OtaTranslationService.translate(locale, 'valueRequired', fallback.valueRequired);

  @override
  String get verify => OtaTranslationService.translate(locale, 'verify', fallback.verify);

  @override
  String get verifyEmailBeforeLogin => OtaTranslationService.translate(locale, 'verifyEmailBeforeLogin', fallback.verifyEmailBeforeLogin);

  @override
  String get video => OtaTranslationService.translate(locale, 'video', fallback.video);

  @override
  String get videoCallAndPhotoUpload => OtaTranslationService.translate(locale, 'videoCallAndPhotoUpload', fallback.videoCallAndPhotoUpload);

  @override
  String get voice => OtaTranslationService.translate(locale, 'voice', fallback.voice);

  @override
  String get voiceCallAndAudioRecording => OtaTranslationService.translate(locale, 'voiceCallAndAudioRecording', fallback.voiceCallAndAudioRecording);

  @override
  String get weakPassword => OtaTranslationService.translate(locale, 'weakPassword', fallback.weakPassword);

  @override
  String get web => OtaTranslationService.translate(locale, 'web', fallback.web);

  @override
  String get webBrowser => OtaTranslationService.translate(locale, 'webBrowser', fallback.webBrowser);

  @override
  String get wednesday => OtaTranslationService.translate(locale, 'wednesday', fallback.wednesday);

  @override
  String get welcomeMessage => OtaTranslationService.translate(locale, 'welcomeMessage', fallback.welcomeMessage);

  @override
  String get whoCanFollow => OtaTranslationService.translate(locale, 'whoCanFollow', fallback.whoCanFollow);

  @override
  String get wikiApprovalSuccess => OtaTranslationService.translate(locale, 'wikiApprovalSuccess', fallback.wikiApprovalSuccess);

  @override
  String get wikiApproved => OtaTranslationService.translate(locale, 'wikiApproved', fallback.wikiApproved);

  @override
  String get wikiApprovedStatus => OtaTranslationService.translate(locale, 'wikiApprovedStatus', fallback.wikiApprovedStatus);

  @override
  String get wikiNeedsChanges => OtaTranslationService.translate(locale, 'wikiNeedsChanges', fallback.wikiNeedsChanges);

  @override
  String get wikiPinned => OtaTranslationService.translate(locale, 'wikiPinned', fallback.wikiPinned);

  @override
  String get wikiRejected => OtaTranslationService.translate(locale, 'wikiRejected', fallback.wikiRejected);

  @override
  String get wikiRemoved => OtaTranslationService.translate(locale, 'wikiRemoved', fallback.wikiRemoved);

  @override
  String get wikiReview => OtaTranslationService.translate(locale, 'wikiReview', fallback.wikiReview);

  @override
  String get windows => OtaTranslationService.translate(locale, 'windows', fallback.windows);

  @override
  String get windowsVersion => OtaTranslationService.translate(locale, 'windowsVersion', fallback.windowsVersion);

  @override
  String get wise => OtaTranslationService.translate(locale, 'wise', fallback.wise);

  @override
  String get writeGuidelines => OtaTranslationService.translate(locale, 'writeGuidelines', fallback.writeGuidelines);

  @override
  String get writeGuidelinesTab => OtaTranslationService.translate(locale, 'writeGuidelinesTab', fallback.writeGuidelinesTab);

  @override
  String get writeWhatYouLike => OtaTranslationService.translate(locale, 'writeWhatYouLike', fallback.writeWhatYouLike);

  @override
  String get yourEntry => OtaTranslationService.translate(locale, 'yourEntry', fallback.yourEntry);

  @override
  String get yourStory => OtaTranslationService.translate(locale, 'yourStory', fallback.yourStory);

  @override
  String get acceptInvite => OtaTranslationService.translate(locale, 'acceptInvite', fallback.acceptInvite);

  @override
  String get accessibleByDirectLink => OtaTranslationService.translate(locale, 'accessibleByDirectLink', fallback.accessibleByDirectLink);

  @override
  String get actionExecutedSuccess => OtaTranslationService.translate(locale, 'actionExecutedSuccess', fallback.actionExecutedSuccess);

  @override
  String get actionLabel => OtaTranslationService.translate(locale, 'actionLabel', fallback.actionLabel);

  @override
  String get actionsLabel => OtaTranslationService.translate(locale, 'actionsLabel', fallback.actionsLabel);

  @override
  String get activeLabel2 => OtaTranslationService.translate(locale, 'activeLabel2', fallback.activeLabel2);

  @override
  String get adNotAvailable => OtaTranslationService.translate(locale, 'adNotAvailable', fallback.adNotAvailable);

  @override
  String get addAtLeastOneImage => OtaTranslationService.translate(locale, 'addAtLeastOneImage', fallback.addAtLeastOneImage);

  @override
  String get addAtLeastOneQuestion => OtaTranslationService.translate(locale, 'addAtLeastOneQuestion', fallback.addAtLeastOneQuestion);

  @override
  String get addedToFavorites => OtaTranslationService.translate(locale, 'addedToFavorites', fallback.addedToFavorites);

  @override
  String get adventurer => OtaTranslationService.translate(locale, 'adventurer', fallback.adventurer);

  @override
  String get alerts => OtaTranslationService.translate(locale, 'alerts', fallback.alerts);

  @override
  String get allowComments => OtaTranslationService.translate(locale, 'allowComments', fallback.allowComments);

  @override
  String get allowContentHighlight => OtaTranslationService.translate(locale, 'allowContentHighlight', fallback.allowContentHighlight);

  @override
  String get appearOfflineDesc => OtaTranslationService.translate(locale, 'appearOfflineDesc', fallback.appearOfflineDesc);

  @override
  String get apprentice => OtaTranslationService.translate(locale, 'apprentice', fallback.apprentice);

  @override
  String get askCommunity => OtaTranslationService.translate(locale, 'askCommunity', fallback.askCommunity);

  @override
  String get banUserFromCommunity => OtaTranslationService.translate(locale, 'banUserFromCommunity', fallback.banUserFromCommunity);

  @override
  String get bioInCommunity => OtaTranslationService.translate(locale, 'bioInCommunity', fallback.bioInCommunity);

  @override
  String get biography => OtaTranslationService.translate(locale, 'biography', fallback.biography);

  @override
  String get bubble => OtaTranslationService.translate(locale, 'bubble', fallback.bubble);

  @override
  String get bubbles => OtaTranslationService.translate(locale, 'bubbles', fallback.bubbles);

  @override
  String get cannotMessageUser => OtaTranslationService.translate(locale, 'cannotMessageUser', fallback.cannotMessageUser);

  @override
  String get centralButtonCreatePosts => OtaTranslationService.translate(locale, 'centralButtonCreatePosts', fallback.centralButtonCreatePosts);

  @override
  String get changeAction => OtaTranslationService.translate(locale, 'changeAction', fallback.changeAction);

  @override
  String get commentsBlocked => OtaTranslationService.translate(locale, 'commentsBlocked', fallback.commentsBlocked);

  @override
  String get communication => OtaTranslationService.translate(locale, 'communication', fallback.communication);

  @override
  String get communityPublicChatsTab => OtaTranslationService.translate(locale, 'communityPublicChatsTab', fallback.communityPublicChatsTab);

  @override
  String get completelyInvisible => OtaTranslationService.translate(locale, 'completelyInvisible', fallback.completelyInvisible);

  @override
  String get createNewPost => OtaTranslationService.translate(locale, 'createNewPost', fallback.createNewPost);

  @override
  String get currentLabel => OtaTranslationService.translate(locale, 'currentLabel', fallback.currentLabel);

  @override
  String get directMessage => OtaTranslationService.translate(locale, 'directMessage', fallback.directMessage);

  @override
  String get disableProfileComments => OtaTranslationService.translate(locale, 'disableProfileComments', fallback.disableProfileComments);

  @override
  String get downloadYourData => OtaTranslationService.translate(locale, 'downloadYourData', fallback.downloadYourData);

  @override
  String get earlyAccess => OtaTranslationService.translate(locale, 'earlyAccess', fallback.earlyAccess);

  @override
  String get earnCoinsLevelUp => OtaTranslationService.translate(locale, 'earnCoinsLevelUp', fallback.earnCoinsLevelUp);

  @override
  String get exclusiveBadge => OtaTranslationService.translate(locale, 'exclusiveBadge', fallback.exclusiveBadge);

  @override
  String get featuredPostsTab => OtaTranslationService.translate(locale, 'featuredPostsTab', fallback.featuredPostsTab);

  @override
  String get feedEmpty => OtaTranslationService.translate(locale, 'feedEmpty', fallback.feedEmpty);

  @override
  String get fillTitleOrContent => OtaTranslationService.translate(locale, 'fillTitleOrContent', fallback.fillTitleOrContent);

  @override
  String get forwardTo => OtaTranslationService.translate(locale, 'forwardTo', fallback.forwardTo);

  @override
  String get forwarded => OtaTranslationService.translate(locale, 'forwarded', fallback.forwarded);

  @override
  String get freeUpStorage => OtaTranslationService.translate(locale, 'freeUpStorage', fallback.freeUpStorage);

  @override
  String get frenchLang => OtaTranslationService.translate(locale, 'frenchLang', fallback.frenchLang);

  @override
  String get friendsOnly => OtaTranslationService.translate(locale, 'friendsOnly', fallback.friendsOnly);

  @override
  String get fromFriendsOnly => OtaTranslationService.translate(locale, 'fromFriendsOnly', fallback.fromFriendsOnly);

  @override
  String get getCommunityQuizzes => OtaTranslationService.translate(locale, 'getCommunityQuizzes', fallback.getCommunityQuizzes);

  @override
  String get informActionReason => OtaTranslationService.translate(locale, 'informActionReason', fallback.informActionReason);

  @override
  String get invalidData => OtaTranslationService.translate(locale, 'invalidData', fallback.invalidData);

  @override
  String get joinDiscussions => OtaTranslationService.translate(locale, 'joinDiscussions', fallback.joinDiscussions);

  @override
  String get layoutResetToDefault => OtaTranslationService.translate(locale, 'layoutResetToDefault', fallback.layoutResetToDefault);

  @override
  String get legendary => OtaTranslationService.translate(locale, 'legendary', fallback.legendary);

  @override
  String get mentions => OtaTranslationService.translate(locale, 'mentions', fallback.mentions);

  @override
  String get moderationActionLabel => OtaTranslationService.translate(locale, 'moderationActionLabel', fallback.moderationActionLabel);

  @override
  String get moderationWarning => OtaTranslationService.translate(locale, 'moderationWarning', fallback.moderationWarning);

  @override
  String get mythical => OtaTranslationService.translate(locale, 'mythical', fallback.mythical);

  @override
  String get nameRequired => OtaTranslationService.translate(locale, 'nameRequired', fallback.nameRequired);

  @override
  String get newMembersNeedApproval => OtaTranslationService.translate(locale, 'newMembersNeedApproval', fallback.newMembersNeedApproval);

  @override
  String get noAchievementsAvailable => OtaTranslationService.translate(locale, 'noAchievementsAvailable', fallback.noAchievementsAvailable);

  @override
  String get noAds => OtaTranslationService.translate(locale, 'noAds', fallback.noAds);

  @override
  String get noChatFound => OtaTranslationService.translate(locale, 'noChatFound', fallback.noChatFound);

  @override
  String get noComments => OtaTranslationService.translate(locale, 'noComments', fallback.noComments);

  @override
  String get noConnections => OtaTranslationService.translate(locale, 'noConnections', fallback.noConnections);

  @override
  String get noModerationActions => OtaTranslationService.translate(locale, 'noModerationActions', fallback.noModerationActions);

  @override
  String get noOneCanCommentWall => OtaTranslationService.translate(locale, 'noOneCanCommentWall', fallback.noOneCanCommentWall);

  @override
  String get noSectionsEnabled => OtaTranslationService.translate(locale, 'noSectionsEnabled', fallback.noSectionsEnabled);

  @override
  String get noTransactionsYet => OtaTranslationService.translate(locale, 'noTransactionsYet', fallback.noTransactionsYet);

  @override
  String get noUserFound => OtaTranslationService.translate(locale, 'noUserFound', fallback.noUserFound);

  @override
  String get noWallComments => OtaTranslationService.translate(locale, 'noWallComments', fallback.noWallComments);

  @override
  String get notAuthenticated => OtaTranslationService.translate(locale, 'notAuthenticated', fallback.notAuthenticated);

  @override
  String get notLinked => OtaTranslationService.translate(locale, 'notLinked', fallback.notLinked);

  @override
  String get notificationLabel => OtaTranslationService.translate(locale, 'notificationLabel', fallback.notificationLabel);

  @override
  String get notificationSoundsInApp => OtaTranslationService.translate(locale, 'notificationSoundsInApp', fallback.notificationSoundsInApp);

  @override
  String get offersNotAvailable => OtaTranslationService.translate(locale, 'offersNotAvailable', fallback.offersNotAvailable);

  @override
  String get onlyInvitedMembers => OtaTranslationService.translate(locale, 'onlyInvitedMembers', fallback.onlyInvitedMembers);

  @override
  String get optionsLabel => OtaTranslationService.translate(locale, 'optionsLabel', fallback.optionsLabel);

  @override
  String get packageNotFound => OtaTranslationService.translate(locale, 'packageNotFound', fallback.packageNotFound);

  @override
  String get pauseNotifications => OtaTranslationService.translate(locale, 'pauseNotifications', fallback.pauseNotifications);

  @override
  String get pollQuestionRequired => OtaTranslationService.translate(locale, 'pollQuestionRequired', fallback.pollQuestionRequired);

  @override
  String get portugueseLang => OtaTranslationService.translate(locale, 'portugueseLang', fallback.portugueseLang);

  @override
  String get postDraftsAppearHere => OtaTranslationService.translate(locale, 'postDraftsAppearHere', fallback.postDraftsAppearHere);

  @override
  String get postNotFoundOrNoPermission => OtaTranslationService.translate(locale, 'postNotFoundOrNoPermission', fallback.postNotFoundOrNoPermission);

  @override
  String get preventNewUsersConversations => OtaTranslationService.translate(locale, 'preventNewUsersConversations', fallback.preventNewUsersConversations);

  @override
  String get projection => OtaTranslationService.translate(locale, 'projection', fallback.projection);

  @override
  String get publicLabel => OtaTranslationService.translate(locale, 'publicLabel', fallback.publicLabel);

  @override
  String get publishContentCommunity => OtaTranslationService.translate(locale, 'publishContentCommunity', fallback.publishContentCommunity);

  @override
  String get questionRequired => OtaTranslationService.translate(locale, 'questionRequired', fallback.questionRequired);

  @override
  String get quizTitleRequired => OtaTranslationService.translate(locale, 'quizTitleRequired', fallback.quizTitleRequired);

  @override
  String get recentPostsTab => OtaTranslationService.translate(locale, 'recentPostsTab', fallback.recentPostsTab);

  @override
  String get recentSearches => OtaTranslationService.translate(locale, 'recentSearches', fallback.recentSearches);

  @override
  String get recognizeMember => OtaTranslationService.translate(locale, 'recognizeMember', fallback.recognizeMember);

  @override
  String get removeUserBan => OtaTranslationService.translate(locale, 'removeUserBan', fallback.removeUserBan);

  @override
  String get reportsLabel => OtaTranslationService.translate(locale, 'reportsLabel', fallback.reportsLabel);

  @override
  String get requiredField => OtaTranslationService.translate(locale, 'requiredField', fallback.requiredField);

  @override
  String get searchCommunityMembers => OtaTranslationService.translate(locale, 'searchCommunityMembers', fallback.searchCommunityMembers);

  @override
  String get searchWikiArticles => OtaTranslationService.translate(locale, 'searchWikiArticles', fallback.searchWikiArticles);

  @override
  String get selectReportReason => OtaTranslationService.translate(locale, 'selectReportReason', fallback.selectReportReason);

  @override
  String get selectReportType => OtaTranslationService.translate(locale, 'selectReportType', fallback.selectReportType);

  @override
  String get sendMessageToAll => OtaTranslationService.translate(locale, 'sendMessageToAll', fallback.sendMessageToAll);

  @override
  String get sharedProfile => OtaTranslationService.translate(locale, 'sharedProfile', fallback.sharedProfile);

  @override
  String get showWhenOnline => OtaTranslationService.translate(locale, 'showWhenOnline', fallback.showWhenOnline);

  @override
  String get someone => OtaTranslationService.translate(locale, 'someone', fallback.someone);

  @override
  String get spanishLang => OtaTranslationService.translate(locale, 'spanishLang', fallback.spanishLang);

  @override
  String get subscribe => OtaTranslationService.translate(locale, 'subscribe', fallback.subscribe);

  @override
  String get subscriptions => OtaTranslationService.translate(locale, 'subscriptions', fallback.subscriptions);

  @override
  String get tapToDownload => OtaTranslationService.translate(locale, 'tapToDownload', fallback.tapToDownload);

  @override
  String get topicCategories => OtaTranslationService.translate(locale, 'topicCategories', fallback.topicCategories);

  @override
  String get uniqueIdentifier => OtaTranslationService.translate(locale, 'uniqueIdentifier', fallback.uniqueIdentifier);

  @override
  String get unpinPost => OtaTranslationService.translate(locale, 'unpinPost', fallback.unpinPost);

  @override
  String get userNotAuthenticated => OtaTranslationService.translate(locale, 'userNotAuthenticated', fallback.userNotAuthenticated);

  @override
  String get usersLabel => OtaTranslationService.translate(locale, 'usersLabel', fallback.usersLabel);

  @override
  String get vibrateOnNotifications => OtaTranslationService.translate(locale, 'vibrateOnNotifications', fallback.vibrateOnNotifications);

  @override
  String get vibration => OtaTranslationService.translate(locale, 'vibration', fallback.vibration);

  @override
  String get videoLabel => OtaTranslationService.translate(locale, 'videoLabel', fallback.videoLabel);

  @override
  String get watchAction => OtaTranslationService.translate(locale, 'watchAction', fallback.watchAction);

  @override
  String get whenLevelUp => OtaTranslationService.translate(locale, 'whenLevelUp', fallback.whenLevelUp);

  @override
  String get whenSomeoneComments => OtaTranslationService.translate(locale, 'whenSomeoneComments', fallback.whenSomeoneComments);

  @override
  String get whenSomeoneFollows => OtaTranslationService.translate(locale, 'whenSomeoneFollows', fallback.whenSomeoneFollows);

  @override
  String get whenSomeoneLikes => OtaTranslationService.translate(locale, 'whenSomeoneLikes', fallback.whenSomeoneLikes);

  @override
  String get whenSomeoneMentions => OtaTranslationService.translate(locale, 'whenSomeoneMentions', fallback.whenSomeoneMentions);

  @override
  String get acceptInviteAction => OtaTranslationService.translate(locale, 'acceptInviteAction', fallback.acceptInviteAction);

  @override
  String get acceptTermsAndPrivacy => OtaTranslationService.translate(locale, 'acceptTermsAndPrivacy', fallback.acceptTermsAndPrivacy);

  @override
  String get accessibleByDirectLinkDesc => OtaTranslationService.translate(locale, 'accessibleByDirectLinkDesc', fallback.accessibleByDirectLinkDesc);

  @override
  String get actionAlreadyPerformed => OtaTranslationService.translate(locale, 'actionAlreadyPerformed', fallback.actionAlreadyPerformed);

  @override
  String get actionCannotBeUndone => OtaTranslationService.translate(locale, 'actionCannotBeUndone', fallback.actionCannotBeUndone);

  @override
  String get actionLabelGeneral => OtaTranslationService.translate(locale, 'actionLabelGeneral', fallback.actionLabelGeneral);

  @override
  String get actionType => OtaTranslationService.translate(locale, 'actionType', fallback.actionType);

  @override
  String get actionsLabelGeneral => OtaTranslationService.translate(locale, 'actionsLabelGeneral', fallback.actionsLabelGeneral);

  @override
  String get activeLabelFem => OtaTranslationService.translate(locale, 'activeLabelFem', fallback.activeLabelFem);

  @override
  String get activeModules => OtaTranslationService.translate(locale, 'activeModules', fallback.activeModules);

  @override
  String get adNotAvailableMsg => OtaTranslationService.translate(locale, 'adNotAvailableMsg', fallback.adNotAvailableMsg);

  @override
  String get addAtLeast2Options => OtaTranslationService.translate(locale, 'addAtLeast2Options', fallback.addAtLeast2Options);

  @override
  String get addAtLeastOneImageMsg => OtaTranslationService.translate(locale, 'addAtLeastOneImageMsg', fallback.addAtLeastOneImageMsg);

  @override
  String get addAtLeastOneQuestionMsg => OtaTranslationService.translate(locale, 'addAtLeastOneQuestionMsg', fallback.addAtLeastOneQuestionMsg);

  @override
  String get addBioDesc => OtaTranslationService.translate(locale, 'addBioDesc', fallback.addBioDesc);

  @override
  String get addMusicAction => OtaTranslationService.translate(locale, 'addMusicAction', fallback.addMusicAction);

  @override
  String get addOptionLabel => OtaTranslationService.translate(locale, 'addOptionLabel', fallback.addOptionLabel);

  @override
  String get addUsefulLinks => OtaTranslationService.translate(locale, 'addUsefulLinks', fallback.addUsefulLinks);

  @override
  String get addVideoAction => OtaTranslationService.translate(locale, 'addVideoAction', fallback.addVideoAction);

  @override
  String get addedToFavoritesMsg => OtaTranslationService.translate(locale, 'addedToFavoritesMsg', fallback.addedToFavoritesMsg);

  @override
  String get advancedOptions => OtaTranslationService.translate(locale, 'advancedOptions', fallback.advancedOptions);

  @override
  String get adventurerLabel => OtaTranslationService.translate(locale, 'adventurerLabel', fallback.adventurerLabel);

  @override
  String get agreeTermsAndPrivacy => OtaTranslationService.translate(locale, 'agreeTermsAndPrivacy', fallback.agreeTermsAndPrivacy);

  @override
  String get alertsLabel => OtaTranslationService.translate(locale, 'alertsLabel', fallback.alertsLabel);

  @override
  String get allowCommentsLabel => OtaTranslationService.translate(locale, 'allowCommentsLabel', fallback.allowCommentsLabel);

  @override
  String get allowContentHighlightSetting => OtaTranslationService.translate(locale, 'allowContentHighlightSetting', fallback.allowContentHighlightSetting);

  @override
  String get alreadyCheckedInCommunity => OtaTranslationService.translate(locale, 'alreadyCheckedInCommunity', fallback.alreadyCheckedInCommunity);

  @override
  String get alreadyCheckedInToday => OtaTranslationService.translate(locale, 'alreadyCheckedInToday', fallback.alreadyCheckedInToday);

  @override
  String get alreadyHaveAccountQuestion => OtaTranslationService.translate(locale, 'alreadyHaveAccountQuestion', fallback.alreadyHaveAccountQuestion);

  @override
  String get alreadyInCommunity => OtaTranslationService.translate(locale, 'alreadyInCommunity', fallback.alreadyInCommunity);

  @override
  String get alreadyMemberCommunity => OtaTranslationService.translate(locale, 'alreadyMemberCommunity', fallback.alreadyMemberCommunity);

  @override
  String get appearOfflineAllUsers => OtaTranslationService.translate(locale, 'appearOfflineAllUsers', fallback.appearOfflineAllUsers);

  @override
  String get applyStrikeDesc => OtaTranslationService.translate(locale, 'applyStrikeDesc', fallback.applyStrikeDesc);

  @override
  String get apprenticeLabel => OtaTranslationService.translate(locale, 'apprenticeLabel', fallback.apprenticeLabel);

  @override
  String get artTheftPlagiarism => OtaTranslationService.translate(locale, 'artTheftPlagiarism', fallback.artTheftPlagiarism);

  @override
  String get askCommunityHint => OtaTranslationService.translate(locale, 'askCommunityHint', fallback.askCommunityHint);

  @override
  String get audioFileUrl => OtaTranslationService.translate(locale, 'audioFileUrl', fallback.audioFileUrl);

  @override
  String get banUserDesc => OtaTranslationService.translate(locale, 'banUserDesc', fallback.banUserDesc);

  @override
  String get bestCommunitiesForYou => OtaTranslationService.translate(locale, 'bestCommunitiesForYou', fallback.bestCommunitiesForYou);

  @override
  String get bestValue => OtaTranslationService.translate(locale, 'bestValue', fallback.bestValue);

  @override
  String get betterLuckNextTime => OtaTranslationService.translate(locale, 'betterLuckNextTime', fallback.betterLuckNextTime);

  @override
  String get bioInCommunityLabel => OtaTranslationService.translate(locale, 'bioInCommunityLabel', fallback.bioInCommunityLabel);

  @override
  String get biographyLabel => OtaTranslationService.translate(locale, 'biographyLabel', fallback.biographyLabel);

  @override
  String get blockedUsersCannotSeeProfile => OtaTranslationService.translate(locale, 'blockedUsersCannotSeeProfile', fallback.blockedUsersCannotSeeProfile);

  @override
  String get blogTitleHint => OtaTranslationService.translate(locale, 'blogTitleHint', fallback.blogTitleHint);

  @override
  String get bubbleLabel => OtaTranslationService.translate(locale, 'bubbleLabel', fallback.bubbleLabel);

  @override
  String get bubblesLabel => OtaTranslationService.translate(locale, 'bubblesLabel', fallback.bubblesLabel);

  @override
  String get bullyingHarassment => OtaTranslationService.translate(locale, 'bullyingHarassment', fallback.bullyingHarassment);

  @override
  String get cameraPermissionsDesc => OtaTranslationService.translate(locale, 'cameraPermissionsDesc', fallback.cameraPermissionsDesc);

  @override
  String get cannotDmYourself => OtaTranslationService.translate(locale, 'cannotDmYourself', fallback.cannotDmYourself);

  @override
  String get cannotMessageUserMsg => OtaTranslationService.translate(locale, 'cannotMessageUserMsg', fallback.cannotMessageUserMsg);

  @override
  String get centralButtonDesc => OtaTranslationService.translate(locale, 'centralButtonDesc', fallback.centralButtonDesc);

  @override
  String get changeLabel => OtaTranslationService.translate(locale, 'changeLabel', fallback.changeLabel);

  @override
  String get chatDeletedMsg => OtaTranslationService.translate(locale, 'chatDeletedMsg', fallback.chatDeletedMsg);

  @override
  String get chatSettingsTitle => OtaTranslationService.translate(locale, 'chatSettingsTitle', fallback.chatSettingsTitle);

  @override
  String get checkInComplete => OtaTranslationService.translate(locale, 'checkInComplete', fallback.checkInComplete);

  @override
  String get checkInEarnReputation => OtaTranslationService.translate(locale, 'checkInEarnReputation', fallback.checkInEarnReputation);

  @override
  String get checkInEveryDay => OtaTranslationService.translate(locale, 'checkInEveryDay', fallback.checkInEveryDay);

  @override
  String get checkInForRewards => OtaTranslationService.translate(locale, 'checkInForRewards', fallback.checkInForRewards);

  @override
  String get checkInKeepStreak => OtaTranslationService.translate(locale, 'checkInKeepStreak', fallback.checkInKeepStreak);

  @override
  String get chooseSections => OtaTranslationService.translate(locale, 'chooseSections', fallback.chooseSections);

  @override
  String get chooseSomethingMemorable => OtaTranslationService.translate(locale, 'chooseSomethingMemorable', fallback.chooseSomethingMemorable);

  @override
  String get clearTempDataDesc => OtaTranslationService.translate(locale, 'clearTempDataDesc', fallback.clearTempDataDesc);

  @override
  String get communicationLabel => OtaTranslationService.translate(locale, 'communicationLabel', fallback.communicationLabel);

  @override
  String get communityIcon => OtaTranslationService.translate(locale, 'communityIcon', fallback.communityIcon);

  @override
  String get communityNotFound => OtaTranslationService.translate(locale, 'communityNotFound', fallback.communityNotFound);

  @override
  String get communityPublicChatsTabDesc => OtaTranslationService.translate(locale, 'communityPublicChatsTabDesc', fallback.communityPublicChatsTabDesc);

  @override
  String get communityStatistics => OtaTranslationService.translate(locale, 'communityStatistics', fallback.communityStatistics);

  @override
  String get communityUpdates => OtaTranslationService.translate(locale, 'communityUpdates', fallback.communityUpdates);

  @override
  String get completelyInvisibleDesc => OtaTranslationService.translate(locale, 'completelyInvisibleDesc', fallback.completelyInvisibleDesc);

  @override
  String get configureBottomNav => OtaTranslationService.translate(locale, 'configureBottomNav', fallback.configureBottomNav);

  @override
  String get confirmDeleteChat => OtaTranslationService.translate(locale, 'confirmDeleteChat', fallback.confirmDeleteChat);

  @override
  String get confirmDeleteChat2 => OtaTranslationService.translate(locale, 'confirmDeleteChat2', fallback.confirmDeleteChat2);

  @override
  String get confirmDeletePost => OtaTranslationService.translate(locale, 'confirmDeletePost', fallback.confirmDeletePost);

  @override
  String get connectedWithCommunities => OtaTranslationService.translate(locale, 'connectedWithCommunities', fallback.connectedWithCommunities);

  @override
  String get connectionsLabelGeneral => OtaTranslationService.translate(locale, 'connectionsLabelGeneral', fallback.connectionsLabelGeneral);

  @override
  String get consecutiveDaysBonus => OtaTranslationService.translate(locale, 'consecutiveDaysBonus', fallback.consecutiveDaysBonus);

  @override
  String get contentCannotBeEmpty => OtaTranslationService.translate(locale, 'contentCannotBeEmpty', fallback.contentCannotBeEmpty);

  @override
  String get conversationRemovedFromList => OtaTranslationService.translate(locale, 'conversationRemovedFromList', fallback.conversationRemovedFromList);

  @override
  String get couldNotAcceptInvite => OtaTranslationService.translate(locale, 'couldNotAcceptInvite', fallback.couldNotAcceptInvite);

  @override
  String get couldNotConfirmParticipation => OtaTranslationService.translate(locale, 'couldNotConfirmParticipation', fallback.couldNotConfirmParticipation);

  @override
  String get couldNotProcessSubscription => OtaTranslationService.translate(locale, 'couldNotProcessSubscription', fallback.couldNotProcessSubscription);

  @override
  String get createNewPostLabel => OtaTranslationService.translate(locale, 'createNewPostLabel', fallback.createNewPostLabel);

  @override
  String get currentConfiguration => OtaTranslationService.translate(locale, 'currentConfiguration', fallback.currentConfiguration);

  @override
  String get currentLabelGeneral => OtaTranslationService.translate(locale, 'currentLabelGeneral', fallback.currentLabelGeneral);

  @override
  String get dailyActivities => OtaTranslationService.translate(locale, 'dailyActivities', fallback.dailyActivities);

  @override
  String get dailyAdLimitReached => OtaTranslationService.translate(locale, 'dailyAdLimitReached', fallback.dailyAdLimitReached);

  @override
  String get dailyCheckIn2 => OtaTranslationService.translate(locale, 'dailyCheckIn2', fallback.dailyCheckIn2);

  @override
  String get dailyCheckInBarDesc => OtaTranslationService.translate(locale, 'dailyCheckInBarDesc', fallback.dailyCheckInBarDesc);

  @override
  String get describeActionReason => OtaTranslationService.translate(locale, 'describeActionReason', fallback.describeActionReason);

  @override
  String get disableProfileCommentsSetting => OtaTranslationService.translate(locale, 'disableProfileCommentsSetting', fallback.disableProfileCommentsSetting);

  @override
  String get discussionsAndDebates => OtaTranslationService.translate(locale, 'discussionsAndDebates', fallback.discussionsAndDebates);

  @override
  String get doNotDisturb => OtaTranslationService.translate(locale, 'doNotDisturb', fallback.doNotDisturb);

  @override
  String get doesNotAcceptDMs => OtaTranslationService.translate(locale, 'doesNotAcceptDMs', fallback.doesNotAcceptDMs);

  @override
  String get dontHaveAccount2 => OtaTranslationService.translate(locale, 'dontHaveAccount2', fallback.dontHaveAccount2);

  @override
  String get downloadDataDesc => OtaTranslationService.translate(locale, 'downloadDataDesc', fallback.downloadDataDesc);

  @override
  String get earlyAccessDesc => OtaTranslationService.translate(locale, 'earlyAccessDesc', fallback.earlyAccessDesc);

  @override
  String get earnCoinsLevelUpDesc => OtaTranslationService.translate(locale, 'earnCoinsLevelUpDesc', fallback.earnCoinsLevelUpDesc);

  @override
  String get emptyFieldsGlobal => OtaTranslationService.translate(locale, 'emptyFieldsGlobal', fallback.emptyFieldsGlobal);

  @override
  String get enableWikiCatalog => OtaTranslationService.translate(locale, 'enableWikiCatalog', fallback.enableWikiCatalog);

  @override
  String get enterValidLink => OtaTranslationService.translate(locale, 'enterValidLink', fallback.enterValidLink);

  @override
  String get errorChangingPin => OtaTranslationService.translate(locale, 'errorChangingPin', fallback.errorChangingPin);

  @override
  String get errorExecutingActionRetry => OtaTranslationService.translate(locale, 'errorExecutingActionRetry', fallback.errorExecutingActionRetry);

  @override
  String get errorLoadingAd => OtaTranslationService.translate(locale, 'errorLoadingAd', fallback.errorLoadingAd);

  @override
  String get exclusiveBadgeDesc => OtaTranslationService.translate(locale, 'exclusiveBadgeDesc', fallback.exclusiveBadgeDesc);

  @override
  String get executeAction2 => OtaTranslationService.translate(locale, 'executeAction2', fallback.executeAction2);

  @override
  String get exploreCommunities => OtaTranslationService.translate(locale, 'exploreCommunities', fallback.exploreCommunities);

  @override
  String get featureTemporarilyUnavailable => OtaTranslationService.translate(locale, 'featureTemporarilyUnavailable', fallback.featureTemporarilyUnavailable);

  @override
  String get featuredPostsTabDesc => OtaTranslationService.translate(locale, 'featuredPostsTabDesc', fallback.featuredPostsTabDesc);

  @override
  String get feedEmptyMsg => OtaTranslationService.translate(locale, 'feedEmptyMsg', fallback.feedEmptyMsg);

  @override
  String get fileNotFoundMsg => OtaTranslationService.translate(locale, 'fileNotFoundMsg', fallback.fileNotFoundMsg);

  @override
  String get fileTypeNotAllowed => OtaTranslationService.translate(locale, 'fileTypeNotAllowed', fallback.fileTypeNotAllowed);

  @override
  String get fillTitleAndUrl => OtaTranslationService.translate(locale, 'fillTitleAndUrl', fallback.fillTitleAndUrl);

  @override
  String get fillTitleOrContentMsg => OtaTranslationService.translate(locale, 'fillTitleOrContentMsg', fallback.fillTitleOrContentMsg);

  @override
  String get freeCoinsMonth => OtaTranslationService.translate(locale, 'freeCoinsMonth', fallback.freeCoinsMonth);

  @override
  String get freeUpStorageDesc => OtaTranslationService.translate(locale, 'freeUpStorageDesc', fallback.freeUpStorageDesc);

  @override
  String get friendsOnlyLabel => OtaTranslationService.translate(locale, 'friendsOnlyLabel', fallback.friendsOnlyLabel);

  @override
  String get fromFriendsOnlyLabel => OtaTranslationService.translate(locale, 'fromFriendsOnlyLabel', fallback.fromFriendsOnlyLabel);

  @override
  String get galleryVideo => OtaTranslationService.translate(locale, 'galleryVideo', fallback.galleryVideo);

  @override
  String get generalNotifications => OtaTranslationService.translate(locale, 'generalNotifications', fallback.generalNotifications);

  @override
  String get getCommunityQuizzesDesc => OtaTranslationService.translate(locale, 'getCommunityQuizzesDesc', fallback.getCommunityQuizzesDesc);

  @override
  String get hidePostDesc => OtaTranslationService.translate(locale, 'hidePostDesc', fallback.hidePostDesc);

  @override
  String get higherStreakDesc => OtaTranslationService.translate(locale, 'higherStreakDesc', fallback.higherStreakDesc);

  @override
  String get highlightDuration => OtaTranslationService.translate(locale, 'highlightDuration', fallback.highlightDuration);

  @override
  String get homePageSections => OtaTranslationService.translate(locale, 'homePageSections', fallback.homePageSections);

  @override
  String get iconImageUrl => OtaTranslationService.translate(locale, 'iconImageUrl', fallback.iconImageUrl);

  @override
  String get identityFraud => OtaTranslationService.translate(locale, 'identityFraud', fallback.identityFraud);

  @override
  String get informActionReasonLabel => OtaTranslationService.translate(locale, 'informActionReasonLabel', fallback.informActionReasonLabel);

  @override
  String get interactionsAppearHere => OtaTranslationService.translate(locale, 'interactionsAppearHere', fallback.interactionsAppearHere);

  @override
  String get invalidDataMsg => OtaTranslationService.translate(locale, 'invalidDataMsg', fallback.invalidDataMsg);

  @override
  String get invalidReference => OtaTranslationService.translate(locale, 'invalidReference', fallback.invalidReference);

  @override
  String get invalidValue => OtaTranslationService.translate(locale, 'invalidValue', fallback.invalidValue);

  @override
  String get inviteInvalidOrExpired => OtaTranslationService.translate(locale, 'inviteInvalidOrExpired', fallback.inviteInvalidOrExpired);

  @override
  String get itemAlreadyExists => OtaTranslationService.translate(locale, 'itemAlreadyExists', fallback.itemAlreadyExists);

  @override
  String get joinDiscussionsDesc => OtaTranslationService.translate(locale, 'joinDiscussionsDesc', fallback.joinDiscussionsDesc);

  @override
  String get joinedChat => OtaTranslationService.translate(locale, 'joinedChat', fallback.joinedChat);

  @override
  String get joinedCommunity => OtaTranslationService.translate(locale, 'joinedCommunity', fallback.joinedCommunity);

  @override
  String get layoutResetMsg => OtaTranslationService.translate(locale, 'layoutResetMsg', fallback.layoutResetMsg);

  @override
  String get leftChat => OtaTranslationService.translate(locale, 'leftChat', fallback.leftChat);

  @override
  String get leftGroup => OtaTranslationService.translate(locale, 'leftGroup', fallback.leftGroup);

  @override
  String get legendaryLabel => OtaTranslationService.translate(locale, 'legendaryLabel', fallback.legendaryLabel);

  @override
  String get letsGo => OtaTranslationService.translate(locale, 'letsGo', fallback.letsGo);

  @override
  String get levelUpAction => OtaTranslationService.translate(locale, 'levelUpAction', fallback.levelUpAction);

  @override
  String get leveledUp => OtaTranslationService.translate(locale, 'leveledUp', fallback.leveledUp);

  @override
  String get likesCommentsFollowers => OtaTranslationService.translate(locale, 'likesCommentsFollowers', fallback.likesCommentsFollowers);

  @override
  String get linksInGeneralSection => OtaTranslationService.translate(locale, 'linksInGeneralSection', fallback.linksInGeneralSection);

  @override
  String get loginToAcceptInvite => OtaTranslationService.translate(locale, 'loginToAcceptInvite', fallback.loginToAcceptInvite);

  @override
  String get max10000Chars => OtaTranslationService.translate(locale, 'max10000Chars', fallback.max10000Chars);

  @override
  String get max24Chars => OtaTranslationService.translate(locale, 'max24Chars', fallback.max24Chars);

  @override
  String get max30Chars => OtaTranslationService.translate(locale, 'max30Chars', fallback.max30Chars);

  @override
  String get max500Chars => OtaTranslationService.translate(locale, 'max500Chars', fallback.max500Chars);

  @override
  String get mentionsLabel => OtaTranslationService.translate(locale, 'mentionsLabel', fallback.mentionsLabel);

  @override
  String get messageToAllMembers => OtaTranslationService.translate(locale, 'messageToAllMembers', fallback.messageToAllMembers);

  @override
  String get min3Chars => OtaTranslationService.translate(locale, 'min3Chars', fallback.min3Chars);

  @override
  String get moderationActionLower => OtaTranslationService.translate(locale, 'moderationActionLower', fallback.moderationActionLower);

  @override
  String get moderationActionTitle => OtaTranslationService.translate(locale, 'moderationActionTitle', fallback.moderationActionTitle);

  @override
  String get moderationActionsTitle => OtaTranslationService.translate(locale, 'moderationActionsTitle', fallback.moderationActionsTitle);

  @override
  String get moderationAlerts => OtaTranslationService.translate(locale, 'moderationAlerts', fallback.moderationAlerts);

  @override
  String get moderationLabel => OtaTranslationService.translate(locale, 'moderationLabel', fallback.moderationLabel);

  @override
  String get moderationWarningLabel => OtaTranslationService.translate(locale, 'moderationWarningLabel', fallback.moderationWarningLabel);

  @override
  String get musicAddedToPost => OtaTranslationService.translate(locale, 'musicAddedToPost', fallback.musicAddedToPost);

  @override
  String get musicRecommendations => OtaTranslationService.translate(locale, 'musicRecommendations', fallback.musicRecommendations);

  @override
  String get mythicalLabel => OtaTranslationService.translate(locale, 'mythicalLabel', fallback.mythicalLabel);

  @override
  String get nameLinkOptional => OtaTranslationService.translate(locale, 'nameLinkOptional', fallback.nameLinkOptional);

  @override
  String get nameRequiredMsg => OtaTranslationService.translate(locale, 'nameRequiredMsg', fallback.nameRequiredMsg);

  @override
  String get needLoginToComment => OtaTranslationService.translate(locale, 'needLoginToComment', fallback.needLoginToComment);

  @override
  String get needLoginToCreateCommunity => OtaTranslationService.translate(locale, 'needLoginToCreateCommunity', fallback.needLoginToCreateCommunity);

  @override
  String get needNewInvite => OtaTranslationService.translate(locale, 'needNewInvite', fallback.needNewInvite);

  @override
  String get needToBeLoggedIn => OtaTranslationService.translate(locale, 'needToBeLoggedIn', fallback.needToBeLoggedIn);

  @override
  String get newMembersNeedApprovalDesc => OtaTranslationService.translate(locale, 'newMembersNeedApprovalDesc', fallback.newMembersNeedApprovalDesc);

  @override
  String get newMessageNotifications => OtaTranslationService.translate(locale, 'newMessageNotifications', fallback.newMessageNotifications);

  @override
  String get nextPost => OtaTranslationService.translate(locale, 'nextPost', fallback.nextPost);

  @override
  String get noAchievementsAvailableMsg => OtaTranslationService.translate(locale, 'noAchievementsAvailableMsg', fallback.noAchievementsAvailableMsg);

  @override
  String get noAdsLabel => OtaTranslationService.translate(locale, 'noAdsLabel', fallback.noAdsLabel);

  @override
  String get noChatsJoinedYet => OtaTranslationService.translate(locale, 'noChatsJoinedYet', fallback.noChatsJoinedYet);

  @override
  String get noCommentsLabel => OtaTranslationService.translate(locale, 'noCommentsLabel', fallback.noCommentsLabel);

  @override
  String get noConnectionsMsg => OtaTranslationService.translate(locale, 'noConnectionsMsg', fallback.noConnectionsMsg);

  @override
  String get noContentYet => OtaTranslationService.translate(locale, 'noContentYet', fallback.noContentYet);

  @override
  String get noModerationActionsMsg => OtaTranslationService.translate(locale, 'noModerationActionsMsg', fallback.noModerationActionsMsg);

  @override
  String get noOneCanCommentWallDesc => OtaTranslationService.translate(locale, 'noOneCanCommentWallDesc', fallback.noOneCanCommentWallDesc);

  @override
  String get noPermissionEditPost => OtaTranslationService.translate(locale, 'noPermissionEditPost', fallback.noPermissionEditPost);

  @override
  String get noPublicChatsYet => OtaTranslationService.translate(locale, 'noPublicChatsYet', fallback.noPublicChatsYet);

  @override
  String get noGuidelinesYet => OtaTranslationService.translate(locale, 'noGuidelinesYet', fallback.noGuidelinesYet);

  @override
  String get noPublicChatsYetShort => OtaTranslationService.translate(locale, 'noPublicChatsYetShort', fallback.noPublicChatsYetShort);

  @override
  String get noSectionsEnabledMsg => OtaTranslationService.translate(locale, 'noSectionsEnabledMsg', fallback.noSectionsEnabledMsg);

  @override
  String get noTransactionsYetMsg => OtaTranslationService.translate(locale, 'noTransactionsYetMsg', fallback.noTransactionsYetMsg);

  @override
  String get noUploadPermission => OtaTranslationService.translate(locale, 'noUploadPermission', fallback.noUploadPermission);

  @override
  String get noUserFoundMsg => OtaTranslationService.translate(locale, 'noUserFoundMsg', fallback.noUserFoundMsg);

  @override
  String get noWallCommentsMsg => OtaTranslationService.translate(locale, 'noWallCommentsMsg', fallback.noWallCommentsMsg);

  @override
  String get notAuthenticatedMsg => OtaTranslationService.translate(locale, 'notAuthenticatedMsg', fallback.notAuthenticatedMsg);

  @override
  String get notLinkedLabel => OtaTranslationService.translate(locale, 'notLinkedLabel', fallback.notLinkedLabel);

  @override
  String get notMemberChat => OtaTranslationService.translate(locale, 'notMemberChat', fallback.notMemberChat);

  @override
  String get notMemberChatRetry => OtaTranslationService.translate(locale, 'notMemberChatRetry', fallback.notMemberChatRetry);

  @override
  String get notMemberCommunity => OtaTranslationService.translate(locale, 'notMemberCommunity', fallback.notMemberCommunity);

  @override
  String get notificationSettingsComingSoon => OtaTranslationService.translate(locale, 'notificationSettingsComingSoon', fallback.notificationSettingsComingSoon);

  @override
  String get notificationSingle => OtaTranslationService.translate(locale, 'notificationSingle', fallback.notificationSingle);

  @override
  String get notificationSoundsDesc => OtaTranslationService.translate(locale, 'notificationSoundsDesc', fallback.notificationSoundsDesc);

  @override
  String get offersNotAvailableMsg => OtaTranslationService.translate(locale, 'offersNotAvailableMsg', fallback.offersNotAvailableMsg);

  @override
  String get onlyAcceptsDMs => OtaTranslationService.translate(locale, 'onlyAcceptsDMs', fallback.onlyAcceptsDMs);

  @override
  String get onlyFollowBackLabel => OtaTranslationService.translate(locale, 'onlyFollowBackLabel', fallback.onlyFollowBackLabel);

  @override
  String get onlyInvitedMembersDesc => OtaTranslationService.translate(locale, 'onlyInvitedMembersDesc', fallback.onlyInvitedMembersDesc);

  @override
  String get optionsLabelGeneral => OtaTranslationService.translate(locale, 'optionsLabelGeneral', fallback.optionsLabelGeneral);

  @override
  String get optionsMarkCorrect => OtaTranslationService.translate(locale, 'optionsMarkCorrect', fallback.optionsMarkCorrect);

  @override
  String get orSendMessages => OtaTranslationService.translate(locale, 'orSendMessages', fallback.orSendMessages);

  @override
  String get packageNotFoundMsg => OtaTranslationService.translate(locale, 'packageNotFoundMsg', fallback.packageNotFoundMsg);

  @override
  String get pasteVideoLink => OtaTranslationService.translate(locale, 'pasteVideoLink', fallback.pasteVideoLink);

  @override
  String get pauseNotifications2 => OtaTranslationService.translate(locale, 'pauseNotifications2', fallback.pauseNotifications2);

  @override
  String get pauseNotificationsDesc => OtaTranslationService.translate(locale, 'pauseNotificationsDesc', fallback.pauseNotificationsDesc);

  @override
  String get pendingReports => OtaTranslationService.translate(locale, 'pendingReports', fallback.pendingReports);

  @override
  String get pinPostDesc => OtaTranslationService.translate(locale, 'pinPostDesc', fallback.pinPostDesc);

  @override
  String get pollExampleHint => OtaTranslationService.translate(locale, 'pollExampleHint', fallback.pollExampleHint);

  @override
  String get pollQuestionRequiredMsg => OtaTranslationService.translate(locale, 'pollQuestionRequiredMsg', fallback.pollQuestionRequiredMsg);

  @override
  String get portugueseBrazil => OtaTranslationService.translate(locale, 'portugueseBrazil', fallback.portugueseBrazil);

  @override
  String get postDraftsHere => OtaTranslationService.translate(locale, 'postDraftsHere', fallback.postDraftsHere);

  @override
  String get postNotFoundMsg => OtaTranslationService.translate(locale, 'postNotFoundMsg', fallback.postNotFoundMsg);

  @override
  String get postNotFoundPermission => OtaTranslationService.translate(locale, 'postNotFoundPermission', fallback.postNotFoundPermission);

  @override
  String get postTitleHint => OtaTranslationService.translate(locale, 'postTitleHint', fallback.postTitleHint);

  @override
  String get postingTooFast => OtaTranslationService.translate(locale, 'postingTooFast', fallback.postingTooFast);

  @override
  String get preferencesLabel => OtaTranslationService.translate(locale, 'preferencesLabel', fallback.preferencesLabel);

  @override
  String get preventNewUsersDesc => OtaTranslationService.translate(locale, 'preventNewUsersDesc', fallback.preventNewUsersDesc);

  @override
  String get projectionLabel => OtaTranslationService.translate(locale, 'projectionLabel', fallback.projectionLabel);

  @override
  String get publicChatLabel => OtaTranslationService.translate(locale, 'publicChatLabel', fallback.publicChatLabel);

  @override
  String get publicChatsLabel => OtaTranslationService.translate(locale, 'publicChatsLabel', fallback.publicChatsLabel);

  @override
  String get publicLabelGeneral => OtaTranslationService.translate(locale, 'publicLabelGeneral', fallback.publicLabelGeneral);

  @override
  String get publicProfile => OtaTranslationService.translate(locale, 'publicProfile', fallback.publicProfile);

  @override
  String get publishContentDesc => OtaTranslationService.translate(locale, 'publishContentDesc', fallback.publishContentDesc);

  @override
  String get pushNotificationSettings => OtaTranslationService.translate(locale, 'pushNotificationSettings', fallback.pushNotificationSettings);

  @override
  String get pushNotifications2 => OtaTranslationService.translate(locale, 'pushNotifications2', fallback.pushNotifications2);

  @override
  String get questionRequiredMsg => OtaTranslationService.translate(locale, 'questionRequiredMsg', fallback.questionRequiredMsg);

  @override
  String get quizExampleHint => OtaTranslationService.translate(locale, 'quizExampleHint', fallback.quizExampleHint);

  @override
  String get quizTitle => OtaTranslationService.translate(locale, 'quizTitle', fallback.quizTitle);

  @override
  String get quizTitleRequiredMsg => OtaTranslationService.translate(locale, 'quizTitleRequiredMsg', fallback.quizTitleRequiredMsg);

  @override
  String get recentPostsTabDesc => OtaTranslationService.translate(locale, 'recentPostsTabDesc', fallback.recentPostsTabDesc);

  @override
  String get recentSearchesLabel => OtaTranslationService.translate(locale, 'recentSearchesLabel', fallback.recentSearchesLabel);

  @override
  String get recipientAminoId => OtaTranslationService.translate(locale, 'recipientAminoId', fallback.recipientAminoId);

  @override
  String get recognizeMemberDesc => OtaTranslationService.translate(locale, 'recognizeMemberDesc', fallback.recognizeMemberDesc);

  @override
  String get removeUserBanAction => OtaTranslationService.translate(locale, 'removeUserBanAction', fallback.removeUserBanAction);

  @override
  String get removeUserDesc => OtaTranslationService.translate(locale, 'removeUserDesc', fallback.removeUserDesc);

  @override
  String get reportContentTitle => OtaTranslationService.translate(locale, 'reportContentTitle', fallback.reportContentTitle);

  @override
  String get reportSubmittedThankYou => OtaTranslationService.translate(locale, 'reportSubmittedThankYou', fallback.reportSubmittedThankYou);

  @override
  String get reportSubmittedThanks => OtaTranslationService.translate(locale, 'reportSubmittedThanks', fallback.reportSubmittedThanks);

  @override
  String get reportsLabelGeneral => OtaTranslationService.translate(locale, 'reportsLabelGeneral', fallback.reportsLabelGeneral);

  @override
  String get requiredLabel => OtaTranslationService.translate(locale, 'requiredLabel', fallback.requiredLabel);

  @override
  String get requiresApproval => OtaTranslationService.translate(locale, 'requiresApproval', fallback.requiresApproval);

  @override
  String get resetToDefault => OtaTranslationService.translate(locale, 'resetToDefault', fallback.resetToDefault);

  @override
  String get saveChangesAction => OtaTranslationService.translate(locale, 'saveChangesAction', fallback.saveChangesAction);

  @override
  String get searchCommunityMembersHint => OtaTranslationService.translate(locale, 'searchCommunityMembersHint', fallback.searchCommunityMembersHint);

  @override
  String get searchWikiArticlesHint => OtaTranslationService.translate(locale, 'searchWikiArticlesHint', fallback.searchWikiArticlesHint);

  @override
  String get selectReportReasonLabel => OtaTranslationService.translate(locale, 'selectReportReasonLabel', fallback.selectReportReasonLabel);

  @override
  String get selectReportTypeLabel => OtaTranslationService.translate(locale, 'selectReportTypeLabel', fallback.selectReportTypeLabel);

  @override
  String get selfHarmSuicide => OtaTranslationService.translate(locale, 'selfHarmSuicide', fallback.selfHarmSuicide);

  @override
  String get sendMessageAllUsers => OtaTranslationService.translate(locale, 'sendMessageAllUsers', fallback.sendMessageAllUsers);

  @override
  String get settingsApplyOnlyCommunity => OtaTranslationService.translate(locale, 'settingsApplyOnlyCommunity', fallback.settingsApplyOnlyCommunity);

  @override
  String get settingsSaved => OtaTranslationService.translate(locale, 'settingsSaved', fallback.settingsSaved);

  @override
  String get showCreateButton => OtaTranslationService.translate(locale, 'showCreateButton', fallback.showCreateButton);

  @override
  String get showWhenOnlineDesc => OtaTranslationService.translate(locale, 'showWhenOnlineDesc', fallback.showWhenOnlineDesc);

  @override
  String get songNameHint => OtaTranslationService.translate(locale, 'songNameHint', fallback.songNameHint);

  @override
  String get storageLabel => OtaTranslationService.translate(locale, 'storageLabel', fallback.storageLabel);

  @override
  String get streakLost => OtaTranslationService.translate(locale, 'streakLost', fallback.streakLost);

  @override
  String get streakLostRecoverMsg => OtaTranslationService.translate(locale, 'streakLostRecoverMsg', fallback.streakLostRecoverMsg);

  @override
  String get streakResetsDesc => OtaTranslationService.translate(locale, 'streakResetsDesc', fallback.streakResetsDesc);

  @override
  String get submitReport => OtaTranslationService.translate(locale, 'submitReport', fallback.submitReport);

  @override
  String get subscribeAction => OtaTranslationService.translate(locale, 'subscribeAction', fallback.subscribeAction);

  @override
  String get subscribePrice => OtaTranslationService.translate(locale, 'subscribePrice', fallback.subscribePrice);

  @override
  String get subscriptionsLabel => OtaTranslationService.translate(locale, 'subscriptionsLabel', fallback.subscriptionsLabel);

  @override
  String get subtitleHint => OtaTranslationService.translate(locale, 'subtitleHint', fallback.subtitleHint);

  @override
  String get tapToAddVideo => OtaTranslationService.translate(locale, 'tapToAddVideo', fallback.tapToAddVideo);

  @override
  String get tellAboutYourself => OtaTranslationService.translate(locale, 'tellAboutYourself', fallback.tellAboutYourself);

  @override
  String get thisMonth => OtaTranslationService.translate(locale, 'thisMonth', fallback.thisMonth);

  @override
  String get titleHint => OtaTranslationService.translate(locale, 'titleHint', fallback.titleHint);

  @override
  String get titleOptionalHint => OtaTranslationService.translate(locale, 'titleOptionalHint', fallback.titleOptionalHint);

  @override
  String get titleRequiredMsg => OtaTranslationService.translate(locale, 'titleRequiredMsg', fallback.titleRequiredMsg);

  @override
  String get tooManyComments => OtaTranslationService.translate(locale, 'tooManyComments', fallback.tooManyComments);

  @override
  String get tooManyReports => OtaTranslationService.translate(locale, 'tooManyReports', fallback.tooManyReports);

  @override
  String get tooManyTransfers => OtaTranslationService.translate(locale, 'tooManyTransfers', fallback.tooManyTransfers);

  @override
  String get topicCategoriesLabel => OtaTranslationService.translate(locale, 'topicCategoriesLabel', fallback.topicCategoriesLabel);

  @override
  String get transactionHistory => OtaTranslationService.translate(locale, 'transactionHistory', fallback.transactionHistory);

  @override
  String get uniqueIdentifierLabel => OtaTranslationService.translate(locale, 'uniqueIdentifierLabel', fallback.uniqueIdentifierLabel);

  @override
  String get unlistedLabel => OtaTranslationService.translate(locale, 'unlistedLabel', fallback.unlistedLabel);

  @override
  String get unpinPostAction => OtaTranslationService.translate(locale, 'unpinPostAction', fallback.unpinPostAction);

  @override
  String get useButtonToCreate => OtaTranslationService.translate(locale, 'useButtonToCreate', fallback.useButtonToCreate);

  @override
  String get userAminoId => OtaTranslationService.translate(locale, 'userAminoId', fallback.userAminoId);

  @override
  String get usernameCharsAllowed => OtaTranslationService.translate(locale, 'usernameCharsAllowed', fallback.usernameCharsAllowed);

  @override
  String get usernameNotAllowed => OtaTranslationService.translate(locale, 'usernameNotAllowed', fallback.usernameNotAllowed);

  @override
  String get usersLabelGeneral => OtaTranslationService.translate(locale, 'usersLabelGeneral', fallback.usersLabelGeneral);

  @override
  String get vibrateOnNotificationsDesc => OtaTranslationService.translate(locale, 'vibrateOnNotificationsDesc', fallback.vibrateOnNotificationsDesc);

  @override
  String get vibrationLabel => OtaTranslationService.translate(locale, 'vibrationLabel', fallback.vibrationLabel);

  @override
  String get videoLabelGeneral => OtaTranslationService.translate(locale, 'videoLabelGeneral', fallback.videoLabelGeneral);

  @override
  String get videoTitleOptional => OtaTranslationService.translate(locale, 'videoTitleOptional', fallback.videoTitleOptional);

  @override
  String get visualCustomization => OtaTranslationService.translate(locale, 'visualCustomization', fallback.visualCustomization);

  @override
  String get waitingForHostVideo => OtaTranslationService.translate(locale, 'waitingForHostVideo', fallback.waitingForHostVideo);

  @override
  String get warningsStrikesActions => OtaTranslationService.translate(locale, 'warningsStrikesActions', fallback.warningsStrikesActions);

  @override
  String get watchAdAction => OtaTranslationService.translate(locale, 'watchAdAction', fallback.watchAdAction);

  @override
  String get watchAdsAction => OtaTranslationService.translate(locale, 'watchAdsAction', fallback.watchAdsAction);

  @override
  String get watchLabel => OtaTranslationService.translate(locale, 'watchLabel', fallback.watchLabel);

  @override
  String get watchVideoAction => OtaTranslationService.translate(locale, 'watchVideoAction', fallback.watchVideoAction);

  @override
  String get welcomeToCommunity => OtaTranslationService.translate(locale, 'welcomeToCommunity', fallback.welcomeToCommunity);

  @override
  String get whatDoYouWantToKnow => OtaTranslationService.translate(locale, 'whatDoYouWantToKnow', fallback.whatDoYouWantToKnow);

  @override
  String get whenLevelUpNotif => OtaTranslationService.translate(locale, 'whenLevelUpNotif', fallback.whenLevelUpNotif);

  @override
  String get whenSomeoneCommentsNotif => OtaTranslationService.translate(locale, 'whenSomeoneCommentsNotif', fallback.whenSomeoneCommentsNotif);

  @override
  String get whenSomeoneFollowsNotif => OtaTranslationService.translate(locale, 'whenSomeoneFollowsNotif', fallback.whenSomeoneFollowsNotif);

  @override
  String get whenSomeoneLikesNotif => OtaTranslationService.translate(locale, 'whenSomeoneLikesNotif', fallback.whenSomeoneLikesNotif);

  @override
  String get whenSomeoneMentionsNotif => OtaTranslationService.translate(locale, 'whenSomeoneMentionsNotif', fallback.whenSomeoneMentionsNotif);

  @override
  String get writeBioHint => OtaTranslationService.translate(locale, 'writeBioHint', fallback.writeBioHint);

  @override
  String get writeContentHere => OtaTranslationService.translate(locale, 'writeContentHere', fallback.writeContentHere);

  @override
  String get checkInDaily => OtaTranslationService.translate(locale, 'checkInDaily', fallback.checkInDaily);

  @override
  String get quizDaily => OtaTranslationService.translate(locale, 'quizDaily', fallback.quizDaily);

  @override
  String get chatPublicNewline => OtaTranslationService.translate(locale, 'chatPublicNewline', fallback.chatPublicNewline);

  @override
  String get defaultAllowedContent => OtaTranslationService.translate(locale, 'defaultAllowedContent', fallback.defaultAllowedContent);

  @override
  String get defaultGuidelines => OtaTranslationService.translate(locale, 'defaultGuidelines', fallback.defaultGuidelines);

  @override
  String get defaultProhibitedContent => OtaTranslationService.translate(locale, 'defaultProhibitedContent', fallback.defaultProhibitedContent);

  @override
  String get defaultRoles => OtaTranslationService.translate(locale, 'defaultRoles', fallback.defaultRoles);

  @override
  String get defaultStrikePolicy => OtaTranslationService.translate(locale, 'defaultStrikePolicy', fallback.defaultStrikePolicy);

  @override
  String get guidelinesEditorHint => OtaTranslationService.translate(locale, 'guidelinesEditorHint', fallback.guidelinesEditorHint);

  @override
  String get yourUniqueIdDesc => OtaTranslationService.translate(locale, 'yourUniqueIdDesc', fallback.yourUniqueIdDesc);

  @override
  String get mediaLabel => OtaTranslationService.translate(locale, 'mediaLabel', fallback.mediaLabel);

  @override
  String get moderationActions30d => OtaTranslationService.translate(locale, 'moderationActions30d', fallback.moderationActions30d);

  @override
  String get leadersTitle => OtaTranslationService.translate(locale, 'leadersTitle', fallback.leadersTitle);

  @override
  String get aminoIdInUse => OtaTranslationService.translate(locale, 'aminoIdInUse', fallback.aminoIdInUse);

  @override
  String get tryAgainGeneric => OtaTranslationService.translate(locale, 'tryAgainGeneric', fallback.tryAgainGeneric);

  @override
  String get textOverflowHint => OtaTranslationService.translate(locale, 'textOverflowHint', fallback.textOverflowHint);

  @override
  String get addCover => OtaTranslationService.translate(locale, 'addCover', fallback.addCover);

  @override
  String get addQuestion2 => OtaTranslationService.translate(locale, 'addQuestion2', fallback.addQuestion2);

  @override
  String get addCaptionHint => OtaTranslationService.translate(locale, 'addCaptionHint', fallback.addCaptionHint);

  @override
  String get addContextHint => OtaTranslationService.translate(locale, 'addContextHint', fallback.addContextHint);

  @override
  String get aminoId => OtaTranslationService.translate(locale, 'aminoId', fallback.aminoId);

  @override
  String get inviteOnly => OtaTranslationService.translate(locale, 'inviteOnly', fallback.inviteOnly);

  @override
  String get fileSentSuccess => OtaTranslationService.translate(locale, 'fileSentSuccess', fallback.fileSentSuccess);

  @override
  String get bannerCover => OtaTranslationService.translate(locale, 'bannerCover', fallback.bannerCover);

  @override
  String get welcomeBanner => OtaTranslationService.translate(locale, 'welcomeBanner', fallback.welcomeBanner);

  @override
  String get bottomBar => OtaTranslationService.translate(locale, 'bottomBar', fallback.bottomBar);

  @override
  String get blogPublishedSuccess => OtaTranslationService.translate(locale, 'blogPublishedSuccess', fallback.blogPublishedSuccess);

  @override
  String get broadcastSent => OtaTranslationService.translate(locale, 'broadcastSent', fallback.broadcastSent);

  @override
  String get searchChatHint => OtaTranslationService.translate(locale, 'searchChatHint', fallback.searchChatHint);

  @override
  String get searchEverythingHint => OtaTranslationService.translate(locale, 'searchEverythingHint', fallback.searchEverythingHint);

  @override
  String get carousel => OtaTranslationService.translate(locale, 'carousel', fallback.carousel);

  @override
  String get helpCenter => OtaTranslationService.translate(locale, 'helpCenter', fallback.helpCenter);

  @override
  String get privateChatLabel => OtaTranslationService.translate(locale, 'privateChatLabel', fallback.privateChatLabel);

  @override
  String get groupChatLabel => OtaTranslationService.translate(locale, 'groupChatLabel', fallback.groupChatLabel);

  @override
  String get liveChats2 => OtaTranslationService.translate(locale, 'liveChats2', fallback.liveChats2);

  @override
  String get checkInLabel => OtaTranslationService.translate(locale, 'checkInLabel', fallback.checkInLabel);

  @override
  String get startConversation2 => OtaTranslationService.translate(locale, 'startConversation2', fallback.startConversation2);

  @override
  String get howItWorks => OtaTranslationService.translate(locale, 'howItWorks', fallback.howItWorks);

  @override
  String get shareLinkTitle => OtaTranslationService.translate(locale, 'shareLinkTitle', fallback.shareLinkTitle);

  @override
  String get copiedMsg => OtaTranslationService.translate(locale, 'copiedMsg', fallback.copiedMsg);

  @override
  String get copyLink => OtaTranslationService.translate(locale, 'copyLink', fallback.copyLink);

  @override
  String get createScreeningRoom => OtaTranslationService.translate(locale, 'createScreeningRoom', fallback.createScreeningRoom);

  @override
  String get leaveEmptyBio => OtaTranslationService.translate(locale, 'leaveEmptyBio', fallback.leaveEmptyBio);

  @override
  String get leaveEmptyGlobal => OtaTranslationService.translate(locale, 'leaveEmptyGlobal', fallback.leaveEmptyGlobal);

  @override
  String get deleteAction2 => OtaTranslationService.translate(locale, 'deleteAction2', fallback.deleteAction2);

  @override
  String get deletePost2 => OtaTranslationService.translate(locale, 'deletePost2', fallback.deletePost2);

  @override
  String get describeBugHint => OtaTranslationService.translate(locale, 'describeBugHint', fallback.describeBugHint);

  @override
  String get describeLinkHint => OtaTranslationService.translate(locale, 'describeLinkHint', fallback.describeLinkHint);

  @override
  String get highlights => OtaTranslationService.translate(locale, 'highlights', fallback.highlights);

  @override
  String get additionalDetailsHint => OtaTranslationService.translate(locale, 'additionalDetailsHint', fallback.additionalDetailsHint);

  @override
  String get saySomethingHint => OtaTranslationService.translate(locale, 'saySomethingHint', fallback.saySomethingHint);

  @override
  String get typeMessageHint => OtaTranslationService.translate(locale, 'typeMessageHint', fallback.typeMessageHint);

  @override
  String get typeQuestionHint => OtaTranslationService.translate(locale, 'typeQuestionHint', fallback.typeQuestionHint);

  @override
  String get editMessage => OtaTranslationService.translate(locale, 'editMessage', fallback.editMessage);

  @override
  String get editPost => OtaTranslationService.translate(locale, 'editPost', fallback.editPost);

  @override
  String get editMessageHint => OtaTranslationService.translate(locale, 'editMessageHint', fallback.editMessageHint);

  @override
  String get pollCreatedSuccess => OtaTranslationService.translate(locale, 'pollCreatedSuccess', fallback.pollCreatedSuccess);

  @override
  String get joinChat => OtaTranslationService.translate(locale, 'joinChat', fallback.joinChat);

  @override
  String get joinCommunityStartChat => OtaTranslationService.translate(locale, 'joinCommunityStartChat', fallback.joinCommunityStartChat);

  @override
  String get sendingImage => OtaTranslationService.translate(locale, 'sendingImage', fallback.sendingImage);

  @override
  String get sendBroadcast => OtaTranslationService.translate(locale, 'sendBroadcast', fallback.sendBroadcast);

  @override
  String get sendTip => OtaTranslationService.translate(locale, 'sendTip', fallback.sendTip);

  @override
  String get sendProps => OtaTranslationService.translate(locale, 'sendProps', fallback.sendProps);

  @override
  String get errorLoadingPosts => OtaTranslationService.translate(locale, 'errorLoadingPosts', fallback.errorLoadingPosts);

  @override
  String get errorCreatingCommunity => OtaTranslationService.translate(locale, 'errorCreatingCommunity', fallback.errorCreatingCommunity);

  @override
  String get errorCreatingPoll => OtaTranslationService.translate(locale, 'errorCreatingPoll', fallback.errorCreatingPoll);

  @override
  String get errorCreatingQuiz => OtaTranslationService.translate(locale, 'errorCreatingQuiz', fallback.errorCreatingQuiz);

  @override
  String get errorCreatingRoom => OtaTranslationService.translate(locale, 'errorCreatingRoom', fallback.errorCreatingRoom);

  @override
  String get errorUnlinking => OtaTranslationService.translate(locale, 'errorUnlinking', fallback.errorUnlinking);

  @override
  String get errorForwarding => OtaTranslationService.translate(locale, 'errorForwarding', fallback.errorForwarding);

  @override
  String get errorPublishing2 => OtaTranslationService.translate(locale, 'errorPublishing2', fallback.errorPublishing2);

  @override
  String get errorCheckIn => OtaTranslationService.translate(locale, 'errorCheckIn', fallback.errorCheckIn);

  @override
  String get writeStoryHint => OtaTranslationService.translate(locale, 'writeStoryHint', fallback.writeStoryHint);

  @override
  String get writeHereHint => OtaTranslationService.translate(locale, 'writeHereHint', fallback.writeHereHint);

  @override
  String get writeCaptionHint => OtaTranslationService.translate(locale, 'writeCaptionHint', fallback.writeCaptionHint);

  @override
  String get highlightsStyle => OtaTranslationService.translate(locale, 'highlightsStyle', fallback.highlightsStyle);

  @override
  String get clickHereExample => OtaTranslationService.translate(locale, 'clickHereExample', fallback.clickHereExample);

  @override
  String get deleteChatTitle => OtaTranslationService.translate(locale, 'deleteChatTitle', fallback.deleteChatTitle);

  @override
  String get deleteDraftQuestion => OtaTranslationService.translate(locale, 'deleteDraftQuestion', fallback.deleteDraftQuestion);

  @override
  String get showOnlineCount => OtaTranslationService.translate(locale, 'showOnlineCount', fallback.showOnlineCount);

  @override
  String get doCheckIn2 => OtaTranslationService.translate(locale, 'doCheckIn2', fallback.doCheckIn2);

  @override
  String get recentFeed => OtaTranslationService.translate(locale, 'recentFeed', fallback.recentFeed);

  @override
  String get pendingFlags => OtaTranslationService.translate(locale, 'pendingFlags', fallback.pendingFlags);

  @override
  String get chatBackground => OtaTranslationService.translate(locale, 'chatBackground', fallback.chatBackground);

  @override
  String get gifAddedToPost => OtaTranslationService.translate(locale, 'gifAddedToPost', fallback.gifAddedToPost);

  @override
  String get rotate => OtaTranslationService.translate(locale, 'rotate', fallback.rotate);

  @override
  String get grid2 => OtaTranslationService.translate(locale, 'grid2', fallback.grid2);

  @override
  String get galleryImage => OtaTranslationService.translate(locale, 'galleryImage', fallback.galleryImage);

  @override
  String get insertLink2 => OtaTranslationService.translate(locale, 'insertLink2', fallback.insertLink2);

  @override
  String get linkOnClick => OtaTranslationService.translate(locale, 'linkOnClick', fallback.linkOnClick);

  @override
  String get linkSharedSuccess => OtaTranslationService.translate(locale, 'linkSharedSuccess', fallback.linkSharedSuccess);

  @override
  String get linkCopied => OtaTranslationService.translate(locale, 'linkCopied', fallback.linkCopied);

  @override
  String get linkRemoved2 => OtaTranslationService.translate(locale, 'linkRemoved2', fallback.linkRemoved2);

  @override
  String get oldest => OtaTranslationService.translate(locale, 'oldest', fallback.oldest);

  @override
  String get mostPopular => OtaTranslationService.translate(locale, 'mostPopular', fallback.mostPopular);

  @override
  String get mostRecent => OtaTranslationService.translate(locale, 'mostRecent', fallback.mostRecent);

  @override
  String get totalMembers2 => OtaTranslationService.translate(locale, 'totalMembers2', fallback.totalMembers2);

  @override
  String get chatMembers => OtaTranslationService.translate(locale, 'chatMembers', fallback.chatMembers);

  @override
  String get welcomeMessage2 => OtaTranslationService.translate(locale, 'welcomeMessage2', fallback.welcomeMessage2);

  @override
  String get pinnedMessages => OtaTranslationService.translate(locale, 'pinnedMessages', fallback.pinnedMessages);

  @override
  String get nothingToSave => OtaTranslationService.translate(locale, 'nothingToSave', fallback.nothingToSave);

  @override
  String get noGifFound => OtaTranslationService.translate(locale, 'noGifFound', fallback.noGifFound);

  @override
  String get noMembers => OtaTranslationService.translate(locale, 'noMembers', fallback.noMembers);

  @override
  String get noPostFound => OtaTranslationService.translate(locale, 'noPostFound', fallback.noPostFound);

  @override
  String get noWallMessages => OtaTranslationService.translate(locale, 'noWallMessages', fallback.noWallMessages);

  @override
  String get communityNameRequired2 => OtaTranslationService.translate(locale, 'communityNameRequired2', fallback.communityNameRequired2);

  @override
  String get roomName => OtaTranslationService.translate(locale, 'roomName', fallback.roomName);

  @override
  String get newMembers7d => OtaTranslationService.translate(locale, 'newMembers7d', fallback.newMembers7d);

  @override
  String get hiddenLabel => OtaTranslationService.translate(locale, 'hiddenLabel', fallback.hiddenLabel);

  @override
  String get hidePost => OtaTranslationService.translate(locale, 'hidePost', fallback.hidePost);

  @override
  String get sortBy => OtaTranslationService.translate(locale, 'sortBy', fallback.sortBy);

  @override
  String get orTypeValue => OtaTranslationService.translate(locale, 'orTypeValue', fallback.orTypeValue);

  @override
  String get profileUpdatedSuccess => OtaTranslationService.translate(locale, 'profileUpdatedSuccess', fallback.profileUpdatedSuccess);

  @override
  String get communityProfileUpdated => OtaTranslationService.translate(locale, 'communityProfileUpdated', fallback.communityProfileUpdated);

  @override
  String get questionAndAnswer => OtaTranslationService.translate(locale, 'questionAndAnswer', fallback.questionAndAnswer);

  @override
  String get questionPublishedSuccess => OtaTranslationService.translate(locale, 'questionPublishedSuccess', fallback.questionPublishedSuccess);

  @override
  String get postUpdated => OtaTranslationService.translate(locale, 'postUpdated', fallback.postUpdated);

  @override
  String get postCreatedSuccess => OtaTranslationService.translate(locale, 'postCreatedSuccess', fallback.postCreatedSuccess);

  @override
  String get postDeleted2 => OtaTranslationService.translate(locale, 'postDeleted2', fallback.postDeleted2);

  @override
  String get postHiddenFromFeed => OtaTranslationService.translate(locale, 'postHiddenFromFeed', fallback.postHiddenFromFeed);

  @override
  String get postPublishedSuccess => OtaTranslationService.translate(locale, 'postPublishedSuccess', fallback.postPublishedSuccess);

  @override
  String get privateLabel => OtaTranslationService.translate(locale, 'privateLabel', fallback.privateLabel);

  @override
  String get searchMyChats => OtaTranslationService.translate(locale, 'searchMyChats', fallback.searchMyChats);

  @override
  String get rewards => OtaTranslationService.translate(locale, 'rewards', fallback.rewards);

  @override
  String get reportAction => OtaTranslationService.translate(locale, 'reportAction', fallback.reportAction);

  @override
  String get reportBug => OtaTranslationService.translate(locale, 'reportBug', fallback.reportBug);

  @override
  String get logOutAction => OtaTranslationService.translate(locale, 'logOutAction', fallback.logOutAction);

  @override
  String get leaveChatTitle => OtaTranslationService.translate(locale, 'leaveChatTitle', fallback.leaveChatTitle);

  @override
  String get holdToFavorite => OtaTranslationService.translate(locale, 'holdToFavorite', fallback.holdToFavorite);

  @override
  String get selectCrosspostCommunity => OtaTranslationService.translate(locale, 'selectCrosspostCommunity', fallback.selectCrosspostCommunity);

  @override
  String get selectCommunity2 => OtaTranslationService.translate(locale, 'selectCommunity2', fallback.selectCommunity2);

  @override
  String get selectImage2 => OtaTranslationService.translate(locale, 'selectImage2', fallback.selectImage2);

  @override
  String get luckyDraw => OtaTranslationService.translate(locale, 'luckyDraw', fallback.luckyDraw);

  @override
  String get storyLabel => OtaTranslationService.translate(locale, 'storyLabel', fallback.storyLabel);

  @override
  String get taglineLabel => OtaTranslationService.translate(locale, 'taglineLabel', fallback.taglineLabel);

  @override
  String get confirmLeaveChat => OtaTranslationService.translate(locale, 'confirmLeaveChat', fallback.confirmLeaveChat);

  @override
  String get tryLuckExtraCoins => OtaTranslationService.translate(locale, 'tryLuckExtraCoins', fallback.tryLuckExtraCoins);

  @override
  String get postType => OtaTranslationService.translate(locale, 'postType', fallback.postType);

  @override
  String get takePhoto2 => OtaTranslationService.translate(locale, 'takePhoto2', fallback.takePhoto2);

  @override
  String get tapToAddImage => OtaTranslationService.translate(locale, 'tapToAddImage', fallback.tapToAddImage);

  @override
  String get bannerImageUrl => OtaTranslationService.translate(locale, 'bannerImageUrl', fallback.bannerImageUrl);

  @override
  String get bannerImageUrlOptional => OtaTranslationService.translate(locale, 'bannerImageUrlOptional', fallback.bannerImageUrlOptional);

  @override
  String get customBgUrlHint => OtaTranslationService.translate(locale, 'customBgUrlHint', fallback.customBgUrlHint);

  @override
  String get customBannerDesc => OtaTranslationService.translate(locale, 'customBannerDesc', fallback.customBannerDesc);

  @override
  String get seeAll2 => OtaTranslationService.translate(locale, 'seeAll2', fallback.seeAll2);

  @override
  String get orLabel => OtaTranslationService.translate(locale, 'orLabel', fallback.orLabel);

  @override
  String get repairCoins => OtaTranslationService.translate(locale, 'repairCoins', fallback.repairCoins);

  @override
  String get bannerTextHint => OtaTranslationService.translate(locale, 'bannerTextHint', fallback.bannerTextHint);

  @override
  String get oneDay => OtaTranslationService.translate(locale, 'oneDay', fallback.oneDay);

  @override
  String get oneHour => OtaTranslationService.translate(locale, 'oneHour', fallback.oneHour);

  @override
  String get twentyFourHours => OtaTranslationService.translate(locale, 'twentyFourHours', fallback.twentyFourHours);

  @override
  String get threeDays => OtaTranslationService.translate(locale, 'threeDays', fallback.threeDays);

  @override
  String get thirtyDays => OtaTranslationService.translate(locale, 'thirtyDays', fallback.thirtyDays);

  @override
  String get sixHours => OtaTranslationService.translate(locale, 'sixHours', fallback.sixHours);

  @override
  String get sevenDays => OtaTranslationService.translate(locale, 'sevenDays', fallback.sevenDays);

  @override
  String get noItemAvailable => OtaTranslationService.translate(locale, 'noItemAvailable', fallback.noItemAvailable);

  @override
  String get searchUser => OtaTranslationService.translate(locale, 'searchUser', fallback.searchUser);

  @override
  String get globalSettings => OtaTranslationService.translate(locale, 'globalSettings', fallback.globalSettings);

  @override
  String get reportsTitle => OtaTranslationService.translate(locale, 'reportsTitle', fallback.reportsTitle);

  @override
  String get startConversationWithUser => OtaTranslationService.translate(locale, 'startConversationWithUser', fallback.startConversationWithUser);

  @override
  String get createCommunityNewline => OtaTranslationService.translate(locale, 'createCommunityNewline', fallback.createCommunityNewline);

  @override
  String get wikiEntryNewline => OtaTranslationService.translate(locale, 'wikiEntryNewline', fallback.wikiEntryNewline);

  @override
  String get coinShopNewline => OtaTranslationService.translate(locale, 'coinShopNewline', fallback.coinShopNewline);

  @override
  String get globalRankingNewline => OtaTranslationService.translate(locale, 'globalRankingNewline', fallback.globalRankingNewline);

  @override
  String get quizCreatedSuccess => OtaTranslationService.translate(locale, 'quizCreatedSuccess', fallback.quizCreatedSuccess);

  @override
  String get errorPrefix => OtaTranslationService.translate(locale, 'errorPrefix', fallback.errorPrefix);

  @override
  String get startConversationUser => OtaTranslationService.translate(locale, 'startConversationUser', fallback.startConversationUser);

  @override
  String get noItemAvailableMsg => OtaTranslationService.translate(locale, 'noItemAvailableMsg', fallback.noItemAvailableMsg);

  @override
  String get pinnedLabel => OtaTranslationService.translate(locale, 'pinnedLabel', fallback.pinnedLabel);

  @override
  String get externalLink => OtaTranslationService.translate(locale, 'externalLink', fallback.externalLink);

  @override
  String get pollOptionsLabel => OtaTranslationService.translate(locale, 'pollOptionsLabel', fallback.pollOptionsLabel);

  @override
  String get quizQuestionsLabel => OtaTranslationService.translate(locale, 'quizQuestionsLabel', fallback.quizQuestionsLabel);

  @override
  String get optionLabel => OtaTranslationService.translate(locale, 'optionLabel', fallback.optionLabel);

  @override
  String get levelTitleNovice => OtaTranslationService.translate(locale, 'levelTitleNovice', fallback.levelTitleNovice);

  @override
  String get levelTitleBeginner => OtaTranslationService.translate(locale, 'levelTitleBeginner', fallback.levelTitleBeginner);

  @override
  String get levelTitleApprentice => OtaTranslationService.translate(locale, 'levelTitleApprentice', fallback.levelTitleApprentice);

  @override
  String get levelTitleExplorer => OtaTranslationService.translate(locale, 'levelTitleExplorer', fallback.levelTitleExplorer);

  @override
  String get levelTitleWarrior => OtaTranslationService.translate(locale, 'levelTitleWarrior', fallback.levelTitleWarrior);

  @override
  String get levelTitleVeteran => OtaTranslationService.translate(locale, 'levelTitleVeteran', fallback.levelTitleVeteran);

  @override
  String get levelTitleSpecialist => OtaTranslationService.translate(locale, 'levelTitleSpecialist', fallback.levelTitleSpecialist);

  @override
  String get levelTitleMaster => OtaTranslationService.translate(locale, 'levelTitleMaster', fallback.levelTitleMaster);

  @override
  String get levelTitleGrandMaster => OtaTranslationService.translate(locale, 'levelTitleGrandMaster', fallback.levelTitleGrandMaster);

  @override
  String get levelTitleChampion => OtaTranslationService.translate(locale, 'levelTitleChampion', fallback.levelTitleChampion);

  @override
  String get levelTitleHero => OtaTranslationService.translate(locale, 'levelTitleHero', fallback.levelTitleHero);

  @override
  String get levelTitleGuardian => OtaTranslationService.translate(locale, 'levelTitleGuardian', fallback.levelTitleGuardian);

  @override
  String get levelTitleSentinel => OtaTranslationService.translate(locale, 'levelTitleSentinel', fallback.levelTitleSentinel);

  @override
  String get levelTitleLegendary => OtaTranslationService.translate(locale, 'levelTitleLegendary', fallback.levelTitleLegendary);

  @override
  String get levelTitleMythical => OtaTranslationService.translate(locale, 'levelTitleMythical', fallback.levelTitleMythical);

  @override
  String get levelTitleDivine => OtaTranslationService.translate(locale, 'levelTitleDivine', fallback.levelTitleDivine);

  @override
  String get levelTitleCelestial => OtaTranslationService.translate(locale, 'levelTitleCelestial', fallback.levelTitleCelestial);

  @override
  String get levelTitleTranscendent => OtaTranslationService.translate(locale, 'levelTitleTranscendent', fallback.levelTitleTranscendent);

  @override
  String get levelTitleSupreme => OtaTranslationService.translate(locale, 'levelTitleSupreme', fallback.levelTitleSupreme);

  @override
  String get levelTitleUltimate => OtaTranslationService.translate(locale, 'levelTitleUltimate', fallback.levelTitleUltimate);

  @override
  String get allRankings => OtaTranslationService.translate(locale, 'allRankings', fallback.allRankings);

  @override
  String get viewAllRankings => OtaTranslationService.translate(locale, 'viewAllRankings', fallback.viewAllRankings);

  @override
  String get beActiveMemberMsg => OtaTranslationService.translate(locale, 'beActiveMemberMsg', fallback.beActiveMemberMsg);

  @override
  String get levelMaxReached => OtaTranslationService.translate(locale, 'levelMaxReached', fallback.levelMaxReached);

  @override
  String get currentLevel => OtaTranslationService.translate(locale, 'currentLevel', fallback.currentLevel);

  @override
  String get nextLevel => OtaTranslationService.translate(locale, 'nextLevel', fallback.nextLevel);

  @override
  String get repToNextLevel => OtaTranslationService.translate(locale, 'repToNextLevel', fallback.repToNextLevel);

  @override
  String get myStatistics => OtaTranslationService.translate(locale, 'myStatistics', fallback.myStatistics);

  @override
  String get statsUpdatedWithDelay => OtaTranslationService.translate(locale, 'statsUpdatedWithDelay', fallback.statsUpdatedWithDelay);

  @override
  String get checkInActivity => OtaTranslationService.translate(locale, 'checkInActivity', fallback.checkInActivity);

  @override
  String get minutesLabel => OtaTranslationService.translate(locale, 'minutesLabel', fallback.minutesLabel);

  @override
  String get last24Hours => OtaTranslationService.translate(locale, 'last24Hours', fallback.last24Hours);

  @override
  String get achievementsUnlocked => OtaTranslationService.translate(locale, 'achievementsUnlocked', fallback.achievementsUnlocked);

  @override
  String get inProgress => OtaTranslationService.translate(locale, 'inProgress', fallback.inProgress);

  @override
  String get newAchievementsUnlocked => OtaTranslationService.translate(locale, 'newAchievementsUnlocked', fallback.newAchievementsUnlocked);

  @override
  String get holdAndDragToReorder => OtaTranslationService.translate(locale, 'holdAndDragToReorder', fallback.holdAndDragToReorder);

  @override
  String get insufficientCoins => OtaTranslationService.translate(locale, 'insufficientCoins', fallback.insufficientCoins);

  @override
  String get noBio => OtaTranslationService.translate(locale, 'noBio', fallback.noBio);

  @override
  String get tapToAddBio => OtaTranslationService.translate(locale, 'tapToAddBio', fallback.tapToAddBio);

  @override
  String get drawerExit => OtaTranslationService.translate(locale, 'drawerExit', fallback.drawerExit);

  @override
  String get drawerMyChats => OtaTranslationService.translate(locale, 'drawerMyChats', fallback.drawerMyChats);

  @override
  String get drawerPublicChatrooms => OtaTranslationService.translate(locale, 'drawerPublicChatrooms', fallback.drawerPublicChatrooms);

  @override
  String get drawerLeaderboards => OtaTranslationService.translate(locale, 'drawerLeaderboards', fallback.drawerLeaderboards);

  @override
  String get drawerMembers => OtaTranslationService.translate(locale, 'drawerMembers', fallback.drawerMembers);

  @override
  String get drawerEditCommunity => OtaTranslationService.translate(locale, 'drawerEditCommunity', fallback.drawerEditCommunity);

  @override
  String get drawerFlagCenter => OtaTranslationService.translate(locale, 'drawerFlagCenter', fallback.drawerFlagCenter);

  @override
  String get drawerStatistics => OtaTranslationService.translate(locale, 'drawerStatistics', fallback.drawerStatistics);

  @override
  String get drawerVisitor => OtaTranslationService.translate(locale, 'drawerVisitor', fallback.drawerVisitor);

  @override
  String get drawerLvLabel => OtaTranslationService.translate(locale, 'drawerLvLabel', fallback.drawerLvLabel);

  @override
  String get thisWeek => OtaTranslationService.translate(locale, 'thisWeek', fallback.thisWeek);

  @override
  String get blockConfirmTitle => OtaTranslationService.translate(locale, 'blockConfirmTitle', fallback.blockConfirmTitle);

  @override
  String get blockConfirmMsg => OtaTranslationService.translate(locale, 'blockConfirmMsg', fallback.blockConfirmMsg);

  @override
  String get blockSuccess => OtaTranslationService.translate(locale, 'blockSuccess', fallback.blockSuccess);

  @override
  String get emailChangeReauthInfo => OtaTranslationService.translate(locale, 'emailChangeReauthInfo', fallback.emailChangeReauthInfo);

  @override
  String get emailChangeDualConfirmInfo => OtaTranslationService.translate(locale, 'emailChangeDualConfirmInfo', fallback.emailChangeDualConfirmInfo);

  @override
  String get emailChangeSentBoth => OtaTranslationService.translate(locale, 'emailChangeSentBoth', fallback.emailChangeSentBoth);

  @override
  String get emailSameAsCurrent => OtaTranslationService.translate(locale, 'emailSameAsCurrent', fallback.emailSameAsCurrent);

  @override
  String get aminoIdInvalidChars => OtaTranslationService.translate(locale, 'aminoIdInvalidChars', fallback.aminoIdInvalidChars);

  @override
  String get repost => OtaTranslationService.translate(locale, 'repost', fallback.repost);

  @override
  String get repostAction => OtaTranslationService.translate(locale, 'repostAction', fallback.repostAction);

  @override
  String get repostSuccess => OtaTranslationService.translate(locale, 'repostSuccess', fallback.repostSuccess);

  @override
  String get repostAlreadyExists => OtaTranslationService.translate(locale, 'repostAlreadyExists', fallback.repostAlreadyExists);

  @override
  String get repostConfirmTitle => OtaTranslationService.translate(locale, 'repostConfirmTitle', fallback.repostConfirmTitle);

  @override
  String get repostConfirmMsg => OtaTranslationService.translate(locale, 'repostConfirmMsg', fallback.repostConfirmMsg);

  @override
  String get repostNotificationTitle => OtaTranslationService.translate(locale, 'repostNotificationTitle', fallback.repostNotificationTitle);

  @override
  String get wikiTitleRequired => OtaTranslationService.translate(locale, 'wikiTitleRequired', fallback.wikiTitleRequired);

  @override
  String get wikiNeedOneSection => OtaTranslationService.translate(locale, 'wikiNeedOneSection', fallback.wikiNeedOneSection);

  @override
  String get wikiPublishedSuccess => OtaTranslationService.translate(locale, 'wikiPublishedSuccess', fallback.wikiPublishedSuccess);

  @override
  String get wikiEntry => OtaTranslationService.translate(locale, 'wikiEntry', fallback.wikiEntry);

  @override
  String get wikiDescription => OtaTranslationService.translate(locale, 'wikiDescription', fallback.wikiDescription);

  @override
  String get aboutMe => OtaTranslationService.translate(locale, 'aboutMe', fallback.aboutMe);

  @override
  String get accountDeleted => OtaTranslationService.translate(locale, 'accountDeleted', fallback.accountDeleted);

  @override
  String get accountSettings => OtaTranslationService.translate(locale, 'accountSettings', fallback.accountSettings);

  @override
  String get adNotAvailableDesc => OtaTranslationService.translate(locale, 'adNotAvailableDesc', fallback.adNotAvailableDesc);

  @override
  String get addAtLeastOneQuestionDesc => OtaTranslationService.translate(locale, 'addAtLeastOneQuestionDesc', fallback.addAtLeastOneQuestionDesc);

  @override
  String get addCoverImage => OtaTranslationService.translate(locale, 'addCoverImage', fallback.addCoverImage);

  @override
  String get addDescription => OtaTranslationService.translate(locale, 'addDescription', fallback.addDescription);

  @override
  String get addDescriptionOptional => OtaTranslationService.translate(locale, 'addDescriptionOptional', fallback.addDescriptionOptional);

  @override
  String get addFriend => OtaTranslationService.translate(locale, 'addFriend', fallback.addFriend);

  @override
  String get addMembersToChat => OtaTranslationService.translate(locale, 'addMembersToChat', fallback.addMembersToChat);

  @override
  String get addMoreInterests => OtaTranslationService.translate(locale, 'addMoreInterests', fallback.addMoreInterests);

  @override
  String get addPollOption => OtaTranslationService.translate(locale, 'addPollOption', fallback.addPollOption);

  @override
  String get addQuizQuestion => OtaTranslationService.translate(locale, 'addQuizQuestion', fallback.addQuizQuestion);

  @override
  String get addSomething => OtaTranslationService.translate(locale, 'addSomething', fallback.addSomething);

  @override
  String get addYourComment => OtaTranslationService.translate(locale, 'addYourComment', fallback.addYourComment);

  @override
  String get addYourInterests => OtaTranslationService.translate(locale, 'addYourInterests', fallback.addYourInterests);

  @override
  String get adminTools => OtaTranslationService.translate(locale, 'adminTools', fallback.adminTools);

  @override
  String get advanced => OtaTranslationService.translate(locale, 'advanced', fallback.advanced);

  @override
  String get advancedSettings => OtaTranslationService.translate(locale, 'advancedSettings', fallback.advancedSettings);

  @override
  String get all => OtaTranslationService.translate(locale, 'all', fallback.all);

  @override
  String get allCommunities => OtaTranslationService.translate(locale, 'allCommunities', fallback.allCommunities);

  @override
  String get allLabel => OtaTranslationService.translate(locale, 'allLabel', fallback.allLabel);

  @override
  String get allMembers => OtaTranslationService.translate(locale, 'allMembers', fallback.allMembers);

  @override
  String get allPosts => OtaTranslationService.translate(locale, 'allPosts', fallback.allPosts);

  @override
  String get allowChatInvites => OtaTranslationService.translate(locale, 'allowChatInvites', fallback.allowChatInvites);

  @override
  String get allowChatInvitesDesc => OtaTranslationService.translate(locale, 'allowChatInvitesDesc', fallback.allowChatInvitesDesc);

  @override
  String get allowCommentsDesc => OtaTranslationService.translate(locale, 'allowCommentsDesc', fallback.allowCommentsDesc);

  @override
  String get allowContentHighlightDesc => OtaTranslationService.translate(locale, 'allowContentHighlightDesc', fallback.allowContentHighlightDesc);

  @override
  String get allowDirectMessages => OtaTranslationService.translate(locale, 'allowDirectMessages', fallback.allowDirectMessages);

  @override
  String get allowDirectMessagesDesc => OtaTranslationService.translate(locale, 'allowDirectMessagesDesc', fallback.allowDirectMessagesDesc);

  @override
  String get allowFollowers => OtaTranslationService.translate(locale, 'allowFollowers', fallback.allowFollowers);

  @override
  String get allowFollowersDesc => OtaTranslationService.translate(locale, 'allowFollowersDesc', fallback.allowFollowersDesc);

  @override
  String get allowMentionsDesc => OtaTranslationService.translate(locale, 'allowMentionsDesc', fallback.allowMentionsDesc);

  @override
  String get allowProfileComments => OtaTranslationService.translate(locale, 'allowProfileComments', fallback.allowProfileComments);

  @override
  String get allowProfileCommentsDesc => OtaTranslationService.translate(locale, 'allowProfileCommentsDesc', fallback.allowProfileCommentsDesc);

  @override
  String get allowProps => OtaTranslationService.translate(locale, 'allowProps', fallback.allowProps);

  @override
  String get allowPropsDesc => OtaTranslationService.translate(locale, 'allowPropsDesc', fallback.allowPropsDesc);

  @override
  String get allowWallComments => OtaTranslationService.translate(locale, 'allowWallComments', fallback.allowWallComments);

  @override
  String get allowWallCommentsDesc => OtaTranslationService.translate(locale, 'allowWallCommentsDesc', fallback.allowWallCommentsDesc);

  @override
  String get amount => OtaTranslationService.translate(locale, 'amount', fallback.amount);

  @override
  String get anErrorOccurred => OtaTranslationService.translate(locale, 'anErrorOccurred', fallback.anErrorOccurred);

  @override
  String get anErrorOccurredWhile => OtaTranslationService.translate(locale, 'anErrorOccurredWhile', fallback.anErrorOccurredWhile);

  @override
  String get and => OtaTranslationService.translate(locale, 'and', fallback.and);

  @override
  String get animation => OtaTranslationService.translate(locale, 'animation', fallback.animation);

  @override
  String get appearOffline => OtaTranslationService.translate(locale, 'appearOffline', fallback.appearOffline);

  @override
  String get applyTheme => OtaTranslationService.translate(locale, 'applyTheme', fallback.applyTheme);

  @override
  String get approveEntry => OtaTranslationService.translate(locale, 'approveEntry', fallback.approveEntry);

  @override
  String get approveJoinRequests => OtaTranslationService.translate(locale, 'approveJoinRequests', fallback.approveJoinRequests);

  @override
  String get approveJoinRequestsDesc => OtaTranslationService.translate(locale, 'approveJoinRequestsDesc', fallback.approveJoinRequestsDesc);

  @override
  String get approveWikiSubmission => OtaTranslationService.translate(locale, 'approveWikiSubmission', fallback.approveWikiSubmission);

  @override
  String get approvedEntries => OtaTranslationService.translate(locale, 'approvedEntries', fallback.approvedEntries);

  @override
  String get areYouSure => OtaTranslationService.translate(locale, 'areYouSure', fallback.areYouSure);

  @override
  String get areYouSureBan => OtaTranslationService.translate(locale, 'areYouSureBan', fallback.areYouSureBan);

  @override
  String get areYouSureDelete => OtaTranslationService.translate(locale, 'areYouSureDelete', fallback.areYouSureDelete);

  @override
  String get areYouSureDeleteAccount => OtaTranslationService.translate(locale, 'areYouSureDeleteAccount', fallback.areYouSureDeleteAccount);

  @override
  String get areYouSureDeletePost => OtaTranslationService.translate(locale, 'areYouSureDeletePost', fallback.areYouSureDeletePost);

  @override
  String get areYouSureKick => OtaTranslationService.translate(locale, 'areYouSureKick', fallback.areYouSureKick);

  @override
  String get areYouSureLeave => OtaTranslationService.translate(locale, 'areYouSureLeave', fallback.areYouSureLeave);

  @override
  String get areYouSureMute => OtaTranslationService.translate(locale, 'areYouSureMute', fallback.areYouSureMute);

  @override
  String get areYouSureReject => OtaTranslationService.translate(locale, 'areYouSureReject', fallback.areYouSureReject);

  @override
  String get areYouSureRemove => OtaTranslationService.translate(locale, 'areYouSureRemove', fallback.areYouSureRemove);

  @override
  String get areYouSureRevoke => OtaTranslationService.translate(locale, 'areYouSureRevoke', fallback.areYouSureRevoke);

  @override
  String get areYouSureStrike => OtaTranslationService.translate(locale, 'areYouSureStrike', fallback.areYouSureStrike);

  @override
  String get areYouSureUnban => OtaTranslationService.translate(locale, 'areYouSureUnban', fallback.areYouSureUnban);

  @override
  String get areYouSureUnfollowUser => OtaTranslationService.translate(locale, 'areYouSureUnfollowUser', fallback.areYouSureUnfollowUser);

  @override
  String get areYouSureWarn => OtaTranslationService.translate(locale, 'areYouSureWarn', fallback.areYouSureWarn);

  @override
  String get article => OtaTranslationService.translate(locale, 'article', fallback.article);

  @override
  String get askJoinCommunity => OtaTranslationService.translate(locale, 'askJoinCommunity', fallback.askJoinCommunity);

  @override
  String get attachFile => OtaTranslationService.translate(locale, 'attachFile', fallback.attachFile);

  @override
  String get attachMedia => OtaTranslationService.translate(locale, 'attachMedia', fallback.attachMedia);

  @override
  String get author => OtaTranslationService.translate(locale, 'author', fallback.author);

  @override
  String get autoPlayVideos => OtaTranslationService.translate(locale, 'autoPlayVideos', fallback.autoPlayVideos);

  @override
  String get autoPlayVideosDesc => OtaTranslationService.translate(locale, 'autoPlayVideosDesc', fallback.autoPlayVideosDesc);

  @override
  String get avatar => OtaTranslationService.translate(locale, 'avatar', fallback.avatar);

  @override
  String get avatarAndCover => OtaTranslationService.translate(locale, 'avatarAndCover', fallback.avatarAndCover);

  @override
  String get banUser => OtaTranslationService.translate(locale, 'banUser', fallback.banUser);

  @override
  String get banUserFromChat => OtaTranslationService.translate(locale, 'banUserFromChat', fallback.banUserFromChat);

  @override
  String get banned => OtaTranslationService.translate(locale, 'banned', fallback.banned);

  @override
  String get beTheFirstToComment => OtaTranslationService.translate(locale, 'beTheFirstToComment', fallback.beTheFirstToComment);

  @override
  String get beTheFirstToPost => OtaTranslationService.translate(locale, 'beTheFirstToPost', fallback.beTheFirstToPost);

  @override
  String get blockUser => OtaTranslationService.translate(locale, 'blockUser', fallback.blockUser);

  @override
  String get blocked => OtaTranslationService.translate(locale, 'blocked', fallback.blocked);

  @override
  String get blogLabel => OtaTranslationService.translate(locale, 'blogLabel', fallback.blogLabel);

  @override
  String get blogs => OtaTranslationService.translate(locale, 'blogs', fallback.blogs);

  @override
  String get bookmarkAdded => OtaTranslationService.translate(locale, 'bookmarkAdded', fallback.bookmarkAdded);

  @override
  String get bookmarkRemoved => OtaTranslationService.translate(locale, 'bookmarkRemoved', fallback.bookmarkRemoved);

  @override
  String get broadcast => OtaTranslationService.translate(locale, 'broadcast', fallback.broadcast);

  @override
  String get broadcastMessage => OtaTranslationService.translate(locale, 'broadcastMessage', fallback.broadcastMessage);

  @override
  String get broadcastNotification => OtaTranslationService.translate(locale, 'broadcastNotification', fallback.broadcastNotification);

  @override
  String get broadcastTitle => OtaTranslationService.translate(locale, 'broadcastTitle', fallback.broadcastTitle);

  @override
  String get by => OtaTranslationService.translate(locale, 'by', fallback.by);

  @override
  String get call => OtaTranslationService.translate(locale, 'call', fallback.call);

  @override
  String get cameraPermission => OtaTranslationService.translate(locale, 'cameraPermission', fallback.cameraPermission);

  @override
  String get cannotBeEmpty => OtaTranslationService.translate(locale, 'cannotBeEmpty', fallback.cannotBeEmpty);

  @override
  String get cannotBeUndone => OtaTranslationService.translate(locale, 'cannotBeUndone', fallback.cannotBeUndone);

  @override
  String get cannotRemoveLastLeader => OtaTranslationService.translate(locale, 'cannotRemoveLastLeader', fallback.cannotRemoveLastLeader);

  @override
  String get cannotReportYourself => OtaTranslationService.translate(locale, 'cannotReportYourself', fallback.cannotReportYourself);

  @override
  String get caption => OtaTranslationService.translate(locale, 'caption', fallback.caption);

  @override
  String get category => OtaTranslationService.translate(locale, 'category', fallback.category);

  @override
  String get changeCommunity => OtaTranslationService.translate(locale, 'changeCommunity', fallback.changeCommunity);

  @override
  String get changeCover => OtaTranslationService.translate(locale, 'changeCover', fallback.changeCover);

  @override
  String get changeNickname => OtaTranslationService.translate(locale, 'changeNickname', fallback.changeNickname);

  @override
  String get changePassword => OtaTranslationService.translate(locale, 'changePassword', fallback.changePassword);

  @override
  String get changePhoto => OtaTranslationService.translate(locale, 'changePhoto', fallback.changePhoto);

  @override
  String get changeUsername => OtaTranslationService.translate(locale, 'changeUsername', fallback.changeUsername);

  @override
  String get chatInvites => OtaTranslationService.translate(locale, 'chatInvites', fallback.chatInvites);

  @override
  String get chatSettings => OtaTranslationService.translate(locale, 'chatSettings', fallback.chatSettings);

  @override
  String get chatWallpaper => OtaTranslationService.translate(locale, 'chatWallpaper', fallback.chatWallpaper);

  @override
  String get chooseACommunity => OtaTranslationService.translate(locale, 'chooseACommunity', fallback.chooseACommunity);

  @override
  String get chooseACover => OtaTranslationService.translate(locale, 'chooseACover', fallback.chooseACover);

  @override
  String get chooseAnImage => OtaTranslationService.translate(locale, 'chooseAnImage', fallback.chooseAnImage);

  @override
  String get chooseCategory => OtaTranslationService.translate(locale, 'chooseCategory', fallback.chooseCategory);

  @override
  String get chooseColor => OtaTranslationService.translate(locale, 'chooseColor', fallback.chooseColor);

  @override
  String get chooseCover => OtaTranslationService.translate(locale, 'chooseCover', fallback.chooseCover);

  @override
  String get chooseDuration => OtaTranslationService.translate(locale, 'chooseDuration', fallback.chooseDuration);

  @override
  String get chooseImage => OtaTranslationService.translate(locale, 'chooseImage', fallback.chooseImage);

  @override
  String get chooseLanguage => OtaTranslationService.translate(locale, 'chooseLanguage', fallback.chooseLanguage);

  @override
  String get chooseLayout => OtaTranslationService.translate(locale, 'chooseLayout', fallback.chooseLayout);

  @override
  String get chooseNicknameDesc => OtaTranslationService.translate(locale, 'chooseNicknameDesc', fallback.chooseNicknameDesc);

  @override
  String get chooseOption => OtaTranslationService.translate(locale, 'chooseOption', fallback.chooseOption);

  @override
  String get choosePollEndDate => OtaTranslationService.translate(locale, 'choosePollEndDate', fallback.choosePollEndDate);

  @override
  String get chooseReason => OtaTranslationService.translate(locale, 'chooseReason', fallback.chooseReason);

  @override
  String get chooseSticker => OtaTranslationService.translate(locale, 'chooseSticker', fallback.chooseSticker);

  @override
  String get chooseTheme => OtaTranslationService.translate(locale, 'chooseTheme', fallback.chooseTheme);

  @override
  String get chooseVisibility => OtaTranslationService.translate(locale, 'chooseVisibility', fallback.chooseVisibility);

  @override
  String get clearAll => OtaTranslationService.translate(locale, 'clearAll', fallback.clearAll);

  @override
  String get clearCacheConfirmation => OtaTranslationService.translate(locale, 'clearCacheConfirmation', fallback.clearCacheConfirmation);

  @override
  String get clearHistory => OtaTranslationService.translate(locale, 'clearHistory', fallback.clearHistory);

  @override
  String get clearHistoryConfirmation => OtaTranslationService.translate(locale, 'clearHistoryConfirmation', fallback.clearHistoryConfirmation);

  @override
  String get clearRecentSearches => OtaTranslationService.translate(locale, 'clearRecentSearches', fallback.clearRecentSearches);

  @override
  String get closeAndSaveChanges => OtaTranslationService.translate(locale, 'closeAndSaveChanges', fallback.closeAndSaveChanges);

  @override
  String get coinBalance => OtaTranslationService.translate(locale, 'coinBalance', fallback.coinBalance);

  @override
  String get coinHistory => OtaTranslationService.translate(locale, 'coinHistory', fallback.coinHistory);

  @override
  String get coins => OtaTranslationService.translate(locale, 'coins', fallback.coins);

  @override
  String get coinsSpent => OtaTranslationService.translate(locale, 'coinsSpent', fallback.coinsSpent);

  @override
  String get collapse => OtaTranslationService.translate(locale, 'collapse', fallback.collapse);

  @override
  String get color => OtaTranslationService.translate(locale, 'color', fallback.color);

  @override
  String get commentDeleted => OtaTranslationService.translate(locale, 'commentDeleted', fallback.commentDeleted);

  @override
  String get commentNotifications => OtaTranslationService.translate(locale, 'commentNotifications', fallback.commentNotifications);

  @override
  String get commentOptions => OtaTranslationService.translate(locale, 'commentOptions', fallback.commentOptions);

  @override
  String get commentSent => OtaTranslationService.translate(locale, 'commentSent', fallback.commentSent);

  @override
  String get commentsLabel => OtaTranslationService.translate(locale, 'commentsLabel', fallback.commentsLabel);

  @override
  String get commentsOnYourProfile => OtaTranslationService.translate(locale, 'commentsOnYourProfile', fallback.commentsOnYourProfile);

  @override
  String get communityCreated => OtaTranslationService.translate(locale, 'communityCreated', fallback.communityCreated);

  @override
  String get communityDeleted => OtaTranslationService.translate(locale, 'communityDeleted', fallback.communityDeleted);

  @override
  String get communityDescriptionHint => OtaTranslationService.translate(locale, 'communityDescriptionHint', fallback.communityDescriptionHint);

  @override
  String get communityGuidelinesShort => OtaTranslationService.translate(locale, 'communityGuidelinesShort', fallback.communityGuidelinesShort);

  @override
  String get communityInvites => OtaTranslationService.translate(locale, 'communityInvites', fallback.communityInvites);

  @override
  String get communityLeader => OtaTranslationService.translate(locale, 'communityLeader', fallback.communityLeader);

  @override
  String get communityLink => OtaTranslationService.translate(locale, 'communityLink', fallback.communityLink);

  @override
  String get communityMembers => OtaTranslationService.translate(locale, 'communityMembers', fallback.communityMembers);

  @override
  String get communityModeration => OtaTranslationService.translate(locale, 'communityModeration', fallback.communityModeration);

  @override
  String get communityNameHint => OtaTranslationService.translate(locale, 'communityNameHint', fallback.communityNameHint);

  @override
  String get communityPrivacy => OtaTranslationService.translate(locale, 'communityPrivacy', fallback.communityPrivacy);

  @override
  String get communitySettings => OtaTranslationService.translate(locale, 'communitySettings', fallback.communitySettings);

  @override
  String get communityStats => OtaTranslationService.translate(locale, 'communityStats', fallback.communityStats);

  @override
  String get communityTheme => OtaTranslationService.translate(locale, 'communityTheme', fallback.communityTheme);

  @override
  String get communityUpdated => OtaTranslationService.translate(locale, 'communityUpdated', fallback.communityUpdated);

  @override
  String get confirmAction => OtaTranslationService.translate(locale, 'confirmAction', fallback.confirmAction);

  @override
  String get confirmAndContinue => OtaTranslationService.translate(locale, 'confirmAndContinue', fallback.confirmAndContinue);

  @override
  String get confirmBlockUser => OtaTranslationService.translate(locale, 'confirmBlockUser', fallback.confirmBlockUser);

  @override
  String get confirmChanges => OtaTranslationService.translate(locale, 'confirmChanges', fallback.confirmChanges);

  @override
  String get confirmDelete => OtaTranslationService.translate(locale, 'confirmDelete', fallback.confirmDelete);

  @override
  String get confirmDeleteAccount => OtaTranslationService.translate(locale, 'confirmDeleteAccount', fallback.confirmDeleteAccount);

  @override
  String get confirmDeleteConversation => OtaTranslationService.translate(locale, 'confirmDeleteConversation', fallback.confirmDeleteConversation);

  @override
  String get confirmDeleteFile => OtaTranslationService.translate(locale, 'confirmDeleteFile', fallback.confirmDeleteFile);

  @override
  String get confirmEmail => OtaTranslationService.translate(locale, 'confirmEmail', fallback.confirmEmail);

  @override
  String get confirmLeave => OtaTranslationService.translate(locale, 'confirmLeave', fallback.confirmLeave);

  @override
  String get confirmLeaveCommunity => OtaTranslationService.translate(locale, 'confirmLeaveCommunity', fallback.confirmLeaveCommunity);

  @override
  String get confirmLeaveGroup => OtaTranslationService.translate(locale, 'confirmLeaveGroup', fallback.confirmLeaveGroup);

  @override
  String get confirmLogout => OtaTranslationService.translate(locale, 'confirmLogout', fallback.confirmLogout);

  @override
  String get confirmNewPassword => OtaTranslationService.translate(locale, 'confirmNewPassword', fallback.confirmNewPassword);

  @override
  String get confirmPurchase => OtaTranslationService.translate(locale, 'confirmPurchase', fallback.confirmPurchase);

  @override
  String get confirmReport => OtaTranslationService.translate(locale, 'confirmReport', fallback.confirmReport);

  @override
  String get confirmSelection => OtaTranslationService.translate(locale, 'confirmSelection', fallback.confirmSelection);

  @override
  String get confirmUnfollow => OtaTranslationService.translate(locale, 'confirmUnfollow', fallback.confirmUnfollow);

  @override
  String get connectWithFriends => OtaTranslationService.translate(locale, 'connectWithFriends', fallback.connectWithFriends);

  @override
  String get connecting => OtaTranslationService.translate(locale, 'connecting', fallback.connecting);

  @override
  String get contactUs => OtaTranslationService.translate(locale, 'contactUs', fallback.contactUs);

  @override
  String get contentAndConduct => OtaTranslationService.translate(locale, 'contentAndConduct', fallback.contentAndConduct);

  @override
  String get contentFormat => OtaTranslationService.translate(locale, 'contentFormat', fallback.contentFormat);

  @override
  String get contentLabel => OtaTranslationService.translate(locale, 'contentLabel', fallback.contentLabel);

  @override
  String get contentPolicies => OtaTranslationService.translate(locale, 'contentPolicies', fallback.contentPolicies);

  @override
  String get continueAnyway => OtaTranslationService.translate(locale, 'continueAnyway', fallback.continueAnyway);

  @override
  String get continueWithEmail => OtaTranslationService.translate(locale, 'continueWithEmail', fallback.continueWithEmail);

  @override
  String get copiedToClipboardMsg => OtaTranslationService.translate(locale, 'copiedToClipboardMsg', fallback.copiedToClipboardMsg);

  @override
  String get copyAction => OtaTranslationService.translate(locale, 'copyAction', fallback.copyAction);

  @override
  String get copyLinkAction => OtaTranslationService.translate(locale, 'copyLinkAction', fallback.copyLinkAction);

  @override
  String get copyPostLink => OtaTranslationService.translate(locale, 'copyPostLink', fallback.copyPostLink);

  @override
  String get copyProfileLink => OtaTranslationService.translate(locale, 'copyProfileLink', fallback.copyProfileLink);

  @override
  String get copyToClipboard => OtaTranslationService.translate(locale, 'copyToClipboard', fallback.copyToClipboard);

  @override
  String get couldNotLaunchUrl => OtaTranslationService.translate(locale, 'couldNotLaunchUrl', fallback.couldNotLaunchUrl);

  @override
  String get createAPoll => OtaTranslationService.translate(locale, 'createAPoll', fallback.createAPoll);

  @override
  String get createAQuiz => OtaTranslationService.translate(locale, 'createAQuiz', fallback.createAQuiz);

  @override
  String get createChat => OtaTranslationService.translate(locale, 'createChat', fallback.createChat);

  @override
  String get createEvent => OtaTranslationService.translate(locale, 'createEvent', fallback.createEvent);

  @override
  String get createFirstPost => OtaTranslationService.translate(locale, 'createFirstPost', fallback.createFirstPost);

  @override
  String get createFolder => OtaTranslationService.translate(locale, 'createFolder', fallback.createFolder);

  @override
  String get createYourAccount => OtaTranslationService.translate(locale, 'createYourAccount', fallback.createYourAccount);

  @override
  String get createYourCommunity => OtaTranslationService.translate(locale, 'createYourCommunity', fallback.createYourCommunity);

  @override
  String get created => OtaTranslationService.translate(locale, 'created', fallback.created);

  @override
  String get createdBy => OtaTranslationService.translate(locale, 'createdBy', fallback.createdBy);

  @override
  String get creating => OtaTranslationService.translate(locale, 'creating', fallback.creating);

  @override
  String get creatingAccount => OtaTranslationService.translate(locale, 'creatingAccount', fallback.creatingAccount);

  @override
  String get creatingCommunity => OtaTranslationService.translate(locale, 'creatingCommunity', fallback.creatingCommunity);

  @override
  String get creatingPost => OtaTranslationService.translate(locale, 'creatingPost', fallback.creatingPost);

  @override
  String get creative => OtaTranslationService.translate(locale, 'creative', fallback.creative);

  @override
  String get custom => OtaTranslationService.translate(locale, 'custom', fallback.custom);

  @override
  String get customColor => OtaTranslationService.translate(locale, 'customColor', fallback.customColor);

  @override
  String get customImage => OtaTranslationService.translate(locale, 'customImage', fallback.customImage);

  @override
  String get customTheme => OtaTranslationService.translate(locale, 'customTheme', fallback.customTheme);

  @override
  String get customize => OtaTranslationService.translate(locale, 'customize', fallback.customize);

  @override
  String get dailyActiveMembers => OtaTranslationService.translate(locale, 'dailyActiveMembers', fallback.dailyActiveMembers);

  @override
  String get dailyBonus => OtaTranslationService.translate(locale, 'dailyBonus', fallback.dailyBonus);

  @override
  String get dailyCheckInCoins => OtaTranslationService.translate(locale, 'dailyCheckInCoins', fallback.dailyCheckInCoins);

  @override
  String get dailyCheckInDesc => OtaTranslationService.translate(locale, 'dailyCheckInDesc', fallback.dailyCheckInDesc);

  @override
  String get dailyCheckInHistory => OtaTranslationService.translate(locale, 'dailyCheckInHistory', fallback.dailyCheckInHistory);

  @override
  String get dailyCheckInReward => OtaTranslationService.translate(locale, 'dailyCheckInReward', fallback.dailyCheckInReward);

  @override
  String get dailyCheckInStreak => OtaTranslationService.translate(locale, 'dailyCheckInStreak', fallback.dailyCheckInStreak);

  @override
  String get dark => OtaTranslationService.translate(locale, 'dark', fallback.dark);

  @override
  String get dataAndStorage => OtaTranslationService.translate(locale, 'dataAndStorage', fallback.dataAndStorage);

  @override
  String get dataExport => OtaTranslationService.translate(locale, 'dataExport', fallback.dataExport);

  @override
  String get dataExportDesc => OtaTranslationService.translate(locale, 'dataExportDesc', fallback.dataExportDesc);

  @override
  String get dataProcessing => OtaTranslationService.translate(locale, 'dataProcessing', fallback.dataProcessing);

  @override
  String get dataUsage => OtaTranslationService.translate(locale, 'dataUsage', fallback.dataUsage);

  @override
  String get dateJoined => OtaTranslationService.translate(locale, 'dateJoined', fallback.dateJoined);

  @override
  String get deactivateAccount => OtaTranslationService.translate(locale, 'deactivateAccount', fallback.deactivateAccount);

  @override
  String get defaultLabel => OtaTranslationService.translate(locale, 'defaultLabel', fallback.defaultLabel);

  @override
  String get deleteAccountConfirmation => OtaTranslationService.translate(locale, 'deleteAccountConfirmation', fallback.deleteAccountConfirmation);

  @override
  String get deleteChat => OtaTranslationService.translate(locale, 'deleteChat', fallback.deleteChat);

  @override
  String get deleteChatConfirmation => OtaTranslationService.translate(locale, 'deleteChatConfirmation', fallback.deleteChatConfirmation);

  @override
  String get deleteComment => OtaTranslationService.translate(locale, 'deleteComment', fallback.deleteComment);

  @override
  String get deleteCommentConfirmation => OtaTranslationService.translate(locale, 'deleteCommentConfirmation', fallback.deleteCommentConfirmation);

  @override
  String get deleteDraft => OtaTranslationService.translate(locale, 'deleteDraft', fallback.deleteDraft);

  @override
  String get deleteForEveryone => OtaTranslationService.translate(locale, 'deleteForEveryone', fallback.deleteForEveryone);

  @override
  String get deleteForMe => OtaTranslationService.translate(locale, 'deleteForMe', fallback.deleteForMe);

  @override
  String get deleteFromHistory => OtaTranslationService.translate(locale, 'deleteFromHistory', fallback.deleteFromHistory);

  @override
  String get deleteMessageConfirmation => OtaTranslationService.translate(locale, 'deleteMessageConfirmation', fallback.deleteMessageConfirmation);

  @override
  String get deletePermanently => OtaTranslationService.translate(locale, 'deletePermanently', fallback.deletePermanently);

  @override
  String get deletePostConfirmation => OtaTranslationService.translate(locale, 'deletePostConfirmation', fallback.deletePostConfirmation);

  @override
  String get deleteStory => OtaTranslationService.translate(locale, 'deleteStory', fallback.deleteStory);

  @override
  String get deleteStoryConfirmation => OtaTranslationService.translate(locale, 'deleteStoryConfirmation', fallback.deleteStoryConfirmation);

  @override
  String get deleteWiki => OtaTranslationService.translate(locale, 'deleteWiki', fallback.deleteWiki);

  @override
  String get deleteWikiConfirmation => OtaTranslationService.translate(locale, 'deleteWikiConfirmation', fallback.deleteWikiConfirmation);

  @override
  String get describeYourCommunity => OtaTranslationService.translate(locale, 'describeYourCommunity', fallback.describeYourCommunity);

  @override
  String get description => OtaTranslationService.translate(locale, 'description', fallback.description);

  @override
  String get details => OtaTranslationService.translate(locale, 'details', fallback.details);

  @override
  String get deviceAndOs => OtaTranslationService.translate(locale, 'deviceAndOs', fallback.deviceAndOs);

  @override
  String get deviceManager => OtaTranslationService.translate(locale, 'deviceManager', fallback.deviceManager);

  @override
  String get deviceName => OtaTranslationService.translate(locale, 'deviceName', fallback.deviceName);

  @override
  String get deviceNotSupported => OtaTranslationService.translate(locale, 'deviceNotSupported', fallback.deviceNotSupported);

  @override
  String get disable => OtaTranslationService.translate(locale, 'disable', fallback.disable);

  @override
  String get disableAccount => OtaTranslationService.translate(locale, 'disableAccount', fallback.disableAccount);

  @override
  String get disableAccountConfirmation => OtaTranslationService.translate(locale, 'disableAccountConfirmation', fallback.disableAccountConfirmation);

  @override
  String get disableComments => OtaTranslationService.translate(locale, 'disableComments', fallback.disableComments);

  @override
  String get disabled => OtaTranslationService.translate(locale, 'disabled', fallback.disabled);

  @override
  String get discard => OtaTranslationService.translate(locale, 'discard', fallback.discard);

  @override
  String get discardChanges => OtaTranslationService.translate(locale, 'discardChanges', fallback.discardChanges);

  @override
  String get discardDraft => OtaTranslationService.translate(locale, 'discardDraft', fallback.discardDraft);

  @override
  String get disconnected => OtaTranslationService.translate(locale, 'disconnected', fallback.disconnected);

  @override
  String get discoverLabel => OtaTranslationService.translate(locale, 'discoverLabel', fallback.discoverLabel);

  @override
  String get discoverMore => OtaTranslationService.translate(locale, 'discoverMore', fallback.discoverMore);

  @override
  String get discussion => OtaTranslationService.translate(locale, 'discussion', fallback.discussion);

  @override
  String get discussions => OtaTranslationService.translate(locale, 'discussions', fallback.discussions);

  @override
  String get dismiss => OtaTranslationService.translate(locale, 'dismiss', fallback.dismiss);

  @override
  String get doNotShowAgain => OtaTranslationService.translate(locale, 'doNotShowAgain', fallback.doNotShowAgain);

  @override
  String get doneEditing => OtaTranslationService.translate(locale, 'doneEditing', fallback.doneEditing);

  @override
  String get download => OtaTranslationService.translate(locale, 'download', fallback.download);

  @override
  String get downloadData => OtaTranslationService.translate(locale, 'downloadData', fallback.downloadData);

  @override
  String get downloading => OtaTranslationService.translate(locale, 'downloading', fallback.downloading);

  @override
  String get draftDiscarded => OtaTranslationService.translate(locale, 'draftDiscarded', fallback.draftDiscarded);

  @override
  String get draftNotFound => OtaTranslationService.translate(locale, 'draftNotFound', fallback.draftNotFound);

  @override
  String get draftPublished => OtaTranslationService.translate(locale, 'draftPublished', fallback.draftPublished);

  @override
  String get duplicateContent => OtaTranslationService.translate(locale, 'duplicateContent', fallback.duplicateContent);

  @override
  String get earnCoins => OtaTranslationService.translate(locale, 'earnCoins', fallback.earnCoins);

  @override
  String get editBio => OtaTranslationService.translate(locale, 'editBio', fallback.editBio);

  @override
  String get editChat => OtaTranslationService.translate(locale, 'editChat', fallback.editChat);

  @override
  String get editCommunity => OtaTranslationService.translate(locale, 'editCommunity', fallback.editCommunity);

  @override
  String get editCover => OtaTranslationService.translate(locale, 'editCover', fallback.editCover);

  @override
  String get editDraft => OtaTranslationService.translate(locale, 'editDraft', fallback.editDraft);

  @override
  String get editEntry => OtaTranslationService.translate(locale, 'editEntry', fallback.editEntry);

  @override
  String get editImage => OtaTranslationService.translate(locale, 'editImage', fallback.editImage);

  @override
  String get editNickname => OtaTranslationService.translate(locale, 'editNickname', fallback.editNickname);

  @override
  String get editPoll => OtaTranslationService.translate(locale, 'editPoll', fallback.editPoll);

  @override
  String get editPostPermission => OtaTranslationService.translate(locale, 'editPostPermission', fallback.editPostPermission);

  @override
  String get editPostTitle => OtaTranslationService.translate(locale, 'editPostTitle', fallback.editPostTitle);

  @override
  String get editProfileLabel => OtaTranslationService.translate(locale, 'editProfileLabel', fallback.editProfileLabel);

  @override
  String get editQuiz => OtaTranslationService.translate(locale, 'editQuiz', fallback.editQuiz);

  @override
  String get editStory => OtaTranslationService.translate(locale, 'editStory', fallback.editStory);

  @override
  String get editTags => OtaTranslationService.translate(locale, 'editTags', fallback.editTags);

  @override
  String get editThePost => OtaTranslationService.translate(locale, 'editThePost', fallback.editThePost);

  @override
  String get editTheme => OtaTranslationService.translate(locale, 'editTheme', fallback.editTheme);

  @override
  String get editTitle => OtaTranslationService.translate(locale, 'editTitle', fallback.editTitle);

  @override
  String get editWiki => OtaTranslationService.translate(locale, 'editWiki', fallback.editWiki);

  @override
  String get editYourProfile => OtaTranslationService.translate(locale, 'editYourProfile', fallback.editYourProfile);

  @override
  String get emailAddress => OtaTranslationService.translate(locale, 'emailAddress', fallback.emailAddress);

  @override
  String get emailInUse => OtaTranslationService.translate(locale, 'emailInUse', fallback.emailInUse);

  @override
  String get emailIsRequired => OtaTranslationService.translate(locale, 'emailIsRequired', fallback.emailIsRequired);

  @override
  String get emailNotVerified => OtaTranslationService.translate(locale, 'emailNotVerified', fallback.emailNotVerified);

  @override
  String get emailSent => OtaTranslationService.translate(locale, 'emailSent', fallback.emailSent);

  @override
  String get emailVerified => OtaTranslationService.translate(locale, 'emailVerified', fallback.emailVerified);

  @override
  String get empty => OtaTranslationService.translate(locale, 'empty', fallback.empty);

  @override
  String get emptyChat => OtaTranslationService.translate(locale, 'emptyChat', fallback.emptyChat);

  @override
  String get emptyChatStart => OtaTranslationService.translate(locale, 'emptyChatStart', fallback.emptyChatStart);

  @override
  String get emptyFeed => OtaTranslationService.translate(locale, 'emptyFeed', fallback.emptyFeed);

  @override
  String get emptyFeedFollow => OtaTranslationService.translate(locale, 'emptyFeedFollow', fallback.emptyFeedFollow);

  @override
  String get emptyWall => OtaTranslationService.translate(locale, 'emptyWall', fallback.emptyWall);

  @override
  String get enable => OtaTranslationService.translate(locale, 'enable', fallback.enable);

  @override
  String get enableModule => OtaTranslationService.translate(locale, 'enableModule', fallback.enableModule);

  @override
  String get enablePushNotifications => OtaTranslationService.translate(locale, 'enablePushNotifications', fallback.enablePushNotifications);

  @override
  String get enabled => OtaTranslationService.translate(locale, 'enabled', fallback.enabled);

  @override
  String get endDate => OtaTranslationService.translate(locale, 'endDate', fallback.endDate);

  @override
  String get endPoll => OtaTranslationService.translate(locale, 'endPoll', fallback.endPoll);

  @override
  String get endQuiz => OtaTranslationService.translate(locale, 'endQuiz', fallback.endQuiz);

  @override
  String get english => OtaTranslationService.translate(locale, 'english', fallback.english);

  @override
  String get enterADescription => OtaTranslationService.translate(locale, 'enterADescription', fallback.enterADescription);

  @override
  String get enterAName => OtaTranslationService.translate(locale, 'enterAName', fallback.enterAName);

  @override
  String get enterATitle => OtaTranslationService.translate(locale, 'enterATitle', fallback.enterATitle);

  @override
  String get enterCode => OtaTranslationService.translate(locale, 'enterCode', fallback.enterCode);

  @override
  String get enterCommunityName => OtaTranslationService.translate(locale, 'enterCommunityName', fallback.enterCommunityName);

  @override
  String get enterCurrentPassword => OtaTranslationService.translate(locale, 'enterCurrentPassword', fallback.enterCurrentPassword);

  @override
  String get enterDescription => OtaTranslationService.translate(locale, 'enterDescription', fallback.enterDescription);

  @override
  String get enterEmail => OtaTranslationService.translate(locale, 'enterEmail', fallback.enterEmail);

  @override
  String get enterLink => OtaTranslationService.translate(locale, 'enterLink', fallback.enterLink);

  @override
  String get enterNewPassword => OtaTranslationService.translate(locale, 'enterNewPassword', fallback.enterNewPassword);

  @override
  String get enterNickname => OtaTranslationService.translate(locale, 'enterNickname', fallback.enterNickname);

  @override
  String get enterPassword => OtaTranslationService.translate(locale, 'enterPassword', fallback.enterPassword);

  @override
  String get enterReason => OtaTranslationService.translate(locale, 'enterReason', fallback.enterReason);

  @override
  String get enterTheReason => OtaTranslationService.translate(locale, 'enterTheReason', fallback.enterTheReason);

  @override
  String get enterTitle => OtaTranslationService.translate(locale, 'enterTitle', fallback.enterTitle);

  @override
  String get enterYourBio => OtaTranslationService.translate(locale, 'enterYourBio', fallback.enterYourBio);

  @override
  String get enterYourMessage => OtaTranslationService.translate(locale, 'enterYourMessage', fallback.enterYourMessage);

  @override
  String get enterYourNickname => OtaTranslationService.translate(locale, 'enterYourNickname', fallback.enterYourNickname);

  @override
  String get entry => OtaTranslationService.translate(locale, 'entry', fallback.entry);

  @override
  String get entrySubmitted => OtaTranslationService.translate(locale, 'entrySubmitted', fallback.entrySubmitted);

  @override
  String get errorAcceptingInvite => OtaTranslationService.translate(locale, 'errorAcceptingInvite', fallback.errorAcceptingInvite);

  @override
  String get errorAddingMember => OtaTranslationService.translate(locale, 'errorAddingMember', fallback.errorAddingMember);

  @override
  String get errorAddingToFavorites => OtaTranslationService.translate(locale, 'errorAddingToFavorites', fallback.errorAddingToFavorites);

  @override
  String get errorApprovingEntry => OtaTranslationService.translate(locale, 'errorApprovingEntry', fallback.errorApprovingEntry);

  @override
  String get errorBanningUser => OtaTranslationService.translate(locale, 'errorBanningUser', fallback.errorBanningUser);

  @override
  String get errorBlockingUser => OtaTranslationService.translate(locale, 'errorBlockingUser', fallback.errorBlockingUser);

  @override
  String get errorChangingEmail => OtaTranslationService.translate(locale, 'errorChangingEmail', fallback.errorChangingEmail);

  @override
  String get errorChangingNickname => OtaTranslationService.translate(locale, 'errorChangingNickname', fallback.errorChangingNickname);

  @override
  String get errorChangingPassword => OtaTranslationService.translate(locale, 'errorChangingPassword', fallback.errorChangingPassword);

  @override
  String get errorCreatingDraft => OtaTranslationService.translate(locale, 'errorCreatingDraft', fallback.errorCreatingDraft);

  @override
  String get errorCreatingEntry => OtaTranslationService.translate(locale, 'errorCreatingEntry', fallback.errorCreatingEntry);

  @override
  String get errorCreatingFolder => OtaTranslationService.translate(locale, 'errorCreatingFolder', fallback.errorCreatingFolder);

  @override
  String get errorCreatingPost => OtaTranslationService.translate(locale, 'errorCreatingPost', fallback.errorCreatingPost);

  @override
  String get errorCreatingStory => OtaTranslationService.translate(locale, 'errorCreatingStory', fallback.errorCreatingStory);

  @override
  String get errorDeleting => OtaTranslationService.translate(locale, 'errorDeleting', fallback.errorDeleting);

  @override
  String get errorDeletingAccount => OtaTranslationService.translate(locale, 'errorDeletingAccount', fallback.errorDeletingAccount);

  @override
  String get errorDeletingComment => OtaTranslationService.translate(locale, 'errorDeletingComment', fallback.errorDeletingComment);

  @override
  String get errorDeletingDraft => OtaTranslationService.translate(locale, 'errorDeletingDraft', fallback.errorDeletingDraft);

  @override
  String get errorDeletingEntry => OtaTranslationService.translate(locale, 'errorDeletingEntry', fallback.errorDeletingEntry);

  @override
  String get errorDeletingFolder => OtaTranslationService.translate(locale, 'errorDeletingFolder', fallback.errorDeletingFolder);

  @override
  String get errorDeletingMessage => OtaTranslationService.translate(locale, 'errorDeletingMessage', fallback.errorDeletingMessage);

  @override
  String get errorDeletingPost => OtaTranslationService.translate(locale, 'errorDeletingPost', fallback.errorDeletingPost);

  @override
  String get errorDeletingStory => OtaTranslationService.translate(locale, 'errorDeletingStory', fallback.errorDeletingStory);

  @override
  String get errorDownloading => OtaTranslationService.translate(locale, 'errorDownloading', fallback.errorDownloading);

  @override
  String get errorEditingChat => OtaTranslationService.translate(locale, 'errorEditingChat', fallback.errorEditingChat);

  @override
  String get errorEditingEntry => OtaTranslationService.translate(locale, 'errorEditingEntry', fallback.errorEditingEntry);

  @override
  String get errorEditingPost => OtaTranslationService.translate(locale, 'errorEditingPost', fallback.errorEditingPost);

  @override
  String get errorEditingProfile => OtaTranslationService.translate(locale, 'errorEditingProfile', fallback.errorEditingProfile);

  @override
  String get errorFetchingData => OtaTranslationService.translate(locale, 'errorFetchingData', fallback.errorFetchingData);

  @override
  String get errorFetchingFeed => OtaTranslationService.translate(locale, 'errorFetchingFeed', fallback.errorFetchingFeed);

  @override
  String get errorFetchingLink => OtaTranslationService.translate(locale, 'errorFetchingLink', fallback.errorFetchingLink);

  @override
  String get errorFetchingMembers => OtaTranslationService.translate(locale, 'errorFetchingMembers', fallback.errorFetchingMembers);

  @override
  String get errorFetchingNotifications => OtaTranslationService.translate(locale, 'errorFetchingNotifications', fallback.errorFetchingNotifications);

  @override
  String get errorFetchingPosts => OtaTranslationService.translate(locale, 'errorFetchingPosts', fallback.errorFetchingPosts);

  @override
  String get errorFetchingProfile => OtaTranslationService.translate(locale, 'errorFetchingProfile', fallback.errorFetchingProfile);

  @override
  String get errorFetchingResults => OtaTranslationService.translate(locale, 'errorFetchingResults', fallback.errorFetchingResults);

  @override
  String get errorFetchingSettings => OtaTranslationService.translate(locale, 'errorFetchingSettings', fallback.errorFetchingSettings);

  @override
  String get errorFetchingUser => OtaTranslationService.translate(locale, 'errorFetchingUser', fallback.errorFetchingUser);

  @override
  String get errorFetchingWiki => OtaTranslationService.translate(locale, 'errorFetchingWiki', fallback.errorFetchingWiki);

  @override
  String get errorFollowingUser => OtaTranslationService.translate(locale, 'errorFollowingUser', fallback.errorFollowingUser);

  @override
  String get errorJoiningCommunity => OtaTranslationService.translate(locale, 'errorJoiningCommunity', fallback.errorJoiningCommunity);

  @override
  String get errorKickingUser => OtaTranslationService.translate(locale, 'errorKickingUser', fallback.errorKickingUser);

  @override
  String get errorLeavingCommunity => OtaTranslationService.translate(locale, 'errorLeavingCommunity', fallback.errorLeavingCommunity);

  @override
  String get errorLeavingGroup => OtaTranslationService.translate(locale, 'errorLeavingGroup', fallback.errorLeavingGroup);

  @override
  String get errorLoading => OtaTranslationService.translate(locale, 'errorLoading', fallback.errorLoading);

  @override
  String get errorLoadingAchievements => OtaTranslationService.translate(locale, 'errorLoadingAchievements', fallback.errorLoadingAchievements);

  @override
  String get errorLoadingBlockedUsers => OtaTranslationService.translate(locale, 'errorLoadingBlockedUsers', fallback.errorLoadingBlockedUsers);

  @override
  String get errorLoadingCategories => OtaTranslationService.translate(locale, 'errorLoadingCategories', fallback.errorLoadingCategories);

  @override
  String get errorLoadingChat => OtaTranslationService.translate(locale, 'errorLoadingChat', fallback.errorLoadingChat);

  @override
  String get errorLoadingComments => OtaTranslationService.translate(locale, 'errorLoadingComments', fallback.errorLoadingComments);

  @override
  String get errorLoadingCommunities => OtaTranslationService.translate(locale, 'errorLoadingCommunities', fallback.errorLoadingCommunities);

  @override
  String get errorLoadingCommunity => OtaTranslationService.translate(locale, 'errorLoadingCommunity', fallback.errorLoadingCommunity);

  @override
  String get errorLoadingContent => OtaTranslationService.translate(locale, 'errorLoadingContent', fallback.errorLoadingContent);

  @override
  String get errorLoadingDrafts => OtaTranslationService.translate(locale, 'errorLoadingDrafts', fallback.errorLoadingDrafts);

  @override
  String get errorLoadingFollowers => OtaTranslationService.translate(locale, 'errorLoadingFollowers', fallback.errorLoadingFollowers);

  @override
  String get errorLoadingFollowing => OtaTranslationService.translate(locale, 'errorLoadingFollowing', fallback.errorLoadingFollowing);

  @override
  String get errorLoadingHistory => OtaTranslationService.translate(locale, 'errorLoadingHistory', fallback.errorLoadingHistory);

  @override
  String get errorLoadingLeaderboard => OtaTranslationService.translate(locale, 'errorLoadingLeaderboard', fallback.errorLoadingLeaderboard);

  @override
  String get errorLoadingMedia => OtaTranslationService.translate(locale, 'errorLoadingMedia', fallback.errorLoadingMedia);

  @override
  String get errorLoadingMembers => OtaTranslationService.translate(locale, 'errorLoadingMembers', fallback.errorLoadingMembers);

  @override
  String get errorLoadingMessages => OtaTranslationService.translate(locale, 'errorLoadingMessages', fallback.errorLoadingMessages);

  @override
  String get errorLoadingMore => OtaTranslationService.translate(locale, 'errorLoadingMore', fallback.errorLoadingMore);

  @override
  String get errorLoadingPage => OtaTranslationService.translate(locale, 'errorLoadingPage', fallback.errorLoadingPage);

  @override
  String get errorLoadingPoll => OtaTranslationService.translate(locale, 'errorLoadingPoll', fallback.errorLoadingPoll);

  @override
  String get errorLoadingPost => OtaTranslationService.translate(locale, 'errorLoadingPost', fallback.errorLoadingPost);

  @override
  String get errorLoadingQuiz => OtaTranslationService.translate(locale, 'errorLoadingQuiz', fallback.errorLoadingQuiz);

  @override
  String get errorLoadingReplies => OtaTranslationService.translate(locale, 'errorLoadingReplies', fallback.errorLoadingReplies);

  @override
  String get errorLoadingUsers => OtaTranslationService.translate(locale, 'errorLoadingUsers', fallback.errorLoadingUsers);

  @override
  String get errorLoadingWallet => OtaTranslationService.translate(locale, 'errorLoadingWallet', fallback.errorLoadingWallet);

  @override
  String get errorLoadingWikiEntries => OtaTranslationService.translate(locale, 'errorLoadingWikiEntries', fallback.errorLoadingWikiEntries);

  @override
  String get errorLoggingIn => OtaTranslationService.translate(locale, 'errorLoggingIn', fallback.errorLoggingIn);

  @override
  String get errorMutingUser => OtaTranslationService.translate(locale, 'errorMutingUser', fallback.errorMutingUser);

  @override
  String get errorOpeningImage => OtaTranslationService.translate(locale, 'errorOpeningImage', fallback.errorOpeningImage);

  @override
  String get errorPinningPost => OtaTranslationService.translate(locale, 'errorPinningPost', fallback.errorPinningPost);

  @override
  String get errorRejectingEntry => OtaTranslationService.translate(locale, 'errorRejectingEntry', fallback.errorRejectingEntry);

  @override
  String get errorRemovingAdmin => OtaTranslationService.translate(locale, 'errorRemovingAdmin', fallback.errorRemovingAdmin);

  @override
  String get errorRemovingCurator => OtaTranslationService.translate(locale, 'errorRemovingCurator', fallback.errorRemovingCurator);

  @override
  String get errorRemovingFavorite => OtaTranslationService.translate(locale, 'errorRemovingFavorite', fallback.errorRemovingFavorite);

  @override
  String get errorRemovingLeader => OtaTranslationService.translate(locale, 'errorRemovingLeader', fallback.errorRemovingLeader);

  @override
  String get errorRemovingMember => OtaTranslationService.translate(locale, 'errorRemovingMember', fallback.errorRemovingMember);

  @override
  String get errorReporting => OtaTranslationService.translate(locale, 'errorReporting', fallback.errorReporting);

  @override
  String get errorResendingEmail => OtaTranslationService.translate(locale, 'errorResendingEmail', fallback.errorResendingEmail);

  @override
  String get errorResettingPassword => OtaTranslationService.translate(locale, 'errorResettingPassword', fallback.errorResettingPassword);

  @override
  String get errorSavingChanges => OtaTranslationService.translate(locale, 'errorSavingChanges', fallback.errorSavingChanges);

  @override
  String get errorSavingDraft => OtaTranslationService.translate(locale, 'errorSavingDraft', fallback.errorSavingDraft);

  @override
  String get errorSavingSettings => OtaTranslationService.translate(locale, 'errorSavingSettings', fallback.errorSavingSettings);

  @override
  String get errorSendingMessage => OtaTranslationService.translate(locale, 'errorSendingMessage', fallback.errorSendingMessage);

  @override
  String get errorSendingVerificationEmail => OtaTranslationService.translate(locale, 'errorSendingVerificationEmail', fallback.errorSendingVerificationEmail);

  @override
  String get errorSigningUp => OtaTranslationService.translate(locale, 'errorSigningUp', fallback.errorSigningUp);

  @override
  String get errorStartingChat => OtaTranslationService.translate(locale, 'errorStartingChat', fallback.errorStartingChat);

  @override
  String get errorStrikingUser => OtaTranslationService.translate(locale, 'errorStrikingUser', fallback.errorStrikingUser);

  @override
  String get errorSubmittingEntry => OtaTranslationService.translate(locale, 'errorSubmittingEntry', fallback.errorSubmittingEntry);

  @override
  String get errorUnbanningUser => OtaTranslationService.translate(locale, 'errorUnbanningUser', fallback.errorUnbanningUser);

  @override
  String get errorUnblockingUser => OtaTranslationService.translate(locale, 'errorUnblockingUser', fallback.errorUnblockingUser);

  @override
  String get errorUnfollowingUser => OtaTranslationService.translate(locale, 'errorUnfollowingUser', fallback.errorUnfollowingUser);

  @override
  String get errorUnpinningPost => OtaTranslationService.translate(locale, 'errorUnpinningPost', fallback.errorUnpinningPost);

  @override
  String get errorUpdatingCommunity => OtaTranslationService.translate(locale, 'errorUpdatingCommunity', fallback.errorUpdatingCommunity);

  @override
  String get errorUpdatingPost => OtaTranslationService.translate(locale, 'errorUpdatingPost', fallback.errorUpdatingPost);

  @override
  String get errorUpdatingSettings => OtaTranslationService.translate(locale, 'errorUpdatingSettings', fallback.errorUpdatingSettings);

  @override
  String get errorUploadingImage => OtaTranslationService.translate(locale, 'errorUploadingImage', fallback.errorUploadingImage);

  @override
  String get errorVerifyingEmail => OtaTranslationService.translate(locale, 'errorVerifyingEmail', fallback.errorVerifyingEmail);

  @override
  String get errorVoting => OtaTranslationService.translate(locale, 'errorVoting', fallback.errorVoting);

  @override
  String get errorWarningUser => OtaTranslationService.translate(locale, 'errorWarningUser', fallback.errorWarningUser);

  @override
  String get events => OtaTranslationService.translate(locale, 'events', fallback.events);

  @override
  String get expand => OtaTranslationService.translate(locale, 'expand', fallback.expand);

  @override
  String get explicitContent => OtaTranslationService.translate(locale, 'explicitContent', fallback.explicitContent);

  @override
  String get failedToLoadImage => OtaTranslationService.translate(locale, 'failedToLoadImage', fallback.failedToLoadImage);

  @override
  String get fanArt => OtaTranslationService.translate(locale, 'fanArt', fallback.fanArt);

  @override
  String get faq => OtaTranslationService.translate(locale, 'faq', fallback.faq);

  @override
  String get feature => OtaTranslationService.translate(locale, 'feature', fallback.feature);

  @override
  String get featurePostInCommunity => OtaTranslationService.translate(locale, 'featurePostInCommunity', fallback.featurePostInCommunity);

  @override
  String get featuredLabel => OtaTranslationService.translate(locale, 'featuredLabel', fallback.featuredLabel);

  @override
  String get featuredMembers => OtaTranslationService.translate(locale, 'featuredMembers', fallback.featuredMembers);

  @override
  String get featuredPosts => OtaTranslationService.translate(locale, 'featuredPosts', fallback.featuredPosts);

  @override
  String get feedAndPosts => OtaTranslationService.translate(locale, 'feedAndPosts', fallback.feedAndPosts);

  @override
  String get feedback => OtaTranslationService.translate(locale, 'feedback', fallback.feedback);

  @override
  String get fileIsTooLarge => OtaTranslationService.translate(locale, 'fileIsTooLarge', fallback.fileIsTooLarge);

  @override
  String get fileName => OtaTranslationService.translate(locale, 'fileName', fallback.fileName);

  @override
  String get fileSize => OtaTranslationService.translate(locale, 'fileSize', fallback.fileSize);

  @override
  String get fileType => OtaTranslationService.translate(locale, 'fileType', fallback.fileType);

  @override
  String get fileUploadedSuccessfully => OtaTranslationService.translate(locale, 'fileUploadedSuccessfully', fallback.fileUploadedSuccessfully);

  @override
  String get fillAllFields => OtaTranslationService.translate(locale, 'fillAllFields', fallback.fillAllFields);

  @override
  String get fillInTheFields => OtaTranslationService.translate(locale, 'fillInTheFields', fallback.fillInTheFields);

  @override
  String get filterBy => OtaTranslationService.translate(locale, 'filterBy', fallback.filterBy);

  @override
  String get findFriends => OtaTranslationService.translate(locale, 'findFriends', fallback.findFriends);

  @override
  String get flag => OtaTranslationService.translate(locale, 'flag', fallback.flag);

  @override
  String get flagContent => OtaTranslationService.translate(locale, 'flagContent', fallback.flagContent);

  @override
  String get flagDetails => OtaTranslationService.translate(locale, 'flagDetails', fallback.flagDetails);

  @override
  String get flagSent => OtaTranslationService.translate(locale, 'flagSent', fallback.flagSent);

  @override
  String get flagUser => OtaTranslationService.translate(locale, 'flagUser', fallback.flagUser);

  @override
  String get flaggedContent => OtaTranslationService.translate(locale, 'flaggedContent', fallback.flaggedContent);

  @override
  String get followNotifications => OtaTranslationService.translate(locale, 'followNotifications', fallback.followNotifications);

  @override
  String get followUser => OtaTranslationService.translate(locale, 'followUser', fallback.followUser);

  @override
  String get followersOnly => OtaTranslationService.translate(locale, 'followersOnly', fallback.followersOnly);

  @override
  String get followingLabel => OtaTranslationService.translate(locale, 'followingLabel', fallback.followingLabel);

  @override
  String get font => OtaTranslationService.translate(locale, 'font', fallback.font);

  @override
  String get forReview => OtaTranslationService.translate(locale, 'forReview', fallback.forReview);

  @override
  String get forgotYourPassword => OtaTranslationService.translate(locale, 'forgotYourPassword', fallback.forgotYourPassword);

  @override
  String get format => OtaTranslationService.translate(locale, 'format', fallback.format);

  @override
  String get frame => OtaTranslationService.translate(locale, 'frame', fallback.frame);

  @override
  String get friends => OtaTranslationService.translate(locale, 'friends', fallback.friends);

  @override
  String get from => OtaTranslationService.translate(locale, 'from', fallback.from);

  @override
  String get galleryPermission => OtaTranslationService.translate(locale, 'galleryPermission', fallback.galleryPermission);

  @override
  String get gaming => OtaTranslationService.translate(locale, 'gaming', fallback.gaming);

  @override
  String get generalChat => OtaTranslationService.translate(locale, 'generalChat', fallback.generalChat);

  @override
  String get getCoins => OtaTranslationService.translate(locale, 'getCoins', fallback.getCoins);

  @override
  String get getHelp => OtaTranslationService.translate(locale, 'getHelp', fallback.getHelp);

  @override
  String get getStartedDesc => OtaTranslationService.translate(locale, 'getStartedDesc', fallback.getStartedDesc);

  @override
  String get giphy => OtaTranslationService.translate(locale, 'giphy', fallback.giphy);

  @override
  String get giveProps => OtaTranslationService.translate(locale, 'giveProps', fallback.giveProps);

  @override
  String get globalProfile => OtaTranslationService.translate(locale, 'globalProfile', fallback.globalProfile);

  @override
  String get goBack => OtaTranslationService.translate(locale, 'goBack', fallback.goBack);

  @override
  String get goLive => OtaTranslationService.translate(locale, 'goLive', fallback.goLive);

  @override
  String get goToChat => OtaTranslationService.translate(locale, 'goToChat', fallback.goToChat);

  @override
  String get goToCommunity => OtaTranslationService.translate(locale, 'goToCommunity', fallback.goToCommunity);

  @override
  String get goToPost => OtaTranslationService.translate(locale, 'goToPost', fallback.goToPost);

  @override
  String get goToProfile => OtaTranslationService.translate(locale, 'goToProfile', fallback.goToProfile);

  @override
  String get group => OtaTranslationService.translate(locale, 'group', fallback.group);

  @override
  String get groupAdmin => OtaTranslationService.translate(locale, 'groupAdmin', fallback.groupAdmin);

  @override
  String get groupCreated => OtaTranslationService.translate(locale, 'groupCreated', fallback.groupCreated);

  @override
  String get groupIcon => OtaTranslationService.translate(locale, 'groupIcon', fallback.groupIcon);

  @override
  String get groupMembers => OtaTranslationService.translate(locale, 'groupMembers', fallback.groupMembers);

  @override
  String get groupSettings => OtaTranslationService.translate(locale, 'groupSettings', fallback.groupSettings);

  @override
  String get guidelinesLabel => OtaTranslationService.translate(locale, 'guidelinesLabel', fallback.guidelinesLabel);

  @override
  String get hasLeftTheChat => OtaTranslationService.translate(locale, 'hasLeftTheChat', fallback.hasLeftTheChat);

  @override
  String get helpAndSupport => OtaTranslationService.translate(locale, 'helpAndSupport', fallback.helpAndSupport);

  @override
  String get insertYoutube => OtaTranslationService.translate(locale, 'insertYoutube', fallback.insertYoutube);

  @override
  String get invalidYoutubeUrl => OtaTranslationService.translate(locale, 'invalidYoutubeUrl', fallback.invalidYoutubeUrl);

  @override
  String get lastActivity => OtaTranslationService.translate(locale, 'lastActivity', fallback.lastActivity);

  @override
  String get lastPost => OtaTranslationService.translate(locale, 'lastPost', fallback.lastPost);

  @override
  String get lastPostBy => OtaTranslationService.translate(locale, 'lastPostBy', fallback.lastPostBy);

  @override
  String get latest2 => OtaTranslationService.translate(locale, 'latest2', fallback.latest2);

  @override
  String get leaveChat2 => OtaTranslationService.translate(locale, 'leaveChat2', fallback.leaveChat2);

  @override
  String get leaveCommunity2 => OtaTranslationService.translate(locale, 'leaveCommunity2', fallback.leaveCommunity2);

  @override
  String get leaveGroup2 => OtaTranslationService.translate(locale, 'leaveGroup2', fallback.leaveGroup2);

  @override
  String get leaveScreening => OtaTranslationService.translate(locale, 'leaveScreening', fallback.leaveScreening);

  @override
  String get legendary2 => OtaTranslationService.translate(locale, 'legendary2', fallback.legendary2);

  @override
  String get light => OtaTranslationService.translate(locale, 'light', fallback.light);

  @override
  String get link2 => OtaTranslationService.translate(locale, 'link2', fallback.link2);

  @override
  String get linkCopied2 => OtaTranslationService.translate(locale, 'linkCopied2', fallback.linkCopied2);

  @override
  String get linkToPost => OtaTranslationService.translate(locale, 'linkToPost', fallback.linkToPost);

  @override
  String get loading2 => OtaTranslationService.translate(locale, 'loading2', fallback.loading2);

  @override
  String get loadingGifs => OtaTranslationService.translate(locale, 'loadingGifs', fallback.loadingGifs);

  @override
  String get loadingImages => OtaTranslationService.translate(locale, 'loadingImages', fallback.loadingImages);

  @override
  String get loadingMedia => OtaTranslationService.translate(locale, 'loadingMedia', fallback.loadingMedia);

  @override
  String get loadingPosts => OtaTranslationService.translate(locale, 'loadingPosts', fallback.loadingPosts);

  @override
  String get loadingStickers => OtaTranslationService.translate(locale, 'loadingStickers', fallback.loadingStickers);

  @override
  String get loadingUsers => OtaTranslationService.translate(locale, 'loadingUsers', fallback.loadingUsers);

  @override
  String get loginError => OtaTranslationService.translate(locale, 'loginError', fallback.loginError);

  @override
  String get loginRequired => OtaTranslationService.translate(locale, 'loginRequired', fallback.loginRequired);

  @override
  String get loginToContinue2 => OtaTranslationService.translate(locale, 'loginToContinue2', fallback.loginToContinue2);

  @override
  String get loginToJoin => OtaTranslationService.translate(locale, 'loginToJoin', fallback.loginToJoin);

  @override
  String get loginToVote => OtaTranslationService.translate(locale, 'loginToVote', fallback.loginToVote);

  @override
  String get longestStreak => OtaTranslationService.translate(locale, 'longestStreak', fallback.longestStreak);

  @override
  String get manageBlockedUsers => OtaTranslationService.translate(locale, 'manageBlockedUsers', fallback.manageBlockedUsers);

  @override
  String get manageDevices => OtaTranslationService.translate(locale, 'manageDevices', fallback.manageDevices);

  @override
  String get managePosts => OtaTranslationService.translate(locale, 'managePosts', fallback.managePosts);

  @override
  String get manageUsers => OtaTranslationService.translate(locale, 'manageUsers', fallback.manageUsers);

  @override
  String get master => OtaTranslationService.translate(locale, 'master', fallback.master);

  @override
  String get max100Chars => OtaTranslationService.translate(locale, 'max100Chars', fallback.max100Chars);

  @override
  String get max150Chars => OtaTranslationService.translate(locale, 'max150Chars', fallback.max150Chars);

  @override
  String get max200Chars => OtaTranslationService.translate(locale, 'max200Chars', fallback.max200Chars);

  @override
  String get max300Chars => OtaTranslationService.translate(locale, 'max300Chars', fallback.max300Chars);

  @override
  String get max50Chars => OtaTranslationService.translate(locale, 'max50Chars', fallback.max50Chars);

  @override
  String get member2 => OtaTranslationService.translate(locale, 'member2', fallback.member2);

  @override
  String get memberList => OtaTranslationService.translate(locale, 'memberList', fallback.memberList);

  @override
  String get memberRole => OtaTranslationService.translate(locale, 'memberRole', fallback.memberRole);

  @override
  String get members2 => OtaTranslationService.translate(locale, 'members2', fallback.members2);

  @override
  String get mention => OtaTranslationService.translate(locale, 'mention', fallback.mention);

  @override
  String get message2 => OtaTranslationService.translate(locale, 'message2', fallback.message2);

  @override
  String get messageFrom => OtaTranslationService.translate(locale, 'messageFrom', fallback.messageFrom);

  @override
  String get messageToBroadcast => OtaTranslationService.translate(locale, 'messageToBroadcast', fallback.messageToBroadcast);

  @override
  String get min2Options => OtaTranslationService.translate(locale, 'min2Options', fallback.min2Options);

  @override
  String get moreOptions => OtaTranslationService.translate(locale, 'moreOptions', fallback.moreOptions);

  @override
  String get moviesTv => OtaTranslationService.translate(locale, 'moviesTv', fallback.moviesTv);

  @override
  String get music2 => OtaTranslationService.translate(locale, 'music2', fallback.music2);

  @override
  String get myDrafts => OtaTranslationService.translate(locale, 'myDrafts', fallback.myDrafts);

  @override
  String get myPosts => OtaTranslationService.translate(locale, 'myPosts', fallback.myPosts);

  @override
  String get myProfile => OtaTranslationService.translate(locale, 'myProfile', fallback.myProfile);

  @override
  String get mySavedPosts => OtaTranslationService.translate(locale, 'mySavedPosts', fallback.mySavedPosts);

  @override
  String get myStickers => OtaTranslationService.translate(locale, 'myStickers', fallback.myStickers);

  @override
  String get nameYourCommunity => OtaTranslationService.translate(locale, 'nameYourCommunity', fallback.nameYourCommunity);

  @override
  String get newPassword => OtaTranslationService.translate(locale, 'newPassword', fallback.newPassword);

  @override
  String get newPasswordConfirmation => OtaTranslationService.translate(locale, 'newPasswordConfirmation', fallback.newPasswordConfirmation);

  @override
  String get newPasswordConfirmationHint => OtaTranslationService.translate(locale, 'newPasswordConfirmationHint', fallback.newPasswordConfirmationHint);

  @override
  String get newPasswordHint => OtaTranslationService.translate(locale, 'newPasswordHint', fallback.newPasswordHint);

  @override
  String get newPasswordIsRequired => OtaTranslationService.translate(locale, 'newPasswordIsRequired', fallback.newPasswordIsRequired);

  @override
  String get newTag => OtaTranslationService.translate(locale, 'newTag', fallback.newTag);

  @override
  String get newTagHint => OtaTranslationService.translate(locale, 'newTagHint', fallback.newTagHint);

  @override
  String get nickname2 => OtaTranslationService.translate(locale, 'nickname2', fallback.nickname2);

  @override
  String get nicknameInCommunity => OtaTranslationService.translate(locale, 'nicknameInCommunity', fallback.nicknameInCommunity);

  @override
  String get no2 => OtaTranslationService.translate(locale, 'no2', fallback.no2);

  @override
  String get noActivity => OtaTranslationService.translate(locale, 'noActivity', fallback.noActivity);

  @override
  String get noActivityInCommunity => OtaTranslationService.translate(locale, 'noActivityInCommunity', fallback.noActivityInCommunity);

  @override
  String get noActivityYet => OtaTranslationService.translate(locale, 'noActivityYet', fallback.noActivityYet);

  @override
  String get noAdAvailable => OtaTranslationService.translate(locale, 'noAdAvailable', fallback.noAdAvailable);

  @override
  String get noAdOffers => OtaTranslationService.translate(locale, 'noAdOffers', fallback.noAdOffers);

  @override
  String get noBannedUsers => OtaTranslationService.translate(locale, 'noBannedUsers', fallback.noBannedUsers);

  @override
  String get noBannedUsersMsg => OtaTranslationService.translate(locale, 'noBannedUsersMsg', fallback.noBannedUsersMsg);

  @override
  String get noChatsFound => OtaTranslationService.translate(locale, 'noChatsFound', fallback.noChatsFound);

  @override
  String get noChatsHere => OtaTranslationService.translate(locale, 'noChatsHere', fallback.noChatsHere);

  @override
  String get noCommonCommunities => OtaTranslationService.translate(locale, 'noCommonCommunities', fallback.noCommonCommunities);

  @override
  String get noCommonFollowers => OtaTranslationService.translate(locale, 'noCommonFollowers', fallback.noCommonFollowers);

  @override
  String get noCommonFollowing => OtaTranslationService.translate(locale, 'noCommonFollowing', fallback.noCommonFollowing);

  @override
  String get noCommunityFound => OtaTranslationService.translate(locale, 'noCommunityFound', fallback.noCommunityFound);

  @override
  String get noCommunityMembers => OtaTranslationService.translate(locale, 'noCommunityMembers', fallback.noCommunityMembers);

  @override
  String get noCommunityPosts => OtaTranslationService.translate(locale, 'noCommunityPosts', fallback.noCommunityPosts);

  @override
  String get noFollowers => OtaTranslationService.translate(locale, 'noFollowers', fallback.noFollowers);

  @override
  String get noFollowers2 => OtaTranslationService.translate(locale, 'noFollowers2', fallback.noFollowers2);

  @override
  String get noFollowersYet => OtaTranslationService.translate(locale, 'noFollowersYet', fallback.noFollowersYet);

  @override
  String get noFollowing => OtaTranslationService.translate(locale, 'noFollowing', fallback.noFollowing);

  @override
  String get noFollowing2 => OtaTranslationService.translate(locale, 'noFollowing2', fallback.noFollowing2);

  @override
  String get noFollowingYet => OtaTranslationService.translate(locale, 'noFollowingYet', fallback.noFollowingYet);

  @override
  String get noGifsFound => OtaTranslationService.translate(locale, 'noGifsFound', fallback.noGifsFound);

  @override
  String get noImagesFound => OtaTranslationService.translate(locale, 'noImagesFound', fallback.noImagesFound);

  @override
  String get noInvites => OtaTranslationService.translate(locale, 'noInvites', fallback.noInvites);

  @override
  String get noMembersFound => OtaTranslationService.translate(locale, 'noMembersFound', fallback.noMembersFound);

  @override
  String get noMembersInCommunity => OtaTranslationService.translate(locale, 'noMembersInCommunity', fallback.noMembersInCommunity);

  @override
  String get noMessagesHere => OtaTranslationService.translate(locale, 'noMessagesHere', fallback.noMessagesHere);

  @override
  String get noMorePosts => OtaTranslationService.translate(locale, 'noMorePosts', fallback.noMorePosts);

  @override
  String get noNotificationsYet => OtaTranslationService.translate(locale, 'noNotificationsYet', fallback.noNotificationsYet);

  @override
  String get noOneCanFollow => OtaTranslationService.translate(locale, 'noOneCanFollow', fallback.noOneCanFollow);

  @override
  String get noOneCanMessage => OtaTranslationService.translate(locale, 'noOneCanMessage', fallback.noOneCanMessage);

  @override
  String get noOneCanMessageDesc => OtaTranslationService.translate(locale, 'noOneCanMessageDesc', fallback.noOneCanMessageDesc);

  @override
  String get noPosts2 => OtaTranslationService.translate(locale, 'noPosts2', fallback.noPosts2);

  @override
  String get noPostsFound => OtaTranslationService.translate(locale, 'noPostsFound', fallback.noPostsFound);

  @override
  String get noPostsToSee => OtaTranslationService.translate(locale, 'noPostsToSee', fallback.noPostsToSee);

  @override
  String get noRecentSearches => OtaTranslationService.translate(locale, 'noRecentSearches', fallback.noRecentSearches);

  @override
  String get noResultsFound => OtaTranslationService.translate(locale, 'noResultsFound', fallback.noResultsFound);

  @override
  String get noResultsFoundMsg => OtaTranslationService.translate(locale, 'noResultsFoundMsg', fallback.noResultsFoundMsg);

  @override
  String get noSharedContent => OtaTranslationService.translate(locale, 'noSharedContent', fallback.noSharedContent);

  @override
  String get noStickersFound => OtaTranslationService.translate(locale, 'noStickersFound', fallback.noStickersFound);

  @override
  String get noUsersFound => OtaTranslationService.translate(locale, 'noUsersFound', fallback.noUsersFound);

  @override
  String get noUsersFound2 => OtaTranslationService.translate(locale, 'noUsersFound2', fallback.noUsersFound2);

  @override
  String get noUsersFoundMsg => OtaTranslationService.translate(locale, 'noUsersFoundMsg', fallback.noUsersFoundMsg);

  @override
  String get noUsersToSee => OtaTranslationService.translate(locale, 'noUsersToSee', fallback.noUsersToSee);

  @override
  String get noWikiEntries => OtaTranslationService.translate(locale, 'noWikiEntries', fallback.noWikiEntries);

  @override
  String get notAMember => OtaTranslationService.translate(locale, 'notAMember', fallback.notAMember);

  @override
  String get notEnoughCoins => OtaTranslationService.translate(locale, 'notEnoughCoins', fallback.notEnoughCoins);

  @override
  String get notNow => OtaTranslationService.translate(locale, 'notNow', fallback.notNow);

  @override
  String get notifications2 => OtaTranslationService.translate(locale, 'notifications2', fallback.notifications2);

  @override
  String get notificationsFrom => OtaTranslationService.translate(locale, 'notificationsFrom', fallback.notificationsFrom);

  @override
  String get notificationsFromChats => OtaTranslationService.translate(locale, 'notificationsFromChats', fallback.notificationsFromChats);

  @override
  String get notificationsFromNexusHub => OtaTranslationService.translate(locale, 'notificationsFromNexusHub', fallback.notificationsFromNexusHub);

  @override
  String get notificationsLabel => OtaTranslationService.translate(locale, 'notificationsLabel', fallback.notificationsLabel);

  @override
  String get nowOnline => OtaTranslationService.translate(locale, 'nowOnline', fallback.nowOnline);

  @override
  String get off => OtaTranslationService.translate(locale, 'off', fallback.off);

  @override
  String get officialEvents => OtaTranslationService.translate(locale, 'officialEvents', fallback.officialEvents);

  @override
  String get offlineStatus => OtaTranslationService.translate(locale, 'offlineStatus', fallback.offlineStatus);

  @override
  String get on => OtaTranslationService.translate(locale, 'on', fallback.on);

  @override
  String get online2 => OtaTranslationService.translate(locale, 'online2', fallback.online2);

  @override
  String get onlineStatus => OtaTranslationService.translate(locale, 'onlineStatus', fallback.onlineStatus);

  @override
  String get onlyFriendsCanComment => OtaTranslationService.translate(locale, 'onlyFriendsCanComment', fallback.onlyFriendsCanComment);

  @override
  String get onlyFriendsCanMessage => OtaTranslationService.translate(locale, 'onlyFriendsCanMessage', fallback.onlyFriendsCanMessage);

  @override
  String get onlyFriendsCanMessageDesc => OtaTranslationService.translate(locale, 'onlyFriendsCanMessageDesc', fallback.onlyFriendsCanMessageDesc);

  @override
  String get onlyHostCanDoThis => OtaTranslationService.translate(locale, 'onlyHostCanDoThis', fallback.onlyHostCanDoThis);

  @override
  String get onlyHostCanInvite => OtaTranslationService.translate(locale, 'onlyHostCanInvite', fallback.onlyHostCanInvite);

  @override
  String get onlyHostCanRemove => OtaTranslationService.translate(locale, 'onlyHostCanRemove', fallback.onlyHostCanRemove);

  @override
  String get onlyHostCanSee => OtaTranslationService.translate(locale, 'onlyHostCanSee', fallback.onlyHostCanSee);

  @override
  String get onlyLeadersCanFeature => OtaTranslationService.translate(locale, 'onlyLeadersCanFeature', fallback.onlyLeadersCanFeature);

  @override
  String get onlyLeadersCanPin => OtaTranslationService.translate(locale, 'onlyLeadersCanPin', fallback.onlyLeadersCanPin);

  @override
  String get onlyYouCanSeeThis => OtaTranslationService.translate(locale, 'onlyYouCanSeeThis', fallback.onlyYouCanSeeThis);

  @override
  String get openCamera => OtaTranslationService.translate(locale, 'openCamera', fallback.openCamera);

  @override
  String get openGallery => OtaTranslationService.translate(locale, 'openGallery', fallback.openGallery);

  @override
  String get openImage => OtaTranslationService.translate(locale, 'openImage', fallback.openImage);

  @override
  String get openInBrowser => OtaTranslationService.translate(locale, 'openInBrowser', fallback.openInBrowser);

  @override
  String get openToEveryone => OtaTranslationService.translate(locale, 'openToEveryone', fallback.openToEveryone);

  @override
  String get openToEveryoneDesc => OtaTranslationService.translate(locale, 'openToEveryoneDesc', fallback.openToEveryoneDesc);

  @override
  String get option => OtaTranslationService.translate(locale, 'option', fallback.option);

  @override
  String get optionCannotBeEmpty => OtaTranslationService.translate(locale, 'optionCannotBeEmpty', fallback.optionCannotBeEmpty);

  @override
  String get optional => OtaTranslationService.translate(locale, 'optional', fallback.optional);

  @override
  String get or => OtaTranslationService.translate(locale, 'or', fallback.or);

  @override
  String get originalContent => OtaTranslationService.translate(locale, 'originalContent', fallback.originalContent);

  @override
  String get originalPoster => OtaTranslationService.translate(locale, 'originalPoster', fallback.originalPoster);

  @override
  String get other2 => OtaTranslationService.translate(locale, 'other2', fallback.other2);

  @override
  String get otherLabel => OtaTranslationService.translate(locale, 'otherLabel', fallback.otherLabel);

  @override
  String get otherOffenses => OtaTranslationService.translate(locale, 'otherOffenses', fallback.otherOffenses);

  @override
  String get otherReason => OtaTranslationService.translate(locale, 'otherReason', fallback.otherReason);

  @override
  String get password2 => OtaTranslationService.translate(locale, 'password2', fallback.password2);

  @override
  String get passwordChanged => OtaTranslationService.translate(locale, 'passwordChanged', fallback.passwordChanged);

  @override
  String get passwordChangedSuccess => OtaTranslationService.translate(locale, 'passwordChangedSuccess', fallback.passwordChangedSuccess);

  @override
  String get passwordDoNotMatch => OtaTranslationService.translate(locale, 'passwordDoNotMatch', fallback.passwordDoNotMatch);

  @override
  String get passwordIsRequired => OtaTranslationService.translate(locale, 'passwordIsRequired', fallback.passwordIsRequired);

  @override
  String get passwordRequired => OtaTranslationService.translate(locale, 'passwordRequired', fallback.passwordRequired);

  @override
  String get passwordReset => OtaTranslationService.translate(locale, 'passwordReset', fallback.passwordReset);

  @override
  String get passwordResetEmailSent => OtaTranslationService.translate(locale, 'passwordResetEmailSent', fallback.passwordResetEmailSent);

  @override
  String get passwordUpdated => OtaTranslationService.translate(locale, 'passwordUpdated', fallback.passwordUpdated);

  @override
  String get pasteGiphyLink => OtaTranslationService.translate(locale, 'pasteGiphyLink', fallback.pasteGiphyLink);

  @override
  String get pasteImageUrl => OtaTranslationService.translate(locale, 'pasteImageUrl', fallback.pasteImageUrl);

  @override
  String get pasteLink => OtaTranslationService.translate(locale, 'pasteLink', fallback.pasteLink);

  @override
  String get pasteLink2 => OtaTranslationService.translate(locale, 'pasteLink2', fallback.pasteLink2);

  @override
  String get pasteYoutubeLink => OtaTranslationService.translate(locale, 'pasteYoutubeLink', fallback.pasteYoutubeLink);

  @override
  String get pendingLabel => OtaTranslationService.translate(locale, 'pendingLabel', fallback.pendingLabel);

  @override
  String get permanentlyBanUser => OtaTranslationService.translate(locale, 'permanentlyBanUser', fallback.permanentlyBanUser);

  @override
  String get permissions => OtaTranslationService.translate(locale, 'permissions', fallback.permissions);

  @override
  String get personalInformation => OtaTranslationService.translate(locale, 'personalInformation', fallback.personalInformation);

  @override
  String get phone => OtaTranslationService.translate(locale, 'phone', fallback.phone);

  @override
  String get phoneNotVerified => OtaTranslationService.translate(locale, 'phoneNotVerified', fallback.phoneNotVerified);

  @override
  String get photo => OtaTranslationService.translate(locale, 'photo', fallback.photo);

  @override
  String get pin => OtaTranslationService.translate(locale, 'pin', fallback.pin);

  @override
  String get pinChat => OtaTranslationService.translate(locale, 'pinChat', fallback.pinChat);

  @override
  String get pinMessage => OtaTranslationService.translate(locale, 'pinMessage', fallback.pinMessage);

  @override
  String get pinToBlog => OtaTranslationService.translate(locale, 'pinToBlog', fallback.pinToBlog);

  @override
  String get pinToCommunityHome => OtaTranslationService.translate(locale, 'pinToCommunityHome', fallback.pinToCommunityHome);

  @override
  String get pinWiki => OtaTranslationService.translate(locale, 'pinWiki', fallback.pinWiki);

  @override
  String get plagiarism => OtaTranslationService.translate(locale, 'plagiarism', fallback.plagiarism);

  @override
  String get pollDuration => OtaTranslationService.translate(locale, 'pollDuration', fallback.pollDuration);

  @override
  String get pollEndsIn => OtaTranslationService.translate(locale, 'pollEndsIn', fallback.pollEndsIn);

  @override
  String get pollOptions => OtaTranslationService.translate(locale, 'pollOptions', fallback.pollOptions);

  @override
  String get pollPublishedSuccess => OtaTranslationService.translate(locale, 'pollPublishedSuccess', fallback.pollPublishedSuccess);

  @override
  String get popular2 => OtaTranslationService.translate(locale, 'popular2', fallback.popular2);

  @override
  String get post2 => OtaTranslationService.translate(locale, 'post2', fallback.post2);

  @override
  String get postCreationSuccess => OtaTranslationService.translate(locale, 'postCreationSuccess', fallback.postCreationSuccess);

  @override
  String get postFeatured => OtaTranslationService.translate(locale, 'postFeatured', fallback.postFeatured);

  @override
  String get postHidden => OtaTranslationService.translate(locale, 'postHidden', fallback.postHidden);

  @override
  String get postHighlighted => OtaTranslationService.translate(locale, 'postHighlighted', fallback.postHighlighted);

  @override
  String get postHistory => OtaTranslationService.translate(locale, 'postHistory', fallback.postHistory);

  @override
  String get postInYourFeed => OtaTranslationService.translate(locale, 'postInYourFeed', fallback.postInYourFeed);

  @override
  String get postIsHidden => OtaTranslationService.translate(locale, 'postIsHidden', fallback.postIsHidden);

  @override
  String get postIsVisible => OtaTranslationService.translate(locale, 'postIsVisible', fallback.postIsVisible);

  @override
  String get postLink => OtaTranslationService.translate(locale, 'postLink', fallback.postLink);

  @override
  String get postOptions => OtaTranslationService.translate(locale, 'postOptions', fallback.postOptions);

  @override
  String get postOptions2 => OtaTranslationService.translate(locale, 'postOptions2', fallback.postOptions2);

  @override
  String get postPinned => OtaTranslationService.translate(locale, 'postPinned', fallback.postPinned);

  @override
  String get postSentForReview => OtaTranslationService.translate(locale, 'postSentForReview', fallback.postSentForReview);

  @override
  String get postSucessfully => OtaTranslationService.translate(locale, 'postSucessfully', fallback.postSucessfully);

  @override
  String get postUnfeatured => OtaTranslationService.translate(locale, 'postUnfeatured', fallback.postUnfeatured);

  @override
  String get postUnhidden => OtaTranslationService.translate(locale, 'postUnhidden', fallback.postUnhidden);

  @override
  String get postUnpinned => OtaTranslationService.translate(locale, 'postUnpinned', fallback.postUnpinned);

  @override
  String get postVisibility => OtaTranslationService.translate(locale, 'postVisibility', fallback.postVisibility);

  @override
  String get posts2 => OtaTranslationService.translate(locale, 'posts2', fallback.posts2);

  @override
  String get postsLabel => OtaTranslationService.translate(locale, 'postsLabel', fallback.postsLabel);

  @override
  String get postsYouMightLike => OtaTranslationService.translate(locale, 'postsYouMightLike', fallback.postsYouMightLike);

  @override
  String get poweredByGiphy => OtaTranslationService.translate(locale, 'poweredByGiphy', fallback.poweredByGiphy);

  @override
  String get presence => OtaTranslationService.translate(locale, 'presence', fallback.presence);

  @override
  String get presenceStatus => OtaTranslationService.translate(locale, 'presenceStatus', fallback.presenceStatus);

  @override
  String get privacy2 => OtaTranslationService.translate(locale, 'privacy2', fallback.privacy2);

  @override
  String get privacyLabel => OtaTranslationService.translate(locale, 'privacyLabel', fallback.privacyLabel);

  @override
  String get private2 => OtaTranslationService.translate(locale, 'private2', fallback.private2);

  @override
  String get privateChatInvite => OtaTranslationService.translate(locale, 'privateChatInvite', fallback.privateChatInvite);

  @override
  String get privateCommunity => OtaTranslationService.translate(locale, 'privateCommunity', fallback.privateCommunity);

  @override
  String get privateCommunityDesc => OtaTranslationService.translate(locale, 'privateCommunityDesc', fallback.privateCommunityDesc);

  @override
  String get profile2 => OtaTranslationService.translate(locale, 'profile2', fallback.profile2);

  @override
  String get profileComments => OtaTranslationService.translate(locale, 'profileComments', fallback.profileComments);

  @override
  String get profileCommentsDisabled => OtaTranslationService.translate(locale, 'profileCommentsDisabled', fallback.profileCommentsDisabled);

  @override
  String get profileCustomization => OtaTranslationService.translate(locale, 'profileCustomization', fallback.profileCustomization);

  @override
  String get profileFrame => OtaTranslationService.translate(locale, 'profileFrame', fallback.profileFrame);

  @override
  String get profileFrames => OtaTranslationService.translate(locale, 'profileFrames', fallback.profileFrames);

  @override
  String get profileIsPrivate => OtaTranslationService.translate(locale, 'profileIsPrivate', fallback.profileIsPrivate);

  @override
  String get profileIsPublic => OtaTranslationService.translate(locale, 'profileIsPublic', fallback.profileIsPublic);

  @override
  String get profileLabel => OtaTranslationService.translate(locale, 'profileLabel', fallback.profileLabel);

  @override
  String get profileOptions => OtaTranslationService.translate(locale, 'profileOptions', fallback.profileOptions);

  @override
  String get profileViewers => OtaTranslationService.translate(locale, 'profileViewers', fallback.profileViewers);

  @override
  String get profileVisibility => OtaTranslationService.translate(locale, 'profileVisibility', fallback.profileVisibility);

  @override
  String get public2 => OtaTranslationService.translate(locale, 'public2', fallback.public2);

  @override
  String get publicChatrooms => OtaTranslationService.translate(locale, 'publicChatrooms', fallback.publicChatrooms);

  @override
  String get publish2 => OtaTranslationService.translate(locale, 'publish2', fallback.publish2);

  @override
  String get publishChanges => OtaTranslationService.translate(locale, 'publishChanges', fallback.publishChanges);

  @override
  String get purchase => OtaTranslationService.translate(locale, 'purchase', fallback.purchase);

  @override
  String get purchaseHistory => OtaTranslationService.translate(locale, 'purchaseHistory', fallback.purchaseHistory);

  @override
  String get purchaseRestored => OtaTranslationService.translate(locale, 'purchaseRestored', fallback.purchaseRestored);

  @override
  String get purchasesRestored => OtaTranslationService.translate(locale, 'purchasesRestored', fallback.purchasesRestored);

  @override
  String get question2 => OtaTranslationService.translate(locale, 'question2', fallback.question2);

  @override
  String get questionCannotBeEmpty => OtaTranslationService.translate(locale, 'questionCannotBeEmpty', fallback.questionCannotBeEmpty);

  @override
  String get questionCreatedSuccess => OtaTranslationService.translate(locale, 'questionCreatedSuccess', fallback.questionCreatedSuccess);

  @override
  String get questionIsRequired => OtaTranslationService.translate(locale, 'questionIsRequired', fallback.questionIsRequired);

  @override
  String get questionLabel => OtaTranslationService.translate(locale, 'questionLabel', fallback.questionLabel);

  @override
  String get quizExplanation => OtaTranslationService.translate(locale, 'quizExplanation', fallback.quizExplanation);

  @override
  String get quizExplanationHint => OtaTranslationService.translate(locale, 'quizExplanationHint', fallback.quizExplanationHint);

  @override
  String get quizLabel => OtaTranslationService.translate(locale, 'quizLabel', fallback.quizLabel);

  @override
  String get quizOptions => OtaTranslationService.translate(locale, 'quizOptions', fallback.quizOptions);

  @override
  String get quizPublishedSuccess => OtaTranslationService.translate(locale, 'quizPublishedSuccess', fallback.quizPublishedSuccess);

  @override
  String get quizPublishedSuccess2 => OtaTranslationService.translate(locale, 'quizPublishedSuccess2', fallback.quizPublishedSuccess2);

  @override
  String get quizResults => OtaTranslationService.translate(locale, 'quizResults', fallback.quizResults);

  @override
  String get quizzes => OtaTranslationService.translate(locale, 'quizzes', fallback.quizzes);

  @override
  String get readOnly => OtaTranslationService.translate(locale, 'readOnly', fallback.readOnly);

  @override
  String get reason2 => OtaTranslationService.translate(locale, 'reason2', fallback.reason2);

  @override
  String get reasonForAction => OtaTranslationService.translate(locale, 'reasonForAction', fallback.reasonForAction);

  @override
  String get reasonForReport => OtaTranslationService.translate(locale, 'reasonForReport', fallback.reasonForReport);

  @override
  String get reasonLabel => OtaTranslationService.translate(locale, 'reasonLabel', fallback.reasonLabel);

  @override
  String get recentPosts => OtaTranslationService.translate(locale, 'recentPosts', fallback.recentPosts);

  @override
  String get recentSearchesCleared => OtaTranslationService.translate(locale, 'recentSearchesCleared', fallback.recentSearchesCleared);

  @override
  String get recentVisitors => OtaTranslationService.translate(locale, 'recentVisitors', fallback.recentVisitors);

  @override
  String get remove2 => OtaTranslationService.translate(locale, 'remove2', fallback.remove2);

  @override
  String get removeAdmin => OtaTranslationService.translate(locale, 'removeAdmin', fallback.removeAdmin);

  @override
  String get removeAtLeastOneImage => OtaTranslationService.translate(locale, 'removeAtLeastOneImage', fallback.removeAtLeastOneImage);

  @override
  String get removeAtLeastOneQuestion => OtaTranslationService.translate(locale, 'removeAtLeastOneQuestion', fallback.removeAtLeastOneQuestion);

  @override
  String get removeCover => OtaTranslationService.translate(locale, 'removeCover', fallback.removeCover);

  @override
  String get removeCurator => OtaTranslationService.translate(locale, 'removeCurator', fallback.removeCurator);

  @override
  String get removeFavorite => OtaTranslationService.translate(locale, 'removeFavorite', fallback.removeFavorite);

  @override
  String get removeFriend => OtaTranslationService.translate(locale, 'removeFriend', fallback.removeFriend);

  @override
  String get removeFromFavorites => OtaTranslationService.translate(locale, 'removeFromFavorites', fallback.removeFromFavorites);

  @override
  String get removeLeader => OtaTranslationService.translate(locale, 'removeLeader', fallback.removeLeader);

  @override
  String get removeLink => OtaTranslationService.translate(locale, 'removeLink', fallback.removeLink);

  @override
  String get removeMember => OtaTranslationService.translate(locale, 'removeMember', fallback.removeMember);

  @override
  String get removeMusic => OtaTranslationService.translate(locale, 'removeMusic', fallback.removeMusic);

  @override
  String get removePoll => OtaTranslationService.translate(locale, 'removePoll', fallback.removePoll);

  @override
  String get removeQuiz => OtaTranslationService.translate(locale, 'removeQuiz', fallback.removeQuiz);

  @override
  String get removeUser => OtaTranslationService.translate(locale, 'removeUser', fallback.removeUser);

  @override
  String get removeUserFromChat => OtaTranslationService.translate(locale, 'removeUserFromChat', fallback.removeUserFromChat);

  @override
  String get removedFromFavorites => OtaTranslationService.translate(locale, 'removedFromFavorites', fallback.removedFromFavorites);

  @override
  String get reorder => OtaTranslationService.translate(locale, 'reorder', fallback.reorder);

  @override
  String get reorder2 => OtaTranslationService.translate(locale, 'reorder2', fallback.reorder2);

  @override
  String get report2 => OtaTranslationService.translate(locale, 'report2', fallback.report2);

  @override
  String get reportBug2 => OtaTranslationService.translate(locale, 'reportBug2', fallback.reportBug2);

  @override
  String get reportDetails => OtaTranslationService.translate(locale, 'reportDetails', fallback.reportDetails);

  @override
  String get reportSentSuccess => OtaTranslationService.translate(locale, 'reportSentSuccess', fallback.reportSentSuccess);

  @override
  String get reportSubmittedSuccess => OtaTranslationService.translate(locale, 'reportSubmittedSuccess', fallback.reportSubmittedSuccess);

  @override
  String get reportSummary => OtaTranslationService.translate(locale, 'reportSummary', fallback.reportSummary);

  @override
  String get reportUser => OtaTranslationService.translate(locale, 'reportUser', fallback.reportUser);

  @override
  String get reportedContent => OtaTranslationService.translate(locale, 'reportedContent', fallback.reportedContent);

  @override
  String get reportedUser => OtaTranslationService.translate(locale, 'reportedUser', fallback.reportedUser);

  @override
  String get reportsCenter => OtaTranslationService.translate(locale, 'reportsCenter', fallback.reportsCenter);

  @override
  String get reputation2 => OtaTranslationService.translate(locale, 'reputation2', fallback.reputation2);

  @override
  String get reputationLevel => OtaTranslationService.translate(locale, 'reputationLevel', fallback.reputationLevel);

  @override
  String get reputationPoints => OtaTranslationService.translate(locale, 'reputationPoints', fallback.reputationPoints);

  @override
  String get requestData => OtaTranslationService.translate(locale, 'requestData', fallback.requestData);

  @override
  String get requestDataMsg => OtaTranslationService.translate(locale, 'requestDataMsg', fallback.requestDataMsg);

  @override
  String get requestToJoin => OtaTranslationService.translate(locale, 'requestToJoin', fallback.requestToJoin);

  @override
  String get requestToJoinSent => OtaTranslationService.translate(locale, 'requestToJoinSent', fallback.requestToJoinSent);

  @override
  String get requested => OtaTranslationService.translate(locale, 'requested', fallback.requested);

  @override
  String get required => OtaTranslationService.translate(locale, 'required', fallback.required);

  @override
  String get resendCode => OtaTranslationService.translate(locale, 'resendCode', fallback.resendCode);

  @override
  String get resendEmail => OtaTranslationService.translate(locale, 'resendEmail', fallback.resendEmail);

  @override
  String get resendVerificationEmail => OtaTranslationService.translate(locale, 'resendVerificationEmail', fallback.resendVerificationEmail);

  @override
  String get reset => OtaTranslationService.translate(locale, 'reset', fallback.reset);

  @override
  String get reset2 => OtaTranslationService.translate(locale, 'reset2', fallback.reset2);

  @override
  String get resetAction => OtaTranslationService.translate(locale, 'resetAction', fallback.resetAction);

  @override
  String get resetLayout => OtaTranslationService.translate(locale, 'resetLayout', fallback.resetLayout);

  @override
  String get resetPasswordSuccess => OtaTranslationService.translate(locale, 'resetPasswordSuccess', fallback.resetPasswordSuccess);

  @override
  String get restore => OtaTranslationService.translate(locale, 'restore', fallback.restore);

  @override
  String get restorePurchases => OtaTranslationService.translate(locale, 'restorePurchases', fallback.restorePurchases);

  @override
  String get restrictContent => OtaTranslationService.translate(locale, 'restrictContent', fallback.restrictContent);

  @override
  String get results => OtaTranslationService.translate(locale, 'results', fallback.results);

  @override
  String get resume => OtaTranslationService.translate(locale, 'resume', fallback.resume);

  @override
  String get review => OtaTranslationService.translate(locale, 'review', fallback.review);

  @override
  String get reviewEntry => OtaTranslationService.translate(locale, 'reviewEntry', fallback.reviewEntry);

  @override
  String get revokeAllDevices => OtaTranslationService.translate(locale, 'revokeAllDevices', fallback.revokeAllDevices);

  @override
  String get rookie => OtaTranslationService.translate(locale, 'rookie', fallback.rookie);

  @override
  String get saveDraft => OtaTranslationService.translate(locale, 'saveDraft', fallback.saveDraft);

  @override
  String get searchByUsername => OtaTranslationService.translate(locale, 'searchByUsername', fallback.searchByUsername);

  @override
  String get searchForCommunities => OtaTranslationService.translate(locale, 'searchForCommunities', fallback.searchForCommunities);

  @override
  String get searchForGifs => OtaTranslationService.translate(locale, 'searchForGifs', fallback.searchForGifs);

  @override
  String get searchForMembers => OtaTranslationService.translate(locale, 'searchForMembers', fallback.searchForMembers);

  @override
  String get searchForMusic => OtaTranslationService.translate(locale, 'searchForMusic', fallback.searchForMusic);

  @override
  String get searchForPosts => OtaTranslationService.translate(locale, 'searchForPosts', fallback.searchForPosts);

  @override
  String get searchForStickers => OtaTranslationService.translate(locale, 'searchForStickers', fallback.searchForStickers);

  @override
  String get searchForStickers2 => OtaTranslationService.translate(locale, 'searchForStickers2', fallback.searchForStickers2);

  @override
  String get searchForUsers => OtaTranslationService.translate(locale, 'searchForUsers', fallback.searchForUsers);

  @override
  String get searchForUsers2 => OtaTranslationService.translate(locale, 'searchForUsers2', fallback.searchForUsers2);

  @override
  String get searchGifs => OtaTranslationService.translate(locale, 'searchGifs', fallback.searchGifs);

  @override
  String get searchImages => OtaTranslationService.translate(locale, 'searchImages', fallback.searchImages);

  @override
  String get searchPosts => OtaTranslationService.translate(locale, 'searchPosts', fallback.searchPosts);

  @override
  String get searchStickers => OtaTranslationService.translate(locale, 'searchStickers', fallback.searchStickers);

  @override
  String get searchUsers => OtaTranslationService.translate(locale, 'searchUsers', fallback.searchUsers);

  @override
  String get securityAndPrivacy => OtaTranslationService.translate(locale, 'securityAndPrivacy', fallback.securityAndPrivacy);

  @override
  String get seeWhoVoted => OtaTranslationService.translate(locale, 'seeWhoVoted', fallback.seeWhoVoted);

  @override
  String get selectAction => OtaTranslationService.translate(locale, 'selectAction', fallback.selectAction);

  @override
  String get selectAtLeastOne => OtaTranslationService.translate(locale, 'selectAtLeastOne', fallback.selectAtLeastOne);

  @override
  String get selectAtLeastOneInterest => OtaTranslationService.translate(locale, 'selectAtLeastOneInterest', fallback.selectAtLeastOneInterest);

  @override
  String get selectAtLeastTwo => OtaTranslationService.translate(locale, 'selectAtLeastTwo', fallback.selectAtLeastTwo);

  @override
  String get selectCover => OtaTranslationService.translate(locale, 'selectCover', fallback.selectCover);

  @override
  String get selectCoverImage => OtaTranslationService.translate(locale, 'selectCoverImage', fallback.selectCoverImage);

  @override
  String get selectDuration => OtaTranslationService.translate(locale, 'selectDuration', fallback.selectDuration);

  @override
  String get selectIcon => OtaTranslationService.translate(locale, 'selectIcon', fallback.selectIcon);

  @override
  String get selectPollEndDate => OtaTranslationService.translate(locale, 'selectPollEndDate', fallback.selectPollEndDate);

  @override
  String get selectQuizEndDate => OtaTranslationService.translate(locale, 'selectQuizEndDate', fallback.selectQuizEndDate);

  @override
  String get selectReason => OtaTranslationService.translate(locale, 'selectReason', fallback.selectReason);

  @override
  String get selectSticker => OtaTranslationService.translate(locale, 'selectSticker', fallback.selectSticker);

  @override
  String get selectVideo => OtaTranslationService.translate(locale, 'selectVideo', fallback.selectVideo);

  @override
  String get selfHarm => OtaTranslationService.translate(locale, 'selfHarm', fallback.selfHarm);

  @override
  String get sendAMessage => OtaTranslationService.translate(locale, 'sendAMessage', fallback.sendAMessage);

  @override
  String get sendBroadcastTo => OtaTranslationService.translate(locale, 'sendBroadcastTo', fallback.sendBroadcastTo);

  @override
  String get sendCoinsToUser => OtaTranslationService.translate(locale, 'sendCoinsToUser', fallback.sendCoinsToUser);

  @override
  String get sendFile => OtaTranslationService.translate(locale, 'sendFile', fallback.sendFile);

  @override
  String get sendFileToChat => OtaTranslationService.translate(locale, 'sendFileToChat', fallback.sendFileToChat);

  @override
  String get sendGif => OtaTranslationService.translate(locale, 'sendGif', fallback.sendGif);

  @override
  String get sendToEveryone => OtaTranslationService.translate(locale, 'sendToEveryone', fallback.sendToEveryone);

  @override
  String get sendingAudio => OtaTranslationService.translate(locale, 'sendingAudio', fallback.sendingAudio);

  @override
  String get sendingMessage => OtaTranslationService.translate(locale, 'sendingMessage', fallback.sendingMessage);

  @override
  String get sendingVideo => OtaTranslationService.translate(locale, 'sendingVideo', fallback.sendingVideo);

  @override
  String get sessionExpiredMessage => OtaTranslationService.translate(locale, 'sessionExpiredMessage', fallback.sessionExpiredMessage);

  @override
  String get sexualContent => OtaTranslationService.translate(locale, 'sexualContent', fallback.sexualContent);

  @override
  String get sexuallyExplicit => OtaTranslationService.translate(locale, 'sexuallyExplicit', fallback.sexuallyExplicit);

  @override
  String get shareCommunity => OtaTranslationService.translate(locale, 'shareCommunity', fallback.shareCommunity);

  @override
  String get shareImage => OtaTranslationService.translate(locale, 'shareImage', fallback.shareImage);

  @override
  String get sharePost => OtaTranslationService.translate(locale, 'sharePost', fallback.sharePost);

  @override
  String get shareProfile2 => OtaTranslationService.translate(locale, 'shareProfile2', fallback.shareProfile2);

  @override
  String get shareTheCommunity => OtaTranslationService.translate(locale, 'shareTheCommunity', fallback.shareTheCommunity);

  @override
  String get shareWiki => OtaTranslationService.translate(locale, 'shareWiki', fallback.shareWiki);

  @override
  String get shareYourThoughts => OtaTranslationService.translate(locale, 'shareYourThoughts', fallback.shareYourThoughts);

  @override
  String get showLess => OtaTranslationService.translate(locale, 'showLess', fallback.showLess);

  @override
  String get showMore => OtaTranslationService.translate(locale, 'showMore', fallback.showMore);

  @override
  String get showOriginal => OtaTranslationService.translate(locale, 'showOriginal', fallback.showOriginal);

  @override
  String get silent => OtaTranslationService.translate(locale, 'silent', fallback.silent);

  @override
  String get soundOnNotifications => OtaTranslationService.translate(locale, 'soundOnNotifications', fallback.soundOnNotifications);

  @override
  String get soundOnNotificationsDesc => OtaTranslationService.translate(locale, 'soundOnNotificationsDesc', fallback.soundOnNotificationsDesc);

  @override
  String get start => OtaTranslationService.translate(locale, 'start', fallback.start);

  @override
  String get startAConversation => OtaTranslationService.translate(locale, 'startAConversation', fallback.startAConversation);

  @override
  String get startChat => OtaTranslationService.translate(locale, 'startChat', fallback.startChat);

  @override
  String get startChatting => OtaTranslationService.translate(locale, 'startChatting', fallback.startChatting);

  @override
  String get startFollowing => OtaTranslationService.translate(locale, 'startFollowing', fallback.startFollowing);

  @override
  String get startNewChat => OtaTranslationService.translate(locale, 'startNewChat', fallback.startNewChat);

  @override
  String get startTyping => OtaTranslationService.translate(locale, 'startTyping', fallback.startTyping);

  @override
  String get stickerAddedToPost => OtaTranslationService.translate(locale, 'stickerAddedToPost', fallback.stickerAddedToPost);

  @override
  String get stickerPack => OtaTranslationService.translate(locale, 'stickerPack', fallback.stickerPack);

  @override
  String get stickerPacks => OtaTranslationService.translate(locale, 'stickerPacks', fallback.stickerPacks);

  @override
  String get story => OtaTranslationService.translate(locale, 'story', fallback.story);

  @override
  String get storyCreatedSuccess => OtaTranslationService.translate(locale, 'storyCreatedSuccess', fallback.storyCreatedSuccess);

  @override
  String get storyOptions => OtaTranslationService.translate(locale, 'storyOptions', fallback.storyOptions);

  @override
  String get storyViews => OtaTranslationService.translate(locale, 'storyViews', fallback.storyViews);

  @override
  String get strikeUser => OtaTranslationService.translate(locale, 'strikeUser', fallback.strikeUser);

  @override
  String get submit => OtaTranslationService.translate(locale, 'submit', fallback.submit);

  @override
  String get submitForReview => OtaTranslationService.translate(locale, 'submitForReview', fallback.submitForReview);

  @override
  String get submitToCatalog => OtaTranslationService.translate(locale, 'submitToCatalog', fallback.submitToCatalog);

  @override
  String get submitted => OtaTranslationService.translate(locale, 'submitted', fallback.submitted);

  @override
  String get subscribeToPlus => OtaTranslationService.translate(locale, 'subscribeToPlus', fallback.subscribeToPlus);

  @override
  String get subscription => OtaTranslationService.translate(locale, 'subscription', fallback.subscription);

  @override
  String get success => OtaTranslationService.translate(locale, 'success', fallback.success);

  @override
  String get successfullyUnfollowed => OtaTranslationService.translate(locale, 'successfullyUnfollowed', fallback.successfullyUnfollowed);

  @override
  String get successfullyUnlinked => OtaTranslationService.translate(locale, 'successfullyUnlinked', fallback.successfullyUnlinked);

  @override
  String get takeAPhoto => OtaTranslationService.translate(locale, 'takeAPhoto', fallback.takeAPhoto);

  @override
  String get takePicture => OtaTranslationService.translate(locale, 'takePicture', fallback.takePicture);

  @override
  String get tapAnAnswer => OtaTranslationService.translate(locale, 'tapAnAnswer', fallback.tapAnAnswer);

  @override
  String get tapHereToStart => OtaTranslationService.translate(locale, 'tapHereToStart', fallback.tapHereToStart);

  @override
  String get tapToAdd => OtaTranslationService.translate(locale, 'tapToAdd', fallback.tapToAdd);

  @override
  String get tapToAddDescription => OtaTranslationService.translate(locale, 'tapToAddDescription', fallback.tapToAddDescription);

  @override
  String get tapToChange => OtaTranslationService.translate(locale, 'tapToChange', fallback.tapToChange);

  @override
  String get tapToCopy => OtaTranslationService.translate(locale, 'tapToCopy', fallback.tapToCopy);

  @override
  String get tapToEdit => OtaTranslationService.translate(locale, 'tapToEdit', fallback.tapToEdit);

  @override
  String get tapToJoin => OtaTranslationService.translate(locale, 'tapToJoin', fallback.tapToJoin);

  @override
  String get tapToRecord => OtaTranslationService.translate(locale, 'tapToRecord', fallback.tapToRecord);

  @override
  String get tapToReply => OtaTranslationService.translate(locale, 'tapToReply', fallback.tapToReply);

  @override
  String get tapToSee => OtaTranslationService.translate(locale, 'tapToSee', fallback.tapToSee);

  @override
  String get tapToSeeDetails => OtaTranslationService.translate(locale, 'tapToSeeDetails', fallback.tapToSeeDetails);

  @override
  String get tapToSelect => OtaTranslationService.translate(locale, 'tapToSelect', fallback.tapToSelect);

  @override
  String get tapToStartChat => OtaTranslationService.translate(locale, 'tapToStartChat', fallback.tapToStartChat);

  @override
  String get tapToUnfollow => OtaTranslationService.translate(locale, 'tapToUnfollow', fallback.tapToUnfollow);

  @override
  String get tapToView => OtaTranslationService.translate(locale, 'tapToView', fallback.tapToView);

  @override
  String get tapToVote => OtaTranslationService.translate(locale, 'tapToVote', fallback.tapToVote);

  @override
  String get textCopied => OtaTranslationService.translate(locale, 'textCopied', fallback.textCopied);

  @override
  String get textFormatting => OtaTranslationService.translate(locale, 'textFormatting', fallback.textFormatting);

  @override
  String get theme => OtaTranslationService.translate(locale, 'theme', fallback.theme);

  @override
  String get thisActionIsIrreversible => OtaTranslationService.translate(locale, 'thisActionIsIrreversible', fallback.thisActionIsIrreversible);

  @override
  String get thisChatIsPrivate => OtaTranslationService.translate(locale, 'thisChatIsPrivate', fallback.thisChatIsPrivate);

  @override
  String get thisChatIsPublic => OtaTranslationService.translate(locale, 'thisChatIsPublic', fallback.thisChatIsPublic);

  @override
  String get thisContentIsHidden => OtaTranslationService.translate(locale, 'thisContentIsHidden', fallback.thisContentIsHidden);

  @override
  String get thisPostIsPrivate => OtaTranslationService.translate(locale, 'thisPostIsPrivate', fallback.thisPostIsPrivate);

  @override
  String get thisPostIsPublic => OtaTranslationService.translate(locale, 'thisPostIsPublic', fallback.thisPostIsPublic);

  @override
  String get title2 => OtaTranslationService.translate(locale, 'title2', fallback.title2);

  @override
  String get titleIsRequired => OtaTranslationService.translate(locale, 'titleIsRequired', fallback.titleIsRequired);

  @override
  String get titleLabel => OtaTranslationService.translate(locale, 'titleLabel', fallback.titleLabel);

  @override
  String get titleOptional => OtaTranslationService.translate(locale, 'titleOptional', fallback.titleOptional);

  @override
  String get todayAt => OtaTranslationService.translate(locale, 'todayAt', fallback.todayAt);

  @override
  String get topFans => OtaTranslationService.translate(locale, 'topFans', fallback.topFans);

  @override
  String get transferCoins => OtaTranslationService.translate(locale, 'transferCoins', fallback.transferCoins);

  @override
  String get transferLeadership => OtaTranslationService.translate(locale, 'transferLeadership', fallback.transferLeadership);

  @override
  String get transferOwnership => OtaTranslationService.translate(locale, 'transferOwnership', fallback.transferOwnership);

  @override
  String get transferTo => OtaTranslationService.translate(locale, 'transferTo', fallback.transferTo);

  @override
  String get transfering => OtaTranslationService.translate(locale, 'transfering', fallback.transfering);

  @override
  String get transferingOwner => OtaTranslationService.translate(locale, 'transferingOwner', fallback.transferingOwner);

  @override
  String get translate => OtaTranslationService.translate(locale, 'translate', fallback.translate);

  @override
  String get translation => OtaTranslationService.translate(locale, 'translation', fallback.translation);

  @override
  String get typeSomething => OtaTranslationService.translate(locale, 'typeSomething', fallback.typeSomething);

  @override
  String get typeYourMessage => OtaTranslationService.translate(locale, 'typeYourMessage', fallback.typeYourMessage);

  @override
  String get typeYourMessageHere => OtaTranslationService.translate(locale, 'typeYourMessageHere', fallback.typeYourMessageHere);

  @override
  String get unbanUser => OtaTranslationService.translate(locale, 'unbanUser', fallback.unbanUser);

  @override
  String get unblockUserConfirmation => OtaTranslationService.translate(locale, 'unblockUserConfirmation', fallback.unblockUserConfirmation);

  @override
  String get underlineFormat => OtaTranslationService.translate(locale, 'underlineFormat', fallback.underlineFormat);

  @override
  String get unfeature => OtaTranslationService.translate(locale, 'unfeature', fallback.unfeature);

  @override
  String get unfeaturePost => OtaTranslationService.translate(locale, 'unfeaturePost', fallback.unfeaturePost);

  @override
  String get unfollowUser => OtaTranslationService.translate(locale, 'unfollowUser', fallback.unfollowUser);

  @override
  String get unfollowUserConfirmation => OtaTranslationService.translate(locale, 'unfollowUserConfirmation', fallback.unfollowUserConfirmation);

  @override
  String get unknownUser => OtaTranslationService.translate(locale, 'unknownUser', fallback.unknownUser);

  @override
  String get unlinkProvider => OtaTranslationService.translate(locale, 'unlinkProvider', fallback.unlinkProvider);

  @override
  String get unpin => OtaTranslationService.translate(locale, 'unpin', fallback.unpin);

  @override
  String get unpinFromBlog => OtaTranslationService.translate(locale, 'unpinFromBlog', fallback.unpinFromBlog);

  @override
  String get unpinFromCommunityHome => OtaTranslationService.translate(locale, 'unpinFromCommunityHome', fallback.unpinFromCommunityHome);

  @override
  String get unpinMessage => OtaTranslationService.translate(locale, 'unpinMessage', fallback.unpinMessage);

  @override
  String get unread => OtaTranslationService.translate(locale, 'unread', fallback.unread);

  @override
  String get unreadChats => OtaTranslationService.translate(locale, 'unreadChats', fallback.unreadChats);

  @override
  String get unsupportedLink => OtaTranslationService.translate(locale, 'unsupportedLink', fallback.unsupportedLink);

  @override
  String get until => OtaTranslationService.translate(locale, 'until', fallback.until);

  @override
  String get upcoming => OtaTranslationService.translate(locale, 'upcoming', fallback.upcoming);

  @override
  String get updateAction => OtaTranslationService.translate(locale, 'updateAction', fallback.updateAction);

  @override
  String get updateAvailable => OtaTranslationService.translate(locale, 'updateAvailable', fallback.updateAvailable);

  @override
  String get updateEmail => OtaTranslationService.translate(locale, 'updateEmail', fallback.updateEmail);

  @override
  String get updateNow => OtaTranslationService.translate(locale, 'updateNow', fallback.updateNow);

  @override
  String get uploadFromGallery => OtaTranslationService.translate(locale, 'uploadFromGallery', fallback.uploadFromGallery);

  @override
  String get uploadVideo => OtaTranslationService.translate(locale, 'uploadVideo', fallback.uploadVideo);

  @override
  String get uploading => OtaTranslationService.translate(locale, 'uploading', fallback.uploading);

  @override
  String get uploadingFile => OtaTranslationService.translate(locale, 'uploadingFile', fallback.uploadingFile);

  @override
  String get uploadingImage => OtaTranslationService.translate(locale, 'uploadingImage', fallback.uploadingImage);

  @override
  String get uploadingVideo => OtaTranslationService.translate(locale, 'uploadingVideo', fallback.uploadingVideo);

  @override
  String get userBanned => OtaTranslationService.translate(locale, 'userBanned', fallback.userBanned);

  @override
  String get userHasBeenBanned => OtaTranslationService.translate(locale, 'userHasBeenBanned', fallback.userHasBeenBanned);

  @override
  String get userHasBeenKicked => OtaTranslationService.translate(locale, 'userHasBeenKicked', fallback.userHasBeenKicked);

  @override
  String get userHasBeenMuted => OtaTranslationService.translate(locale, 'userHasBeenMuted', fallback.userHasBeenMuted);

  @override
  String get userHasBeenUnbanned => OtaTranslationService.translate(locale, 'userHasBeenUnbanned', fallback.userHasBeenUnbanned);

  @override
  String get userHasBeenWarned => OtaTranslationService.translate(locale, 'userHasBeenWarned', fallback.userHasBeenWarned);

  @override
  String get userKicked => OtaTranslationService.translate(locale, 'userKicked', fallback.userKicked);

  @override
  String get userMuted => OtaTranslationService.translate(locale, 'userMuted', fallback.userMuted);

  @override
  String get userNotFound => OtaTranslationService.translate(locale, 'userNotFound', fallback.userNotFound);

  @override
  String get userProfile => OtaTranslationService.translate(locale, 'userProfile', fallback.userProfile);

  @override
  String get userUnbanned => OtaTranslationService.translate(locale, 'userUnbanned', fallback.userUnbanned);

  @override
  String get userWarned => OtaTranslationService.translate(locale, 'userWarned', fallback.userWarned);

  @override
  String get verificationEmailSent => OtaTranslationService.translate(locale, 'verificationEmailSent', fallback.verificationEmailSent);

  @override
  String get veteran => OtaTranslationService.translate(locale, 'veteran', fallback.veteran);

  @override
  String get video2 => OtaTranslationService.translate(locale, 'video2', fallback.video2);

  @override
  String get videoAddedToPost => OtaTranslationService.translate(locale, 'videoAddedToPost', fallback.videoAddedToPost);

  @override
  String get videoPublishedSuccess => OtaTranslationService.translate(locale, 'videoPublishedSuccess', fallback.videoPublishedSuccess);

  @override
  String get videoTitle => OtaTranslationService.translate(locale, 'videoTitle', fallback.videoTitle);

  @override
  String get viewAll => OtaTranslationService.translate(locale, 'viewAll', fallback.viewAll);

  @override
  String get viewAll2 => OtaTranslationService.translate(locale, 'viewAll2', fallback.viewAll2);

  @override
  String get viewParticipants => OtaTranslationService.translate(locale, 'viewParticipants', fallback.viewParticipants);

  @override
  String get viewPost => OtaTranslationService.translate(locale, 'viewPost', fallback.viewPost);

  @override
  String get viewProfile => OtaTranslationService.translate(locale, 'viewProfile', fallback.viewProfile);

  @override
  String get viewResults => OtaTranslationService.translate(locale, 'viewResults', fallback.viewResults);

  @override
  String get viewStory => OtaTranslationService.translate(locale, 'viewStory', fallback.viewStory);

  @override
  String get violentContent => OtaTranslationService.translate(locale, 'violentContent', fallback.violentContent);

  @override
  String get visitor => OtaTranslationService.translate(locale, 'visitor', fallback.visitor);

  @override
  String get voiceChat => OtaTranslationService.translate(locale, 'voiceChat', fallback.voiceChat);

  @override
  String get voiceNote => OtaTranslationService.translate(locale, 'voiceNote', fallback.voiceNote);

  @override
  String get waitingForWifi => OtaTranslationService.translate(locale, 'waitingForWifi', fallback.waitingForWifi);

  @override
  String get wall2 => OtaTranslationService.translate(locale, 'wall2', fallback.wall2);

  @override
  String get wallComments => OtaTranslationService.translate(locale, 'wallComments', fallback.wallComments);

  @override
  String get warnUser => OtaTranslationService.translate(locale, 'warnUser', fallback.warnUser);

  @override
  String get warning => OtaTranslationService.translate(locale, 'warning', fallback.warning);

  @override
  String get warningSent => OtaTranslationService.translate(locale, 'warningSent', fallback.warningSent);

  @override
  String get watch => OtaTranslationService.translate(locale, 'watch', fallback.watch);

  @override
  String get watchAds => OtaTranslationService.translate(locale, 'watchAds', fallback.watchAds);

  @override
  String get watchVideo => OtaTranslationService.translate(locale, 'watchVideo', fallback.watchVideo);

  @override
  String get welcome2 => OtaTranslationService.translate(locale, 'welcome2', fallback.welcome2);

  @override
  String get welcomeToOurCommunity => OtaTranslationService.translate(locale, 'welcomeToOurCommunity', fallback.welcomeToOurCommunity);

  @override
  String get wiki2 => OtaTranslationService.translate(locale, 'wiki2', fallback.wiki2);

  @override
  String get writeAComment => OtaTranslationService.translate(locale, 'writeAComment', fallback.writeAComment);

  @override
  String get writeAMessage => OtaTranslationService.translate(locale, 'writeAMessage', fallback.writeAMessage);

  @override
  String get writeAPost => OtaTranslationService.translate(locale, 'writeAPost', fallback.writeAPost);

  @override
  String get writeAReply => OtaTranslationService.translate(locale, 'writeAReply', fallback.writeAReply);

  @override
  String get writeSomething => OtaTranslationService.translate(locale, 'writeSomething', fallback.writeSomething);

  @override
  String get writeYourMessage => OtaTranslationService.translate(locale, 'writeYourMessage', fallback.writeYourMessage);

  @override
  String get yes2 => OtaTranslationService.translate(locale, 'yes2', fallback.yes2);

  @override
  String get yesDeleteIt => OtaTranslationService.translate(locale, 'yesDeleteIt', fallback.yesDeleteIt);

  @override
  String get youAreBanned => OtaTranslationService.translate(locale, 'youAreBanned', fallback.youAreBanned);

  @override
  String get youAreMuted => OtaTranslationService.translate(locale, 'youAreMuted', fallback.youAreMuted);

  @override
  String get youAreNotFollowingAnyone => OtaTranslationService.translate(locale, 'youAreNotFollowingAnyone', fallback.youAreNotFollowingAnyone);

  @override
  String get youHaveBeenBanned => OtaTranslationService.translate(locale, 'youHaveBeenBanned', fallback.youHaveBeenBanned);

  @override
  String get youHaveBeenKicked => OtaTranslationService.translate(locale, 'youHaveBeenKicked', fallback.youHaveBeenKicked);

  @override
  String get youHaveBeenMuted => OtaTranslationService.translate(locale, 'youHaveBeenMuted', fallback.youHaveBeenMuted);

  @override
  String get youHaveBeenWarned => OtaTranslationService.translate(locale, 'youHaveBeenWarned', fallback.youHaveBeenWarned);

  @override
  String get youHaveNoDrafts => OtaTranslationService.translate(locale, 'youHaveNoDrafts', fallback.youHaveNoDrafts);

  @override
  String get youHaveNoFollowers => OtaTranslationService.translate(locale, 'youHaveNoFollowers', fallback.youHaveNoFollowers);

  @override
  String get youHaveNoPosts => OtaTranslationService.translate(locale, 'youHaveNoPosts', fallback.youHaveNoPosts);

  @override
  String get youHaveNoSavedPosts => OtaTranslationService.translate(locale, 'youHaveNoSavedPosts', fallback.youHaveNoSavedPosts);

  @override
  String get yourAccount => OtaTranslationService.translate(locale, 'yourAccount', fallback.yourAccount);

  @override
  String get yourAccountHasBeenDeleted => OtaTranslationService.translate(locale, 'yourAccountHasBeenDeleted', fallback.yourAccountHasBeenDeleted);

  @override
  String get yourChangesHaveBeenSaved => OtaTranslationService.translate(locale, 'yourChangesHaveBeenSaved', fallback.yourChangesHaveBeenSaved);

  @override
  String get yourEmailHasBeenVerified => OtaTranslationService.translate(locale, 'yourEmailHasBeenVerified', fallback.yourEmailHasBeenVerified);

  @override
  String get yourInterests => OtaTranslationService.translate(locale, 'yourInterests', fallback.yourInterests);

  @override
  String get yourLanguages => OtaTranslationService.translate(locale, 'yourLanguages', fallback.yourLanguages);

  @override
  String get yourNickname => OtaTranslationService.translate(locale, 'yourNickname', fallback.yourNickname);

  @override
  String get yourProfile => OtaTranslationService.translate(locale, 'yourProfile', fallback.yourProfile);

  @override
  String get yourProfileIsNowPublic => OtaTranslationService.translate(locale, 'yourProfileIsNowPublic', fallback.yourProfileIsNowPublic);

  @override
  String get yourTopCommunities => OtaTranslationService.translate(locale, 'yourTopCommunities', fallback.yourTopCommunities);

  @override
  String get yourWallIsEmpty => OtaTranslationService.translate(locale, 'yourWallIsEmpty', fallback.yourWallIsEmpty);

  @override
  String get youtubeVideo => OtaTranslationService.translate(locale, 'youtubeVideo', fallback.youtubeVideo);

  @override
  String get coverPhoto => OtaTranslationService.translate(locale, 'coverPhoto', fallback.coverPhoto);

  @override
  String get chatIcon => OtaTranslationService.translate(locale, 'chatIcon', fallback.chatIcon);

  @override
  String get chatIconHint => OtaTranslationService.translate(locale, 'chatIconHint', fallback.chatIconHint);

  @override
  String get coverPhotoHint => OtaTranslationService.translate(locale, 'coverPhotoHint', fallback.coverPhotoHint);

  @override
  String get chatAppearance => OtaTranslationService.translate(locale, 'chatAppearance', fallback.chatAppearance);

  @override
  String get chatSettings2 => OtaTranslationService.translate(locale, 'chatSettings2', fallback.chatSettings2);

  @override
  String get slowMode => OtaTranslationService.translate(locale, 'slowMode', fallback.slowMode);

  @override
  String get slowModeDesc => OtaTranslationService.translate(locale, 'slowModeDesc', fallback.slowModeDesc);

  @override
  String get announcementOnlyMode => OtaTranslationService.translate(locale, 'announcementOnlyMode', fallback.announcementOnlyMode);

  @override
  String get announcementOnlyModeDesc => OtaTranslationService.translate(locale, 'announcementOnlyModeDesc', fallback.announcementOnlyModeDesc);

  @override
  String get voiceChatEnabled => OtaTranslationService.translate(locale, 'voiceChatEnabled', fallback.voiceChatEnabled);

  @override
  String get voiceChatEnabledDesc => OtaTranslationService.translate(locale, 'voiceChatEnabledDesc', fallback.voiceChatEnabledDesc);

  @override
  String get videoChatEnabled => OtaTranslationService.translate(locale, 'videoChatEnabled', fallback.videoChatEnabled);

  @override
  String get videoChatEnabledDesc => OtaTranslationService.translate(locale, 'videoChatEnabledDesc', fallback.videoChatEnabledDesc);

  @override
  String get projectionRoomEnabled => OtaTranslationService.translate(locale, 'projectionRoomEnabled', fallback.projectionRoomEnabled);

  @override
  String get projectionRoomEnabledDesc => OtaTranslationService.translate(locale, 'projectionRoomEnabledDesc', fallback.projectionRoomEnabledDesc);

  @override
  String get tapToChangeCover => OtaTranslationService.translate(locale, 'tapToChangeCover', fallback.tapToChangeCover);

  @override
  String get tapToChangeIcon => OtaTranslationService.translate(locale, 'tapToChangeIcon', fallback.tapToChangeIcon);

  @override
  String get chatCreatedSuccess => OtaTranslationService.translate(locale, 'chatCreatedSuccess', fallback.chatCreatedSuccess);

  @override
  String get chatPermissions => OtaTranslationService.translate(locale, 'chatPermissions', fallback.chatPermissions);

  @override
  String get onlyHostsCanSend => OtaTranslationService.translate(locale, 'onlyHostsCanSend', fallback.onlyHostsCanSend);

  @override
  String get allMembersCanSend => OtaTranslationService.translate(locale, 'allMembersCanSend', fallback.allMembersCanSend);

  @override
  String get chatVisibility => OtaTranslationService.translate(locale, 'chatVisibility', fallback.chatVisibility);

  @override
  String get publicChatDesc => OtaTranslationService.translate(locale, 'publicChatDesc', fallback.publicChatDesc);

  @override
  String get privateChatDesc => OtaTranslationService.translate(locale, 'privateChatDesc', fallback.privateChatDesc);

  @override
  String get editProfileFrames => OtaTranslationService.translate(locale, 'editProfileFrames', fallback.editProfileFrames);

  @override
  String get profileBackgroundOptional => OtaTranslationService.translate(locale, 'profileBackgroundOptional', fallback.profileBackgroundOptional);

  @override
  String get removeBackground => OtaTranslationService.translate(locale, 'removeBackground', fallback.removeBackground);

  @override
  String get addPhotoToGallery => OtaTranslationService.translate(locale, 'addPhotoToGallery', fallback.addPhotoToGallery);

  @override
  String get removePhoto => OtaTranslationService.translate(locale, 'removePhoto', fallback.removePhoto);

  @override
  String get galleryCount => OtaTranslationService.translate(locale, 'galleryCount', fallback.galleryCount);

  @override
  String get nicknameStyleHint => OtaTranslationService.translate(locale, 'nicknameStyleHint', fallback.nicknameStyleHint);

  @override
  String get tapToEditAvatar => OtaTranslationService.translate(locale, 'tapToEditAvatar', fallback.tapToEditAvatar);

  @override
  String get localAvatarRemoved => OtaTranslationService.translate(locale, 'localAvatarRemoved', fallback.localAvatarRemoved);

  @override
  String get maxGalleryPhotos => OtaTranslationService.translate(locale, 'maxGalleryPhotos', fallback.maxGalleryPhotos);

  @override
  String get backgroundColorSolid => OtaTranslationService.translate(locale, 'backgroundColorSolid', fallback.backgroundColorSolid);

  @override
  String get backgroundFromGallery => OtaTranslationService.translate(locale, 'backgroundFromGallery', fallback.backgroundFromGallery);

  @override
  String get backgroundTypeLabel => OtaTranslationService.translate(locale, 'backgroundTypeLabel', fallback.backgroundTypeLabel);

  @override
  String get galleryAsBannerHint => OtaTranslationService.translate(locale, 'galleryAsBannerHint', fallback.galleryAsBannerHint);

  @override
  String get bioAndWallTitle => OtaTranslationService.translate(locale, 'bioAndWallTitle', fallback.bioAndWallTitle);

  @override
  String get viewWikiEntry => OtaTranslationService.translate(locale, 'viewWikiEntry', fallback.viewWikiEntry);

  @override
  String get wikiHide => OtaTranslationService.translate(locale, 'wikiHide', fallback.wikiHide);

  @override
  String get wikiUnhide => OtaTranslationService.translate(locale, 'wikiUnhide', fallback.wikiUnhide);

  @override
  String get wikiHidden => OtaTranslationService.translate(locale, 'wikiHidden', fallback.wikiHidden);

  @override
  String get wikiUnhidden => OtaTranslationService.translate(locale, 'wikiUnhidden', fallback.wikiUnhidden);

  @override
  String get wikiCanonize => OtaTranslationService.translate(locale, 'wikiCanonize', fallback.wikiCanonize);

  @override
  String get wikiDecanonize => OtaTranslationService.translate(locale, 'wikiDecanonize', fallback.wikiDecanonize);

  @override
  String get wikiCanonized => OtaTranslationService.translate(locale, 'wikiCanonized', fallback.wikiCanonized);

  @override
  String get wikiDecanonized => OtaTranslationService.translate(locale, 'wikiDecanonized', fallback.wikiDecanonized);

  @override
  String get wikiCanonicalBadge => OtaTranslationService.translate(locale, 'wikiCanonicalBadge', fallback.wikiCanonicalBadge);

  @override
  String get wikiCommentDeleted => OtaTranslationService.translate(locale, 'wikiCommentDeleted', fallback.wikiCommentDeleted);

  @override
  String get wikiCommentDeleteError => OtaTranslationService.translate(locale, 'wikiCommentDeleteError', fallback.wikiCommentDeleteError);

  @override
  String get wikiCommentCopied => OtaTranslationService.translate(locale, 'wikiCommentCopied', fallback.wikiCommentCopied);

  @override
  String get myTitle => OtaTranslationService.translate(locale, 'myTitle', fallback.myTitle);

  @override
  String get communityInfo => OtaTranslationService.translate(locale, 'communityInfo', fallback.communityInfo);

  @override
  String get management => OtaTranslationService.translate(locale, 'management', fallback.management);

  @override
  String get appealsTitle => OtaTranslationService.translate(locale, 'appealsTitle', fallback.appealsTitle);

  @override
  String get appealsSubtitle => OtaTranslationService.translate(locale, 'appealsSubtitle', fallback.appealsSubtitle);

  @override
  String get appealsSettingsSubtitle => OtaTranslationService.translate(locale, 'appealsSettingsSubtitle', fallback.appealsSettingsSubtitle);

  @override
  String get appealsEmpty => OtaTranslationService.translate(locale, 'appealsEmpty', fallback.appealsEmpty);

  @override
  String get appealsEmptyDesc => OtaTranslationService.translate(locale, 'appealsEmptyDesc', fallback.appealsEmptyDesc);

  @override
  String get appealsPending => OtaTranslationService.translate(locale, 'appealsPending', fallback.appealsPending);

  @override
  String get appealsApproved => OtaTranslationService.translate(locale, 'appealsApproved', fallback.appealsApproved);

  @override
  String get appealsRejected => OtaTranslationService.translate(locale, 'appealsRejected', fallback.appealsRejected);

  @override
  String get appealsStatusPending => OtaTranslationService.translate(locale, 'appealsStatusPending', fallback.appealsStatusPending);

  @override
  String get appealsStatusApproved => OtaTranslationService.translate(locale, 'appealsStatusApproved', fallback.appealsStatusApproved);

  @override
  String get appealsStatusRejected => OtaTranslationService.translate(locale, 'appealsStatusRejected', fallback.appealsStatusRejected);

  @override
  String get submitAppeal => OtaTranslationService.translate(locale, 'submitAppeal', fallback.submitAppeal);

  @override
  String get submitAppealTitle => OtaTranslationService.translate(locale, 'submitAppealTitle', fallback.submitAppealTitle);

  @override
  String get appealReasonLabel => OtaTranslationService.translate(locale, 'appealReasonLabel', fallback.appealReasonLabel);

  @override
  String get appealReasonHint => OtaTranslationService.translate(locale, 'appealReasonHint', fallback.appealReasonHint);

  @override
  String get appealReasonTooShort => OtaTranslationService.translate(locale, 'appealReasonTooShort', fallback.appealReasonTooShort);

  @override
  String get appealSubmitted => OtaTranslationService.translate(locale, 'appealSubmitted', fallback.appealSubmitted);

  @override
  String get appealSubmittedDesc => OtaTranslationService.translate(locale, 'appealSubmittedDesc', fallback.appealSubmittedDesc);

  @override
  String get appealAlreadyPending => OtaTranslationService.translate(locale, 'appealAlreadyPending', fallback.appealAlreadyPending);

  @override
  String get appealNotBanned => OtaTranslationService.translate(locale, 'appealNotBanned', fallback.appealNotBanned);

  @override
  String get appealCommunity => OtaTranslationService.translate(locale, 'appealCommunity', fallback.appealCommunity);

  @override
  String get appealBanReason => OtaTranslationService.translate(locale, 'appealBanReason', fallback.appealBanReason);

  @override
  String get appealBanDate => OtaTranslationService.translate(locale, 'appealBanDate', fallback.appealBanDate);

  @override
  String get appealPermanent => OtaTranslationService.translate(locale, 'appealPermanent', fallback.appealPermanent);

  @override
  String get appealExpires => OtaTranslationService.translate(locale, 'appealExpires', fallback.appealExpires);

  @override
  String get appealReviewedBy => OtaTranslationService.translate(locale, 'appealReviewedBy', fallback.appealReviewedBy);

  @override
  String get appealReviewNote => OtaTranslationService.translate(locale, 'appealReviewNote', fallback.appealReviewNote);

  @override
  String get securityCenterTitle => OtaTranslationService.translate(locale, 'securityCenterTitle', fallback.securityCenterTitle);

  @override
  String get securityCenterSubtitle => OtaTranslationService.translate(locale, 'securityCenterSubtitle', fallback.securityCenterSubtitle);

  @override
  String get securityEventsTitle => OtaTranslationService.translate(locale, 'securityEventsTitle', fallback.securityEventsTitle);

  @override
  String get securityEventsEmpty => OtaTranslationService.translate(locale, 'securityEventsEmpty', fallback.securityEventsEmpty);

  @override
  String get securityEventLogin => OtaTranslationService.translate(locale, 'securityEventLogin', fallback.securityEventLogin);

  @override
  String get securityEventPasswordChange => OtaTranslationService.translate(locale, 'securityEventPasswordChange', fallback.securityEventPasswordChange);

  @override
  String get securityEventEmailChange => OtaTranslationService.translate(locale, 'securityEventEmailChange', fallback.securityEventEmailChange);

  @override
  String get securityEventTwoFactorEnabled => OtaTranslationService.translate(locale, 'securityEventTwoFactorEnabled', fallback.securityEventTwoFactorEnabled);

  @override
  String get securityEventTwoFactorDisabled => OtaTranslationService.translate(locale, 'securityEventTwoFactorDisabled', fallback.securityEventTwoFactorDisabled);

  @override
  String get securityEventSuspiciousLogin => OtaTranslationService.translate(locale, 'securityEventSuspiciousLogin', fallback.securityEventSuspiciousLogin);

  @override
  String get securityEventAccountLocked => OtaTranslationService.translate(locale, 'securityEventAccountLocked', fallback.securityEventAccountLocked);

  @override
  String get securityEventUnknown => OtaTranslationService.translate(locale, 'securityEventUnknown', fallback.securityEventUnknown);

  @override
  String get securitySettingsTitle => OtaTranslationService.translate(locale, 'securitySettingsTitle', fallback.securitySettingsTitle);

  @override
  String get securityTwoFactor => OtaTranslationService.translate(locale, 'securityTwoFactor', fallback.securityTwoFactor);

  @override
  String get securityTwoFactorDesc => OtaTranslationService.translate(locale, 'securityTwoFactorDesc', fallback.securityTwoFactorDesc);

  @override
  String get securityLoginAlerts => OtaTranslationService.translate(locale, 'securityLoginAlerts', fallback.securityLoginAlerts);

  @override
  String get securityLoginAlertsDesc => OtaTranslationService.translate(locale, 'securityLoginAlertsDesc', fallback.securityLoginAlertsDesc);

  @override
  String get securitySuspiciousAlerts => OtaTranslationService.translate(locale, 'securitySuspiciousAlerts', fallback.securitySuspiciousAlerts);

  @override
  String get securitySuspiciousAlertsDesc => OtaTranslationService.translate(locale, 'securitySuspiciousAlertsDesc', fallback.securitySuspiciousAlertsDesc);

  @override
  String get securityActiveSessionsTitle => OtaTranslationService.translate(locale, 'securityActiveSessionsTitle', fallback.securityActiveSessionsTitle);

  @override
  String get securityActiveSessionsDesc => OtaTranslationService.translate(locale, 'securityActiveSessionsDesc', fallback.securityActiveSessionsDesc);

  @override
  String get securityCurrentDevice => OtaTranslationService.translate(locale, 'securityCurrentDevice', fallback.securityCurrentDevice);

  @override
  String get securityTerminateSession => OtaTranslationService.translate(locale, 'securityTerminateSession', fallback.securityTerminateSession);

  @override
  String get securityTerminateAllSessions => OtaTranslationService.translate(locale, 'securityTerminateAllSessions', fallback.securityTerminateAllSessions);

  @override
  String get securityTerminateConfirm => OtaTranslationService.translate(locale, 'securityTerminateConfirm', fallback.securityTerminateConfirm);

  @override
  String get securitySessionTerminated => OtaTranslationService.translate(locale, 'securitySessionTerminated', fallback.securitySessionTerminated);

  @override
  String get securityAllSessionsTerminated => OtaTranslationService.translate(locale, 'securityAllSessionsTerminated', fallback.securityAllSessionsTerminated);

  @override
  String get managementLogsTitle => OtaTranslationService.translate(locale, 'managementLogsTitle', fallback.managementLogsTitle);

  @override
  String get managementLogsEmpty => OtaTranslationService.translate(locale, 'managementLogsEmpty', fallback.managementLogsEmpty);

  @override
  String get managementLogsTotalActions => OtaTranslationService.translate(locale, 'managementLogsTotalActions', fallback.managementLogsTotalActions);

  @override
  String get managementLogsBans => OtaTranslationService.translate(locale, 'managementLogsBans', fallback.managementLogsBans);

  @override
  String get managementLogsPendingFlags => OtaTranslationService.translate(locale, 'managementLogsPendingFlags', fallback.managementLogsPendingFlags);

  @override
  String get managementLogsPendingAppeals => OtaTranslationService.translate(locale, 'managementLogsPendingAppeals', fallback.managementLogsPendingAppeals);

  @override
  String get logReason => OtaTranslationService.translate(locale, 'logReason', fallback.logReason);

  @override
  String get logDuration => OtaTranslationService.translate(locale, 'logDuration', fallback.logDuration);

  @override
  String get logDurationPermanent => OtaTranslationService.translate(locale, 'logDurationPermanent', fallback.logDurationPermanent);

  @override
  String get logDurationHours => OtaTranslationService.translate(locale, 'logDurationHours', fallback.logDurationHours);

  @override
  String get logExpiresAt => OtaTranslationService.translate(locale, 'logExpiresAt', fallback.logExpiresAt);

  @override
  String get logTargetPost => OtaTranslationService.translate(locale, 'logTargetPost', fallback.logTargetPost);

  @override
  String get logTargetUser => OtaTranslationService.translate(locale, 'logTargetUser', fallback.logTargetUser);

  @override
  String get logAutomated => OtaTranslationService.translate(locale, 'logAutomated', fallback.logAutomated);

  @override
  String get actionBan => OtaTranslationService.translate(locale, 'actionBan', fallback.actionBan);

  @override
  String get actionUnban => OtaTranslationService.translate(locale, 'actionUnban', fallback.actionUnban);

  @override
  String get actionWarn => OtaTranslationService.translate(locale, 'actionWarn', fallback.actionWarn);

  @override
  String get actionMute => OtaTranslationService.translate(locale, 'actionMute', fallback.actionMute);

  @override
  String get actionUnmute => OtaTranslationService.translate(locale, 'actionUnmute', fallback.actionUnmute);

  @override
  String get actionDeletePost => OtaTranslationService.translate(locale, 'actionDeletePost', fallback.actionDeletePost);

  @override
  String get actionDeleteContent => OtaTranslationService.translate(locale, 'actionDeleteContent', fallback.actionDeleteContent);

  @override
  String get actionPinPost => OtaTranslationService.translate(locale, 'actionPinPost', fallback.actionPinPost);

  @override
  String get actionUnpinPost => OtaTranslationService.translate(locale, 'actionUnpinPost', fallback.actionUnpinPost);

  @override
  String get actionApproveFlag => OtaTranslationService.translate(locale, 'actionApproveFlag', fallback.actionApproveFlag);

  @override
  String get actionDismissFlag => OtaTranslationService.translate(locale, 'actionDismissFlag', fallback.actionDismissFlag);

  @override
  String get actionAcceptAppeal => OtaTranslationService.translate(locale, 'actionAcceptAppeal', fallback.actionAcceptAppeal);

  @override
  String get actionRejectAppeal => OtaTranslationService.translate(locale, 'actionRejectAppeal', fallback.actionRejectAppeal);

  @override
  String get actionStrike => OtaTranslationService.translate(locale, 'actionStrike', fallback.actionStrike);

  @override
  String get actionFeaturePost => OtaTranslationService.translate(locale, 'actionFeaturePost', fallback.actionFeaturePost);

  @override
  String get actionUnfeaturePost => OtaTranslationService.translate(locale, 'actionUnfeaturePost', fallback.actionUnfeaturePost);

  @override
  String get actionHidePost => OtaTranslationService.translate(locale, 'actionHidePost', fallback.actionHidePost);

  @override
  String get actionUnhidePost => OtaTranslationService.translate(locale, 'actionUnhidePost', fallback.actionUnhidePost);

  @override
  String get actionPromote => OtaTranslationService.translate(locale, 'actionPromote', fallback.actionPromote);

  @override
  String get actionDemote => OtaTranslationService.translate(locale, 'actionDemote', fallback.actionDemote);

  @override
  String get actionKick => OtaTranslationService.translate(locale, 'actionKick', fallback.actionKick);

  @override
  String get actionWikiApprove => OtaTranslationService.translate(locale, 'actionWikiApprove', fallback.actionWikiApprove);

  @override
  String get actionWikiReject => OtaTranslationService.translate(locale, 'actionWikiReject', fallback.actionWikiReject);

  @override
  String get actionCanonizeWiki => OtaTranslationService.translate(locale, 'actionCanonizeWiki', fallback.actionCanonizeWiki);

  @override
  String get actionDecanonizeWiki => OtaTranslationService.translate(locale, 'actionDecanonizeWiki', fallback.actionDecanonizeWiki);

  @override
  String get actionTransferAgent => OtaTranslationService.translate(locale, 'actionTransferAgent', fallback.actionTransferAgent);

  @override
  String get filterAll => OtaTranslationService.translate(locale, 'filterAll', fallback.filterAll);

  @override
  String get filterBan => OtaTranslationService.translate(locale, 'filterBan', fallback.filterBan);

  @override
  String get filterWarn => OtaTranslationService.translate(locale, 'filterWarn', fallback.filterWarn);

  @override
  String get filterDeletePost => OtaTranslationService.translate(locale, 'filterDeletePost', fallback.filterDeletePost);

  @override
  String get filterMute => OtaTranslationService.translate(locale, 'filterMute', fallback.filterMute);

  @override
  String get filterUnban => OtaTranslationService.translate(locale, 'filterUnban', fallback.filterUnban);

  @override
  String get filterKick => OtaTranslationService.translate(locale, 'filterKick', fallback.filterKick);

  @override
  String get filterStrike => OtaTranslationService.translate(locale, 'filterStrike', fallback.filterStrike);

  @override
  String get filterUnmute => OtaTranslationService.translate(locale, 'filterUnmute', fallback.filterUnmute);

  @override
  String get filterDeleteContent => OtaTranslationService.translate(locale, 'filterDeleteContent', fallback.filterDeleteContent);

  @override
  String get filterHidePost => OtaTranslationService.translate(locale, 'filterHidePost', fallback.filterHidePost);

  @override
  String get filterUnhidePost => OtaTranslationService.translate(locale, 'filterUnhidePost', fallback.filterUnhidePost);

  @override
  String get filterPinPost => OtaTranslationService.translate(locale, 'filterPinPost', fallback.filterPinPost);

  @override
  String get filterUnpinPost => OtaTranslationService.translate(locale, 'filterUnpinPost', fallback.filterUnpinPost);

  @override
  String get filterFeaturePost => OtaTranslationService.translate(locale, 'filterFeaturePost', fallback.filterFeaturePost);

  @override
  String get filterUnfeaturePost => OtaTranslationService.translate(locale, 'filterUnfeaturePost', fallback.filterUnfeaturePost);

  @override
  String get filterPromote => OtaTranslationService.translate(locale, 'filterPromote', fallback.filterPromote);

  @override
  String get filterDemote => OtaTranslationService.translate(locale, 'filterDemote', fallback.filterDemote);

  @override
  String get filterWikiApprove => OtaTranslationService.translate(locale, 'filterWikiApprove', fallback.filterWikiApprove);

  @override
  String get filterWikiReject => OtaTranslationService.translate(locale, 'filterWikiReject', fallback.filterWikiReject);

  @override
  String get filterCanonizeWiki => OtaTranslationService.translate(locale, 'filterCanonizeWiki', fallback.filterCanonizeWiki);

  @override
  String get filterDecanonizeWiki => OtaTranslationService.translate(locale, 'filterDecanonizeWiki', fallback.filterDecanonizeWiki);

  @override
  String get filterTransferAgent => OtaTranslationService.translate(locale, 'filterTransferAgent', fallback.filterTransferAgent);

  @override
  String get filterApproveFlag => OtaTranslationService.translate(locale, 'filterApproveFlag', fallback.filterApproveFlag);

  @override
  String get filterDismissFlag => OtaTranslationService.translate(locale, 'filterDismissFlag', fallback.filterDismissFlag);

  @override
  String get filterAcceptAppeal => OtaTranslationService.translate(locale, 'filterAcceptAppeal', fallback.filterAcceptAppeal);

  @override
  String get filterRejectAppeal => OtaTranslationService.translate(locale, 'filterRejectAppeal', fallback.filterRejectAppeal);

  @override
  String get reportDialogTitle => OtaTranslationService.translate(locale, 'reportDialogTitle', fallback.reportDialogTitle);

  @override
  String get reportDialogSubtitle => OtaTranslationService.translate(locale, 'reportDialogSubtitle', fallback.reportDialogSubtitle);

  @override
  String get reportReasonSexualContent => OtaTranslationService.translate(locale, 'reportReasonSexualContent', fallback.reportReasonSexualContent);

  @override
  String get reportReasonHarassment => OtaTranslationService.translate(locale, 'reportReasonHarassment', fallback.reportReasonHarassment);

  @override
  String get reportReasonHateSpeech => OtaTranslationService.translate(locale, 'reportReasonHateSpeech', fallback.reportReasonHateSpeech);

  @override
  String get reportReasonViolence => OtaTranslationService.translate(locale, 'reportReasonViolence', fallback.reportReasonViolence);

  @override
  String get reportReasonSpam => OtaTranslationService.translate(locale, 'reportReasonSpam', fallback.reportReasonSpam);

  @override
  String get reportReasonMisinformation => OtaTranslationService.translate(locale, 'reportReasonMisinformation', fallback.reportReasonMisinformation);

  @override
  String get reportReasonSelfHarm => OtaTranslationService.translate(locale, 'reportReasonSelfHarm', fallback.reportReasonSelfHarm);

  @override
  String get reportReasonIllegalContent => OtaTranslationService.translate(locale, 'reportReasonIllegalContent', fallback.reportReasonIllegalContent);

  @override
  String get reportReasonOther => OtaTranslationService.translate(locale, 'reportReasonOther', fallback.reportReasonOther);

  @override
  String get reportDetailsLabel => OtaTranslationService.translate(locale, 'reportDetailsLabel', fallback.reportDetailsLabel);

  @override
  String get reportDetailsHint => OtaTranslationService.translate(locale, 'reportDetailsHint', fallback.reportDetailsHint);

  @override
  String get reportDetailsRequired => OtaTranslationService.translate(locale, 'reportDetailsRequired', fallback.reportDetailsRequired);

  @override
  String get reportSending => OtaTranslationService.translate(locale, 'reportSending', fallback.reportSending);

  @override
  String get reportSent => OtaTranslationService.translate(locale, 'reportSent', fallback.reportSent);

  @override
  String get reportSentDesc => OtaTranslationService.translate(locale, 'reportSentDesc', fallback.reportSentDesc);

  @override
  String get reportAlreadySent => OtaTranslationService.translate(locale, 'reportAlreadySent', fallback.reportAlreadySent);

  @override
  String get reportSendError => OtaTranslationService.translate(locale, 'reportSendError', fallback.reportSendError);

  @override
  String get appealStatusAccepted => OtaTranslationService.translate(locale, 'appealStatusAccepted', fallback.appealStatusAccepted);

  @override
  String get appealStatusRejected => OtaTranslationService.translate(locale, 'appealStatusRejected', fallback.appealStatusRejected);

  @override
  String get appealStatusCancelled => OtaTranslationService.translate(locale, 'appealStatusCancelled', fallback.appealStatusCancelled);

  @override
  String get appealStatusPending => OtaTranslationService.translate(locale, 'appealStatusPending', fallback.appealStatusPending);

  @override
  String get appealYourReason => OtaTranslationService.translate(locale, 'appealYourReason', fallback.appealYourReason);

  @override
  String get appealReviewerNote => OtaTranslationService.translate(locale, 'appealReviewerNote', fallback.appealReviewerNote);

  @override
  String get appealReviewedAt => OtaTranslationService.translate(locale, 'appealReviewedAt', fallback.appealReviewedAt);

  @override
  String get appealCancel => OtaTranslationService.translate(locale, 'appealCancel', fallback.appealCancel);

  @override
  String get appealCancelledSuccess => OtaTranslationService.translate(locale, 'appealCancelledSuccess', fallback.appealCancelledSuccess);

  @override
  String get appealSubmittedTitle => OtaTranslationService.translate(locale, 'appealSubmittedTitle', fallback.appealSubmittedTitle);

  @override
  String get appealSubmittedSubtitle => OtaTranslationService.translate(locale, 'appealSubmittedSubtitle', fallback.appealSubmittedSubtitle);

  @override
  String get backToAppeals => OtaTranslationService.translate(locale, 'backToAppeals', fallback.backToAppeals);

  @override
  String get appealSubmitTitle => OtaTranslationService.translate(locale, 'appealSubmitTitle', fallback.appealSubmitTitle);

  @override
  String get appealTargetCommunity => OtaTranslationService.translate(locale, 'appealTargetCommunity', fallback.appealTargetCommunity);

  @override
  String get appealWarning => OtaTranslationService.translate(locale, 'appealWarning', fallback.appealWarning);

  @override
  String get appealAdditionalLabel => OtaTranslationService.translate(locale, 'appealAdditionalLabel', fallback.appealAdditionalLabel);

  @override
  String get appealAdditionalHint2 => OtaTranslationService.translate(locale, 'appealAdditionalHint2', fallback.appealAdditionalHint2);

  @override
  String get appealAdditionalHint => OtaTranslationService.translate(locale, 'appealAdditionalHint', fallback.appealAdditionalHint);

  @override
  String get appealSubmitButton => OtaTranslationService.translate(locale, 'appealSubmitButton', fallback.appealSubmitButton);

  @override
  String get securityTabOverview => OtaTranslationService.translate(locale, 'securityTabOverview', fallback.securityTabOverview);

  @override
  String get securityTabSessions => OtaTranslationService.translate(locale, 'securityTabSessions', fallback.securityTabSessions);

  @override
  String get securityTabActivity => OtaTranslationService.translate(locale, 'securityTabActivity', fallback.securityTabActivity);

  @override
  String get securitySettings => OtaTranslationService.translate(locale, 'securitySettings', fallback.securitySettings);

  @override
  String get securityEmailVerification => OtaTranslationService.translate(locale, 'securityEmailVerification', fallback.securityEmailVerification);

  @override
  String get securityEmailVerified => OtaTranslationService.translate(locale, 'securityEmailVerified', fallback.securityEmailVerified);

  @override
  String get securityEmailNotVerified => OtaTranslationService.translate(locale, 'securityEmailNotVerified', fallback.securityEmailNotVerified);

  @override
  String get securityChangePassword => OtaTranslationService.translate(locale, 'securityChangePassword', fallback.securityChangePassword);

  @override
  String get securityChangePasswordSubtitle => OtaTranslationService.translate(locale, 'securityChangePasswordSubtitle', fallback.securityChangePasswordSubtitle);

  @override
  String get featureComingSoon => OtaTranslationService.translate(locale, 'featureComingSoon', fallback.featureComingSoon);

  @override
  String get securityActiveSessions => OtaTranslationService.translate(locale, 'securityActiveSessions', fallback.securityActiveSessions);

  @override
  String get securityActiveSessionsSubtitle => OtaTranslationService.translate(locale, 'securityActiveSessionsSubtitle', fallback.securityActiveSessionsSubtitle);

  @override
  String get securityActivityLog => OtaTranslationService.translate(locale, 'securityActivityLog', fallback.securityActivityLog);

  @override
  String get securityActivityLogSubtitle => OtaTranslationService.translate(locale, 'securityActivityLogSubtitle', fallback.securityActivityLogSubtitle);

  @override
  String get securityNoSessions => OtaTranslationService.translate(locale, 'securityNoSessions', fallback.securityNoSessions);

  @override
  String get unknownDevice => OtaTranslationService.translate(locale, 'unknownDevice', fallback.unknownDevice);

  @override
  String get securityCurrentSession => OtaTranslationService.translate(locale, 'securityCurrentSession', fallback.securityCurrentSession);

  @override
  String get securityNoActivity => OtaTranslationService.translate(locale, 'securityNoActivity', fallback.securityNoActivity);

  @override
  String get insufficientPermissions => OtaTranslationService.translate(locale, 'insufficientPermissions', fallback.insufficientPermissions);

  @override
  String get reportCategorySexual => OtaTranslationService.translate(locale, 'reportCategorySexual', fallback.reportCategorySexual);

  @override
  String get reportCategorySexualDesc => OtaTranslationService.translate(locale, 'reportCategorySexualDesc', fallback.reportCategorySexualDesc);

  @override
  String get reportCategoryBullying => OtaTranslationService.translate(locale, 'reportCategoryBullying', fallback.reportCategoryBullying);

  @override
  String get reportCategoryBullyingDesc => OtaTranslationService.translate(locale, 'reportCategoryBullyingDesc', fallback.reportCategoryBullyingDesc);

  @override
  String get reportCategoryHate => OtaTranslationService.translate(locale, 'reportCategoryHate', fallback.reportCategoryHate);

  @override
  String get reportCategoryHateDesc => OtaTranslationService.translate(locale, 'reportCategoryHateDesc', fallback.reportCategoryHateDesc);

  @override
  String get reportCategoryViolence => OtaTranslationService.translate(locale, 'reportCategoryViolence', fallback.reportCategoryViolence);

  @override
  String get reportCategoryViolenceDesc => OtaTranslationService.translate(locale, 'reportCategoryViolenceDesc', fallback.reportCategoryViolenceDesc);

  @override
  String get reportCategorySpam => OtaTranslationService.translate(locale, 'reportCategorySpam', fallback.reportCategorySpam);

  @override
  String get reportCategorySpamDesc => OtaTranslationService.translate(locale, 'reportCategorySpamDesc', fallback.reportCategorySpamDesc);

  @override
  String get reportCategoryMisinfo => OtaTranslationService.translate(locale, 'reportCategoryMisinfo', fallback.reportCategoryMisinfo);

  @override
  String get reportCategoryMisinfoDesc => OtaTranslationService.translate(locale, 'reportCategoryMisinfoDesc', fallback.reportCategoryMisinfoDesc);

  @override
  String get reportCategoryArtTheft => OtaTranslationService.translate(locale, 'reportCategoryArtTheft', fallback.reportCategoryArtTheft);

  @override
  String get reportCategoryArtTheftDesc => OtaTranslationService.translate(locale, 'reportCategoryArtTheftDesc', fallback.reportCategoryArtTheftDesc);

  @override
  String get reportCategoryImpersonation => OtaTranslationService.translate(locale, 'reportCategoryImpersonation', fallback.reportCategoryImpersonation);

  @override
  String get reportCategoryImpersonationDesc => OtaTranslationService.translate(locale, 'reportCategoryImpersonationDesc', fallback.reportCategoryImpersonationDesc);

  @override
  String get reportCategorySelfHarm => OtaTranslationService.translate(locale, 'reportCategorySelfHarm', fallback.reportCategorySelfHarm);

  @override
  String get reportCategorySelfHarmDesc => OtaTranslationService.translate(locale, 'reportCategorySelfHarmDesc', fallback.reportCategorySelfHarmDesc);

  @override
  String get reportCategoryOther => OtaTranslationService.translate(locale, 'reportCategoryOther', fallback.reportCategoryOther);

  @override
  String get reportCategoryOtherDesc => OtaTranslationService.translate(locale, 'reportCategoryOtherDesc', fallback.reportCategoryOtherDesc);

  @override
  String get reportResponsibleUse => OtaTranslationService.translate(locale, 'reportResponsibleUse', fallback.reportResponsibleUse);

  @override
  String get reportDetailsRequiredHint => OtaTranslationService.translate(locale, 'reportDetailsRequiredHint', fallback.reportDetailsRequiredHint);

  @override
  String get requiresDetails => OtaTranslationService.translate(locale, 'requiresDetails', fallback.requiresDetails);

  @override
  String get appealsEmptyTitle => OtaTranslationService.translate(locale, 'appealsEmptyTitle', fallback.appealsEmptyTitle);

  @override
  String get appealsEmptySubtitle => OtaTranslationService.translate(locale, 'appealsEmptySubtitle', fallback.appealsEmptySubtitle);

  @override
  String get appealsInfoBanner => OtaTranslationService.translate(locale, 'appealsInfoBanner', fallback.appealsInfoBanner);

  @override
  String get securityEventFailedLogin => OtaTranslationService.translate(locale, 'securityEventFailedLogin', fallback.securityEventFailedLogin);

  @override
  String get securityEventLogout => OtaTranslationService.translate(locale, 'securityEventLogout', fallback.securityEventLogout);

  @override
  String get securityEventSessionRevoked => OtaTranslationService.translate(locale, 'securityEventSessionRevoked', fallback.securityEventSessionRevoked);

  @override
  String get securityLevelLow => OtaTranslationService.translate(locale, 'securityLevelLow', fallback.securityLevelLow);

  @override
  String get securityLevelMedium => OtaTranslationService.translate(locale, 'securityLevelMedium', fallback.securityLevelMedium);

  @override
  String get securityLevelHigh => OtaTranslationService.translate(locale, 'securityLevelHigh', fallback.securityLevelHigh);

  @override
  String get securityRevokeSession => OtaTranslationService.translate(locale, 'securityRevokeSession', fallback.securityRevokeSession);

  @override
  String get securityScoreTitle => OtaTranslationService.translate(locale, 'securityScoreTitle', fallback.securityScoreTitle);

  @override
  String get securitySessionRevoked => OtaTranslationService.translate(locale, 'securitySessionRevoked', fallback.securitySessionRevoked);

  @override
  String get securityRevokeAllOtherSessions => OtaTranslationService.translate(locale, 'securityRevokeAllOtherSessions', fallback.securityRevokeAllOtherSessions);

  @override
  String get securityRevokeAllConfirm => OtaTranslationService.translate(locale, 'securityRevokeAllConfirm', fallback.securityRevokeAllConfirm);

  @override
  String get securityAllSessionsRevoked => OtaTranslationService.translate(locale, 'securityAllSessionsRevoked', fallback.securityAllSessionsRevoked);

  @override
  String get securityTipsTitle => OtaTranslationService.translate(locale, 'securityTipsTitle', fallback.securityTipsTitle);

  @override
  String get securityTip1 => OtaTranslationService.translate(locale, 'securityTip1', fallback.securityTip1);

  @override
  String get securityTip2 => OtaTranslationService.translate(locale, 'securityTip2', fallback.securityTip2);

  @override
  String get securityTip3 => OtaTranslationService.translate(locale, 'securityTip3', fallback.securityTip3);

  @override
  String get securityVerifyEmailTitle => OtaTranslationService.translate(locale, 'securityVerifyEmailTitle', fallback.securityVerifyEmailTitle);

  @override
  String get securityVerifyEmailSubtitle => OtaTranslationService.translate(locale, 'securityVerifyEmailSubtitle', fallback.securityVerifyEmailSubtitle);

  @override
  String get securityVerifyEmailSentTitle => OtaTranslationService.translate(locale, 'securityVerifyEmailSentTitle', fallback.securityVerifyEmailSentTitle);

  @override
  String get securityVerifyEmailSentBody => OtaTranslationService.translate(locale, 'securityVerifyEmailSentBody', fallback.securityVerifyEmailSentBody);

  @override
  String get securityVerifyEmailResend => OtaTranslationService.translate(locale, 'securityVerifyEmailResend', fallback.securityVerifyEmailResend);

  @override
  String get securityVerifyEmailResendIn => OtaTranslationService.translate(locale, 'securityVerifyEmailResendIn', fallback.securityVerifyEmailResendIn);

  @override
  String get securityVerifyEmailAlreadyVerified => OtaTranslationService.translate(locale, 'securityVerifyEmailAlreadyVerified', fallback.securityVerifyEmailAlreadyVerified);

  @override
  String get securityPasswordChangeTitle => OtaTranslationService.translate(locale, 'securityPasswordChangeTitle', fallback.securityPasswordChangeTitle);

  @override
  String get securityPasswordChangeSubtitle => OtaTranslationService.translate(locale, 'securityPasswordChangeSubtitle', fallback.securityPasswordChangeSubtitle);

  @override
  String get oneReaction => OtaTranslationService.translate(locale, 'oneReaction', fallback.oneReaction);

  @override
  String get signupVerifyEmailTitle => OtaTranslationService.translate(locale, 'signupVerifyEmailTitle', fallback.signupVerifyEmailTitle);

  @override
  String get signupVerifyEmailSubtitle => OtaTranslationService.translate(locale, 'signupVerifyEmailSubtitle', fallback.signupVerifyEmailSubtitle);

  @override
  String get signupVerifyEmailCodeHint => OtaTranslationService.translate(locale, 'signupVerifyEmailCodeHint', fallback.signupVerifyEmailCodeHint);

  @override
  String get signupVerifyEmailCodeLabel => OtaTranslationService.translate(locale, 'signupVerifyEmailCodeLabel', fallback.signupVerifyEmailCodeLabel);

  @override
  String get signupVerifyEmailButton => OtaTranslationService.translate(locale, 'signupVerifyEmailButton', fallback.signupVerifyEmailButton);

  @override
  String get signupVerifyEmailResend => OtaTranslationService.translate(locale, 'signupVerifyEmailResend', fallback.signupVerifyEmailResend);

  @override
  String get signupVerifyEmailResendIn => OtaTranslationService.translate(locale, 'signupVerifyEmailResendIn', fallback.signupVerifyEmailResendIn);

  @override
  String get signupVerifyEmailInvalidCode => OtaTranslationService.translate(locale, 'signupVerifyEmailInvalidCode', fallback.signupVerifyEmailInvalidCode);

  @override
  String get signupVerifyEmailExpiredCode => OtaTranslationService.translate(locale, 'signupVerifyEmailExpiredCode', fallback.signupVerifyEmailExpiredCode);

  @override
  String get signupVerifyEmailSuccess => OtaTranslationService.translate(locale, 'signupVerifyEmailSuccess', fallback.signupVerifyEmailSuccess);

  @override
  String streakDaysLabel(int streak) => fallback.streakDaysLabel(streak);

  @override
  String timeAgoMonths(int months) => fallback.timeAgoMonths(months);

  @override
  String timeAgoDays(int days) => fallback.timeAgoDays(days);

  @override
  String timeAgoHours(int hours) => fallback.timeAgoHours(hours);

  @override
  String timeAgoMinutes(int minutes) => fallback.timeAgoMinutes(minutes);

  @override
  String viewsCountLabel(int count) => fallback.viewsCountLabel(count);

  @override
  String optionNumber(int number) => fallback.optionNumber(number);

  @override
  String viewCommentsCount(int count) => fallback.viewCommentsCount(count);

  @override
  String replyInComments(int count) => fallback.replyInComments(count);

  @override
  String dayOfStreak(int days) => fallback.dayOfStreak(days);

  @override
  String wonExtraCoins(int coins) => fallback.wonExtraCoins(coins);

  @override
  String freeCoinsRemaining(int remaining) => fallback.freeCoinsRemaining(remaining);

  @override
  String joinedCommunityName(String name) => fallback.joinedCommunityName(name);

  @override
  String checkInStreakMsg(int streak, int coins) => fallback.checkInStreakMsg(streak, coins);

  @override
  String levelAndRep(int level, int reputation) => fallback.levelAndRep(level, reputation);

  @override
  String timeAgoMonthsShort(int months) => fallback.timeAgoMonthsShort(months);

  @override
  String timeAgoDaysShort(int days) => fallback.timeAgoDaysShort(days);

  @override
  String timeAgoHoursShort(int hours) => fallback.timeAgoHoursShort(hours);

  @override
  String timeAgoMinutesShort(int minutes) => fallback.timeAgoMinutesShort(minutes);

  @override
  String receivedWarning(String reason) => fallback.receivedWarning(reason);

  @override
  String removedFromCommunity(String reason) => fallback.removedFromCommunity(reason);

  @override
  String pausedUntil(String dateTime) => fallback.pausedUntil(dateTime);

  @override
  String entryApprovedMsg(String title) => fallback.entryApprovedMsg(title);

  @override
  String entryNeedsChanges(String title, String reason) => fallback.entryNeedsChanges(title, reason);

  @override
  String amountCoinsTransferred(int amount) => fallback.amountCoinsTransferred(amount);

  @override
  String nicknameUnblocked(String nickname) => fallback.nicknameUnblocked(nickname);

  @override
  String reactionSent(String reaction) => fallback.reactionSent(reaction);

  @override
  String propsAmountSent(int amount) => fallback.propsAmountSent(amount);

  @override
  String totalVotesLabel(int count) => fallback.totalVotesLabel(count);

  @override
  String postCommentsCountReplies(int count) => fallback.postCommentsCountReplies(count);

  @override
  String coinsEarnedLabel(int coins) => fallback.coinsEarnedLabel(coins);

  @override
  String xpEarnedLabel(int xp) => fallback.xpEarnedLabel(xp);

  @override
  String rewardCoinsLabel(int coins) => fallback.rewardCoinsLabel(coins);

  @override
  String providerUnlinked(String provider) => fallback.providerUnlinked(provider);

  @override
  String costCoinsLabel(int amount) => fallback.costCoinsLabel(amount);

  @override
  String leftCommunityName(String name) => fallback.leftCommunityName(name);

  @override
  String memberCountMembers(int count) => fallback.memberCountMembers(count);

  @override
  String errorPurchase(String error) => fallback.errorPurchase(error);

  @override
  String errorGeneric(String error) => fallback.errorGeneric(error);

  @override
  String currentBalanceCoins(String coins) => fallback.currentBalanceCoins(coins);

  @override
  String leftCommunityMsg(String name) => fallback.leftCommunityMsg(name);

  @override
  String pollQuestion(String question) => fallback.pollQuestion(question);

  @override
  String optionN(int n) => fallback.optionN(n);

  @override
  String questionN(int n) => fallback.questionN(n);

  @override
  String amountCoins(int amount) => fallback.amountCoins(amount);

  @override
  String reputationPointsLabel(int points) => fallback.reputationPointsLabel(points);

  @override
  String repProgressLabel(int current, int total) => fallback.repProgressLabel(current, total);

  @override
  String daysToLevelUp(int days) => fallback.daysToLevelUp(days);

  @override
  String checkInSuccessMsg(int rep, int streak) => fallback.checkInSuccessMsg(rep, streak);

  @override
  String plusReputationLabel(int amount) => fallback.plusReputationLabel(amount);

  @override
  String streakRestoredMsg(int days) => fallback.streakRestoredMsg(days);

  @override
  String memberSinceLabel(String month, int year, int days) => fallback.memberSinceLabel(month, year, days);

  @override
  String lvBadge(int level) => fallback.lvBadge(level);

  @override
  String leaveCommunityConfirmMsg(String communityName) => fallback.leaveCommunityConfirmMsg(communityName);

  @override
  String dayLabel(int n) => fallback.dayLabel(n);

  @override
  String repostNotificationBody(String username) => fallback.repostNotificationBody(username);

  @override
  String repostedBy(String username) => fallback.repostedBy(username);

  @override
  String followersCount(int count) => fallback.followersCount(count);

  @override
  String followingCount(int count) => fallback.followingCount(count);

  @override
  String postsCount(int count) => fallback.postsCount(count);

  @override
  String onlineMembersCount(int count) => fallback.onlineMembersCount(count);

  @override
  String commentsCount(int count) => fallback.commentsCount(count);

  @override
  String memberSinceDate(String date) => fallback.memberSinceDate(date);

  @override
  String userIsTyping(String user) => fallback.userIsTyping(user);

  @override
  String userLikedYourPost(String user) => fallback.userLikedYourPost(user);

  @override
  String userCommentedOnYourPost(String user) => fallback.userCommentedOnYourPost(user);

  @override
  String userFollowedYou(String user) => fallback.userFollowedYou(user);

  @override
  String userMentionedYou(String user) => fallback.userMentionedYou(user);

  @override
  String userInvitedYouTo(String user, String something) => fallback.userInvitedYouTo(user, something);

  @override
  String userSentYouAMessage(String user) => fallback.userSentYouAMessage(user);

  @override
  String userJoinedTheCommunity(String user) => fallback.userJoinedTheCommunity(user);

  @override
  String userJoinedTheChat(String user) => fallback.userJoinedTheChat(user);

  @override
  String userLeftTheChat(String user) => fallback.userLeftTheChat(user);

  @override
  String userDeletedMessage(String user) => fallback.userDeletedMessage(user);

  @override
  String youWereKickedFromTheChat(String reason) => fallback.youWereKickedFromTheChat(reason);

  @override
  String youWereMutedInTheChat(String reason) => fallback.youWereMutedInTheChat(reason);

  @override
  String youLeveledUpTo(int level) => fallback.youLeveledUpTo(level);

  @override
  String youGotANewAchievement(String achievement) => fallback.youGotANewAchievement(achievement);

  @override
  String youHaveBeenStriked(int strike, String reason) => fallback.youHaveBeenStriked(strike, reason);

  @override
  String yourPostWasFeatured(String postTitle) => fallback.yourPostWasFeatured(postTitle);

  @override
  String yourPostWasPinned(String postTitle) => fallback.yourPostWasPinned(postTitle);

  @override
  String yourPostWasCrossposted(String postTitle) => fallback.yourPostWasCrossposted(postTitle);

  @override
  String yourWikiWasApproved(String wikiTitle) => fallback.yourWikiWasApproved(wikiTitle);

  @override
  String yourWikiWasRejected(String wikiTitle) => fallback.yourWikiWasRejected(wikiTitle);

  @override
  String reactionsCount(int count) => fallback.reactionsCount(count);

}
