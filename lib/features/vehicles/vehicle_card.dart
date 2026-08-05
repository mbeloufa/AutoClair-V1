import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'vehicle.dart';
import 'vehicle_brand_logo.dart';

enum VehicleCardAction { edit, delete }

class VehicleCard extends StatelessWidget {
  const VehicleCard({
    required this.vehicle,
    required this.onTap,
    required this.onAction,
    super.key,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;
  final ValueChanged<VehicleCardAction> onAction;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (vehicle.vehicleYear != null) vehicle.vehicleYear.toString(),
      if (vehicle.fuelType?.trim().isNotEmpty == true) vehicle.fuelType!,
      if (vehicle.mileage != null) '${vehicle.mileage} km',
    ];

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 10, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VehicleBrandLogo(brand: vehicle.make, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            vehicle.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (vehicle.isPrimary) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softPrimary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Principal',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (vehicle.nickname?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        vehicle.makeAndModel,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        details.join(' • '),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (vehicle.registrationNumber?.trim().isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 8),
                      Text(
                        vehicle.registrationNumber!,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<VehicleCardAction>(
                tooltip: 'Actions du véhicule',
                onSelected: onAction,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: VehicleCardAction.edit,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Modifier'),
                    ),
                  ),
                  PopupMenuItem(
                    value: VehicleCardAction.delete,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                      title: Text(
                        'Supprimer',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
