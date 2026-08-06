import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import 'workshop_visit_preparation_calculator.dart';
import 'workshop_visit_preparation_models.dart';
import 'workshop_visit_preparation_service.dart';

class WorkshopVisitPreparationPage extends StatefulWidget {
  const WorkshopVisitPreparationPage({super.key});

  @override
  State<WorkshopVisitPreparationPage> createState() =>
      _WorkshopVisitPreparationPageState();
}

class _WorkshopVisitPreparationPageState
    extends State<WorkshopVisitPreparationPage> {
  final _service = WorkshopVisitPreparationService();
  List<Vehicle> _vehicles = const [];
  List<WorkshopVisitPreparationSnapshot> _recent = const [];
  String? _selectedVehicleId;
  DateTime _plannedDate = DateTime.now().add(const Duration(days: 7));
  WorkshopVisitReason _visitReason = WorkshopVisitReason.routineMaintenance;
  bool _vehicleCanMoveSafely = true;
  bool _warningLightOn = false;
  Map<WorkshopPreparationArea, WorkshopPreparationStatus> _checks = {
    for (final area in WorkshopPreparationArea.values)
      area: WorkshopPreparationStatus.notChecked,
  };
  WorkshopVisitPreparationAssessment? _assessment;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  Vehicle? get _selectedVehicle {
    for (final vehicle in _vehicles) {
      if (vehicle.id == _selectedVehicleId) {
        return vehicle;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final vehicles = await _service.fetchVehicles();
      if (!mounted) {
        return;
      }
      Vehicle? selected;
      for (final vehicle in vehicles) {
        if (vehicle.isPrimary) {
          selected = vehicle;
          break;
        }
      }
      selected ??= vehicles.isEmpty ? null : vehicles.first;
      setState(() {
        _vehicles = vehicles;
        _selectedVehicleId = selected?.id;
        _loading = false;
      });
      if (_selectedVehicleId != null) {
        await _loadRecent();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Impossible de charger les véhicules.';
        _loading = false;
      });
    }
  }

  Future<void> _loadRecent() async {
    final vehicleId = _selectedVehicleId;
    if (vehicleId == null) {
      return;
    }
    try {
      final recent = await _service.fetchRecent(vehicleId);
      if (!mounted || vehicleId != _selectedVehicleId) {
        return;
      }
      setState(() => _recent = recent);
    } on WorkshopVisitPreparationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.message);
    }
  }

  Future<void> _selectVehicle(String id) async {
    setState(() {
      _selectedVehicleId = id;
      _recent = const [];
      _assessment = null;
      _error = null;
    });
    await _loadRecent();
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _assessment = null;
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _plannedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (selected != null) {
      _update(() => _plannedDate = selected);
    }
  }

  WorkshopVisitPreparationProfile _buildProfile() =>
      WorkshopVisitPreparationProfile(
        vehicleId: _selectedVehicleId ?? '',
        plannedDate: _plannedDate,
        visitReason: _visitReason,
        checks: _checks,
        vehicleCanMoveSafely: _vehicleCanMoveSafely,
        warningLightOn: _warningLightOn,
      );

  Future<void> _evaluate() async {
    final profile = _buildProfile();
    try {
      profile.validate();
      final assessment = WorkshopVisitPreparationCalculator.assess(profile);
      setState(() {
        _saving = true;
        _assessment = assessment;
        _error = null;
      });
      await _service.save(profile: profile, assessment: assessment);
      await _loadRecent();
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
    } on FormatException catch (error) {
      setState(() {
        _error = error.message;
        _saving = false;
      });
    } on WorkshopVisitPreparationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _saving = false;
      });
    }
  }

  Future<void> _copySummary() async {
    final assessment = _assessment;
    final vehicle = _selectedVehicle;
    if (assessment == null || vehicle == null) {
      return;
    }
    final summary = assessment.buildShareSummary(
      vehicleLabel: vehicle.displayName,
      profile: _buildProfile(),
    );
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Résumé copié.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Préparer ma visite au garage')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_car_outlined, size: 52),
                    const SizedBox(height: 14),
                    const Text(
                      'Ajoutez un véhicule avant de préparer la visite au garage.',
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
              key: const ValueKey('workshop-visit-scroll'),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                const _WorkshopIntro(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Rendez-vous',
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
                          if (value != null) {
                            _selectVehicle(value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<WorkshopVisitReason>(
                        initialValue: _visitReason,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Motif de la visite',
                        ),
                        items: [
                          for (final item in WorkshopVisitReason.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _update(() => _visitReason = value);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: const Text('Date prévue'),
                        subtitle: Text(_formatDate(_plannedDate)),
                        trailing: const Icon(Icons.edit_calendar_outlined),
                        onTap: _pickDate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Situation actuelle',
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Le véhicule peut être déplacé sans danger manifeste',
                        ),
                        subtitle: const Text(
                          'En cas de doute sur la sécurité, ne circulez pas.',
                        ),
                        value: _vehicleCanMoveSafely,
                        onChanged: (value) =>
                            _update(() => _vehicleCanMoveSafely = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Un voyant reste allumé'),
                        subtitle: const Text(
                          'Hors témoins normaux liés au contact ou au démarrage.',
                        ),
                        value: _warningLightOn,
                        onChanged: (value) =>
                            _update(() => _warningLightOn = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Préparation du rendez-vous',
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < WorkshopPreparationArea.values.length;
                        index++
                      ) ...[
                        _AreaField(
                          key: ValueKey(
                            'workshop-visit-${WorkshopPreparationArea.values[index].databaseValue}',
                          ),
                          area: WorkshopPreparationArea.values[index],
                          value:
                              _checks[WorkshopPreparationArea.values[index]]!,
                          onChanged: (value) => _update(
                            () => _checks = {
                              ..._checks,
                              WorkshopPreparationArea.values[index]: value,
                            },
                          ),
                        ),
                        if (index < WorkshopPreparationArea.values.length - 1)
                          const Divider(height: 20),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('workshop-visit-evaluate'),
                  onPressed: _saving ? null : _evaluate,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.car_repair_outlined),
                  label: const Text('Préparer le dossier'),
                ),
                if (_assessment != null) ...[
                  const SizedBox(height: 16),
                  _WorkshopResult(
                    assessment: _assessment!,
                    onCopy: _copySummary,
                    onQuoteComparison: () =>
                        context.push<void>('/quote-comparison'),
                    onDocuments: () => context.push<void>('/history'),
                    onMaintenance: () =>
                        context.push<void>('/maintenance-planner'),
                  ),
                ],
                if (_recent.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _RecentPreparations(items: _recent),
                ],
              ],
            ),
    );
  }
}

class _WorkshopIntro extends StatelessWidget {
  const _WorkshopIntro();

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
          Icon(Icons.car_repair_outlined, color: Colors.white, size: 34),
          SizedBox(height: 12),
          Text(
            'Arriver avec un dossier clair',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'La checklist organise les faits, documents et décisions à clarifier. Elle ne pose aucun diagnostic.',
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

class _AreaField extends StatelessWidget {
  const _AreaField({
    super.key,
    required this.area,
    required this.value,
    required this.onChanged,
  });

  final WorkshopPreparationArea area;
  final WorkshopPreparationStatus value;
  final ValueChanged<WorkshopPreparationStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<WorkshopPreparationStatus>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: area.label,
        helperText: area.isSafetyCritical
            ? 'Point à clarifier avant de circuler'
            : null,
      ),
      items: [
        for (final status in WorkshopPreparationStatus.values)
          DropdownMenuItem(value: status, child: Text(status.label)),
      ],
      onChanged: (status) {
        if (status != null) {
          onChanged(status);
        }
      },
    );
  }
}

class _WorkshopResult extends StatelessWidget {
  const _WorkshopResult({
    required this.assessment,
    required this.onCopy,
    required this.onQuoteComparison,
    required this.onDocuments,
    required this.onMaintenance,
  });

  final WorkshopVisitPreparationAssessment assessment;
  final VoidCallback onCopy;
  final VoidCallback onQuoteComparison;
  final VoidCallback onDocuments;
  final VoidCallback onMaintenance;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('workshop-visit-result'),
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
          if (assessment.urgentCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${assessment.urgentCount} point(s) urgent(s) déclaré(s).',
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (assessment.findings.isEmpty)
            const Text('Le dossier déclaré est prêt à être présenté.')
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
            'Cette préparation ne pose aucun diagnostic et ne vaut ni devis ni autorisation de travaux.',
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
                onPressed: onQuoteComparison,
                icon: const Icon(Icons.request_quote_outlined),
                label: const Text('Comparer les devis'),
              ),
              OutlinedButton.icon(
                onPressed: onDocuments,
                icon: const Icon(Icons.folder_copy_outlined),
                label: const Text('Voir mes documents'),
              ),
              OutlinedButton.icon(
                onPressed: onMaintenance,
                icon: const Icon(Icons.build_outlined),
                label: const Text('Planifier l’entretien'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentPreparations extends StatelessWidget {
  const _RecentPreparations({required this.items});

  final List<WorkshopVisitPreparationSnapshot> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Visites préparées récemment',
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded),
              title: Text(items[index].visitReason.label),
              subtitle: Text(
                '${_formatDate(items[index].plannedDate)} · ${items[index].level.label}',
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
