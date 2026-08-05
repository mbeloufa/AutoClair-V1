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
import 'charging_actions.dart';
import 'charging_catalog.dart';
import 'charging_service.dart';
import 'charging_station_offer.dart';

class ChargingComparePage extends StatefulWidget {
  const ChargingComparePage({super.key});

  @override
  State<ChargingComparePage> createState() => _ChargingComparePageState();
}

class _ChargingComparePageState extends State<ChargingComparePage> {
  final _vehicleService = VehicleService();
  final _chargingService = ChargingService();
  final _locationService = NearbyLocationService.instance;

  List<Vehicle> _vehicles = const [];
  List<ChargingStationOffer> _offers = const [];

  String? _selectedVehicleId;
  String _connector = 'any';
  String _sortBy = 'price';
  String _viewMode = 'map';
  String? _selectedStationId;
  double _minimumPowerKw = 0;
  double _energyKwh = 40;
  double _radiusKm = 20;
  NearbySearchLocation? _lastLocation;
  DateTime? _sourceFetchedAt;
  String _sourceName = 'Base nationale IRVE';
  String _pricingDisclaimer =
      'Le tarif publié par l’opérateur reste la référence.';
  bool _cacheHit = false;
  bool _truncated = false;

  bool _loading = true;
  bool _searching = false;
  bool _settingsRequired = false;
  bool _openLocationServices = false;
  String? _errorMessage;

  Vehicle? get _selectedVehicle {
    for (final vehicle in _vehicles) {
      if (vehicle.id == _selectedVehicleId) return vehicle;
    }
    return null;
  }

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

      Vehicle? selectedVehicle;
      for (final vehicle in vehicles) {
        if (ChargingCatalog.isElectricVehicle(vehicle)) {
          selectedVehicle = vehicle;
          break;
        }
      }
      selectedVehicle ??= vehicles.isEmpty ? null : vehicles.first;

      setState(() {
        _vehicles = vehicles;
        _selectedVehicleId = selectedVehicle?.id;
        _connector = ChargingCatalog.defaultConnectorForVehicle(
          selectedVehicle,
        );
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
    Vehicle? selected;
    for (final vehicle in _vehicles) {
      if (vehicle.id == vehicleId) {
        selected = vehicle;
        break;
      }
    }

    setState(() {
      _selectedVehicleId = vehicleId;
      _connector = ChargingCatalog.defaultConnectorForVehicle(selected);
      _resetResults();
    });
  }

  void _resetResults() {
    _offers = const [];
    _selectedStationId = null;
    _lastLocation = null;
    _sourceFetchedAt = null;
    _sourceName = 'Base nationale IRVE';
    _pricingDisclaimer = 'Le tarif publié par l’opérateur reste la référence.';
    _cacheHit = false;
    _truncated = false;
    _errorMessage = null;
  }

  Future<void> _compare() async {
    setState(() {
      _searching = true;
      _settingsRequired = false;
      _openLocationServices = false;
      _errorMessage = null;
    });

    try {
      final location = await _locationService.resolveSearchLocation();
      await _searchAt(location, sortBy: _sortBy);
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
    required String sortBy,
  }) async {
    try {
      final result = await _chargingService.searchStations(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: _radiusKm,
        connector: _connector,
        minimumPowerKw: _minimumPowerKw,
        energyKwh: _energyKwh,
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
        _sourceName = result.sourceName;
        _pricingDisclaimer = result.pricingDisclaimer;
        _cacheHit = result.cacheHit;
        _truncated = result.truncated;
        _energyKwh = result.energyKwh;
        _sortBy = sortBy;
        _searching = false;
        _errorMessage = null;
        _settingsRequired = false;
        _openLocationServices = false;
      });
    } on ChargingServiceException catch (error) {
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
    setState(() => _sortBy = sortBy);
    if (location == null) return;

    setState(() {
      _searching = true;
      _errorMessage = null;
    });
    await _searchAt(location, sortBy: sortBy);
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

  Future<void> _openDirections(ChargingStationOffer offer) async {
    try {
      final opened = await ChargingActions.openDirections(offer);
      if (!opened && mounted) {
        _showMessage("L'itinéraire n'a pas pu être ouvert.");
      }
    } catch (_) {
      if (mounted) _showMessage("L'itinéraire n'a pas pu être ouvert.");
    }
  }

  Future<void> _callOperator(ChargingStationOffer offer) async {
    try {
      final opened = await ChargingActions.callOperator(offer);
      if (!opened && mounted) {
        _showMessage("Le numéro de l'opérateur n'est pas disponible.");
      }
    } catch (_) {
      if (mounted) _showMessage("L'appel n'a pas pu être lancé.");
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
      appBar: AppBar(title: const Text('Comparer les tarifs de recharge')),
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
                prefixIcon: Icon(Icons.electric_car_outlined),
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
            if (!ChargingCatalog.isElectricVehicle(_selectedVehicle)) ...[
              const SizedBox(height: 10),
              const _InlineHint(
                icon: Icons.info_outline,
                message:
                    'Le véhicule sélectionné n’est pas identifié comme électrique ou hybride rechargeable. Les filtres restent utilisables manuellement.',
              ),
            ],
            const SizedBox(height: 14),
          ] else ...[
            _NoVehicleHint(onCreateVehicle: _openCreateVehicle),
            const SizedBox(height: 14),
          ],
          DropdownButtonFormField<String>(
            initialValue: _connector,
            decoration: const InputDecoration(
              labelText: 'Connecteur',
              prefixIcon: Icon(Icons.ev_station_outlined),
            ),
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
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _connector = value;
                      _resetResults();
                    });
                  },
          ),
          const SizedBox(height: 14),
          _ChargingPowerSlider(
            value: _minimumPowerKw,
            enabled: !_searching,
            onChanged: (value) {
              setState(() {
                _minimumPowerKw = value;
                _resetResults();
              });
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Quantité à recharger',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          Text(
            'Quantité d’électricité que vous prévoyez d’ajouter à la batterie. Elle sert uniquement à estimer le coût.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final energy in ChargingCatalog.energyChoicesKwh)
                ChoiceChip(
                  label: Text('${energy.toInt()} kWh'),
                  selected: _energyKwh == energy,
                  onSelected: _searching
                      ? null
                      : (selected) {
                          if (!selected) return;
                          setState(() {
                            _energyKwh = energy;
                            _resetResults();
                          });
                        },
                ),
            ],
          ),
          const SizedBox(height: 20),
          _SearchLocationBanner(location: _locationService.sessionLocation),
          const SizedBox(height: 14),
          NearbyRadiusSlider(
            key: const ValueKey('charging-radius-slider'),
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
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search_rounded),
            label: Text(
              _searching
                  ? 'Recherche en cours…'
                  : _locationService.sessionLocation == null
                  ? 'Comparer autour de moi'
                  : 'Comparer autour de ${_locationService.sessionLocation!.label}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_searching && _lastLocation == null) {
      return const _MessagePanel(
        icon: Icons.ev_station_rounded,
        title: 'Recherche des bornes',
        message: 'Nous recherchons les stations compatibles autour de vous.',
        showProgress: true,
      );
    }

    if (_lastLocation == null) {
      return const _MessagePanel(
        icon: Icons.ev_station_outlined,
        title: 'Prêt pour la comparaison',
        message:
            'Choisissez vos critères puis autorisez la localisation pour afficher les bornes proches.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_offers.length} station${_offers.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_searching)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          showSelectedIcon: false,
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
            ButtonSegment(
              value: 'power',
              icon: Icon(Icons.bolt_rounded),
              label: Text('Puissance'),
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
        const SizedBox(height: 10),
        _WarningBanner(message: _pricingDisclaimer),
        if (_truncated) ...[
          const SizedBox(height: 10),
          const _WarningBanner(
            message:
                'Le nombre de points dans ce rayon dépasse la limite de lecture. Affinez le rayon ou la puissance pour une comparaison plus complète.',
          ),
        ],
        const SizedBox(height: 14),
        if (_offers.isEmpty)
          _MessagePanel(
            icon: Icons.search_off_rounded,
            title: 'Aucune borne dans ce rayon',
            message:
                'Aucune station correspondant à ${ChargingCatalog.connectorLabel(_connector).toLowerCase()} et ${ChargingCatalog.powerLabel(_minimumPowerKw).toLowerCase()} n’a été trouvée dans un rayon de ${_radiusKm.toInt()} km.',
          )
        else if (_viewMode == 'map')
          _buildMapResults(context)
        else
          for (var index = 0; index < _offers.length; index++) ...[
            _OfferCard(
              offer: _offers[index],
              rank: index + 1,
              energyKwh: _energyKwh,
              onDirections: () => _openDirections(_offers[index]),
              onCall: _offers[index].hasPhone
                  ? () => _callOperator(_offers[index])
                  : null,
            ),
            if (index < _offers.length - 1) const SizedBox(height: 12),
          ],
        const SizedBox(height: 14),
        Text(
          'Source : $_sourceName. Les tarifs sont déclaratifs et peuvent dépendre du badge, de l’abonnement, du temps de recharge ou de frais annexes.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildMapResults(BuildContext context) {
    final location = _lastLocation;
    if (location == null || _offers.isEmpty) return const SizedBox.shrink();

    ChargingStationOffer selectedOffer = _offers.first;
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
          'charging-map-$_connector-${_energyKwh.toInt()}-${_sourceFetchedAt?.millisecondsSinceEpoch ?? 0}',
        ),
        userLatitude: location.latitude,
        userLongitude: location.longitude,
        markers: _offers
            .map(
              (offer) => ComparisonMapMarkerData(
                id: offer.stationId,
                latitude: offer.latitude,
                longitude: offer.longitude,
                label: _chargingMarkerLabel(offer),
                icon: Icons.ev_station_rounded,
                color: _chargingMarkerColor(offer),
              ),
            )
            .toList(growable: false),
        selectedMarkerId: selectedOffer.stationId,
        onMarkerSelected: (stationId) {
          setState(() => _selectedStationId = stationId);
        },
        sheetBuilder: (context, controller) => _ChargingMapSheet(
          controller: controller,
          offer: selectedOffer,
          rank: selectedRank,
          energyKwh: _energyKwh,
          sourceName: _sourceName,
          onDirections: () => _openDirections(selectedOffer),
          onCall: selectedOffer.hasPhone
              ? () => _callOperator(selectedOffer)
              : null,
        ),
      ),
    );
  }

  String _chargingMarkerLabel(ChargingStationOffer offer) {
    if (offer.isFree || offer.pricingKind == 'free') return 'Gratuit';
    if (offer.pricingComparable && offer.estimatedCost != null) {
      return '≈ ${offer.estimatedCost!.toStringAsFixed(2).replaceAll('.', ',')} €';
    }
    return '${offer.maxPowerKw.toStringAsFixed(0)} kW';
  }

  static Color _chargingMarkerColor(ChargingStationOffer offer) {
    if (offer.isFree || offer.pricingKind == 'free') return AppColors.success;
    if (offer.pricingComparable) return AppColors.accent;
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

class _ChargingMapSheet extends StatelessWidget {
  const _ChargingMapSheet({
    required this.controller,
    required this.offer,
    required this.rank,
    required this.energyKwh,
    required this.sourceName,
    required this.onDirections,
    required this.onCall,
  });

  final ScrollController controller;
  final ChargingStationOffer offer;
  final int rank;
  final double energyKwh;
  final String sourceName;
  final VoidCallback onDirections;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final comparable = offer.isFree || offer.pricingComparable;
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
                color: AppColors.infoSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.ev_station_rounded,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    offer.address,
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
                  offer.pricingLabel(energyKwh),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: comparable ? AppColors.success : AppColors.text,
                  ),
                ),
                Text(
                  '${offer.distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km • ${offer.maxPowerKw.toStringAsFixed(0)} kW',
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
        _OfferCard(
          offer: offer,
          rank: rank,
          energyKwh: energyKwh,
          onDirections: onDirections,
          onCall: onCall,
        ),
        const SizedBox(height: 12),
        Text(
          'Source : $sourceName. Le tarif publié par l’opérateur reste la référence.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ChargingPowerSlider extends StatelessWidget {
  const _ChargingPowerSlider({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final values = ChargingCatalog.minimumPowersKw;
    var index = values.indexOf(value);
    if (index < 0) index = 0;
    return Container(
      key: const ValueKey('charging-power-slider'),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.softPrimary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Puissance minimale',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                ChargingCatalog.powerLabel(value),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: index.toDouble(),
            min: 0,
            max: (values.length - 1).toDouble(),
            divisions: values.length - 1,
            label: ChargingCatalog.powerLabel(value),
            onChanged: enabled ? (raw) => onChanged(values[raw.round()]) : null,
          ),
        ],
      ),
    );
  }
}

class _SearchLocationBanner extends StatelessWidget {
  const _SearchLocationBanner({required this.location});

  final NearbySearchLocation? location;

  @override
  Widget build(BuildContext context) {
    final value = location;
    return Text(
      value == null
          ? 'La position de votre appareil sera utilisée. Une ville peut être choisie depuis Autour de moi.'
          : 'Zone de recherche : ${value.label}',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: value == null ? null : AppColors.primary,
        fontWeight: value == null ? null : FontWeight.w800,
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
          colors: [AppColors.primaryDark, AppColors.accent],
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
              Icons.ev_station_rounded,
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
                  'Comparez les bornes autour de vous',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Compatibilité, puissance, distance et estimation prudente du coût de recharge.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
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
          const Icon(Icons.electric_car_outlined, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Vous pouvez comparer sans véhicule ou en ajouter un pour personnaliser progressivement les filtres.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onCreateVehicle, child: const Text('Ajouter')),
        ],
      ),
    );
  }
}

class _InlineHint extends StatelessWidget {
  const _InlineHint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.info),
        const SizedBox(width: 7),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
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
    required this.energyKwh,
    required this.onDirections,
    required this.onCall,
  });

  final ChargingStationOffer offer;
  final int rank;
  final double energyKwh;
  final VoidCallback onDirections;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final comparable = offer.pricingComparable || offer.isFree;

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
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (offer.secondaryName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        offer.secondaryName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      offer.address,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    offer.pricingLabel(energyKwh),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: comparable ? AppColors.success : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
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
            offer.pricingDetail(energyKwh),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: comparable ? AppColors.success : AppColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (offer.hasTariffText) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: comparable
                    ? AppColors.successSoft
                    : AppColors.warningSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                offer.tariffText!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 13),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _InfoChip(
                icon: Icons.bolt_rounded,
                label: '${_number(offer.maxPowerKw)} kW max',
              ),
              _InfoChip(
                icon: Icons.ev_station_outlined,
                label:
                    '${offer.pointCount} point${offer.pointCount > 1 ? 's' : ''}',
              ),
              for (final connector in offer.connectors.take(4))
                _InfoChip(icon: Icons.electrical_services, label: connector),
              if (offer.paymentCard)
                const _InfoChip(
                  icon: Icons.credit_card_rounded,
                  label: 'Carte bancaire',
                ),
              if (offer.paymentAtTerminal)
                const _InfoChip(
                  icon: Icons.touch_app_outlined,
                  label: 'Paiement à l’acte',
                ),
              if (offer.reservation)
                const _InfoChip(
                  icon: Icons.event_available_outlined,
                  label: 'Réservation',
                ),
            ],
          ),
          if (offer.accessCondition != null ||
              offer.hours != null ||
              offer.accessibility != null) ...[
            const SizedBox(height: 14),
            _DetailsBlock(offer: offer),
          ],
          if (offer.updatedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Donnée mise à jour le ${_date(offer.updatedAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (onCall != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.phone_outlined),
                    label: const Text('Appeler'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: onDirections,
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Itinéraire'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _number(double value) {
    final rounded = value.roundToDouble();
    if (value == rounded) return rounded.toInt().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
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

class _DetailsBlock extends StatelessWidget {
  const _DetailsBlock({required this.offer});

  final ChargingStationOffer offer;

  @override
  Widget build(BuildContext context) {
    final rows = <({IconData icon, String value})>[
      if (offer.accessCondition != null)
        (icon: Icons.lock_open_outlined, value: offer.accessCondition!),
      if (offer.hours != null)
        (icon: Icons.schedule_outlined, value: offer.hours!),
      if (offer.accessibility != null)
        (icon: Icons.accessible_outlined, value: offer.accessibility!),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(rows[index].icon, size: 17, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rows[index].value,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (index < rows.length - 1) const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}
