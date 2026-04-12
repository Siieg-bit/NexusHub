import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviço centralizado para acesso ao Supabase.
/// Provê acesso ao cliente, auth, storage e realtime.
class SupabaseService {
  SupabaseService._();

  /// Instância do cliente Supabase
  static SupabaseClient get client => Supabase.instance.client;

  /// Instância do Auth
  static GoTrueClient get auth => client.auth;

  /// ID do usuário autenticado atual
  static String? get currentUserId => auth.currentUser?.id;

  /// Sessão atual
  static Session? get currentSession => auth.currentSession;

  /// Verificar se está autenticado
  static bool get isAuthenticated => currentSession != null;

  /// Acesso direto às tabelas
  static SupabaseQueryBuilder table(String name) => client.from(name);

  /// Acesso ao Storage
  static SupabaseStorageClient get storage => client.storage;

  /// Acesso ao Realtime
  static RealtimeClient get realtime => client.realtime;

  /// Chamar funções RPC
  static Future<dynamic> rpc(String functionName,
      {Map<String, dynamic>? params}) {
    return client.rpc(functionName, params: params);
  }

  /// Chamar Edge Functions
  static Future<FunctionResponse> edgeFunction(
    String functionName, {
    Map<String, dynamic>? body,
  }) {
    return client.functions.invoke(functionName, body: body);
  }

  /// Upload de arquivo para o Storage.
  ///
  /// Aceita tanto [File] quanto bytes brutos ([Uint8List] ou [List<int>]).
  static Future<String> uploadFile({
    required String bucket,
    required String path,
    required dynamic file,
    FileOptions fileOptions = const FileOptions(),
  }) async {
    final storageBucket = storage.from(bucket);

    if (file is Uint8List) {
      await storageBucket.uploadBinary(path, file, fileOptions: fileOptions);
    } else if (file is List<int>) {
      await storageBucket.uploadBinary(
        path,
        Uint8List.fromList(file),
        fileOptions: fileOptions,
      );
    } else if (file is File) {
      await storageBucket.upload(path, file, fileOptions: fileOptions);
    } else {
      throw ArgumentError(
        'Tipo de arquivo não suportado para upload: ${file.runtimeType}',
      );
    }

    return storageBucket.getPublicUrl(path);
  }

  /// Inscrever-se em canal Realtime
  static RealtimeChannel subscribeToChannel(String channelName) {
    return client.channel(channelName);
  }
}
