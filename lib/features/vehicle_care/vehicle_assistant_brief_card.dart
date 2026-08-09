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
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Votre assistant AutoClair',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      brief.summary,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < brief.items.length; index++) ...[
            _AssistantItemTile(item: brief.items[index], onAction: onAction),
            if (index != brief.items.length - 1) const SizedBox(height: 9),
          ],
          const SizedBox(height: 12),
          Text(
            'Basé sur votre carnet, vos échéances, alertes et offres connues.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _AssistantItemTile extends StatelessWidget {
  const _AssistantItemTile({required this.item, required this.onAction});

  final VehicleAssistantItem item;
  final ValueChanged<VehicleAssistantTarget> onAction;

  @override
  Widget build(BuildContext context) {
    final visual = _visual(item.importance);
    final target = item.target;
    final actionLabel = item.actionLabel;

    return Material(
      color: visual.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: target == null ? null : () => onAction(target),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(visual.icon, color: visual.foreground, size: 22),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: AppColors.text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (target != null && actionLabel != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        actionLabel,
                        style: TextStyle(
                          color: visual.foreground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (target != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: visual.foreground),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

_AssistantVisual _visual(VehicleAssistantImportance importance) {
  return switch (importance) {
    VehicleAssistantImportance.urgent => const _AssistantVisual(
      background: AppColors.errorSoft,
      foreground: AppColors.error,
      icon: Icons.priority_high_rounded,
    ),
    VehicleAssistantImportance.attention => const _AssistantVisual(
      background: AppColors.warningSoft,
      foreground: AppColors.warning,
      icon: Icons.schedule_rounded,
    ),
    VehicleAssistantImportance.useful => const _AssistantVisual(
      background: AppColors.infoSoft,
      foreground: AppColors.info,
      icon: Icons.lightbulb_outline_rounded,
    ),
    VehicleAssistantImportance.upToDate => const _AssistantVisual(
      background: AppColors.successSoft,
      foreground: AppColors.success,
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
