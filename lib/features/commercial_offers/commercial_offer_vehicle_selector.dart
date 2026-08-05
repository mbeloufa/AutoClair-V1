import 'package:flutter/material.dart';

import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_brand_logo.dart';

class CommercialOfferVehicleSelector extends StatelessWidget {
  const CommercialOfferVehicleSelector({
    required this.vehicles,
    required this.selectedVehicleId,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final List<Vehicle> vehicles;
  final String? selectedVehicleId;
  final bool enabled;
  final ValueChanged<String> onChanged;

  Vehicle? get _selectedVehicle {
    for (final vehicle in vehicles) {
      if (vehicle.id == selectedVehicleId) return vehicle;
    }
    return vehicles.isEmpty ? null : vehicles.first;
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _selectedVehicle;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        key: const ValueKey('commercial-offer-vehicle-selector'),
        borderRadius: BorderRadius.circular(18),
        onTap: enabled && vehicles.isNotEmpty
            ? () => _openPicker(context)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (vehicle != null)
                VehicleBrandLogo(brand: vehicle.make, size: 36)
              else
                const Icon(Icons.directions_car_outlined),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Véhicule',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vehicle?.displayName ?? 'Choisir un véhicule',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (vehicle != null &&
                        vehicle.displayName != vehicle.makeAndModel)
                      Text(
                        vehicle.makeAndModel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Choisir un véhicule',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: vehicles.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final vehicle = vehicles[index];
                  final selected = vehicle.id == selectedVehicleId;
                  return ListTile(
                    key: ValueKey('commercial-offer-vehicle-${vehicle.id}'),
                    leading: VehicleBrandLogo(brand: vehicle.make, size: 38),
                    title: Text(
                      vehicle.displayName,
                      key: ValueKey(
                        'commercial-offer-vehicle-name-${vehicle.id}',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: vehicle.displayName == vehicle.makeAndModel
                        ? null
                        : Text(
                            vehicle.makeAndModel,
                            key: ValueKey(
                              'commercial-offer-vehicle-details-${vehicle.id}',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: selected
                        ? const Icon(Icons.check_circle_rounded)
                        : null,
                    selected: selected,
                    onTap: () => Navigator.of(context).pop(vehicle.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    if (selected != null && selected != selectedVehicleId) {
      onChanged(selected);
    }
  }
}
