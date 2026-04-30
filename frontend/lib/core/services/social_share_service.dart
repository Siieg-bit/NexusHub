import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// SocialShareService centraliza compartilhamento direcionado para apps sociais.
///
/// A estratégia é em camadas: primeiro tenta integração nativa via MethodChannel
/// para abrir o app específico com imagem e link; se o destino não estiver
/// instalado ou a plataforma não oferecer a integração, usa o share sheet padrão.
class SocialShareService {
  SocialShareService._();

  static const MethodChannel _channel = MethodChannel('nexushub/social_share');

  static Future<bool> shareCommunityCard({
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
      return true;
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
      if (success) return true;
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
    return false;
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
