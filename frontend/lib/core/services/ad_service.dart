import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'supabase_service.dart';
import 'remote_config_service.dart';

/// Serviço de Anúncios — Gerencia Rewarded Ads para ganhar moedas.
///
/// Usa o SDK real do Google Mobile Ads (AdMob).
/// App ID configurado no AndroidManifest.xml:
///   ca-app-pub-7192605876220796~8519538940
class AdService {
  // IDs reais de produção
  static const String _rewardedAdUnitAndroid =
      'ca-app-pub-7192605876220796/7206457273';

  // IDs de teste (usados em debug)
  static const String _rewardedAdUnitAndroidTest =
      'ca-app-pub-3940256099942544/5224354917';

  static String get _adUnitId =>
      kDebugMode ? _rewardedAdUnitAndroidTest : _rewardedAdUnitAndroid;

  static bool _initialized = false;
  static RewardedAd? _rewardedAd;
  static bool _adLoading = false;

  /// Limite diário de anúncios recompensados por usuário (dinâmico via RemoteConfig)
  static int get maxDailyRewardedAds => RemoteConfigService.maxDailyRewardedAds;
  static int _todayRewardedCount = 0;
  static DateTime? _lastRewardDate;

  /// Inicializa o SDK do AdMob e pré-carrega o primeiro anúncio
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      // Registrar dispositivos de teste em modo debug para evitar
      // cliques inválidos e possível bloqueio de conta AdMob.
      // O ID abaixo foi obtido do log: "Use RequestConfiguration.Builder()..."
      if (kDebugMode) {
        MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: const ['AF681C65379386F3419B92ABCC9444EC'],
          ),
        );
      }
      await MobileAds.instance.initialize();
      _initialized = true;
      await _loadRewardedAd();
      debugPrint('[AdService] AdMob inicializado com sucesso');
    } catch (e) {
      debugPrint('[AdService] Erro ao inicializar AdMob: $e');
    }
  }

  /// Verifica se ainda pode assistir anúncios hoje
  static bool get canWatchAd {
    _resetDailyCountIfNeeded();
    return _todayRewardedCount < maxDailyRewardedAds && _initialized;
  }

  /// Retorna quantos anúncios restam hoje
  static int get remainingAdsToday {
    _resetDailyCountIfNeeded();
    return maxDailyRewardedAds - _todayRewardedCount;
  }

  /// Verifica se um anúncio está pronto para exibição
  static bool get isAdReady => _rewardedAd != null && _initialized;

  /// Carrega o anúncio recompensado em background
  static Future<void> _loadRewardedAd() async {
    if (_adLoading || _rewardedAd != null) return;
    _adLoading = true;
    await RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _adLoading = false;
          debugPrint('[AdService] Rewarded ad carregado');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _adLoading = false;
          debugPrint(
              '[AdService] Falha ao carregar rewarded: ${error.message}');
        },
      ),
    );
  }

  /// Mostra o anúncio recompensado e credita moedas ao completar.
  ///
  /// Retorna `true` se o usuário completou o anúncio e recebeu a recompensa.
  static Future<bool> showRewardedAd({int? rewardCoins}) async {
    final effectiveCoins = rewardCoins ?? RemoteConfigService.rewardedCoinsPerAd;
    if (!canWatchAd) {
      debugPrint('[AdService] Limite diário atingido ou não inicializado');
      return false;
    }
    if (_rewardedAd == null) {
      debugPrint('[AdService] Anúncio não está pronto — tentando carregar...');
      await _loadRewardedAd();
      return false;
    }

    final completer = Completer<bool>();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd(); // pré-carrega o próximo
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        debugPrint('[AdService] Falha ao exibir anúncio: ${error.message}');
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
        _todayRewardedCount++;
        _lastRewardDate = DateTime.now();
        await _creditAdReward(effectiveCoins);
        await _logAdReward(effectiveCoins);
        debugPrint('[AdService] Recompensa de $effectiveCoins moedas creditada');
        if (!completer.isCompleted) completer.complete(true);
      },
    );

    return completer.future;
  }

  /// Credita moedas da recompensa de anúncio via RPC do Supabase
  static Future<void> _creditAdReward(int coins) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      await SupabaseService.client.rpc('transfer_coins', params: {
        'p_receiver_id': userId,
        'p_amount': coins,
      });
    } catch (e) {
      // Fallback: atualizar diretamente na coluna coins
      try {
        final current = await SupabaseService.table('profiles')
            .select('coins')
            .eq('id', userId)
            .maybeSingle();
        final balance = (current?['coins'] ?? 0) as num;
        await SupabaseService.table('profiles')
            .update({'coins': balance + coins}).eq('id', userId);
      } catch (e2) {
        debugPrint('[AdService] Erro ao creditar moedas: $e2');
      }
    }
  }

  /// Registra a recompensa de anúncio na tabela ad_reward_logs
  static Future<void> _logAdReward(int coins) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      await SupabaseService.table('ad_reward_logs').insert({
        'user_id': userId,
        'reward_type': 'rewarded_video',
        'coins_earned': coins,
      });
    } catch (e) {
      debugPrint('[AdService] Erro ao registrar reward log: $e');
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

  /// Libera recursos
  static void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
