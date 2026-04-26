import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';
import 'cosmetic_avatar.dart';
import '../../config/nexus_theme_extension.dart';
import '../utils/responsive.dart';

/// Provider que busca usuários pelo prefixo de aminoId para autocomplete de menção.
final mentionSearchProvider =
    FutureProvider.family<List<UserModel>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final rows = await SupabaseService.table('profiles')
      .select('id, nickname, amino_id, icon_url, is_nickname_verified')
      .ilike('amino_id', '$query%')
      .limit(8);
  return (rows as List)
      .map((r) => UserModel.fromJson(r as Map<String, dynamic>))
      .toList();
});

/// Detecta se o texto atual contém uma query de menção ativa (ex: "@jo").
/// Retorna a query sem o "@" ou null se não há menção ativa.
String? detectMentionQuery(TextEditingController controller) {
  final text = controller.text;
  final cursor = controller.selection.baseOffset;
  if (cursor <= 0) return null;
  final before = text.substring(0, cursor);
  // Encontrar o último "@" antes do cursor que não seja precedido por letra/número
  final match = RegExp(r'(?:^|[\s\n])@(\w*)$').firstMatch(before);
  if (match == null) return null;
  return match.group(1) ?? '';
}

/// Insere a menção no controller, substituindo a query atual.
void insertMention(TextEditingController controller, String aminoId) {
  final text = controller.text;
  final cursor = controller.selection.baseOffset;
  if (cursor <= 0) return;
  final before = text.substring(0, cursor);
  final after = text.substring(cursor);
  // Substituir "@query" pela menção completa
  final newBefore = before.replaceFirstMapped(
    RegExp(r'@(\w*)$'),
    (_) => '@$aminoId ',
  );
  controller.value = TextEditingValue(
    text: newBefore + after,
    selection: TextSelection.collapsed(offset: newBefore.length),
  );
}

/// Widget de overlay de sugestões de menção.
/// Exibir acima do campo de texto quando há uma query ativa.
class MentionSuggestionList extends ConsumerWidget {
  final String query;
  final TextEditingController controller;
  final VoidCallback? onMentionInserted;

  const MentionSuggestionList({
    super.key,
    required this.query,
    required this.controller,
    this.onMentionInserted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final asyncUsers = ref.watch(mentionSearchProvider(query));

    return asyncUsers.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (users) {
        if (users.isEmpty) return const SizedBox.shrink();
        return Container(
          constraints: BoxConstraints(maxHeight: r.s(220)),
          decoration: BoxDecoration(
            color: context.nexusTheme.backgroundSecondary,
            borderRadius: BorderRadius.circular(r.s(12)),
            border: Border.all(
              color: context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(vertical: r.s(4)),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return InkWell(
                onTap: () {
                  insertMention(controller, user.aminoId);
                  onMentionInserted?.call();
                },
                borderRadius: BorderRadius.circular(r.s(8)),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.s(12),
                    vertical: r.s(8),
                  ),
                  child: Row(
                    children: [
                      CosmeticAvatar(
                        userId: user.id,
                        avatarUrl: user.iconUrl,
                        size: r.s(32),
                      ),
                      SizedBox(width: r.s(10)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.nickname,
                                    style: TextStyle(
                                      color: context.nexusTheme.textPrimary,
                                      fontSize: r.fs(13),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (user.isNicknameVerified) ...[
                                  SizedBox(width: r.s(4)),
                                  Icon(
                                    Icons.verified_rounded,
                                    size: r.s(13),
                                    color: context.nexusTheme.accentSecondary,
                                  ),
                                ],
                              ],
                            ),
                            if (user.aminoId.isNotEmpty)
                              Text(
                                '@${user.aminoId}',
                                style: TextStyle(
                                  color: context.nexusTheme.accentPrimary,
                                  fontSize: r.fs(11),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Mixin para adicionar suporte a menções em um State com TextEditingController.
/// Uso:
///   1. Adicionar `with MentionMixin` no State
///   2. Chamar `initMention(controller)` no initState
///   3. Chamar `onTextChangedMention(value)` no onChanged do TextField
///   4. Renderizar `buildMentionOverlay()` acima do campo de texto
///   5. Chamar `disposeMention()` no dispose
mixin MentionMixin<T extends StatefulWidget> on State<T> {
  String? _mentionQuery;
  TextEditingController? _mentionController;

  String? get mentionQuery => _mentionQuery;

  void initMention(TextEditingController controller) {
    _mentionController = controller;
    controller.addListener(_onMentionControllerChanged);
  }

  void _onMentionControllerChanged() {
    if (_mentionController == null) return;
    final query = detectMentionQuery(_mentionController!);
    if (query != _mentionQuery) {
      setState(() => _mentionQuery = query);
    }
  }

  void onMentionInserted() {
    setState(() => _mentionQuery = null);
  }

  void disposeMention() {
    _mentionController?.removeListener(_onMentionControllerChanged);
  }
}
