import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

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
    _InterestItem('Anime & Manga', Icons.movie_filter_rounded, Color(0xFFE91E63)),
    _InterestItem('K-Pop', Icons.music_note_rounded, Color(0xFF9C27B0)),
    _InterestItem('Gaming', Icons.sports_esports_rounded, Color(0xFF4CAF50)),
    _InterestItem('Art & Design', Icons.palette_rounded, Color(0xFFFF9800)),
    _InterestItem('Fashion', Icons.checkroom_rounded, Color(0xFFE040FB)),
    _InterestItem('Books & Writing', Icons.menu_book_rounded, Color(0xFF795548)),
    _InterestItem('Movies & TV', Icons.theaters_rounded, Color(0xFFF44336)),
    _InterestItem('Music', Icons.headphones_rounded, Color(0xFF2196F3)),
    _InterestItem('Photography', Icons.camera_alt_rounded, Color(0xFF607D8B)),
    _InterestItem('Science', Icons.science_rounded, Color(0xFF00BCD4)),
    _InterestItem('Sports', Icons.fitness_center_rounded, Color(0xFFFF5722)),
    _InterestItem('Technology', Icons.computer_rounded, Color(0xFF3F51B5)),
    _InterestItem('Cosplay', Icons.face_retouching_natural_rounded, Color(0xFFFF4081)),
    _InterestItem('Spirituality', Icons.self_improvement_rounded, Color(0xFF8BC34A)),
    _InterestItem('Food & Cooking', Icons.restaurant_rounded, Color(0xFFFFEB3B)),
    _InterestItem('Pets & Animals', Icons.pets_rounded, Color(0xFF009688)),
    _InterestItem('Travel', Icons.flight_rounded, Color(0xFF03A9F4)),
    _InterestItem('Horror', Icons.dark_mode_rounded, Color(0xFF424242)),
    _InterestItem('Memes & Humor', Icons.sentiment_very_satisfied_rounded, Color(0xFFFFC107)),
    _InterestItem('Languages', Icons.translate_rounded, Color(0xFF673AB7)),
    _InterestItem('DIY & Crafts', Icons.handyman_rounded, Color(0xFFCDDC39)),
    _InterestItem('Comics', Icons.auto_stories_rounded, Color(0xFFFF6F00)),
    _InterestItem('Dance', Icons.nightlife_rounded, Color(0xFFD500F9)),
    _InterestItem('Nature', Icons.park_rounded, Color(0xFF4CAF50)),
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
        final interests = _selectedInterests.map((name) => {
          'user_id': userId,
          'name': name,
        }).toList();

        // Deletar interesses antigos e inserir novos
        await SupabaseService.table('interests')
            .delete()
            .eq('user_id', userId);
        await SupabaseService.table('interests').insert(interests);
      }

      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                GestureDetector(
                  onTap: _prevStep,
                  child: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                )
              else
                const SizedBox(width: 20),
              Text(
                'Passo ${_currentStep + 1} de 4',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/'),
                child: const Text(
                  'Pular',
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 4,
              backgroundColor: AppTheme.dividerColor,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.waving_hand_rounded, size: 56, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text(
            'Bem-vindo ao NexusHub!',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Vamos personalizar sua experiência. Em poucos passos, '
            'você estará conectado com comunidades incríveis!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Adicione uma bio para que outros membros te conheçam:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textHint,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'Conte um pouco sobre você...',
              counterStyle: TextStyle(color: AppTheme.textHint),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextStep,
              child: const Text('Vamos Começar!'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAminoIdStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withOpacity(0.15),
            ),
            child: const Icon(Icons.badge_rounded, size: 48, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 32),
          Text(
            'Escolha seu ID',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Seu ID único é como outros membros vão te encontrar. '
            'Escolha algo memorável!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _aminoIdController,
            maxLength: 24,
            decoration: InputDecoration(
              hintText: 'ex: gamer_pro_2026',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              counterStyle: const TextStyle(color: AppTheme.textHint),
              suffixIcon: _aminoIdController.text.length >= 3
                  ? const Icon(Icons.check_circle_rounded, color: AppTheme.successColor)
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            'Mínimo 3 caracteres. Letras, números e underscores.',
            style: TextStyle(color: AppTheme.textHint, fontSize: 12),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextStep,
              child: const Text('Continuar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsStep() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          'O que te interessa?',
          style: Theme.of(context).textTheme.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Selecione pelo menos 3 categorias para personalizarmos suas recomendações.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_selectedInterests.length} selecionados',
          style: TextStyle(
            color: _selectedInterests.length >= 3
                ? AppTheme.successColor
                : AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          ? item.color.withOpacity(0.25)
                          : AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? item.color : AppTheme.dividerColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          color: isSelected ? item.color : AppTheme.textSecondary,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.name,
                          style: TextStyle(
                            color: isSelected ? item.color : AppTheme.textPrimary,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Icon(Icons.check_circle_rounded, color: item.color, size: 16),
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
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedInterests.length >= 3 ? _nextStep : null,
              child: const Text('Continuar'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestedCommunitiesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.successColor.withOpacity(0.15),
            ),
            child: const Icon(Icons.celebration_rounded, size: 48, color: AppTheme.successColor),
          ),
          const SizedBox(height: 24),
          Text(
            'Tudo Pronto!',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Seus interesses foram salvos. Agora vamos encontrar '
            'as melhores comunidades para você!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Preview dos interesses selecionados
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _selectedInterests.map((interest) {
              final item = _interestCategories.firstWhere(
                (i) => i.name == interest,
                orElse: () => _InterestItem(interest, Icons.star_rounded, AppTheme.primaryColor),
              );
              return Chip(
                avatar: Icon(item.icon, size: 16, color: item.color),
                label: Text(interest, style: TextStyle(color: item.color, fontSize: 12)),
                backgroundColor: item.color.withOpacity(0.15),
                side: BorderSide.none,
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _finishWizard,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Explorar Comunidades'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Pular por enquanto'),
          ),
        ],
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
