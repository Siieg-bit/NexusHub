import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import 'package:amino_clone/core/services/supabase_service.dart';
import 'package:amino_clone/core/utils/responsive.dart';
import '../../../core/widgets/rgb_color_picker.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final chatRpgConfigProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, threadId) async {
  final res = await SupabaseService.client
      .from('chat_threads')
      .select('rpg_mode_enabled, rpg_currency_name, rpg_currency_icon, rpg_xp_multiplier')
      .eq('id', threadId)
      .single();
  return res as Map<String, dynamic>;
});

final chatRpgClassesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, threadId) async {
  final res = await SupabaseService.client
      .from('chat_rpg_classes')
      .select('*')
      .eq('thread_id', threadId)
      .eq('is_active', true)
      .order('sort_order');
  return (res as List).cast<Map<String, dynamic>>();
});

final chatRpgItemsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, threadId) async {
  final res = await SupabaseService.client
      .from('chat_rpg_items')
      .select('*')
      .eq('thread_id', threadId)
      .order('rarity')
      .order('name');
  return (res as List).cast<Map<String, dynamic>>();
});

// ── Tela Principal ─────────────────────────────────────────────────────────────

class ChatRpgAdminScreen extends ConsumerStatefulWidget {
  final String threadId;

  const ChatRpgAdminScreen({super.key, required this.threadId});

  @override
  ConsumerState<ChatRpgAdminScreen> createState() => _ChatRpgAdminScreenState();
}

class _ChatRpgAdminScreenState extends ConsumerState<ChatRpgAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _rpgEnabled = false;
  bool _isSaving = false;
  final _currencyNameCtrl = TextEditingController();
  final _xpMultiplierCtrl = TextEditingController(text: '1.0');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _currencyNameCtrl.dispose();
    _xpMultiplierCtrl.dispose();
    super.dispose();
  }

  void _applyConfig(Map<String, dynamic> config) {
    _rpgEnabled = config['rpg_mode_enabled'] as bool? ?? false;
    _currencyNameCtrl.text = config['rpg_currency_name'] as String? ?? 'Ouro';
    _xpMultiplierCtrl.text =
        (config['rpg_xp_multiplier'] as num? ?? 1.0).toStringAsFixed(1);
  }

  Future<void> _toggleRpgMode(bool value) async {
    setState(() => _isSaving = true);
    try {
      final res = await SupabaseService.rpc('toggle_chat_rpg_mode', params: {
        'p_thread_id': widget.threadId,
        'p_enabled': value,
      });
      if (res?['success'] == true && mounted) {
        setState(() => _rpgEnabled = value);
        ref.invalidate(chatRpgConfigProvider(widget.threadId));
        _showSnack(value ? '⚔️ Modo RPG ativado!' : 'Modo RPG desativado.');
      } else {
        _showSnack('Erro: ${res?['error'] ?? 'desconhecido'}', isError: true);
      }
    } catch (e) {
      _showSnack('Erro ao alterar modo RPG.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveGeneralConfig() async {
    setState(() => _isSaving = true);
    try {
      final multiplier = double.tryParse(_xpMultiplierCtrl.text) ?? 1.0;
      final res = await SupabaseService.rpc('configure_chat_rpg', params: {
        'p_thread_id': widget.threadId,
        'p_currency_name': _currencyNameCtrl.text.trim(),
        'p_xp_multiplier': multiplier,
      });
      if (res?['success'] == true && mounted) {
        ref.invalidate(chatRpgConfigProvider(widget.threadId));
        _showSnack('Configurações salvas!');
      }
    } catch (e) {
      _showSnack('Erro ao salvar configurações.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : context.nexusTheme.accentPrimary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final configAsync = ref.watch(chatRpgConfigProvider(widget.threadId));

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        title: Text('Painel RPG',
            style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: r.fs(18))),
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.nexusTheme.accentPrimary,
          unselectedLabelColor: context.nexusTheme.textHint,
          indicatorColor: context.nexusTheme.accentPrimary,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Geral'),
            Tab(text: 'Classes'),
            Tab(text: 'Itens'),
          ],
        ),
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (config) {
          // Aplica os valores carregados apenas na primeira vez
          if (_currencyNameCtrl.text.isEmpty ||
              _currencyNameCtrl.text == 'Ouro' &&
                  config['rpg_currency_name'] != 'Ouro') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _applyConfig(config);
            });
          }
          _rpgEnabled = config['rpg_mode_enabled'] as bool? ?? _rpgEnabled;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildGeneralTab(r, config),
              _buildClassesTab(r),
              _buildItemsTab(r),
            ],
          );
        },
      ),
    );
  }

  // ── ABA: Geral ───────────────────────────────────────────────────────────────
  Widget _buildGeneralTab(Responsive r, Map<String, dynamic> config) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(r.s(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card: Ativar/Desativar
          _card(
            r,
            child: SwitchListTile(
              value: _rpgEnabled,
              onChanged: _isSaving ? null : _toggleRpgMode,
              activeColor: context.nexusTheme.accentPrimary,
              title: Text('Modo RPG',
                  style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(15))),
              subtitle: Text(
                _rpgEnabled
                    ? 'O modo RPG está ativo neste chat. Os membros podem criar personagens.'
                    : 'Ative para transformar este chat em uma sala de RPG gamificada.',
                style: TextStyle(
                    color: context.nexusTheme.textSecondary,
                    fontSize: r.fs(12)),
              ),
              secondary: Container(
                width: r.s(40),
                height: r.s(40),
                decoration: BoxDecoration(
                  color: (_rpgEnabled
                          ? context.nexusTheme.accentPrimary
                          : context.nexusTheme.textHint)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.s(10)),
                ),
                child: Icon(
                  Icons.shield_rounded,
                  color: _rpgEnabled
                      ? context.nexusTheme.accentPrimary
                      : context.nexusTheme.textHint,
                  size: r.s(22),
                ),
              ),
            ),
          ),
          SizedBox(height: r.s(16)),

          if (_rpgEnabled) ...[
            // Card: Moeda
            _sectionLabel(r, 'Economia'),
            SizedBox(height: r.s(8)),
            _card(
              r,
              child: Column(
                children: [
                  _inputField(
                    r,
                    label: 'Nome da Moeda',
                    controller: _currencyNameCtrl,
                    hint: 'Ex: Ouro, Gemas, Créditos...',
                    icon: Icons.monetization_on_rounded,
                  ),
                  SizedBox(height: r.s(12)),
                  _inputField(
                    r,
                    label: 'Multiplicador de XP',
                    controller: _xpMultiplierCtrl,
                    hint: '1.0',
                    icon: Icons.trending_up_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  SizedBox(height: r.s(16)),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveGeneralConfig,
                      icon: _isSaving
                          ? SizedBox(
                              width: r.s(16),
                              height: r.s(16),
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: const Text('Salvar Configurações'),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.nexusTheme.accentPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r.s(12))),
                        padding: EdgeInsets.symmetric(vertical: r.s(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(16)),

            // Dica de uso
            Container(
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: context.nexusTheme.accentPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.s(12)),
                border: Border.all(
                    color: context.nexusTheme.accentPrimary
                        .withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: context.nexusTheme.accentPrimary, size: r.s(18)),
                  SizedBox(width: r.s(10)),
                  Expanded(
                    child: Text(
                      'Use as abas "Classes" e "Itens" para configurar o ecossistema. '
                      'Conceda XP e moeda aos jogadores pelo painel de membros do chat.',
                      style: TextStyle(
                          color: context.nexusTheme.textSecondary,
                          fontSize: r.fs(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── ABA: Classes ─────────────────────────────────────────────────────────────
  Widget _buildClassesTab(Responsive r) {
    final classesAsync = ref.watch(chatRpgClassesProvider(widget.threadId));

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(r.s(12)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Classes definem o personagem do jogador e seus atributos iniciais.',
                  style: TextStyle(
                      color: context.nexusTheme.textSecondary,
                      fontSize: r.fs(12)),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showClassEditor(r),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nova Classe'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.nexusTheme.accentPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(10))),
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(12), vertical: r.s(8)),
                  textStyle: TextStyle(fontSize: r.fs(13)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: classesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (classes) {
              if (classes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_alt_rounded,
                          color: context.nexusTheme.textHint, size: r.s(48)),
                      SizedBox(height: r.s(12)),
                      Text('Nenhuma classe criada',
                          style: TextStyle(
                              color: context.nexusTheme.textSecondary,
                              fontSize: r.fs(14))),
                      SizedBox(height: r.s(4)),
                      Text('Crie classes para que os jogadores possam escolher.',
                          style: TextStyle(
                              color: context.nexusTheme.textHint,
                              fontSize: r.fs(12))),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: EdgeInsets.all(r.s(12)),
                itemCount: classes.length,
                separatorBuilder: (_, __) => SizedBox(height: r.s(8)),
                itemBuilder: (context, i) {
                  final cls = classes[i];
                  final color = _parseColor(cls['color'] as String? ?? '#7C4DFF');
                  return _card(
                    r,
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: r.s(12), vertical: r.s(4)),
                      leading: Container(
                        width: r.s(40),
                        height: r.s(40),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(r.s(10)),
                          border: Border.all(
                              color: color.withValues(alpha: 0.5)),
                        ),
                        child: Center(
                          child: Text(
                            cls['icon_url'] as String? ?? '⚔️',
                            style: TextStyle(fontSize: r.fs(18)),
                          ),
                        ),
                      ),
                      title: Text(cls['name'] as String? ?? '',
                          style: TextStyle(
                              color: context.nexusTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: r.fs(14))),
                      subtitle: cls['description'] != null
                          ? Text(cls['description'] as String,
                              style: TextStyle(
                                  color: context.nexusTheme.textSecondary,
                                  fontSize: r.fs(12)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_rounded,
                                color: context.nexusTheme.textHint,
                                size: r.s(18)),
                            onPressed: () => _showClassEditor(r, existing: cls),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded,
                                color: Colors.red.withValues(alpha: 0.7),
                                size: r.s(18)),
                            onPressed: () => _deleteClass(cls['id'] as String),
                          ),
                        ],
                      ),
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

  // ── ABA: Itens ────────────────────────────────────────────────────────────────
  Widget _buildItemsTab(Responsive r) {
    final itemsAsync = ref.watch(chatRpgItemsProvider(widget.threadId));

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(r.s(12)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Itens que os jogadores podem comprar com a moeda do chat.',
                  style: TextStyle(
                      color: context.nexusTheme.textSecondary,
                      fontSize: r.fs(12)),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showItemEditor(r),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Novo Item'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.nexusTheme.accentPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(10))),
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(12), vertical: r.s(8)),
                  textStyle: TextStyle(fontSize: r.fs(13)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: itemsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_rounded,
                          color: context.nexusTheme.textHint, size: r.s(48)),
                      SizedBox(height: r.s(12)),
                      Text('Nenhum item criado',
                          style: TextStyle(
                              color: context.nexusTheme.textSecondary,
                              fontSize: r.fs(14))),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: EdgeInsets.all(r.s(12)),
                itemCount: items.length,
                separatorBuilder: (_, __) => SizedBox(height: r.s(8)),
                itemBuilder: (context, i) {
                  final item = items[i];
                  final rarityColor = _rarityColor(item['rarity'] as String? ?? 'common');
                  return _card(
                    r,
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: r.s(12), vertical: r.s(4)),
                      leading: Container(
                        width: r.s(40),
                        height: r.s(40),
                        decoration: BoxDecoration(
                          color: rarityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(r.s(10)),
                          border: Border.all(
                              color: rarityColor.withValues(alpha: 0.4)),
                        ),
                        child: Center(
                          child: Icon(
                            _itemTypeIcon(item['item_type'] as String? ?? 'consumable'),
                            color: rarityColor,
                            size: r.s(20),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(item['name'] as String? ?? '',
                                style: TextStyle(
                                    color: context.nexusTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: r.fs(14))),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(6), vertical: r.s(2)),
                            decoration: BoxDecoration(
                              color: rarityColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(r.s(4)),
                            ),
                            child: Text(
                              _rarityLabel(item['rarity'] as String? ?? 'common'),
                              style: TextStyle(
                                  color: rarityColor,
                                  fontSize: r.fs(10),
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '${item['price'] ?? 0} moedas',
                        style: TextStyle(
                            color: context.nexusTheme.textSecondary,
                            fontSize: r.fs(12)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_rounded,
                                color: context.nexusTheme.textHint,
                                size: r.s(18)),
                            onPressed: () => _showItemEditor(r, existing: item),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded,
                                color: Colors.red.withValues(alpha: 0.7),
                                size: r.s(18)),
                            onPressed: () => _deleteItem(item['id'] as String),
                          ),
                        ],
                      ),
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

  // ── Editor de Classe ──────────────────────────────────────────────────────────
  void _showClassEditor(Responsive r, {Map<String, dynamic>? existing}) {
    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description'] as String? ?? '');
    final iconCtrl =
        TextEditingController(text: existing?['icon_url'] as String? ?? '⚔️');
    final currCtrl = TextEditingController(
        text: (existing?['starting_currency'] as int? ?? 0).toString());
    String selectedColor = existing?['color'] as String? ?? '#7C4DFF';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.nexusTheme.backgroundSecondary,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: r.s(16),
              right: r.s(16),
              top: r.s(20)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Nova Classe' : 'Editar Classe',
                  style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(18)),
                ),
                SizedBox(height: r.s(16)),
                _inputField(r,
                    label: 'Nome da Classe',
                    controller: nameCtrl,
                    hint: 'Ex: Guerreiro, Mago, Arqueiro...'),
                SizedBox(height: r.s(12)),
                _inputField(r,
                    label: 'Descrição',
                    controller: descCtrl,
                    hint: 'Descreva a classe...',
                    maxLines: 2),
                SizedBox(height: r.s(12)),
                _inputField(r,
                    label: 'Emoji/Ícone',
                    controller: iconCtrl,
                    hint: '⚔️'),
                SizedBox(height: r.s(12)),
                _inputField(r,
                    label: 'Moeda inicial',
                    controller: currCtrl,
                    hint: '0',
                    keyboardType: TextInputType.number),
                SizedBox(height: r.s(12)),
                Row(
                  children: [
                    Text('Cor da Classe',
                        style: TextStyle(
                            color: context.nexusTheme.textSecondary,
                            fontSize: r.fs(12))),
                    const Spacer(),
                    ColorPickerButton(
                      color: _parseColor(selectedColor),
                      title: 'Cor da Classe',
                      label: selectedColor,
                      size: 30,
                      onColorChanged: (c) {
                        final hex =
                            '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                        setModalState(() => selectedColor = hex);
                      },
                    ),
                  ],
                ),
                SizedBox(height: r.s(20)),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _saveClass(
                        classId: existing?['id'] as String?,
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        iconUrl: iconCtrl.text.trim(),
                        color: selectedColor,
                        startingCurrency:
                            int.tryParse(currCtrl.text) ?? 0,
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: context.nexusTheme.accentPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.s(12))),
                      padding: EdgeInsets.symmetric(vertical: r.s(14)),
                    ),
                    child: const Text('Salvar Classe'),
                  ),
                ),
                SizedBox(height: r.s(16)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveClass({
    String? classId,
    required String name,
    String? description,
    String? iconUrl,
    required String color,
    int startingCurrency = 0,
  }) async {
    if (name.isEmpty) return;
    try {
      final res = await SupabaseService.rpc('manage_chat_rpg_class', params: {
        'p_thread_id': widget.threadId,
        if (classId != null) 'p_class_id': classId,
        'p_name': name,
        'p_description': description,
        'p_icon_url': iconUrl,
        'p_color': color,
        'p_starting_currency': startingCurrency,
      });
      if (res?['success'] == true && mounted) {
        ref.invalidate(chatRpgClassesProvider(widget.threadId));
        _showSnack(classId == null ? 'Classe criada!' : 'Classe atualizada!');
      }
    } catch (e) {
      _showSnack('Erro ao salvar classe.', isError: true);
    }
  }

  Future<void> _deleteClass(String classId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nexusTheme.backgroundSecondary,
        title: Text('Excluir Classe',
            style: TextStyle(color: context.nexusTheme.textPrimary)),
        content: Text('Os personagens com esta classe perderão a referência.',
            style: TextStyle(color: context.nexusTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.rpc('manage_chat_rpg_class', params: {
        'p_thread_id': widget.threadId,
        'p_class_id': classId,
        'p_delete': true,
      });
      if (mounted) {
        ref.invalidate(chatRpgClassesProvider(widget.threadId));
        _showSnack('Classe removida.');
      }
    } catch (e) {
      _showSnack('Erro ao remover classe.', isError: true);
    }
  }

  // ── Editor de Item ────────────────────────────────────────────────────────────
  void _showItemEditor(Responsive r, {Map<String, dynamic>? existing}) {
    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description'] as String? ?? '');
    final priceCtrl = TextEditingController(
        text: (existing?['price'] as int? ?? 0).toString());
    String selectedType = existing?['item_type'] as String? ?? 'consumable';
    String selectedRarity = existing?['rarity'] as String? ?? 'common';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.nexusTheme.backgroundSecondary,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: r.s(16),
              right: r.s(16),
              top: r.s(20)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Novo Item' : 'Editar Item',
                  style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(18)),
                ),
                SizedBox(height: r.s(16)),
                _inputField(r,
                    label: 'Nome do Item',
                    controller: nameCtrl,
                    hint: 'Ex: Espada de Fogo, Poção de Vida...'),
                SizedBox(height: r.s(12)),
                _inputField(r,
                    label: 'Descrição',
                    controller: descCtrl,
                    hint: 'Descreva o item...',
                    maxLines: 2),
                SizedBox(height: r.s(12)),
                _inputField(r,
                    label: 'Preço (moedas)',
                    controller: priceCtrl,
                    hint: '0',
                    keyboardType: TextInputType.number),
                SizedBox(height: r.s(12)),
                Text('Tipo',
                    style: TextStyle(
                        color: context.nexusTheme.textSecondary,
                        fontSize: r.fs(12))),
                SizedBox(height: r.s(6)),
                Wrap(
                  spacing: r.s(8),
                  children: [
                    'weapon', 'armor', 'consumable', 'accessory', 'quest_item'
                  ].map((t) {
                    final selected = selectedType == t;
                    return ChoiceChip(
                      label: Text(_itemTypeLabel(t),
                          style: TextStyle(
                              fontSize: r.fs(12),
                              color: selected
                                  ? Colors.white
                                  : context.nexusTheme.textSecondary)),
                      selected: selected,
                      selectedColor: context.nexusTheme.accentPrimary,
                      backgroundColor:
                          context.nexusTheme.backgroundPrimary,
                      onSelected: (_) =>
                          setModalState(() => selectedType = t),
                    );
                  }).toList(),
                ),
                SizedBox(height: r.s(12)),
                Text('Raridade',
                    style: TextStyle(
                        color: context.nexusTheme.textSecondary,
                        fontSize: r.fs(12))),
                SizedBox(height: r.s(6)),
                Wrap(
                  spacing: r.s(8),
                  children: [
                    'common', 'uncommon', 'rare', 'epic', 'legendary'
                  ].map((rarity) {
                    final selected = selectedRarity == rarity;
                    final color = _rarityColor(rarity);
                    return ChoiceChip(
                      label: Text(_rarityLabel(rarity),
                          style: TextStyle(
                              fontSize: r.fs(12),
                              color: selected ? Colors.white : color)),
                      selected: selected,
                      selectedColor: color,
                      backgroundColor:
                          context.nexusTheme.backgroundPrimary,
                      onSelected: (_) =>
                          setModalState(() => selectedRarity = rarity),
                    );
                  }).toList(),
                ),
                SizedBox(height: r.s(20)),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _saveItem(
                        itemId: existing?['id'] as String?,
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        price: int.tryParse(priceCtrl.text) ?? 0,
                        itemType: selectedType,
                        rarity: selectedRarity,
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: context.nexusTheme.accentPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.s(12))),
                      padding: EdgeInsets.symmetric(vertical: r.s(14)),
                    ),
                    child: const Text('Salvar Item'),
                  ),
                ),
                SizedBox(height: r.s(16)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveItem({
    String? itemId,
    required String name,
    String? description,
    required int price,
    required String itemType,
    required String rarity,
  }) async {
    if (name.isEmpty) return;
    try {
      final res = await SupabaseService.rpc('manage_chat_rpg_item', params: {
        'p_thread_id': widget.threadId,
        if (itemId != null) 'p_item_id': itemId,
        'p_name': name,
        'p_description': description,
        'p_price': price,
        'p_item_type': itemType,
        'p_rarity': rarity,
      });
      if (res?['success'] == true && mounted) {
        ref.invalidate(chatRpgItemsProvider(widget.threadId));
        _showSnack(itemId == null ? 'Item criado!' : 'Item atualizado!');
      }
    } catch (e) {
      _showSnack('Erro ao salvar item.', isError: true);
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nexusTheme.backgroundSecondary,
        title: Text('Excluir Item',
            style: TextStyle(color: context.nexusTheme.textPrimary)),
        content: Text('O item será removido da loja permanentemente.',
            style: TextStyle(color: context.nexusTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.rpc('manage_chat_rpg_item', params: {
        'p_thread_id': widget.threadId,
        'p_item_id': itemId,
        'p_delete': true,
      });
      if (mounted) {
        ref.invalidate(chatRpgItemsProvider(widget.threadId));
        _showSnack('Item removido.');
      }
    } catch (e) {
      _showSnack('Erro ao remover item.', isError: true);
    }
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────────

  Widget _card(Responsive r, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: context.nexusTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(r.s(14)),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(Responsive r, String label) {
    return Padding(
      padding: EdgeInsets.only(left: r.s(4)),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              color: context.nexusTheme.textHint,
              fontSize: r.fs(11),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
    );
  }

  Widget _inputField(
    Responsive r, {
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: context.nexusTheme.textSecondary,
                fontSize: r.fs(12))),
        SizedBox(height: r.s(6)),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(
              color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: context.nexusTheme.textHint, fontSize: r.fs(14)),
            prefixIcon: icon != null
                ? Icon(icon,
                    color: context.nexusTheme.textHint, size: r.s(18))
                : null,
            filled: true,
            fillColor: context.nexusTheme.backgroundPrimary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.s(10)),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
                horizontal: r.s(12), vertical: r.s(12)),
          ),
        ),
      ],
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF7C4DFF);
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

  String _itemTypeLabel(String type) {
    return switch (type) {
      'weapon' => 'Arma',
      'armor' => 'Armadura',
      'accessory' => 'Acessório',
      'quest_item' => 'Quest',
      _ => 'Consumível',
    };
  }
}
