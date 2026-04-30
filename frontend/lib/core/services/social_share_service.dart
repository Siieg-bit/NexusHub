import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Resultado de uma tentativa de compartilhamento social.
class SocialShareResult {
  final bool success;
  final bool usedNativeTarget;
  final String target;
  final String? nativePackage;
  final String? error;

  const SocialShareResult({
    required this.success,
    required this.usedNativeTarget,
    required this.target,
    this.nativePackage,
    this.error,
  });
}

/// SocialShareService centraliza compartilhamento direcionado para apps sociais.
///
/// A estratégia é em camadas: primeiro tenta integração nativa via MethodChannel
/// para abrir o app específico com imagem e link; se o destino não estiver
/// instalado ou a plataforma não oferecer a integração, usa o share sheet padrão.
class SocialShareService {
  SocialShareService._();

  static const MethodChannel _channel = MethodChannel('nexushub/social_share');

  /// Retorna alvos sociais instalados/conhecidos na plataforma atual.
  ///
  /// No Android a consulta é nativa por pacote. Em plataformas sem ponte nativa,
  /// retorna apenas o fallback genérico para manter a UI funcional.
  static Future<Set<String>> availableTargets() async {
    if (kIsWeb) return {SocialShareTarget.more};
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('availableTargets');
      if (result == null) return {SocialShareTarget.more};
      return {...result.map((e) => e.toString()), SocialShareTarget.more};
    } on MissingPluginException catch (_) {
      return {SocialShareTarget.more};
    } on PlatformException catch (e) {
      debugPrint('[SocialShareService] availableTargets failed: ${e.code} ${e.message}');
      return {SocialShareTarget.more};
    } catch (e) {
      debugPrint('[SocialShareService] availableTargets unexpected error: $e');
      return {SocialShareTarget.more};
    }
  }

  static Future<SocialShareResult> shareCommunityCard({
    required String target,
    required File imageFile,
    required String text,
    required String url,
    required String subject,
  }) async {
    if (target == SocialShareTarget.more || kIsWeb) {
      await _fallbackShare(
        imageFile: imageFile,
        text: text,
        subject: subject,
      );
      return SocialShareResult(
        success: true,
        usedNativeTarget: false,
        target: target,
      );
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'shareCommunityCard',
        {
          'target': target,
          'imagePath': imageFile.path,
          'text': text,
          'url': url,
          'subject': subject,
        },
      );
      final success = result?['success'] == true;
      if (success) {
        return SocialShareResult(
          success: true,
          usedNativeTarget: true,
          target: target,
          nativePackage: result?['target'] as String?,
        );
      }
    } on MissingPluginException catch (_) {
      // Plataforma sem implementação nativa: fallback controlado abaixo.
    } on PlatformException catch (e) {
      debugPrint('[SocialShareService] native share failed: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('[SocialShareService] unexpected share error: $e');
    }

    await _fallbackShare(
      imageFile: imageFile,
      text: text,
      subject: subject,
    );
    return SocialShareResult(
      success: true,
      usedNativeTarget: false,
      target: target,
      error: 'fallback_used',
    );
  }

  static Future<void> _fallbackShare({
    required File imageFile,
    required String text,
    required String subject,
  }) async {
    await Share.shareXFiles(
      [
        XFile(
          imageFile.path,
          mimeType: 'image/png',
          name: 'nexushub-community.png',
        ),
      ],
      text: text,
      subject: subject,
    );
  }
}

class SocialShareTarget {
  static const String whatsapp = 'whatsapp';
  static const String instagramStories = 'instagram_stories';
  static const String instagramFeed = 'instagram_feed';
  static const String telegram = 'telegram';
  static const String facebook = 'facebook';
  static const String messenger = 'messenger';
  static const String twitter = 'twitter';
  static const String more = 'more';
}
