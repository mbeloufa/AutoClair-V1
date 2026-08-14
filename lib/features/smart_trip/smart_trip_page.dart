import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'smart_trip_models.dart';
import 'smart_trip_service.dart';

class SmartTripPage extends StatefulWidget {
  const SmartTripPage({super.key});

  @override
  State<SmartTripPage> createState() => _SmartTripPageState();
}

class _SmartTripPageState extends State<SmartTripPage> {
  final _vehicleService = VehicleService();
  final _service = SmartTripService();
  final _consumption = TextEditingController();

  List<Vehicle> _vehicles = const [];
  Vehicle? _vehicle;
  bool _loading = true;
  bool _current = true;
  bool _busy = false;
  int _delay = 15;
  SmartTripPoint? _position;
  SmartTripSuggestion? _originSelection;
  SmartTripSuggestion? _destinationSelection;
  SmartTripResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _consumption.dispose();
    super.dispose();
  }

  bool get _electric {
    final fuel = _vehicle?.fuelType?.toLowerCase() ?? '';
    final electric = fuel.contains('elect') || fuel.contains('élect');
    return electric && !fuel.contains('hybrid');
  }

  Future<void> _load() async {
    try {
      final vehicles = await _vehicleService.fetchVehicles();
      Vehicle? selected;
      for (final vehicle in vehicles) {
        if (vehicle.isPrimary) {
          selected = vehicle;
          break;
        }
      }
      selected ??= vehicles.isEmpty ? null : vehicles.first;
      if (!mounted) {
        return;
      }
      setState(() {
        _vehicles = vehicles;
        _vehicle = selected;
        _loading = false;
      });
      await _loadPreferences();
    } on VehicleServiceException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _loadPreferences() async {
    final vehicle = _vehicle;
    if (vehicle == null) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      final consumption = preferences.getDouble(
        'smart_trip_consumption_${vehicle.id}',
      );
      _consumption.text = consumption == null ? '' : _compact(consumption);
      _delay = preferences.getInt('smart_trip_delay') ?? 15;
      _result = null;
    });
  }

  Future<void> _changeVehicle(Vehicle? vehicle) async {
    if (vehicle == null || vehicle.id == _vehicle?.id) {
      return;
    }
    setState(() {
      _vehicle = vehicle;
      _result = null;
      _error = null;
    });
    await _loadPreferences();
  }

  Future<SmartTripPoint> _locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const SmartTripException(
        'Activez la localisation pour utiliser « Ma position ».',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const SmartTripException(
        'Autorisez la localisation ou choisissez un point de départ.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return SmartTripPoint(lat: position.latitude, lng: position.longitude);
  }

  double? _number(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  Future<void> _analyze() async {
    final vehicle = _vehicle;
    final consumptionText = _consumption.text.trim();
    final consumption = consumptionText.isEmpty
        ? null
        : _number(consumptionText);

    String? validation;
    if (vehicle == null) {
      validation = 'Ajoutez ou sélectionnez un véhicule.';
    } else if (_electric) {
      validation =
          'Le moteur électrique sera proposé avec autonomie et recharge.';
    } else if (_destinationSelection == null) {
      validation = 'Sélectionnez une destination dans les résultats proposés.';
    } else if (!_current && _originSelection == null) {
      validation =
          'Sélectionnez un point de départ dans les résultats proposés.';
    } else if (consumptionText.isNotEmpty &&
        (consumption == null || consumption <= 0)) {
      validation = 'La consommation renseignée doit être un nombre positif.';
    }

    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    try {
      Map<String, dynamic> origin;
      if (_current) {
        final point = _position ?? await _locate();
        _position = point;
        origin = {'lat': point.lat, 'lng': point.lng, 'label': 'Ma position'};
      } else {
        final selected = _originSelection!;
        origin = {
          'lat': selected.lat,
          'lng': selected.lng,
          'label': selected.label,
        };
      }

      final selectedDestination = _destinationSelection!;
      final destination = {
        'lat': selectedDestination.lat,
        'lng': selectedDestination.lng,
        'label': selectedDestination.label,
      };

      final preferences = await SharedPreferences.getInstance();
      if (consumption == null) {
        await preferences.remove('smart_trip_consumption_${vehicle!.id}');
      } else {
        await preferences.setDouble(
          'smart_trip_consumption_${vehicle!.id}',
          consumption,
        );
      }
      await preferences.setInt('smart_trip_delay', _delay);

      final result = await _service.analyze(
        vehicleId: vehicle.id,
        origin: origin,
        destination: destination,
        consumptionPer100: consumption,
        maxExtraMinutes: _delay,
      );

      if (mounted) {
        setState(() => _result = result);
      }
    } on SmartTripException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Le calcul du trajet est momentanément indisponible.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _google() async {
    final result = _result;
    if (result == null) {
      return;
    }
    final parameters = <String, String>{
      'api': '1',
      'origin': result.origin.coordinate,
      'destination': result.destination.coordinate,
      'travelmode': 'driving',
    };
    if (result.navigationWaypoints.isNotEmpty) {
      parameters['waypoints'] = result.navigationWaypoints
          .map((point) => point.coordinate)
          .join('|');
    }
    await _launch(Uri.https('www.google.com', '/maps/dir/', parameters));
  }

  Future<void> _apple() async {
    final result = _result;
    if (result == null) {
      return;
    }
    await _launch(
      Uri.https('maps.apple.com', '/', {
        'saddr': result.origin.coordinate,
        'daddr': result.destination.coordinate,
        'dirflg': 'd',
      }),
    );
  }

  Future<void> _waze() async {
    final result = _result;
    if (result == null) {
      return;
    }
    await _launch(
      Uri.https('www.waze.com', '/ul', {
        'll': result.destination.coordinate,
        'navigate': 'yes',
      }),
    );
  }

  Future<void> _launch(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le GPS choisi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trajet intelligent')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Text(
              'Le meilleur compromis, en euros',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'AutoClair explore plusieurs variantes puis conserve les '
              'meilleurs compromis entre péages, carburant, temps et '
              'simplicité du trajet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading)
                    const LinearProgressIndicator()
                  else if (_vehicles.isEmpty)
                    const Text(
                      'Ajoutez d’abord un véhicule pour personnaliser le trajet.',
                    )
                  else
                    DropdownButtonFormField<Vehicle>(
                      initialValue: _vehicle,
                      decoration: const InputDecoration(
                        labelText: 'Véhicule',
                        prefixIcon: Icon(Icons.directions_car_outlined),
                      ),
                      items: [
                        for (final vehicle in _vehicles)
                          DropdownMenuItem(
                            value: vehicle,
                            child: Text(vehicle.displayName),
                          ),
                      ],
                      onChanged: _changeVehicle,
                    ),
                  const SizedBox(height: 14),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Ma position'),
                        icon: Icon(Icons.my_location),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Choisir point départ'),
                        icon: Icon(Icons.edit_location_alt_outlined),
                      ),
                    ],
                    selected: {_current},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _current = selection.first;
                        _result = null;
                        _error = null;
                        if (_current) {
                          _originSelection = null;
                        }
                      });
                    },
                  ),
                  if (!_current) ...[
                    const SizedBox(height: 14),
                    _PlaceSearchField(
                      key: const ValueKey('smart-trip-origin-search'),
                      label: 'Départ',
                      hint: 'Ville, adresse ou lieu précis',
                      service: _service,
                      around: _position,
                      onSelected: (selection) {
                        setState(() {
                          _originSelection = selection;
                          _result = null;
                          _error = null;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  _PlaceSearchField(
                    key: const ValueKey('smart-trip-destination-search'),
                    label: 'Destination',
                    hint: 'Ville, adresse ou lieu précis',
                    service: _service,
                    around: _position,
                    onSelected: (selection) {
                      setState(() {
                        _destinationSelection = selection;
                        _result = null;
                        _error = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _consumption,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Consommation moyenne (optionnel)',
                      hintText: 'Ex. 6,5 L/100 km',
                      prefixIcon: Icon(Icons.speed_outlined),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Si vous ne la connaissez pas, AutoClair utilise '
                    'une estimation prudente selon la motorisation.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Temps supplémentaire accepté : $_delay min',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Slider(
                    key: const ValueKey('smart-trip-delay-slider'),
                    value: _delay.toDouble(),
                    min: 0,
                    max: 30,
                    divisions: 30,
                    label: '$_delay min',
                    onChanged: (value) {
                      setState(() {
                        _delay = value.round();
                        _result = null;
                      });
                    },
                  ),
                  Row(
                    children: [
                      Text(
                        '0 min',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        '+30 min',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const _InfoLine(
                    icon: Icons.local_gas_station_outlined,
                    text:
                        'Prix du carburant récupéré automatiquement depuis '
                        'les données officielles françaises.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('smart-trip-analyze'),
                    onPressed: _busy || _vehicles.isEmpty || _electric
                        ? null
                        : _analyze,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.alt_route_outlined),
                    label: Text(
                      _busy ? 'Optimisation en cours…' : 'Optimiser mon trajet',
                    ),
                  ),
                ],
              ),
            ),
            if (_electric) ...[
              const SizedBox(height: 14),
              const _Notice(
                text:
                    'Véhicule électrique : AutoClair ajoutera autonomie, '
                    'recharge et prix des bornes avant d’activer ce calcul.',
                error: false,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              _Notice(text: _error!, error: true),
            ],
            if (_result != null) ...[
              const SizedBox(height: 18),
              _Result(
                result: _result!,
                onGoogle: _google,
                onApple: _apple,
                onWaze: _waze,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _compact(double value) {
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _PlaceSearchField extends StatefulWidget {
  const _PlaceSearchField({
    super.key,
    required this.label,
    required this.hint,
    required this.service,
    required this.around,
    required this.onSelected,
  });

  final String label;
  final String hint;
  final SmartTripService service;
  final SmartTripPoint? around;
  final ValueChanged<SmartTripSuggestion?> onSelected;

  @override
  State<_PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<_PlaceSearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<SmartTripSuggestion> _suggestions = const [];
  bool _loading = false;
  int _requestSerial = 0;
  SmartTripSuggestion? _selected;

  void _clearField() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _suggestions = const [];
      _loading = false;
    });
    widget.onSelected(null);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    if (_selected != null && value.trim() != _selected!.label.trim()) {
      _selected = null;
      widget.onSelected(null);
    }

    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _loading = false;
      });
      return;
    }

    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_search(query)),
    );
  }

  Future<void> _search(String query) async {
    final serial = ++_requestSerial;
    setState(() => _loading = true);
    final suggestions = await widget.service.suggestPlaces(
      query: query,
      around: widget.around,
    );
    if (!mounted || serial != _requestSerial) {
      return;
    }
    setState(() {
      _loading = false;
      _suggestions = suggestions;
    });
  }

  void _choose(SmartTripSuggestion suggestion) {
    _selected = suggestion;
    _controller.text = suggestion.label;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() => _suggestions = const []);
    widget.onSelected(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onChanged: _changed,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, child) {
                      if (value.text.trim().isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        tooltip: 'Vider le champ',
                        onPressed: _clearField,
                        icon: const Icon(Icons.close_rounded),
                      );
                    },
                  ),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (final suggestion in _suggestions)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined, size: 20),
                    title: Text(
                      suggestion.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: suggestion.subtitle.isEmpty
                        ? null
                        : Text(
                            suggestion.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () => _choose(suggestion),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.error});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: error
            ? Theme.of(context).colorScheme.errorContainer
            : AppColors.softPrimary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.result,
    required this.onGoogle,
    required this.onApple,
    required this.onWaze,
  });

  final SmartTripResult result;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onWaze;

  @override
  Widget build(BuildContext context) {
    final consumption = result.consumptionReference;
    final fuel = result.fuelReference;
    final complexity = result.recommended.complexitySteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Notice(
          text: result.hasSaving
              ? 'Économie nette : ${_money(result.comparison.netSavingEur)} · '
                    '${result.comparison.extraMinutes > 0 ? '+${result.comparison.extraMinutes.round()} min' : 'sans temps supplémentaire significatif'}'
              : 'Le trajet classique est déjà le meilleur compromis '
                    'dans le temps accepté.',
          error: false,
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hypothèses automatiques',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              _Line(
                'Carburant',
                '${fuel.fuelType} · ${_moneyPerLiter(fuel.priceEurPerL)}',
              ),
              _Line(
                'Prix de référence',
                fuel.sampleCount > 0
                    ? '${fuel.sampleCount} stations'
                    : 'source officielle',
              ),
              _Line(
                'Consommation',
                '${consumption.consumptionPer100.toStringAsFixed(1).replaceAll('.', ',')} L/100 km'
                    '${consumption.isEstimated ? ' · estimée' : ' · renseignée'}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Route(title: 'Trajet classique', route: result.baseline),
        if (result.hasSaving) ...[
          const SizedBox(height: 12),
          _Route(title: 'Trajet AutoClair', route: result.recommended),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              children: [
                _Line(
                  'Temps',
                  _signed(result.comparison.extraMinutes, 'min', 0),
                ),
                _Line('Distance', _signed(result.comparison.extraKm, 'km', 1)),
                _Line('Péage', '-${_money(result.comparison.tollSavingEur)}'),
                _Line(
                  'Carburant',
                  result.comparison.energyCostDeltaEur >= 0
                      ? '+${_money(result.comparison.energyCostDeltaEur)}'
                      : '-${_money(result.comparison.energyCostDeltaEur.abs())}',
                ),
                if (complexity > 0)
                  _Line('Ajustements de trajet', '$complexity'),
                const Divider(),
                _Line(
                  'Économie nette',
                  _money(result.comparison.netSavingEur),
                  strong: true,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('smart-trip-open-google'),
          onPressed: onGoogle,
          icon: const Icon(Icons.navigation_outlined),
          label: Text(
            result.hasSaving
                ? 'Utiliser ce trajet dans Google Maps'
                : 'Ouvrir dans Google Maps',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onApple,
                child: const Text('Plans'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: onWaze,
                child: const Text('Waze'),
              ),
            ),
          ],
        ),
        if (result.hasSaving) ...[
          const SizedBox(height: 8),
          Text(
            'Google Maps reçoit des points de passage pour conserver le '
            'corridor optimisé. Plans et Waze peuvent recalculer.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '${result.testedRoutes} variantes comparées · '
          '${result.paretoRoutes} compromis utiles conservés · '
          '${result.routeRequests} simulations routières.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _Route extends StatelessWidget {
  const _Route({required this.title, required this.route});

  final String title;
  final SmartTripRoute route;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(
            route.label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              Text(_duration(route.durationMinutes)),
              Text('${route.distanceKm.toStringAsFixed(1)} km'),
              Text('Péage ${_money(route.tollEur)}'),
              Text(
                'Carburant '
                '${route.energyQuantity.toStringAsFixed(1).replaceAll('.', ',')} L · '
                '${_money(route.energyCostEur)}',
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Text('Coût total estimé'),
              const Spacer(),
              Text(
                _money(route.totalCostEur),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong ? const TextStyle(fontWeight: FontWeight.w900) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

String _money(double value) {
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
}

String _moneyPerLiter(double value) {
  return '${value.toStringAsFixed(3).replaceAll('.', ',')} €/L';
}

String _duration(double value) {
  final total = value.round();
  final hours = total ~/ 60;
  final minutes = total % 60;
  return hours == 0
      ? '$minutes min'
      : '${hours}h${minutes.toString().padLeft(2, '0')}';
}

String _signed(double value, String unit, int digits) {
  return '${value > 0 ? '+' : ''}'
      '${value.toStringAsFixed(digits).replaceAll('.', ',')} $unit';
}
