import 'dart:math';
import 'package:flutter/material.dart';

/// Utilitário centralizado de responsividade para o NexusHub.
///
/// Usa um design base de **375×812** (iPhone X/11/12/13/14) como referência.
/// Todos os valores fixos de layout são escalados proporcionalmente ao
/// tamanho real da tela, garantindo que a UI se adapte a qualquer dispositivo.
///
/// ## Uso
///
/// ```dart
/// // Em qualquer widget com acesso ao BuildContext:
/// final r = context.r;          // instância do Responsive
///
/// // Escalar dimensões:
/// width: r.s(48),               // escala proporcional (menor eixo)
/// fontSize: r.fs(14),           // escala de fonte (com clamp)
/// padding: r.insets(16),        // EdgeInsets.all escalado
/// height: r.h(200),             // escala proporcional à altura
/// width: r.w(100),              // escala proporcional à largura
///
/// // Breakpoints:
/// r.isCompact                   // < 360 (celulares pequenos)
/// r.isMedium                    // 360–413 (celulares médios)
/// r.isExpanded                  // 414–599 (celulares grandes / phablets)
/// r.isTablet                    // >= 600 (tablets)
/// r.isDesktop                   // >= 1024 (desktop / landscape tablet)
///
/// // Valores condicionais por breakpoint:
/// r.value(compact: 2, medium: 3, expanded: 4, tablet: 6)
/// ```
class Responsive {
  /// Largura de referência do design base (iPhone X).
  static const double _designWidth = 375.0;

  /// Altura de referência do design base (iPhone X).
  static const double _designHeight = 812.0;

  final double screenWidth;
  final double screenHeight;
  final double topPadding;
  final double bottomPadding;

  Responsive({
    required this.screenWidth,
    required this.screenHeight,
    this.topPadding = 0,
    this.bottomPadding = 0,
  });

  // ── Fatores de escala ──

  /// Fator de escala horizontal (largura).
  double get _scaleW => screenWidth / _designWidth;

  /// Fator de escala vertical (altura).
  double get _scaleH => screenHeight / _designHeight;

  /// Fator de escala proporcional (usa o menor eixo para não distorcer).
  double get _scale => min(_scaleW, _scaleH);

  // ── Breakpoints ──

  /// Celulares muito pequenos (< 360dp). Ex: iPhone SE 1st gen, Galaxy A01.
  bool get isCompact => screenWidth < 360;

  /// Celulares médios (360–413dp). Ex: iPhone 8, Pixel 5, Galaxy S21.
  bool get isMedium => screenWidth >= 360 && screenWidth < 414;

  /// Celulares grandes / phablets (414–599dp). Ex: iPhone Pro Max, Galaxy Ultra.
  bool get isExpanded => screenWidth >= 414 && screenWidth < 600;

  /// Tablets (>= 600dp). Ex: iPad Mini, Galaxy Tab.
  bool get isTablet => screenWidth >= 600;

  /// Desktop ou tablet landscape (>= 1024dp).
  bool get isDesktop => screenWidth >= 1024;

  // ── Métodos de escala ──

  /// Escala proporcional genérica (baseada no menor eixo).
  /// Ideal para ícones, avatares, espaçamentos, bordas.
  double s(double value) => value * _scale;

  /// Escala proporcional à largura.
  /// Ideal para larguras de containers, margens horizontais.
  double w(double value) => value * _scaleW;

  /// Escala proporcional à altura.
  /// Ideal para alturas de containers, margens verticais.
  double h(double value) => value * _scaleH;

  /// Escala de fonte com limites mínimo e máximo.
  /// Garante legibilidade em telas pequenas e não fica gigante em tablets.
  double fs(double value) {
    final scaled = value * _scale;
    // Mínimo: 70% do valor original, Máximo: 140% do valor original
    return scaled.clamp(value * 0.7, value * 1.4);
  }

  /// EdgeInsets.all escalado.
  EdgeInsets insets(double value) => EdgeInsets.all(s(value));

  /// EdgeInsets.symmetric escalado.
  EdgeInsets insetsSymmetric({double horizontal = 0, double vertical = 0}) =>
      EdgeInsets.symmetric(
        horizontal: w(horizontal),
        vertical: h(vertical),
      );

  /// EdgeInsets.only escalado.
  EdgeInsets insetsOnly({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) =>
      EdgeInsets.only(
        left: w(left),
        top: h(top),
        right: w(right),
        bottom: h(bottom),
      );

  /// Retorna um valor baseado no breakpoint atual.
  /// Usa cascade: se `tablet` não for definido, usa `expanded`, etc.
  T value<T>({
    required T compact,
    T? medium,
    T? expanded,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop) return desktop ?? tablet ?? expanded ?? medium ?? compact;
    if (isTablet) return tablet ?? expanded ?? medium ?? compact;
    if (isExpanded) return expanded ?? medium ?? compact;
    if (isMedium) return medium ?? compact;
    return compact;
  }

  /// Número de colunas para grid layouts.
  int get gridColumns => value(compact: 2, medium: 2, expanded: 3, tablet: 4, desktop: 6);

  /// Largura máxima de conteúdo (para centralizar em telas grandes).
  double get maxContentWidth => value<double>(
        compact: screenWidth,
        tablet: 700,
        desktop: 900,
      );

  /// Raio de borda padrão escalado.
  double get radius => s(12);

  /// Raio de borda grande escalado.
  double get radiusLg => s(20);

  /// Raio de borda pequeno escalado.
  double get radiusSm => s(8);
}

/// Extension no BuildContext para acesso rápido ao Responsive.
extension ResponsiveContext on BuildContext {
  /// Instância do [Responsive] baseada no MediaQuery atual.
  Responsive get r {
    final mq = MediaQuery.of(this);
    return Responsive(
      screenWidth: mq.size.width,
      screenHeight: mq.size.height,
      topPadding: mq.padding.top,
      bottomPadding: mq.padding.bottom,
    );
  }
}

/// Widget wrapper que fornece [Responsive] via builder.
/// Útil quando precisa do Responsive fora de um build method.
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, Responsive r) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => builder(context, context.r);
}

/// Mixin para StatefulWidget que precisa de Responsive no initState/didChangeDependencies.
mixin ResponsiveMixin<T extends StatefulWidget> on State<T> {
  late Responsive r;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    r = context.r;
  }
}
