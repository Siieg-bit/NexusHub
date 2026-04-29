import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import 'package:amino_clone/core/services/supabase_service.dart';
import 'package:amino_clone/core/utils/responsive.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final chatRpgCharacterProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, threadId) async {
  final res = await SupabaseService.rpc(
    'get_chat_rpg_character',
    params: {'p_thread_id': threadId},
  );
  return (res as Map<String, dynamic>?) ?? {'found': false};
});

final chatRpgRankingProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, threadId) async {
  final res = await SupabaseService.rpc(
    'get_chat_rpg_ranking',
    params: {'p_thread_id': threadId, 'p_limit': 20},
  );
  return (res as List?)?.cast<Map<String, dynamic>>() ?? [];
});

final chatRpgShopProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, threadId) async {
  final res = await SupabaseService.client
      .from('chat_rpg_items')
      .select('*')
      .eq('thread_id', threadId)
      .eq('is_available', true)
      .order('rarity')
      .order('price');
  return (res as List).cast<Map<String, dynamic>>();
});

final chatRpgClassesForPickerProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, threadId) async {
  final res = await SupabaseService.client
      .from('chat_rpg_classes')
      .select('*')
      .eq('thread_id', threadId)
      .eq('is_active', true)
      .order('sort_order');
  return (res as List).cast<Map<String, dynamic>>();
});

// ── Tela Principal ─────────────────────────────────────────────────────────────

class ChatRpgScreen extends ConsumerStatefulWidget {
  final String threadId;

  const ChatRpgScreen({super.key, required this.threadId});

  @override
  ConsumerState<ChatRpgScreen> createState() => _ChatRpgScreenState();
}

class _ChatRpgScreenState extends ConsumerState<ChatRpgScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final charAsync = ref.watch(chatRpgCharacterProvider(widget.threadId));

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        title: Row(
          children: [
            Icon(Icons.shield_rounded,
                color: context.nexusTheme.accentPrimary, size: r.s(20)),
            SizedBox(width: r.s(8)),
            Text('Modo RPG',
                style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(18))),
          ],
        ),
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.nexusTheme.accentPrimary,
          unselectedLabelColor: context.nexusTheme.textHint,
          indicatorColor: context.nexusTheme.accentPrimary,
          dividerColor: Colors.transparent,
          isScrollable: false,
          tabs: const [
            Tab(icon: Icon(Icons.person_rounded, size: 20)),
            Tab(icon: Icon(Icons.inventory_2_rounded, size: 20)),
            Tab(icon: Icon(Icons.storefront_rounded, size: 20)),
            Tab(icon: Icon(Icons.leaderboard_rounded, size: 20)),
          ],
        ),
      ),
      body: charAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (data) {
          final found = data['found'] as bool? ?? false;
          if (!found) {
            return _buildCreateCharacter(r);
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _CharacterTab(
                  threadId: widget.threadId, charData: data),
              _InventoryTab(
                  threadId: widget.threadId, charData: data),
              _ShopTab(threadId: widget.threadId, charData: data),
              _RankingTab(threadId: widget.threadId),
            ],
          );
        },
      ),
    );
  }

  // ── Criar Personagem ──────────────────────────────────────────────────────────
  Widget _buildCreateCharacter(Responsive r) {
    final nameCtrl = TextEditingController();
    final bioCtrl = TextEditingController();
    String? selectedClassId;
    final classesAsync =
        ref.watch(chatRpgClassesForPickerProvider(widget.threadId));

    return StatefulBuilder(
      builder: (context, setS) => SingleChildScrollView(
        padding: EdgeInsets.all(r.s(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: r.s(80),
                    height: r.s(80),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.nexusTheme.accentPrimary,
                          context.nexusTheme.accentPrimary
                              .withValues(alpha: 0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shield_rounded,
                        color: Colors.white, size: r.s(40)),
                  ),
                  SizedBox(height: r.s(12)),
                  Text('Criar seu Personagem',
                      style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: r.fs(20))),
                  SizedBox(height: r.s(4)),
                  Text('Escolha uma classe e dê vida ao seu herói!',
                      style: TextStyle(
                          color: context.nexusTheme.textSecondary,
                          fontSize: r.fs(13))),
                ],
              ),
            ),
            SizedBox(height: r.s(28)),

            // Nome
            _inputLabel(r, 'Nome do Personagem'),
            SizedBox(height: r.s(6)),
            _textField(r, controller: nameCtrl, hint: 'Ex: Aldric, Lyra...'),
            SizedBox(height: r.s(16)),

            // Bio
            _inputLabel(r, 'Biografia (opcional)'),
            SizedBox(height: r.s(6)),
            _textField(r,
                controller: bioCtrl,
                hint: 'Conte a história do seu personagem...',
                maxLines: 3),
            SizedBox(height: r.s(16)),

            // Escolha de Classe
            _inputLabel(r, 'Escolha uma Classe'),
            SizedBox(height: r.s(10)),
            classesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erro ao carregar classes',
                  style: TextStyle(color: context.nexusTheme.textHint)),
              data: (classes) {
                if (classes.isEmpty) {
                  return Container(
                    padding: EdgeInsets.all(r.s(12)),
                    decoration: BoxDecoration(
                      color: context.nexusTheme.backgroundSecondary,
                      borderRadius: BorderRadius.circular(r.s(12)),
                    ),
                    child: Text(
                        'Nenhuma classe disponível. O host ainda não configurou as classes.',
                        style: TextStyle(
                            color: context.nexusTheme.textSecondary,
                            fontSize: r.fs(13))),
                  );
                }
                return Column(
                  children: classes.map((cls) {
                    final isSelected = selectedClassId == cls['id'];
                    final color = _parseColor(
                        cls['color'] as String? ?? '#7C4DFF');
                    return GestureDetector(
                      onTap: () =>
                          setS(() => selectedClassId = cls['id'] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(bottom: r.s(8)),
                        padding: EdgeInsets.all(r.s(14)),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.15)
                              : context.nexusTheme.backgroundSecondary,
                          borderRadius: BorderRadius.circular(r.s(12)),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: r.s(44),
                              height: r.s(44),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(r.s(10)),
                              ),
                              child: Center(
                                child: Text(
                                  cls['icon_url'] as String? ?? '⚔️',
                                  style: TextStyle(fontSize: r.fs(22)),
                                ),
                              ),
                            ),
                            SizedBox(width: r.s(12)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cls['name'] as String? ?? '',
                                      style: TextStyle(
                                          color: isSelected
                                              ? color
                                              : context.nexusTheme.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: r.fs(15))),
                                  if (cls['description'] != null)
                                    Text(cls['description'] as String,
                                        style: TextStyle(
                                            color: context
                                                .nexusTheme.textSecondary,
                                            fontSize: r.fs(12)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded,
                                  color: color, size: r.s(22)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            SizedBox(height: r.s(24)),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Digite o nome do personagem.')));
                    return;
                  }
                  try {
                    final res = await SupabaseService.rpc(
                      'create_or_update_chat_rpg_character',
                      params: {
                        'p_thread_id': widget.threadId,
                        'p_name': name,
                        if (selectedClassId != null)
                          'p_class_id': selectedClassId,
                        'p_bio': bioCtrl.text.trim(),
                      },
                    );
                    if (res?['success'] == true && mounted) {
                      ref.invalidate(
                          chatRpgCharacterProvider(widget.threadId));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Erro: $e')));
                    }
                  }
                },
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Criar Personagem'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.nexusTheme.accentPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(14))),
                  padding: EdgeInsets.symmetric(vertical: r.s(16)),
                  textStyle: TextStyle(
                      fontSize: r.fs(15), fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputLabel(Responsive r, String label) {
    return Text(label,
        style: TextStyle(
            color: context.nexusTheme.textSecondary,
            fontSize: r.fs(12),
            fontWeight: FontWeight.w600));
  }

  Widget _textField(Responsive r,
      {required TextEditingController controller,
      required String hint,
      int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
          color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: context.nexusTheme.textHint, fontSize: r.fs(14)),
        filled: true,
        fillColor: context.nexusTheme.backgroundSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(10)),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(12)),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF7C4DFF);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA: Ficha do Personagem
// ═══════════════════════════════════════════════════════════════════════════════

class _CharacterTab extends ConsumerWidget {
  final String threadId;
  final Map<String, dynamic> charData;

  const _CharacterTab({required this.threadId, required this.charData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final char = charData['character'] as Map<String, dynamic>? ?? {};
    final cls = charData['class'] as Map<String, dynamic>?;
    final config = charData['thread_config'] as Map<String, dynamic>? ?? {};

    final level = char['level'] as int? ?? 1;
    final xp = char['xp'] as int? ?? 0;
    final currency = char['currency_balance'] as int? ?? 0;
    final currencyName = config['rpg_currency_name'] as String? ?? 'Ouro';
    final charStatus = char['char_status'] as String? ?? 'alive';

    // XP para próximo nível: (level)^2 * 100
    final xpForNext = level * level * 100;
    final xpProgress = xpForNext > 0 ? (xp % xpForNext) / xpForNext : 0.0;

    final classColor = cls != null
        ? _parseColor(cls['color'] as String? ?? '#7C4DFF')
        : context.nexusTheme.accentPrimary;

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.s(16)),
      child: Column(
        children: [
          // ── Card Principal ───────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(r.s(20)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  classColor.withValues(alpha: 0.25),
                  classColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(r.s(20)),
              border: Border.all(color: classColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                // Avatar + Nome
                Row(
                  children: [
                    Container(
                      width: r.s(64),
                      height: r.s(64),
                      decoration: BoxDecoration(
                        color: classColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: classColor, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          cls?['icon_url'] as String? ?? '⚔️',
                          style: TextStyle(fontSize: r.fs(28)),
                        ),
                      ),
                    ),
                    SizedBox(width: r.s(14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  char['name'] as String? ?? 'Personagem',
                                  style: TextStyle(
                                      color: context.nexusTheme.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: r.fs(18)),
                                ),
                              ),
                              if (charStatus == 'dead')
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(8), vertical: r.s(3)),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.2),
                                    borderRadius:
                                        BorderRadius.circular(r.s(6)),
                                  ),
                                  child: Text('💀 Morto',
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontSize: r.fs(11),
                                          fontWeight: FontWeight.w700)),
                                ),
                            ],
                          ),
                          if (cls != null)
                            Container(
                              margin: EdgeInsets.only(top: r.s(4)),
                              padding: EdgeInsets.symmetric(
                                  horizontal: r.s(8), vertical: r.s(3)),
                              decoration: BoxDecoration(
                                color: classColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(r.s(6)),
                              ),
                              child: Text(cls['name'] as String? ?? '',
                                  style: TextStyle(
                                      color: classColor,
                                      fontSize: r.fs(12),
                                      fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.s(16)),

                // Nível + XP
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(12), vertical: r.s(6)),
                      decoration: BoxDecoration(
                        color: classColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(r.s(8)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              color: classColor, size: r.s(16)),
                          SizedBox(width: r.s(4)),
                          Text('Nível $level',
                              style: TextStyle(
                                  color: classColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: r.fs(14))),
                        ],
                      ),
                    ),
                    SizedBox(width: r.s(10)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('XP',
                                  style: TextStyle(
                                      color: context.nexusTheme.textSecondary,
                                      fontSize: r.fs(11))),
                              Text('$xp / $xpForNext',
                                  style: TextStyle(
                                      color: context.nexusTheme.textSecondary,
                                      fontSize: r.fs(11))),
                            ],
                          ),
                          SizedBox(height: r.s(4)),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(r.s(4)),
                            child: LinearProgressIndicator(
                              value: xpProgress.clamp(0.0, 1.0),
                              backgroundColor:
                                  classColor.withValues(alpha: 0.15),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(classColor),
                              minHeight: r.s(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.s(14)),

                // Moeda
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(14), vertical: r.s(10)),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(r.s(10)),
                    border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Text('💰', style: TextStyle(fontSize: r.fs(18))),
                      SizedBox(width: r.s(8)),
                      Text('$currency $currencyName',
                          style: TextStyle(
                              color: const Color(0xFFFFD700),
                              fontWeight: FontWeight.w700,
                              fontSize: r.fs(15))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.s(16)),

          // Bio
          if ((char['bio'] as String?)?.isNotEmpty == true) ...[
            _sectionCard(
              r,
              context,
              title: 'Biografia',
              icon: Icons.menu_book_rounded,
              child: Text(
                char['bio'] as String,
                style: TextStyle(
                    color: context.nexusTheme.textSecondary,
                    fontSize: r.fs(13),
                    height: 1.5),
              ),
            ),
            SizedBox(height: r.s(12)),
          ],

          // Atributos
          if ((char['attributes'] as Map?)?.isNotEmpty == true) ...[
            _sectionCard(
              r,
              context,
              title: 'Atributos',
              icon: Icons.bar_chart_rounded,
              child: _buildAttributes(r, context,
                  char['attributes'] as Map<String, dynamic>),
            ),
            SizedBox(height: r.s(12)),
          ],

          // Botão editar
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showEditSheet(context, ref, r, char, cls),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Editar Personagem'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.nexusTheme.accentPrimary,
                side: BorderSide(
                    color: context.nexusTheme.accentPrimary
                        .withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(12))),
                padding: EdgeInsets.symmetric(vertical: r.s(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributes(Responsive r, BuildContext context,
      Map<String, dynamic> attributes) {
    final entries = attributes.entries.toList();
    return Wrap(
      spacing: r.s(8),
      runSpacing: r.s(8),
      children: entries.map((e) {
        return Container(
          padding: EdgeInsets.symmetric(
              horizontal: r.s(10), vertical: r.s(6)),
          decoration: BoxDecoration(
            color: context.nexusTheme.backgroundPrimary,
            borderRadius: BorderRadius.circular(r.s(8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.key,
                  style: TextStyle(
                      color: context.nexusTheme.textSecondary,
                      fontSize: r.fs(12))),
              SizedBox(width: r.s(6)),
              Text(e.value.toString(),
                  style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(13))),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, Responsive r,
      Map<String, dynamic> char, Map<String, dynamic>? cls) {
    final nameCtrl =
        TextEditingController(text: char['name'] as String? ?? '');
    final bioCtrl =
        TextEditingController(text: char['bio'] as String? ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.nexusTheme.backgroundSecondary,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: r.s(16),
            right: r.s(16),
            top: r.s(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Editar Personagem',
                style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(18))),
            SizedBox(height: r.s(16)),
            TextField(
              controller: nameCtrl,
              style: TextStyle(
                  color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
              decoration: InputDecoration(
                labelText: 'Nome',
                labelStyle:
                    TextStyle(color: context.nexusTheme.textSecondary),
                filled: true,
                fillColor: context.nexusTheme.backgroundPrimary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: r.s(12)),
            TextField(
              controller: bioCtrl,
              maxLines: 3,
              style: TextStyle(
                  color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
              decoration: InputDecoration(
                labelText: 'Biografia',
                labelStyle:
                    TextStyle(color: context.nexusTheme.textSecondary),
                filled: true,
                fillColor: context.nexusTheme.backgroundPrimary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: r.s(20)),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await SupabaseService.rpc(
                      'create_or_update_chat_rpg_character',
                      params: {
                        'p_thread_id': threadId,
                        'p_name': nameCtrl.text.trim(),
                        'p_bio': bioCtrl.text.trim(),
                      },
                    );
                    ref.invalidate(chatRpgCharacterProvider(threadId));
                  } catch (e) {
                    debugPrint('[RPG] edit char: $e');
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: context.nexusTheme.accentPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(12))),
                  padding: EdgeInsets.symmetric(vertical: r.s(14)),
                ),
                child: const Text('Salvar'),
              ),
            ),
            SizedBox(height: r.s(16)),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(Responsive r, BuildContext context,
      {required String title,
      required IconData icon,
      required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: context.nexusTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(r.s(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  color: context.nexusTheme.accentPrimary, size: r.s(16)),
              SizedBox(width: r.s(6)),
              Text(title,
                  style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(14))),
            ],
          ),
          SizedBox(height: r.s(10)),
          child,
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF7C4DFF);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA: Inventário
// ═══════════════════════════════════════════════════════════════════════════════

class _InventoryTab extends ConsumerWidget {
  final String threadId;
  final Map<String, dynamic> charData;

  const _InventoryTab({required this.threadId, required this.charData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final inventory =
        (charData['inventory'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (inventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_rounded,
                color: context.nexusTheme.textHint, size: r.s(56)),
            SizedBox(height: r.s(12)),
            Text('Inventário vazio',
                style: TextStyle(
                    color: context.nexusTheme.textSecondary,
                    fontSize: r.fs(16),
                    fontWeight: FontWeight.w600)),
            SizedBox(height: r.s(4)),
            Text('Compre itens na loja para equipar seu personagem.',
                style: TextStyle(
                    color: context.nexusTheme.textHint, fontSize: r.fs(13))),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(r.s(12)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: r.s(10),
        mainAxisSpacing: r.s(10),
        childAspectRatio: 1.1,
      ),
      itemCount: inventory.length,
      itemBuilder: (context, i) {
        final inv = inventory[i];
        final item = inv['item'] as Map<String, dynamic>? ?? {};
        final rarity = item['rarity'] as String? ?? 'common';
        final rarityColor = _rarityColor(rarity);
        final isEquipped = inv['is_equipped'] as bool? ?? false;

        return GestureDetector(
          onTap: () => _toggleEquip(context, ref, r,
              inv['inventory_id'] as String? ?? '', item, isEquipped),
          child: Container(
            padding: EdgeInsets.all(r.s(12)),
            decoration: BoxDecoration(
              color: context.nexusTheme.backgroundSecondary,
              borderRadius: BorderRadius.circular(r.s(14)),
              border: Border.all(
                color: isEquipped
                    ? rarityColor
                    : rarityColor.withValues(alpha: 0.2),
                width: isEquipped ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(r.s(8)),
                      decoration: BoxDecoration(
                        color: rarityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(r.s(8)),
                      ),
                      child: Icon(
                        _itemTypeIcon(item['item_type'] as String? ?? 'consumable'),
                        color: rarityColor,
                        size: r.s(20),
                      ),
                    ),
                    const Spacer(),
                    if (isEquipped)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(6), vertical: r.s(2)),
                        decoration: BoxDecoration(
                          color: rarityColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(r.s(4)),
                        ),
                        child: Text('Equipado',
                            style: TextStyle(
                                color: rarityColor,
                                fontSize: r.fs(9),
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const Spacer(),
                Text(item['name'] as String? ?? '',
                    style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(13)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: r.s(2)),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(5), vertical: r.s(2)),
                      decoration: BoxDecoration(
                        color: rarityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(r.s(4)),
                      ),
                      child: Text(_rarityLabel(rarity),
                          style: TextStyle(
                              color: rarityColor,
                              fontSize: r.fs(9),
                              fontWeight: FontWeight.w700)),
                    ),
                    const Spacer(),
                    Text('x${inv['quantity'] ?? 1}',
                        style: TextStyle(
                            color: context.nexusTheme.textHint,
                            fontSize: r.fs(12))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleEquip(BuildContext context, WidgetRef ref, Responsive r,
      String invId, Map<String, dynamic> item, bool isEquipped) async {
    try {
      await SupabaseService.rpc('toggle_equip_chat_rpg_item', params: {
        'p_thread_id': threadId,
        'p_item_id': item['id'] as String,
      });
      ref.invalidate(chatRpgCharacterProvider(threadId));
    } catch (e) {
      debugPrint('[RPG] toggle equip: $e');
    }
  }

  Color _rarityColor(String rarity) {
    return switch (rarity) {
      'uncommon' => const Color(0xFF4CAF50),
      'rare' => const Color(0xFF2196F3),
      'epic' => const Color(0xFF9C27B0),
      'legendary' => const Color(0xFFFF9800),
      _ => const Color(0xFF9E9E9E),
    };
  }

  String _rarityLabel(String rarity) {
    return switch (rarity) {
      'uncommon' => 'Incomum',
      'rare' => 'Raro',
      'epic' => 'Épico',
      'legendary' => 'Lendário',
      _ => 'Comum',
    };
  }

  IconData _itemTypeIcon(String type) {
    return switch (type) {
      'weapon' => Icons.gavel_rounded,
      'armor' => Icons.shield_rounded,
      'accessory' => Icons.auto_awesome_rounded,
      'quest_item' => Icons.star_rounded,
      _ => Icons.science_rounded,
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA: Loja
// ═══════════════════════════════════════════════════════════════════════════════

class _ShopTab extends ConsumerStatefulWidget {
  final String threadId;
  final Map<String, dynamic> charData;

  const _ShopTab({required this.threadId, required this.charData});

  @override
  ConsumerState<_ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends ConsumerState<_ShopTab> {
  bool _isBuying = false;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final shopAsync = ref.watch(chatRpgShopProvider(widget.threadId));
    final char = widget.charData['character'] as Map<String, dynamic>? ?? {};
    final config =
        widget.charData['thread_config'] as Map<String, dynamic>? ?? {};
    final balance = char['currency_balance'] as int? ?? 0;
    final currencyName = config['rpg_currency_name'] as String? ?? 'Ouro';

    return Column(
      children: [
        // Saldo
        Container(
          margin: EdgeInsets.all(r.s(12)),
          padding: EdgeInsets.symmetric(
              horizontal: r.s(16), vertical: r.s(10)),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(r.s(12)),
            border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Text('💰', style: TextStyle(fontSize: r.fs(20))),
              SizedBox(width: r.s(8)),
              Text('Saldo: $balance $currencyName',
                  style: TextStyle(
                      color: const Color(0xFFFFD700),
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(15))),
            ],
          ),
        ),
        Expanded(
          child: shopAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_rounded,
                          color: context.nexusTheme.textHint, size: r.s(56)),
                      SizedBox(height: r.s(12)),
                      Text('Loja vazia',
                          style: TextStyle(
                              color: context.nexusTheme.textSecondary,
                              fontSize: r.fs(16))),
                      SizedBox(height: r.s(4)),
                      Text('O host ainda não adicionou itens.',
                          style: TextStyle(
                              color: context.nexusTheme.textHint,
                              fontSize: r.fs(13))),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: r.s(12)),
                itemCount: items.length,
                separatorBuilder: (_, __) => SizedBox(height: r.s(8)),
                itemBuilder: (context, i) {
                  final item = items[i];
                  final rarity =
                      item['rarity'] as String? ?? 'common';
                  final rarityColor = _rarityColor(rarity);
                  final price = item['price'] as int? ?? 0;
                  final canAfford = balance >= price;

                  return Container(
                    padding: EdgeInsets.all(r.s(12)),
                    decoration: BoxDecoration(
                      color: context.nexusTheme.backgroundSecondary,
                      borderRadius: BorderRadius.circular(r.s(14)),
                      border: Border.all(
                          color: rarityColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: r.s(48),
                          height: r.s(48),
                          decoration: BoxDecoration(
                            color: rarityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(r.s(10)),
                          ),
                          child: Center(
                            child: Icon(
                              _itemTypeIcon(
                                  item['item_type'] as String? ??
                                      'consumable'),
                              color: rarityColor,
                              size: r.s(24),
                            ),
                          ),
                        ),
                        SizedBox(width: r.s(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                        item['name'] as String? ?? '',
                                        style: TextStyle(
                                            color: context
                                                .nexusTheme.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: r.fs(14))),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: r.s(6),
                                        vertical: r.s(2)),
                                    decoration: BoxDecoration(
                                      color: rarityColor
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(r.s(4)),
                                    ),
                                    child: Text(_rarityLabel(rarity),
                                        style: TextStyle(
                                            color: rarityColor,
                                            fontSize: r.fs(10),
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                              if ((item['description'] as String?)
                                      ?.isNotEmpty ==
                                  true)
                                Text(item['description'] as String,
                                    style: TextStyle(
                                        color: context
                                            .nexusTheme.textSecondary,
                                        fontSize: r.fs(12)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              SizedBox(height: r.s(4)),
                              Row(
                                children: [
                                  Text('💰 $price $currencyName',
                                      style: TextStyle(
                                          color: canAfford
                                              ? const Color(0xFFFFD700)
                                              : context
                                                  .nexusTheme.textHint,
                                          fontWeight: FontWeight.w700,
                                          fontSize: r.fs(13))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: r.s(8)),
                        FilledButton(
                          onPressed: (_isBuying || !canAfford)
                              ? null
                              : () => _buyItem(context, item, currencyName),
                          style: FilledButton.styleFrom(
                            backgroundColor: canAfford
                                ? rarityColor
                                : context.nexusTheme.textHint
                                    .withValues(alpha: 0.3),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(r.s(10))),
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(12), vertical: r.s(8)),
                            textStyle: TextStyle(
                                fontSize: r.fs(12),
                                fontWeight: FontWeight.w700),
                          ),
                          child: const Text('Comprar'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _buyItem(BuildContext context, Map<String, dynamic> item,
      String currencyName) async {
    final r = context.r;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nexusTheme.backgroundSecondary,
        title: Text('Comprar Item',
            style: TextStyle(color: context.nexusTheme.textPrimary)),
        content: Text(
            'Comprar "${item['name']}" por ${item['price']} $currencyName?',
            style: TextStyle(color: context.nexusTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Comprar')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isBuying = true);
    try {
      final res = await SupabaseService.rpc('buy_chat_rpg_item', params: {
        'p_thread_id': widget.threadId,
        'p_item_id': item['id'] as String,
        'p_quantity': 1,
      });
      if (res?['success'] == true && mounted) {
        ref.invalidate(chatRpgCharacterProvider(widget.threadId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ "${item['name']}" adquirido!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.nexusTheme.accentPrimary,
        ));
      } else if (mounted) {
        final err = res?['error'] as String? ?? 'erro';
        final msg = switch (err) {
          'insufficient_funds' => 'Saldo insuficiente!',
          'stack_full' => 'Inventário cheio para este item.',
          _ => 'Erro ao comprar: $err',
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erro ao processar compra.'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isBuying = false);
    }
  }

  Color _rarityColor(String rarity) {
    return switch (rarity) {
      'uncommon' => const Color(0xFF4CAF50),
      'rare' => const Color(0xFF2196F3),
      'epic' => const Color(0xFF9C27B0),
      'legendary' => const Color(0xFFFF9800),
      _ => const Color(0xFF9E9E9E),
    };
  }

  String _rarityLabel(String rarity) {
    return switch (rarity) {
      'uncommon' => 'Incomum',
      'rare' => 'Raro',
      'epic' => 'Épico',
      'legendary' => 'Lendário',
      _ => 'Comum',
    };
  }

  IconData _itemTypeIcon(String type) {
    return switch (type) {
      'weapon' => Icons.gavel_rounded,
      'armor' => Icons.shield_rounded,
      'accessory' => Icons.auto_awesome_rounded,
      'quest_item' => Icons.star_rounded,
      _ => Icons.science_rounded,
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA: Ranking
// ═══════════════════════════════════════════════════════════════════════════════

class _RankingTab extends ConsumerWidget {
  final String threadId;

  const _RankingTab({required this.threadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final rankingAsync = ref.watch(chatRpgRankingProvider(threadId));

    return rankingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (ranking) {
        if (ranking.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.leaderboard_rounded,
                    color: context.nexusTheme.textHint, size: r.s(56)),
                SizedBox(height: r.s(12)),
                Text('Sem dados ainda',
                    style: TextStyle(
                        color: context.nexusTheme.textSecondary,
                        fontSize: r.fs(16))),
                SizedBox(height: r.s(4)),
                Text('Os jogadores precisam criar personagens.',
                    style: TextStyle(
                        color: context.nexusTheme.textHint,
                        fontSize: r.fs(13))),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(r.s(12)),
          itemCount: ranking.length,
          separatorBuilder: (_, __) => SizedBox(height: r.s(6)),
          itemBuilder: (context, i) {
            final entry = ranking[i];
            final rank = entry['rank'] as int? ?? (i + 1);
            final classColor = _parseColor(
                entry['class_color'] as String? ?? '#7C4DFF');
            final isTop3 = rank <= 3;

            return Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(14), vertical: r.s(10)),
              decoration: BoxDecoration(
                color: isTop3
                    ? _podiumColor(rank).withValues(alpha: 0.08)
                    : context.nexusTheme.backgroundSecondary,
                borderRadius: BorderRadius.circular(r.s(12)),
                border: isTop3
                    ? Border.all(
                        color: _podiumColor(rank).withValues(alpha: 0.3))
                    : null,
              ),
              child: Row(
                children: [
                  // Rank
                  SizedBox(
                    width: r.s(32),
                    child: isTop3
                        ? Text(_podiumEmoji(rank),
                            style: TextStyle(fontSize: r.fs(20)),
                            textAlign: TextAlign.center)
                        : Text('#$rank',
                            style: TextStyle(
                                color: context.nexusTheme.textHint,
                                fontWeight: FontWeight.w700,
                                fontSize: r.fs(13)),
                            textAlign: TextAlign.center),
                  ),
                  SizedBox(width: r.s(10)),
                  // Avatar
                  Container(
                    width: r.s(40),
                    height: r.s(40),
                    decoration: BoxDecoration(
                      color: classColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: classColor.withValues(alpha: 0.5)),
                    ),
                    child: Center(
                      child: Text(
                        entry['avatar_url'] as String? ?? '⚔️',
                        style: TextStyle(fontSize: r.fs(18)),
                      ),
                    ),
                  ),
                  SizedBox(width: r.s(10)),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            entry['character_name'] as String? ??
                                'Personagem',
                            style: TextStyle(
                                color: context.nexusTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: r.fs(14))),
                        if ((entry['class_name'] as String?) != null)
                          Text(entry['class_name'] as String,
                              style: TextStyle(
                                  color: classColor,
                                  fontSize: r.fs(11),
                                  fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  // Nível + XP
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(8), vertical: r.s(3)),
                        decoration: BoxDecoration(
                          color: classColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(r.s(6)),
                        ),
                        child: Text('Nv. ${entry['level'] ?? 1}',
                            style: TextStyle(
                                color: classColor,
                                fontWeight: FontWeight.w800,
                                fontSize: r.fs(12))),
                      ),
                      SizedBox(height: r.s(2)),
                      Text('${entry['xp'] ?? 0} XP',
                          style: TextStyle(
                              color: context.nexusTheme.textHint,
                              fontSize: r.fs(11))),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _podiumColor(int rank) {
    return switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => const Color(0xFF9E9E9E),
    };
  }

  String _podiumEmoji(int rank) {
    return switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '#$rank',
    };
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF7C4DFF);
    }
  }
}
