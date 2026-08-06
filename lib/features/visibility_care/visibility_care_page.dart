import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import 'visibility_care_calculator.dart';
import 'visibility_care_models.dart';
import 'visibility_care_service.dart';

class VisibilityCarePage extends StatefulWidget {
  const VisibilityCarePage({super.key});

  @override
  State<VisibilityCarePage> createState() => _VisibilityCarePageState();
}

class _VisibilityCarePageState extends State<VisibilityCarePage> {
  final _service = VisibilityCareService();
  List<Vehicle> _vehicles = const [];
  List<VisibilityCareSnapshot> _recent = const [];
  String? _selectedVehicleId;
  DateTime _checkedAt = DateTime.now();
  VisibilityCheckContext _checkContext = VisibilityCheckContext.routine;
  bool _vehicleCanMoveSafely = true;
  bool _majorVisibilityObstruction = false;
  bool _essentialLightFailure = false;
  bool _badWeatherExpected = false;
  Map<VisibilityCareArea, VisibilityCareStatus> _checks = {
    for (final area in VisibilityCareArea.values)
      area: VisibilityCareStatus.notChecked,
  };
  VisibilityCareAssessment? _assessment;
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
    } on VisibilityCareException catch (error) {
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

  VisibilityCareProfile _buildProfile() => VisibilityCareProfile(
    vehicleId: _selectedVehicleId ?? '',
    checkedAt: _checkedAt,
    checkContext: _checkContext,
    checks: _checks,
    vehicleCanMoveSafely: _vehicleCanMoveSafely,
    majorVisibilityObstruction: _majorVisibilityObstruction,
    essentialLightFailure: _essentialLightFailure,
    badWeatherExpected: _badWeatherExpected,
  );

  Future<void> _evaluate() async {
    final profile = _buildProfile();
    try {
      profile.validate();
      final assessment = VisibilityCareCalculator.assess(profile);
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
    } on VisibilityCareException catch (error) {
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
      appBar: AppBar(title: const Text('Éclairage et visibilité')),
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
                      'Ajoutez un véhicule avant de vérifier son éclairage et sa visibilité.',
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
              key: const ValueKey('visibility-care-scroll'),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                const _VisibilityCareIntro(),
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
                      DropdownButtonFormField<VisibilityCheckContext>(
                        initialValue: _checkContext,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Contexte',
                        ),
                        items: [
                          for (final item in VisibilityCheckContext.values)
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
                          'Le véhicule peut être déplacé avec une visibilité suffisante',
                        ),
                        subtitle: const Text(
                          'Une visibilité fortement réduite ou un éclairage essentiel absent impose un avis adapté.',
                        ),
                        value: _vehicleCanMoveSafely,
                        onChanged: (value) =>
                            _update(() => _vehicleCanMoveSafely = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Champ de vision fortement gêné'),
                        value: _majorVisibilityObstruction,
                        onChanged: (value) =>
                            _update(() => _majorVisibilityObstruction = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Éclairage essentiel déclaré défaillant',
                        ),
                        value: _essentialLightFailure,
                        onChanged: (value) =>
                            _update(() => _essentialLightFailure = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Pluie, brouillard ou froid humide attendus',
                        ),
                        subtitle: const Text(
                          'Vérifiez en priorité l’essuyage, le lave-glace et le désembuage.',
                        ),
                        value: _badWeatherExpected,
                        onChanged: (value) =>
                            _update(() => _badWeatherExpected = value),
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
                        index < VisibilityCareArea.values.length;
                        index++
                      ) ...[
                        _AreaField(
                          key: ValueKey(
                            'visibility-care-${VisibilityCareArea.values[index].databaseValue}',
                          ),
                          area: VisibilityCareArea.values[index],
                          value: _checks[VisibilityCareArea.values[index]]!,
                          onChanged: (value) => _update(
                            () => _checks = {
                              ..._checks,
                              VisibilityCareArea.values[index]: value,
                            },
                          ),
                        ),
                        if (index < VisibilityCareArea.values.length - 1)
                          const Divider(height: 20),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('visibility-care-evaluate'),
                  onPressed: _saving ? null : _evaluate,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.visibility_outlined),
                  label: const Text('Évaluer les points déclarés'),
                ),
                if (_assessment != null) ...[
                  const SizedBox(height: 16),
                  _VisibilityCareResult(
                    assessment: _assessment!,
                    onTrip: () => context.push<void>('/trip-readiness'),
                    onWorkshop: () => context.push<void>('/workshop-visit'),
                    onControl: () =>
                        context.push<void>('/technical-control-readiness'),
                    onCopy: _copySummary,
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

class _VisibilityCareIntro extends StatelessWidget {
  const _VisibilityCareIntro();

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
          Icon(Icons.visibility_outlined, color: Colors.white, size: 34),
          SizedBox(height: 12),
          Text(
            'Voir et être vu avant de prendre la route',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Déclarez uniquement ce que vous observez. AutoClair ne diagnostique aucun circuit électrique et ne garantit pas la conformité du véhicule.',
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

  final VisibilityCareArea area;
  final VisibilityCareStatus value;
  final ValueChanged<VisibilityCareStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<VisibilityCareStatus>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: area.label,
        helperText: area.isSafetyCritical
            ? 'Ne démontez aucun feu et ne manipulez aucun circuit électrique'
            : null,
      ),
      items: [
        for (final status in VisibilityCareStatus.values)
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

class _VisibilityCareResult extends StatelessWidget {
  const _VisibilityCareResult({
    required this.assessment,
    required this.onCopy,
    required this.onTrip,
    required this.onWorkshop,
    required this.onControl,
  });

  final VisibilityCareAssessment assessment;
  final VoidCallback onCopy;
  final VoidCallback onTrip;
  final VoidCallback onWorkshop;
  final VoidCallback onControl;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('visibility-care-result'),
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
            const Text('Aucun écart n’a été déclaré sur les points vérifiés.')
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
            'Ce suivi ne diagnostique aucun circuit, ne garantit pas la conformité du véhicule et ne remplace pas un professionnel.',
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
                onPressed: onWorkshop,
                icon: const Icon(Icons.car_repair_outlined),
                label: const Text('Préparer le garage'),
              ),
              OutlinedButton.icon(
                onPressed: onControl,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Préparer le contrôle technique'),
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

  final List<VisibilityCareSnapshot> items;

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
