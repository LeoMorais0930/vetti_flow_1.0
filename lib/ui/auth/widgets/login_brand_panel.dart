import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class LoginBrandPanel extends StatelessWidget {
  const LoginBrandPanel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final borderRadius = compact
        ? BorderRadius.circular(24)
        : const BorderRadius.horizontal(left: Radius.circular(24));

    return AspectRatio(
      aspectRatio: compact ? 1.72 : 558 / 685,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: ColoredBox(
          color: AppColors.primary,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(child: _FlowWaves()),
              _GuideLine(
                left: compact ? 32 : 63,
                right: compact ? 32 : 63,
                top: compact ? 42 : 76,
              ),
              _GuideLine(
                left: compact ? 48 : 94,
                right: compact ? 48 : 167,
                top: compact ? 210 : 362,
              ),
              _GuideLine(
                left: compact ? 32 : 63,
                right: compact ? 32 : 63,
                bottom: compact ? 34 : 76,
              ),
              Align(
                alignment: compact
                    ? const Alignment(0, -0.16)
                    : const Alignment(0, -0.2),
                child: Image.asset(
                  'assets/images/vetti-flow-logo.png',
                  width: compact ? 215 : 298,
                  fit: BoxFit.contain,
                  color: Colors.white,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
              Positioned(
                left: compact ? 48 : 94,
                right: compact ? 48 : 64,
                top: compact ? 230 : 399,
                child: const _PortalText(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalText extends StatelessWidget {
  const _PortalText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Portal interno',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 13),
        Text(
          'Acesso exclusivo para colaboradores Vetti',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _GuideLine extends StatelessWidget {
  const _GuideLine({
    required this.left,
    required this.right,
    this.top,
    this.bottom,
  });

  final double left;
  final double right;
  final double? top;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(height: 2, color: Colors.white.withValues(alpha: 0.15)),
    );
  }
}

class _FlowWaves extends StatelessWidget {
  const _FlowWaves();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _FlowWavesPainter());
  }
}

class _FlowWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final highWave = Paint()..color = const Color(0xFF218EC8);
    final lowWave = Paint()..color = const Color(0xFF3296CA);

    final highPath = Path()
      ..moveTo(0, size.height * 0.78)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.66,
        size.width * 0.43,
        size.height * 0.82,
        size.width * 0.74,
        size.height * 0.58,
      )
      ..cubicTo(
        size.width * 0.88,
        size.height * 0.47,
        size.width * 0.98,
        size.height * 0.46,
        size.width,
        size.height * 0.45,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final lowPath = Path()
      ..moveTo(0, size.height * 0.84)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.77,
        size.width * 0.42,
        size.height * 0.88,
        size.width * 0.72,
        size.height * 0.69,
      )
      ..cubicTo(
        size.width * 0.86,
        size.height * 0.6,
        size.width * 0.97,
        size.height * 0.57,
        size.width,
        size.height * 0.56,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(highPath, highWave);
    canvas.drawPath(lowPath, lowWave);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
