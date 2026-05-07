import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/interests_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Wizard de seleção de interesses em 4 passos, inspirado no Amino Apps.
/// Passo 1: Boas-vindas e avatar
/// Passo 2: Definir Amino ID
/// Passo 3: Selecionar categorias de interesse (carregadas do Supabase)
/// Passo 4: Comunidades sugeridas
class InterestWizardScreen extends ConsumerStatefulWidget {
  const InterestWizardScreen({super.key});

  @override
  ConsumerState<InterestWizardScreen> createState() => _InterestWizardScreenState();
}

class _InterestWizardScreenState extends ConsumerState<InterestWizardScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  final _aminoIdController = TextEditingController();
  final _bioController = TextEditingController();
  final Set<String> _selectedInterests = {};
  bool _isLoading = false;
  Timer? _aminoIdDebounce;
  bool _isCheckingAminoId = false;
  bool? _isAminoIdAvailable;
  String? _aminoIdAvailabilityMessage;

  void _nextStep() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  String _normalizeAminoId(String value) {
    return value.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
  }

  String? _validateAminoIdValue(String? value, AppStrings s) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = _normalizeAminoId(value);
    if (trimmed.length < 3) return s.min3Chars;
    if (trimmed.length > 30) return s.max30Chars;
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(trimmed)) {
      return s.aminoIdInvalidChars;
    }
    return null;
  }

  Future<bool> _checkAminoIdAvailability({required bool silent}) async {
    final s = getStrings();
    final userId = SupabaseService.currentUserId;
    final normalizedAminoId = _normalizeAminoId(_aminoIdController.text);
    final validationError = _validateAminoIdValue(normalizedAminoId, s);

    if (normalizedAminoId.isEmpty) {
      if (mounted) {
        setState(() {
          _isCheckingAminoId = false;
          _isAminoIdAvailable = null;
          _aminoIdAvailabilityMessage = null;
        });
      }
      return true;
    }

    if (validationError != null) {
      if (mounted && !silent) {
        setState(() {
          _isCheckingAminoId = false;
          _isAminoIdAvailable = false;
          _aminoIdAvailabilityMessage = validationError;
        });
      }
      return false;
    }

    if (mounted) {
      setState(() {
        _isCheckingAminoId = true;
        _isAminoIdAvailable = null;
        _aminoIdAvailabilityMessage = null;
      });
    }

    try {
      final existing = await SupabaseService.table('profiles')
          .select('id')
          .eq('amino_id', normalizedAminoId)
          .neq('id', userId ?? '')
          .maybeSingle();
      final available = existing == null;
      if (mounted) {
        setState(() {
          _isCheckingAminoId = false;
          _isAminoIdAvailable = available;
          _aminoIdAvailabilityMessage = available
              ? '@username disponível globalmente'
              : s.aminoIdInUse;
        });
      }
      return available;
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCheckingAminoId = false;
          _isAminoIdAvailable = null;
          _aminoIdAvailabilityMessage = s.tryAgainGeneric;
        });
      }
      return false;
    }
  }

  void _onAminoIdChanged(String value) {
    _aminoIdDebounce?.cancel();
    setState(() {
      _isAminoIdAvailable = null;
      _aminoIdAvailabilityMessage = null;
      _isCheckingAminoId = false;
    });

    final s = getStrings();
    final normalizedAminoId = _normalizeAminoId(value);
    final validationError = _validateAminoIdValue(normalizedAminoId, s);

    if (normalizedAminoId.isEmpty) {
      return;
    }

    if (validationError != null) {
      setState(() {
        _isAminoIdAvailable = false;
        _aminoIdAvailabilityMessage = validationError;
      });
      return;
    }

    _aminoIdDebounce = Timer(const Duration(milliseconds: 450), () {
      _checkAminoIdAvailability(silent: false);
    });
  }

  Future<void> _finishWizard() async {
    final s = getStrings();
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      // Atualizar perfil com @username global e bio
      final updates = <String, dynamic>{};
      final normalizedAminoId = _normalizeAminoId(_aminoIdController.text);
      final isAminoIdAvailable = await _checkAminoIdAvailability(silent: false);
      if (!isAminoIdAvailable) {
        setState(() => _isLoading = false);
        return;
      }
      if (normalizedAminoId.isNotEmpty) {
        updates['amino_id'] = normalizedAminoId;
      }
      if (_bioController.text.trim().isNotEmpty) {
        updates['bio'] = _bioController.text.trim();
      }
      if (updates.isNotEmpty) {
        await SupabaseService.table('profiles')
            .update(updates)
            .eq('id', userId);
      }

      // Salvar interesses selecionados via RPC
      // A RPC set_user_interests espera JSONB — passamos a lista diretamente.
      if (_selectedInterests.isNotEmpty) {
        await SupabaseService.rpc('set_user_interests', params: {
          'p_interests': _selectedInterests.toList(),
        });
      }

      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.errorSavingTryAgain)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _aminoIdDebounce?.cancel();
    _aminoIdController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header com progresso
            _buildHeader(),
            // Conteúdo dos passos
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [
                  _buildWelcomeStep(),
                  _buildAminoIdStep(),
                  _buildInterestsStep(),
                  _buildSuggestedCommunitiesStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final s = getStrings();
    final r = context.r;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(20), vertical: r.s(12)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                GestureDetector(
                  onTap: _prevStep,
                  child: Icon(Icons.arrow_back_ios_rounded,
                      size: r.s(20), color: context.nexusTheme.textPrimary),
                )
              else
                SizedBox(width: r.s(20)),
              Text(
                '${s.stepProgress} ${_currentStep + 1}/4',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: r.fs(14),
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/'),
                child: Text(
                  s.skip,
                  style: TextStyle(
                      color: context.nexusTheme.accentPrimary,
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: r.s(12)),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(r.s(4)),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 4,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation(context.nexusTheme.accentPrimary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep() {
    final s = getStrings();
    final r = context.r;
    return SingleChildScrollView(
      padding: EdgeInsets.all(r.s(24)),
      child: Column(
        children: [
          SizedBox(height: r.s(40)),
          Container(
            width: r.s(120),
            height: r.s(120),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [context.nexusTheme.accentPrimary, context.nexusTheme.accentSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.waving_hand_rounded,
                size: r.s(56), color: Colors.white),
          ),
          SizedBox(height: r.s(32)),
          Text(
            s.welcomeMessage,
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(28),
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.s(16)),
          Text(
            '${s.customizePrompt}\n${s.connectedWithCommunities}',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: r.fs(16),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.s(16)),
          Text(
            s.addBioDesc,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: r.fs(14),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.s(16)),
          TextField(
            controller: _bioController,
            maxLines: 3,
            maxLength: 200,
            style: TextStyle(color: context.nexusTheme.textPrimary),
            decoration: InputDecoration(
              hintText: s.tellAboutYourself,
              hintStyle: TextStyle(color: Colors.grey[600]),
              counterStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: context.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(16)),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(16)),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(16)),
                borderSide: BorderSide(color: context.nexusTheme.accentPrimary),
              ),
            ),
          ),
          SizedBox(height: r.s(40)),
          _buildCustomButton(
            text: s.letsGo,
            onTap: _nextStep,
          ),
        ],
      ),
    );
  }

  Widget _buildAminoIdStep() {
    final s = getStrings();
    final r = context.r;
    return SingleChildScrollView(
      padding: EdgeInsets.all(r.s(24)),
      child: Column(
        children: [
          SizedBox(height: r.s(40)),
          Container(
            width: r.s(100),
            height: r.s(100),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(Icons.badge_rounded,
                size: r.s(48), color: context.nexusTheme.accentPrimary),
          ),
          SizedBox(height: r.s(32)),
          Text(
            'Escolha seu @username',
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(28),
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.s(12)),
          Text(
            '${s.yourUniqueIdDesc}\n${s.chooseSomethingMemorable}',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: r.fs(16),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.s(32)),
          TextField(
            controller: _aminoIdController,
            maxLength: 30,
            style: TextStyle(color: context.nexusTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'ex: nexus_user_2026',
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: Icon(Icons.alternate_email_rounded,
                  color: context.nexusTheme.accentPrimary),
              counterStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: context.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(16)),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(16)),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(16)),
                borderSide: BorderSide(color: context.nexusTheme.accentPrimary),
              ),
              suffixIcon: _isCheckingAminoId
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: r.s(18),
                        height: r.s(18),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(context.nexusTheme.accentPrimary),
                        ),
                      ),
                    )
                  : _isAminoIdAvailable == null
                      ? (_aminoIdController.text.length >= 3
                          ? Icon(Icons.alternate_email_rounded,
                              color: context.nexusTheme.accentPrimary)
                          : null)
                      : Icon(
                          _isAminoIdAvailable!
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          color: _isAminoIdAvailable!
                              ? context.nexusTheme.accentPrimary
                              : context.nexusTheme.error,
                        ),
            ),
            onChanged: _onAminoIdChanged,
          ),
          SizedBox(height: r.s(8)),
          Text(
            _aminoIdAvailabilityMessage ??
                'Mínimo 3 caracteres. Use letras minúsculas, números e underscores. Esse @username é global e aparece só no seu perfil principal.',
            style: TextStyle(
              color: (_isAminoIdAvailable == false)
                  ? context.nexusTheme.error
                  : (_isAminoIdAvailable == true
                      ? context.nexusTheme.accentPrimary
                      : Colors.grey[600]),
              fontSize: r.fs(12),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.s(40)),
          _buildCustomButton(
            text: s.continueAction,
            onTap: () async {
              final validationError =
                  _validateAminoIdValue(_aminoIdController.text, s);
              if (validationError != null) {
                setState(() {
                  _isAminoIdAvailable = false;
                  _aminoIdAvailabilityMessage = validationError;
                });
                return;
              }
              final isAminoIdAvailable =
                  await _checkAminoIdAvailability(silent: false);
              if (!isAminoIdAvailable) return;
              _nextStep();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsStep() {
    final s = getStrings();
    final r = context.r;
    // Observa o provider de interesses remotos
    final interestsAsync = ref.watch(interestCategoriesProvider);

    return Column(
      children: [
        SizedBox(height: r.s(16)),
        Text(
          'O que te interessa?',
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(24),
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: r.s(8)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.s(24)),
          child: Text(
            'Selecione pelo menos 3 categorias para personalizarmos suas recomendações.',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: r.fs(14),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: r.s(8)),
        Text(
          '${_selectedInterests.length} selecionados',
          style: TextStyle(
            color: _selectedInterests.length >= 3
                ? context.nexusTheme.accentPrimary
                : context.nexusTheme.accentSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: r.s(16)),
        Expanded(
          child: interestsAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(
                color: context.nexusTheme.accentPrimary,
                strokeWidth: 2,
              ),
            ),
            error: (_, __) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: context.nexusTheme.error, size: r.s(40)),
                  SizedBox(height: r.s(12)),
                  Text(
                    s.errorLoading,
                    style: TextStyle(color: context.nexusTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: r.s(12)),
                  TextButton(
                    onPressed: () => ref.invalidate(interestCategoriesProvider),
                    child: Text(s.retry,
                        style: TextStyle(color: context.nexusTheme.accentPrimary)),
                  ),
                ],
              ),
            ),
            data: (categories) => Padding(
              padding: EdgeInsets.symmetric(horizontal: r.s(16)),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final item = categories[index];
                  final isSelected = _selectedInterests.contains(item.name);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedInterests.remove(item.name);
                        } else {
                          _selectedInterests.add(item.name);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? item.color.withValues(alpha: 0.25)
                            : context.surfaceColor,
                        borderRadius: BorderRadius.circular(r.s(16)),
                        border: Border.all(
                          color: isSelected
                              ? item.color
                              : Colors.white.withValues(alpha: 0.05),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: item.color.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            color: isSelected ? item.color : Colors.grey[500],
                            size: r.s(32),
                          ),
                          SizedBox(height: r.s(8)),
                          Text(
                            item.name,
                            style: TextStyle(
                              color: isSelected
                                  ? item.color
                                  : context.nexusTheme.textPrimary,
                              fontSize: r.fs(11),
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isSelected)
                            Padding(
                              padding: EdgeInsets.only(top: r.s(4)),
                              child: Icon(Icons.check_circle_rounded,
                                  color: item.color, size: r.s(16)),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(r.s(20)),
          child: _buildCustomButton(
            text: s.continueAction,
            onTap: _selectedInterests.length >= 3 ? _nextStep : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestedCommunitiesStep() {
    final s = getStrings();
    final r = context.r;
    // Usa os interesses já carregados pelo provider (cache do Riverpod)
    final categories = ref.watch(interestCategoriesProvider).valueOrNull ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.s(24)),
      child: Column(
        children: [
          SizedBox(height: r.s(20)),
          Container(
            width: r.s(100),
            height: r.s(100),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(Icons.celebration_rounded,
                size: r.s(48), color: context.nexusTheme.accentPrimary),
          ),
          SizedBox(height: r.s(24)),
          Text(
            'Tudo Pronto!',
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(28),
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.s(12)),
          Text(
            'Seus interesses foram salvos. Agora vamos encontrar ${s.bestCommunitiesForYou}',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: r.fs(16),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.s(32)),
          // Preview dos interesses selecionados
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _selectedInterests.map((interestName) {
              // Busca a categoria no cache do provider para obter ícone e cor
              final item = categories.firstWhere(
                (c) => c.name == interestName,
                orElse: () => InterestCategory(
                  name: interestName,
                  displayName: interestName,
                  category: '',
                  color: context.nexusTheme.accentPrimary,
                  icon: Icons.star_rounded,
                  sortOrder: 0,
                ),
              );
              return Container(
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.s(20)),
                  border: Border.all(color: item.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: r.s(16), color: item.color),
                    SizedBox(width: r.s(6)),
                    Text(
                      interestName,
                      style: TextStyle(
                        color: item.color,
                        fontSize: r.fs(12),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          SizedBox(height: r.s(40)),
          _buildCustomButton(
            text: 'Explorar Comunidades',
            onTap: _isLoading ? null : _finishWizard,
            isLoading: _isLoading,
          ),
          SizedBox(height: r.s(16)),
          GestureDetector(
            onTap: () => context.go('/'),
            child: Text(
              s.skipForNow,
              style: TextStyle(
                color: context.nexusTheme.accentPrimary,
                fontSize: r.fs(14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomButton({
    required String text,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    final r = context.r;
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: r.s(16)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r.s(24)),
          gradient: isEnabled
              ? LinearGradient(
                  colors: [context.nexusTheme.accentPrimary, context.nexusTheme.accentSecondary],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isEnabled ? null : context.surfaceColor,
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: r.s(20),
                  height: r.s(20),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  text,
                  style: TextStyle(
                    color: isEnabled ? Colors.white : Colors.grey[600],
                    fontSize: r.fs(16),
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}
