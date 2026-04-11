import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../providers/sticker_providers.dart';

/// Tela de criação de um novo pack de stickers.
class CreatePackScreen extends ConsumerStatefulWidget {
  const CreatePackScreen({super.key});

  @override
  ConsumerState<CreatePackScreen> createState() => _CreatePackScreenState();
}

class _CreatePackScreenState extends ConsumerState<CreatePackScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isPublic = true;
  final List<String> _tags = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim().toLowerCase().replaceAll(' ', '_');
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 10) {
      setState(() {
        _tags.add(tag);
        _tagCtrl.clear();
      });
    }
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final packId = await ref.read(packEditorProvider.notifier).createPack(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      tags: _tags,
      isPublic: _isPublic,
    );

    if (packId != null) {
      ref.invalidate(myPacksProvider);
      ref.read(stickerPickerProvider.notifier).reload();
      if (mounted) Navigator.pop(context, true);
    } else {
      final error = ref.read(packEditorProvider).error;
      if (mounted && error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final editorState = ref.watch(packEditorProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        title: Text(
          'Novo Pack de Figurinhas',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: r.fs(17),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(r.s(16)),
          children: [
            // Ícone decorativo
            Center(
              child: Container(
                width: r.s(80),
                height: r.s(80),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.emoji_emotions_rounded,
                  size: r.s(40),
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            SizedBox(height: r.s(24)),

            // Nome do pack
            _SectionLabel(label: 'Nome do pack *'),
            SizedBox(height: r.s(6)),
            TextFormField(
              controller: _nameCtrl,
              style: TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
              maxLength: 50,
              decoration: _inputDecoration(context, r, 'Ex: Memes do dia a dia'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Nome é obrigatório';
                if (v.trim().length < 2) return 'Nome muito curto';
                return null;
              },
            ),
            SizedBox(height: r.s(16)),

            // Descrição
            _SectionLabel(label: 'Descrição'),
            SizedBox(height: r.s(6)),
            TextFormField(
              controller: _descCtrl,
              style: TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
              maxLines: 3,
              maxLength: 200,
              decoration: _inputDecoration(context, r, 'Descreva seu pack...'),
            ),
            SizedBox(height: r.s(16)),

            // Tags
            _SectionLabel(label: 'Tags (até 10)'),
            SizedBox(height: r.s(6)),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tagCtrl,
                    style: TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
                    decoration: _inputDecoration(context, r, 'Ex: memes, engraçado...'),
                    onFieldSubmitted: (_) => _addTag(),
                  ),
                ),
                SizedBox(width: r.s(8)),
                GestureDetector(
                  onTap: _addTag,
                  child: Container(
                    width: r.s(40),
                    height: r.s(40),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(r.s(10)),
                    ),
                    child: Icon(Icons.add_rounded, color: Colors.white, size: r.s(20)),
                  ),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              SizedBox(height: r.s(8)),
              Wrap(
                spacing: r.s(6),
                runSpacing: r.s(4),
                children: _tags.map((tag) => Chip(
                  label: Text('#$tag', style: TextStyle(fontSize: r.fs(12))),
                  backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
                  labelStyle: TextStyle(color: AppTheme.accentColor),
                  deleteIconColor: AppTheme.accentColor,
                  onDeleted: () => setState(() => _tags.remove(tag)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.symmetric(horizontal: r.s(4)),
                )).toList(),
              ),
            ],
            SizedBox(height: r.s(20)),

            // Visibilidade
            Container(
              padding: EdgeInsets.all(r.s(16)),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(r.s(14)),
              ),
              child: Row(
                children: [
                  Icon(
                    _isPublic ? Icons.public_rounded : Icons.lock_rounded,
                    color: _isPublic ? AppTheme.primaryColor : Colors.grey[500],
                    size: r.s(22),
                  ),
                  SizedBox(width: r.s(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPublic ? 'Pack público' : 'Pack privado',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: r.fs(14),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _isPublic
                              ? 'Outros usuários podem ver e salvar seu pack'
                              : 'Apenas você pode ver este pack',
                          style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                    activeColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(32)),

            // Botão criar
            ElevatedButton(
              onPressed: editorState.isLoading ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, r.s(52)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(14)),
                ),
                elevation: 0,
              ),
              child: editorState.isLoading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Text(
                      'Criar Pack',
                      style: TextStyle(
                        fontSize: r.fs(16),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            SizedBox(height: r.s(8)),
            Text(
              'Após criar o pack, você poderá adicionar suas figurinhas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: r.fs(12)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, Responsive r, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600], fontSize: r.fs(13)),
      filled: true,
      fillColor: context.cardBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r.s(12)),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: r.s(16),
        vertical: r.s(12),
      ),
      counterStyle: TextStyle(color: Colors.grey[600], fontSize: r.fs(11)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Text(
      label,
      style: TextStyle(
        color: context.textSecondary,
        fontSize: r.fs(12),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}
