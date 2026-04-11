import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'supabase_service.dart';
import '../../core/l10n/locale_provider.dart';

/// ============================================================================
/// MediaUploadService — Upload de mídia para Supabase Storage.
///
/// Features:
/// - Pick single/multiple images
/// - Pick video, file
/// - Crop de imagem (avatar, banner)
/// - Upload para bucket correto com path isolado por usuário
/// - Retorna URL pública
/// - Suporte a progresso de upload
/// ============================================================================

enum MediaBucket {
  avatars,
  communityIcons,
  postMedia,
  chatMedia,
  wikiMedia,
}

class UploadResult {
  final String url;
  final String path;
  final String bucket;

  const UploadResult({
    required this.url,
    required this.path,
    required this.bucket,
  });
}

class MediaUploadService {
  static final _picker = ImagePicker();
  static const _uuid = Uuid();

  /// Retorna o nome do bucket no Supabase Storage
  static String _bucketName(MediaBucket bucket) {
    switch (bucket) {
      case MediaBucket.avatars:
        return 'avatars';
      case MediaBucket.communityIcons:
        return 'community-icons';
      case MediaBucket.postMedia:
        return 'post-media';
      case MediaBucket.chatMedia:
        return 'chat-media';
      case MediaBucket.wikiMedia:
        return 'wiki-media';
    }
  }

  /// Pick uma única imagem da galeria ou câmera
  static Future<File?> pickImage({
    ImageSource source = ImageSource.gallery,
    int maxWidth = 1920,
    int maxHeight = 1920,
    int imageQuality = 85,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight.toDouble(),
      imageQuality: imageQuality,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Pick múltiplas imagens da galeria
  static Future<List<File>> pickMultipleImages({
    int maxWidth = 1920,
    int maxHeight = 1920,
    int imageQuality = 85,
    int limit = 10,
  }) async {
    final picked = await _picker.pickMultiImage(
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight.toDouble(),
      imageQuality: imageQuality,
      limit: limit,
    );
    return picked.map((xf) => File(xf.path)).toList();
  }

  /// Pick um vídeo
  static Future<File?> pickVideo({
    ImageSource source = ImageSource.gallery,
    Duration maxDuration = const Duration(minutes: 5),
  }) async {
    final picked = await _picker.pickVideo(
      source: source,
      maxDuration: maxDuration,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Crop de imagem (para avatares, banners)
  ///
  /// [cropStyle] foi removido da API do cropImage() no image_cropper 6+.
  /// Para crop circular, use [useCircleCrop] = true, que configura
  /// o AndroidUiSettings com CropStyle.circle internamente.
  static Future<File?> cropImage(
    File file, {
    CropAspectRatio? aspectRatio,
    bool useCircleCrop = false,
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async {
    final cropStyle = useCircleCrop ? CropStyle.circle : CropStyle.rectangle;

    try {
      final s = getStrings();
      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        aspectRatio: aspectRatio,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar Imagem',
            toolbarColor: const Color(0xFF6C63FF),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFF6C63FF),
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: aspectRatio != null,
            cropStyle: cropStyle,
          ),
          IOSUiSettings(
            title: 'Recortar Imagem',
            cancelButtonTitle: s.cancel2,
            doneButtonTitle: 'Pronto',
            aspectRatioLockEnabled: aspectRatio != null,
          ),
        ],
      );
      if (cropped == null) return null;
      return File(cropped.path);
    } catch (e) {
      debugPrint('MediaUploadService.cropImage error: $e');
      // Fallback: retornar arquivo original sem crop
      return file;
    }
  }

  /// Upload de um único arquivo para Supabase Storage
  static Future<UploadResult?> uploadFile({
    required File file,
    required MediaBucket bucket,
    String? customPath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final s = getStrings();
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception(s.userNotAuthenticated);

      final ext = path.extension(file.path).toLowerCase();
      final fileName = '${_uuid.v4()}$ext';
      final storagePath = customPath ?? '$userId/$fileName';
      final bucketName = _bucketName(bucket);

      final bytes = await file.readAsBytes();

      await SupabaseService.client.storage.from(bucketName).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _getMimeType(ext),
              upsert: true,
            ),
          );

      final url = SupabaseService.client.storage
          .from(bucketName)
          .getPublicUrl(storagePath);

      return UploadResult(
        url: url,
        path: storagePath,
        bucket: bucketName,
      );
    } catch (e) {
      debugPrint('MediaUploadService.uploadFile error: $e');
      return null;
    }
  }

  /// Upload de múltiplos arquivos em paralelo
  static Future<List<UploadResult>> uploadMultipleFiles({
    required List<File> files,
    required MediaBucket bucket,
    void Function(int completed, int total)? onProgress,
  }) async {
    final results = <UploadResult>[];
    int completed = 0;

    for (final file in files) {
      final result = await uploadFile(file: file, bucket: bucket);
      if (result != null) {
        results.add(result);
      }
      completed++;
      onProgress?.call(completed, files.length);
    }

    return results;
  }

  /// Upload de avatar com crop circular
  static Future<String?> uploadAvatar({
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 90,
    );
    if (file == null) return null;

    final cropped = await cropImage(
      file,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      useCircleCrop: true,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (cropped == null) return null;

    final result = await uploadFile(
      file: cropped,
      bucket: MediaBucket.avatars,
    );
    return result?.url;
  }

  /// Upload de banner/cover da comunidade
  static Future<String?> uploadCommunityBanner({
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (file == null) return null;

    final cropped = await cropImage(
      file,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (cropped == null) return null;

    final result = await uploadFile(
      file: cropped,
      bucket: MediaBucket.communityIcons,
    );
    return result?.url;
  }

  /// Upload de imagens para post (múltiplas)
  static Future<List<String>> uploadPostImages({
    void Function(int completed, int total)? onProgress,
  }) async {
    final files = await pickMultipleImages(limit: 10);
    if (files.isEmpty) return [];

    final results = await uploadMultipleFiles(
      files: files,
      bucket: MediaBucket.postMedia,
      onProgress: onProgress,
    );

    return results.map((r) => r.url).toList();
  }

  /// Upload de mídia para chat
  static Future<String?> uploadChatMedia({
    required File file,
  }) async {
    final result = await uploadFile(
      file: file,
      bucket: MediaBucket.chatMedia,
    );
    return result?.url;
  }

  /// Deletar arquivo do Storage
  static Future<bool> deleteFile({
    required String bucket,
    required String filePath,
  }) async {
    try {
      await SupabaseService.client.storage.from(bucket).remove([filePath]);
      return true;
    } catch (e) {
      debugPrint('MediaUploadService.deleteFile error: $e');
      return false;
    }
  }

  static String _getMimeType(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.webm':
        return 'video/webm';
      case '.mp3':
        return 'audio/mpeg';
      case '.ogg':
        return 'audio/ogg';
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      case '.wav':
        return 'audio/wav';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}
