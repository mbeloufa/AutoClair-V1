import 'package:flutter/material.dart';

import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_brand_logo.dart';

class DocumentVehicleSelector extends StatelessWidget {
  const DocumentVehicleSelector({
    required this.vehicles,
    required this.selectedVehicleId,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final List<Vehicle> vehicles;
  final String? selectedVehicleId;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedVehicle = _findVehicle(selectedVehicleId);
    final selectedId = selectedVehicle?.id;

    return FormField<String>(
      key: ValueKey('document-vehicle-$selectedId-${vehicles.length}'),
      initialValue: selectedId,
      validator: (value) =>
          value == null ? 'Sélectionnez le véhicule concerné.' : null,
      builder: (field) {
        final currentVehicle = _findVehicle(field.value);

        return Semantics(
          button: true,
          enabled: enabled,
          label: 'Choisir le véhicule concerné',
          child: InkWell(
            key: const ValueKey('document-vehicle-selector'),
            borderRadius: BorderRadius.circular(12),
            onTap: enabled
                ? () => _openVehiclePicker(context: context, field: field)
                : null,
            child: InputDecorator(
              isEmpty: currentVehicle == null,
              decoration: InputDecoration(
                labelText: 'Véhicule',
                errorText: field.errorText,
                enabled: enabled,
                suffixIcon: Icon(
                  enabled
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.lock_outline_rounded,
                ),
              ),
              child: currentVehicle == null
                  ? const Text('Choisir un véhicule')
                  : _SelectedVehicle(vehicle: currentVehicle),
            ),
          ),
        );
      },
    );
  }

  Vehicle? _findVehicle(String? id) {
    if (id == null) return null;

    for (final vehicle in vehicles) {
      if (vehicle.id == id) return vehicle;
    }

    return null;
  }

  Future<void> _openVehiclePicker({
    required BuildContext context,
    required FormFieldState<String> field,
  }) async {
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
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
                    final isSelected = vehicle.id == field.value;

                    return ListTile(
                      key: ValueKey('document-vehicle-option-${vehicle.id}'),
                      leading: VehicleBrandLogo(brand: vehicle.make, size: 38),
                      title: Text(
                        _primaryLabel(vehicle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _secondaryLabel(vehicle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded)
                          : null,
                      selected: isSelected,
                      onTap: () => Navigator.of(context).pop(vehicle.id),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedId == null || selectedId == field.value) return;

    field.didChange(selectedId);
    onChanged(selectedId);
  }

  static String _primaryLabel(Vehicle vehicle) {
    final nickname = vehicle.nickname?.trim();
    if (nickname != null && nickname.isNotEmpty) return nickname;
    return vehicle.makeAndModel;
  }

  static String _secondaryLabel(Vehicle vehicle) {
    final nickname = vehicle.nickname?.trim();
    if (nickname != null && nickname.isNotEmpty) {
      return vehicle.makeAndModel;
    }

    final details = <String>[
      if (vehicle.vehicleYear != null) '${vehicle.vehicleYear}',
      if (vehicle.fuelType != null && vehicle.fuelType!.trim().isNotEmpty)
        vehicle.fuelType!.trim(),
    ];

    return details.isEmpty ? 'Véhicule AutoClair' : details.join(' • ');
  }
}

class _SelectedVehicle extends StatelessWidget {
  const _SelectedVehicle({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        VehicleBrandLogo(brand: vehicle.make, size: 30),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            DocumentVehicleSelector._primaryLabel(vehicle),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
