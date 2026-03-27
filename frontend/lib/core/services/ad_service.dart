import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'supabase_service.dart';

/// Serviço de Anúncios — Gerencia Rewarded Ads para ganhar moedas.
///
/// Usa Google AdMob (pode ser substituído por AppLovin MAX ou Vungle).
/// Para configurar:
/// 1. Crie uma conta em https://admob.google.com
/// 2. Crie um app e obtenha os Ad Unit IDs
/// 3. Substitua os IDs de teste abaixo pelos seus IDs reais
/// 4. Adicione o App ID no AndroidManifest.xml e Info.plist
class AdService {
  // IDs de teste — substituir por IDs reais em produção
  static const String _rewardedAdUnitAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _rewardedAdUnitIOS =
      'ca-app-pub-3940256099942544/1712485313';
  static const String _bannerAdUnitAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _bannerAdUnitIOS =
      'ca-app-pub-3940256099942544/2934735716';

  static RewardedAd? _rewardedAd;
  static BannerAd? _bannerAd;
  static bool _initialized = false;

  /// Limite diário de anúncios recompensados
  static const int maxDailyRewardedAds = 10;
  static int _todayRewardedCount = 0;
  static DateTime? _lastRewardDate;

  /// Inicializa o SDK de anúncios
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      _loadRewardedAd();
      debugPrint('[AdService] AdMob inicializado com sucesso');
    } catch (e) {
      debugPrint('[AdService] Erro ao inicializar AdMob: $e');
    }
  }

  /// Verifica se ainda pode assistir anúncios hoje
  static bool get canWatchAd {
    _resetDailyCountIfNeeded();
    return _todayRewardedCount < maxDailyRewardedAds;
  }

  /// Retorna quantos anúncios restam hoje
  static int get remainingAdsToday {
    _resetDailyCountIfNeeded();
    return maxDailyRewardedAds - _todayRewardedCount;
  }

  /// Mostra um anúncio recompensado e credita moedas ao assistir completo
  static Future<bool> showRewardedAd({int rewardCoins = 5}) async {
    if (!canWatchAd) return false;

    if (_rewardedAd == null) {
      await _loadRewardedAd();
      // Espera carregar
      await Future.delayed(const Duration(seconds: 2));
      if (_rewardedAd == null) return false;
    }

    final completer = Completer<bool>();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd(); // Pre-load próximo
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
        _todayRewardedCount++;
        _lastRewardDate = DateTime.now();

        // Creditar moedas no Supabase
        await _creditAdReward(rewardCoins);

        // Registrar no ad_rewards
        await _logAdReward(rewardCoins);

        if (!completer.isCompleted) completer.complete(true);
      },
    );

    return completer.future;
  }

  /// Carrega um banner ad
  static BannerAd? loadBannerAd({
    AdSize size = AdSize.banner,
    Function(Ad)? onLoaded,
  }) {
    _bannerAd = BannerAd(
      adUnitId: defaultTargetPlatform == TargetPlatform.iOS
          ? _bannerAdUnitIOS
          : _bannerAdUnitAndroid,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          onLoaded?.call(ad);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('[AdService] Banner falhou: $error');
        },
      ),
    )..load();
    return _bannerAd;
  }

  /// Carrega o próximo anúncio recompensado
  static Future<void> _loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: defaultTargetPlatform == TargetPlatform.iOS
          ? _rewardedAdUnitIOS
          : _rewardedAdUnitAndroid,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          debugPrint('[AdService] Rewarded ad carregado');
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Falha ao carregar rewarded: $error');
        },
      ),
    );
  }

  /// Credita moedas da recompensa de anúncio
  static Future<void> _creditAdReward(int coins) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      // Incrementar moedas diretamente
      await SupabaseService.table('profiles').update({
        'coins_count': _rawSql('coins_count + $coins'),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('[AdService] Erro ao creditar moedas: $e');
    }
  }

  /// Registra a recompensa de anúncio na tabela ad_rewards
  static Future<void> _logAdReward(int coins) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      await SupabaseService.table('ad_rewards').insert({
        'user_id': userId,
        'reward_type': 'rewarded_video',
        'coins_earned': coins,
      });
    } catch (e) {
      debugPrint('[AdService] Erro ao registrar reward: $e');
    }
  }

  /// Reseta o contador diário se mudou o dia
  static void _resetDailyCountIfNeeded() {
    if (_lastRewardDate == null) return;
    final now = DateTime.now();
    if (now.day != _lastRewardDate!.day ||
        now.month != _lastRewardDate!.month ||
        now.year != _lastRewardDate!.year) {
      _todayRewardedCount = 0;
    }
  }

  /// Helper para SQL raw (Supabase não suporta diretamente, usar RPC)
  static dynamic _rawSql(String expr) => expr;

  /// Libera recursos
  static void dispose() {
    _rewardedAd?.dispose();
    _bannerAd?.dispose();
  }
}
