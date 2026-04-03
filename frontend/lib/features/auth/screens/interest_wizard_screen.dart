import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Wizard de seleção de interesses em 4 passos, inspirado no Amino Apps.
/// Passo 1: Boas-vindas e avatar
/// Passo 2: Definir Amino ID
/// Passo 3: Selecionar categorias de interesse
/// Passo 4: Comunidades sugeridas
class InterestWizardScreen extends StatefulWidget {
  const InterestWizardScreen({super.key});

  @override
  State<InterestWizardScreen> createState() => _InterestWizardScreenState();
}

class _InterestWizardScreenState extends State<InterestWizardScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  final _aminoIdController = TextEditingController();
  final _bioController = TextEditingController();
  final Set<String> _selectedInterests = {};
  bool _isLoading = false;

  static const _interestCategories = [
    _InterestItem(
        'Anime & Mangá', Icons.movie_filter_rounded, AppTheme.fabPink),
    _InterestItem('K-Pop', Icons.music_note_rounded, AppTheme.badgeAge),
    _InterestItem('Jogos', Icons.sports_esports_rounded, AppTheme.primaryColor),
    _InterestItem('Arte & Design', Icons.palette_rounded, AppTheme.aminoOrange),
    _InterestItem('Moda', Icons.checkroom_rounded, AppTheme.aminoMagenta),
    _InterestItem(
        'Livros & Escrita', Icons.menu_book_rounded, Color(0xFF795548)),
    _InterestItem('Filmes & Séries', Icons.theaters_rounded, Color(0xFFF44336)),
    _InterestItem('Música', Icons.headphones_rounded, AppTheme.infoColor),
    _InterestItem('Fotografia', Icons.camera_alt_rounded, Color(0xFF607D8B)),
    _InterestItem('Ciência', Icons.science_rounded, AppTheme.accentColor),
    _InterestItem('Esportes', Icons.fitness_center_rounded, Color(0xFFFF5722)),
    _InterestItem('Tecnologia', Icons.computer_rounded, Color(0xFF3F51B5)),
    _InterestItem(
        'Cosplay', Icons.face_retouching_natural_rounded, Color(0xFFFF4081)),
    _InterestItem(
        'Espiritualidade', Icons.self_improvement_rounded, Color(0xFF8BC34A)),
    _InterestItem(
        'Culinária', Icons.restaurant_rounded, Color(0xFFFFEB3B)),
    _InterestItem('Pets & Animais', Icons.pets_rounded, Color(0xFF009688)),
    _InterestItem('Viagem', Icons.flight_rounded, Color(0xFF03A9F4)),
    _InterestItem('Terror', Icons.dark_mode_rounded, Color(0xFF424242)),
    _InterestItem('Memes & Humor', Icons.sentiment_very_satisfied_rounded,
        Color(0xFFFFC107)),
    _InterestItem('Idiomas', Icons.translate_rounded, Color(0xFF673AB7)),
    _InterestItem('Faça Você Mesmo', Icons.handyman_rounded, Color(0xFFCDDC39)),
    _InterestItem('Quadrinhos', Icons.auto_stories_rounded, Color(0xFFFF6F00)),
    _InterestItem('Dança', Icons.nightlife_rounded, Color(0xFFD500F9)),
    _InterestItem('Natureza', Icons.park_rounded, AppTheme.primaryColor),
  ];

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

  Future<void> _finishWizard() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      // Atualizar perfil com Amino ID e bio
      final updates = <String, dynamic>{};
      if (_aminoIdController.text.trim().isNotEmpty) {
        updates['amino_id'] = _aminoIdController.text.trim();
      }
      if (_bioController.text.trim().isNotEmpty) {
        updates['bio'] = _bioController.text.trim();
      }
      if (updates.isNotEmpty) {
        await SupabaseService.table('profiles')
            .update(updates)
            .eq('id', userId);
      }

      // Salvar interesses selecionados
      if (_selectedInterests.isNotEmpty) {
        final interests = _selectedInterests
            .map((name) => {
                  'user_id': userId,
                  'name': name,
                })
            .toList();

        // Deletar interesses antigos e inserir novos
        await SupabaseService.table('interests').delete().eq('user_id', userId);
        await SupabaseService.table('interests').insert(interests);
      }

      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _aminoIdController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
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
                  child: Icon(Icons.arrow_back_ios_rounded, size: r.s(20), color: context.textPrimary),
                )
              else
                SizedBox(width: r.s(20)),
              Text(
                'Passo ${_currentStep + 1} de 4',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: r.fs(14),
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/'),
                child: Text(
                  'Pular',
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: r.fs(14), fontWeight: FontWeight.w700),
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
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep() {
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
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
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
            'Bem-vindo ao NexusHub!',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: r.fs(28),
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.s(16)),
          Text(
            'Vamos personalizar sua experiência. Em poucos passos, '
            'você estará conectado com comunidades incríveis!',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: r.fs(16),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.s(16)),
          Text(
            'Adicione uma bio para que outros membros te conheçam:',
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
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'Conte um pouco sobre você...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              counterStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: context.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(16)),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(16)),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(16)),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
          ),
          SizedBox(height: r.s(40)),
          _buildCustomButton(
            text: 'Vamos Começar!',
            onTap: _nextStep,
          ),
        ],
      ),
    );
  }

  Widget _buildAminoIdStep() {
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
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(Icons.badge_rounded,
                size: r.s(48), color: AppTheme.primaryColor),
          ),
          SizedBox(height: r.s(32)),
          Text(
            'Escolha seu ID',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: r.fs(28),
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.s(12)),
          Text(
            'Seu ID único é como outros membros vão te encontrar. '
            'Escolha algo memorável!',
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
            maxLength: 24,
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'ex: gamer_pro_2026',
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: const Icon(Icons.alternate_email_rounded, color: AppTheme.primaryColor),
              counterStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: context.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(16)),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(16)),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(16)),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
              suffixIcon: _aminoIdController.text.length >= 3
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppTheme.primaryColor)
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: r.s(8)),
          Text(
            'Mínimo 3 caracteres. Letras, números e underscores.',
            style: TextStyle(color: Colors.grey[600], fontSize: r.fs(12)),
          ),
          SizedBox(height: r.s(40)),
          _buildCustomButton(
            text: 'Continuar',
            onTap: _nextStep,
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsStep() {
      final r = context.r;
    return Column(
      children: [
        SizedBox(height: r.s(16)),
        Text(
          'O que te interessa?',
          style: TextStyle(
            color: context.textPrimary,
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
                ? AppTheme.primaryColor
                : AppTheme.accentColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: r.s(16)),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(16)),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: _interestCategories.length,
              itemBuilder: (context, index) {
                final item = _interestCategories[index];
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
                        color: isSelected ? item.color : Colors.white.withValues(alpha: 0.05),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: item.color.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ] : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          color:
                              isSelected ? item.color : Colors.grey[500],
                          size: r.s(32),
                        ),
                        SizedBox(height: r.s(8)),
                        Text(
                          item.name,
                          style: TextStyle(
                            color:
                                isSelected ? item.color : context.textPrimary,
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
        Padding(
          padding: EdgeInsets.all(r.s(20)),
          child: _buildCustomButton(
            text: 'Continuar',
            onTap: _selectedInterests.length >= 3 ? _nextStep : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestedCommunitiesStep() {
      final r = context.r;
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
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(Icons.celebration_rounded,
                size: r.s(48), color: AppTheme.primaryColor),
          ),
          SizedBox(height: r.s(24)),
          Text(
            'Tudo Pronto!',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: r.fs(28),
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.s(12)),
          Text(
            'Seus interesses foram salvos. Agora vamos encontrar '
            'as melhores comunidades para você!',
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
            children: _selectedInterests.map((interest) {
              final item = _interestCategories.firstWhere(
                (i) => i.name == interest,
                orElse: () => _InterestItem(
                    interest, Icons.star_rounded, AppTheme.primaryColor),
              );
              return Container(
                padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
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
                      interest,
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
              'Pular por enquanto',
              style: TextStyle(
                color: AppTheme.primaryColor,
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
              ? const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isEnabled ? null : context.surfaceColor,
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
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
                  child: CircularProgressIndicator(
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

class _InterestItem {
  final String name;
  final IconData icon;
  final Color color;
  const _InterestItem(this.name, this.icon, this.color);
}
