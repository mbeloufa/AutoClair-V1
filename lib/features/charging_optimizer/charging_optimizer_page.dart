import 'package:flutter/material.dart';

import '../../core/finance/money_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../charging_prices/charging_actions.dart';
import '../charging_prices/charging_catalog.dart';
import '../home/nearby_location_service.dart';
import '../home/nearby_radius_slider.dart';
import '../technical_control/technical_control_location_service.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'charging_optimizer_calculator.dart';
import 'charging_optimizer_models.dart';
import 'charging_optimizer_service.dart';

class ChargingOptimizerPage extends StatefulWidget {
  const ChargingOptimizerPage({super.key});

  @override
  State<ChargingOptimizerPage> createState() => _ChargingOptimizerPageState();
}

class _ChargingOptimizerPageState extends State<ChargingOptimizerPage> {
  final _vehicleService = VehicleService();
  final _optimizerService = ChargingOptimizerService();
  final _locationService = NearbyLocationService.instance;

  final _energyController = TextEditingController(text: '40');
  final _consumptionController = TextEditingController(text: '18');
  final _referencePriceController = TextEditingController(text: '0.45');
  final _maxPowerController = TextEditingController(text: '100');

  List<Vehicle> _vehicles = const [];
  List<ChargingOptimizationResult> _results = const [];
  String? _vehicleId;
  String _connector = 'any';
  double _minimumPowerKw = 0;
  double _radiusKm = 20;
  bool _loading = true;
  bool _searching = false;
  bool _settingsRequired = false;
  bool _openLocationServices = false;
  String? _error;

  Vehicle? get _vehicle {
    for (final vehicle in _vehicles) {
      if (vehicle.id == _vehicleId) return vehicle;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _energyController.dispose();
    _consumptionController.dispose();
    _referencePriceController.dispose();
    _maxPowerController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vehicles = await _vehicleService.fetchVehicles();
      if (!mounted) return;
      Vehicle? selected;
      for (final vehicle in vehicles) {
        if (ChargingCatalog.isElectricVehicle(vehicle)) {
          selected = vehicle;
          break;
        }
      }
      selected ??= vehicles.isEmpty
          ? null
          : vehicles.firstWhere(
              (vehicle) => vehicle.isPrimary,
              orElse: () => vehicles.first,
            );
      setState(() {
        _vehicles = vehicles;
        _vehicleId = selected?.id;
        _connector = ChargingCatalog.defaultConnectorForVehicle(selected);
        _loading = false;
      });
      if (selected != null) await _loadProfile(selected.id);
    } on VehicleServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadProfile(String vehicleId) async {
    try {
      final profile = await _optimizerService.loadProfile(vehicleId);
      if (!mounted || profile == null) return;
      setState(() {
        _energyController.text = profile.usualChargeKwh.toStringAsFixed(0);
        _consumptionController.text = profile.consumptionKwhPer100Km
            .toStringAsFixed(1);
        _referencePriceController.text = profile.referencePricePerKwh
            .toStringAsFixed(2);
        _maxPowerController.text = profile.maxChargingPowerKw.toStringAsFixed(
          0,
        );
        _connector = profile.connector;
      });
    } on ChargingOptimizerException catch (error) {
      if (mounted) _show(error.message);
    }
  }

  Future<void> _changeVehicle(String? vehicleId) async {
    if (vehicleId == null) return;
    Vehicle? selected;
    for (final vehicle in _vehicles) {
      if (vehicle.id == vehicleId) selected = vehicle;
    }
    setState(() {
      _vehicleId = vehicleId;
      _connector = ChargingCatalog.defaultConnectorForVehicle(selected);
      _results = const [];
    });
    await _loadProfile(vehicleId);
  }

  Future<void> _search() async {
    final vehicle = _vehicle;
    if (vehicle == null) {
      _show('Ajoutez un véhicule avant d’optimiser une recharge.');
      return;
    }

    final energy = _number(_energyController);
    final consumption = _number(_consumptionController);
    final referencePrice = _number(_referencePriceController);
    final maxPower = _number(_maxPowerController);
    if (energy == null ||
        consumption == null ||
        referencePrice == null ||
        maxPower == null) {
      _show('Vérifiez les valeurs numériques du profil de recharge.');
      return;
    }

    final profile = VehicleChargingProfile(
      consumptionKwhPer100Km: consumption,
      usualChargeKwh: energy,
      referencePricePerKwh: referencePrice,
      maxChargingPowerKw: maxPower,
      connector: _connector,
    );

    setState(() {
      _searching = true;
      _error = null;
      _settingsRequired = false;
      _openLocationServices = false;
    });

    try {
      await _optimizerService.saveProfile(
        vehicleId: vehicle.id,
        profile: profile,
      );
      final location = await _locationService.resolveSearchLocation();
      final searchResult = await _optimizerService.searchStations(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: _radiusKm,
        connector: _connector,
        minimumPowerKw: _minimumPowerKw,
        energyKwh: energy,
      );
      final calculated = ChargingOptimizerCalculator.calculate(
        offers: searchResult.offers,
        input: ChargingOptimizationInput(
          energyKwh: energy,
          consumptionKwhPer100Km: consumption,
          referencePricePerKwh: referencePrice,
          vehicleMaxPowerKw: maxPower,
        ),
      );
      if (!mounted) return;
      setState(() {
        _results = calculated;
        _searching = false;
      });
    } on TechnicalControlLocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _settingsRequired = error.settingsRequired;
        _openLocationServices = error.openLocationServices;
        _searching = false;
      });
    } on ChargingOptimizerException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _searching = false;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de calculer les coûts de recharge.';
        _searching = false;
      });
    }
  }

  Future<void> _confirm(ChargingOptimizationResult result) async {
    final vehicle = _vehicle;
    final energy = _number(_energyController);
    if (vehicle == null || energy == null) return;
    try {
      await _optimizerService.confirmSession(
        vehicleId: vehicle.id,
        result: result,
        energyKwh: energy,
      );
      if (!mounted) return;
      _show(
        result.isWorthwhile
            ? 'Recharge et économie confirmées dans votre budget.'
            : 'Recharge ajoutée à votre budget.',
      );
    } on ChargingOptimizerException catch (error) {
      if (mounted) _show(error.message);
    }
  }

  Future<void> _openDirections(ChargingOptimizationResult result) async {
    try {
      final opened = await ChargingActions.openDirections(result.offer);
      if (!opened && mounted) {
        _show("L’itinéraire n’a pas pu être ouvert.");
      }
    } catch (_) {
      if (mounted) _show("L’itinéraire n’a pas pu être ouvert.");
    }
  }

  Future<void> _openSettings() async {
    await _locationService.openSettings(
      locationServices: _openLocationServices,
    );
  }

  double? _number(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', '.'));
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Optimiser ma recharge')),
      body: RefreshIndicator(
        onRefresh: _loadVehicles,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const _ChargingOptimizerIntro(),
            const SizedBox(height: 18),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_vehicles.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Ajoutez un véhicule électrique ou hybride rechargeable.',
                  ),
                ),
              )
            else ...[
              _buildForm(),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _ChargingError(
                  message: _error!,
                  settingsRequired: _settingsRequired,
                  onSettings: _openSettings,
                ),
              ],
              const SizedBox(height: 20),
              if (_searching)
                const Center(child: CircularProgressIndicator())
              else
                _buildResults(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _vehicleId,
              decoration: const InputDecoration(labelText: 'Véhicule'),
              items: _vehicles
                  .map(
                    (vehicle) => DropdownMenuItem(
                      value: vehicle.id,
                      child: Text(
                        vehicle.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _searching ? null : _changeVehicle,
            ),
            if (!ChargingCatalog.isElectricVehicle(_vehicle)) ...[
              const SizedBox(height: 10),
              const Text(
                'Vérifiez le type d’énergie du véhicule avant de poursuivre.',
                style: TextStyle(color: AppColors.warning),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _connector,
              decoration: const InputDecoration(labelText: 'Connecteur'),
              items: ChargingCatalog.connectors
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.id,
                      child: Text(option.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _searching
                  ? null
                  : (value) => setState(() => _connector = value ?? _connector),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('charging-optimizer-energy'),
              controller: _energyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Énergie à ajouter (kWh)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('charging-optimizer-consumption'),
              controller: _consumptionController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Consommation (kWh/100 km)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('charging-optimizer-reference-price'),
              controller: _referencePriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Tarif habituel de référence (€/kWh)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('charging-optimizer-max-power'),
              controller: _maxPowerController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Puissance maximale du véhicule (kW)',
              ),
            ),
            const SizedBox(height: 14),
            NearbyRadiusSlider(
              value: _minimumPowerKw,
              min: 0,
              max: 150,
              divisions: 6,
              enabled: !_searching,
              title: 'Puissance minimale de la borne',
              unit: 'kW',
              icon: Icons.bolt_outlined,
              onChanged: (value) => setState(() => _minimumPowerKw = value),
            ),
            const SizedBox(height: 12),
            NearbyRadiusSlider(
              value: _radiusKm,
              min: 5,
              max: 50,
              divisions: 9,
              enabled: !_searching,
              title: 'Rayon maximal',
              onChanged: (value) => setState(() => _radiusKm = value),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('charging-optimizer-search'),
              onPressed: _searching ? null : _search,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Comparer le coût complet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_results.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Text(
            'Lancez une recherche. Les bornes dont le tarif n’est pas '
            'comparable ne seront pas classées financièrement.',
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_results.length} offre(s) comparable(s)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        for (final result in _results) ...[
          _ChargingResultCard(
            result: result,
            onDirections: () => _openDirections(result),
            onConfirm: () => _confirm(result),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ChargingOptimizerIntro extends StatelessWidget {
  const _ChargingOptimizerIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.softPrimary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.electric_bolt_outlined,
            color: AppColors.primary,
            size: 32,
          ),
          SizedBox(height: 12),
          Text(
            'Comparez la recharge, le coût d’accès et le temps théorique.',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 7),
          Text(
            'Le tarif publié par l’opérateur reste la référence avant paiement.',
          ),
        ],
      ),
    );
  }
}

class _ChargingResultCard extends StatelessWidget {
  const _ChargingResultCard({
    required this.result,
    required this.onDirections,
    required this.onConfirm,
  });

  final ChargingOptimizationResult result;
  final VoidCallback onDirections;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final savingColor = result.isWorthwhile
        ? AppColors.success
        : AppColors.textMuted;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.offer.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (result.offer.secondaryName.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(result.offer.secondaryName),
            ],
            const SizedBox(height: 5),
            Text(result.offer.address),
            const SizedBox(height: 14),
            _MetricLine(
              label: 'Recharge à la borne',
              value: MoneyFormatter.euros(result.stationEnergyCost),
            ),
            _MetricLine(
              label: 'Coût estimé de l’accès',
              value: MoneyFormatter.euros(result.accessCost),
            ),
            const Divider(height: 22),
            _MetricLine(
              label: 'Coût complet estimé',
              value: MoneyFormatter.euros(result.totalEstimatedCost),
              emphasized: true,
            ),
            _MetricLine(
              label: 'Tarif habituel de référence',
              value: MoneyFormatter.euros(result.referenceCost),
            ),
            _MetricLine(
              label: result.isWorthwhile
                  ? 'Économie estimée'
                  : 'Écart par rapport à l’habitude',
              value: MoneyFormatter.euros(result.netSaving),
              valueColor: savingColor,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  icon: Icons.route_outlined,
                  label: '${result.accessDistanceKm.toStringAsFixed(1)} km A/R',
                ),
                _Chip(
                  icon: Icons.schedule_outlined,
                  label: '≈ ${result.estimatedDurationMinutes} min théoriques',
                ),
                _Chip(
                  icon: Icons.euro_outlined,
                  label:
                      '${result.effectivePricePerKwh.toStringAsFixed(2)} €/kWh réel',
                ),
                _Chip(
                  icon: Icons.bolt_outlined,
                  label:
                      '${result.effectivePowerKw.toStringAsFixed(0)} kW utiles',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(result.freshnessLabel),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onDirections,
              icon: const Icon(Icons.directions_outlined),
              label: const Text('Itinéraire'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirmer cette recharge'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: style?.copyWith(
                color: valueColor,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ChargingError extends StatelessWidget {
  const _ChargingError({
    required this.message,
    required this.settingsRequired,
    required this.onSettings,
  });

  final String message;
  final bool settingsRequired;
  final Future<void> Function() onSettings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            if (settingsRequired) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onSettings,
                child: const Text('Ouvrir les réglages'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
