// =============================================================================
// ScreeningLocalVideoSheet — Seleção e upload de vídeo local da galeria
//
// Exibe:
//   1. Botão "Escolher da Galeria" (abre image_picker)
//   2. Preview do arquivo selecionado (nome, tamanho, duração)
//   3. Barra de progresso durante o upload
//   4. Confirmação ao concluir
// =============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/screening_room_provider.dart';
import '../services/local_video_service.dart';

class ScreeningLocalVideoSheet extends ConsumerStatefulWidget {
  final String sessionId;
  final String threadId;
  /// Se true, o vídeo é adicionado à fila em vez de reproduzir imediatamente.
  final bool addToQueue;

  const ScreeningLocalVideoSheet({
    super.key,
    required this.sessionId,
    required this.threadId,
    this.addToQueue = false,
  });

  @override
  ConsumerState<ScreeningLocalVideoSheet> createState() =>
      _ScreeningLocalVideoSheetState();
}

class _ScreeningLocalVideoSheetState
    extends ConsumerState<ScreeningLocalVideoSheet> {
  XFile? _selectedFile;
  String? _selectedFileName;
  int? _selectedFileSizeBytes;

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  String? _errorMessage;

  // ── Selecionar vídeo da galeria ────────────────────────────────────────────
  Future<void> _pickVideo() async {
    HapticFeedback.selectionClick();

    final file = await LocalVideoService.pickVideo();
    if (file == null || !mounted) return;

    final fileSizeBytes = await File(file.path).length();
    if (!mounted) return;

    setState(() {
      _selectedFile = file;
      _selectedFileName = LocalVideoService.cleanFileName(file.name);
      _selectedFileSizeBytes = fileSizeBytes;
      _errorMessage = null;
    });
  }

  // ── Fazer upload e atualizar a sala ────────────────────────────────────────
  Future<void> _upload() async {
    if (_selectedFile == null) return;
    HapticFeedback.mediumImpact();

    final userId = ref.read(screeningRoomProvider(widget.threadId)).hostUserId;
    if (userId == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Enviando vídeo...';
      _errorMessage = null;
    });

    try {
      final result = await LocalVideoService.uploadVideo(
        file: _selectedFile!,
        sessionId: widget.sessionId,
        userId: userId,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _uploadProgress = progress.progress;
            _uploadStatus = switch (progress.status) {
              'uploading' when progress.progress < 0.1 => 'Preparando vídeo...',
              'uploading' => 'Enviando vídeo... mantenha a tela aberta',
              'done' => 'Concluído!',
              'error' => 'Erro no upload',
              _ => 'Processando...',
            };
          });
        },
      );

      if (!mounted) return;

      // Adicionar à fila ou reproduzir imediatamente
      final notifier = ref.read(screeningRoomProvider(widget.threadId).notifier);
      if (widget.addToQueue) {
        await notifier.addToQueue(
          url: result.url,
          title: result.fileName,
          thumbnail: result.thumbnailUrl,
        );
      } else {
        await notifier.updateVideo(
          videoUrl: result.url,
          videoTitle: result.fileName,
          videoThumbnail: result.thumbnailUrl,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(result.url);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Helpers de formatação ──────────────────────────────────────────────────
  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPad = mq.viewInsets.bottom + mq.padding.bottom + 24;
    final isUploadIndeterminate =
        _isUploading && _uploadProgress >= 0.1 && _uploadProgress < 1.0;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPad),
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E0E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Título ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.video_library_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Vídeo da Galeria',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Selecione um vídeo do seu dispositivo para reproduzir na sala',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Área de seleção ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _selectedFile == null
                ? _buildPickerButton()
                : _buildFilePreview(),
          ),

          // ── Erro ────────────────────────────────────────────────────────────
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Progresso do upload ──────────────────────────────────────────────
          if (_isUploading) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _uploadStatus,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        isUploadIndeterminate
                            ? 'Enviando'
                            : '${(_uploadProgress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: isUploadIndeterminate ? null : _uploadProgress,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF6C5CE7),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Botão de upload ──────────────────────────────────────────────────
          if (_selectedFile != null && !_isUploading) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _upload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Enviar e Reproduzir',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Botão de seleção (estado vazio) ───────────────────────────────────────
  Widget _buildPickerButton() {
    return GestureDetector(
      onTap: _pickVideo,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              color: Colors.white.withValues(alpha: 0.4),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Toque para escolher um vídeo',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'MP4, MOV, AVI, MKV — até 500 MB',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preview do arquivo selecionado ────────────────────────────────────────
  Widget _buildFilePreview() {
    return GestureDetector(
      onTap: _isUploading ? null : _pickVideo,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Ícone de vídeo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: Color(0xFF6C5CE7),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            // Info do arquivo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedFileName ?? 'Vídeo selecionado',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_selectedFileSizeBytes != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _formatSize(_selectedFileSizeBytes!),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Botão de trocar
            if (!_isUploading)
              Icon(
                Icons.swap_horiz_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
