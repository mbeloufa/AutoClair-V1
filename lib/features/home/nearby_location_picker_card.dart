import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
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
  bool _openingSearch = false;
  String? _errorMessage;

  NearbySearchLocation? get _selected => _service.sessionLocation;
  bool get _usesCurrentPosition =>
      _selected == null || _selected!.isDevicePosition;

  void _selectCurrentPosition() {
    if (_openingSearch) return;
    _service.clearRememberedLocation();
    setState(() => _errorMessage = null);
    widget.onChanged?.call(null);
  }

  Future<void> _choosePlace() async {
    if (_openingSearch) return;
    setState(() {
      _openingSearch = true;
      _errorMessage = null;
    });
    try {
      final selected = await showModalBottomSheet<NearbyLocationSuggestion>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) =>
            _NearbyLocationSearchSheet(service: _service),
      );
      if (selected == null || !mounted) return;
      _service.remember(selected);
      setState(() {});
      widget.onChanged?.call(selected);
    } finally {
      if (mounted) setState(() => _openingSearch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final customLabel = !_usesCurrentPosition ? selected!.label : null;
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
          Text(
            'Zone de recherche',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Choisissez simplement où AutoClair doit chercher.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          _LocationChoiceTile(
            key: const ValueKey('category-location-current'),
            icon: Icons.my_location_rounded,
            title: 'Autour de moi',
            subtitle: 'Position du téléphone au moment de la recherche',
            selected: _usesCurrentPosition,
            enabled: !_openingSearch,
            onTap: _selectCurrentPosition,
          ),
          const SizedBox(height: 9),
          _LocationChoiceTile(
            key: const ValueKey('category-location-custom'),
            icon: Icons.place_outlined,
            title: 'Choisir un lieu',
            subtitle: customLabel ?? 'Ville, code postal ou adresse',
            selected: !_usesCurrentPosition,
            enabled: !_openingSearch,
            trailing: _openingSearch
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: _choosePlace,
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
        ],
      ),
    );
  }
}

class _LocationChoiceTile extends StatelessWidget {
  const _LocationChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.softPrimary : AppColors.background,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? AppColors.primary : AppColors.textMuted,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyLocationSearchSheet extends StatefulWidget {
  const _NearbyLocationSearchSheet({required this.service});

  final NearbyLocationService service;

  @override
  State<_NearbyLocationSearchSheet> createState() =>
      _NearbyLocationSearchSheetState();
}

class _NearbyLocationSearchSheetState
    extends State<_NearbyLocationSearchSheet> {
  final _controller = TextEditingController();
  List<NearbyLocationSuggestion> _suggestions = const [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_searching) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.service.searchLocations(_controller.text);
      if (!mounted) return;
      setState(() => _suggestions = results);
    } on NearbyLocationSearchException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _suggestions = const [];
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choisir un lieu',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('category-address-field'),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                labelText: 'Ville, code postal ou adresse',
                hintText: 'Ex. Dijon ou 21000',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('category-address-search'),
              onPressed: _searching ? null : _search,
              icon: _searching
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.travel_explore_rounded),
              label: Text(_searching ? 'Recherche…' : 'Rechercher'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ListTile(
                      key: ValueKey('category-location-result-$index'),
                      contentPadding: EdgeInsets.zero,
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
          ],
        ),
      ),
    );
  }
}
