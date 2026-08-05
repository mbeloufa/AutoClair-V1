import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/finance/money_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'eco_driving_models.dart';
import 'eco_driving_service.dart';
import 'eco_driving_tracker.dart';

class EcoDrivingPage extends StatefulWidget {
  const EcoDrivingPage({super.key});

  @override
  State<EcoDrivingPage> createState() => _EcoDrivingPageState();
}

class _EcoDrivingPageState extends State<EcoDrivingPage>
    with WidgetsBindingObserver {
  final _vehicleService = VehicleService();
  final _ecoService = EcoDrivingService();
  final _tracker = EcoDrivingTracker();
  final _consumptionController = TextEditingController(text: '6.5');
  final _priceController = TextEditingController(text: '1.85');

  List<Vehicle> _vehicles = const [];
  List<EcoDrivingSessionRecord> _recentSessions = const [];
  String? _vehicleId;
  EcoDrivingEnergyType _energyType = EcoDrivingEnergyType.fuel;
  double _potentialGainPercent = 5;
  EcoDrivingLiveMetrics _liveMetrics = const EcoDrivingLiveMetrics.empty();
  EcoDrivingSessionSummary? _lastSummary;
  EcoDrivingProfile? _activeProfile;
  bool _loading = true;
  bool _tracking = false;
  bool _stopping = false;
  bool _settingsRequired = false;
  bool _openLocationServices = false;
  String? _error;

  Vehicle? get _selectedVehicle {
    for (final vehicle in _vehicles) {
      if (vehicle.id == _vehicleId) return vehicle;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVehicles();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_tracking && !_stopping && state != AppLifecycleState.resumed) {
      unawaited(_stopTrip(automatic: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _consumptionController.dispose();
    _priceController.dispose();
    unawaited(_tracker.cancel());
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vehicles = await _vehicleService.fetchVehicles();
      if (!mounted) return;
      final selected = vehicles.isEmpty
          ? null
          : vehicles.firstWhere(
              (vehicle) => vehicle.isPrimary,
              orElse: () => vehicles.first,
            );
      setState(() {
        _vehicles = vehicles;
        _vehicleId = selected?.id;
        _loading = false;
      });
      if (selected != null) {
        await _loadVehicleData(selected);
      }
    } on VehicleServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadVehicleData(Vehicle vehicle) async {
    final defaultProfile = EcoDrivingProfile.defaultsForFuelType(
      vehicle.fuelType,
    );
    try {
      final results = await Future.wait<Object?>([
        _ecoService.loadProfile(vehicle.id),
        _ecoService.fetchRecentSessions(vehicle.id),
      ]);
      if (!mounted || vehicle.id != _vehicleId) return;
      final profile = results[0] as EcoDrivingProfile? ?? defaultProfile;
      final sessions = results[1] as List<EcoDrivingSessionRecord>;
      setState(() {
        _applyProfile(profile);
        _recentSessions = sessions;
      });
    } on EcoDrivingServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _applyProfile(defaultProfile);
        _recentSessions = const [];
        _error = error.message;
      });
    }
  }

  void _applyProfile(EcoDrivingProfile profile) {
    _energyType = profile.energyType;
    _consumptionController.text = profile.consumptionPer100Km.toStringAsFixed(
      1,
    );
    _priceController.text = profile.energyPrice.toStringAsFixed(2);
    _potentialGainPercent = profile.potentialGainPercent;
  }

  Future<void> _changeVehicle(String? vehicleId) async {
    if (vehicleId == null || vehicleId == _vehicleId || _tracking) return;
    Vehicle? selected;
    for (final vehicle in _vehicles) {
      if (vehicle.id == vehicleId) selected = vehicle;
    }
    if (selected == null) return;
    setState(() {
      _vehicleId = vehicleId;
      _lastSummary = null;
      _recentSessions = const [];
      _error = null;
    });
    await _loadVehicleData(selected);
  }

  EcoDrivingProfile? _readProfile() {
    final consumption = double.tryParse(
      _consumptionController.text.trim().replaceAll(',', '.'),
    );
    final price = double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    );
    if (consumption == null ||
        consumption <= 0 ||
        consumption > 100 ||
        price == null ||
        price < 0 ||
        price > 10) {
      return null;
    }
    return EcoDrivingProfile(
      energyType: _energyType,
      consumptionPer100Km: consumption,
      energyPrice: price,
      potentialGainPercent: _potentialGainPercent,
    );
  }

  Future<void> _startTrip() async {
    final vehicle = _selectedVehicle;
    final profile = _readProfile();
    if (vehicle == null) {
      _show('Ajoutez un véhicule avant de démarrer un trajet.');
      return;
    }
    if (profile == null) {
      _show('Vérifiez la consommation et le prix de l’énergie.');
      return;
    }

    setState(() {
      _error = null;
      _settingsRequired = false;
      _openLocationServices = false;
      _lastSummary = null;
      _liveMetrics = const EcoDrivingLiveMetrics.empty();
    });

    try {
      await _ecoService.saveProfile(vehicleId: vehicle.id, profile: profile);
      await _tracker.start(
        onMetrics: (metrics) {
          if (!mounted) return;
          setState(() => _liveMetrics = metrics);
        },
        onError: (message) {
          if (!mounted) return;
          setState(() => _error = message);
        },
      );
      if (!mounted) return;
      setState(() {
        _tracking = true;
        _activeProfile = profile;
      });
    } on EcoDrivingTrackerException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _settingsRequired = error.settingsRequired;
        _openLocationServices = error.openLocationServices;
      });
    } on EcoDrivingServiceException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _stopTrip({bool automatic = false}) async {
    if (!_tracking || _stopping) return;
    final vehicle = _selectedVehicle;
    final profile = _activeProfile;
    if (vehicle == null || profile == null) return;

    setState(() => _stopping = true);
    try {
      final summary = await _tracker.stop(profile: profile);
      final saveResult = await _ecoService.saveSession(
        vehicleId: vehicle.id,
        profile: profile,
        summary: summary,
      );
      final sessions = await _ecoService.fetchRecentSessions(vehicle.id);
      if (!mounted) return;
      setState(() {
        _tracking = false;
        _stopping = false;
        _activeProfile = null;
        _lastSummary = summary;
        _recentSessions = sessions;
      });
      if (automatic) {
        _show(
          'Trajet arrêté automatiquement : AutoClair a quitté le premier plan.',
        );
      } else if (saveResult.savingOpportunityRecorded) {
        _show('Bilan enregistré avec une économie potentielle.');
      } else {
        _show('Bilan du trajet enregistré.');
      }
    } on Object catch (error) {
      await _tracker.cancel();
      if (!mounted) return;
      final message = error is EcoDrivingTrackerException
          ? error.message
          : error is EcoDrivingServiceException
          ? error.message
          : 'Le bilan du trajet n’a pas pu être terminé.';
      setState(() {
        _tracking = false;
        _stopping = false;
        _activeProfile = null;
        _error = message;
      });
    }
  }

  Future<void> _openSettings() async {
    await _tracker.openSettings(locationServices: _openLocationServices);
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coach d’écoconduite')),
      body: RefreshIndicator(
        onRefresh: _tracking ? () async {} : _loadVehicles,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const EcoDrivingPrivacyNotice(),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_vehicles.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Ajoutez un véhicule avant d’utiliser le coach.'),
                ),
              )
            else ...[
              _buildProfileCard(),
              const SizedBox(height: 16),
              if (_tracking || _stopping) _buildLiveCard(),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _EcoDrivingErrorCard(
                  message: _error!,
                  settingsRequired: _settingsRequired,
                  onSettings: _openSettings,
                ),
              ],
              if (_lastSummary != null) ...[
                const SizedBox(height: 16),
                _EcoDrivingSummaryCard(summary: _lastSummary!),
              ],
              if (_recentSessions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _RecentEcoDrivingSessions(sessions: _recentSessions),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('eco-driving-vehicle-selector'),
              initialValue: _vehicleId,
              decoration: const InputDecoration(labelText: 'Véhicule'),
              items: _vehicles
                  .map(
                    (vehicle) => DropdownMenuItem(
                      value: vehicle.id,
                      child: Text(vehicle.displayName),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _tracking ? null : _changeVehicle,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<EcoDrivingEnergyType>(
              key: const ValueKey('eco-driving-energy-type'),
              initialValue: _energyType,
              decoration: const InputDecoration(labelText: 'Énergie'),
              items: EcoDrivingEnergyType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(growable: false),
              onChanged: _tracking
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _energyType = value);
                    },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _consumptionController,
              enabled: !_tracking,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Consommation (${_energyType.consumptionUnit})',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _priceController,
              enabled: !_tracking,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Prix de l’énergie (${_energyType.priceUnit})',
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Gain maximal étudié : '
              '${_potentialGainPercent.toStringAsFixed(0)} %',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _potentialGainPercent,
              min: 1,
              max: 10,
              divisions: 9,
              label: '${_potentialGainPercent.toStringAsFixed(0)} %',
              onChanged: _tracking
                  ? null
                  : (value) {
                      setState(() => _potentialGainPercent = value);
                    },
            ),
            const SizedBox(height: 10),
            if (_tracking)
              FilledButton.icon(
                key: const ValueKey('eco-driving-stop'),
                onPressed: _stopping ? null : () => _stopTrip(),
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(
                  _stopping ? 'Arrêt en cours…' : 'Terminer le trajet',
                ),
              )
            else
              FilledButton.icon(
                key: const ValueKey('eco-driving-start'),
                onPressed: _startTrip,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Démarrer le trajet'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sensors, color: AppColors.success),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Trajet en cours',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _MetricRow(
              label: 'Durée',
              value: _duration(_liveMetrics.durationSeconds),
            ),
            _MetricRow(
              label: 'Distance',
              value: '${_liveMetrics.distanceKm.toStringAsFixed(2)} km',
            ),
            _MetricRow(
              label: 'Vitesse actuelle',
              value: '${_liveMetrics.currentSpeedKph.toStringAsFixed(0)} km/h',
            ),
            _MetricRow(
              label: 'Accélérations fortes',
              value: '${_liveMetrics.harshAccelerationCount}',
            ),
            _MetricRow(
              label: 'Freinages forts',
              value: '${_liveMetrics.harshBrakingCount}',
            ),
          ],
        ),
      ),
    );
  }
}

class EcoDrivingPrivacyNotice extends StatelessWidget {
  const EcoDrivingPrivacyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.softPrimary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, color: AppColors.primary, size: 30),
          SizedBox(height: 10),
          Text(
            'Votre trajet reste privé',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
          ),
          SizedBox(height: 6),
          Text(
            'Le suivi fonctionne uniquement après votre action et s’arrête '
            'lorsque l’application quitte le premier plan. Aucun point GPS '
            'ni itinéraire n’est enregistré : seules les statistiques '
            'agrégées du trajet sont conservées.',
          ),
        ],
      ),
    );
  }
}

class _EcoDrivingSummaryCard extends StatelessWidget {
  const _EcoDrivingSummaryCard({required this.summary});

  final EcoDrivingSessionSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _scoreBackground(summary.score),
                  foregroundColor: _scoreForeground(summary.score),
                  child: Text('${summary.score}'),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Bilan du trajet',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _MetricRow(
              label: 'Distance analysée',
              value: '${summary.distanceKm.toStringAsFixed(2)} km',
            ),
            _MetricRow(
              label: 'Durée',
              value: _duration(summary.durationSeconds),
            ),
            _MetricRow(
              label: 'Coût énergétique estimé',
              value: MoneyFormatter.euros(summary.baselineEnergyCost),
            ),
            _MetricRow(
              label: 'Économie potentielle',
              value: summary.isMeaningful
                  ? MoneyFormatter.euros(summary.potentialSaving)
                  : 'Estimation insuffisante',
            ),
            const Divider(height: 26),
            for (final recommendation in summary.recommendations) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(recommendation)),
                ],
              ),
              const SizedBox(height: 9),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentEcoDrivingSessions extends StatelessWidget {
  const _RecentEcoDrivingSessions({required this.sessions});

  final List<EcoDrivingSessionRecord> sessions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Derniers trajets',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < sessions.length; index++) ...[
              _RecentSessionTile(session: sessions[index]),
              if (index != sessions.length - 1) const Divider(height: 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentSessionTile extends StatelessWidget {
  const _RecentSessionTile({required this.session});

  final EcoDrivingSessionRecord session;

  @override
  Widget build(BuildContext context) {
    final date = session.startedAt.toLocal();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
    return Row(
      children: [
        CircleAvatar(child: Text('${session.score}')),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$dateLabel · ${session.distanceKm.toStringAsFixed(1)} km',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(_duration(session.durationSeconds)),
            ],
          ),
        ),
        Text(
          MoneyFormatter.euros(session.potentialSaving),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _EcoDrivingErrorCard extends StatelessWidget {
  const _EcoDrivingErrorCard({
    required this.message,
    required this.settingsRequired,
    required this.onSettings,
  });

  final String message;
  final bool settingsRequired;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            if (settingsRequired) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onSettings,
                child: const Text('Ouvrir les réglages'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainingSeconds = seconds % 60;
  if (hours > 0) {
    return '$hours h ${minutes.toString().padLeft(2, '0')} min';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${remainingSeconds.toString().padLeft(2, '0')}';
}

Color _scoreBackground(int score) {
  if (score >= 80) return AppColors.successSoft;
  if (score >= 60) return AppColors.warningSoft;
  return AppColors.errorSoft;
}

Color _scoreForeground(int score) {
  if (score >= 80) return AppColors.success;
  if (score >= 60) return AppColors.warning;
  return AppColors.error;
}
