import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../technical_control/technical_control_location_service.dart';
import 'nearby_location.dart';
import 'nearby_location_service.dart';

class NearbyLocationPickerCard extends StatefulWidget {
  const NearbyLocationPickerCard({super.key, this.onChanged});

  final ValueChanged<NearbySearchLocation?>? onChanged;

  @override
  State<NearbyLocationPickerCard> createState() =>
      _NearbyLocationPickerCardState();
}

class _NearbyLocationPickerCardState extends State<NearbyLocationPickerCard> {
  final _service = NearbyLocationService.instance;
  final _controller = TextEditingController();

  bool _locating = false;
  bool _searching = false;
  String? _errorMessage;

  NearbySearchLocation? get _selected => _service.sessionLocation;

  @override
  void initState() {
    super.initState();
    _controller.text = _selected?.label ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (_locating || _searching) return;
    setState(() {
      _locating = true;
      _errorMessage = null;
    });

    try {
      final location = await _service.useCurrentLocation();
      if (!mounted) return;
      _controller.text = location.label;
      setState(() {});
      widget.onChanged?.call(location);
    } on TechnicalControlLocationException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _searchAddress() async {
    if (_locating || _searching) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _errorMessage = null;
    });

    try {
      final suggestions = await _service.searchLocations(_controller.text);
      if (!mounted) return;

      final selected = await showModalBottomSheet<NearbyLocationSuggestion>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) =>
            _NearbyLocationResultsSheet(suggestions: suggestions),
      );
      if (selected == null || !mounted) return;

      _service.remember(selected);
      _controller.text = selected.label;
      setState(() {});
      widget.onChanged?.call(selected);
    } on NearbyLocationSearchException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _clear() {
    _service.clearRememberedLocation();
    _controller.clear();
    setState(() => _errorMessage = null);
    widget.onChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Container(
      key: const ValueKey('category-location-search'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_searching_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Où voulez-vous chercher ?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (selected != null)
                IconButton(
                  tooltip: 'Effacer le lieu choisi',
                  onPressed: _locating || _searching ? null : _clear,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          if (selected != null) ...[
            const SizedBox(height: 8),
            Container(
              key: const ValueKey('category-selected-location'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softPrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    selected.isDevicePosition
                        ? Icons.my_location_rounded
                        : Icons.place_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      selected.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('category-use-current-location'),
            onPressed: _locating || _searching ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.my_location_rounded),
            label: Text(_locating ? 'Localisation…' : 'Utiliser ma position'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('category-address-field'),
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchAddress(),
            decoration: const InputDecoration(
              labelText: 'Ville, code postal ou adresse',
              hintText: 'Ex. Dijon ou 21000',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('category-address-search'),
            onPressed: _locating || _searching ? null : _searchAddress,
            icon: _searching
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.travel_explore_rounded),
            label: Text(_searching ? 'Recherche…' : 'Choisir cette zone'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              key: const ValueKey('category-location-error'),
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'La recherche d’adresse utilise la Géoplateforme IGN et la Base Adresse Nationale.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _NearbyLocationResultsSheet extends StatelessWidget {
  const _NearbyLocationResultsSheet({required this.suggestions});

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
                  key: ValueKey('category-location-result-$index'),
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
