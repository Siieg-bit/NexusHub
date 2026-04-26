import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

/// ============================================================================
/// BlurHashService — Geração e cache de BlurHash para mídias.
///
/// Fluxo:
/// 1. Após upload de imagem, chamar [generateAndStore] passando a URL pública.
/// 2. O serviço chama a Edge Function `generate-blurhash` que processa a imagem
///    no servidor e retorna a string do hash.
/// 3. O hash é retornado para ser salvo no modelo (post ou mensagem).
///
/// No Flutter, usar o pacote `blurhash_dart` para decodificar e exibir o
/// placeholder antes da imagem real carregar no CachedNetworkImage.
/// ============================================================================
class BlurHashService {
  BlurHashService._();

  static const String _functionName = 'generate-blurhash';

  /// Gera o BlurHash para uma imagem a partir de sua URL pública.
  ///
  /// Retorna a string do BlurHash ou `null` em caso de erro.
  /// O erro é silencioso — BlurHash é uma feature de polimento, não crítica.
  static Future<String?> generateForUrl(String imageUrl) async {
    try {
      final supabaseUrl = SupabaseService.client.supabaseUrl;
      final anonKey = SupabaseService.client.supabaseKey;
      final functionUrl = '$supabaseUrl/functions/v1/$_functionName';

      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $anonKey',
        },
        body: jsonEncode({'image_url': imageUrl}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['blurhash'] as String?;
      }
      return null;
    } catch (e) {
      // BlurHash é opcional — nunca bloquear o fluxo principal por falha aqui.
      return null;
    }
  }
}
