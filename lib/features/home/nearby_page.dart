import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../technical_control/technical_control_location_service.dart';
import 'nearby_location.dart';
import 'nearby_location_service.dart';

class NearbyPage extends StatefulWidget {
  const NearbyPage({super.key});

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  final _locationService = NearbyLocationService.instance;
  final _queryController = TextEditingController();

  NearbySearchLocation? _selectedLocation;
  bool _locating = false;
  bool _searchingAddress = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _selectedLocation = _locationService.sessionLocation;
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
    });

    try {
      final location = await _locationService.useCurrentLocation();
      if (!mounted) return;
      setState(() => _selectedLocation = location);
    } on TechnicalControlLocationException catch (error) {
      if (!mounted) return;
      setState(() => _locationError = error.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _searchAddress() async {
    if (_searchingAddress) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searchingAddress = true;
      _locationError = null;
    });

    try {
      final suggestions = await _locationService.searchLocations(
        _queryController.text,
      );
      if (!mounted) return;

      final selected = await showModalBottomSheet<NearbyLocationSuggestion>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) =>
            _LocationResultsSheet(suggestions: suggestions),
      );
      if (selected == null || !mounted) return;

      _locationService.remember(selected);
      setState(() {
        _selectedLocation = selected;
        _queryController.text = selected.label;
      });
    } on NearbyLocationSearchException catch (error) {
      if (mounted) setState(() => _locationError = error.message);
    } finally {
      if (mounted) setState(() => _searchingAddress = false);
    }
  }

  void _clearLocation() {
    _locationService.clearRememberedLocation();
    setState(() {
      _selectedLocation = null;
      _queryController.clear();
      _locationError = null;
    });
  }

  Future<void> _openGarageSearch() async {
    NearbySearchLocation location;
    try {
      location = await _locationService.resolveSearchLocation();
    } on TechnicalControlLocationException catch (error) {
      if (mounted) setState(() => _locationError = error.message);
      return;
    }

    final geoUri = Uri.parse(
      'geo:${location.latitude},${location.longitude}'
      '?q=garage%20automobile',
    );
    final webUri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': 'garage automobile près de ${location.label}',
    });

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("L'application de cartographie n'a pas pu s'ouvrir."),
          ),
        );
      }
    }
  }

  void _openService(String path) {
    context.push(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Autour de moi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          const _NearbyIntro(),
          const SizedBox(height: 18),
          _LocationSearchCard(
            controller: _queryController,
            selectedLocation: _selectedLocation,
            errorMessage: _locationError,
            locating: _locating,
            searchingAddress: _searchingAddress,
            onUseCurrentLocation: _useCurrentLocation,
            onSearchAddress: _searchAddress,
            onClearLocation: _clearLocation,
          ),
          const SizedBox(height: 22),
          Text(
            'Que recherchez-vous ?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _NearbyServiceCard(
            icon: Icons.local_gas_station_rounded,
            title: 'Une station-service',
            description:
                'Comparez les prix des carburants autour du lieu choisi.',
            actionLabel: 'Comparer les carburants',
            foreground: AppColors.success,
            background: AppColors.successSoft,
            onTap: () => _openService('/fuel-prices'),
          ),
          const SizedBox(height: 12),
          _NearbyServiceCard(
            icon: Icons.ev_station_rounded,
            title: 'Une borne de recharge',
            description:
                'Repérez les bornes proches et réglez la puissance minimale.',
            actionLabel: 'Trouver une borne',
            foreground: AppColors.accent,
            background: AppColors.softPrimary,
            onTap: () => _openService('/charging-prices'),
          ),
          const SizedBox(height: 12),
          _NearbyServiceCard(
            icon: Icons.local_parking_rounded,
            title: 'Un parking ou une place de stationnement',
            description:
                'Repérez les stationnements autour de la zone sélectionnée.',
            actionLabel: 'Trouver un stationnement',
            foreground: AppColors.warning,
            background: AppColors.warningSoft,
            onTap: () => _openService('/parking'),
          ),
          const SizedBox(height: 12),
          _NearbyServiceCard(
            icon: Icons.fact_check_outlined,
            title: 'Un contrôle technique',
            description:
                'Trouvez les centres proches et comparez leurs prix déclarés.',
            actionLabel: 'Comparer les centres',
            foreground: AppColors.info,
            background: AppColors.infoSoft,
            onTap: () => _openService('/technical-controls'),
          ),
          const SizedBox(height: 12),
          _NearbyServiceCard(
            icon: Icons.car_repair_outlined,
            title: 'Un garage automobile',
            description:
                'Ouvrez les garages proches dans votre application de cartographie.',
            actionLabel: 'Rechercher un garage',
            foreground: AppColors.primary,
            background: AppColors.softPrimary,
            onTap: _openGarageSearch,
          ),
          const SizedBox(height: 18),
          const _LocationPrivacyNote(),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}

class _LocationSearchCard extends StatelessWidget {
  const _LocationSearchCard({
    required this.controller,
    required this.selectedLocation,
    required this.errorMessage,
    required this.locating,
    required this.searchingAddress,
    required this.onUseCurrentLocation,
    required this.onSearchAddress,
    required this.onClearLocation,
  });

  final TextEditingController controller;
  final NearbySearchLocation? selectedLocation;
  final String? errorMessage;
  final bool locating;
  final bool searchingAddress;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onSearchAddress;
  final VoidCallback onClearLocation;

  @override
  Widget build(BuildContext context) {
    final selected = selectedLocation;
    return Container(
      key: const ValueKey('nearby-location-search'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.location_searching, color: AppColors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Zone de recherche',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (selected != null)
                IconButton(
                  tooltip: 'Effacer le lieu choisi',
                  onPressed: onClearLocation,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          if (selected != null) ...[
            const SizedBox(height: 4),
            Container(
              key: const ValueKey('nearby-selected-location'),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.softPrimary,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(
                    selected.isDevicePosition
                        ? Icons.my_location_rounded
                        : Icons.place_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selected.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            key: const ValueKey('nearby-use-current-location'),
            onPressed: locating || searchingAddress
                ? null
                : onUseCurrentLocation,
            icon: locating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.my_location_rounded),
            label: Text(locating ? 'Localisation…' : 'Utiliser ma position'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('nearby-address-field'),
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearchAddress(),
            decoration: const InputDecoration(
              labelText: 'Ville, code postal ou adresse',
              hintText: 'Ex. Dijon ou 21000',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('nearby-address-search'),
            onPressed: locating || searchingAddress ? null : onSearchAddress,
            icon: searchingAddress
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.travel_explore_rounded),
            label: Text(searchingAddress ? 'Recherche…' : 'Choisir ce lieu'),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              errorMessage!,
              key: const ValueKey('nearby-location-error'),
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Recherche d’adresse fournie par la Géoplateforme IGN et la Base Adresse Nationale.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LocationResultsSheet extends StatelessWidget {
  const _LocationResultsSheet({required this.suggestions});

  final List<NearbyLocationSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Choisir un lieu',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return ListTile(
                  key: ValueKey('nearby-location-result-$index'),
                  leading: const Icon(Icons.place_outlined),
                  title: Text(suggestion.label),
                  subtitle: suggestion.secondaryLabel == null
                      ? null
                      : Text(suggestion.secondaryLabel!),
                  onTap: () => Navigator.of(context).pop(suggestion),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyIntro extends StatelessWidget {
  const _NearbyIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.near_me_outlined,
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
                  'Tout ce qui est utile sur la route',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 7),
                Text(
                  'Choisissez votre position ou recherchez une ville avant de comparer.',
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

class _NearbyServiceCard extends StatelessWidget {
  const _NearbyServiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: foreground, size: 29),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      actionLabel,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationPrivacyNote extends StatelessWidget {
  const _LocationPrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Votre position sert uniquement à afficher les résultats proches. '
              'Une ville ou une adresse peut être utilisée sans autoriser la géolocalisation.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
