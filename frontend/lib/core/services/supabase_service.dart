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
  static Future<dynamic> rpc(String functionName, {Map<String, dynamic>? params}) {
    return client.rpc(functionName, params: params);
  }

  /// Chamar Edge Functions
  static Future<FunctionResponse> edgeFunction(
    String functionName, {
    Map<String, dynamic>? body,
  }) {
    return client.functions.invoke(functionName, body: body);
  }

  /// Upload de arquivo para o Storage
  static Future<String> uploadFile({
    required String bucket,
    required String path,
    required dynamic file,
    FileOptions? fileOptions,
  }) async {
    await storage.from(bucket).upload(path, file, fileOptions: fileOptions);
    return storage.from(bucket).getPublicUrl(path);
  }

  /// Inscrever-se em canal Realtime
  static RealtimeChannel subscribeToChannel(String channelName) {
    return client.channel(channelName);
  }
}
