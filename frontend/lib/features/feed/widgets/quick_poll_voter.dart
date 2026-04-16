import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Widget para votação rápida em enquetes
/// Permite votar com um toque, sem necessidade de confirmação

class QuickPollVoter extends ConsumerStatefulWidget {
  final String pollId;
  final List<Map<String, dynamic>> options;
  final int? userVoteIndex;
  final VoidCallback? onVoted;

  const QuickPollVoter({
    super.key,
    required this.pollId,
    required this.options,
    this.userVoteIndex,
    this.onVoted,
  });

  @override
  ConsumerState<QuickPollVoter> createState() => _QuickPollVoterState();
}

class _QuickPollVoterState extends ConsumerState<QuickPollVoter> {
  late int? _selectedIndex;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.userVoteIndex;
  }

  Future<void> _vote(int optionIndex) async {
    if (_selectedIndex != null) {
      // Usuário já votou
      return;
    }

    final s = ref.read(stringsProvider);
    
    setState(() => _isVoting = true);

    try {
      final optionId = widget.options[optionIndex]['id'] as String?;
      if (optionId == null) throw Exception('Option ID not found');

      // Votar na enquete
      await SupabaseService.table('poll_votes').insert({
        'option_id': optionId,
        'user_id': SupabaseService.currentUserId,
      });

      // Incrementar contador
      await SupabaseService.table('poll_options')
          .update({'votes_count': (widget.options[optionIndex]['votes_count'] as int? ?? 0) + 1})
          .eq('id', optionId);

      if (mounted) {
        setState(() => _selectedIndex = optionIndex);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voto registrado!'),
            backgroundColor: context.nexusTheme.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
        
        widget.onVoted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorVoting),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    
    // Calcular total de votos
    int totalVotes = 0;
    for (final option in widget.options) {
      totalVotes += (option['votes_count'] as int? ?? 0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final optionText = option['text'] as String? ?? 'Opção ${index + 1}';
        final votes = (option['votes_count'] as int? ?? 0);
        final isSelected = _selectedIndex == index;
        final percentage = totalVotes > 0 ? (votes / totalVotes * 100) : 0;

        return GestureDetector(
          onTap: _isVoting || _selectedIndex != null ? null : () => _vote(index),
          child: Container(
            margin: EdgeInsets.only(bottom: r.s(8)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r.s(8)),
              border: Border.all(
                color: isSelected
                    ? context.nexusTheme.accentPrimary
                    : context.nexusTheme.accentSecondary.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                // Barra de progresso
                Container(
                  height: r.s(48),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r.s(8)),
                    color: isSelected
                        ? context.nexusTheme.accentPrimary.withValues(alpha: 0.15)
                        : context.nexusTheme.accentSecondary.withValues(alpha: 0.08),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: percentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(r.s(8)),
                        color: isSelected
                            ? context.nexusTheme.accentPrimary.withValues(alpha: 0.3)
                            : context.nexusTheme.accentSecondary.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),

                // Conteúdo
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.s(12),
                    vertical: r.s(10),
                  ),
                  child: Row(
                    children: [
                      // Checkbox
                      Container(
                        width: r.s(20),
                        height: r.s(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? context.nexusTheme.accentPrimary
                                : context.nexusTheme.accentSecondary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: r.s(10),
                                  height: r.s(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: context.nexusTheme.accentPrimary,
                                  ),
                                ),
                              )
                            : null,
                      ),

                      SizedBox(width: r.s(12)),

                      // Texto da opção
                      Expanded(
                        child: Text(
                          optionText,
                          style: TextStyle(
                            color: context.nexusTheme.textPrimary,
                            fontSize: r.fs(13),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),

                      SizedBox(width: r.s(8)),

                      // Percentual
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary.withValues(alpha: 0.7),
                          fontSize: r.fs(12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Widget para criar enquete rápida
class QuickPollCreator extends ConsumerStatefulWidget {
  final String communityId;
  final VoidCallback? onPollCreated;

  const QuickPollCreator({
    super.key,
    required this.communityId,
    this.onPollCreated,
  });

  @override
  ConsumerState<QuickPollCreator> createState() => _QuickPollCreatorState();
}

class _QuickPollCreatorState extends ConsumerState<QuickPollCreator> {
  late TextEditingController _questionController;
  late List<TextEditingController> _optionControllers;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController();
    _optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  Future<void> _createPoll() async {
    final s = ref.read(stringsProvider);
    
    if (_questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Digite a pergunta'),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final options = _optionControllers
        .where((c) => c.text.isNotEmpty)
        .map((c) => {'text': c.text})
        .toList();

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Adicione pelo menos 2 opções'),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Criar post com enquete
      await SupabaseService.rpc('create_poll_post', params: {
        'p_community_id': widget.communityId,
        'p_question': _questionController.text,
        'p_options': options,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.success),
            backgroundColor: context.nexusTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        widget.onPollCreated?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorCreatingPoll),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Dialog(
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r.s(16)),
      ),
      child: Padding(
        padding: EdgeInsets.all(r.s(20)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título
              Text(
                'Criar Enquete',
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(18),
                  fontWeight: FontWeight.w700,
                ),
              ),

              SizedBox(height: r.s(20)),

              // Campo de pergunta
              TextField(
                controller: _questionController,
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(13),
                ),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Pergunta',
                  labelStyle: TextStyle(
                    color: context.nexusTheme.textPrimary.withValues(alpha: 0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(8)),
                    borderSide: BorderSide(
                      color: context.nexusTheme.accentSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: r.s(12),
                    vertical: r.s(10),
                  ),
                ),
              ),

              SizedBox(height: r.s(16)),

              // Opções
              Text(
                'Opções',
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w600,
                ),
              ),

              SizedBox(height: r.s(8)),

              ..._optionControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controller = entry.value;

                return Padding(
                  padding: EdgeInsets.only(bottom: r.s(8)),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: TextStyle(
                            color: context.nexusTheme.textPrimary,
                            fontSize: r.fs(12),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Opção ${index + 1}',
                            hintStyle: TextStyle(
                              color: context.nexusTheme.textPrimary.withValues(alpha: 0.4),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(r.s(6)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(r.s(6)),
                              borderSide: BorderSide(
                                color: context.nexusTheme.accentSecondary.withValues(alpha: 0.2),
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: r.s(10),
                              vertical: r.s(8),
                            ),
                          ),
                        ),
                      ),
                      if (_optionControllers.length > 2)
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: r.s(18)),
                          onPressed: () => _removeOption(index),
                          color: context.nexusTheme.error,
                        ),
                    ],
                  ),
                );
              }).toList(),

              SizedBox(height: r.s(12)),

              // Botão adicionar opção
              if (_optionControllers.length < 5)
                TextButton.icon(
                  onPressed: _addOption,
                  icon: Icon(Icons.add_rounded),
                  label: Text('Adicionar Opção'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.nexusTheme.accentPrimary,
                  ),
                ),

              SizedBox(height: r.s(20)),

              // Botões de ação
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: r.s(12)),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createPoll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.nexusTheme.accentPrimary,
                      ),
                      child: _isCreating
                          ? SizedBox(
                              height: r.s(18),
                              width: r.s(18),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(
                              'Criar',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
