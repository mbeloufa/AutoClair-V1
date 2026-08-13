import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/comparison_map.dart';
import '../home/nearby_location.dart';
import '../home/nearby_location_service.dart';
import '../home/nearby_location_picker_card.dart';
import '../home/nearby_radius_slider.dart';
import '../technical_control/technical_control_location_service.dart';
import 'parking_actions.dart';
import 'parking_offer.dart';
import 'parking_service.dart';

class ParkingPage extends StatefulWidget {
  const ParkingPage({super.key});

  @override
  State<ParkingPage> createState() => _ParkingPageState();
}

class _ParkingPageState extends State<ParkingPage> {
  static const _arrivalChoices = <int>[0, 15, 30, 60];

  final _parkingService = ParkingService();
  final _locationService = NearbyLocationService.instance;

  List<ParkingOffer> _offers = const [];
  List<ParkingProviderSummary> _providers = const [];
  NearbySearchLocation? _location;
  String? _selectedParkingId;
  String? _recommendedParkingId;
  String _parkingType = 'all';
  String _sortBy = 'recommendation';
  String _preference = 'availability';
  String _viewMode = 'map';
  double _radiusKm = 5;
  int _arrivalMinutes = 15;
  bool _freeOnly = false;
  bool _accessibleOnly = false;
  bool _evOnly = false;
  bool _searching = false;
  bool _settingsRequired = false;
  bool _openLocationServices = false;
  bool _cacheHit = false;
  bool _truncated = false;
  bool _realtimeCoverage = false;
  bool _historyEnabled = false;
  DateTime? _sourceFetchedAt;
  DateTime? _osmBase;
  String _sourceName = 'OpenStreetMap et flux officiels locaux';
  String _availabilityDisclaimer =
      'La disponibilité dépend des flux publiés par les exploitants.';
  String? _errorMessage;

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _settingsRequired = false;
      _openLocationServices = false;
      _errorMessage = null;
    });

    try {
      final location = await _locationService.resolveSearchLocation();
      await _searchAt(location);
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

  Future<void> _searchAt(NearbySearchLocation location) async {
    try {
      final result = await _parkingService.searchParking(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: _radiusKm,
        parkingType: _parkingType,
        sortBy: _sortBy,
        preference: _preference,
        arrivalMinutes: _arrivalMinutes,
        freeOnly: _freeOnly,
        accessibleOnly: _accessibleOnly,
        evOnly: _evOnly,
      );

      final previousSelection = _selectedParkingId;
      final selectedParkingId =
          result.offers.any((offer) => offer.parkingId == previousSelection)
          ? previousSelection
          : result.recommendedParkingId ??
                (result.offers.isEmpty ? null : result.offers.first.parkingId);

      if (!mounted) return;
      setState(() {
        _location = location;
        _offers = result.offers;
        _providers = result.providers;
        _selectedParkingId = selectedParkingId;
        _recommendedParkingId = result.recommendedParkingId;
        _cacheHit = result.cacheHit;
        _sourceFetchedAt = result.sourceFetchedAt;
        _sourceName = result.sourceName;
        _availabilityDisclaimer = result.availabilityDisclaimer;
        _truncated = result.truncated;
        _realtimeCoverage = result.realtimeCoverage;
        _historyEnabled = result.historyEnabled;
        _osmBase = result.osmBase;
        _searching = false;
        _errorMessage = null;
        _settingsRequired = false;
        _openLocationServices = false;
      });
    } on ParkingServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _searching = false;
      });
    }
  }

  Future<void> _refreshSearch() async {
    final location = _location;
    if (location == null) return;
    setState(() {
      _searching = true;
      _errorMessage = null;
    });
    await _searchAt(location);
  }

  void _resetResults() {
    _offers = const [];
    _providers = const [];
    _location = null;
    _selectedParkingId = null;
    _recommendedParkingId = null;
    _sourceFetchedAt = null;
    _osmBase = null;
    _cacheHit = false;
    _truncated = false;
    _realtimeCoverage = false;
    _historyEnabled = false;
    _errorMessage = null;
  }

  Future<void> _setPreference(String value) async {
    if (_preference == value) return;
    setState(() => _preference = value);
    await _refreshSearch();
  }

  Future<void> _setSort(String value) async {
    if (_sortBy == value) return;
    setState(() => _sortBy = value);
    await _refreshSearch();
  }

  Future<void> _setArrival(int value) async {
    if (_arrivalMinutes == value) return;
    setState(() => _arrivalMinutes = value);
    await _refreshSearch();
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

  Future<void> _openDirections(ParkingOffer offer) async {
    try {
      final opened = await ParkingActions.openDirections(offer);
      if (!opened && mounted) {
        _showMessage("L'itinéraire n'a pas pu être ouvert.");
      }
    } catch (_) {
      if (mounted) _showMessage("L'itinéraire n'a pas pu être ouvert.");
    }
  }

  Future<void> _callOperator(ParkingOffer offer) async {
    try {
      final opened = await ParkingActions.callOperator(offer);
      if (!opened && mounted) {
        _showMessage("Le numéro de l'opérateur n'est pas disponible.");
      }
    } catch (_) {
      if (mounted) _showMessage("L'appel n'a pas pu être lancé.");
    }
  }

  Future<void> _openWebsite(ParkingOffer offer) async {
    try {
      final opened = await ParkingActions.openWebsite(offer);
      if (!opened && mounted) {
        _showMessage("Le site du parking n'est pas disponible.");
      }
    } catch (_) {
      if (mounted) _showMessage("Le site n'a pas pu être ouvert.");
    }
  }

  Future<void> _showSourceInfo() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: _SourceDetails(
              sourceName: _sourceName,
              osmBase: _osmBase,
              availabilityDisclaimer: _availabilityDisclaimer,
              providers: _providers,
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parking intelligent')),
      body: RefreshIndicator(
        onRefresh: _search,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const _HeroCard(),
            const SizedBox(height: 20),
            _searchCard(context),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _ErrorPanel(
                message: _errorMessage!,
                settingsRequired: _settingsRequired,
                onOpenSettings: _openSettings,
                onRetry: _search,
              ),
            ],
            const SizedBox(height: 24),
            _results(context),
          ],
        ),
      ),
    );
  }

  Widget _searchCard(BuildContext context) {
    final selectedLocation = _locationService.sessionLocation;
    final usesCurrent =
        selectedLocation == null || selectedLocation.isDevicePosition;
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
            'Votre priorité',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PreferenceChip(
                label: 'Trouver une place',
                icon: Icons.bolt_rounded,
                selected: _preference == 'availability',
                onTap: () => _setPreference('availability'),
              ),
              _PreferenceChip(
                label: 'Plus proche',
                icon: Icons.near_me_rounded,
                selected: _preference == 'closest',
                onTap: () => _setPreference('closest'),
              ),
              _PreferenceChip(
                label: 'Économiser',
                icon: Icons.savings_outlined,
                selected: _preference == 'free',
                onTap: () => _setPreference('free'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          NearbyLocationPickerCard(
            key: const ValueKey('parking-location-picker'),
            onChanged: (_) => setState(_resetResults),
          ),
          const SizedBox(height: 10),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const ValueKey('parking-advanced-search'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 6),
              leading: const Icon(Icons.tune_rounded),
              title: const Text(
                'Recherche avancée',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Horaires, type, rayon et équipements'),
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _arrivalMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Arrivée prévue',
                    prefixIcon: Icon(Icons.schedule_rounded),
                  ),
                  items: _arrivalChoices
                      .map(
                        (minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text(
                            minutes == 0
                                ? 'Maintenant'
                                : 'Dans $minutes minutes',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _searching
                      ? null
                      : (value) {
                          if (value != null) _setArrival(value);
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _parkingType,
                  decoration: const InputDecoration(
                    labelText: 'Type de stationnement',
                    prefixIcon: Icon(Icons.local_parking_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('Tous les parkings'),
                    ),
                    DropdownMenuItem(
                      value: 'covered',
                      child: Text('Parkings couverts'),
                    ),
                    DropdownMenuItem(
                      value: 'surface',
                      child: Text('Parkings de surface'),
                    ),
                    DropdownMenuItem(
                      value: 'street',
                      child: Text('Stationnement sur voirie'),
                    ),
                    DropdownMenuItem(
                      value: 'park_and_ride',
                      child: Text('Parcs relais'),
                    ),
                  ],
                  onChanged: _searching
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _parkingType = value;
                            _resetResults();
                          });
                        },
                ),
                const SizedBox(height: 12),
                NearbyRadiusSlider(
                  key: const ValueKey('parking-radius-slider'),
                  value: _radiusKm,
                  min: 1,
                  max: 20,
                  divisions: 19,
                  enabled: !_searching,
                  onChanged: (value) {
                    setState(() {
                      _radiusKm = value.roundToDouble();
                      _resetResults();
                    });
                  },
                ),
                const SizedBox(height: 4),
                _FilterSwitch(
                  title: 'Gratuits uniquement',
                  subtitle: 'Les tarifs inconnus sont exclus.',
                  value: _freeOnly,
                  onChanged: _searching
                      ? null
                      : (value) => setState(() {
                          _freeOnly = value;
                          _resetResults();
                        }),
                ),
                _FilterSwitch(
                  title: 'Places PMR déclarées',
                  subtitle: 'Au moins une place accessible renseignée.',
                  value: _accessibleOnly,
                  onChanged: _searching
                      ? null
                      : (value) => setState(() {
                          _accessibleOnly = value;
                          _resetResults();
                        }),
                ),
                _FilterSwitch(
                  title: 'Recharge déclarée',
                  subtitle: 'Au moins un emplacement de recharge renseigné.',
                  value: _evOnly,
                  onChanged: _searching
                      ? null
                      : (value) => setState(() {
                          _evOnly = value;
                          _resetResults();
                        }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _searching ? null : _search,
            icon: _searching
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(
              _searching
                  ? 'Analyse en cours…'
                  : usesCurrent
                  ? 'Trouver autour de moi'
                  : 'Rechercher près de ${selectedLocation.label}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(BuildContext context) {
    if (_location == null && !_searching && _errorMessage == null) {
      return const _MessagePanel(
        icon: Icons.auto_awesome_rounded,
        title: 'Plus qu’une simple recherche',
        message:
            'AutoClair combine distance, disponibilité officielle, fraîcheur des données et vos préférences.',
      );
    }

    if (_searching && _offers.isEmpty) {
      return const _MessagePanel(
        icon: Icons.travel_explore_rounded,
        title: 'Analyse des solutions proches',
        message:
            'La carte nationale et les flux officiels disponibles sont interrogés.',
        showProgress: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CoverageBanner(
          realtimeCoverage: _realtimeCoverage,
          providers: _providers,
          historyEnabled: _historyEnabled,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                '${_offers.length} résultat${_offers.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            IconButton(
              onPressed: _sourceFetchedAt == null ? null : _showSourceInfo,
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: 'Sources et fiabilité',
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _sortBy,
          decoration: const InputDecoration(
            labelText: 'Classement',
            prefixIcon: Icon(Icons.sort_rounded),
          ),
          items: const [
            DropdownMenuItem(
              value: 'recommendation',
              child: Text('Recommandation AutoClair'),
            ),
            DropdownMenuItem(
              value: 'availability',
              child: Text('Places disponibles'),
            ),
            DropdownMenuItem(value: 'distance', child: Text('Distance')),
            DropdownMenuItem(value: 'capacity', child: Text('Capacité')),
            DropdownMenuItem(value: 'free', child: Text('Gratuité')),
          ],
          onChanged: _searching
              ? null
              : (value) {
                  if (value != null) _setSort(value);
                },
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
              _selectedParkingId ??=
                  _recommendedParkingId ??
                  (_offers.isEmpty ? null : _offers.first.parkingId);
            });
          },
        ),
        if (_sourceFetchedAt != null) ...[
          const SizedBox(height: 10),
          Text(
            'Mis à jour ${_dateTime(_sourceFetchedAt!)}'
            '${_cacheHit ? ' • résultat récent' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_truncated) ...[
          const SizedBox(height: 10),
          const _WarningBanner(
            message: 'Seuls les résultats les plus pertinents sont affichés.',
          ),
        ],
        const SizedBox(height: 14),
        if (_offers.isEmpty)
          _MessagePanel(
            icon: Icons.search_off_rounded,
            title: 'Aucun parking trouvé',
            message:
                'Aucun stationnement correspondant aux filtres n’a été trouvé dans un rayon de ${_radiusKm.toInt()} km.',
          )
        else if (_viewMode == 'map')
          _map(context)
        else
          for (var index = 0; index < _offers.length; index++) ...[
            _ParkingCard(
              offer: _offers[index],
              onDirections: () => _openDirections(_offers[index]),
              onCall: _offers[index].phone == null
                  ? null
                  : () => _callOperator(_offers[index]),
              onWebsite: _offers[index].website == null
                  ? null
                  : () => _openWebsite(_offers[index]),
            ),
            if (index < _offers.length - 1) const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _map(BuildContext context) {
    final location = _location;
    if (location == null || _offers.isEmpty) return const SizedBox.shrink();

    var selected = _offers.first;
    for (final offer in _offers) {
      if (offer.parkingId == _selectedParkingId) selected = offer;
    }

    final height = (MediaQuery.sizeOf(context).height * 0.58)
        .clamp(460.0, 620.0)
        .toDouble();

    return SizedBox(
      height: height,
      child: ComparisonMapView(
        key: ValueKey(
          'parking-map-${_sourceFetchedAt?.millisecondsSinceEpoch ?? 0}',
        ),
        userLatitude: location.latitude,
        userLongitude: location.longitude,
        markers: _offers
            .map(
              (offer) => ComparisonMapMarkerData(
                id: offer.parkingId,
                latitude: offer.latitude,
                longitude: offer.longitude,
                label: _markerLabel(offer),
                icon: offer.isRecommended
                    ? Icons.auto_awesome_rounded
                    : offer.parkAndRide
                    ? Icons.directions_bus_rounded
                    : Icons.local_parking_rounded,
                color: _markerColor(offer),
              ),
            )
            .toList(growable: false),
        selectedMarkerId: selected.parkingId,
        initialSheetSize: 0.40,
        minSheetSize: 0.30,
        maxSheetSize: 0.88,
        onMarkerSelected: (parkingId) {
          setState(() => _selectedParkingId = parkingId);
        },
        sheetBuilder: (context, controller) => _ParkingMapSheet(
          controller: controller,
          offer: selected,
          onDirections: () => _openDirections(selected),
          onCall: selected.phone == null ? null : () => _callOperator(selected),
          onWebsite: selected.website == null
              ? null
              : () => _openWebsite(selected),
        ),
      ),
    );
  }

  static String _markerLabel(ParkingOffer offer) {
    if (offer.isClosed) return 'Fermé';
    if (offer.isFull) return 'Complet';
    if (offer.availableSpaces != null && offer.availabilityIsFresh) {
      return '${offer.availableSpaces} libres';
    }
    if (offer.isRecommended) return 'Conseillé';
    if (offer.parkAndRide) return 'P+R';
    if (offer.isFree) return 'Gratuit';
    return offer.capacity == null ? 'Parking' : '${offer.capacity} pl.';
  }

  static Color _markerColor(ParkingOffer offer) {
    if (offer.isClosed || offer.isFull) return AppColors.error;
    if (offer.isRecommended) return AppColors.success;
    if (offer.availabilityIsFresh) return AppColors.info;
    if (offer.isFree) return AppColors.success;
    if (offer.parkAndRide) return AppColors.warning;
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

class _HeroCard extends StatelessWidget {
  const _HeroCard();

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
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Le meilleur choix, pas seulement le plus proche',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Disponibilité officielle, distance, fiabilité, équipements et historique observé.',
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

class _PreferenceChip extends StatelessWidget {
  const _PreferenceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _FilterSwitch extends StatelessWidget {
  const _FilterSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _CoverageBanner extends StatelessWidget {
  const _CoverageBanner({
    required this.realtimeCoverage,
    required this.providers,
    required this.historyEnabled,
  });

  final bool realtimeCoverage;
  final List<ParkingProviderSummary> providers;
  final bool historyEnabled;

  @override
  Widget build(BuildContext context) {
    final names = providers
        .where((provider) => provider.succeeded && provider.realtime)
        .map((provider) => provider.name)
        .where((name) => name.isNotEmpty)
        .join(', ');

    final color = realtimeCoverage ? AppColors.success : AppColors.info;
    final background = realtimeCoverage
        ? AppColors.successSoft
        : AppColors.infoSoft;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            realtimeCoverage ? Icons.sensors_rounded : Icons.public_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              realtimeCoverage
                  ? 'Temps réel officiel : $names'
                        '${historyEnabled ? '\nHistorique AutoClair actif.' : ''}'
                  : 'Aucun flux temps réel officiel compatible dans cette zone. La couverture cartographique nationale reste disponible.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParkingMapSheet extends StatelessWidget {
  const _ParkingMapSheet({
    required this.controller,
    required this.offer,
    required this.onDirections,
    required this.onCall,
    required this.onWebsite,
  });

  final ScrollController controller;
  final ParkingOffer offer;
  final VoidCallback onDirections;
  final VoidCallback? onCall;
  final VoidCallback? onWebsite;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        _ParkingCard(
          offer: offer,
          compact: true,
          onDirections: onDirections,
          onCall: onCall,
          onWebsite: onWebsite,
        ),
      ],
    );
  }
}

class _ParkingCard extends StatelessWidget {
  const _ParkingCard({
    required this.offer,
    required this.onDirections,
    required this.onCall,
    required this.onWebsite,
    this.compact = false,
  });

  final ParkingOffer offer;
  final bool compact;
  final VoidCallback onDirections;
  final VoidCallback? onCall;
  final VoidCallback? onWebsite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: offer.isRecommended
              ? AppColors.success.withValues(alpha: 0.45)
              : AppColors.border,
          width: offer.isRecommended ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (offer.isRecommended) ...[
            const _RecommendationBanner(),
            const SizedBox(height: 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: offer.isRecommended
                      ? AppColors.successSoft
                      : offer.availabilityIsFresh
                      ? AppColors.infoSoft
                      : AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  offer.isRecommended
                      ? Icons.auto_awesome_rounded
                      : offer.parkAndRide
                      ? Icons.directions_bus_rounded
                      : Icons.local_parking_rounded,
                  color: offer.isRecommended
                      ? AppColors.success
                      : offer.availabilityIsFresh
                      ? AppColors.info
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      offer.address.isEmpty ? offer.typeLabel : offer.address,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                offer.distanceLabel,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AvailabilityPanel(offer: offer),
          if (offer.recommendationReasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final reason in offer.recommendationReasons.take(
              compact ? 1 : 3,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 17,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        reason,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _Badge(label: offer.typeLabel, icon: Icons.local_parking_rounded),
              _Badge(
                label: offer.feeLabel,
                icon: offer.isFree
                    ? Icons.money_off_rounded
                    : Icons.euro_rounded,
                positive: offer.isFree,
              ),
              if (offer.capacity != null)
                _Badge(
                  label: offer.capacityLabel,
                  icon: Icons.directions_car_filled_outlined,
                ),
              if (offer.parkAndRide)
                const _Badge(
                  label: 'Parc relais',
                  icon: Icons.directions_bus_rounded,
                ),
              if (offer.hasAccessibleSpaces)
                _Badge(
                  label: '${offer.disabledSpaces} places PMR',
                  icon: Icons.accessible_rounded,
                ),
              if (offer.hasChargingSpaces)
                _Badge(
                  label: '${offer.chargingSpaces} avec recharge',
                  icon: Icons.ev_station_rounded,
                ),
              if (offer.covered)
                const _Badge(label: 'Couvert', icon: Icons.roofing_rounded),
            ],
          ),
          if (!compact &&
              (offer.operatorName != null ||
                  offer.openingHours != null ||
                  offer.maxHeightM != null)) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 10),
            if (offer.openingHours != null)
              _DetailRow(
                icon: Icons.schedule_rounded,
                label: 'Horaires',
                value: offer.openingHours!,
              ),
            if (offer.operatorName != null)
              _DetailRow(
                icon: Icons.business_outlined,
                label: 'Exploitant',
                value: offer.operatorName!,
              ),
            if (offer.maxHeightM != null)
              _DetailRow(
                icon: Icons.height_rounded,
                label: 'Hauteur maximale',
                value:
                    '${offer.maxHeightM!.toStringAsFixed(1).replaceAll('.', ',')} m',
              ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onDirections,
            icon: const Icon(Icons.directions_rounded),
            label: const Text('Itinéraire'),
          ),
          if (onCall != null || onWebsite != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (onCall != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCall,
                      icon: const Icon(Icons.phone_outlined),
                      label: const Text('Appeler'),
                    ),
                  ),
                if (onCall != null && onWebsite != null)
                  const SizedBox(width: 8),
                if (onWebsite != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onWebsite,
                      icon: const Icon(Icons.language_rounded),
                      label: const Text('Site'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationBanner extends StatelessWidget {
  const _RecommendationBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 19,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Recommandation AutoClair',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityPanel extends StatelessWidget {
  const _AvailabilityPanel({required this.offer});
  final ParkingOffer offer;

  @override
  Widget build(BuildContext context) {
    final error = offer.isClosed || offer.isFull;
    final color = error
        ? AppColors.error
        : offer.availabilityIsFresh
        ? AppColors.success
        : offer.availabilityIsStale
        ? AppColors.warning
        : AppColors.info;
    final background = error
        ? AppColors.errorSoft
        : offer.availabilityIsFresh
        ? AppColors.successSoft
        : offer.availabilityIsStale
        ? AppColors.warningSoft
        : AppColors.infoSoft;
    final age = offer.availabilityAgeLabel(DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offer.availabilityLabel,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${offer.confidenceLabel}'
            '${age == null ? '' : ' • $age'}'
            '${offer.availabilitySource == null ? '' : ' • ${offer.availabilitySource}'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (offer.hasPrediction) ...[
            const SizedBox(height: 6),
            Text(
              'Historique AutoClair : environ ${offer.predictedAvailableSpaces} places habituellement disponibles à cette heure '
              '(${offer.predictionSamples} observations).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.icon,
    this.positive = false,
  });

  final String label;
  final IconData icon;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final foreground = positive ? AppColors.success : AppColors.primary;
    final background = positive ? AppColors.successSoft : AppColors.softPrimary;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (MediaQuery.sizeOf(context).width - 92)
            .clamp(180.0, 420.0)
            .toDouble(),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label : $value',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
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
          OutlinedButton.icon(
            onPressed: settingsRequired ? onOpenSettings : onRetry,
            icon: Icon(
              settingsRequired
                  ? Icons.settings_outlined
                  : Icons.refresh_rounded,
            ),
            label: Text(settingsRequired ? 'Ouvrir les réglages' : 'Réessayer'),
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _SourceDetails extends StatelessWidget {
  const _SourceDetails({
    required this.sourceName,
    required this.osmBase,
    required this.availabilityDisclaimer,
    required this.providers,
  });

  final String sourceName;
  final DateTime? osmBase;
  final String availabilityDisclaimer;
  final List<ParkingProviderSummary> providers;

  @override
  Widget build(BuildContext context) {
    final providerLabels = providers
        .where((provider) => provider.succeeded)
        .map((provider) => provider.name)
        .where((name) => name.isNotEmpty)
        .join(', ');
    final baseLabel = osmBase == null
        ? null
        : _ParkingPageState._dateTime(osmBase!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.info),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sources et fiabilité',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SourceDetailRow(label: 'Carte', value: sourceName),
        if (providerLabels.isNotEmpty)
          _SourceDetailRow(label: 'Flux officiels', value: providerLabels),
        if (baseLabel != null)
          _SourceDetailRow(label: 'Mise à jour', value: baseLabel),
        _SourceDetailRow(label: 'Disponibilité', value: availabilityDisclaimer),
        const SizedBox(height: 10),
        Text(
          '© contributeurs OpenStreetMap',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SourceDetailRow extends StatelessWidget {
  const _SourceDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
