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
              color: HhColors.text.withValues(alpha: 0.14),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: HhColors.text.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword && obscureText,
            keyboardType: keyboardType,
            validator: validator,
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
              prefixIcon: Icon(icon, size: 20, color: HhColors.primary),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
      ],
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
