import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'vehicle_identification_details_view.dart';
import 'vehicle_identification_profile.dart';

class VehicleIdentificationProfileCard extends StatelessWidget {
  const VehicleIdentificationProfileCard({required this.profile, super.key});

  final VehicleIdentificationProfile profile;

  @override
  Widget build(BuildContext context) {
    final version = _text(profile.identity['version']);
    final trim = _text(profile.identity['trim']);
    final firstRegistration = _text(
      profile.identity['first_registration_date'],
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.softPrimary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.badge_outlined, color: AppColors.primary),
        ),
        title: const Text(
          'Caractéristiques du véhicule',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            if (profile.vin != null) 'VIN ${profile.vin}',
            ?version,
            ?trim,
            if (firstRegistration != null) 'MEC $firstRegistration',
          ].take(2).join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          VehicleIdentificationDetailsView(
            identity: profile.identity,
            technical: profile.technical,
            administrative: profile.administrative,
            aftersales: profile.aftersales,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 17,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Source : ${profile.sourceLabel}. Ces données sont réutilisées '
                  'par AutoClair sans refaire une identification payante à chaque affichage.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toUpperCase() == 'INCONNU') {
      return null;
    }
    return text;
  }
}
