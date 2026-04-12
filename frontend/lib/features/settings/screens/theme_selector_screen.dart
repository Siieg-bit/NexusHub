import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/nexus_theme_data.dart';
import '../../../config/nexus_themes.dart';
import '../../../config/nexus_theme_extension.dart';
import '../../../core/providers/nexus_theme_provider.dart';
import '../../../core/utils/responsive.dart';

// =============================================================================
// ThemeSelectorScreen — Tela de seleção de temas do NexusHub
//
// Exibe todos os temas disponíveis com:
//   - Preview visual miniaturizado (app bar, cards, chips, bottom nav)
//   - Nome e descrição do tema
//   - Indicador visual do tema ativo
//   - Troca instantânea com animação suave
//   - Persistência automática via NexusThemeProvider
//
// Auditoria visual 12/04/2026:
//   - Ícone de check usa buttonPrimaryForeground (não Colors.white hardcoded)
//   - Preview usa tokens reais do tema — não valores hardcoded
//   - Preview aprimorado: FAB, badge online, barra de progresso simulada
// =============================================================================

class ThemeSelectorScreen extends ConsumerWidget {
  const ThemeSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(nexusThemeProvider);
    final r = context.r;

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: theme.appBarBackground,
        foregroundColor: theme.appBarForeground,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Aparência',
          style: TextStyle(
            color: theme.appBarForeground,
            fontSize: r.fs(18),
            fontWeight: FontWeight.w700,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.appBarForeground,
            size: r.s(20),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: theme.divider),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho descritivo
          Padding(
            padding: EdgeInsets.fromLTRB(r.s(20), r.s(20), r.s(20), r.s(4)),
            child: Text(
              'Escolha o visual do app',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w700,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(r.s(20), 0, r.s(20), r.s(16)),
            child: Text(
              'A mudança é aplicada imediatamente em todo o app.',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: r.fs(13),
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ),

          // Lista de temas
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(16), vertical: r.s(4)),
              itemCount: NexusThemes.all.length,
              separatorBuilder: (_, __) => SizedBox(height: r.s(12)),
              itemBuilder: (context, index) {
                final t = NexusThemes.all[index];
                final isSelected = t.id == theme.id;
                return _ThemeCard(
                  theme: t,
                  isSelected: isSelected,
                  currentTheme: theme,
                  onTap: () {
                    ref.read(nexusThemeProvider.notifier).setTheme(t);
                  },
                );
              },
            ),
          ),

          // Rodapé
          Padding(
            padding: EdgeInsets.fromLTRB(
                r.s(20), r.s(8), r.s(20), r.s(24) + MediaQuery.of(context).padding.bottom),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: r.s(13), color: theme.textHint),
                SizedBox(width: r.s(6)),
                Text(
                  'Mais temas em breve',
                  style: TextStyle(
                    color: theme.textHint,
                    fontSize: r.fs(12),
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _ThemeCard — Card interativo com preview visual do tema
// =============================================================================

class _ThemeCard extends StatelessWidget {
  final NexusThemeData theme;
  final bool isSelected;
  final NexusThemeData currentTheme;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.currentTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: currentTheme.cardBackground,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(
            color: isSelected
                ? currentTheme.accentPrimary
                : currentTheme.borderSubtle,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: currentTheme.accentPrimary.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : currentTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview visual do tema
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(r.s(14))),
              child: _ThemePreview(theme: theme, r: r),
            ),

            // Informações do tema
            Padding(
              padding: EdgeInsets.all(r.s(14)),
              child: Row(
                children: [
                  // Círculo com gradiente do tema
                  Container(
                    width: r.s(36),
                    height: r.s(36),
                    decoration: BoxDecoration(
                      gradient: theme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.previewAccent.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _themeIcon(theme.id),
                      // Usa buttonPrimaryForeground — garante contraste no GreenLeaf
                      color: theme.buttonPrimaryForeground,
                      size: r.s(16),
                    ),
                  ),
                  SizedBox(width: r.s(12)),

                  // Nome e descrição
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              theme.name,
                              style: TextStyle(
                                color: currentTheme.textPrimary,
                                fontSize: r.fs(15),
                                fontWeight: FontWeight.w700,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),
                            if (isSelected) ...[
                              SizedBox(width: r.s(6)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.s(6), vertical: r.s(2)),
                                decoration: BoxDecoration(
                                  color: currentTheme.accentPrimary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(r.s(4)),
                                ),
                                child: Text(
                                  'Ativo',
                                  style: TextStyle(
                                    color: currentTheme.accentPrimary,
                                    fontSize: r.fs(10),
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'PlusJakartaSans',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (theme.description != null) ...[
                          SizedBox(height: r.s(3)),
                          Text(
                            theme.description!,
                            style: TextStyle(
                              color: currentTheme.textSecondary,
                              fontSize: r.fs(12),
                              fontFamily: 'PlusJakartaSans',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(width: r.s(8)),

                  // Indicador de seleção animado
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isSelected
                        ? Container(
                            key: const ValueKey('selected'),
                            width: r.s(24),
                            height: r.s(24),
                            decoration: BoxDecoration(
                              // Usa gradient do tema para o círculo de check
                              gradient: currentTheme.accentGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              // buttonPrimaryForeground garante contraste em todos os temas
                              color: currentTheme.buttonPrimaryForeground,
                              size: r.s(14),
                            ),
                          )
                        : Container(
                            key: const ValueKey('unselected'),
                            width: r.s(24),
                            height: r.s(24),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: currentTheme.borderPrimary,
                                width: 1.5,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _themeIcon(NexusThemeId id) {
    switch (id) {
      case NexusThemeId.principal:
        return Icons.water_rounded;
      case NexusThemeId.midnight:
        return Icons.nights_stay_rounded;
      case NexusThemeId.greenLeaf:
        return Icons.eco_rounded;
    }
  }
}

// =============================================================================
// _ThemePreview — Mini-representação visual da interface com as cores do tema
//
// Renderiza uma versão miniaturizada da interface do NexusHub usando
// exclusivamente os tokens do tema passado como parâmetro, permitindo
// que o usuário visualize como o app ficará antes de confirmar a escolha.
//
// Layout (de cima para baixo):
//   - App bar: avatar + search bar + pílula de moedas + sino
//   - Conteúdo: card de post + linha de chips + barra de progresso simulada
//   - Bottom nav: 4 ícones com FAB central
//
// Auditoria 12/04/2026:
//   - FAB central adicionado ao bottom nav (mais fiel ao layout real)
//   - Badge online adicionado ao avatar
//   - Barra de progresso simulada adicionada ao conteúdo
//   - Todos os tokens são do tema passado — sem hardcoded
// =============================================================================

class _ThemePreview extends StatelessWidget {
  final NexusThemeData theme;
  final Responsive r;

  const _ThemePreview({required this.theme, required this.r});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: r.s(130),
      color: theme.backgroundPrimary,
      child: Stack(
        children: [
          // App Bar simulada
          _buildAppBar(),

          // Conteúdo central
          Positioned(
            top: r.s(32),
            left: r.s(10),
            right: r.s(10),
            bottom: r.s(28),
            child: _buildContent(),
          ),

          // Bottom Nav simulada
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: r.s(28),
        color: theme.appBarBackground,
        padding: EdgeInsets.symmetric(horizontal: r.s(10)),
        child: Row(
          children: [
            // Avatar simulado com badge online
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: r.s(16),
                  height: r.s(16),
                  decoration: BoxDecoration(
                    color: theme.accentPrimary.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.borderSubtle,
                      width: 0.5,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -r.s(1),
                  right: -r.s(1),
                  child: Container(
                    width: r.s(5),
                    height: r.s(5),
                    decoration: BoxDecoration(
                      color: theme.onlineIndicator,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.appBarBackground,
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: r.s(6)),
            // Search bar simulada
            Expanded(
              child: Container(
                height: r.s(14),
                decoration: BoxDecoration(
                  color: theme.inputBackground,
                  borderRadius: BorderRadius.circular(r.s(7)),
                ),
                child: Row(
                  children: [
                    SizedBox(width: r.s(4)),
                    Container(
                      width: r.s(6),
                      height: r.s(6),
                      decoration: BoxDecoration(
                        color: theme.textHint.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: r.s(3)),
                    Container(
                      width: r.s(30),
                      height: r.s(4),
                      decoration: BoxDecoration(
                        color: theme.textHint.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: r.s(5)),
            // Pílula de moedas simulada
            ClipRRect(
              borderRadius: BorderRadius.circular(r.s(7)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: r.s(22),
                    height: r.s(14),
                    color: theme.walletGradient.colors.first,
                    child: Center(
                      child: Container(
                        width: r.s(7),
                        height: r.s(7),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFD700),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: r.s(12),
                    height: r.s(14),
                    color: theme.accentPrimary,
                    child: Center(
                      child: Container(
                        width: r.s(5),
                        height: r.s(5),
                        decoration: BoxDecoration(
                          color: theme.buttonPrimaryForeground.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: r.s(4)),
            // Sino simulado
            Container(
              width: r.s(14),
              height: r.s(14),
              decoration: BoxDecoration(
                color: theme.appBarForeground.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card de post simulado
        Container(
          height: r.s(38),
          decoration: BoxDecoration(
            color: theme.cardBackground,
            borderRadius: BorderRadius.circular(r.s(8)),
            border: Border.all(color: theme.borderSubtle, width: 0.5),
          ),
          padding: EdgeInsets.symmetric(
              horizontal: r.s(8), vertical: r.s(6)),
          child: Row(
            children: [
              // Avatar do autor
              Container(
                width: r.s(20),
                height: r.s(20),
                decoration: BoxDecoration(
                  gradient: theme.accentGradient,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: r.s(6)),
              // Título e subtítulo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      height: r.s(6),
                      decoration: BoxDecoration(
                        color: theme.textPrimary.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: r.s(3)),
                    Container(
                      width: r.s(60),
                      height: r.s(5),
                      decoration: BoxDecoration(
                        color: theme.textSecondary.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: r.s(6)),
              // Botão CTA simulado
              Container(
                width: r.s(30),
                height: r.s(16),
                decoration: BoxDecoration(
                  color: theme.buttonPrimaryBackground,
                  borderRadius: BorderRadius.circular(r.s(8)),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: r.s(5)),

        // Linha de chips simulados
        Row(
          children: [
            _miniChip(active: true),
            SizedBox(width: r.s(4)),
            _miniChip(),
            SizedBox(width: r.s(4)),
            _miniChip(),
            SizedBox(width: r.s(4)),
            _miniChip(),
          ],
        ),

        SizedBox(height: r.s(5)),

        // Barra de progresso de nível simulada
        Container(
          height: r.s(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.s(5)),
            color: theme.shimmerBase,
            border: Border.all(
              color: theme.accentPrimary.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(r.s(5)),
            child: FractionallySizedBox(
              widthFactor: 0.65,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: theme.accentGradient,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: r.s(24),
      color: theme.bottomNavBackground,
      padding: EdgeInsets.symmetric(horizontal: r.s(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Item 1 — Home (ativo)
          _navItem(active: true),
          // Item 2 — Online
          _navItem(),
          // FAB central
          Container(
            width: r.s(20),
            height: r.s(20),
            decoration: BoxDecoration(
              gradient: theme.fabGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.accentPrimary.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: r.s(8),
                height: r.s(1.5),
                color: theme.buttonPrimaryForeground,
              ),
            ),
          ),
          // Item 3 — Chats
          _navItem(),
          // Item 4 — Eu
          _navItem(),
        ],
      ),
    );
  }

  Widget _navItem({bool active = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: r.s(12),
          height: r.s(12),
          decoration: BoxDecoration(
            color: active
                ? theme.bottomNavSelectedItem
                : theme.bottomNavUnselectedItem.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(r.s(3)),
          ),
        ),
      ],
    );
  }

  Widget _miniChip({bool active = false}) {
    return Container(
      width: r.s(32),
      height: r.s(13),
      decoration: BoxDecoration(
        color: active ? theme.chipSelectedBackground : theme.chipBackground,
        borderRadius: BorderRadius.circular(r.s(6)),
        border: active
            ? Border.all(
                color: theme.accentPrimary.withValues(alpha: 0.6),
                width: 0.5)
            : Border.all(
                color: theme.borderSubtle,
                width: 0.5,
              ),
      ),
    );
  }
}
