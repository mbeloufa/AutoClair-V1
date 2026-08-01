import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
import '../../core/theme/app_theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isFinishing = false;

  static const _steps = <_OnboardingStep>[
    _OnboardingStep(
      icon: Icons.menu_book_rounded,
      badge: 'Comprendre',
      title: 'Comprenez chaque opération',
      description:
          'AutoClair traduit les termes techniques pour vous expliquer '
          'précisément ce qui est fait sur votre véhicule.',
    ),
    _OnboardingStep(
      icon: Icons.fact_check_outlined,
      badge: 'Vérifier',
      title: 'Repérez ce qui doit être précisé',
      description:
          'Les informations manquantes, les zones illisibles et les '
          'incertitudes sont clairement signalées.',
    ),
    _OnboardingStep(
      icon: Icons.question_answer_outlined,
      badge: 'Décider',
      title: 'Préparez les bonnes questions',
      description:
          'Vous repartez avec une synthèse claire et une liste de questions '
          'concrètes à poser au garage.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_isFinishing) {
      return;
    }
    setState(() => _isFinishing = true);
    await widget.controller.completeOnboarding();
    if (mounted) {
      context.go('/login');
    }
  }

  Future<void> _next() async {
    if (_currentIndex < _steps.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      return;
    }
    await _finish();
  }

  Future<void> _previous() async {
    if (_currentIndex == 0) {
      return;
    }
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: _currentIndex > 0
                        ? IconButton(
                            onPressed: _previous,
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Étape précédente',
                          )
                        : null,
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _steps.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: index == _currentIndex ? 28 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: index == _currentIndex
                                ? AppColors.primary
                                : AppColors.border,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  return _StepContent(step: _steps[index]);
                },
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: _isFinishing ? null : _next,
                    child: _isFinishing
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentIndex == _steps.length - 1
                                ? 'Commencer'
                                : 'Suivant',
                          ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isFinishing ? null : _finish,
                    child: const Text("Passer l'introduction"),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AutoClair fournit une aide informative et ne remplace '
                    'pas un diagnostic professionnel.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({required this.step});

  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      child: Column(
        children: [
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(step.icon, size: 72, color: AppColors.primary),
                const SizedBox(height: 22),
                Text(
                  step.badge,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 34),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            step.description,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.icon,
    required this.badge,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String badge;
  final String title;
  final String description;
}
