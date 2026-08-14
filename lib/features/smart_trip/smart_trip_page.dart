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
  final _origin = TextEditingController(),
      _destination = TextEditingController(),
      _consumption = TextEditingController(),
      _price = TextEditingController();
  List<Vehicle> _vehicles = const [];
  Vehicle? _vehicle;
  bool _loading = true, _current = true, _busy = false;
  int _delay = 15;
  SmartTripPoint? _position;
  SmartTripResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _origin.dispose();
    _destination.dispose();
    _consumption.dispose();
    _price.dispose();
    super.dispose();
  }

  bool get _electric {
    final f = _vehicle?.fuelType?.toLowerCase() ?? '';
    final electric = f.contains('elect') || f.contains('élect');
    return electric && !f.contains('hybrid');
  }

  String get _energy => _electric ? 'Électricité' : 'Carburant';

  Future<void> _load() async {
    try {
      final list = await _vehicleService.fetchVehicles();
      Vehicle? selected;
      for (final v in list) {
        if (v.isPrimary) {
          selected = v;
          break;
        }
      }
      selected ??= list.isEmpty ? null : list.first;
      if (!mounted) {
        return;
      }
      setState(() {
        _vehicles = list;
        _vehicle = selected;
        _loading = false;
      });
      await _loadPrefs();
    } on VehicleServiceException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _loadPrefs() async {
    final v = _vehicle;
    if (v == null) {
      return;
    }
    final p = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      final c = p.getDouble('smart_trip_consumption_${v.id}');
      final e = p.getDouble('smart_trip_price_${v.id}');
      _consumption.text = c == null ? '' : _compact(c);
      _price.text = e == null ? '' : _compact(e);
      _delay = p.getInt('smart_trip_delay') ?? 15;
      _result = null;
    });
  }

  Future<void> _changeVehicle(Vehicle? v) async {
    if (v == null || v.id == _vehicle?.id) {
      return;
    }
    setState(() {
      _vehicle = v;
      _result = null;
      _error = null;
    });
    await _loadPrefs();
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
        'Autorisez la localisation ou saisissez un autre départ.',
      );
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return SmartTripPoint(lat: p.latitude, lng: p.longitude);
  }

  double? _num(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

  Future<void> _analyze() async {
    final v = _vehicle,
        destination = _destination.text.trim(),
        cons = _num(_consumption.text),
        price = _num(_price.text);
    String? validation;
    if (v == null) {
      validation = 'Ajoutez ou sélectionnez un véhicule.';
    } else if (_electric) {
      validation =
          'La V1 électrique intégrera autonomie, recharge et prix des bornes. '
          'AutoClair préfère ne pas afficher un calcul incomplet.';
    } else if (destination.isEmpty) {
      validation = 'Indiquez votre destination.';
    } else if (!_current && _origin.text.trim().isEmpty) {
      validation = 'Indiquez votre lieu de départ.';
    } else if (cons == null || cons <= 0 || price == null || price <= 0) {
      validation =
          'Renseignez votre consommation moyenne et votre prix d’énergie.';
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
        final p = _position ?? await _locate();
        _position = p;
        origin = {'lat': p.lat, 'lng': p.lng, 'label': 'Ma position'};
      } else {
        origin = {'query': _origin.text.trim()};
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('smart_trip_consumption_${v!.id}', cons!);
      await prefs.setDouble('smart_trip_price_${v.id}', price!);
      await prefs.setInt('smart_trip_delay', _delay);
      final result = await _service.analyze(
        vehicleId: v.id,
        origin: origin,
        destination: {'query': destination},
        consumptionPer100: cons,
        energyPrice: price,
        maxExtraMinutes: _delay,
      );
      if (mounted) {
        setState(() => _result = result);
      }
    } on SmartTripException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
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
    final r = _result;
    if (r == null) {
      return;
    }
    final p = <String, String>{
      'api': '1',
      'origin': r.origin.coordinate,
      'destination': r.destination.coordinate,
      'travelmode': 'driving',
    };
    if (r.navigationWaypoints.isNotEmpty) {
      p['waypoints'] = r.navigationWaypoints.map((x) => x.coordinate).join('|');
    }
    await _launch(Uri.https('www.google.com', '/maps/dir/', p));
  }

  Future<void> _apple() async {
    final r = _result;
    if (r == null) {
      return;
    }
    await _launch(
      Uri.https('maps.apple.com', '/', {
        'saddr': r.origin.coordinate,
        'daddr': r.destination.coordinate,
        'dirflg': 'd',
      }),
    );
  }

  Future<void> _waze() async {
    final r = _result;
    if (r == null) {
      return;
    }
    await _launch(
      Uri.https('www.waze.com', '/ul', {
        'll': r.destination.coordinate,
        'navigate': 'yes',
      }),
    );
  }

  Future<void> _launch(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le GPS choisi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
            'AutoClair compare temps, kilomètres, péages et carburant. La consommation est adaptée au profil de vitesse et au trafic. Un détour n’est proposé que si l’économie est significative.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
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
                    'Ajoutez d’abord un véhicule pour personnaliser le coût du trajet.',
                  )
                else
                  DropdownButtonFormField<Vehicle>(
                    initialValue: _vehicle,
                    decoration: const InputDecoration(
                      labelText: 'Véhicule',
                      prefixIcon: Icon(Icons.directions_car_outlined),
                    ),
                    items: [
                      for (final v in _vehicles)
                        DropdownMenuItem(value: v, child: Text(v.displayName)),
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
                      label: Text('Autre départ'),
                      icon: Icon(Icons.edit_location_alt_outlined),
                    ),
                  ],
                  selected: {_current},
                  onSelectionChanged: (s) => setState(() {
                    _current = s.first;
                    _result = null;
                    _error = null;
                  }),
                ),
                if (!_current) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _origin,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Départ',
                      hintText: 'Paris, adresse…',
                      prefixIcon: Icon(Icons.trip_origin),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _destination,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    hintText: 'Marseille, adresse…',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, c) {
                    final fields = [
                      TextField(
                        controller: _consumption,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _electric
                              ? 'Consommation (kWh/100 km)'
                              : 'Consommation (L/100 km)',
                          prefixIcon: const Icon(Icons.speed_outlined),
                        ),
                      ),
                      TextField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _electric ? 'Prix (€/kWh)' : 'Prix (€/L)',
                          prefixIcon: const Icon(Icons.euro_outlined),
                        ),
                      ),
                    ];
                    if (c.maxWidth < 520) {
                      return Column(
                        children: [
                          fields[0],
                          const SizedBox(height: 12),
                          fields[1],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: fields[0]),
                        const SizedBox(width: 12),
                        Expanded(child: fields[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Temps supplémentaire maximum',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in const [5, 10, 15, 30])
                      ChoiceChip(
                        label: Text('+$m min'),
                        selected: _delay == m,
                        onSelected: (_) => setState(() {
                          _delay = m;
                          _result = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
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
                    _busy
                        ? 'Comparaison en cours…'
                        : 'Analyser le meilleur compromis',
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'La consommation et le prix restent uniquement sur cet appareil.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (_electric) ...[
            const SizedBox(height: 14),
            const _Notice(
              text:
                  'Véhicule électrique : la V1 dédiée intégrera autonomie, recharge et prix des bornes. Le calcul financier n’est pas proposé tant qu’il serait incomplet.',
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
              energy: _energy,
              onGoogle: _google,
              onApple: _apple,
              onWaze: _waze,
            ),
          ],
        ],
      ),
    ),
  );
  static String _compact(double v) => v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.error});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Container(
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

class _Result extends StatelessWidget {
  const _Result({
    required this.result,
    required this.energy,
    required this.onGoogle,
    required this.onApple,
    required this.onWaze,
  });
  final SmartTripResult result;
  final String energy;
  final VoidCallback onGoogle, onApple, onWaze;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Notice(
        text: result.hasSaving
            ? 'Économie nette : ${_money(result.comparison.netSavingEur)} · ${result.comparison.extraMinutes > 0 ? '+${result.comparison.extraMinutes.round()} min' : 'sans temps supplémentaire significatif'}'
            : 'Le trajet classique est déjà le meilleur compromis dans le temps accepté.',
        error: false,
      ),
      const SizedBox(height: 12),
      _Route(title: 'Trajet classique', route: result.baseline, energy: energy),
      if (result.hasSaving) ...[
        const SizedBox(height: 12),
        _Route(
          title: 'Trajet AutoClair',
          route: result.recommended,
          energy: energy,
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            children: [
              _Line('Temps', _signed(result.comparison.extraMinutes, 'min', 0)),
              _Line('Distance', _signed(result.comparison.extraKm, 'km', 1)),
              _Line('Péage', '-${_money(result.comparison.tollSavingEur)}'),
              _Line(
                energy,
                result.comparison.energyCostDeltaEur >= 0
                    ? '+${_money(result.comparison.energyCostDeltaEur)}'
                    : '-${_money(result.comparison.energyCostDeltaEur.abs())}',
              ),
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
            child: OutlinedButton(onPressed: onWaze, child: const Text('Waze')),
          ),
        ],
      ),
      if (result.hasSaving) ...[
        const SizedBox(height: 8),
        Text(
          'Google Maps reçoit des points de passage pour conserver le corridor optimisé. Plans et Waze peuvent recalculer un autre itinéraire.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      ],
      const SizedBox(height: 8),
      Text(
        '${result.testedRoutes} variantes comparées · estimation à actualiser si trafic ou tarifs changent.',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
      ),
    ],
  );
}

class _Route extends StatelessWidget {
  const _Route({
    required this.title,
    required this.route,
    required this.energy,
  });
  final String title, energy;
  final SmartTripRoute route;
  @override
  Widget build(BuildContext context) => _Card(
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
              '$energy ${route.energyQuantity.toStringAsFixed(1).replaceAll('.', ',')} L · ${_money(route.energyCostEur)}',
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false});
  final String label, value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: strong ? const TextStyle(fontWeight: FontWeight.w900) : null,
          ),
        ),
        Text(
          value,
          style: strong ? const TextStyle(fontWeight: FontWeight.w900) : null,
        ),
      ],
    ),
  );
}

String _money(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} €';
String _duration(double v) {
  final t = v.round(), h = t ~/ 60, m = t % 60;
  return h == 0 ? '$m min' : '${h}h${m.toString().padLeft(2, '0')}';
}

String _signed(double v, String unit, int d) =>
    '${v > 0 ? '+' : ''}${v.toStringAsFixed(d).replaceAll('.', ',')} $unit';
