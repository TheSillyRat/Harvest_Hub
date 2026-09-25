import 'package:flutter/material.dart';
import 'theme.dart';

class HarvestHubLogo extends StatelessWidget {
  final double fontSize;
  final double iconSize;

  const HarvestHubLogo({
    super.key,
    this.fontSize = 18,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize + 14,
          height: iconSize + 14,
          decoration: BoxDecoration(
            color: HhColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(
              Icons.spa_rounded,
              color: HhColors.bg,
              size: iconSize,
            ),
          ),
        ),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            text: 'Harvest',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
              color: HhColors.primary,
              fontFamily: 'sans-serif',
            ),
            children: const [
              TextSpan(
                text: 'Hub',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: HhColors.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HorizonLinePainter extends CustomPainter {
  final double horizonY;

  HorizonLinePainter({required this.horizonY});

  @override
  void paint(Canvas canvas, Size size) {
    final hillPaint = Paint()
      ..color = HhColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final hillPath = Path()
      ..moveTo(0, horizonY)
      ..quadraticBezierTo(size.width * 0.25, horizonY - 26, size.width * 0.55, horizonY)
      ..quadraticBezierTo(size.width * 0.8, horizonY - 18, size.width, horizonY)
      ..lineTo(size.width, horizonY)
      ..lineTo(0, horizonY)
      ..close();

    canvas.drawPath(hillPath, hillPaint);

    final linePaint = Paint()
      ..color = HhColors.text.withValues(alpha: 0.20)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, horizonY),
      Offset(size.width, horizonY),
      linePaint,
    );

    final hatchPaint = Paint()
      ..color = HhColors.text.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    for (double x = 12; x < size.width; x += 18) {
      canvas.drawLine(
        Offset(x, horizonY + 6),
        Offset(x + 10, horizonY + 22),
        hatchPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HorizonLinePainter oldDelegate) {
    return oldDelegate.horizonY != horizonY;
  }
}

class ElasticLiquidIndicator extends StatelessWidget {
  final int count;
  final double pageOffset;

  const ElasticLiquidIndicator({
    super.key,
    required this.count,
    required this.pageOffset,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      width: count * 26.0,
      child: CustomPaint(
        painter: LiquidIndicatorPainter(
          count: count,
          offset: pageOffset,
        ),
      ),
    );
  }
}

class LiquidIndicatorPainter extends CustomPainter {
  final int count;
  final double offset;

  LiquidIndicatorPainter({required this.count, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final double spacing = size.width / count;
    const double dotRadius = 4.0;

    final Paint bgPaint = Paint()
      ..color = HhColors.primary.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final Paint activePaint = Paint()
      ..color = HhColors.primary
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final center = Offset(i * spacing + spacing / 2, size.height / 2);
      canvas.drawCircle(center, dotRadius, bgPaint);
    }

    final clampedOffset = offset.clamp(0.0, (count - 1).toDouble());
    final int baseIndex = clampedOffset.floor();
    final double fraction = clampedOffset - baseIndex;

    final double startX = (baseIndex * spacing) + (spacing / 2);
    final double nextX = ((baseIndex + 1) * spacing) + (spacing / 2);

    double leftX, rightX;
    if (fraction <= 0.5) {
      leftX = startX - dotRadius;
      rightX = startX + dotRadius + (nextX - startX) * (fraction * 2);
    } else {
      leftX = startX - dotRadius + (nextX - startX) * ((fraction - 0.5) * 2);
      rightX = nextX + dotRadius;
    }

    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        leftX,
        (size.height / 2) - dotRadius,
        rightX,
        (size.height / 2) + dotRadius,
      ),
      const Radius.circular(dotRadius),
    );

    canvas.drawRRect(rRect, activePaint);
  }

  @override
  bool shouldRepaint(covariant LiquidIndicatorPainter oldDelegate) {
    return oldDelegate.offset != offset;
  }
}

class PillTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const PillTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleVisibility,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: validator != null ? (_) => validator!(controller.text) : null,
      initialValue: controller.text,
      builder: (FormFieldState<String> fieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 14.0, bottom: 6.0),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: HhColors.text,
                ),
              ),
            ),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: fieldState.hasError
                      ? HhColors.danger
                      : HhColors.text.withValues(alpha: 0.14),
                  width: fieldState.hasError ? 1.4 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: fieldState.hasError
                        ? HhColors.danger.withValues(alpha: 0.08)
                        : HhColors.text.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                obscureText: isPassword && obscureText,
                keyboardType: keyboardType,
                onChanged: (val) {
                  if (fieldState.hasError) {
                    fieldState.didChange(val);
                  }
                },
                style: const TextStyle(
                  fontSize: 15,
                  color: HhColors.text,
                ),
                decoration: InputDecoration(
                  filled: false,
                  fillColor: Colors.transparent,
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 14.5,
                    color: HhColors.text.withValues(alpha: 0.35),
                  ),
                  prefixIcon: Icon(
                    icon,
                    size: 20,
                    color: fieldState.hasError ? HhColors.danger : HhColors.primary,
                  ),
                  suffixIcon: isPassword
                      ? IconButton(
                          icon: Icon(
                            obscureText
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: HhColors.text.withValues(alpha: 0.5),
                          ),
                          onPressed: onToggleVisibility,
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
            if (fieldState.hasError && fieldState.errorText != null) ...[
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(left: 14.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 13,
                      color: HhColors.danger,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      fieldState.errorText!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: HhColors.danger,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class BadgeChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const BadgeChip({
    super.key,
    required this.label,
    this.icon = Icons.shield_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: HhColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: HhColors.primary.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: HhColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: HhColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class SproutLoadingIndicator extends StatefulWidget {
  final double size;
  final Color primaryColor;
  final Color backgroundColor;
  final Duration duration;

  const SproutLoadingIndicator({
    super.key,
    this.size = 120.0,
    this.primaryColor = HhColors.primary,
    this.backgroundColor = Colors.white,
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<SproutLoadingIndicator> createState() => _SproutLoadingIndicatorState();
}

class _SproutLoadingIndicatorState extends State<SproutLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleY;
  late final Animation<double> _scaleX;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleY = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _scaleX = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRect(
        clipper: _GroundBottomClipper(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform(
                    alignment: const Alignment(0.0, 0.3125),
                    transform: Matrix4.identity()
                      ..scale(_scaleX.value, _scaleY.value),
                    child: child,
                  );
                },
                child: CustomPaint(
                  painter: _ShortSproutPainter(
                    plantColor: widget.primaryColor,
                    veinColor: widget.backgroundColor,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _SmallGroundMoundPainter(
                  groundColor: widget.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroundBottomClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    final scale = size.width / 320.0;
    return Rect.fromLTWH(0, 0, size.width, 255.0 * scale);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

class _SmallGroundMoundPainter extends CustomPainter {
  final Color groundColor;

  _SmallGroundMoundPainter({required this.groundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 320.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = groundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();
    path.moveTo(160, 210);

    path.cubicTo(172, 211, 185, 218, 198, 226);
    path.cubicTo(207, 228, 215, 234, 222, 240);
    path.cubicTo(228, 242, 234, 246, 238, 250);

    path.arcToPoint(
      const Offset(232, 254),
      radius: const Radius.circular(6),
      clockwise: true,
    );

    path.lineTo(88, 254);

    path.arcToPoint(
      const Offset(82, 250),
      radius: const Radius.circular(6),
      clockwise: true,
    );

    path.cubicTo(86, 246, 92, 242, 98, 240);
    path.cubicTo(105, 234, 113, 228, 122, 226);
    path.cubicTo(135, 218, 148, 211, 160, 210);

    path.close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SmallGroundMoundPainter oldDelegate) =>
      oldDelegate.groundColor != groundColor;
}

class _ShortSproutPainter extends CustomPainter {
  final Color plantColor;
  final Color veinColor;

  _ShortSproutPainter({
    required this.plantColor,
    required this.veinColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 320.0;
    canvas.save();
    canvas.scale(scale, scale);

    final plantPaint = Paint()
      ..color = plantColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final rightHalfPath = Path();

    rightHalfPath.moveTo(160, 218);
    rightHalfPath.lineTo(166, 210);

    rightHalfPath.cubicTo(165, 202, 164, 192, 164, 184);

    rightHalfPath.cubicTo(164.5, 178, 165.5, 174, 167.5, 169);

    rightHalfPath.cubicTo(177, 169, 215, 164, 234, 140);
    rightHalfPath.cubicTo(243, 128, 245, 114, 244, 103);

    rightHalfPath.cubicTo(210, 103.5, 182, 115, 169, 132);
    rightHalfPath.cubicTo(164, 142, 164, 158, 166.5, 168);

    rightHalfPath.cubicTo(164.5, 173, 162.5, 176, 160, 178);

    rightHalfPath.lineTo(160, 218);
    rightHalfPath.close();

    canvas.drawPath(rightHalfPath, plantPaint);

    canvas.save();
    canvas.translate(320, 0);
    canvas.scale(-1, 1);
    canvas.drawPath(rightHalfPath, plantPaint);
    canvas.restore();

    final rightVeinPath = Path();
    rightVeinPath.moveTo(168, 161);
    rightVeinPath.cubicTo(173, 148, 185, 136, 203, 126);
    rightVeinPath.cubicTo(188, 134, 176, 146, 172.5, 160);
    rightVeinPath.close();

    final veinPaint = Paint()
      ..color = veinColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(rightVeinPath, veinPaint);

    canvas.save();
    canvas.translate(320, 0);
    canvas.scale(-1, 1);
    canvas.drawPath(rightVeinPath, veinPaint);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShortSproutPainter oldDelegate) =>
      oldDelegate.plantColor != plantColor || oldDelegate.veinColor != veinColor;
}

