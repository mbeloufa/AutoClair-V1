import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/comparison_map.dart';
import '../home/nearby_location.dart';
import '../home/nearby_location_service.dart';
import '../home/nearby_radius_slider.dart';
import '../technical_control/technical_control_location_service.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'fuel_price_catalog.dart';
import 'fuel_price_service.dart';
import 'fuel_station_actions.dart';
import 'fuel_station_offer.dart';

class FuelPriceComparePage extends StatefulWidget {
  const FuelPriceComparePage({super.key});

  @override
  State<FuelPriceComparePage> createState() => _FuelPriceComparePageState();
}

class _FuelPriceComparePageState extends State<FuelPriceComparePage> {
  final _vehicleService = VehicleService();
  final _fuelPriceService = FuelPriceService();
  final _locationService = NearbyLocationService.instance;

  List<Vehicle> _vehicles = const [];
  List<FuelStationOffer> _offers = const [];

  String? _selectedVehicleId;
  String? _selectedFuelType;
  String _sortBy = 'price';
  String _viewMode = 'map';
  String? _selectedStationId;
  double _radiusKm = 20;
  NearbySearchLocation? _lastLocation;
  DateTime? _sourceFetchedAt;
  bool _cacheHit = false;
  bool _truncated = false;

  bool _loading = true;
  bool _searching = false;
  bool _settingsRequired = false;
  bool _openLocationServices = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final vehicles = await _vehicleService.fetchVehicles();
      if (!mounted) return;

      final selectedVehicle = vehicles.isEmpty ? null : vehicles.first;
      setState(() {
        _vehicles = vehicles;
        _selectedVehicleId = selectedVehicle?.id;
        _selectedFuelType =
            FuelPriceCatalog.defaultFuelForVehicle(selectedVehicle) ?? 'E10';
        _loading = false;
      });
    } on VehicleServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _loading = false;
      });
    }
  }

  void _onVehicleChanged(String? vehicleId) {
    Vehicle? selectedVehicle;
    for (final vehicle in _vehicles) {
      if (vehicle.id == vehicleId) {
        selectedVehicle = vehicle;
        break;
      }
    }

    setState(() {
      _selectedVehicleId = vehicleId;
      _selectedFuelType =
          FuelPriceCatalog.defaultFuelForVehicle(selectedVehicle) ??
          _selectedFuelType ??
          'E10';
      _resetResults();
    });
  }

  void _resetResults() {
    _offers = const [];
    _selectedStationId = null;
    _lastLocation = null;
    _sourceFetchedAt = null;
    _cacheHit = false;
    _truncated = false;
    _errorMessage = null;
  }

  Future<void> _compare() async {
    final fuelType = _selectedFuelType;
    if (fuelType == null) {
      _showMessage('Sélectionnez un carburant.');
      return;
    }

    setState(() {
      _searching = true;
      _settingsRequired = false;
      _openLocationServices = false;
      _errorMessage = null;
    });

    try {
      final location = await _locationService.resolveSearchLocation();
      await _searchAt(location, fuelType: fuelType, sortBy: _sortBy);
    } on TechnicalControlLocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _settingsRequired = error.settingsRequired;
        _openLocationServices = error.openLocationServices;
        _searching = false;
      });
    }
  }

  Future<void> _searchAt(
    NearbySearchLocation location, {
    required String fuelType,
    required String sortBy,
  }) async {
    try {
      final result = await _fuelPriceService.searchStations(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: _radiusKm,
        fuelType: fuelType,
        sortBy: sortBy,
      );

      final previousSelection = _selectedStationId;
      final selectedStationId =
          result.offers.any((offer) => offer.stationId == previousSelection)
          ? previousSelection
          : (result.offers.isEmpty ? null : result.offers.first.stationId);

      if (!mounted) return;
      setState(() {
        _lastLocation = location;
        _offers = result.offers;
        _selectedStationId = selectedStationId;
        _sourceFetchedAt = result.sourceFetchedAt;
        _cacheHit = result.cacheHit;
        _truncated = result.truncated;
        _sortBy = sortBy;
        _searching = false;
        _errorMessage = null;
        _settingsRequired = false;
        _openLocationServices = false;
      });
    } on FuelPriceServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _searching = false;
      });
    }
  }

  Future<void> _changeSort(String sortBy) async {
    if (_sortBy == sortBy) return;

    final location = _lastLocation;
    final fuelType = _selectedFuelType;
    setState(() => _sortBy = sortBy);

    if (location == null || fuelType == null) return;

    setState(() {
      _searching = true;
      _errorMessage = null;
    });
    await _searchAt(location, fuelType: fuelType, sortBy: sortBy);
  }

  Future<void> _openSettings() async {
    try {
      final opened = await _locationService.openSettings(
        locationServices: _openLocationServices,
      );
      if (!opened && mounted) {
        _showMessage(
          "Les réglages de l'application n'ont pas pu être ouverts.",
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Ouvrez les réglages de votre appareil manuellement.');
      }
    }
  }

  Future<void> _openCreateVehicle() async {
    final changed = await context.push<bool>('/vehicles/new');
    if (changed == true) await _loadVehicles();
  }

  Future<void> _openDirections(FuelStationOffer offer) async {
    try {
      final opened = await FuelStationActions.openDirections(offer);
      if (!opened && mounted) {
        _showMessage("L'itinéraire n'a pas pu être ouvert.");
      }
    } catch (_) {
      if (mounted) {
        _showMessage("L'itinéraire n'a pas pu être ouvert.");
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comparer les prix des carburants')),
      body: RefreshIndicator(
        onRefresh: _loadVehicles,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const _IntroductionCard(),
            const SizedBox(height: 20),
            if (_loading)
              const _LoadingPanel()
            else ...[
              _buildSearchForm(context),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                _ErrorPanel(
                  message: _errorMessage!,
                  settingsRequired: _settingsRequired,
                  onOpenSettings: _openSettings,
                  onRetry: _loadVehicles,
                ),
              ],
              const SizedBox(height: 24),
              _buildResults(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_vehicles.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedVehicleId,
              decoration: const InputDecoration(
                labelText: 'Véhicule',
                prefixIcon: Icon(Icons.directions_car_outlined),
              ),
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
              onChanged: _searching ? null : _onVehicleChanged,
            ),
            const SizedBox(height: 14),
          ] else ...[
            _NoVehicleHint(onCreateVehicle: _openCreateVehicle),
            const SizedBox(height: 14),
          ],
          DropdownButtonFormField<String>(
            initialValue: _selectedFuelType,
            decoration: const InputDecoration(
              labelText: 'Carburant',
              prefixIcon: Icon(Icons.local_gas_station_outlined),
            ),
            items: FuelPriceCatalog.fuelTypes
                .map(
                  (fuelType) =>
                      DropdownMenuItem(value: fuelType, child: Text(fuelType)),
                )
                .toList(growable: false),
            onChanged: _searching
                ? null
                : (value) {
                    setState(() {
                      _selectedFuelType = value;
                      _resetResults();
                    });
                  },
          ),
          const SizedBox(height: 20),
          _SearchLocationBanner(location: _locationService.sessionLocation),
          const SizedBox(height: 14),
          NearbyRadiusSlider(
            key: const ValueKey('fuel-radius-slider'),
            value: _radiusKm,
            min: 5,
            max: 50,
            divisions: 9,
            enabled: !_searching,
            onChanged: (value) {
              setState(() {
                _radiusKm = ((value / 5).round() * 5).toDouble();
                _resetResults();
              });
            },
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _searching ? null : _compare,
            icon: _searching
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.my_location_rounded),
            label: Text(
              _searching
                  ? 'Recherche en cours…'
                  : _locationService.sessionLocation == null
                  ? 'Comparer autour de moi'
                  : 'Comparer autour de ${_locationService.sessionLocation!.label}',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Votre position sert uniquement à calculer les distances et '
                  "n'est pas enregistrée dans votre compte.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_searching && _offers.isEmpty) {
      return const _MessagePanel(
        icon: Icons.location_searching_rounded,
        title: 'Recherche des stations proches',
        message: 'AutoClair consulte les prix officiels disponibles.',
        showProgress: true,
      );
    }

    if (_lastLocation == null && _offers.isEmpty) {
      return const _MessagePanel(
        icon: Icons.map_outlined,
        title: 'Les résultats apparaîtront ici',
        message:
            'Sélectionnez votre carburant puis autorisez votre position au moment de la recherche.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _offers.isEmpty
                    ? 'Aucune station trouvée'
                    : '${_offers.length} station${_offers.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_offers.isNotEmpty && _searching)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'price',
              icon: Icon(Icons.euro_rounded),
              label: Text('Prix'),
            ),
            ButtonSegment(
              value: 'distance',
              icon: Icon(Icons.near_me_outlined),
              label: Text('Distance'),
            ),
          ],
          selected: {_sortBy},
          onSelectionChanged: _searching
              ? null
              : (selection) => _changeSort(selection.first),
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: 'list',
              icon: Icon(Icons.view_list_rounded),
              label: Text('Liste'),
            ),
            ButtonSegment(
              value: 'map',
              icon: Icon(Icons.map_rounded),
              label: Text('Carte'),
            ),
          ],
          selected: {_viewMode},
          onSelectionChanged: (selection) {
            setState(() {
              _viewMode = selection.first;
              if (_selectedStationId == null && _offers.isNotEmpty) {
                _selectedStationId = _offers.first.stationId;
              }
            });
          },
        ),
        if (_sourceFetchedAt != null) ...[
          const SizedBox(height: 10),
          Text(
            'Données récupérées le ${_dateTime(_sourceFetchedAt!)}'
            '${_cacheHit ? ' • cache récent' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_truncated) ...[
          const SizedBox(height: 10),
          const _WarningBanner(
            message:
                'De nombreuses stations ont été trouvées. Seuls les meilleurs résultats sont affichés.',
          ),
        ],
        const SizedBox(height: 14),
        if (_offers.isEmpty)
          _MessagePanel(
            icon: Icons.search_off_rounded,
            title: 'Aucun prix dans ce rayon',
            message:
                'Aucune station proposant ${_selectedFuelType ?? 'ce carburant'} n’a été trouvée dans un rayon de ${_radiusKm.toInt()} km.',
          )
        else if (_viewMode == 'map')
          _buildMapResults(context)
        else
          for (var index = 0; index < _offers.length; index++) ...[
            _OfferCard(
              offer: _offers[index],
              rank: index + 1,
              onDirections: () => _openDirections(_offers[index]),
            ),
            if (index < _offers.length - 1) const SizedBox(height: 12),
          ],
        const SizedBox(height: 14),
        Text(
          'Source : données officielles Prix des carburants. Les enseignes ne sont pas fournies par le flux public.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildMapResults(BuildContext context) {
    final location = _lastLocation;
    if (location == null || _offers.isEmpty) return const SizedBox.shrink();

    FuelStationOffer selectedOffer = _offers.first;
    for (final offer in _offers) {
      if (offer.stationId == _selectedStationId) {
        selectedOffer = offer;
        break;
      }
    }

    final selectedRank =
        _offers.indexWhere(
          (offer) => offer.stationId == selectedOffer.stationId,
        ) +
        1;
    final mapHeight = (MediaQuery.sizeOf(context).height * 0.72)
        .clamp(560.0, 760.0)
        .toDouble();

    return SizedBox(
      height: mapHeight,
      child: ComparisonMapView(
        key: ValueKey(
          'fuel-map-${_selectedFuelType ?? 'fuel'}-${_sourceFetchedAt?.millisecondsSinceEpoch ?? 0}',
        ),
        userLatitude: location.latitude,
        userLongitude: location.longitude,
        markers: _offers
            .map(
              (offer) => ComparisonMapMarkerData(
                id: offer.stationId,
                latitude: offer.latitude,
                longitude: offer.longitude,
                label: _fuelMarkerLabel(offer),
                icon: Icons.local_gas_station_rounded,
                color: _fuelMarkerColor(offer),
              ),
            )
            .toList(growable: false),
        selectedMarkerId: selectedOffer.stationId,
        onMarkerSelected: (stationId) {
          setState(() => _selectedStationId = stationId);
        },
        sheetBuilder: (context, controller) => _FuelMapSheet(
          controller: controller,
          offer: selectedOffer,
          rank: selectedRank,
          sourceFetchedAt: _sourceFetchedAt,
          cacheHit: _cacheHit,
          onDirections: () => _openDirections(selectedOffer),
        ),
      ),
    );
  }

  static String _fuelMarkerLabel(FuelStationOffer offer) {
    final price = offer.price;
    if (offer.isTemporaryOutage) return 'Rupture';
    if (offer.isDefinitiveOutage) return 'Indispo.';
    if (price == null) return 'Prix N/D';
    return '${price.toStringAsFixed(3).replaceAll('.', ',')} €';
  }

  static Color _fuelMarkerColor(FuelStationOffer offer) {
    if (offer.isDefinitiveOutage) return AppColors.error;
    if (offer.isTemporaryOutage) return AppColors.warning;
    return AppColors.primary;
  }

  static String _dateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} à $hour:$minute';
  }
}

class _FuelMapSheet extends StatelessWidget {
  const _FuelMapSheet({
    required this.controller,
    required this.offer,
    required this.rank,
    required this.sourceFetchedAt,
    required this.cacheHit,
    required this.onDirections,
  });

  final ScrollController controller;
  final FuelStationOffer offer;
  final int rank;
  final DateTime? sourceFetchedAt;
  final bool cacheHit;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final price = offer.price;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.softPrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.local_gas_station_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.stationLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    offer.fullAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price == null
                      ? 'Prix N/D'
                      : '${price.toStringAsFixed(3).replaceAll('.', ',')} €',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: AppColors.primary),
                ),
                Text(
                  '${offer.distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Faites glisser ce panneau vers le haut pour afficher tous les détails.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        const Divider(),
        const SizedBox(height: 14),
        _OfferCard(offer: offer, rank: rank, onDirections: onDirections),
        if (sourceFetchedAt != null) ...[
          const SizedBox(height: 12),
          Text(
            'Données récupérées le ${_FuelPriceComparePageState._dateTime(sourceFetchedAt!)}'
            '${cacheHit ? ' • cache récent' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _SearchLocationBanner extends StatelessWidget {
  const _SearchLocationBanner({required this.location});

  final NearbySearchLocation? location;

  @override
  Widget build(BuildContext context) {
    final value = location;
    if (value == null) {
      return Text(
        'La position de votre appareil sera utilisée. Vous pouvez aussi choisir une ville depuis Autour de moi.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softPrimary,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, color: AppColors.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Zone : ${value.label}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroductionCard extends StatelessWidget {
  const _IntroductionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.local_gas_station_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Le carburant au meilleur prix autour de vous',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Prix officiels, disponibilité déclarée et distance depuis votre position.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _NoVehicleHint extends StatelessWidget {
  const _NoVehicleHint({required this.onCreateVehicle});

  final VoidCallback onCreateVehicle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car_outlined, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Vous pouvez comparer sans véhicule ou en ajouter un pour préremplir le carburant.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onCreateVehicle, child: const Text('Ajouter')),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.settingsRequired,
    required this.onOpenSettings,
    required this.onRetry,
  });

  final String message;
  final bool settingsRequired;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          const SizedBox(height: 12),
          if (settingsRequired)
            OutlinedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Ouvrir les réglages'),
            )
          else
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (showProgress)
            const SizedBox.square(
              dimension: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          else
            Icon(icon, size: 40, color: AppColors.primary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.rank,
    required this.onDirections,
  });

  final FuelStationOffer offer;
  final int rank;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final availability = _availability(offer);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.stationLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (offer.fullAddress.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        offer.fullAddress,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    offer.price == null ? 'Indisponible' : _price(offer.price!),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: offer.price == null
                          ? AppColors.warning
                          : AppColors.primary,
                      fontSize: offer.price == null ? 16 : 24,
                    ),
                  ),
                  Text(
                    '${_number(offer.distanceKm)} km',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.local_gas_station_outlined,
                label: offer.fuelType,
              ),
              _InfoChip(icon: availability.icon, label: availability.label),
              if (offer.automate24h)
                const _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: 'Automate 24/24',
                ),
            ],
          ),
          if (offer.priceUpdatedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Prix actualisé le ${_dateTime(offer.priceUpdatedAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (offer.outageStartedAt != null && !offer.isAvailable) ...[
            const SizedBox(height: 7),
            Text(
              'Rupture déclarée depuis le ${_date(offer.outageStartedAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (offer.services.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Services', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              offer.services.take(4).join(' • '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 15),
          const Divider(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDirections,
              icon: const Icon(Icons.route_outlined),
              label: const Text('Itinéraire'),
            ),
          ),
        ],
      ),
    );
  }

  static _AvailabilityPresentation _availability(FuelStationOffer offer) {
    if (offer.isAvailable) {
      return const _AvailabilityPresentation(
        icon: Icons.check_circle_outline,
        label: 'Disponible',
      );
    }
    if (offer.isTemporaryOutage) {
      return const _AvailabilityPresentation(
        icon: Icons.schedule_outlined,
        label: 'Rupture temporaire',
      );
    }
    if (offer.isDefinitiveOutage) {
      return const _AvailabilityPresentation(
        icon: Icons.block_outlined,
        label: 'Rupture définitive',
      );
    }
    return const _AvailabilityPresentation(
      icon: Icons.help_outline,
      label: 'Disponibilité inconnue',
    );
  }

  static String _price(double value) =>
      '${value.toStringAsFixed(3).replaceAll('.', ',')} €/L';

  static String _number(double value) {
    final isWhole = (value - value.roundToDouble()).abs() < 0.001;
    return isWhole
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2).replaceAll('.', ',');
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  static String _dateTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${_date(local)} à $hour:$minute';
  }
}

class _AvailabilityPresentation {
  const _AvailabilityPresentation({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
