import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Gerencia o ciclo de vida dos tokens de autenticação do Disney+.
///
/// A Disney+ não oferece OAuth público para terceiros. O Rave (e este serviço)
/// interceptam os tokens do localStorage após o login no WebView oficial da Disney.
///
/// Fluxo:
/// 1. O usuário faz login em `https://www.disneyplus.com/login` via WebView.
/// 2. [extractAndSaveTokens] lê o localStorage e salva os tokens no secure storage.
/// 3. [getValidAccessToken] retorna o access_token, renovando-o se necessário.
class DisneyAuthService {
  static const _storage = FlutterSecureStorage();

  // ── Chaves de armazenamento seguro ────────────────────────────────────────
  static const _kAccessToken = 'disney_access_token';
  static const _kRefreshToken = 'disney_refresh_token';
  static const _kTokenExpiry = 'disney_token_expiry';

  // ── Credenciais BAM SDK (extraídas do APK do Rave via engenharia reversa) ─
  // Client-ID da plataforma Android SVOD do Disney+.
  static const _bamClientId = 'disney-svod-3d9324fc';
  static const _bamPlatform = 'android/google/handset';
  static const _bamSdkVersion = '8.3.3';
  static const _appVersion = '2.16.2-rc2.0';

  // API Key inicial (Bearer token para obter o access_token anônimo inicial).
  // Decodificado: "disney&android&1.0.0" + HMAC.
  static const _initialApiKey =
      'Bearer ZGlzbmV5JmFuZHJvaWQmMS4wLjA.bkeb0m230uUhv8qrAXuNu39tbE_mD5EEhM_NAcohjyA';

  // ── Endpoints BAMGrid ─────────────────────────────────────────────────────
  static const _tokenEndpoint = 'https://disney.api.edge.bamgrid.com/token';
  static const _bamSdkConfigUrl =
      'https://bam-sdk-configs.bamgrid.com/bam-sdk/v4.0/disney-svod-3d9324fc/android/v8.3.0/google/handset/prod.json';

  // ── Headers comuns BAMGrid ────────────────────────────────────────────────
  static Map<String, String> _bamHeaders(String authorization) => {
        'Authorization': authorization,
        'X-BAMSDK-Client-ID': _bamClientId,
        'X-BAMSDK-Platform': _bamPlatform,
        'X-BAMSDK-Version': _bamSdkVersion,
        'X-Application-Version': _appVersion,
        'X-DSS-Edge-Accept': 'vnd.dss.edge+json; version=2',
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      };

  // ── JavaScript injetado no WebView (baseado no disney.js do Rave) ─────────
  /// Script que monitora mudanças de URL e remove atributos readonly dos inputs.
  static const disneyJs = r'''
(function() {
    console.log("nexushub-disney.js loaded");
    var currentUrl = window.location.href;
    setInterval(function() {
        if (currentUrl != window.location.href) {
            currentUrl = window.location.href;
            if (window.NexusInterface && window.NexusInterface.pageChanged) {
                window.NexusInterface.pageChanged(window.location.href);
            }
            var pinInput = document.getElementsByClassName("form-input-digit__input");
            if (pinInput) {
                for (var i = 0; i < pinInput.length; i++) {
                    if (pinInput[i]) {
                        if (i == 0) { pinInput[i].blur(); }
                        pinInput[i].removeAttribute("readonly");
                    }
                }
            }
        }
    }, 100);
})();
''';

  // ── Extração de tokens via WebView ────────────────────────────────────────
  /// Extrai e salva os tokens de autenticação do localStorage do WebView.
  ///
  /// Fluxo idêntico ao Rave (DisneyVideoGridFragment.extractLocalStorage):
  /// 1. Serializa o localStorage completo com JSON.stringify
  /// 2. Remove todos os backslashes (unescape de JSON aninhado) — IGUAL AO RAVE
  /// 3. Aplica os regexes exatos do Rave: {"token":"(.*?)"} e {"refresh_token":"(.*?)"}
  ///
  /// O Disney+ armazena os tokens dentro de valores JSON aninhados no localStorage,
  /// ex: {"bam.api.token":"{\"token\":\"eyJ...\",\"refresh_token\":\"eyJ...\"}"}
  /// Após remover os backslashes, o regex encontra os tokens corretamente.
  static Future<bool> extractAndSaveTokens(
    InAppWebViewController controller,
  ) async {
    try {
      debugPrint('[DisneyAuth] Extraindo tokens do localStorage...');

      // Passo 1: Serializar o localStorage completo (igual ao Rave)
      final lsRaw = await controller.evaluateJavascript(
        source: 'JSON.stringify(window.localStorage)',
      );

      if (lsRaw == null || lsRaw == 'null' || lsRaw.toString().isEmpty) {
        debugPrint('[DisneyAuth] localStorage vazio ou inacessível');
        return false;
      }

      // Passo 2: Remover backslashes — EXATAMENTE como o Rave faz
      // O Rave chama: Ll60/d0;->S(p1, "\\", "", false, 4, null)
      // que é equivalente a string.replace("\", "")
      final lsUnescaped = lsRaw.toString().replaceAll(r'\', '');

      debugPrint('[DisneyAuth] localStorage (primeiros 500 chars): '
          '${lsUnescaped.length > 500 ? lsUnescaped.substring(0, 500) : lsUnescaped}');

      // Passo 3: Aplicar os regexes EXATOS do Rave
      // Rave usa: Pattern.compile("\\{\"token\":\"(.*?)\"}")
      // Equivalente Dart: RegExp(r'{"token":"(.*?)"}')
      String? accessToken;
      final tokenMatch = RegExp(r'{"token":"(.*?)"}').firstMatch(lsUnescaped);
      if (tokenMatch != null &&
          tokenMatch.group(1) != null &&
          tokenMatch.group(1)!.isNotEmpty) {
        accessToken = tokenMatch.group(1);
        debugPrint('[DisneyAuth] access_token encontrado via regex Rave');
      }

      String? refreshToken;
      final refreshMatch =
          RegExp(r'{"refresh_token":"(.*?)"}').firstMatch(lsUnescaped);
      if (refreshMatch != null &&
          refreshMatch.group(1) != null &&
          refreshMatch.group(1)!.isNotEmpty) {
        refreshToken = refreshMatch.group(1);
        debugPrint('[DisneyAuth] refresh_token encontrado via regex Rave');
      }

      // Fallback 1: regex mais permissivo para variações de formato
      if (accessToken == null) {
        final fallbackPatterns = [
          RegExp(r'"token":"([^"]{20,})"'),
          RegExp(r'"access_token":"([^"]{20,})"'),
          RegExp(r'"bamAccessToken":"([^"]{20,})"'),
        ];
        for (final pattern in fallbackPatterns) {
          final m = pattern.firstMatch(lsUnescaped);
          if (m != null && m.group(1) != null && m.group(1)!.isNotEmpty) {
            accessToken = m.group(1);
            debugPrint('[DisneyAuth] access_token encontrado via fallback regex');
            break;
          }
        }
      }

      // Fallback 2: acessar chaves diretamente no localStorage
      if (accessToken == null) {
        debugPrint('[DisneyAuth] Tentando acesso direto às chaves do localStorage...');
        for (final key in [
          'token',
          'access_token',
          'bamAccessToken',
          'bam.api.token',
        ]) {
          final val = await controller.evaluateJavascript(
            source: "localStorage.getItem('$key')",
          );
          if (val != null && val != 'null' && val.toString().length > 10) {
            final cleaned =
                val.toString().replaceAll('"', '').replaceAll(r'\', '');
            // Se o valor for um JSON, tentar extrair o token de dentro
            final innerMatch =
                RegExp(r'{"token":"(.*?)"}').firstMatch(cleaned);
            if (innerMatch != null) {
              accessToken = innerMatch.group(1);
            } else if (cleaned.startsWith('eyJ')) {
              // JWT direto
              accessToken = cleaned;
            }
            if (accessToken != null && accessToken.isNotEmpty) {
              debugPrint(
                  '[DisneyAuth] access_token encontrado via chave direta: $key');
              break;
            }
          }
        }
      }

      if (accessToken == null) {
        debugPrint('[DisneyAuth] access_token não encontrado no localStorage');
        return false;
      }

      debugPrint('[DisneyAuth] Tokens extraídos com sucesso!');
      await _saveTokens(accessToken, refreshToken);
      return true;
    } catch (e) {
      debugPrint('[DisneyAuth] Erro ao extrair tokens: $e');
      return false;
    }
  }

  /// Verifica se o usuário está autenticado (tem tokens salvos).
  static Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: _kAccessToken);
    return token != null && token.isNotEmpty;
  }

  /// Retorna um access_token válido, renovando-o se necessário.
  ///
  /// Lança [DisneyAuthException] se não houver tokens salvos.
  static Future<String> getValidAccessToken() async {
    final accessToken = await _storage.read(key: _kAccessToken);
    if (accessToken == null) {
      throw DisneyAuthException(
        'Não autenticado no Disney+. '
        'Por favor, faça login pelo navegador integrado.',
      );
    }

    // Verificar se o token expirou
    final expiryStr = await _storage.read(key: _kTokenExpiry);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        debugPrint('[DisneyAuth] Token expirado, renovando...');
        return await _refreshAccessToken();
      }
    }

    return accessToken;
  }

  /// Limpa todos os tokens salvos (logout).
  static Future<void> logout() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kTokenExpiry);
    debugPrint('[DisneyAuth] Tokens Disney+ removidos');
  }

  // ── Renovação de token ────────────────────────────────────────────────────

  /// Força a renovação imediata do access_token, ignorando o cache de expiração.
  ///
  /// Usado pelo DisneyPlaybackService quando o servidor retorna 401 inesperado,
  /// idêntico ao comportamento do Rave de renovar e repetir a requisição.
  static Future<String> forceRefresh() async {
    debugPrint('[DisneyAuth] Forçando renovação de token (401 recebido do servidor)...');
    // Invalidar o cache de expiração para forçar renovação
    await _storage.delete(key: _kTokenExpiry);
    return await _refreshAccessToken();
  }

  /// Renova o access_token usando o refresh_token via endpoint BAMGrid.
  ///
  /// Baseado no fluxo `exchangeTokens` do DisneyServer do Rave.
  static Future<String> _refreshAccessToken() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null) {
      throw DisneyAuthException(
        'Refresh token não encontrado. '
        'Por favor, faça login novamente.',
      );
    }

    debugPrint('[DisneyAuth] Renovando access_token via BAMGrid...');

    try {
      // Primeiro, obter a configuração do BAM SDK para pegar o endpoint de exchange
      final config = await _fetchBamSdkConfig();
      final exchangeEndpoint = config?['services']?['token']?['client']
          ?['endpoints']?['exchange']?['href'] as String?;
      final endpoint = exchangeEndpoint ?? _tokenEndpoint;

      // POST para o endpoint de troca de token
      // Campos baseados no DisneyService.smali do Rave:
      // grant_type, latitude, longitude, platform, refresh_token
      final response = await http.post(
        Uri.parse(endpoint),
        headers: _bamHeaders(_initialApiKey),
        body: {
          'grant_type': 'refresh_token',
          'latitude': '0',
          'longitude': '0',
          'platform': 'android',
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        if (newAccessToken == null) {
          throw DisneyAuthException('Resposta de renovação inválida');
        }

        await _saveTokens(newAccessToken, newRefreshToken ?? refreshToken);
        debugPrint('[DisneyAuth] Token renovado com sucesso');
        return newAccessToken;
      } else if (response.statusCode == 400) {
        // invalid_grant — token expirado ou revogado
        final error = jsonDecode(response.body);
        if (error['error'] == 'invalid_grant') {
          await logout();
          throw DisneyAuthException(
            'Sessão Disney+ expirada. Por favor, faça login novamente.',
            isExpired: true,
          );
        }
        throw DisneyAuthException(
          'Erro ao renovar token: ${response.body}',
        );
      } else {
        throw DisneyAuthException(
          'Erro HTTP ${response.statusCode} ao renovar token',
        );
      }
    } catch (e) {
      if (e is DisneyAuthException) rethrow;
      throw DisneyAuthException('Falha ao renovar token Disney+: $e');
    }
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  static Future<void> _saveTokens(
    String accessToken,
    String? refreshToken,
  ) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _kRefreshToken, value: refreshToken);
    }
    // Tokens do Disney+ expiram em ~1 hora
    final expiry = DateTime.now().add(const Duration(minutes: 55));
    await _storage.write(key: _kTokenExpiry, value: expiry.toIso8601String());
  }

  static String? _extractTokenByRegex(String source, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(source);
      if (match != null && match.groupCount >= 1) {
        final token = match.group(1);
        if (token != null && token.isNotEmpty && token != 'null') {
          return token;
        }
      }
    }
    return null;
  }

  static Map<String, dynamic>? _cachedConfig;

  static Future<Map<String, dynamic>?> _fetchBamSdkConfig() async {
    if (_cachedConfig != null) return _cachedConfig;
    try {
      final response = await http.get(Uri.parse(_bamSdkConfigUrl));
      if (response.statusCode == 200) {
        _cachedConfig = jsonDecode(response.body) as Map<String, dynamic>;
        return _cachedConfig;
      }
    } catch (_) {}
    return null;
  }
}

/// Exceção específica para erros de autenticação Disney+.
class DisneyAuthException implements Exception {
  final String message;
  final bool isExpired;

  const DisneyAuthException(this.message, {this.isExpired = false});

  @override
  String toString() => 'DisneyAuthException: $message';
}
