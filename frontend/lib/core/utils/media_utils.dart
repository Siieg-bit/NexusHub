import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_player/video_player.dart';

/// Utilitários de mídia: compressão de imagem e validação de vídeo.
class MediaUtils {
  MediaUtils._();

  /// Duração máxima permitida para vídeos (em segundos).
  static const int maxVideoDurationSeconds = 180; // 3 minutos

  /// Tamanho máximo de imagem após compressão (em bytes) — 1 MB.
  static const int maxImageSizeBytes = 1024 * 1024;

  /// Qualidade padrão de compressão JPEG (0–100).
  static const int defaultJpegQuality = 80;

  /// Comprime uma imagem a partir de bytes brutos.
  /// Reduz a qualidade progressivamente até atingir [maxImageSizeBytes].
  /// Retorna os bytes comprimidos ou os originais se já estiverem abaixo do limite.
  static Future<Uint8List> compressImage(
    Uint8List bytes, {
    int quality = defaultJpegQuality,
    int minWidth = 1920,
    int minHeight = 1920,
  }) async {
    if (bytes.length <= maxImageSizeBytes) return bytes;

    try {
      var result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: CompressFormat.jpeg,
      );

      // Reduz qualidade progressivamente se ainda estiver grande
      int currentQuality = quality;
      while (result.length > maxImageSizeBytes && currentQuality > 30) {
        currentQuality -= 10;
        result = await FlutterImageCompress.compressWithList(
          bytes,
          quality: currentQuality,
          minWidth: minWidth,
          minHeight: minHeight,
          format: CompressFormat.jpeg,
        );
      }

      debugPrint(
          '[MediaUtils] Imagem comprimida: ${bytes.length} → ${result.length} bytes (qualidade: $currentQuality)');
      return result;
    } catch (e) {
      debugPrint('[MediaUtils] Erro ao comprimir imagem: $e');
      return bytes; // Retorna original em caso de erro
    }
  }

  /// Comprime uma imagem a partir de um arquivo.
  static Future<Uint8List> compressImageFile(File file) async {
    final bytes = await file.readAsBytes();
    return compressImage(bytes);
  }

  /// Valida a duração de um vídeo antes do upload.
  /// Retorna `null` se válido, ou uma mensagem de erro se inválido.
  static Future<String?> validateVideoDuration(String filePath) async {
    try {
      final controller = VideoPlayerController.file(File(filePath));
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();

      if (duration.inSeconds > maxVideoDurationSeconds) {
        final maxMin = maxVideoDurationSeconds ~/ 60;
        return 'O vídeo excede o limite de $maxMin minutos. '
            'Duração atual: ${_formatDuration(duration)}.';
      }
      return null; // Válido
    } catch (e) {
      debugPrint('[MediaUtils] Erro ao validar vídeo: $e');
      return null; // Em caso de erro, deixa prosseguir
    }
  }

  /// Formata uma Duration para exibição amigável (mm:ss).
  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Retorna o tamanho formatado de um arquivo em KB ou MB.
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
