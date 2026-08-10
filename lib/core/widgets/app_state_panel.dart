import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppStateTone { neutral, warning, error }

class AppStatePanel extends StatelessWidget {
  const AppStatePanel({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
    this.tone = AppStateTone.neutral,
    this.loading = false,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final AppStateTone tone;
  final bool loading;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final colors = _AppStateColors.from(tone);

    return Semantics(
      container: true,
      liveRegion: loading,
      label: '$title. $message',
      child: Container(
        key: const ValueKey('app-state-panel'),
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: loading
                  ? SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: colors.foreground,
                      ),
                    )
                  : Icon(icon, size: 34, color: colors.foreground),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (primaryActionLabel != null && onPrimaryAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onPrimaryAction,
                child: Text(primaryActionLabel!, textAlign: TextAlign.center),
              ),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!, textAlign: TextAlign.center),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppStateColors {
  const _AppStateColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;

  factory _AppStateColors.from(AppStateTone tone) {
    return switch (tone) {
      AppStateTone.neutral => const _AppStateColors(
        background: AppColors.softPrimary,
        foreground: AppColors.primary,
      ),
      AppStateTone.warning => const _AppStateColors(
        background: AppColors.warningSoft,
        foreground: AppColors.warning,
      ),
      AppStateTone.error => const _AppStateColors(
        background: AppColors.errorSoft,
        foreground: AppColors.error,
      ),
    };
  }
}
