import 'dart:async';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Serviço de Anúncios — Gerencia Rewarded Ads para ganhar moedas.
///
/// Implementação abstrata que funciona sem SDK de anúncios instalado.
/// Para ativar anúncios reais:
/// 1. Adicione `google_mobile_ads: ^5.3.0` ao pubspec.yaml
/// 2. Crie uma conta em https://admob.google.com
/// 3. Substitua os IDs de teste abaixo pelos seus IDs reais
/// 4. Adicione o App ID no AndroidManifest.xml
/// 5. Descomente as chamadas ao SDK no código abaixo
class AdService {
  // IDs de teste — substituir por IDs reais em produção
  static const String rewardedAdUnitAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String rewardedAdUnitIOS =
      'ca-app-pub-3940256099942544/1712485313';
  static const String bannerAdUnitAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String bannerAdUnitIOS =
      'ca-app-pub-3940256099942544/2934735716';

  static bool _initialized = false;
  static bool _adReady = false;

  /// Limite diário de anúncios recompensados
  static const int maxDailyRewardedAds = 10;
  static int _todayRewardedCount = 0;
  static DateTime? _lastRewardDate;

  /// Inicializa o SDK de anúncios
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      // TODO: Quando google_mobile_ads estiver no pubspec, descomente:
      // await MobileAds.instance.initialize();
      _initialized = true;
      _preloadRewardedAd();
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

  /// Verifica se um anúncio está pronto para exibição
  static bool get isAdReady => _adReady && _initialized;

  /// Mostra um anúncio recompensado e credita moedas ao assistir completo.
  ///
  /// Retorna `true` se o usuário completou o anúncio e recebeu a recompensa.
  /// Em modo de desenvolvimento (sem SDK), simula o anúncio.
  static Future<bool> showRewardedAd({int rewardCoins = 5}) async {
    if (!canWatchAd) return false;

    try {
      // TODO: Quando google_mobile_ads estiver no pubspec, substituir por:
      // RewardedAd.show(...) com callback onUserEarnedReward

      // Simulação para desenvolvimento — credita moedas diretamente
      if (kDebugMode) {
        debugPrint('[AdService] Simulando anúncio recompensado...');
        await Future.delayed(const Duration(seconds: 1));
      }

      _todayRewardedCount++;
      _lastRewardDate = DateTime.now();

      // Creditar moedas no Supabase
      await _creditAdReward(rewardCoins);

      // Registrar no ad_rewards
      await _logAdReward(rewardCoins);

      debugPrint('[AdService] Recompensa de $rewardCoins moedas creditada');
      return true;
    } catch (e) {
      debugPrint('[AdService] Erro ao mostrar anúncio: $e');
      return false;
    }
  }

  /// Pré-carrega o próximo anúncio recompensado
  static Future<void> _preloadRewardedAd() async {
    try {
      // TODO: Quando google_mobile_ads estiver no pubspec:
      // await RewardedAd.load(adUnitId: ..., request: AdRequest(), ...)
      _adReady = true;
    } catch (e) {
      debugPrint('[AdService] Falha ao pré-carregar rewarded: $e');
      _adReady = false;
    }
  }

  /// Credita moedas da recompensa de anúncio via RPC
  static Future<void> _creditAdReward(int coins) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      await SupabaseService.client.rpc('transfer_coins', params: {
        'sender_id': userId,
        'receiver_id': userId,
        'amount': coins,
        'description': 'Recompensa de anúncio',
      });
    } catch (e) {
      // Fallback: atualizar diretamente
      try {
        final current = await SupabaseService.table('wallets')
            .select('balance')
            .eq('user_id', userId)
            .maybeSingle();
        final balance = (current?['balance'] ?? 0) as num;
        await SupabaseService.table('wallets')
            .update({'balance': balance + coins}).eq('user_id', userId);
      } catch (e2) {
        debugPrint('[AdService] Erro ao creditar moedas: $e2');
      }
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

  /// Libera recursos
  static void dispose() {
    _adReady = false;
  }
}
