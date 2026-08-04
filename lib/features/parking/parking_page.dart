import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/comparison_map.dart';
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
  static const _radiusChoices = <double>[1, 3, 5, 10, 20];

  final _parkingService = ParkingService();
  final _locationService = TechnicalControlLocationService();

  List<ParkingOffer> _offers = const [];
  Position? _lastPosition;
  String? _selectedParkingId;
  String _parkingType = 'all';
  String _sortBy = 'distance';
  String _viewMode = 'map';
  double _radiusKm = 5;
  bool _freeOnly = false;
  bool _accessibleOnly = false;
  bool _evOnly = false;
  bool _searching = false;
  bool _settingsRequired = false;
  bool _openLocationServices = false;
  bool _cacheHit = false;
  bool _truncated = false;
  DateTime? _sourceFetchedAt;
  DateTime? _osmBase;
  String _sourceName = 'OpenStreetMap via Overpass';
  String _availabilityDisclaimer =
      'La disponibilité en temps réel n’est pas fournie.';
  String? _errorMessage;

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _settingsRequired = false;
      _openLocationServices = false;
      _errorMessage = null;
    });

    try {
      final position = await _locationService.determineCurrentPosition();
      await _searchAt(position);
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

  Future<void> _searchAt(Position position) async {
    try {
      final result = await _parkingService.searchParking(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: _radiusKm,
        parkingType: _parkingType,
        sortBy: _sortBy,
        freeOnly: _freeOnly,
        accessibleOnly: _accessibleOnly,
        evOnly: _evOnly,
      );

      final previousSelection = _selectedParkingId;
      final selectedParkingId =
          result.offers.any((offer) => offer.parkingId == previousSelection)
          ? previousSelection
          : (result.offers.isEmpty ? null : result.offers.first.parkingId);

      if (!mounted) return;
      setState(() {
        _lastPosition = position;
        _offers = result.offers;
        _selectedParkingId = selectedParkingId;
        _cacheHit = result.cacheHit;
        _sourceFetchedAt = result.sourceFetchedAt;
        _sourceName = result.sourceName;
        _availabilityDisclaimer = result.availabilityDisclaimer;
        _truncated = result.truncated;
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

  void _resetResults() {
    _offers = const [];
    _selectedParkingId = null;
    _lastPosition = null;
    _sourceFetchedAt = null;
    _osmBase = null;
    _cacheHit = false;
    _truncated = false;
    _errorMessage = null;
  }

  Future<void> _changeSort(String sortBy) async {
    if (_sortBy == sortBy) return;
    setState(() => _sortBy = sortBy);

    final position = _lastPosition;
    if (position == null) return;

    setState(() {
      _searching = true;
      _errorMessage = null;
    });
    await _searchAt(position);
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parkings autour de moi')),
      body: RefreshIndicator(
        onRefresh: _search,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const _IntroductionCard(),
            const SizedBox(height: 20),
            _buildSearchForm(context),
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
            _buildResults(context),
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
          DropdownButtonFormField<String>(
            initialValue: _parkingType,
            decoration: const InputDecoration(
              labelText: 'Type de stationnement',
              prefixIcon: Icon(Icons.local_parking_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Tous les parkings')),
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
          const SizedBox(height: 14),
          DropdownButtonFormField<double>(
            initialValue: _radiusKm,
            decoration: const InputDecoration(
              labelText: 'Rayon de recherche',
              prefixIcon: Icon(Icons.radar_rounded),
            ),
            items: _radiusChoices
                .map(
                  (radius) => DropdownMenuItem(
                    value: radius,
                    child: Text('${radius.toInt()} km'),
                  ),
                )
                .toList(growable: false),
            onChanged: _searching
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _radiusKm = value;
                      _resetResults();
                    });
                  },
          ),
          const SizedBox(height: 14),
          _FilterSwitch(
            title: 'Uniquement les parkings gratuits',
            subtitle:
                'Les parkings dont le tarif n’est pas renseigné sont exclus.',
            value: _freeOnly,
            onChanged: _searching
                ? null
                : (value) {
                    setState(() {
                      _freeOnly = value;
                      _resetResults();
                    });
                  },
          ),
          _FilterSwitch(
            title: 'Places PMR déclarées',
            subtitle:
                'Affiche les parkings mentionnant au moins une place accessible.',
            value: _accessibleOnly,
            onChanged: _searching
                ? null
                : (value) {
                    setState(() {
                      _accessibleOnly = value;
                      _resetResults();
                    });
                  },
          ),
          _FilterSwitch(
            title: 'Places avec recharge déclarée',
            subtitle:
                'Affiche les parkings mentionnant des emplacements de recharge.',
            value: _evOnly,
            onChanged: _searching
                ? null
                : (value) {
                    setState(() {
                      _evOnly = value;
                      _resetResults();
                    });
                  },
          ),
          const SizedBox(height: 18),
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
                : const Icon(Icons.my_location_rounded),
            label: Text(
              _searching ? 'Recherche en cours…' : 'Rechercher autour de moi',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_lastPosition == null && !_searching && _errorMessage == null) {
      return const _MessagePanel(
        icon: Icons.local_parking_rounded,
        title: 'Trouvez un stationnement adapté',
        message:
            'Lancez la recherche pour afficher les parkings publics, les parcs relais et les zones de stationnement cartographiées autour de vous.',
      );
    }

    if (_searching && _offers.isEmpty) {
      return const _MessagePanel(
        icon: Icons.travel_explore_rounded,
        title: 'Recherche des parkings proches',
        message: 'La carte est en cours d’interrogation.',
        showProgress: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_offers.length} résultat${_offers.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_searching)
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
              value: 'distance',
              icon: Icon(Icons.near_me_outlined),
              label: Text('Distance'),
            ),
            ButtonSegment(
              value: 'capacity',
              icon: Icon(Icons.directions_car_filled_outlined),
              label: Text('Places'),
            ),
            ButtonSegment(
              value: 'free',
              icon: Icon(Icons.euro_rounded),
              label: Text('Gratuit'),
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
              if (_selectedParkingId == null && _offers.isNotEmpty) {
                _selectedParkingId = _offers.first.parkingId;
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
                'De nombreux parkings ont été trouvés. Seuls les résultats les plus pertinents sont affichés.',
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
          _buildMapResults(context)
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
        const SizedBox(height: 14),
        _SourceNote(
          sourceName: _sourceName,
          osmBase: _osmBase,
          availabilityDisclaimer: _availabilityDisclaimer,
        ),
      ],
    );
  }

  Widget _buildMapResults(BuildContext context) {
    final position = _lastPosition;
    if (position == null || _offers.isEmpty) return const SizedBox.shrink();

    ParkingOffer selectedOffer = _offers.first;
    for (final offer in _offers) {
      if (offer.parkingId == _selectedParkingId) {
        selectedOffer = offer;
        break;
      }
    }

    final mapHeight = (MediaQuery.sizeOf(context).height * 0.72)
        .clamp(560.0, 760.0)
        .toDouble();

    return SizedBox(
      height: mapHeight,
      child: ComparisonMapView(
        key: ValueKey(
          'parking-map-${_sourceFetchedAt?.millisecondsSinceEpoch ?? 0}',
        ),
        userLatitude: position.latitude,
        userLongitude: position.longitude,
        markers: _offers
            .map(
              (offer) => ComparisonMapMarkerData(
                id: offer.parkingId,
                latitude: offer.latitude,
                longitude: offer.longitude,
                label: _markerLabel(offer),
                icon: offer.parkAndRide
                    ? Icons.directions_bus_rounded
                    : Icons.local_parking_rounded,
                color: _markerColor(offer),
              ),
            )
            .toList(growable: false),
        selectedMarkerId: selectedOffer.parkingId,
        onMarkerSelected: (parkingId) {
          setState(() => _selectedParkingId = parkingId);
        },
        sheetBuilder: (context, controller) => _ParkingMapSheet(
          controller: controller,
          offer: selectedOffer,
          onDirections: () => _openDirections(selectedOffer),
          onCall: selectedOffer.phone == null
              ? null
              : () => _callOperator(selectedOffer),
          onWebsite: selectedOffer.website == null
              ? null
              : () => _openWebsite(selectedOffer),
        ),
      ),
    );
  }

  static String _markerLabel(ParkingOffer offer) {
    if (offer.parkAndRide) return 'P+R';
    if (offer.isFree) return 'Gratuit';
    final capacity = offer.capacity;
    if (capacity != null) return '$capacity pl.';
    return 'Parking';
  }

  static Color _markerColor(ParkingOffer offer) {
    if (offer.isFree) return AppColors.success;
    if (offer.parkAndRide) return AppColors.info;
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
              Icons.local_parking_rounded,
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
                  'Le bon stationnement autour de vous',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Parkings publics, parcs relais, capacité déclarée, accès PMR et recharge lorsque ces informations sont disponibles.',
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
              child: Icon(
                offer.parkAndRide
                    ? Icons.directions_bus_rounded
                    : Icons.local_parking_rounded,
                color: AppColors.primary,
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
                  const SizedBox(height: 2),
                  Text(
                    offer.address.isEmpty ? offer.typeLabel : offer.address,
                    maxLines: 2,
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
        Text(
          'Faites glisser ce panneau vers le haut pour afficher tous les détails.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        const Divider(),
        const SizedBox(height: 14),
        _ParkingCard(
          offer: offer,
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
  });

  final ParkingOffer offer;
  final VoidCallback onDirections;
  final VoidCallback? onCall;
  final VoidCallback? onWebsite;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      _Badge(label: offer.typeLabel, icon: Icons.local_parking_rounded),
      _Badge(
        label: offer.feeLabel,
        icon: offer.isFree ? Icons.money_off_rounded : Icons.euro_rounded,
        positive: offer.isFree,
      ),
      if (offer.capacity != null)
        _Badge(
          label: offer.capacityLabel,
          icon: Icons.directions_car_filled_outlined,
        ),
      if (offer.parkAndRide)
        const _Badge(label: 'Parc relais', icon: Icons.directions_bus_rounded),
      if (offer.hasAccessibleSpaces)
        _Badge(
          label:
              '${offer.disabledSpaces} place${offer.disabledSpaces == 1 ? '' : 's'} PMR',
          icon: Icons.accessible_rounded,
        ),
      if (offer.hasChargingSpaces)
        _Badge(
          label:
              '${offer.chargingSpaces} place${offer.chargingSpaces == 1 ? '' : 's'} avec recharge',
          icon: Icons.ev_station_rounded,
        ),
      if (offer.covered)
        const _Badge(label: 'Couvert', icon: Icons.roofing_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: offer.isFree
                      ? AppColors.successSoft
                      : AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  offer.parkAndRide
                      ? Icons.directions_bus_rounded
                      : Icons.local_parking_rounded,
                  color: offer.isFree ? AppColors.success : AppColors.primary,
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
                    const SizedBox(height: 4),
                    Text(
                      offer.address.isEmpty ? offer.typeLabel : offer.address,
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
          const SizedBox(height: 12),
          Wrap(spacing: 7, runSpacing: 7, children: badges),
          if (offer.openingHours != null ||
              offer.operatorName != null ||
              offer.maxHeightM != null ||
              offer.surface != null) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 12),
            if (offer.openingHours != null)
              _DetailRow(
                icon: Icons.schedule_rounded,
                label: 'Horaires déclarés',
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
            if (offer.surface != null)
              _DetailRow(
                icon: Icons.layers_outlined,
                label: 'Revêtement',
                value: offer.surface!,
              ),
          ],
          const SizedBox(height: 14),
          Text(offer.accessLabel, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
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

    return Container(
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
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

class _SourceNote extends StatelessWidget {
  const _SourceNote({
    required this.sourceName,
    required this.osmBase,
    required this.availabilityDisclaimer,
  });

  final String sourceName;
  final DateTime? osmBase;
  final String availabilityDisclaimer;

  @override
  Widget build(BuildContext context) {
    final base = osmBase;
    final baseLabel = base == null
        ? null
        : 'Mise à jour cartographique : ${_ParkingPageState._dateTime(base)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Source : $sourceName — © contributeurs OpenStreetMap.'
              '${baseLabel == null ? '' : '\n$baseLabel'}'
              '\n$availabilityDisclaimer '
              'Les tarifs, horaires, accès et capacités doivent être vérifiés auprès de l’exploitant.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
