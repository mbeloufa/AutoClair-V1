import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'vehicle_assistant_brief.dart';

class VehicleAssistantBriefCard extends StatelessWidget {
  const VehicleAssistantBriefCard({
    required this.brief,
    required this.onAction,
    super.key,
  });

  final VehicleAssistantBrief brief;
  final ValueChanged<VehicleAssistantTarget> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Votre assistant AutoClair',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Basé sur votre carnet, vos échéances, alertes et offres connues.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            brief.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < brief.items.length; index++) ...[
            _AssistantItemCard(
              key: ValueKey('vehicle-assistant-item-$index'),
              item: brief.items[index],
              onAction: onAction,
            ),
            if (index != brief.items.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _AssistantItemCard extends StatelessWidget {
  const _AssistantItemCard({
    required this.item,
    required this.onAction,
    super.key,
  });

  final VehicleAssistantItem item;
  final ValueChanged<VehicleAssistantTarget> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final target = item.target;
    final VoidCallback? onTap = target == null ? null : () => onAction(target);
    final visual = _visualFor(item.importance, colors);

    return Semantics(
      button: onTap != null,
      label: onTap == null
          ? item.title
          : '${item.title}. ${item.actionLabel ?? 'Ouvrir'}',
      child: Material(
        color: visual.background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(visual.icon, size: 21, color: visual.foreground),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: visual.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      if (target != null && item.actionLabel != null) ...[
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.actionLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 17,
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (target != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

_AssistantVisual _visualFor(
  VehicleAssistantImportance importance,
  ColorScheme colors,
) {
  return switch (importance) {
    VehicleAssistantImportance.urgent => _AssistantVisual(
      background: colors.errorContainer.withValues(alpha: 0.52),
      foreground: colors.onErrorContainer,
      icon: Icons.priority_high_rounded,
    ),
    VehicleAssistantImportance.attention => _AssistantVisual(
      background: colors.tertiaryContainer.withValues(alpha: 0.55),
      foreground: colors.onTertiaryContainer,
      icon: Icons.schedule_rounded,
    ),
    VehicleAssistantImportance.useful => _AssistantVisual(
      background: colors.secondaryContainer.withValues(alpha: 0.55),
      foreground: colors.onSecondaryContainer,
      icon: Icons.lightbulb_outline_rounded,
    ),
    VehicleAssistantImportance.upToDate => _AssistantVisual(
      background: colors.primaryContainer.withValues(alpha: 0.45),
      foreground: colors.onPrimaryContainer,
      icon: Icons.check_circle_outline_rounded,
    ),
  };
}

class _AssistantVisual {
  const _AssistantVisual({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}
