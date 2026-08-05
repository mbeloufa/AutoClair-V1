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
                        'La vie d’une voiture n’est pas toujours simple',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AutoClair vous aide à chaque étape.',
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
                        'Vos données restent dans votre espace sécurisé.',
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
          for (var index = 0; index < _steps.length; index++) ...[
            _JourneyStep(data: _steps[index], alignRight: index.isOdd),
            if (index < _steps.length - 1)
              _JourneyConnector(alignRight: index.isEven),
          ],
          const SizedBox(height: 8),
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

class _JourneyConnector extends StatelessWidget {
  const _JourneyConnector({required this.alignRight});

  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: CustomPaint(
        painter: _JourneyConnectorPainter(
          alignRight: alignRight,
          color: AppColors.primary.withValues(alpha: 0.38),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _JourneyConnectorPainter extends CustomPainter {
  const _JourneyConnectorPainter({
    required this.alignRight,
    required this.color,
  });

  final bool alignRight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final startX = alignRight ? size.width * 0.30 : size.width * 0.70;
    final endX = alignRight ? size.width * 0.70 : size.width * 0.30;
    path.moveTo(startX, 0);
    path.cubicTo(
      startX,
      size.height * 0.50,
      endX,
      size.height * 0.50,
      endX,
      size.height,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _JourneyConnectorPainter oldDelegate) {
    return oldDelegate.alignRight != alignRight || oldDelegate.color != color;
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
