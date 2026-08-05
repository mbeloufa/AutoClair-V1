import 'package:flutter/material.dart';

import '../../core/finance/money_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../fuel_prices/fuel_price_catalog.dart';
import '../fuel_prices/fuel_price_service.dart';
import '../fuel_prices/fuel_station_actions.dart';
import '../home/nearby_location_service.dart';
import '../home/nearby_radius_slider.dart';
import '../technical_control/technical_control_location_service.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'fuel_optimization_models.dart';
import 'fuel_optimizer_service.dart';
import 'fuel_saving_calculator.dart';

class FuelOptimizerPage extends StatefulWidget {
  const FuelOptimizerPage({super.key});

  @override
  State<FuelOptimizerPage> createState() => _FuelOptimizerPageState();
}

class _FuelOptimizerPageState extends State<FuelOptimizerPage> {
  final _vehicleService = VehicleService();
  final _priceService = FuelPriceService();
  final _optimizerService = FuelOptimizerService();
  final _locationService = NearbyLocationService.instance;
  final _volumeController = TextEditingController(text: '40');
  final _consumptionController = TextEditingController(text: '6.5');

  List<Vehicle> _vehicles = const [];
  List<FuelOptimizationResult> _results = const [];
  String? _vehicleId;
  String _fuelType = 'E10';
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
    _volumeController.dispose();
    _consumptionController.dispose();
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
      final selected = vehicles.isEmpty
          ? null
          : vehicles.firstWhere(
              (vehicle) => vehicle.isPrimary,
              orElse: () => vehicles.first,
            );
      setState(() {
        _vehicles = vehicles;
        _vehicleId = selected?.id;
        _fuelType = FuelPriceCatalog.defaultFuelForVehicle(selected) ?? 'E10';
        _loading = false;
      });
      if (selected != null) await _loadProfile(selected.id);
    } on VehicleServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _loadProfile(String vehicleId) async {
    final profile = await _optimizerService.loadProfile(vehicleId);
    if (!mounted || profile == null) return;
    setState(() {
      _volumeController.text = profile.usualFillLiters.toStringAsFixed(0);
      _consumptionController.text = profile.consumptionLitersPer100Km
          .toStringAsFixed(1);
    });
  }

  Future<void> _changeVehicle(String? vehicleId) async {
    if (vehicleId == null) return;
    Vehicle? selected;
    for (final vehicle in _vehicles) {
      if (vehicle.id == vehicleId) selected = vehicle;
    }
    setState(() {
      _vehicleId = vehicleId;
      _fuelType = FuelPriceCatalog.defaultFuelForVehicle(selected) ?? _fuelType;
      _results = const [];
    });
    await _loadProfile(vehicleId);
  }

  Future<void> _search() async {
    final vehicle = _vehicle;
    if (vehicle == null) {
      _show('Ajoutez un véhicule avant d’optimiser un plein.');
      return;
    }
    final volume = double.tryParse(
      _volumeController.text.trim().replaceAll(',', '.'),
    );
    final consumption = double.tryParse(
      _consumptionController.text.trim().replaceAll(',', '.'),
    );
    if (volume == null || volume <= 0 || volume > 200) {
      _show('Saisissez un volume compris entre 1 et 200 litres.');
      return;
    }
    if (consumption == null || consumption <= 0 || consumption > 40) {
      _show('Saisissez une consommation réaliste.');
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
      _settingsRequired = false;
      _openLocationServices = false;
    });

    try {
      await _optimizerService.saveProfile(
        vehicleId: vehicle.id,
        consumption: consumption,
        fillLiters: volume,
      );
      final location = await _locationService.resolveSearchLocation();
      final searchResult = await _priceService.searchStations(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: _radiusKm,
        fuelType: _fuelType,
        sortBy: 'distance',
        resultLimit: 50,
      );
      final calculated = FuelSavingCalculator.calculate(
        offers: searchResult.offers,
        input: FuelOptimizationInput(
          volumeLiters: volume,
          consumptionLitersPer100Km: consumption,
          detourMultiplier: 2,
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
    } on FuelPriceServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _searching = false;
      });
    } on FuelOptimizerException catch (error) {
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
    }
  }

  Future<void> _openSettings() async {
    await _locationService.openSettings(
      locationServices: _openLocationServices,
    );
  }

  Future<void> _confirm(FuelOptimizationResult result) async {
    final vehicle = _vehicle;
    final volume = double.tryParse(
      _volumeController.text.trim().replaceAll(',', '.'),
    );
    if (vehicle == null || volume == null) return;
    try {
      await _optimizerService.confirmFill(
        vehicleId: vehicle.id,
        result: result,
        volumeLiters: volume,
      );
      if (!mounted) return;
      _show('Plein et économie confirmés dans votre budget.');
    } on FuelOptimizerException catch (error) {
      if (!mounted) return;
      _show(error.message);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Optimiser mon plein')),
      body: RefreshIndicator(
        onRefresh: _loadVehicles,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const _FuelOptimizerIntro(),
            const SizedBox(height: 18),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_vehicles.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Ajoutez un véhicule pour utiliser ce calcul.'),
                ),
              )
            else ...[
              _buildForm(),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _FuelError(
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
          children: [
            DropdownButtonFormField<String>(
              initialValue: _vehicleId,
              decoration: const InputDecoration(labelText: 'Véhicule'),
              items: _vehicles
                  .map(
                    (vehicle) => DropdownMenuItem(
                      value: vehicle.id,
                      child: Text(vehicle.displayName),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _changeVehicle,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _fuelType,
              decoration: const InputDecoration(labelText: 'Carburant'),
              items: FuelPriceCatalog.fuelTypes
                  .map(
                    (fuel) => DropdownMenuItem(value: fuel, child: Text(fuel)),
                  )
                  .toList(growable: false),
              onChanged: (value) =>
                  setState(() => _fuelType = value ?? _fuelType),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('fuel-optimizer-volume'),
                    controller: _volumeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Volume prévu (L)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('fuel-optimizer-consumption'),
                    controller: _consumptionController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Conso. (L/100)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            NearbyRadiusSlider(
              value: _radiusKm,
              min: 5,
              max: 50,
              divisions: 9,
              title: 'Rayon maximal',
              onChanged: (value) => setState(() => _radiusKm = value),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('fuel-optimizer-search'),
              onPressed: _searching ? null : _search,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Calculer l’économie réelle'),
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
          padding: EdgeInsets.all(24),
          child: Text(
            'Lancez un calcul pour comparer les stations après déduction '
            'du coût du détour.',
          ),
        ),
      );
    }

    final worthwhile = _results
        .where((result) => result.isWorthwhile)
        .take(12)
        .toList(growable: false);
    if (worthwhile.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucune station ne génère une économie nette positive dans '
            'ce rayon. La station la plus proche reste le meilleur choix.',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meilleures économies',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final result in worthwhile) ...[
          _FuelOptimizationCard(
            result: result,
            onDirections: () => FuelStationActions.openDirections(result.offer),
            onConfirm: () => _confirm(result),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _FuelOptimizerIntro extends StatelessWidget {
  const _FuelOptimizerIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_gas_station_outlined, color: AppColors.success),
          SizedBox(height: 10),
          Text(
            'Le prix le plus bas n’est pas toujours le moins cher.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'AutoClair déduit le carburant consommé pour le détour avant '
            'd’annoncer une économie.',
          ),
        ],
      ),
    );
  }
}

class _FuelOptimizationCard extends StatelessWidget {
  const _FuelOptimizationCard({
    required this.result,
    required this.onDirections,
    required this.onConfirm,
  });

  final FuelOptimizationResult result;
  final VoidCallback onDirections;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final offer = result.offer;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.successSoft,
                  child: Icon(
                    Icons.local_gas_station,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.city.isEmpty ? offer.stationLabel : offer.city,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(offer.fullAddress),
                      Text(
                        result.freshnessLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${offer.price!.toStringAsFixed(3)} €/L',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ResultLine(label: 'Prix du plein', value: result.fillCost),
            _ResultLine(
              label: 'Économie à la pompe',
              value: result.grossSaving,
            ),
            _ResultLine(
              label: 'Coût estimé du détour',
              value: -result.detourCost,
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Économie réelle estimée',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  MoneyFormatter.euros(result.netSaving),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Détour supplémentaire estimé : '
              '${result.detourDistanceKm.toStringAsFixed(1)} km',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDirections,
                    child: const Text('Itinéraire'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onConfirm,
                    child: const Text('Plein effectué'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(MoneyFormatter.euros(value)),
        ],
      ),
    );
  }
}

class _FuelError extends StatelessWidget {
  const _FuelError({
    required this.message,
    required this.settingsRequired,
    required this.onSettings,
  });

  final String message;
  final bool settingsRequired;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
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
