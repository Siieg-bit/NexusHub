import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'supabase_service.dart';
import 'chunked_upload_service.dart';
import '../../core/l10n/locale_provider.dart';
import '../widgets/nexus_media_picker.dart';

/// ============================================================================
/// MediaUploadService — Upload de mídia para Supabase Storage.
///
/// Features:
/// - Pick single/multiple images
/// - Pick video, file
/// - Crop de imagem (avatar, banner)
/// - Compressão WebP automática para imagens (reduz ~40% vs JPEG)
/// - Upload PARALELO de múltiplos arquivos (3x mais rápido)
/// - Upload para bucket correto com path isolado por usuário
/// - Retorna URL pública
/// ============================================================================

enum MediaBucket {
  avatars,
  communityIcons,
  postMedia,
  chatMedia,
  wikiMedia,
  /// Banner local do usuário dentro de uma comunidade
  communityProfileBanners,
  /// Plano de fundo local do usuário dentro de uma comunidade
  communityProfileBackgrounds,
  /// Galeria de fotos local do usuário dentro de uma comunidade
  communityProfileGallery,
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
  static const _uuid = Uuid();

  // Context obrigatório para abrir o NexusMediaPicker.
  // Deve ser setado antes de chamar pickImage/pickVideo/pickMultipleImages.
  // Alternativa: passar context diretamente em cada método.
  // Mantemos o _picker como fallback para contextos sem BuildContext.
  static final _picker = ImagePicker();

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
      case MediaBucket.communityProfileBanners:
        return 'community-profile-banners';
      case MediaBucket.communityProfileBackgrounds:
        return 'community-profile-backgrounds';
      case MediaBucket.communityProfileGallery:
        return 'community-profile-gallery';
    }
  }

  /// Pick uma única imagem usando o NexusMediaPicker (galeria própria).
  /// [context] é obrigatório para abrir o bottom sheet.
  /// [cropConfig] aplica crop após a seleção.
  static Future<File?> pickImage({
    BuildContext? context,
    ImageSource source = ImageSource.gallery, // mantido para retrocompat.
    int maxWidth = 1920,
    int maxHeight = 1920,
    int imageQuality = 85,
    NexusCropConfig? cropConfig,
  }) async {
    // Se tiver context, usa o NexusMediaPicker
    if (context != null && context.mounted) {
      final results = await showNexusMediaPicker(
        context,
        maxSelect: 1,
        mode: NexusPickerMode.imageOnly,
        cropConfig: cropConfig,
      );
      if (results.isEmpty) return null;
      return results.first.file;
    }
    // Fallback: ImagePicker legado (sem context)
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight.toDouble(),
      imageQuality: imageQuality,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Pick múltiplas imagens usando o NexusMediaPicker.
  static Future<List<File>> pickMultipleImages({
    BuildContext? context,
    int maxWidth = 1920,
    int maxHeight = 1920,
    int imageQuality = 85,
    int limit = 10,
  }) async {
    if (context != null && context.mounted) {
      final results = await showNexusMediaPicker(
        context,
        maxSelect: limit,
        mode: NexusPickerMode.imageOnly,
      );
      return results.map((r) => r.file).toList();
    }
    // Fallback: ImagePicker legado
    final picked = await _picker.pickMultiImage(
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight.toDouble(),
      imageQuality: imageQuality,
      limit: limit,
    );
    return picked.map((xf) => File(xf.path)).toList();
  }

  /// Pick um vídeo usando o NexusMediaPicker.
  static Future<File?> pickVideo({
    BuildContext? context,
    ImageSource source = ImageSource.gallery, // mantido para retrocompat.
    Duration maxDuration = const Duration(minutes: 5),
  }) async {
    if (context != null && context.mounted) {
      final results = await showNexusMediaPicker(
        context,
        maxSelect: 1,
        mode: NexusPickerMode.videoOnly,
      );
      if (results.isEmpty) return null;
      return results.first.file;
    }
    // Fallback: ImagePicker legado
    final picked = await _picker.pickVideo(
      source: source,
      maxDuration: maxDuration,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Pick imagem OU vídeo usando o NexusMediaPicker.
  static Future<NexusMediaFile?> pickMedia({
    required BuildContext context,
    NexusCropConfig? cropConfig,
  }) async {
    final results = await showNexusMediaPicker(
      context,
      maxSelect: 1,
      mode: NexusPickerMode.all,
      cropConfig: cropConfig,
    );
    if (results.isEmpty) return null;
    return results.first;
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

  /// Comprime uma imagem para WebP (reduz ~40% vs JPEG).
  ///
  /// Parâmetros:
  /// - [minWidth]/[minHeight]: dimensões máximas de saída
  /// - [quality]: qualidade WebP (0–100)
  ///
  /// Retorna o arquivo comprimido ou o original se a compressão falhar.
  static Future<File> _compressToWebP(
    File file, {
    int minWidth = 1280,
    int minHeight = 1280,
    int quality = 80,
  }) async {
    try {
      final ext = path.extension(file.path).toLowerCase();
      // Não comprimir vídeos, PDFs ou arquivos já otimizados
      if (!['.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'].contains(ext)) {
        return file;
      }

      final tmpDir = await getTemporaryDirectory();
      final targetPath = '${tmpDir.path}/${_uuid.v4()}.webp';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        format: CompressFormat.webp,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
      );

      if (result == null) return file;
      return File(result.path);
    } catch (e) {
      debugPrint('MediaUploadService._compressToWebP error: $e — usando original');
      return file;
    }
  }

  /// Upload de um único arquivo para Supabase Storage.
  ///
  /// Imagens são automaticamente comprimidas para WebP antes do upload.
  /// Use [skipCompression: true] para pular a compressão (ex: GIFs, vídeos).
  static Future<UploadResult?> uploadFile({
    required File file,
    required MediaBucket bucket,
    String? customPath,
    void Function(double progress)? onProgress,
    bool skipCompression = false,
    int compressQuality = 80,
    int compressMaxWidth = 1280,
    int compressMaxHeight = 1280,
    BuildContext? context, // Opcional para mostrar overlay de progresso
  }) async {
    OverlayEntry? overlayEntry;
    try {
      final s = getStrings();
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception(s.userNotAuthenticated);

      // Mostrar overlay se for arquivo grande (> 1MB) e tiver context
      final fileSize = await file.length();
      final isLargeFile = fileSize > 1024 * 1024;
      
      if (isLargeFile && context != null && context.mounted) {
        final progressNotifier = ValueNotifier<double>(0.0);
        overlayEntry = OverlayEntry(
          builder: (ctx) => Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (ctx, value, child) {
                    return UploadProgressIndicator(
                      progress: value,
                      label: 'Enviando arquivo...',
                    );
                  },
                ),
              ),
            ),
          ),
        );
        Overlay.of(context).insert(overlayEntry!);
        
        // Wrap onProgress para atualizar o notifier
        final originalOnProgress = onProgress;
        onProgress = (val) {
          progressNotifier.value = val;
          originalOnProgress?.call(val);
        };
      }

      // Comprimir para WebP se for imagem
      final fileToUpload = skipCompression
          ? file
          : await _compressToWebP(
              file,
              quality: compressQuality,
              minWidth: compressMaxWidth,
              minHeight: compressMaxHeight,
            );

      final ext = skipCompression
          ? path.extension(file.path).toLowerCase()
          : '.webp';
      final fileName = '${_uuid.v4()}$ext';
      final storagePath = customPath ?? '$userId/$fileName';
      final bucketName = _bucketName(bucket);

      final contentType = skipCompression
          ? _getMimeType(path.extension(file.path).toLowerCase())
          : 'image/webp';

      // Usa ChunkedUploadService para todos os uploads
      final url = await ChunkedUploadService.upload(
        file: fileToUpload,
        bucket: bucketName,
        path: storagePath,
        onProgress: onProgress,
        contentType: contentType,
      );

      overlayEntry?.remove();
      return UploadResult(
        url: url,
        path: storagePath,
        bucket: bucketName,
      );
    } catch (e) {
      debugPrint('MediaUploadService.uploadFile error: $e');
      overlayEntry?.remove();
      return null;
    }
  }

  /// Upload de múltiplos arquivos em PARALELO.
  ///
  /// Todos os arquivos são enviados simultaneamente, reduzindo o tempo total
  /// de upload de O(n) para O(1) (limitado pelo arquivo mais lento).
  /// O progresso é reportado conforme cada upload é concluído.
  static Future<List<UploadResult>> uploadMultipleFiles({
    required List<File> files,
    required MediaBucket bucket,
    void Function(int completed, int total)? onProgress,
    bool skipCompression = false,
  }) async {
    if (files.isEmpty) return [];

    int completed = 0;
    final total = files.length;

    // Disparar todos os uploads em paralelo
    final futures = files.map((file) async {
      final result = await uploadFile(
        file: file,
        bucket: bucket,
        skipCompression: skipCompression,
      );
      completed++;
      onProgress?.call(completed, total);
      return result;
    });

    final results = await Future.wait(futures, eagerError: false);
    return results.whereType<UploadResult>().toList();
  }

  /// Upload de avatar com crop circular e compressão otimizada para avatar.
  static Future<String?> uploadAvatar({
    BuildContext? context,
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await pickImage(
      context: context,
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 90,
      cropConfig: NexusCropConfig.avatar,
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
      compressQuality: 85,
      compressMaxWidth: 512,
      compressMaxHeight: 512,
    );
    return result?.url;
  }

  /// Upload de banner/cover da comunidade
  static Future<String?> uploadCommunityBanner({
    BuildContext? context,
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await pickImage(
      context: context,
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
      cropConfig: NexusCropConfig.banner,
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
      compressQuality: 80,
      compressMaxWidth: 1920,
      compressMaxHeight: 1080,
    );
    return result?.url;
  }

  /// Upload de imagens para post (múltiplas, em paralelo)
  static Future<List<String>> uploadPostImages({
    BuildContext? context,
    void Function(int completed, int total)? onProgress,
  }) async {
    final files = await pickMultipleImages(context: context, limit: 10);
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
    final ext = path.extension(file.path).toLowerCase();
    final isVideo = ['.mp4', '.webm', '.mov', '.avi'].contains(ext);

    final result = await uploadFile(
      file: file,
      bucket: MediaBucket.chatMedia,
      skipCompression: isVideo, // Não comprimir vídeos
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
