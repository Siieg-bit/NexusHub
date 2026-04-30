// =============================================================================
// LocalVideoService — Seleção de vídeo local e upload para Supabase Storage
//
// Fluxo:
//   1. Host toca em "Galeria" no ScreeningAddVideoSheet
//   2. image_picker abre o seletor de vídeo nativo
//   3. Vídeo selecionado é comprimido (se necessário) e enviado ao bucket
//      "screening-videos" no Supabase Storage
//   4. URL pública é retornada como LocalVideoResult
//   5. ScreeningRoomProvider.updateVideo() propaga para todos os participantes
//   6. StreamResolverService detecta a URL como StreamPlatform.local e usa
//      media_kit para reprodução direta
//
// Bucket: "screening-videos" (público, com RLS: apenas usuários autenticados
//   podem fazer upload; qualquer um pode ler)
// Caminho: screening-videos/{sessionId}/{userId}/{timestamp}.{ext}
// =============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../../../core/services/supabase_service.dart';

class LocalVideoResult {
  /// URL pública do vídeo no Supabase Storage
  final String url;

  /// Nome do arquivo original (para exibir como título)
  final String fileName;

  /// Tamanho do arquivo em bytes
  final int fileSize;

  /// Duração estimada (null se não disponível antes do upload)
  final Duration? duration;

  const LocalVideoResult({
    required this.url,
    required this.fileName,
    required this.fileSize,
    this.duration,
  });
}

class LocalVideoUploadProgress {
  final double progress; // 0.0 a 1.0
  final String status;   // 'compressing', 'uploading', 'done', 'error'
  final String? error;

  const LocalVideoUploadProgress({
    required this.progress,
    required this.status,
    this.error,
  });
}

class LocalVideoService {
  static const _bucket = 'screening-videos';
  static const _maxFileSizeMb = 500; // limite de upload: 500 MB

  /// Abre o seletor de vídeo nativo e retorna o arquivo selecionado.
  /// Retorna null se o usuário cancelar.
  static Future<XFile?> pickVideo() async {
    final picker = ImagePicker();
    try {
      final video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(hours: 3),
      );
      return video;
    } catch (e) {
      debugPrint('[LocalVideoService] pickVideo error: $e');
      return null;
    }
  }

  /// Faz upload do vídeo para o Supabase Storage e retorna a URL pública.
  ///
  /// [file] — arquivo de vídeo selecionado pelo image_picker
  /// [sessionId] — ID da sessão de screening (para organizar no bucket)
  /// [userId] — ID do usuário host
  /// [onProgress] — callback de progresso (opcional)
  static Future<LocalVideoResult> uploadVideo({
    required XFile file,
    required String sessionId,
    required String userId,
    void Function(LocalVideoUploadProgress)? onProgress,
  }) async {
    final localFile = File(file.path);
    final fileSizeBytes = await localFile.length();
    final fileSizeMb = fileSizeBytes / (1024 * 1024);

    // Validar tamanho
    if (fileSizeMb > _maxFileSizeMb) {
      throw Exception(
        'Vídeo muito grande (${fileSizeMb.toStringAsFixed(0)} MB). '
        'O limite é $_maxFileSizeMb MB.',
      );
    }

    onProgress?.call(const LocalVideoUploadProgress(
      progress: 0.05,
      status: 'uploading',
    ));

    // Construir caminho no bucket
    final ext = p.extension(file.name).toLowerCase().replaceAll('.', '');
    final safeExt = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'].contains(ext)
        ? ext
        : 'mp4';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$sessionId/$userId/$timestamp.$safeExt';

    onProgress?.call(const LocalVideoUploadProgress(
      progress: 0.1,
      status: 'uploading',
    ));

    try {
      // Upload para o Supabase Storage usando File em vez de bytes.
      // Carregar o vídeo inteiro em memória com readAsBytes() fazia aparelhos
      // menos potentes travarem ou encerrarem o processo durante uploads curtos
      // mas pesados. O client do Supabase consegue enviar File diretamente,
      // preservando memória e evitando o falso "travou em 10%" causado por OOM.
      final publicUrl = await SupabaseService.uploadFile(
        bucket: _bucket,
        path: storagePath,
        file: localFile,
        fileOptions: FileOptions(
          contentType: _mimeType(safeExt),
          upsert: false,
        ),
      );

      onProgress?.call(const LocalVideoUploadProgress(
        progress: 1.0,
        status: 'done',
      ));

      // Gerar um nome de exibição limpo
      final displayName = cleanFileName(file.name);

      return LocalVideoResult(
        url: publicUrl,
        fileName: displayName,
        fileSize: fileSizeBytes,
      );
    } catch (e) {
      onProgress?.call(LocalVideoUploadProgress(
        progress: 0.0,
        status: 'error',
        error: e.toString(),
      ));
      rethrow;
    }
  }

  /// Remove o vídeo do bucket após a sessão encerrar.
  /// Chamado opcionalmente pelo ScreeningRoomProvider ao fechar a sala.
  static Future<void> deleteVideo({
    required String sessionId,
    required String userId,
  }) async {
    try {
      final storage = SupabaseService.storage.from(_bucket);
      final files = await storage.list(path: '$sessionId/$userId');
      if (files.isNotEmpty) {
        final paths = files.map((f) => '$sessionId/$userId/${f.name}').toList();
        await storage.remove(paths);
        debugPrint('[LocalVideoService] Removidos ${paths.length} arquivo(s) do bucket.');
      }
    } catch (e) {
      debugPrint('[LocalVideoService] deleteVideo error: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _mimeType(String ext) {
    switch (ext) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      case 'webm':
        return 'video/webm';
      case 'm4v':
        return 'video/x-m4v';
      default:
        return 'video/mp4';
    }
  }

  /// Limpa o nome do arquivo para exibição (remove extensão, underscores, etc.)
  static String cleanFileName(String fileName) {
    // Remove extensão e caracteres especiais
    final withoutExt = p.basenameWithoutExtension(fileName);
    // Substituir underscores e hifens por espaços
    final clean = withoutExt
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Capitalizar primeira letra
    if (clean.isEmpty) return 'Vídeo local';
    return clean[0].toUpperCase() + clean.substring(1);
  }
}
