import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _isFinishing = false;

  Future<void> _finish() async {
    if (_isFinishing) return;

    setState(() => _isFinishing = true);
    await widget.controller.completeOnboarding();

    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 22,
                20,
                compact ? 16 : 22,
                28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: AppLogo(compact: true)),
                      const SizedBox(height: 24),
                      Text(
                        'Votre voiture, plus simple à gérer',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Comprenez quoi faire, au bon moment, sans jargon.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      SizedBox(height: compact ? 22 : 30),
                      const DriverJourney(),
                      const SizedBox(height: 26),
                      FilledButton.icon(
                        onPressed: _isFinishing ? null : _finish,
                        icon: _isFinishing
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          _isFinishing ? 'Préparation…' : 'Commencer',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Vous gardez le contrôle de vos données.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class DriverJourney extends StatelessWidget {
  const DriverJourney({super.key});

  static const _steps = <_JourneyStepData>[
    _JourneyStepData(
      icon: Icons.key_rounded,
      title: 'Acheter',
      subtitle: 'Choisir et comprendre',
    ),
    _JourneyStepData(
      icon: Icons.build_circle_outlined,
      title: 'Entretenir',
      subtitle: 'Savoir quoi faire',
    ),
    _JourneyStepData(
      icon: Icons.car_repair_outlined,
      title: 'Réparer',
      subtitle: 'Lire devis et factures',
    ),
    _JourneyStepData(
      icon: Icons.fact_check_outlined,
      title: 'Contrôler',
      subtitle: 'Suivre les échéances',
    ),
    _JourneyStepData(
      icon: Icons.sell_outlined,
      title: 'Revendre',
      subtitle: 'Préparer le bon moment',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey('onboarding-road'),
                    painter: _JourneyRoadPainter(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      centerLineColor: Colors.white.withValues(alpha: 0.82),
                      stepCount: _steps.length,
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  for (var index = 0; index < _steps.length; index++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _JourneyStep(
                        data: _steps[index],
                        alignRight: index.isOdd,
                      ),
                    ),
                    if (index < _steps.length - 1) const SizedBox(height: 22),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.softPrimary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                SizedBox(width: 9),
                Flexible(
                  child: Text(
                    'AutoClair reste à vos côtés',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
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

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({required this.data, required this.alignRight});

  final _JourneyStepData data;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: card,
    );
  }
}

class _JourneyRoadPainter extends CustomPainter {
  const _JourneyRoadPainter({
    required this.color,
    required this.centerLineColor,
    required this.stepCount,
  });

  final Color color;
  final Color centerLineColor;
  final int stepCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (stepCount < 2 || size.isEmpty) return;

    final roadPaint = Paint()
      ..color = color
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerPaint = Paint()
      ..color = centerLineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final points = <Offset>[
      for (var index = 0; index < stepCount; index++)
        Offset(
          index.isEven ? size.width * 0.28 : size.width * 0.72,
          size.height * ((index + 0.5) / stepCount),
        ),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final middleY = (previous.dy + current.dy) / 2;
      path.cubicTo(
        previous.dx,
        middleY,
        current.dx,
        middleY,
        current.dx,
        current.dy,
      );
    }

    canvas.drawPath(path, roadPaint);
    _drawDashedPath(canvas, path, centerPaint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLength = 8.0;
    const gapLength = 7.0;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength)
            .clamp(0.0, metric.length)
            .toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _JourneyRoadPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.centerLineColor != centerLineColor ||
        oldDelegate.stepCount != stepCount;
  }
}

class _JourneyStepData {
  const _JourneyStepData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}
