import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import 'tire_care_calculator.dart';
import 'tire_care_models.dart';
import 'tire_care_service.dart';

class TireCarePage extends StatefulWidget {
  const TireCarePage({super.key});

  @override
  State<TireCarePage> createState() => _TireCarePageState();
}

class _TireCarePageState extends State<TireCarePage> {
  final _service = TireCareService();
  List<Vehicle> _vehicles = const [];
  List<TireCareSnapshot> _recent = const [];
  String? _selectedVehicleId;
  DateTime _checkedAt = DateTime.now();
  TireCheckContext _checkContext = TireCheckContext.routine;
  bool _vehicleCanMoveSafely = true;
  bool _vibrationOrPulling = false;
  bool _recentImpact = false;
  Map<TireCareArea, TireCareStatus> _checks = {
    for (final area in TireCareArea.values) area: TireCareStatus.notChecked,
  };
  TireCareAssessment? _assessment;
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
    } on TireCareException catch (error) {
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
      initialDate: _checkedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected != null) {
      _update(() => _checkedAt = selected);
    }
  }

  TireCareProfile _buildProfile() => TireCareProfile(
    vehicleId: _selectedVehicleId ?? '',
    checkedAt: _checkedAt,
    checkContext: _checkContext,
    checks: _checks,
    vehicleCanMoveSafely: _vehicleCanMoveSafely,
    vibrationOrPulling: _vibrationOrPulling,
    recentImpact: _recentImpact,
  );

  Future<void> _evaluate() async {
    final profile = _buildProfile();
    try {
      profile.validate();
      final assessment = TireCareCalculator.assess(profile);
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
    } on TireCareException catch (error) {
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
      appBar: AppBar(title: const Text('Suivre mes pneus')),
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
                      'Ajoutez un véhicule avant de suivre ses pneus.',
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
              key: const ValueKey('tire-care-scroll'),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                const _TireCareIntro(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Contrôle',
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
                      DropdownButtonFormField<TireCheckContext>(
                        initialValue: _checkContext,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Contexte',
                        ),
                        items: [
                          for (final item in TireCheckContext.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _update(() => _checkContext = value);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: const Text('Date du contrôle'),
                        subtitle: Text(_formatDate(_checkedAt)),
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
                          'En cas de doute sur un pneu ou une roue, ne circulez pas.',
                        ),
                        value: _vehicleCanMoveSafely,
                        onChanged: (value) =>
                            _update(() => _vehicleCanMoveSafely = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Vibration ou tirage ressenti'),
                        value: _vibrationOrPulling,
                        onChanged: (value) =>
                            _update(() => _vibrationOrPulling = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Choc récent sur une roue'),
                        subtitle: const Text(
                          'Bordure, nid-de-poule ou autre impact déclaré.',
                        ),
                        value: _recentImpact,
                        onChanged: (value) =>
                            _update(() => _recentImpact = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Points à vérifier',
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < TireCareArea.values.length;
                        index++
                      ) ...[
                        _AreaField(
                          key: ValueKey(
                            'tire-care-${TireCareArea.values[index].databaseValue}',
                          ),
                          area: TireCareArea.values[index],
                          value: _checks[TireCareArea.values[index]]!,
                          onChanged: (value) => _update(
                            () => _checks = {
                              ..._checks,
                              TireCareArea.values[index]: value,
                            },
                          ),
                        ),
                        if (index < TireCareArea.values.length - 1)
                          const Divider(height: 20),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('tire-care-evaluate'),
                  onPressed: _saving ? null : _evaluate,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.tire_repair_outlined),
                  label: const Text('Évaluer les points déclarés'),
                ),
                if (_assessment != null) ...[
                  const SizedBox(height: 16),
                  _TireCareResult(
                    assessment: _assessment!,
                    onCopy: _copySummary,
                    onTrip: () => context.push<void>('/trip-readiness'),
                    onInspection: () =>
                        context.push<void>('/vehicle-inspection'),
                    onWorkshop: () => context.push<void>('/workshop-visit'),
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

class _TireCareIntro extends StatelessWidget {
  const _TireCareIntro();

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
          Icon(Icons.tire_repair_outlined, color: Colors.white, size: 34),
          SizedBox(height: 12),
          Text(
            'Repérer les signes visibles avant de rouler',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Comparez la pression aux indications du véhicule et signalez les anomalies visibles. AutoClair ne fixe aucune valeur constructeur.',
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

  final TireCareArea area;
  final TireCareStatus value;
  final ValueChanged<TireCareStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<TireCareStatus>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: area.label,
        helperText: area.isSafetyCritical
            ? 'Point de sécurité à traiter en cas de doute'
            : null,
      ),
      items: [
        for (final status in TireCareStatus.values)
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

class _TireCareResult extends StatelessWidget {
  const _TireCareResult({
    required this.assessment,
    required this.onCopy,
    required this.onTrip,
    required this.onInspection,
    required this.onWorkshop,
  });

  final TireCareAssessment assessment;
  final VoidCallback onCopy;
  final VoidCallback onTrip;
  final VoidCallback onInspection;
  final VoidCallback onWorkshop;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('tire-care-result'),
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
            const Text(
              'Aucune anomalie n’a été déclarée sur les points vérifiés.',
            )
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
            'Ce suivi ne fixe aucune pression constructeur et ne confirme ni la conformité ni la sécurité réelle d’un pneu.',
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
                onPressed: onTrip,
                icon: const Icon(Icons.route_outlined),
                label: const Text('Préparer un départ'),
              ),
              OutlinedButton.icon(
                onPressed: onInspection,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Inspecter le véhicule'),
              ),
              OutlinedButton.icon(
                onPressed: onWorkshop,
                icon: const Icon(Icons.car_repair_outlined),
                label: const Text('Préparer le garage'),
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

  final List<TireCareSnapshot> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Contrôles récents',
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded),
              title: Text(items[index].checkContext.label),
              subtitle: Text(
                '${_formatDate(items[index].checkedAt)} · ${items[index].level.label}',
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
