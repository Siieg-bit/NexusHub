import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/responsive.dart';
import '../../config/app_theme.dart';

// ============================================================================
// RGBColorPicker — Modal seletor de cor RGB inovador e profissional
//
// Features:
// - Roda de cores (hue wheel) interativa com gradiente completo
// - Sliders RGB individuais com gradiente visual
// - Preview da cor em tempo real com animação
// - Campo HEX editável
// - Paleta de cores recentes
// - Paleta de cores predefinidas (swatches)
// - Feedback háptico
// - Design glassmorphism com fundo escuro
// ============================================================================

/// Abre o modal seletor de cor RGB.
/// Retorna a cor selecionada ou null se cancelado.
Future<Color?> showRGBColorPicker(
  BuildContext context, {
  Color initialColor = const Color(0xFF6C5CE7),
  String title = 'Selecionar Cor',
}) async {
  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (ctx) => _RGBColorPickerSheet(
      initialColor: initialColor,
      title: title,
    ),
  );
}

// ============================================================================
// _RGBColorPickerSheet — Conteúdo do modal
// ============================================================================
class _RGBColorPickerSheet extends StatefulWidget {
  final Color initialColor;
  final String title;

  const _RGBColorPickerSheet({
    required this.initialColor,
    required this.title,
  });

  @override
  State<_RGBColorPickerSheet> createState() => _RGBColorPickerSheetState();
}

class _RGBColorPickerSheetState extends State<_RGBColorPickerSheet>
    with TickerProviderStateMixin {
  late double _r;
  late double _g;
  late double _b;
  late TextEditingController _hexController;
  late AnimationController _previewAnimController;
  late Animation<Color?> _previewColorAnim;
  Color _currentColor = Colors.white;
  Color _previousColor = Colors.white;
  bool _isEditingHex = false;

  // Cores recentes (simuladas — em produção viriam de SharedPreferences)
  static final List<Color> _recentColors = [
    const Color(0xFF6C5CE7),
    const Color(0xFFE91E63),
    const Color(0xFF00BCD4),
    const Color(0xFF2DBE60),
    const Color(0xFFFF9800),
    const Color(0xFFE53935),
  ];

  // Paleta de swatches predefinidos
  static const List<Color> _swatches = [
    Color(0xFFE53935), Color(0xFFE91E63), Color(0xFF9C27B0),
    Color(0xFF673AB7), Color(0xFF3F51B5), Color(0xFF2196F3),
    Color(0xFF03A9F4), Color(0xFF00BCD4), Color(0xFF009688),
    Color(0xFF4CAF50), Color(0xFF8BC34A), Color(0xFFCDDC39),
    Color(0xFFFFEB3B), Color(0xFFFFC107), Color(0xFFFF9800),
    Color(0xFFFF5722), Color(0xFF795548), Color(0xFF607D8B),
    Color(0xFF000000), Color(0xFF212121), Color(0xFF424242),
    Color(0xFF757575), Color(0xFFBDBDBD), Color(0xFFFFFFFF),
    Color(0xFF6C5CE7), Color(0xFF2DBE60), Color(0xFF00BCD4),
  ];

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    _previousColor = widget.initialColor;
    _r = widget.initialColor.red.toDouble();
    _g = widget.initialColor.green.toDouble();
    _b = widget.initialColor.blue.toDouble();
    _hexController = TextEditingController(
      text: _colorToHex(widget.initialColor),
    );

    _previewAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _previewColorAnim = ColorTween(
      begin: widget.initialColor,
      end: widget.initialColor,
    ).animate(CurvedAnimation(
      parent: _previewAnimController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _hexController.dispose();
    _previewAnimController.dispose();
    super.dispose();
  }

  Color get _computedColor => Color.fromARGB(255, _r.round(), _g.round(), _b.round());

  String _colorToHex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2, '0').toUpperCase()}'
      '${c.green.toRadixString(16).padLeft(2, '0').toUpperCase()}'
      '${c.blue.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  void _updateFromRGB() {
    final newColor = _computedColor;
    _animateToColor(newColor);
    if (!_isEditingHex) {
      _hexController.text = _colorToHex(newColor);
    }
  }

  void _animateToColor(Color newColor) {
    _previewColorAnim = ColorTween(
      begin: _currentColor,
      end: newColor,
    ).animate(CurvedAnimation(
      parent: _previewAnimController,
      curve: Curves.easeInOut,
    ));
    _previewAnimController.forward(from: 0);
    setState(() => _currentColor = newColor);
  }

  void _updateFromHex(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '').trim();
      if (cleaned.length == 6) {
        final value = int.parse('FF$cleaned', radix: 16);
        final color = Color(value);
        setState(() {
          _r = color.red.toDouble();
          _g = color.green.toDouble();
          _b = color.blue.toDouble();
        });
        _animateToColor(color);
      }
    } catch (_) {}
  }

  void _selectSwatch(Color color) {
    HapticFeedback.selectionClick();
    setState(() {
      _r = color.red.toDouble();
      _g = color.green.toDouble();
      _b = color.blue.toDouble();
    });
    _hexController.text = _colorToHex(color);
    _animateToColor(color);
  }

  void _confirm() {
    // Adicionar às recentes
    if (!_recentColors.contains(_currentColor)) {
      _recentColors.insert(0, _currentColor);
      if (_recentColors.length > 8) _recentColors.removeLast();
    }
    Navigator.of(context).pop(_currentColor);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(28))),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            _buildHandle(r),
            // Header com título e preview
            _buildHeader(r),
            // Roda de cores (hue wheel)
            _buildHueWheel(r),
            SizedBox(height: r.s(20)),
            // Sliders RGB
            _buildRGBSliders(r),
            SizedBox(height: r.s(16)),
            // Campo HEX
            _buildHexField(r),
            SizedBox(height: r.s(16)),
            // Swatches predefinidos
            _buildSwatches(r),
            SizedBox(height: r.s(16)),
            // Recentes
            if (_recentColors.isNotEmpty) ...[
              _buildRecentColors(r),
              SizedBox(height: r.s(16)),
            ],
            // Botões de ação
            _buildActionButtons(r),
            SizedBox(height: r.s(8)),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(Responsive r) {
    return Padding(
      padding: EdgeInsets.only(top: r.s(12), bottom: r.s(4)),
      child: Container(
        width: r.s(40),
        height: r.s(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(r.s(2)),
        ),
      ),
    );
  }

  Widget _buildHeader(Responsive r) {
    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(20), r.s(8), r.s(20), r.s(4)),
      child: Row(
        children: [
          // Preview da cor anterior
          Column(
            children: [
              Text(
                'Anterior',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: r.fs(10),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: r.s(4)),
              Container(
                width: r.s(40),
                height: r.s(40),
                decoration: BoxDecoration(
                  color: _previousColor,
                  borderRadius: BorderRadius.circular(r.s(10)),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: r.s(8)),
          // Seta
          Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white24,
            size: r.s(16),
          ),
          SizedBox(width: r.s(8)),
          // Preview da cor atual (animado)
          Column(
            children: [
              Text(
                'Nova',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: r.fs(10),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: r.s(4)),
              AnimatedBuilder(
                animation: _previewColorAnim,
                builder: (_, __) => Container(
                  width: r.s(40),
                  height: r.s(40),
                  decoration: BoxDecoration(
                    color: _previewColorAnim.value ?? _currentColor,
                    borderRadius: BorderRadius.circular(r.s(10)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_previewColorAnim.value ?? _currentColor)
                            .withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Título
          Text(
            widget.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: r.fs(16),
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          SizedBox(width: r.s(96)), // Balancear layout
        ],
      ),
    );
  }

  Widget _buildHueWheel(Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(20)),
      child: _HueWheelPicker(
        currentColor: _currentColor,
        onColorSelected: (color) {
          setState(() {
            _r = color.red.toDouble();
            _g = color.green.toDouble();
            _b = color.blue.toDouble();
          });
          _hexController.text = _colorToHex(color);
          _animateToColor(color);
        },
      ),
    );
  }

  Widget _buildRGBSliders(Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(20)),
      child: Column(
        children: [
          _RGBSlider(
            label: 'R',
            value: _r,
            color: Colors.red,
            gradientColors: [Colors.black, Colors.red],
            onChanged: (v) {
              setState(() => _r = v);
              _updateFromRGB();
            },
          ),
          SizedBox(height: r.s(10)),
          _RGBSlider(
            label: 'G',
            value: _g,
            color: Colors.green,
            gradientColors: [Colors.black, Colors.green],
            onChanged: (v) {
              setState(() => _g = v);
              _updateFromRGB();
            },
          ),
          SizedBox(height: r.s(10)),
          _RGBSlider(
            label: 'B',
            value: _b,
            color: Colors.blue,
            gradientColors: [Colors.black, Colors.blue],
            onChanged: (v) {
              setState(() => _b = v);
              _updateFromRGB();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHexField(Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(20)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Preview mini
            Container(
              width: r.s(36),
              height: r.s(36),
              margin: EdgeInsets.all(r.s(8)),
              decoration: BoxDecoration(
                color: _currentColor,
                borderRadius: BorderRadius.circular(r.s(8)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            // Label #
            Text(
              '#',
              style: TextStyle(
                color: Colors.white38,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(width: r.s(4)),
            // Campo de texto
            Expanded(
              child: TextField(
                controller: _hexController,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.fs(15),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                ),
                decoration: InputDecoration(
                  hintText: 'RRGGBB',
                  hintStyle: TextStyle(
                    color: Colors.white24,
                    fontSize: r.fs(14),
                    fontFamily: 'monospace',
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: r.s(12)),
                ),
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                ],
                onChanged: (v) {
                  _isEditingHex = true;
                  _updateFromHex(v);
                },
                onEditingComplete: () {
                  _isEditingHex = false;
                  FocusScope.of(context).unfocus();
                },
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
              ),
            ),
            // Botão copiar
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(
                  text: '#${_hexController.text}',
                ));
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Cor copiada!'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppTheme.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.all(r.s(12)),
                child: Icon(
                  Icons.copy_rounded,
                  color: Colors.white38,
                  size: r.s(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwatches(Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cores predefinidas',
            style: TextStyle(
              color: Colors.white38,
              fontSize: r.fs(11),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: r.s(10)),
          Wrap(
            spacing: r.s(8),
            runSpacing: r.s(8),
            children: _swatches.map((color) {
              final isSelected = _currentColor.value == color.value;
              return GestureDetector(
                onTap: () => _selectSwatch(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: r.s(28),
                  height: r.s(28),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.15),
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          color: color.computeLuminance() > 0.5
                              ? Colors.black87
                              : Colors.white,
                          size: r.s(14),
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentColors(Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Usadas recentemente',
            style: TextStyle(
              color: Colors.white38,
              fontSize: r.fs(11),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: r.s(10)),
          Row(
            children: _recentColors.take(8).map((color) {
              final isSelected = _currentColor.value == color.value;
              return GestureDetector(
                onTap: () => _selectSwatch(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: r.s(28),
                  height: r.s(28),
                  margin: EdgeInsets.only(right: r.s(8)),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.15),
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(20), vertical: r.s(4)),
      child: Row(
        children: [
          // Cancelar
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                height: r.s(48),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(r.s(14)),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: r.fs(15),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: r.s(12)),
          // Confirmar
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _confirm,
              child: AnimatedBuilder(
                animation: _previewColorAnim,
                builder: (_, __) {
                  final color = _previewColorAnim.value ?? _currentColor;
                  return Container(
                    height: r.s(48),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color,
                          Color.lerp(color, Colors.black, 0.3) ?? color,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(r.s(14)),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: color.computeLuminance() > 0.5
                                ? Colors.black87
                                : Colors.white,
                            size: r.s(18),
                          ),
                          SizedBox(width: r.s(8)),
                          Text(
                            'Aplicar Cor',
                            style: TextStyle(
                              color: color.computeLuminance() > 0.5
                                  ? Colors.black87
                                  : Colors.white,
                              fontSize: r.fs(15),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _HueWheelPicker — Roda de cores interativa
// ============================================================================
class _HueWheelPicker extends StatefulWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorSelected;

  const _HueWheelPicker({
    required this.currentColor,
    required this.onColorSelected,
  });

  @override
  State<_HueWheelPicker> createState() => _HueWheelPickerState();
}

class _HueWheelPickerState extends State<_HueWheelPicker> {
  late double _hue;
  late double _saturation;
  late double _brightness;
  Offset? _selectorPos;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.currentColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _brightness = hsv.value;
  }

  @override
  void didUpdateWidget(_HueWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentColor != widget.currentColor) {
      final hsv = HSVColor.fromColor(widget.currentColor);
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _brightness = hsv.value;
    }
  }

  Color get _selectedColor =>
      HSVColor.fromAHSV(1.0, _hue, _saturation, _brightness).toColor();

  void _onWheelPan(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final delta = localPos - center;
    final distance = delta.distance;

    if (distance <= radius) {
      // Calcular hue a partir do ângulo
      final angle = math.atan2(delta.dy, delta.dx);
      _hue = ((angle * 180 / math.pi) + 360) % 360;
      // Calcular saturação a partir da distância
      _saturation = (distance / radius).clamp(0.0, 1.0);
      setState(() {});
      widget.onColorSelected(_selectedColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Column(
      children: [
        // Roda de cores
        SizedBox(
          height: r.s(200),
          child: Row(
            children: [
              // Roda HSV
              Expanded(
                child: GestureDetector(
                  onPanStart: (d) =>
                      _onWheelPan(d.localPosition, Size(r.s(160), r.s(160))),
                  onPanUpdate: (d) =>
                      _onWheelPan(d.localPosition, Size(r.s(160), r.s(160))),
                  onTapDown: (d) =>
                      _onWheelPan(d.localPosition, Size(r.s(160), r.s(160))),
                  child: CustomPaint(
                    painter: _HueWheelPainter(
                      hue: _hue,
                      saturation: _saturation,
                    ),
                    size: Size(r.s(160), r.s(160)),
                  ),
                ),
              ),
              SizedBox(width: r.s(16)),
              // Slider de brilho (vertical)
              Column(
                children: [
                  Text(
                    'Brilho',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: r.fs(10),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: r.s(8)),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: -1,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: r.s(12),
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: r.s(10),
                          ),
                          overlayShape: RoundSliderOverlayShape(
                            overlayRadius: r.s(16),
                          ),
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withValues(alpha: 0.2),
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          trackShape: _GradientTrackShape(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black,
                                HSVColor.fromAHSV(
                                        1.0, _hue, _saturation, 1.0)
                                    .toColor(),
                              ],
                            ),
                          ),
                        ),
                        child: Slider(
                          value: _brightness,
                          min: 0,
                          max: 1,
                          onChanged: (v) {
                            setState(() => _brightness = v);
                            widget.onColorSelected(_selectedColor);
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: r.s(8)),
                  Text(
                    '${(_brightness * 100).round()}%',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: r.fs(10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// _HueWheelPainter — Desenha a roda de cores HSV
// ============================================================================
class _HueWheelPainter extends CustomPainter {
  final double hue;
  final double saturation;

  _HueWheelPainter({required this.hue, required this.saturation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Desenhar a roda de cores com gradiente angular
    for (int i = 0; i < 360; i++) {
      final angle = i * math.pi / 180;
      final paint = Paint()
        ..color = HSVColor.fromAHSV(1.0, i.toDouble(), 1.0, 1.0).toColor()
        ..strokeWidth = radius * 0.5
        ..style = PaintingStyle.stroke;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.75),
        angle,
        math.pi / 180 + 0.01,
        false,
        paint,
      );
    }

    // Gradiente branco do centro para a borda (saturação)
    final satGradient = RadialGradient(
      colors: [Colors.white, Colors.transparent],
    );
    final satPaint = Paint()
      ..shader = satGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..blendMode = BlendMode.srcOver;
    canvas.drawCircle(center, radius, satPaint);

    // Borda circular
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // Indicador de posição selecionada
    final selectedAngle = hue * math.pi / 180;
    final selectedRadius = saturation * radius * 0.9;
    final selectorX = center.dx + selectedRadius * math.cos(selectedAngle);
    final selectorY = center.dy + selectedRadius * math.sin(selectedAngle);
    final selectorPos = Offset(selectorX, selectorY);

    // Sombra do seletor
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(selectorPos, 12, shadowPaint);

    // Círculo externo branco
    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(selectorPos, 11, outerPaint);

    // Círculo interno com a cor selecionada
    final innerPaint = Paint()
      ..color = HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor()
      ..style = PaintingStyle.fill;
    canvas.drawCircle(selectorPos, 8, innerPaint);
  }

  @override
  bool shouldRepaint(_HueWheelPainter oldDelegate) =>
      oldDelegate.hue != hue || oldDelegate.saturation != saturation;
}

// ============================================================================
// _RGBSlider — Slider individual para canal R, G ou B
// ============================================================================
class _RGBSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final List<Color> gradientColors;
  final ValueChanged<double> onChanged;

  const _RGBSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.gradientColors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Row(
      children: [
        // Label
        SizedBox(
          width: r.s(20),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: r.fs(13),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(width: r.s(8)),
        // Slider com gradiente
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: r.s(8),
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: r.s(10),
              ),
              overlayShape: RoundSliderOverlayShape(
                overlayRadius: r.s(16),
              ),
              thumbColor: Colors.white,
              overlayColor: color.withValues(alpha: 0.2),
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              trackShape: _GradientTrackShape(
                gradient: LinearGradient(colors: gradientColors),
              ),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 255,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(width: r.s(8)),
        // Valor numérico
        SizedBox(
          width: r.s(36),
          child: Text(
            value.round().toString(),
            style: TextStyle(
              color: Colors.white60,
              fontSize: r.fs(12),
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// _GradientTrackShape — Track shape com gradiente para o slider
// ============================================================================
class _GradientTrackShape extends SliderTrackShape {
  final LinearGradient gradient;

  const _GradientTrackShape({required this.gradient});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4;
    final trackLeft = offset.dx;
    final trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final paint = Paint()
      ..shader = gradient.createShader(trackRect)
      ..style = PaintingStyle.fill;

    final radius = Radius.circular(trackRect.height / 2);
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, radius),
      paint,
    );
  }
}

// ============================================================================
// ColorPickerButton — Botão que abre o seletor de cor RGB
//
// Uso:
//   ColorPickerButton(
//     color: _selectedColor,
//     onColorChanged: (color) => setState(() => _selectedColor = color),
//   )
// ============================================================================
class ColorPickerButton extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onColorChanged;
  final String? label;
  final String title;
  final double size;

  const ColorPickerButton({
    super.key,
    required this.color,
    required this.onColorChanged,
    this.label,
    this.title = 'Selecionar Cor',
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        final result = await showRGBColorPicker(
          context,
          initialColor: color,
          title: title,
        );
        if (result != null) {
          onColorChanged(result);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: r.s(size),
            height: r.s(size),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              Icons.colorize_rounded,
              color: color.computeLuminance() > 0.5
                  ? Colors.black54
                  : Colors.white54,
              size: r.s(size * 0.45),
            ),
          ),
          if (label != null) ...[
            SizedBox(width: r.s(8)),
            Text(
              label!,
              style: TextStyle(
                color: Colors.white70,
                fontSize: r.fs(13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
