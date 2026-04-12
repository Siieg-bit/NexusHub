import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/responsive.dart';
import '../../config/app_theme.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ============================================================================
// RGBColorPicker — Modal seletor de cor RGB inovador e profissional
//
// Features:
// - Roda de cores (hue wheel) interativa com gradiente completo
// - Slider de saturação e brilho
// - Sliders RGB individuais com gradiente visual
// - Preview da cor em tempo real
// - Campo HEX editável
// - Paleta de cores recentes
// - Paleta de cores predefinidas (swatches)
// - Feedback háptico
// - Layout scrollável sem overflow
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
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => _RGBColorPickerSheet(
        initialColor: initialColor,
        title: title,
        scrollController: scrollController,
      ),
    ),
  );
}

// ============================================================================
// _RGBColorPickerSheet — Conteúdo do modal
// ============================================================================
class _RGBColorPickerSheet extends StatefulWidget {
  final Color initialColor;
  final String title;
  final ScrollController scrollController;

  const _RGBColorPickerSheet({
    required this.initialColor,
    required this.title,
    required this.scrollController,
  });

  @override
  State<_RGBColorPickerSheet> createState() => _RGBColorPickerSheetState();
}

class _RGBColorPickerSheetState extends State<_RGBColorPickerSheet>
    with SingleTickerProviderStateMixin {
  late double _hue;
  late double _saturation;
  late double _brightness;
  late TextEditingController _hexController;
  Color _currentColor = Colors.white;
  Color _previousColor = Colors.white;
  bool _isEditingHex = false;
  bool _isSyncing = false; // evita loops de atualização

  // Cores recentes (persistidas em memória durante a sessão)
  static final List<Color> _recentColors = [
    const Color(0xFF6C5CE7),
    const Color(0xFFE91E63),
    const Color(0xFF00BCD4),
    const Color(0xFF2DBE60),
    const Color(0xFFFF9800),
    const Color(0xFFE53935),
  ];

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    _previousColor = widget.initialColor;
    _syncFromColor(widget.initialColor);
    _hexController = TextEditingController(
      text: _colorToHex(widget.initialColor),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  // Sincroniza todos os valores HSV a partir de uma cor
  void _syncFromColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _brightness = hsv.value;
  }

  Color get _hsvColor =>
      HSVColor.fromAHSV(1.0, _hue, _saturation, _brightness).toColor();

  String _colorToHex(Color c) {
    final argb = c.toARGB32();
    final red = (argb >> 16) & 0xFF;
    final green = (argb >> 8) & 0xFF;
    final blue = argb & 0xFF;
    return '${red.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${green.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${blue.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  // Atualiza a partir da roda HSV
  void _updateFromHSV() {
    if (_isSyncing) return;
    _isSyncing = true;
    final color = _hsvColor;
    _currentColor = color;
    if (!_isEditingHex) {
      _hexController.text = _colorToHex(color);
    }
    _isSyncing = false;
    setState(() {});
  }

  // Atualiza a partir do campo HEX
  void _updateFromHex(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '').trim();
      if (cleaned.length == 6) {
        final value = int.parse('FF$cleaned', radix: 16);
        final color = Color(value);
        if (_isSyncing) return;
        _isSyncing = true;
        _syncFromColor(color);
        _currentColor = color;
        _isSyncing = false;
        setState(() {});
      }
    } catch (_) {}
  }

  void _selectSwatch(Color color) {
    HapticFeedback.selectionClick();
    _syncFromColor(color);
    _currentColor = color;
    _hexController.text = _colorToHex(color);
    setState(() {});
  }

  void _confirm() {
    // Adicionar às recentes
    final colorValue = _currentColor.toARGB32();
    _recentColors.removeWhere((c) => c.toARGB32() == colorValue);
    _recentColors.insert(0, _currentColor);
    if (_recentColors.length > 8) _recentColors.removeLast();
    Navigator.of(context).pop(_currentColor);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(24))),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Handle
          _buildHandle(r),
          // Header fixo
          _buildHeader(r),
          // Conteúdo scrollável
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: EdgeInsets.fromLTRB(r.s(20), 0, r.s(20), r.s(8)),
              children: [
                // Roda de cores HSV
                _buildHSVWheel(r),
                SizedBox(height: r.s(16)),
                // Campo HEX
                _buildHexField(r),
                SizedBox(height: r.s(16)),
                // Recentes
                if (_recentColors.isNotEmpty) ...[
                  _buildRecentColors(r),
                  SizedBox(height: r.s(14)),
                ],
                // Botões de ação
                _buildActionButtons(r),
                SizedBox(height: r.s(12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle(Responsive r) {
    return Padding(
      padding: EdgeInsets.only(top: r.s(10), bottom: r.s(4)),
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
      padding: EdgeInsets.fromLTRB(r.s(20), r.s(4), r.s(20), r.s(12)),
      child: Row(
        children: [
          // Preview anterior
          _ColorPreviewBox(
            label: 'Anterior',
            color: _previousColor,
            size: r.s(36),
            borderRadius: r.s(8),
          ),
          SizedBox(width: r.s(6)),
          Icon(Icons.arrow_forward_rounded, color: Colors.white24, size: r.s(14)),
          SizedBox(width: r.s(6)),
          // Preview atual
          _ColorPreviewBox(
            label: 'Nova',
            color: _currentColor,
            size: r.s(36),
            borderRadius: r.s(8),
            glowing: true,
          ),
          SizedBox(width: r.s(12)),
          // Título
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: r.fs(15),
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Botão fechar
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: r.s(32),
              height: r.s(32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded, color: Colors.white54, size: r.s(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHSVWheel(Responsive r) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // Reservar 56px para o slider de brilho lateral
        final wheelSize = availableWidth - r.s(56);

        return SizedBox(
          height: wheelSize,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Roda HSV
              SizedBox(
                width: wheelSize,
                height: wheelSize,
                child: _HSVWheelWidget(
                  hue: _hue,
                  saturation: _saturation,
                  brightness: _brightness,
                  onChanged: (h, s) {
                    _hue = h;
                    _saturation = s;
                    _updateFromHSV();
                  },
                ),
              ),
              SizedBox(width: r.s(12)),
              // Slider de brilho vertical
              Expanded(
                child: _BrightnessSlider(
                  hue: _hue,
                  saturation: _saturation,
                  brightness: _brightness,
                  onChanged: (v) {
                    _brightness = v;
                    _updateFromHSV();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHexField(Responsive r) {
    return Container(
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
          SizedBox(width: r.s(2)),
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
                  backgroundColor: context.nexusTheme.accentSecondary,
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
    );
  }

  Widget _buildRecentColors(Responsive r) {
    return Column(
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
        Wrap(
          spacing: r.s(8),
          runSpacing: r.s(8),
          children: _recentColors.take(8).map((color) {
            final isSelected = _currentColor.toARGB32() == color.toARGB32();
            return GestureDetector(
              onTap: () => _selectSwatch(color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: r.s(30),
                height: r.s(30),
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
    );
  }

  Widget _buildActionButtons(Responsive r) {
    return Row(
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
            child: Container(
              height: r.s(48),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _currentColor,
                    Color.lerp(_currentColor, Colors.black, 0.3) ?? _currentColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(r.s(14)),
                boxShadow: [
                  BoxShadow(
                    color: _currentColor.withValues(alpha: 0.4),
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
                      color: _currentColor.computeLuminance() > 0.5
                          ? Colors.black87
                          : Colors.white,
                      size: r.s(18),
                    ),
                    SizedBox(width: r.s(8)),
                    Text(
                      'Aplicar',
                      style: TextStyle(
                        color: _currentColor.computeLuminance() > 0.5
                            ? Colors.black87
                            : Colors.white,
                        fontSize: r.fs(15),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// _ColorPreviewBox — Caixa de preview de cor com label
// ============================================================================
class _ColorPreviewBox extends StatelessWidget {
  final String label;
  final Color color;
  final double size;
  final double borderRadius;
  final bool glowing;

  const _ColorPreviewBox({
    required this.label,
    required this.color,
    required this.size,
    required this.borderRadius,
    this.glowing = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white38,
            fontSize: r.fs(9),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: r.s(3)),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: glowing ? 0.3 : 0.15),
              width: 1.5,
            ),
            boxShadow: glowing
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// _HSVWheelWidget — Roda HSV interativa usando LayoutBuilder para tamanho real
// ============================================================================
class _HSVWheelWidget extends StatelessWidget {
  final double hue;
  final double saturation;
  final double brightness;
  final void Function(double hue, double saturation) onChanged;

  const _HSVWheelWidget({
    required this.hue,
    required this.saturation,
    required this.brightness,
    required this.onChanged,
  });

  void _handlePan(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final delta = localPos - center;
    final distance = delta.distance;

    // Calcular hue a partir do ângulo
    final angle = math.atan2(delta.dy, delta.dx);
    final newHue = ((angle * 180 / math.pi) + 360) % 360;
    // Calcular saturação a partir da distância (clamped ao raio)
    final newSat = (distance / radius).clamp(0.0, 1.0);

    onChanged(newHue, newSat);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanStart: (d) => _handlePan(d.localPosition, size),
          onPanUpdate: (d) => _handlePan(d.localPosition, size),
          onTapDown: (d) => _handlePan(d.localPosition, size),
          child: CustomPaint(
            painter: _HSVWheelPainter(
              hue: hue,
              saturation: saturation,
              brightness: brightness,
            ),
            size: size,
          ),
        );
      },
    );
  }
}

// ============================================================================
// _HSVWheelPainter — Desenha a roda de cores HSV com indicador de posição
// ============================================================================
class _HSVWheelPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double brightness;

  _HSVWheelPainter({
    required this.hue,
    required this.saturation,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;

    // Clip para círculo
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    // Desenhar a roda de cores com gradiente angular (sweep)
    // Usamos setores finos para simular o sweep gradient
    final segmentCount = 360;
    final segmentAngle = 2 * math.pi / segmentCount;
    for (int i = 0; i < segmentCount; i++) {
      final startAngle = i * segmentAngle;
      final hueDeg = (i * 360.0 / segmentCount);
      final paint = Paint()
        ..color = HSVColor.fromAHSV(1.0, hueDeg, 1.0, brightness).toColor()
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          segmentAngle + 0.01,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }

    // Gradiente radial: branco no centro → transparente na borda (saturação)
    final satPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.white.withValues(alpha: 0.0)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, satPaint);

    // Borda sutil
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Posição do seletor baseada em hue + saturation
    final selectorAngle = hue * math.pi / 180;
    final selectorDist = saturation * radius;
    final selectorX = center.dx + selectorDist * math.cos(selectorAngle);
    final selectorY = center.dy + selectorDist * math.sin(selectorAngle);
    final selectorPos = Offset(selectorX, selectorY);

    // Sombra
    canvas.drawCircle(
      selectorPos,
      13,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Anel branco externo
    canvas.drawCircle(
      selectorPos,
      12,
      Paint()..color = Colors.white,
    );
    // Cor selecionada no centro do seletor
    canvas.drawCircle(
      selectorPos,
      9,
      Paint()
        ..color = HSVColor.fromAHSV(1.0, hue, saturation, brightness).toColor(),
    );
  }

  @override
  bool shouldRepaint(_HSVWheelPainter old) =>
      old.hue != hue || old.saturation != saturation || old.brightness != brightness;
}

// ============================================================================
// _BrightnessSlider — Slider vertical de brilho
// ============================================================================
class _BrightnessSlider extends StatelessWidget {
  final double hue;
  final double saturation;
  final double brightness;
  final ValueChanged<double> onChanged;

  const _BrightnessSlider({
    required this.hue,
    required this.saturation,
    required this.brightness,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final fullColor = HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor();
    return Column(
      children: [
        Text(
          'Brilho',
          style: TextStyle(
            color: Colors.white38,
            fontSize: r.fs(9),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: r.s(6)),
        Expanded(
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: r.s(14),
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
                    colors: [Colors.black, fullColor],
                  ),
                ),
              ),
              child: Slider(
                value: brightness,
                min: 0,
                max: 1,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        SizedBox(height: r.s(4)),
        Text(
          '${(brightness * 100).round()}%',
          style: TextStyle(
            color: Colors.white38,
            fontSize: r.fs(9),
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
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
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
                color: Colors.white.withValues(alpha: 0.25),
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
