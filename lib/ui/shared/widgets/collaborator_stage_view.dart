import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class CollaboratorStageMetric {
  const CollaboratorStageMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
}

class CollaboratorStageBody extends StatelessWidget {
  const CollaboratorStageBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF4F8FB)),
      child: Stack(
        children: [
          const Positioned.fill(child: _StageBackdrop()),
          child,
        ],
      ),
    );
  }
}

class CollaboratorStageContent extends StatelessWidget {
  const CollaboratorStageContent({
    super.key,
    required this.metrics,
    required this.queue,
    required this.detail,
  });

  final List<CollaboratorStageMetric> metrics;
  final Widget queue;
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(38, 26, 38, 34),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            children: [
              CollaboratorMetricStrip(metrics: metrics),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 360, child: queue),
                  const SizedBox(width: 26),
                  Expanded(child: detail),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CollaboratorMetricStrip extends StatelessWidget {
  const CollaboratorMetricStrip({super.key, required this.metrics});

  final List<CollaboratorStageMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          Expanded(child: _MetricTile(metric: metrics[i])),
          if (i < metrics.length - 1) const SizedBox(width: 18),
        ],
      ],
    );
  }
}

class CollaboratorPanel extends StatelessWidget {
  const CollaboratorPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.09),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.85),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      foregroundDecoration: accent == null
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border(left: BorderSide(color: accent!, width: 5)),
            ),
      child: child,
    );
  }
}

class CollaboratorQueueHeading extends StatelessWidget {
  const CollaboratorQueueHeading({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    this.accent = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.24),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _CountPill(value: count, accent: accent),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class CollaboratorDivider extends StatelessWidget {
  const CollaboratorDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 1,
      color: const Color(0xFFE4EDF4),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final CollaboratorStageMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.075),
            blurRadius: 26,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: metric.accent, width: 5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.label,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    metric.value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 36,
                      height: 0.96,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: metric.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(metric.icon, color: metric.accent, size: 23),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.value, required this.accent});

  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StageBackdrop extends StatelessWidget {
  const _StageBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StageBackdropPainter());
  }
}

class _StageBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFCADBE6).withValues(alpha: 0.26)
      ..strokeWidth = 1;
    final band = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.primary.withValues(alpha: 0.045);
    final sweep = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (var x = -size.height; x < size.width; x += 88) {
      canvas.drawLine(
        Offset(x.toDouble(), size.height),
        Offset(x + size.height * 0.34, 0),
        line,
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.58, size.width, size.height * 0.16),
      band,
    );

    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.62, -size.height * 0.28, 520, 520),
      sweep,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
