# Engenharia Reversa - Amino APK (com.narvii.amino.master v3.5.35109)

## Pacote e Estrutura
- Package: com.narvii.amino.master
- 8 DEX files (classes.dex a classes8.dex) - app grande e complexo
- Domínios: .aminoapps.com, .narvii.com, static.aminoapps.com, s1.aminoapps.com

## Módulos Principais (pacotes com.narvii.*)
- account (login, signup, push notifications)
- amino (MainActivity, page navigation)
- blog/post (BlogPost, ImagePost, LinkPost, PollPost, QuizPost, StoryPost, TopicPost)
- catalog (CatalogWrapper, CategoryPost)
- chat (ChatActivity, global chat, video/RTC, screenroom, thread, signalling)
- comment (CommentPost)
- community (CommunityList, search, detail)
- drawer (navigation drawer)
- editor (image cropping, editing)
- feed (Feed, quizzes)
- flag (moderation/reports, FlagLogList)
- headlines (featured content)
- influencer (influencer system)
- item (Wiki/ItemPost)
- livelayer (live streaming)
- master (MasterActivity, explorer, home, profile, widget)
- media (gallery, online media)
- members (member management)
- monetization (avatar frames, bubbles, stickers, store)
- onboarding (OnBoardingActivity)
- poll (PlainPollPost)
- repost (RepostActivity)
- sharedfolder (SharedAlbum)
- story (ShareStory)
- user/profile (UserProfile, GlobalBio, EditAvatar, EditBackground)
- wallet (Wallet, WalletTrans, Membership)
- util/http (ApiRequest, ApiService, URLFetch)
- util/ws (WsService - WebSocket)
- video (fullscreen video, filters, recording)
- widget (UI components)
- youtube (YouTube integration)

## Modelo de Dados (Campos extraídos do smali)

### User
- uid, nickname, aminoId, icon (avatar), content (bio)
- level, reputation, onlineStatus (ONLINE=1, OFFLINE=2)
- role (USER=0, LEADER=100, CURATOR=101, COMMUNITY_AGENT=102, MODERATOR=200, ADMIN=201)
- blogsCount, commentsCount, postsCount, storiesCount, itemsCount
- consecutiveCheckInDays, totalQuizHighestScore, totalQuizPlayedTimes
- followingStatus, membershipStatus (NONE/FORWARD/BACKWARD/MUTUAL)
- accountMembershipStatus (NONE=0, AMINO_PLUS=1)
- avatarFrame, moodSticker, mediaList, tagList, fanClubList
- createdTime, modifiedTime, activeTime, securityLevel, settings

### Community
- id, name, content (description), tagline, icon, endpoint
- agent (owner User), membersCount, communityHeat
- themePack, primaryLanguage, joinType, searchable
- configuration, extensions, mediaList, promotionalMediaList
- communityHeadList, influencerList, userAddedTopicList
- createdTime, modifiedTime, status, listedStatus

### Feed/Post (NVObject)
- author (User), content, mediaList, commentsCount
- votedValue, votesCount (likes), globalVotesCount
- featureType (NONE=0, NORMAL=1, PINNED=2)
- createdTime, modifiedTime, status, viewCount
- shareURLFullPath, tipInfo, keywords

### Blog (extends Feed)
- blogId, title, type, credits
- polloptList, quizQuestionList, sceneList
- publishToGlobal, refObject, refObjectId, refObjectType
- userAddedTopicList, totalPollVoteCount, totalQuizPlayCount

### Comment
- commentId, author, content, type (GENERAL=0, STICKER=3)
- parentId, parentType, headCommentId
- votedValue, votesSum, subcommentsCount, subcommentsPreview
- mediaList, stickerId, createTime, modifiedTime

### CheckInHistory (Gamificação)
- consecutiveCheckInDays, hasCheckInToday, hasAnyCheckIn
- history, joinedTime, startTime, stopTime
- streakRepairCoinCost, streakRepairWindowSize

## API Endpoints Encontrados
- /api/v1/g/s/community/joined
- /api/v1/g/s/community/suggested
- /api/v1/g/s/persona/interest
- /api/v1/g/s/topic/{id}/metadata
- /api/v1/x{ndcId}/s/... (community-specific endpoints)
- /g/s/community-collection/view
- /g/s/community-collection/{id}/communities
- /auth/login

## WebSocket
- Protocolo: wss://
- Ping interval: 60000ms (60s)
- Request timeout: 15000ms (15s)
- Reconnect strategy com backoff
- Usa OkHttp WebSocket client

## Navegação (172 layouts de chat, 20+ de profile, 20+ de community)
- Bottom navigation com tabs
- Drawer lateral com lista de comunidades
- Dentro de cada comunidade: Feed, Chat, Members, Wiki/Catalog
- Chat com bubbles, imagens, vídeo, stickers, links
- Profile com avatar frame, badges, reputation, level

## Monetização
- Amino Coins (wallet)
- Amino+ membership
- Avatar frames, chat bubbles, stickers (store)
- Offer wall, ads integration (AdMob, AppLovin, Facebook Ads, Amazon APS, Fyber)
