import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

enum LoginBrandVariant { desktopBackdrop, mobileBackdrop }

class LoginBrandPanel extends StatelessWidget {
  const LoginBrandPanel({super.key, required this.variant});

  final LoginBrandVariant variant;

  bool get _compact => variant == LoginBrandVariant.mobileBackdrop;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF005B91), AppColors.primary, Color(0xFF12A6C8)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: _FlowWaves()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: _compact ? 0.16 : 0.26),
                  ],
                ),
              ),
            ),
          ),
          if (_compact) _MobileBrandContent() else _DesktopBrandContent(),
        ],
      ),
    );
  }
}

class _MobileBrandContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 32, 30, 26),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/vetti-flow-logo.png',
              width: 168,
              fit: BoxFit.contain,
              color: Colors.white,
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(height: 30),
            Text(
              'Portal interno Vetti',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fluxo operacional para producao, testes e expedicao.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopBrandContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(64, 60, 56, 56),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/vetti-flow-logo.png',
                  width: 268,
                  fit: BoxFit.contain,
                  color: Colors.white,
                  colorBlendMode: BlendMode.srcIn,
                ),
                const Spacer(),
                const Text(
                  'Portal interno Vetti',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    height: 1.06,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    'Fluxo operacional unico para producao, testes e '
                    'expedicao das centrais e acessorios Vetti.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 16,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 44),
                const _FeatureRow(
                  icon: Icons.memory_rounded,
                  label: 'Gravacao de firmware rastreavel',
                ),
                const SizedBox(height: 18),
                const _FeatureRow(
                  icon: Icons.fact_check_outlined,
                  label: 'Testes e validacao por etapa',
                ),
                const SizedBox(height: 18),
                const _FeatureRow(
                  icon: Icons.local_shipping_outlined,
                  label: 'Expedicao e almoxarifado integrados',
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 17,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Acesso restrito a colaboradores autorizados.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
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
    final highWave = Paint()..color = Colors.white.withValues(alpha: 0.11);
    final midWave = Paint()
      ..color = const Color(0xFF24B58F).withValues(alpha: 0.26);
    final lowWave = Paint()
      ..color = const Color(0xFF004064).withValues(alpha: 0.22);

    final highPath = Path()
      ..moveTo(0, size.height * 0.62)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.54,
        size.width * 0.44,
        size.height * 0.72,
        size.width * 0.72,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.86,
        size.height * 0.36,
        size.width * 0.96,
        size.height * 0.35,
        size.width,
        size.height * 0.34,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final midPath = Path()
      ..moveTo(0, size.height * 0.76)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.68,
        size.width * 0.44,
        size.height * 0.82,
        size.width * 0.72,
        size.height * 0.62,
      )
      ..cubicTo(
        size.width * 0.85,
        size.height * 0.53,
        size.width * 0.97,
        size.height * 0.50,
        size.width,
        size.height * 0.49,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final lowPath = Path()
      ..moveTo(0, size.height * 0.88)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.80,
        size.width * 0.42,
        size.height * 0.92,
        size.width * 0.72,
        size.height * 0.72,
      )
      ..cubicTo(
        size.width * 0.86,
        size.height * 0.63,
        size.width * 0.97,
        size.height * 0.60,
        size.width,
        size.height * 0.59,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(highPath, highWave);
    canvas.drawPath(midPath, midWave);
    canvas.drawPath(lowPath, lowWave);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
