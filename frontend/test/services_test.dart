import 'package:flutter_test/flutter_test.dart';
import 'package:amino_clone/core/services/ad_service.dart';
import 'package:amino_clone/core/services/iap_service.dart';

/// Testes unitários para os serviços de AdMob e IAP.
///
/// Estes testes cobrem a lógica de negócio dos serviços sem depender
/// de SDKs externos (que requerem dispositivo físico ou emulador).
void main() {
  group('AdService — lógica de negócio', () {
    test('canWatchAd retorna false quando não inicializado', () {
      // AdService não foi inicializado, então não pode exibir anúncios
      expect(AdService.canWatchAd, isFalse);
    });

    test('isAdReady retorna false quando não inicializado', () {
      expect(AdService.isAdReady, isFalse);
    });

    test('remainingAdsToday retorna maxDailyRewardedAds quando zerado', () {
      expect(AdService.remainingAdsToday, equals(3));
    });

    test('dispose não lança exceção', () {
      expect(() => AdService.dispose(), returnsNormally);
    });
  });

  group('IAPService — constantes e fallback', () {
    test('fallbackCoinPackages tem 5 pacotes', () {
      expect(IAPService.fallbackCoinPackages.length, equals(5));
    });

    test('pacotes de moedas têm IDs corretos', () {
      final ids = IAPService.fallbackCoinPackages.map((p) => p.id).toList();
      expect(ids, containsAll([
        'coins_100',
        'coins_500',
        'coins_1200',
        'coins_3000',
        'coins_7000',
      ]));
    });

    test('pacotes de moedas têm quantidades corretas', () {
      final coins = IAPService.fallbackCoinPackages.map((p) => p.coins).toList();
      expect(coins, equals([100, 500, 1200, 3000, 7000]));
    });

    test('pacotes de moedas têm preços em reais', () {
      for (final pkg in IAPService.fallbackCoinPackages) {
        expect(pkg.priceLabel, contains('R\$'));
      }
    });

    test('isAminoPlus começa como false', () {
      expect(IAPService.isAminoPlus, isFalse);
    });

    test('entitlementAminoPlus tem valor correto', () {
      expect(IAPService.entitlementAminoPlus, equals('amino_plus'));
    });
  });

  group('CoinPackage — modelo', () {
    test('CoinPackage cria instância corretamente', () {
      const pkg = CoinPackage(
        id: 'coins_100',
        coins: 100,
        priceLabel: r'R$ 4,90',
      );
      expect(pkg.id, equals('coins_100'));
      expect(pkg.coins, equals(100));
      expect(pkg.priceLabel, equals(r'R$ 4,90'));
      expect(pkg.revenueCatPackage, isNull);
    });

    test('pacote com maior valor tem mais moedas', () {
      const pkg1 = CoinPackage(id: 'coins_100', coins: 100, priceLabel: r'R$ 4,90');
      const pkg2 = CoinPackage(id: 'coins_7000', coins: 7000, priceLabel: r'R$ 179,90');
      expect(pkg2.coins, greaterThan(pkg1.coins));
    });
  });

  group('AdService — limite diário', () {
    test('maxDailyRewardedAds é 3', () {
      expect(AdService.maxDailyRewardedAds, equals(3));
    });

    test('showRewardedAd retorna false quando não inicializado', () async {
      final result = await AdService.showRewardedAd(rewardCoins: 10);
      expect(result, isFalse);
    });
  });
}
