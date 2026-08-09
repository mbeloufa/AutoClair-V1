import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'vehicle_360_access.dart';

class Vehicle360AccessCard extends StatelessWidget {
  const Vehicle360AccessCard({required this.access, super.key});

  final Vehicle360Access access;

  @override
  Widget build(BuildContext context) {
    final active = access.entitled || access.creditBalance > 0;
    final color = active || access.trialAvailable
        ? AppColors.success
        : AppColors.warning;
    final background = active || access.trialAvailable
        ? AppColors.successSoft
        : AppColors.warningSoft;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            access.entitled
                ? Icons.workspace_premium_outlined
                : access.trialAvailable
                ? Icons.redeem_outlined
                : Icons.lock_outline,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  access.statusLabel,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  access.entitled
                      ? 'Les nouveaux Bilans 360 sont inclus dans votre accès.'
                      : access.creditBalance > 0
                      ? 'Un crédit est utilisé uniquement si un nouveau bilan doit être généré.'
                      : access.trialAvailable
                      ? 'Votre premier Bilan AutoClair 360 peut être réellement testé gratuitement.'
                      : 'Un abonnement Premium ou un crédit sera nécessaire pour générer un nouveau bilan.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
