import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ============================================================================
// RolePlayScreen
//
// Permite que membros de um chat convidem um personagem de IA para a conversa.
// O personagem responde via Edge Function ai-roleplay (OpenAI GPT-4.1-mini).
//
// Fluxo:
//   1. Usuário abre o menu do chat → "RolePlay com IA"
//   2. Tela exibe personagens disponíveis
//   3. Usuário seleciona um → abre o chat de roleplay
//   4. Mensagens do usuário são enviadas à Edge Function
//   5. Resposta do personagem é exibida no chat e salva no histórico
// ============================================================================

// ── Modelos ──────────────────────────────────────────────────────────────────

class AiCharacter {
  final String id;
  final String name;
  final String? avatarUrl;
  final String description;
  final List<String> tags;

  const AiCharacter({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.description,
    required this.tags,
  });

  factory AiCharacter.fromJson(Map<String, dynamic> j) => AiCharacter(
        id: j['id'] as String,
        name: j['name'] as String,
        avatarUrl: j['avatar_url'] as String?,
        description: j['description'] as String,
        tags: List<String>.from(j['tags'] as List? ?? []),
      );
}

class RolePlayMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  const RolePlayMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });
}

// ── Tela principal ────────────────────────────────────────────────────────────

class RolePlayScreen extends ConsumerStatefulWidget {
  final String threadId;

  const RolePlayScreen({super.key, required this.threadId});

  static Future<void> show(BuildContext context, String threadId) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RolePlayScreen(threadId: threadId),
      ),
    );
  }

  @override
  ConsumerState<RolePlayScreen> createState() => _RolePlayScreenState();
}

class _RolePlayScreenState extends ConsumerState<RolePlayScreen> {
  // ── Estado ──
  List<AiCharacter> _characters = [];
  AiCharacter? _activeCharacter;
  bool _isLoadingCharacters = true;
  bool _hasActiveSession = false;

  // ── Chat ──
  final List<RolePlayMessage> _messages = [];
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadCharacters();
    _checkActiveSession();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Carregamento ──────────────────────────────────────────────────────────

  Future<void> _loadCharacters() async {
    try {
      final res = await SupabaseService.table('ai_characters')
          .select('id, name, avatar_url, description, tags')
          .eq('is_active', true)
          .order('name');
      if (!mounted) return;
      setState(() {
        _characters = (res as List? ?? [])
            .map((e) => AiCharacter.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _isLoadingCharacters = false;
      });
    } catch (e) {
      debugPrint('[RolePlay] loadCharacters error: $e');
      if (mounted) setState(() => _isLoadingCharacters = false);
    }
  }

  Future<void> _checkActiveSession() async {
    try {
      final res = await SupabaseService.rpc(
        'get_active_roleplay_session',
        params: {'p_thread_id': widget.threadId},
      );
      final rows = res as List? ?? [];
      if (rows.isNotEmpty && mounted) {
        final row = Map<String, dynamic>.from(rows.first);
        final char = AiCharacter(
          id: row['character_id'] as String,
          name: row['character_name'] as String,
          avatarUrl: row['character_avatar'] as String?,
          description: '',
          tags: [],
        );
        setState(() {
          _activeCharacter = char;
          _hasActiveSession = true;
        });
      }
    } catch (e) {
      debugPrint('[RolePlay] checkActiveSession error: $e');
    }
  }

  // ── Ações ─────────────────────────────────────────────────────────────────

  Future<void> _startSession(AiCharacter character) async {
    HapticService.action();
    try {
      await SupabaseService.rpc(
        'start_roleplay_session',
        params: {
          'p_thread_id': widget.threadId,
          'p_character_id': character.id,
        },
      );
      if (!mounted) return;
      setState(() {
        _activeCharacter = character;
        _hasActiveSession = true;
        _messages.clear();
        _history.clear();
      });
      // Mensagem de boas-vindas do personagem
      await _sendToAI(
        'Olá! Apresente-se brevemente e pergunte como pode ajudar.',
        isWelcome: true,
      );
    } catch (e) {
      debugPrint('[RolePlay] startSession error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao iniciar sessão'),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _endSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surfaceColor,
        title: Text(
          'Encerrar RolePlay?',
          style: TextStyle(
              color: ctx.nexusTheme.textPrimary,
              fontWeight: FontWeight.w700),
        ),
        content: Text(
          'O personagem ${_activeCharacter?.name} será removido do chat.',
          style: TextStyle(color: ctx.nexusTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Encerrar',
              style: TextStyle(color: ctx.nexusTheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await SupabaseService.rpc(
        'end_roleplay_session',
        params: {'p_thread_id': widget.threadId},
      );
      if (!mounted) return;
      setState(() {
        _activeCharacter = null;
        _hasActiveSession = false;
        _messages.clear();
        _history.clear();
      });
      HapticService.action();
    } catch (e) {
      debugPrint('[RolePlay] endSession error: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isSending || _activeCharacter == null) return;
    _chatController.clear();
    HapticService.action();

    setState(() {
      _messages.add(RolePlayMessage(
        content: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isSending = true;
    });
    _scrollToBottom();

    await _sendToAI(text);
  }

  Future<void> _sendToAI(String userMessage, {bool isWelcome = false}) async {
    if (_activeCharacter == null) return;
    try {
      final response = await SupabaseService.client.functions.invoke(
        'ai-roleplay',
        body: {
          'thread_id': widget.threadId,
          'user_message': userMessage,
          'character_id': _activeCharacter!.id,
          'history': _history,
        },
      );

      if (response.status != 200) {
        throw Exception('HTTP ${response.status}');
      }

      final data = response.data as Map<String, dynamic>?;
      final reply = data?['reply'] as String? ?? '';

      if (reply.isEmpty) throw Exception('Empty reply');

      // Atualizar histórico para contexto futuro
      if (!isWelcome) {
        _history.add({'role': 'user', 'content': userMessage});
      }
      _history.add({'role': 'assistant', 'content': reply});

      // Manter histórico limitado
      if (_history.length > 20) {
        _history = _history.sublist(_history.length - 20);
      }

      if (mounted) {
        setState(() {
          _messages.add(RolePlayMessage(
            content: reply,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isSending = false;
        });
        _scrollToBottom();
        HapticService.tap();
      }

      // Salvar mensagem do personagem no histórico do chat
      try {
        await SupabaseService.rpc(
          'send_chat_message_with_reputation',
          params: {
            'p_thread_id': widget.threadId,
            'p_content': '[${_activeCharacter!.name}] $reply',
            'p_type': 'text',
          },
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('[RolePlay] sendToAI error: $e');
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao obter resposta do personagem'),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = context.nexusTheme;
    final r = context.r;

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: theme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                color: theme.accentPrimary, size: r.s(20)),
            SizedBox(width: r.s(8)),
            Text(
              'RolePlay com IA',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: r.fs(17),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          if (_hasActiveSession)
            TextButton(
              onPressed: _endSession,
              child: Text(
                'Encerrar',
                style: TextStyle(
                    color: theme.error, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: _hasActiveSession
          ? _buildChatView(theme, r)
          : _buildCharacterPicker(theme, r),
    );
  }

  // ── Seleção de personagem ─────────────────────────────────────────────────

  Widget _buildCharacterPicker(dynamic theme, dynamic r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.s(20), r.s(16), r.s(20), r.s(8)),
          child: Text(
            'Escolha um personagem para o chat',
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: r.fs(14),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingCharacters
              ? Center(
                  child: CircularProgressIndicator(
                      color: theme.accentPrimary))
              : _characters.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum personagem disponível',
                        style: TextStyle(color: theme.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(16), vertical: r.s(8)),
                      itemCount: _characters.length,
                      separatorBuilder: (_, __) => SizedBox(height: r.s(8)),
                      itemBuilder: (_, i) =>
                          _buildCharacterCard(_characters[i], theme, r),
                    ),
        ),
      ],
    );
  }

  Widget _buildCharacterCard(
      AiCharacter char, dynamic theme, dynamic r) {
    return GestureDetector(
      onTap: () => _startSession(char),
      child: Container(
        padding: EdgeInsets.all(r.s(16)),
        decoration: BoxDecoration(
          color: theme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            // Avatar do personagem
            Container(
              width: r.s(52),
              height: r.s(52),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.accentPrimary.withValues(alpha: 0.8),
                    theme.accentSecondary.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: char.avatarUrl != null
                  ? ClipOval(
                      child: Image.network(char.avatarUrl!,
                          fit: BoxFit.cover))
                  : Icon(Icons.smart_toy_rounded,
                      color: Colors.white, size: r.s(26)),
            ),
            SizedBox(width: r.s(12)),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    char.name,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: r.fs(15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: r.s(4)),
                  Text(
                    char.description,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: r.fs(12),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (char.tags.isNotEmpty) ...[
                    SizedBox(height: r.s(6)),
                    Wrap(
                      spacing: r.s(4),
                      children: char.tags
                          .take(3)
                          .map((tag) => Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.s(8),
                                    vertical: r.s(2)),
                                decoration: BoxDecoration(
                                  color: theme.accentPrimary
                                      .withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(r.s(20)),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    color: theme.accentPrimary,
                                    fontSize: r.fs(10),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: theme.textSecondary, size: r.s(20)),
          ],
        ),
      ),
    );
  }

  // ── Chat com o personagem ─────────────────────────────────────────────────

  Widget _buildChatView(dynamic theme, dynamic r) {
    return Column(
      children: [
        // Banner do personagem ativo
        _buildActiveBanner(theme, r),
        // Mensagens
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          color: theme.accentPrimary),
                      SizedBox(height: r.s(12)),
                      Text(
                        'Iniciando conversa...',
                        style: TextStyle(color: theme.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(16), vertical: r.s(8)),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) =>
                      _buildMessageBubble(_messages[i], theme, r),
                ),
        ),
        // Indicador de digitação
        if (_isSending) _buildTypingIndicator(theme, r),
        // Input
        _buildInput(theme, r),
      ],
    );
  }

  Widget _buildActiveBanner(dynamic theme, dynamic r) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.s(16), vertical: r.s(10)),
      decoration: BoxDecoration(
        color: theme.accentPrimary.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
              color: theme.accentPrimary.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: r.s(32),
            height: r.s(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [theme.accentPrimary, theme.accentSecondary],
              ),
            ),
            child: _activeCharacter?.avatarUrl != null
                ? ClipOval(
                    child: Image.network(_activeCharacter!.avatarUrl!,
                        fit: BoxFit.cover))
                : Icon(Icons.smart_toy_rounded,
                    color: Colors.white, size: r.s(18)),
          ),
          SizedBox(width: r.s(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activeCharacter?.name ?? '',
                  style: TextStyle(
                    color: theme.accentPrimary,
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Personagem ativo • As respostas são salvas no chat',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: r.fs(10),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: r.s(8),
            height: r.s(8),
            decoration: BoxDecoration(
              color: theme.success,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      RolePlayMessage msg, dynamic theme, dynamic r) {
    final isUser = msg.isUser;
    return Padding(
      padding: EdgeInsets.only(bottom: r.s(8)),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: r.s(28),
              height: r.s(28),
              margin: EdgeInsets.only(right: r.s(6)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [theme.accentPrimary, theme.accentSecondary],
                ),
              ),
              child: Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: r.s(14)),
            ),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(14), vertical: r.s(10)),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.accentPrimary
                    : theme.surfacePrimary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(r.s(16)),
                  topRight: Radius.circular(r.s(16)),
                  bottomLeft: Radius.circular(isUser ? r.s(16) : r.s(4)),
                  bottomRight: Radius.circular(isUser ? r.s(4) : r.s(16)),
                ),
              ),
              child: Text(
                msg.content,
                style: TextStyle(
                  color: isUser ? Colors.white : theme.textPrimary,
                  fontSize: r.fs(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(dynamic theme, dynamic r) {
    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(16), 0, r.s(16), r.s(4)),
      child: Row(
        children: [
          Container(
            width: r.s(28),
            height: r.s(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [theme.accentPrimary, theme.accentSecondary],
              ),
            ),
            child: Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: r.s(14)),
          ),
          SizedBox(width: r.s(8)),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: r.s(14), vertical: r.s(10)),
            decoration: BoxDecoration(
              color: theme.surfacePrimary,
              borderRadius: BorderRadius.circular(r.s(16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0, color: theme.textSecondary),
                SizedBox(width: r.s(4)),
                _Dot(delay: 200, color: theme.textSecondary),
                SizedBox(width: r.s(4)),
                _Dot(delay: 400, color: theme.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(dynamic theme, dynamic r) {
    return Container(
      padding: EdgeInsets.fromLTRB(r.s(12), r.s(8), r.s(12), r.s(12)),
      decoration: BoxDecoration(
        color: theme.surfacePrimary,
        border: Border(
          top: BorderSide(
              color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.backgroundPrimary,
                  borderRadius: BorderRadius.circular(r.s(24)),
                ),
                child: TextField(
                  controller: _chatController,
                  style: TextStyle(
                      color: theme.textPrimary, fontSize: r.fs(14)),
                  decoration: InputDecoration(
                    hintText:
                        'Fale com ${_activeCharacter?.name ?? 'o personagem'}...',
                    hintStyle: TextStyle(
                        color: theme.textSecondary, fontSize: r.fs(14)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: r.s(16), vertical: r.s(10)),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  enabled: !_isSending,
                ),
              ),
            ),
            SizedBox(width: r.s(8)),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: r.s(40),
                height: r.s(40),
                decoration: BoxDecoration(
                  color: _isSending
                      ? theme.textSecondary
                      : theme.accentPrimary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: r.s(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dot animado para indicador de digitação ───────────────────────────────────

class _Dot extends StatefulWidget {
  final int delay;
  final Color color;

  const _Dot({required this.delay, required this.color});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
