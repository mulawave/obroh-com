import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// A text field wrapped in a gradient gold border with the label rendered above
/// the field to avoid overlap with the custom border treatment.
class GoldTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixWidget;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final int maxLines;
  final bool enabled;
  final FocusNode? focusNode;

  const GoldTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixWidget,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
    this.focusNode,
  });

  @override
  State<GoldTextField> createState() => _GoldTextFieldState();
}

class _GoldTextFieldState extends State<GoldTextField> {
  late FocusNode _focus;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focus.hasFocus);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focus.removeListener(_onFocusChange);
      _focus.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _isFocused
                  ? ObrohColors.gold300
                  : ObrohColors.foreground60,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        _GoldBorderWrap(
          focused: _isFocused,
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            enabled: widget.enabled,
            style: const TextStyle(
              color: ObrohColors.foreground,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            validator: widget.validator,
            onFieldSubmitted: widget.onFieldSubmitted,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: ObrohColors.foreground.withValues(alpha: 0.2),
                fontSize: 14,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: _isFocused
                          ? ObrohColors.gold400.withValues(alpha: 0.9)
                          : ObrohColors.foreground40,
                      size: 20,
                    )
                  : null,
              suffixIcon: widget.suffixWidget,
              filled: true,
              fillColor: ObrohColors.obsidian800.withValues(alpha: 0.85),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: ObrohColors.error,
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: ObrohColors.error,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Internal gradient border wrapper
// ---------------------------------------------------------------------------

class _GoldBorderWrap extends StatelessWidget {
  final Widget child;
  final bool focused;

  const _GoldBorderWrap({required this.child, required this.focused});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GradientBorderPainter(focused: focused),
      child: child,
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final bool focused;
  _GradientBorderPainter({required this.focused});

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 12.0;
    final strokeWidth = focused ? 1.8 : 1.0;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: focused
          ? [
              ObrohColors.gold200.withValues(alpha: 0.95),
              ObrohColors.gold400,
              ObrohColors.gold600.withValues(alpha: 0.85),
            ]
          : [
              ObrohColors.gold400.withValues(alpha: 0.28),
              ObrohColors.gold500.withValues(alpha: 0.18),
              ObrohColors.gold600.withValues(alpha: 0.12),
            ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rRect, paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter old) => old.focused != focused;
}

// ---------------------------------------------------------------------------
// Convenience: password field with show/hide toggle
// ---------------------------------------------------------------------------

class GoldPasswordField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final void Function(String)? onFieldSubmitted;

  const GoldPasswordField({
    super.key,
    this.controller,
    this.label = 'Password',
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onFieldSubmitted,
  });

  @override
  State<GoldPasswordField> createState() => _GoldPasswordFieldState();
}

class _GoldPasswordFieldState extends State<GoldPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return GoldTextField(
      controller: widget.controller,
      label: widget.label,
      obscureText: _obscure,
      prefixIcon: Icons.lock_outline_rounded,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      suffixWidget: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: ObrohColors.foreground40,
          size: 20,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Obsidian background with grain texture
// ---------------------------------------------------------------------------

class ObsidianBackground extends StatelessWidget {
  final Widget child;
  const ObsidianBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Deep obsidian base
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [ObrohColors.obsidian900, ObrohColors.obsidian950],
            ),
          ),
        ),
        // Grain / noise overlay
        const _GrainOverlay(),
        // Very subtle vignette
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.4,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.45),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _GrainOverlay extends StatelessWidget {
  const _GrainOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GrainPainter());
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(0xABCDE); // fixed seed = consistent grain

    // Fine grain dots — leather-like
    final grainPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 14000; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final opacity = 0.015 + rand.nextDouble() * 0.025;
      final r = 0.3 + rand.nextDouble() * 0.6;
      grainPaint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), r, grainPaint);
    }

    // Slightly larger darker grain for depth
    for (int i = 0; i < 3000; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final opacity = 0.04 + rand.nextDouble() * 0.06;
      grainPaint.color = Colors.black.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(x, y),
        0.8 + rand.nextDouble() * 0.8,
        grainPaint,
      );
    }

    // Subtle denim-like diagonal weave pattern
    final weavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.014)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 14.0;
    final totalLines = (size.width + size.height) ~/ spacing + 2;
    for (int i = 0; i < totalLines; i++) {
      final offset = i * spacing - size.height;
      canvas.drawLine(
        Offset(0, offset),
        Offset(size.height, offset + size.height),
        weavePaint,
      );
    }
    for (int i = 0; i < totalLines; i++) {
      final offset = i * spacing;
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset - size.height, size.height),
        weavePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GrainPainter _) => false;
}
