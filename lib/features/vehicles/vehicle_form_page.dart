import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'vehicle.dart';
import 'vehicle_brand_catalog.dart';
import 'vehicle_brand_picker.dart';
import 'vehicle_identification_result.dart';
import 'vehicle_registration_identification_card.dart';
import 'vehicle_service.dart';

class VehicleFormPage extends StatefulWidget {
  const VehicleFormPage({this.vehicleId, super.key});

  final String? vehicleId;

  bool get isEditing => vehicleId != null;

  @override
  State<VehicleFormPage> createState() => _VehicleFormPageState();
}

class _VehicleFormPageState extends State<VehicleFormPage> {
  static const _fuelTypes = <String>[
    'Essence',
    'Diesel',
    'Hybride',
    'Hybride rechargeable',
    'Électrique',
    'GPL',
    'Autre',
  ];

  final _formKey = GlobalKey<FormState>();
  final _service = VehicleService();

  final _nicknameController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _mileageController = TextEditingController();
  final _registrationController = TextEditingController();
  final _vinController = TextEditingController();

  Vehicle? _vehicle;
  String? _fuelType;
  bool _isPrimary = false;
  bool _loading = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadVehicle();
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _mileageController.dispose();
    _registrationController.dispose();
    _vinController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicle() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final vehicle = await _service.fetchVehicle(widget.vehicleId!);
      if (!mounted) {
        return;
      }

      _vehicle = vehicle;
      _nicknameController.text = vehicle.nickname ?? '';
      _makeController.text = vehicle.make;
      _modelController.text = vehicle.model;
      _yearController.text = vehicle.vehicleYear?.toString() ?? '';
      _mileageController.text = vehicle.mileage?.toString() ?? '';
      _registrationController.text = vehicle.registrationNumber ?? '';
      _vinController.text = vehicle.vin ?? '';
      _fuelType = vehicle.fuelType;
      _isPrimary = vehicle.isPrimary;
    } on VehicleServiceException catch (error) {
      if (mounted) {
        _loadError = error.message;
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _requiredText(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  String? _validateYear(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }

    final year = int.tryParse(trimmed);
    final maximumYear = DateTime.now().year + 1;

    if (year == null || year < 1886 || year > maximumYear) {
      return 'Saisissez une année comprise entre 1886 et $maximumYear.';
    }

    return null;
  }

  String? _validateMileage(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }

    final mileage = int.tryParse(trimmed);
    if (mileage == null || mileage < 0) {
      return 'Saisissez un kilométrage valide.';
    }

    return null;
  }

  String? _validateVin(String? value) {
    final normalized = (value ?? '').replaceAll(RegExp(r'\s'), '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.length != 17) {
      return 'Le VIN doit contenir exactement 17 caractères.';
    }
    return null;
  }

  int? _nullableInt(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : int.parse(value);
  }

  void _applyIdentifiedVehicle(VehicleIdentificationResult result) {
    setState(() {
      _makeController.text = VehicleBrandCatalog.canonicalValue(result.make);
      _modelController.text = result.model;

      if (result.vehicleYear != null) {
        _yearController.text = result.vehicleYear.toString();
      }

      final fuelType = result.fuelType;
      if (fuelType != null && _fuelTypes.contains(fuelType)) {
        _fuelType = fuelType;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) {
      return;
    }

    setState(() => _saving = true);

    try {
      await _service.saveVehicle(
        vehicleId: widget.vehicleId,
        nickname: _nicknameController.text,
        make: VehicleBrandCatalog.canonicalValue(_makeController.text),
        model: _modelController.text,
        vehicleYear: _nullableInt(_yearController),
        fuelType: _fuelType,
        mileage: _nullableInt(_mileageController),
        registrationNumber: _registrationController.text,
        vin: _vinController.text,
        isPrimary: _isPrimary,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Le véhicule a été modifié.'
                : 'Le véhicule a été ajouté.',
          ),
        ),
      );

      context.pop(true);
    } on VehicleServiceException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Modifier le véhicule' : 'Ajouter un véhicule',
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 52, color: AppColors.error),
              const SizedBox(height: 16),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: _loadVehicle,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Ajout rapide', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          VehicleRegistrationIdentificationCard(
            controller: _registrationController,
            enabled: !_saving,
            onIdentified: _applyIdentifiedVehicle,
          ),
          const SizedBox(height: 28),
          Text(
            'Informations principales',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nicknameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nom personnalisé',
              hintText: 'Ex. Ma Golf',
              prefixIcon: Icon(Icons.label_outline),
              helperText: 'Facultatif',
            ),
          ),
          const SizedBox(height: 16),
          VehicleBrandPickerField(
            controller: _makeController,
            enabled: !_saving,
            validator: (value) =>
                _requiredText(value, 'Sélectionnez la marque du véhicule.'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _modelController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            validator: (value) =>
                _requiredText(value, 'Saisissez le modèle du véhicule.'),
            decoration: const InputDecoration(
              labelText: 'Modèle',
              hintText: 'Ex. Golf',
              prefixIcon: Icon(Icons.car_repair_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _yearController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validator: _validateYear,
            decoration: const InputDecoration(
              labelText: 'Année',
              hintText: 'Ex. 2020',
              prefixIcon: Icon(Icons.calendar_today_outlined),
              helperText: 'Facultatif',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _fuelType,
            decoration: const InputDecoration(
              labelText: 'Motorisation',
              prefixIcon: Icon(Icons.local_gas_station_outlined),
              helperText: 'Facultatif',
            ),
            items: _fuelTypes
                .map((fuel) => DropdownMenuItem(value: fuel, child: Text(fuel)))
                .toList(growable: false),
            onChanged: (value) {
              setState(() => _fuelType = value);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _mileageController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: _validateMileage,
            decoration: const InputDecoration(
              labelText: 'Kilométrage',
              hintText: 'Ex. 85000',
              suffixText: 'km',
              prefixIcon: Icon(Icons.speed_outlined),
              helperText: 'Facultatif',
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Identification complémentaire',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vinController,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            inputFormatters: [LengthLimitingTextInputFormatter(20)],
            validator: _validateVin,
            decoration: const InputDecoration(
              labelText: 'VIN',
              hintText: '17 caractères',
              prefixIcon: Icon(Icons.fingerprint),
              helperText: 'Facultatif',
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: SwitchListTile(
              value: _isPrimary,
              onChanged: _vehicle?.isPrimary == true
                  ? null
                  : (value) {
                      setState(() => _isPrimary = value);
                    },
              title: const Text('Véhicule principal'),
              subtitle: Text(
                _vehicle?.isPrimary == true
                    ? 'Ce véhicule reste principal tant que vous '
                          "n'en choisissez pas un autre."
                    : 'Il sera affiché en priorité sur votre accueil.',
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "L'immatriculation et le VIN sont facultatifs. "
                  "Lors d'une identification, AutoClair ne conserve que "
                  'les données techniques que vous choisissez ensuite '
                  "d'enregistrer dans la fiche véhicule.",
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    widget.isEditing
                        ? 'Enregistrer les modifications'
                        : 'Ajouter le véhicule',
                  ),
          ),
        ],
      ),
    );
  }
}
