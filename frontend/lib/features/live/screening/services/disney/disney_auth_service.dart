import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Gerencia o ciclo de vida dos tokens de autenticação do Disney+.
///
/// A Disney+ não oferece OAuth público para terceiros. O Rave (e este serviço)
/// interceptam o device grant do localStorage após o login no WebView oficial
/// da Disney e o trocam por um access_token real via BAMGrid.
///
/// Fluxo:
/// 1. O usuário faz login em `https://www.disneyplus.com/login` via WebView.
/// 2. [extractAndSaveTokens] lê o localStorage, extrai o device grant assertion
///    e faz o exchange via POST /token para obter um access_token real.
/// 3. [getValidAccessToken] retorna o access_token, renovando-o se necessário.
class DisneyAuthService {
  static const _storage = FlutterSecureStorage();

  // ── Chaves de armazenamento seguro ────────────────────────────────────────
  static const _kAccessToken = 'disney_access_token';
  static const _kRefreshToken = 'disney_refresh_token';
  static const _kDeviceAssertion = 'disney_device_assertion';
  static const _kTokenExpiry = 'disney_token_expiry';

  // ── Credenciais BAM SDK (extraídas do APK do Rave via engenharia reversa) ─
  // API Key inicial (Bearer token para obter o access_token via device grant).
  // Decodificado: "disney&android&1.0.0" + HMAC.
  static const _initialApiKey =
      'Bearer ZGlzbmV5JmFuZHJvaWQmMS4wLjA.bkeb0m230uUhv8qrAXuNu39tbE_mD5EEhM_NAcohjyA';

  // Chave do device grant no localStorage do Disney+
  static const _deviceGrantKey =
      '__bam_sdk_device_grant--disney-svod-3d9324fc_prod';

  // ── Endpoints BAMGrid ─────────────────────────────────────────────────────
  static const _tokenEndpoint = 'https://global.edge.bamgrid.com/token';

  // ── Headers comuns BAMGrid ────────────────────────────────────────────────
  static Map<String, String> _bamHeaders(String authorization) => {
        'Authorization': authorization,
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
  /// Extrai o device grant do localStorage e faz o exchange para obter
  /// um access_token real via BAMGrid.
  ///
  /// O Disney+ armazena no localStorage a chave:
  ///   __bam_sdk_device_grant--disney-svod-3d9324fc_prod
  /// com valor: {"grantType":"urn:ietf:params:oauth:grant-type:jwt-bearer",
  ///              "assertion":"eyJ..."}
  ///
  /// O assertion é um JWT de dispositivo que é trocado por um access_token real
  /// via POST /token com grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer.
  static Future<bool> extractAndSaveTokens(
    InAppWebViewController controller,
  ) async {
    try {
      debugPrint('[DisneyAuth] Extraindo device grant do localStorage...');

      // Passo 1: Ler o device grant diretamente pela chave
      final deviceGrantRaw = await controller.evaluateJavascript(
        source: "localStorage.getItem('$_deviceGrantKey')",
      );

      debugPrint('[DisneyAuth] deviceGrant raw: ${deviceGrantRaw?.toString().substring(0, deviceGrantRaw.toString().length.clamp(0, 200))}');

      String? assertion;
      String? grantType;

      if (deviceGrantRaw != null &&
          deviceGrantRaw != 'null' &&
          deviceGrantRaw.toString().isNotEmpty) {
        // O valor pode vir com aspas externas do evaluateJavascript
        var raw = deviceGrantRaw.toString();
        // Remover aspas externas se presentes
        if (raw.startsWith('"') && raw.endsWith('"')) {
          raw = raw.substring(1, raw.length - 1);
        }
        // Unescape de JSON aninhado (igual ao Rave: replace("\", ""))
        raw = raw.replaceAll(r'\', '');

        try {
          final grant = jsonDecode(raw) as Map<String, dynamic>;
          assertion = grant['assertion'] as String?;
          grantType = grant['grantType'] as String?;
          debugPrint('[DisneyAuth] Device grant extraído: grantType=$grantType, assertion=${assertion?.substring(0, 20)}...');
        } catch (e) {
          debugPrint('[DisneyAuth] Erro ao parsear device grant JSON: $e');
          // Tentar regex como fallback
          final m = RegExp(r'"assertion":"(eyJ[^"]+)"').firstMatch(raw);
          if (m != null) {
            assertion = m.group(1);
            grantType = 'urn:ietf:params:oauth:grant-type:jwt-bearer';
            debugPrint('[DisneyAuth] assertion extraído via regex fallback');
          }
        }
      }

      // Fallback: tentar serializar o localStorage completo e buscar o device grant
      if (assertion == null) {
        debugPrint('[DisneyAuth] Tentando via JSON.stringify do localStorage...');
        final lsRaw = await controller.evaluateJavascript(
          source: 'JSON.stringify(window.localStorage)',
        );
        if (lsRaw != null && lsRaw != 'null') {
          final lsUnescaped = lsRaw.toString().replaceAll(r'\', '');
          debugPrint('[DisneyAuth] localStorage (500 chars): ${lsUnescaped.length > 500 ? lsUnescaped.substring(0, 500) : lsUnescaped}');

          // Buscar o assertion do device grant
          final assertionMatch = RegExp(r'"assertion":"(eyJ[^"]+)"').firstMatch(lsUnescaped);
          if (assertionMatch != null) {
            assertion = assertionMatch.group(1);
            grantType = 'urn:ietf:params:oauth:grant-type:jwt-bearer';
            debugPrint('[DisneyAuth] assertion encontrado via regex no localStorage completo');
          }

          // Também tentar pegar refresh_token para renovação futura
          final refreshMatch = RegExp(r'"refresh_token":"(eyJ[^"]+)"').firstMatch(lsUnescaped);
          if (refreshMatch != null) {
            final refreshToken = refreshMatch.group(1);
            if (refreshToken != null) {
              await _storage.write(key: _kRefreshToken, value: refreshToken);
              debugPrint('[DisneyAuth] refresh_token salvo como fallback');
            }
          }
        }
      }

      if (assertion == null) {
        debugPrint('[DisneyAuth] Device grant assertion não encontrado no localStorage');
        return false;
      }

      // Salvar o assertion para renovação futura
      await _storage.write(key: _kDeviceAssertion, value: assertion);

      // Passo 2: Fazer o exchange do device grant por um access_token real
      debugPrint('[DisneyAuth] Fazendo exchange do device grant por access_token...');
      final exchangeResult = await _exchangeDeviceGrant(
        assertion: assertion,
        grantType: grantType ?? 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      );

      if (exchangeResult == null) {
        debugPrint('[DisneyAuth] Exchange do device grant falhou');
        return false;
      }

      final accessToken = exchangeResult['access_token'] as String?;
      final refreshToken = exchangeResult['refresh_token'] as String?;

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('[DisneyAuth] access_token não retornado pelo exchange');
        return false;
      }

      await _saveTokens(accessToken, refreshToken);
      debugPrint('[DisneyAuth] Tokens salvos com sucesso! access_token: ${accessToken.substring(0, 20)}...');
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
    await _storage.delete(key: _kDeviceAssertion);
    await _storage.delete(key: _kTokenExpiry);
    debugPrint('[DisneyAuth] Tokens Disney+ removidos');
  }

  // ── Renovação de token ────────────────────────────────────────────────────

  /// Força a renovação imediata do access_token, ignorando o cache de expiração.
  static Future<String> forceRefresh() async {
    debugPrint('[DisneyAuth] Forçando renovação de token (401 recebido)...');
    await _storage.delete(key: _kTokenExpiry);
    return await _refreshAccessToken();
  }

  /// Renova o access_token usando o refresh_token ou o device assertion.
  static Future<String> _refreshAccessToken() async {
    // Tentar primeiro via refresh_token
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken != null) {
      debugPrint('[DisneyAuth] Renovando via refresh_token...');
      try {
        final response = await http.post(
          Uri.parse(_tokenEndpoint),
          headers: _bamHeaders(_initialApiKey),
          body: {
            'grant_type': 'refresh_token',
            'latitude': '0',
            'longitude': '0',
            'platform': 'browser',
            'refresh_token': refreshToken,
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final newAccessToken = data['access_token'] as String?;
          final newRefreshToken = data['refresh_token'] as String?;
          if (newAccessToken != null) {
            await _saveTokens(newAccessToken, newRefreshToken ?? refreshToken);
            debugPrint('[DisneyAuth] Token renovado via refresh_token');
            return newAccessToken;
          }
        } else if (response.statusCode == 400) {
          debugPrint('[DisneyAuth] refresh_token inválido, tentando device assertion...');
        }
      } catch (e) {
        debugPrint('[DisneyAuth] Erro ao renovar via refresh_token: $e');
      }
    }

    // Fallback: usar o device assertion
    final assertion = await _storage.read(key: _kDeviceAssertion);
    if (assertion != null) {
      debugPrint('[DisneyAuth] Renovando via device assertion...');
      final result = await _exchangeDeviceGrant(
        assertion: assertion,
        grantType: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      );
      if (result != null) {
        final newToken = result['access_token'] as String?;
        final newRefresh = result['refresh_token'] as String?;
        if (newToken != null) {
          await _saveTokens(newToken, newRefresh);
          debugPrint('[DisneyAuth] Token renovado via device assertion');
          return newToken;
        }
      }
    }

    await logout();
    throw DisneyAuthException(
      'Sessão Disney+ expirada. Por favor, faça login novamente.',
      isExpired: true,
    );
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  /// Faz o exchange do device grant assertion por um access_token real.
  ///
  /// POST /token com grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer
  static Future<Map<String, dynamic>?> _exchangeDeviceGrant({
    required String assertion,
    required String grantType,
  }) async {
    try {
      debugPrint('[DisneyAuth] Exchange device grant → $_tokenEndpoint');
      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: _bamHeaders(_initialApiKey),
        body: {
          'grant_type': grantType,
          'latitude': '0',
          'longitude': '0',
          'platform': 'browser',
          'assertion': assertion,
        },
      );
      debugPrint('[DisneyAuth] Exchange status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('[DisneyAuth] Exchange bem-sucedido! access_token: ${(data['access_token'] as String?)?.substring(0, 20)}...');
        return data;
      } else {
        debugPrint('[DisneyAuth] Exchange falhou: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
        return null;
      }
    } catch (e) {
      debugPrint('[DisneyAuth] Erro no exchange: $e');
      return null;
    }
  }

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

  static Map<String, dynamic>? _cachedConfig;

  static Future<Map<String, dynamic>?> _fetchBamSdkConfig() async {
    if (_cachedConfig != null) return _cachedConfig;
    try {
      const configUrl =
          'https://bam-sdk-configs.bamgrid.com/bam-sdk/v4.0/disney-svod-3d9324fc/android/v8.3.0/google/handset/prod.json';
      final response = await http.get(Uri.parse(configUrl));
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
