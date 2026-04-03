import 'app_strings.dart';

/// Strings in English (en-US).
class AppStringsEn implements AppStrings {
  const AppStringsEn();

  // GERAL
  @override String get appName => 'NexusHub';
  @override String get ok => 'OK';
  @override String get cancel => 'Cancel';
  @override String get save => 'Save';
  @override String get delete => 'Delete';
  @override String get edit => 'Edit';
  @override String get close => 'Close';
  @override String get back => 'Back';
  @override String get next => 'Next';
  @override String get done => 'Done';
  @override String get loading => 'Loading...';
  @override String get error => 'Error';
  @override String get retry => 'Retry';
  @override String get search => 'Search';
  @override String get seeAll => 'See all';
  @override String get share => 'Share';
  @override String get report => 'Report';
  @override String get block => 'Block';
  @override String get confirm => 'Confirm';
  @override String get yes => 'Yes';
  @override String get no => 'No';
  @override String get noResults => 'No results found';
  @override String get somethingWentWrong => 'Something went wrong';
  @override String get tryAgainLater => 'Please try again later';
  @override String get copiedToClipboard => 'Copied to clipboard';

  // AUTENTICAÇÃO
  @override String get login => 'Log In';
  @override String get signUp => 'Sign Up';
  @override String get logout => 'Log Out';
  @override String get email => 'Email';
  @override String get password => 'Password';
  @override String get forgotPassword => 'Forgot password?';
  @override String get resetPassword => 'Reset password';
  @override String get createAccount => 'Create account';
  @override String get alreadyHaveAccount => 'Already have an account?';
  @override String get dontHaveAccount => "Don't have an account?";
  @override String get loginWithGoogle => 'Continue with Google';
  @override String get loginWithApple => 'Continue with Apple';
  @override String get orContinueWith => 'Or continue with';
  @override String get welcomeBack => 'Welcome back!';
  @override String get getStarted => 'Get Started';

  // NAVEGAÇÃO
  @override String get home => 'Home';
  @override String get explore => 'Explore';
  @override String get communities => 'Communities';
  @override String get chats => 'Chats';
  @override String get profile => 'Profile';
  @override String get notifications => 'Notifications';
  @override String get settings => 'Settings';
  @override String get feed => 'Feed';
  @override String get latest => 'Latest';
  @override String get popular => 'Popular';
  @override String get online => 'Online';
  @override String get me => 'Me';

  // COMUNIDADES
  @override String get joinCommunity => 'Join Community';
  @override String get leaveCommunity => 'Leave Community';
  @override String get createCommunity => 'Create Community';
  @override String get communityName => 'Community name';
  @override String get communityDescription => 'Description';
  @override String get members => 'Members';
  @override String get onlineMembers => 'Online members';
  @override String get guidelines => 'Guidelines';
  @override String get editGuidelines => 'Edit guidelines';
  @override String get joined => 'Joined';
  @override String get pending => 'Pending';
  @override String get myCommunities => 'My Communities';
  @override String get discoverCommunities => 'Discover Communities';
  @override String get newCommunities => 'New Communities';
  @override String get forYou => 'For You';
  @override String get trendingNow => 'Trending Now';
  @override String get categories => 'Categories';
  @override String get inviteLink => 'Invite link';

  // POSTS
  @override String get createPost => 'Create Post';
  @override String get writePost => 'Write something...';
  @override String get title => 'Title';
  @override String get content => 'Content';
  @override String get addImage => 'Add image';
  @override String get addPoll => 'Add poll';
  @override String get addQuiz => 'Add quiz';
  @override String get tags => 'Tags';
  @override String get publish => 'Publish';
  @override String get draft => 'Draft';
  @override String get like => 'Like';
  @override String get comment => 'Comment';
  @override String get comments => 'Comments';
  @override String get bookmark => 'Bookmark';
  @override String get bookmarked => 'Bookmarked';
  @override String get featured => 'Featured';
  @override String get pinned => 'Pinned';
  @override String get crosspost => 'Crosspost';
  @override String get crosspostTo => 'Crosspost to';
  @override String get selectCommunity => 'Select community';
  @override String get writeComment => 'Write a comment...';
  @override String get noPostsYet => 'No posts yet';
  @override String get deletePost => 'Delete post';
  @override String get deletePostConfirm => 'Are you sure you want to delete this post?';
  @override String get reportPost => 'Report post';
  @override String get featurePost => 'Feature post';
  @override String get pinPost => 'Pin post';

  // CHAT
  @override String get newChat => 'New Chat';
  @override String get newGroupChat => 'New Group Chat';
  @override String get privateChat => 'Private Chat';
  @override String get groupChat => 'Group Chat';
  @override String get typeMessage => 'Type a message...';
  @override String get sendMessage => 'Send message';
  @override String get voiceMessage => 'Voice message';
  @override String get stickers => 'Stickers';
  @override String get gifs => 'GIFs';
  @override String get attachImage => 'Attach image';
  @override String get reply => 'Reply';
  @override String get typing => 'typing...';
  @override String get isTyping => 'is typing...';
  @override String get groupName => 'Group name';
  @override String get addMembers => 'Add members';
  @override String get leaveGroup => 'Leave group';
  @override String get noChatsYet => 'No chats yet';
  @override String get startConversation => 'Start a conversation';

  // PERFIL
  @override String get editProfile => 'Edit Profile';
  @override String get nickname => 'Nickname';
  @override String get bio => 'Bio';
  @override String get level => 'Level';
  @override String get reputation => 'Reputation';
  @override String get followers => 'Followers';
  @override String get following => 'Following';
  @override String get follow => 'Follow';
  @override String get unfollow => 'Unfollow';
  @override String get posts => 'Posts';
  @override String get wall => 'Wall';
  @override String get stories => 'Stories';
  @override String get linkedCommunities => 'Linked Communities';
  @override String get pinnedWikis => 'Pinned Wikis';
  @override String get achievements => 'Achievements';
  @override String get checkIn => 'Check-in';
  @override String get dailyCheckIn => 'Daily Check-in';
  @override String get streak => 'Streak';

  // WIKI
  @override String get wiki => 'Wiki';
  @override String get createWiki => 'Create Wiki';
  @override String get wikiEntries => 'Wiki Entries';
  @override String get curatorReview => 'Curator Review';
  @override String get approve => 'Approve';
  @override String get reject => 'Reject';
  @override String get pendingReview => 'Pending Review';
  @override String get approved => 'Approved';
  @override String get rejected => 'Rejected';
  @override String get pinToProfile => 'Pin to Profile';
  @override String get unpinFromProfile => 'Unpin from Profile';
  @override String get rating => 'Rating';
  @override String get whatILike => 'What I Like';

  // NOTIFICAÇÕES
  @override String get markAllAsRead => 'Mark all as read';
  @override String get noNotifications => 'No notifications';
  @override String get likedYourPost => 'liked your post';
  @override String get commentedOnYourPost => 'commented on your post';
  @override String get followedYou => 'followed you';
  @override String get mentionedYou => 'mentioned you';
  @override String get invitedYou => 'invited you';
  @override String get levelUp => 'Level Up!';
  @override String get newAchievement => 'New Achievement!';

  // MODERAÇÃO
  @override String get moderation => 'Moderation';
  @override String get adminPanel => 'Admin Panel';
  @override String get flagCenter => 'Flag Center';
  @override String get ban => 'Ban';
  @override String get unban => 'Unban';
  @override String get kick => 'Kick';
  @override String get mute => 'Mute';
  @override String get warn => 'Warn';
  @override String get strike => 'Strike';
  @override String get reason => 'Reason';
  @override String get duration => 'Duration';
  @override String get permanent => 'Permanent';
  @override String get executeAction => 'Execute Action';
  @override String get leader => 'Leader';
  @override String get curator => 'Curator';
  @override String get member => 'Member';

  // CONFIGURAÇÕES
  @override String get generalSettings => 'General Settings';
  @override String get darkMode => 'Dark Mode';
  @override String get lightMode => 'Light Mode';
  @override String get language => 'Language';
  @override String get pushNotifications => 'Push Notifications';
  @override String get privacy => 'Privacy';
  @override String get blockedUsers => 'Blocked Users';
  @override String get clearCache => 'Clear Cache';
  @override String get cacheCleared => 'Cache cleared successfully';
  @override String get about => 'About';
  @override String get version => 'Version';
  @override String get termsOfService => 'Terms of Service';
  @override String get privacyPolicy => 'Privacy Policy';
  @override String get deleteAccount => 'Delete Account';
  @override String get deleteAccountConfirm => 'Are you sure you want to delete your account? This action cannot be undone.';
  @override String get logoutConfirm => 'Are you sure you want to log out?';

  // TEMPO
  @override String get justNow => 'Just now';
  @override String get minutesAgo => 'min ago';
  @override String get hoursAgo => 'h ago';
  @override String get daysAgo => 'd ago';
  @override String get yesterday => 'Yesterday';
  @override String get today => 'Today';

  // ERROS
  @override String get networkError => 'Connection error. Check your internet.';
  @override String get sessionExpired => 'Session expired. Please log in again.';
  @override String get permissionDenied => 'Permission denied.';
  @override String get notFound => 'Not found.';
  @override String get serverError => 'Server error. Please try again later.';

  // ══════════════════════════════════════════════════════════════════════════
  // STRINGS ADICIONAIS (migração i18n)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  String get accept => 'Accept';
  @override
  String get acceptTerms => 'Accept the terms of use to continue';
  @override
  String get actionError => 'Error executing action. Please try again.';
  @override
  String get actionSuccess => 'Action executed successfully';
  @override
  String get active => 'Active';
  @override
  String get addAtLeastOneImage => 'Add at least one image';
  @override
  String get addAtLeastOneQuestion => 'Add at least one question';
  @override
  String get addAtLeastTwoOptions => 'Add at least 2 options';
  @override
  String get addCover => 'Add Cover';
  @override
  String get addMusic => 'Add Music';
  @override
  String get addOption => 'Add Option';
  @override
  String get addQuestion => 'Add Question';
  @override
  String get addVideo => 'Add Video';
  @override
  String get advancedOptions => 'Advanced Options';
  @override
  String get allSessionsRevoked => 'All other sessions have been revoked';
  @override
  String get alreadyCheckedIn => 'You already checked in today in this community!';
  @override
  String get appPermissions => 'App Permissions';
  @override
  String get appearance => 'Appearance';
  @override
  String get apply => 'Apply';
  @override
  String get audio => 'Audio';
  @override
  String get change => 'Change';
  @override
  String get changeEmail => 'Change Email';
  @override
  String get checkInError => 'Check-in error. Please try again.';
  @override
  String get coins => 'coins';
  @override
  String get confirmPassword => 'Confirm Password';
  @override
  String get current => 'Current';
  @override
  String get dailyReward => 'Daily reward';
  @override
  String get deleteChat => 'Delete Chat';
  @override
  String get deleteChatError => 'Error deleting chat. Please try again.';
  @override
  String get deleteDraft => 'Delete draft?';
  @override
  String get deleteError => 'Error deleting. Please try again.';
  @override
  String get deletePermanently => 'Delete Permanently';
  @override
  String get enableBanner => 'Enable Banner';
  @override
  String get enterGroupName => 'Enter a group name';
  @override
  String get fileSentSuccess => 'File sent successfully!';
  @override
  String get genericError => 'An error occurred. Please try again.';
  @override
  String get insertLink => 'Insert Link';
  @override
  String get insufficientBalance => 'Insufficient balance';
  @override
  String get joinedChat => 'You joined the chat!';
  @override
  String get leaveChat => 'Leave Chat';
  @override
  String get leaveChatConfirm => 'Are you sure you want to leave this chat?';
  @override
  String get leaveChatError => 'Error leaving chat. Please try again.';
  @override
  String get leaveCommunityError => 'Error leaving community. Please try again.';
  @override
  String get linkCopied => 'Link copied!';
  @override
  String get loadChatsError => 'Error loading chats';
  @override
  String get loginRequired => 'You need to be logged in to comment.';
  @override
  String get messageForwarded => 'Message forwarded!';
  @override
  String get moderationAction => 'Moderation Action';
  @override
  String get nameLink => 'Name link';
  @override
  String get newWikiEntry => 'New Wiki Entry';
  @override
  String get noCommunityFound => 'No community found';
  @override
  String get noMemberFound => 'No member found';
  @override
  String get noWallComments => 'No wall comments';
  @override
  String get openSettings => 'Open Settings';
  @override
  String get or => 'or';
  @override
  String get permissionDeniedTitle => 'Permission denied';
  @override
  String get pinChatError => 'Error pinning/unpinning chat.';
  @override
  String get pollQuestionRequired => 'Poll question is required';
  @override
  String get private => 'Private';
  @override
  String get profileLinkCopied => 'Profile link copied!';
  @override
  String get public => 'Public';
  @override
  String get publishError => 'Error publishing. Please try again.';
  @override
  String get questionRequired => 'Question is required';
  @override
  String get rejectionReason => 'Rejection reason';
  @override
  String get reorderCommunities => 'Hold and drag the cards to reorder your communities.';
  @override
  String get reportBug => 'Report Bug';
  @override
  String get revokeAllOthers => 'Revoke All Others';
  @override
  String get revokeDevice => 'Revoke Device';
  @override
  String get saveError => 'Error saving. Please try again.';
  @override
  String get sendError => 'Error sending. Please try again.';
  @override
  String get settingsSaved => 'Settings saved!';
  @override
  String get showOnlineCount => 'Show online count in bottom bar';
  @override
  String get startConversationWith => 'Start conversation with a user';
  @override
  String get titleRequired => 'Title is required';
  @override
  String get uploadError => 'Upload error. Please try again.';
  @override
  String get visibility => 'Visibility';
  @override
  String get waitingParticipants => 'Waiting for participants...';
  @override
  String get welcomeBanner => 'Welcome Banner';
  @override
  String get writeOnWall => 'Write on the wall...';
}
