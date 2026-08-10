import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../home/nearby_location.dart';
import '../home/nearby_location_service.dart';
import '../home/nearby_location_picker_card.dart';
import '../home/nearby_radius_slider.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'technical_control_actions.dart';
import 'technical_control_catalog.dart';
import 'technical_control_location_service.dart';
import 'technical_control_offer.dart';
import 'technical_control_service.dart';

class TechnicalControlComparePage extends StatefulWidget {
  const TechnicalControlComparePage({super.key});

  @override
  State<TechnicalControlComparePage> createState() =>
      _TechnicalControlComparePageState();
}

class _TechnicalControlComparePageState
    extends State<TechnicalControlComparePage> {
  final _vehicleService = VehicleService();
  final _technicalControlService = TechnicalControlService();
  final _locationService = NearbyLocationService.instance;

  List<Vehicle> _vehicles = const [];
  List<TechnicalControlCatalogOption> _vehicleCategories = const [];
  List<TechnicalControlCatalogOption> _energyCategories = const [];
  List<TechnicalControlOffer> _offers = const [];

  String? _selectedVehicleId;
  String? _selectedVehicleCategoryId;
  String? _selectedEnergyCategoryId;
  String _sortBy = 'price';
  double _radiusKm = 30;
  NearbySearchLocation? _lastLocation;

  bool _loading = true;
  bool _searching = false;
  bool _settingsRequired = false;
  bool _openLocationServices = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPrerequisites();
  }

  Future<void> _loadPrerequisites() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final vehicles = await _vehicleService.fetchVehicles();
      final catalog = await _technicalControlService.fetchCatalog();

      if (!mounted) return;

      final selectedVehicle = vehicles.isEmpty ? null : vehicles.first;
      final vehicleCategoryId = _defaultVehicleCategoryId(
        catalog.vehicleCategories,
      );
      final energyCategoryId = _defaultEnergyCategoryId(
        catalog.energyCategories,
        selectedVehicle?.fuelType,
      );

      setState(() {
        _vehicles = vehicles;
        _vehicleCategories = catalog.vehicleCategories;
        _energyCategories = catalog.energyCategories;
        _selectedVehicleId = selectedVehicle?.id;
        _selectedVehicleCategoryId = vehicleCategoryId;
        _selectedEnergyCategoryId = energyCategoryId;
        _loading = false;
      });
    } on VehicleServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _loading = false;
      });
    } on TechnicalControlServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _loading = false;
      });
    }
  }

  String? _defaultVehicleCategoryId(
    List<TechnicalControlCatalogOption> options,
  ) {
    if (options.isEmpty) return null;

    for (final option in options) {
      final label = _normalize(option.label);
      if (label.contains('vehicule particulier') ||
          label.contains('voiture particuliere')) {
        return option.id;
      }
    }

    return options.first.id;
  }

  String? _defaultEnergyCategoryId(
    List<TechnicalControlCatalogOption> options,
    String? fuelType,
  ) {
    if (options.isEmpty) return null;

    final fuel = _normalize(fuelType ?? '');
    if (fuel.isNotEmpty) {
      final searchTerms = <String>{fuel};

      if (fuel.contains('diesel')) searchTerms.add('gazole');
      if (fuel.contains('gazole')) searchTerms.add('diesel');
      if (fuel.contains('electrique')) searchTerms.add('electrique');
      if (fuel.contains('essence')) searchTerms.add('essence');
      if (fuel.contains('hybride')) searchTerms.add('hybride');

      for (final option in options) {
        final label = _normalize(option.label);
        if (searchTerms.any((term) => label.contains(term))) {
          return option.id;
        }
      }
    }

    return options.first.id;
  }

  void _onVehicleChanged(String? vehicleId) {
    Vehicle? vehicle;
    for (final item in _vehicles) {
      if (item.id == vehicleId) {
        vehicle = item;
        break;
      }
    }
    final energyId = _defaultEnergyCategoryId(
      _energyCategories,
      vehicle?.fuelType,
    );

    setState(() {
      _selectedVehicleId = vehicleId;
      _selectedEnergyCategoryId = energyId;
      _offers = const [];
      _lastLocation = null;
      _errorMessage = null;
    });
  }

  Future<void> _compare() async {
    final vehicleCategoryId = _selectedVehicleCategoryId;
    final energyCategoryId = _selectedEnergyCategoryId;

    if (vehicleCategoryId == null || energyCategoryId == null) {
      _showMessage('Sélectionnez le type de véhicule et son énergie.');
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
      await _searchAt(
        location,
        vehicleCategoryId: vehicleCategoryId,
        energyCategoryId: energyCategoryId,
        sortBy: _sortBy,
      );
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
    required String vehicleCategoryId,
    required String energyCategoryId,
    required String sortBy,
  }) async {
    try {
      final offers = await _technicalControlService.searchOffers(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: _radiusKm,
        vehicleCategoryId: vehicleCategoryId,
        energyCategoryId: energyCategoryId,
        sortBy: sortBy,
      );

      if (!mounted) return;
      setState(() {
        _lastLocation = location;
        _offers = offers;
        _sortBy = sortBy;
        _searching = false;
        _errorMessage = null;
        _settingsRequired = false;
        _openLocationServices = false;
      });
    } on TechnicalControlServiceException catch (error) {
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
    final vehicleCategoryId = _selectedVehicleCategoryId;
    final energyCategoryId = _selectedEnergyCategoryId;

    setState(() => _sortBy = sortBy);

    if (location == null ||
        vehicleCategoryId == null ||
        energyCategoryId == null) {
      return;
    }

    setState(() {
      _searching = true;
      _errorMessage = null;
    });

    await _searchAt(
      location,
      vehicleCategoryId: vehicleCategoryId,
      energyCategoryId: energyCategoryId,
      sortBy: sortBy,
    );
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
    if (changed == true) await _loadPrerequisites();
  }

  Future<void> _runExternalAction(Future<bool> Function() action) async {
    try {
      final opened = await action();
      if (!opened && mounted) {
        _showMessage("L'action n'a pas pu être ouverte sur cet appareil.");
      }
    } catch (_) {
      if (mounted) {
        _showMessage("L'action n'a pas pu être ouverte sur cet appareil.");
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
      appBar: AppBar(title: const Text('Comparer les contrôles techniques')),
      body: RefreshIndicator(
        onRefresh: _loadPrerequisites,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const _IntroductionCard(),
            const SizedBox(height: 20),
            if (_loading)
              const _LoadingPanel()
            else if (_errorMessage != null && _vehicles.isEmpty)
              _ErrorPanel(
                message: _errorMessage!,
                settingsRequired: false,
                onOpenSettings: _openSettings,
                onRetry: _loadPrerequisites,
              )
            else if (_vehicles.isEmpty)
              _NoVehiclePanel(onCreateVehicle: _openCreateVehicle)
            else ...[
              _buildSearchForm(context),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                _ErrorPanel(
                  message: _errorMessage!,
                  settingsRequired: _settingsRequired,
                  onOpenSettings: _openSettings,
                  onRetry: _loadPrerequisites,
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
          Text(
            'Votre recherche',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Les filtres sont préremplis à partir de votre véhicule principal.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            key: ValueKey('vehicle-$_selectedVehicleId'),
            initialValue: _selectedVehicleId,
            isExpanded: true,
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
          DropdownButtonFormField<String>(
            key: ValueKey('category-$_selectedVehicleCategoryId'),
            initialValue: _selectedVehicleCategoryId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Type de véhicule contrôlé',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: _vehicleCategories
                .map(
                  (option) => DropdownMenuItem(
                    value: option.id,
                    child: Text(option.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: _searching
                ? null
                : (value) {
                    setState(() {
                      _selectedVehicleCategoryId = value;
                      _offers = const [];
                      _lastLocation = null;
                    });
                  },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey('energy-$_selectedEnergyCategoryId'),
            initialValue: _selectedEnergyCategoryId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Énergie',
              prefixIcon: Icon(Icons.local_gas_station_outlined),
            ),
            items: _energyCategories
                .map(
                  (option) => DropdownMenuItem(
                    value: option.id,
                    child: Text(option.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: _searching
                ? null
                : (value) {
                    setState(() {
                      _selectedEnergyCategoryId = value;
                      _offers = const [];
                      _lastLocation = null;
                    });
                  },
          ),
          const SizedBox(height: 20),
          NearbyLocationPickerCard(
            key: const ValueKey('technical-control-location-picker'),
            onChanged: (_) => setState(() {
              _offers = const [];
              _lastLocation = null;
            }),
          ),
          const SizedBox(height: 14),
          NearbyRadiusSlider(
            key: const ValueKey('technical-control-radius-slider'),
            value: _radiusKm,
            min: 10,
            max: 100,
            divisions: 9,
            enabled: !_searching,
            onChanged: (value) {
              setState(() {
                _radiusKm = ((value / 10).round() * 10).toDouble();
                _offers = const [];
                _lastLocation = null;
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
                  : 'Comparer près de ${_locationService.sessionLocation!.label}',
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
                  "n'est pas enregistrée.",
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
      return const _SearchingPanel();
    }

    if (_lastLocation == null && _offers.isEmpty) {
      return const _InitialResultsPanel();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _offers.isEmpty
                    ? 'Aucun centre trouvé'
                    : '${_offers.length} centre${_offers.length > 1 ? 's' : ''}',
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
        const SizedBox(height: 14),
        if (_offers.isEmpty)
          _EmptyResultsPanel(radiusKm: _radiusKm)
        else
          for (var index = 0; index < _offers.length; index++) ...[
            _OfferCard(
              offer: _offers[index],
              rank: index + 1,
              onCall: _offers[index].phone == null
                  ? null
                  : () => _runExternalAction(
                      () => TechnicalControlActions.callCenter(
                        _offers[index].phone!,
                      ),
                    ),
              onWebsite: _offers[index].website == null
                  ? null
                  : () => _runExternalAction(
                      () => TechnicalControlActions.openWebsite(
                        _offers[index].website!,
                      ),
                    ),
              onDirections: () => _runExternalAction(
                () => TechnicalControlActions.openDirections(_offers[index]),
              ),
            ),
            if (index < _offers.length - 1) const SizedBox(height: 12),
          ],
      ],
    );
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('ç', 'c')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u');
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
              Icons.price_check_rounded,
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
                  'Trouvez le bon centre au bon prix',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tarifs officiels publiés par les centres de contrôle '
                  'technique et distances calculées depuis votre position.',
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

class _NoVehiclePanel extends StatelessWidget {
  const _NoVehiclePanel({required this.onCreateVehicle});

  final VoidCallback onCreateVehicle;

  @override
  Widget build(BuildContext context) {
    return _MessagePanel(
      icon: Icons.directions_car_outlined,
      title: 'Ajoutez d’abord votre véhicule',
      message:
          'AutoClair utilisera son énergie pour préremplir la comparaison.',
      actionLabel: 'Ajouter un véhicule',
      onAction: onCreateVehicle,
    );
  }
}

class _SearchingPanel extends StatelessWidget {
  const _SearchingPanel();

  @override
  Widget build(BuildContext context) {
    return const _MessagePanel(
      icon: Icons.location_searching_rounded,
      title: 'Recherche des centres proches',
      message: 'AutoClair compare les prix disponibles dans le rayon choisi.',
      showProgress: true,
    );
  }
}

class _InitialResultsPanel extends StatelessWidget {
  const _InitialResultsPanel();

  @override
  Widget build(BuildContext context) {
    return const _MessagePanel(
      icon: Icons.map_outlined,
      title: 'Les résultats apparaîtront ici',
      message:
          'Sélectionnez vos critères puis autorisez votre position au moment de la recherche.',
    );
  }
}

class _EmptyResultsPanel extends StatelessWidget {
  const _EmptyResultsPanel({required this.radiusKm});

  final double radiusKm;

  @override
  Widget build(BuildContext context) {
    return _MessagePanel(
      icon: Icons.search_off_rounded,
      title: 'Aucun tarif dans ce rayon',
      message:
          'Aucun centre compatible n’a été trouvé dans un rayon de ${radiusKm.toInt()} km. '
          'Élargissez le rayon ou vérifiez les filtres.',
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
    this.actionLabel,
    this.onAction,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
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
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
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
    this.onCall,
    this.onWebsite,
  });

  final TechnicalControlOffer offer;
  final int rank;
  final VoidCallback? onCall;
  final VoidCallback? onWebsite;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final reinspection = _reinspectionLabel(offer);
    final updatedAt = offer.tariffUpdatedAt;

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
                      offer.denomination,
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
                    _price(offer.inspectionPrice),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                      fontSize: 24,
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
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.directions_car_outlined,
                label: offer.vehicleCategoryLabel,
              ),
              _InfoChip(
                icon: Icons.local_gas_station_outlined,
                label: offer.energyCategoryLabel,
              ),
            ],
          ),
          if (reinspection != null) ...[
            const SizedBox(height: 13),
            Row(
              children: [
                const Icon(
                  Icons.replay_rounded,
                  size: 19,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Contre-visite : $reinspection',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
          if (updatedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Tarif actualisé le ${_date(updatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 15),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDirections,
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('Itinéraire'),
                ),
              ),
              if (onCall != null) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onCall,
                  icon: const Icon(Icons.call_outlined),
                  tooltip: 'Appeler le centre',
                ),
              ],
              if (onWebsite != null) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onWebsite,
                  icon: const Icon(Icons.language_outlined),
                  tooltip: 'Ouvrir le site',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String? _reinspectionLabel(TechnicalControlOffer offer) {
    final minimum = offer.reinspectionMinPrice;
    final maximum = offer.reinspectionMaxPrice;

    if (minimum == null && maximum == null) return null;
    if (minimum != null && maximum != null) {
      if ((minimum - maximum).abs() < 0.001) return _price(minimum);
      return 'de ${_price(minimum)} à ${_price(maximum)}';
    }
    if (minimum != null) return 'à partir de ${_price(minimum)}';
    return "jusqu'à ${_price(maximum!)}";
  }

  static String _price(double value) => '${_number(value)} €';

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
