import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import 'trip_readiness_calculator.dart';
import 'trip_readiness_models.dart';
import 'trip_readiness_service.dart';

class TripReadinessPage extends StatefulWidget {
  const TripReadinessPage({super.key});

  @override
  State<TripReadinessPage> createState() => _TripReadinessPageState();
}

class _TripReadinessPageState extends State<TripReadinessPage> {
  final _service = TripReadinessService();

  List<Vehicle> _vehicles = const [];
  List<TripReadinessSnapshot> _recent = const [];
  String? _selectedVehicleId;
  DateTime _departureDate = DateTime.now();
  TripPurpose _purpose = TripPurpose.everyday;
  Map<TripReadinessArea, TripCheckStatus> _checks = {
    for (final area in TripReadinessArea.values)
      area: TripCheckStatus.notChecked,
  };
  bool _longDistance = false;
  bool _towing = false;
  bool _coldConditions = false;
  bool _youngPassengers = false;
  bool _breakdownCoverageKnown = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  TripReadinessAssessment? _assessment;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final vehicles = await _service.loadVehicles();
      final selected = vehicles.isEmpty
          ? null
          : vehicles
                .firstWhere(
                  (vehicle) => vehicle.isPrimary,
                  orElse: () => vehicles.first,
                )
                .id;
      var recent = <TripReadinessSnapshot>[];
      if (selected != null) {
        recent = await _service.loadRecentChecks(selected);
      }
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _selectedVehicleId = selected;
        _recent = recent;
        _loading = false;
      });
    } on TripReadinessException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Vehicle? get _selectedVehicle {
    for (final vehicle in _vehicles) {
      if (vehicle.id == _selectedVehicleId) return vehicle;
    }
    return null;
  }

  TripReadinessProfile _profile() => TripReadinessProfile(
    vehicleId: _selectedVehicleId ?? '',
    departureDate: _departureDate,
    purpose: _purpose,
    checks: Map.unmodifiable(_checks),
    longDistance: _longDistance,
    towing: _towing,
    coldConditions: _coldConditions,
    youngPassengers: _youngPassengers,
    breakdownCoverageKnown: _breakdownCoverageKnown,
  );

  void _update(VoidCallback change) {
    setState(() {
      change();
      _assessment = null;
      _error = null;
    });
  }

  Future<void> _selectVehicle(String vehicleId) async {
    _update(() {
      _selectedVehicleId = vehicleId;
      _recent = const [];
    });
    try {
      final recent = await _service.loadRecentChecks(vehicleId);
      if (!mounted || _selectedVehicleId != vehicleId) return;
      setState(() => _recent = recent);
    } on TripReadinessException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _departureDate.isBefore(now) ? now : _departureDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      helpText: 'Date prévue du départ',
    );
    if (selected != null) _update(() => _departureDate = selected);
  }

  Future<void> _evaluate() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = _profile();
      final assessment = TripReadinessCalculator.assess(profile);
      await _service.saveCheck(profile: profile, assessment: assessment);
      final recent = await _service.loadRecentChecks(profile.vehicleId);
      if (!mounted) return;
      setState(() {
        _assessment = assessment;
        _recent = recent;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Préparation enregistrée.')));
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on TripReadinessException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copySummary() async {
    final assessment = _assessment;
    final vehicle = _selectedVehicle;
    if (assessment == null || vehicle == null) return;
    await Clipboard.setData(
      ClipboardData(
        text: assessment.buildShareSummary(
          vehicleLabel: vehicle.displayName,
          profile: _profile(),
        ),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Résumé de préparation copié.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Préparer mon départ')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ajoutez d’abord un véhicule pour préparer votre départ.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => context.push<void>('/vehicles/new'),
                      child: const Text('Ajouter un véhicule'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              key: const ValueKey('trip-readiness-scroll'),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                const _TripIntro(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Départ prévu',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedVehicleId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Véhicule',
                        ),
                        items: [
                          for (final vehicle in _vehicles)
                            DropdownMenuItem(
                              value: vehicle.id,
                              child: Text(vehicle.displayName),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) _selectVehicle(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<TripPurpose>(
                        initialValue: _purpose,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Type de déplacement',
                        ),
                        items: [
                          for (final purpose in TripPurpose.values)
                            DropdownMenuItem(
                              value: purpose,
                              child: Text(purpose.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) _update(() => _purpose = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: const Text('Date de départ'),
                        subtitle: Text(_formatDate(_departureDate)),
                        trailing: const Icon(Icons.edit_calendar_outlined),
                        onTap: _pickDate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Contexte',
                  child: Column(
                    children: [
                      _OptionSwitch(
                        title: 'Long trajet',
                        subtitle:
                            'La fatigue et les pauses deviennent prioritaires.',
                        value: _longDistance,
                        onChanged: (value) =>
                            _update(() => _longDistance = value),
                      ),
                      _OptionSwitch(
                        title: 'Conditions froides ou hivernales',
                        subtitle:
                            'Les pneus et équipements doivent être adaptés.',
                        value: _coldConditions,
                        onChanged: (value) =>
                            _update(() => _coldConditions = value),
                      ),
                      _OptionSwitch(
                        title: 'Remorque ou charge tractée',
                        subtitle:
                            'L’attelage, la charge et l’éclairage sont à vérifier.',
                        value: _towing,
                        onChanged: (value) => _update(() => _towing = value),
                      ),
                      _OptionSwitch(
                        title: 'Jeunes passagers',
                        subtitle:
                            'Les dispositifs de retenue doivent être adaptés.',
                        value: _youngPassengers,
                        onChanged: (value) =>
                            _update(() => _youngPassengers = value),
                      ),
                      _OptionSwitch(
                        title: 'Assistance panne retrouvée',
                        subtitle: 'Numéro et périmètre de couverture connus.',
                        value: _breakdownCoverageKnown,
                        onChanged: (value) =>
                            _update(() => _breakdownCoverageKnown = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Checklist avant départ',
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < TripReadinessArea.values.length;
                        index++
                      ) ...[
                        _AreaField(
                          key: ValueKey(
                            'trip-${TripReadinessArea.values[index].databaseValue}',
                          ),
                          area: TripReadinessArea.values[index],
                          value:
                              _checks[TripReadinessArea.values[index]] ??
                              TripCheckStatus.notChecked,
                          onChanged: (value) => _update(
                            () => _checks = {
                              ..._checks,
                              TripReadinessArea.values[index]: value,
                            },
                          ),
                        ),
                        if (index < TripReadinessArea.values.length - 1)
                          const Divider(height: 20),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('trip-readiness-evaluate'),
                  onPressed: _saving ? null : _evaluate,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fact_check_outlined),
                  label: const Text('Évaluer ma préparation'),
                ),
                if (_assessment != null) ...[
                  const SizedBox(height: 16),
                  _TripResult(
                    assessment: _assessment!,
                    onCopy: _copySummary,
                    onInspection: () =>
                        context.push<void>('/vehicle-inspection'),
                    onMaintenance: () =>
                        context.push<void>('/maintenance-planner'),
                    onBreakdown: () =>
                        context.push<void>('/breakdown-assistant'),
                  ),
                ],
                if (_recent.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _RecentChecks(items: _recent),
                ],
              ],
            ),
    );
  }
}

class _TripIntro extends StatelessWidget {
  const _TripIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.route_outlined, color: Colors.white, size: 34),
          SizedBox(height: 12),
          Text(
            'Un départ plus serein, sans partager votre destination',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Vérifiez les éléments essentiels. AutoClair ne suit ni votre trajet, ni votre position.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _OptionSwitch extends StatelessWidget {
  const _OptionSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _AreaField extends StatelessWidget {
  const _AreaField({
    super.key,
    required this.area,
    required this.value,
    required this.onChanged,
  });

  final TripReadinessArea area;
  final TripCheckStatus value;
  final ValueChanged<TripCheckStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<TripCheckStatus>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: area.label,
        helperText: area.isSafetyCritical
            ? 'Point de sécurité prioritaire'
            : null,
      ),
      items: [
        for (final status in TripCheckStatus.values)
          DropdownMenuItem(value: status, child: Text(status.label)),
      ],
      onChanged: (status) {
        if (status != null) onChanged(status);
      },
    );
  }
}

class _TripResult extends StatelessWidget {
  const _TripResult({
    required this.assessment,
    required this.onCopy,
    required this.onInspection,
    required this.onMaintenance,
    required this.onBreakdown,
  });

  final TripReadinessAssessment assessment;
  final VoidCallback onCopy;
  final VoidCallback onInspection;
  final VoidCallback onMaintenance;
  final VoidCallback onBreakdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('trip-readiness-result'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            assessment.level.label,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Indice ${assessment.score}/100 · ${assessment.completenessPercent} % vérifié',
          ),
          if (assessment.blockingCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${assessment.blockingCount} point(s) déclaré(s) bloquant(s).',
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (assessment.findings.isEmpty)
            const Text('Aucune action déclarée parmi les points vérifiés.')
          else
            for (final finding in assessment.findings.take(6)) ...[
              Text(
                finding.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(finding.action),
              const SizedBox(height: 10),
            ],
          const Text(
            'Cette checklist ne remplace ni les informations officielles, ni la météo, ni un contrôle professionnel.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copier le résumé'),
              ),
              OutlinedButton.icon(
                onPressed: onInspection,
                icon: const Icon(Icons.checklist_rounded),
                label: const Text('Inspecter le véhicule'),
              ),
              OutlinedButton.icon(
                onPressed: onMaintenance,
                icon: const Icon(Icons.build_outlined),
                label: const Text('Planifier l’entretien'),
              ),
              OutlinedButton.icon(
                onPressed: onBreakdown,
                icon: const Icon(Icons.car_crash_outlined),
                label: const Text('Préparer l’assistance'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentChecks extends StatelessWidget {
  const _RecentChecks({required this.items});

  final List<TripReadinessSnapshot> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Préparations récentes',
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded),
              title: Text(items[index].purpose.label),
              subtitle: Text(
                '${_formatDate(items[index].departureDate)} · ${items[index].level.label}',
              ),
              trailing: Text('${items[index].score}/100'),
            ),
            if (index < items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
