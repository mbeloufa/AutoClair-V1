import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class VehicleSmartReminderCard extends StatelessWidget {
  const VehicleSmartReminderCard({
    required this.enabled,
    required this.busy,
    required this.availableCount,
    required this.onChanged,
    super.key,
  });

  final bool enabled;
  final bool busy;
  final int availableCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final message = enabled
        ? availableCount > 0
              ? availableCount == 1
                    ? '1 prochain moment important sera rappelé sur cet appareil.'
                    : '$availableCount prochains moments importants seront rappelés sur cet appareil.'
              : 'Les prochains rappels seront programmés dès qu’une date utile sera connue.'
        : 'Activez seulement les rappels utiles : échéances datées et entretiens à anticiper.';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(
              Icons.notifications_active_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rappels essentiels',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Les rappels d’événements que vous avez choisis restent indépendants.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Switch(
              key: const ValueKey('vehicle-smart-reminder-switch'),
              value: enabled,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}
