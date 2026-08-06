import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import 'vehicle_storage_calculator.dart';
import 'vehicle_storage_models.dart';
import 'vehicle_storage_service.dart';

class VehicleStoragePage extends StatefulWidget {
  const VehicleStoragePage({super.key});

  @override
  State<VehicleStoragePage> createState() => _VehicleStoragePageState();
}

class _VehicleStoragePageState extends State<VehicleStoragePage> {
  final _service = VehicleStorageService();
  List<Vehicle> _vehicles = const [];
  List<VehicleStorageSnapshot> _recent = const [];
  String? _selectedVehicleId;
  VehicleStorageScenario _scenario = VehicleStorageScenario.shortPause;
  DateTime _plannedDate = DateTime.now().add(const Duration(days: 1));
  int _plannedWeeks = 4;
  bool _electricOrHybrid = false;
  bool _outdoorStorage = false;
  bool _humidEnvironment = false;
  Map<VehicleStorageArea, VehicleStorageStatus> _checks = {
    for (final area in VehicleStorageArea.values)
      area: area == VehicleStorageArea.tractionBattery
          ? VehicleStorageStatus.notApplicable
          : VehicleStorageStatus.notChecked,
  };
  VehicleStorageAssessment? _assessment;
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
      setState(() {
        _vehicles = vehicles;
        Vehicle? selected;
        for (final vehicle in vehicles) {
          if (vehicle.isPrimary) {
            selected = vehicle;
            break;
          }
        }
        selected ??= vehicles.isEmpty ? null : vehicles.first;
        _selectedVehicleId = selected?.id;
        _loading = false;
      });
      if (_selectedVehicleId != null) {
        _applyVehicleEnergy(_selectedVehicle!);
        await _loadRecent();
      }
    } on VehicleStorageException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _loading = false;
      });
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
    } on VehicleStorageException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.message);
    }
  }

  void _applyVehicleEnergy(Vehicle vehicle) {
    final fuel = (vehicle.fuelType ?? '').toLowerCase();
    final electrified =
        fuel.contains('élect') ||
        fuel.contains('elect') ||
        fuel.contains('hybr');
    setState(() {
      _electricOrHybrid = electrified;
      _checks = {
        ..._checks,
        VehicleStorageArea.tractionBattery: electrified
            ? VehicleStorageStatus.notChecked
            : VehicleStorageStatus.notApplicable,
      };
      _assessment = null;
    });
  }

  Future<void> _selectVehicle(String id) async {
    setState(() {
      _selectedVehicleId = id;
      _recent = const [];
      _assessment = null;
      _error = null;
    });
    final vehicle = _selectedVehicle;
    if (vehicle != null) {
      _applyVehicleEnergy(vehicle);
    }
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

  VehicleStorageProfile _buildProfile() => VehicleStorageProfile(
    vehicleId: _selectedVehicleId ?? '',
    plannedStartDate: _plannedDate,
    plannedWeeks: _plannedWeeks,
    scenario: _scenario,
    checks: _checks,
    electricOrHybrid: _electricOrHybrid,
    outdoorStorage: _outdoorStorage,
    humidEnvironment: _humidEnvironment,
  );

  Future<void> _evaluate() async {
    final profile = _buildProfile();
    try {
      profile.validate();
      final assessment = VehicleStorageCalculator.assess(profile);
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
      setState(() => _error = error.message);
    } on VehicleStorageException catch (error) {
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
      appBar: AppBar(title: const Text('Immobilisation du véhicule')),
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
                      'Ajoutez un véhicule avant de préparer une immobilisation.',
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
              key: const ValueKey('vehicle-storage-scroll'),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                const _StorageIntro(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Contexte de l’immobilisation',
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
                      DropdownButtonFormField<VehicleStorageScenario>(
                        initialValue: _scenario,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Situation',
                        ),
                        items: [
                          for (final scenario in VehicleStorageScenario.values)
                            DropdownMenuItem(
                              value: scenario,
                              child: Text(scenario.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _update(() => _scenario = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _plannedWeeks,
                        decoration: const InputDecoration(
                          labelText: 'Durée indicative',
                        ),
                        items: const [
                          DropdownMenuItem(value: 2, child: Text('2 semaines')),
                          DropdownMenuItem(value: 4, child: Text('4 semaines')),
                          DropdownMenuItem(
                            value: 8,
                            child: Text('2 mois environ'),
                          ),
                          DropdownMenuItem(
                            value: 12,
                            child: Text('3 mois environ'),
                          ),
                          DropdownMenuItem(
                            value: 24,
                            child: Text('6 mois environ'),
                          ),
                          DropdownMenuItem(
                            value: 52,
                            child: Text('1 an environ'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _update(() => _plannedWeeks = value);
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
                  title: 'Conditions',
                  child: Column(
                    children: [
                      _OptionSwitch(
                        title: 'Motorisation électrique ou hybride',
                        subtitle:
                            'Ajoute le contrôle de la batterie de traction.',
                        value: _electricOrHybrid,
                        onChanged: (value) => _update(() {
                          _electricOrHybrid = value;
                          _checks = {
                            ..._checks,
                            VehicleStorageArea.tractionBattery: value
                                ? VehicleStorageStatus.notChecked
                                : VehicleStorageStatus.notApplicable,
                          };
                        }),
                      ),
                      _OptionSwitch(
                        title: 'Stationnement extérieur',
                        subtitle:
                            'La protection et la ventilation deviennent prioritaires.',
                        value: _outdoorStorage,
                        onChanged: (value) =>
                            _update(() => _outdoorStorage = value),
                      ),
                      _OptionSwitch(
                        title: 'Environnement potentiellement humide',
                        subtitle:
                            'Demande une vigilance supplémentaire sur la protection.',
                        value: _humidEnvironment,
                        onChanged: (value) =>
                            _update(() => _humidEnvironment = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Checklist structurée',
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < VehicleStorageArea.values.length;
                        index++
                      ) ...[
                        _AreaField(
                          key: ValueKey(
                            'storage-${VehicleStorageArea.values[index].databaseValue}',
                          ),
                          area: VehicleStorageArea.values[index],
                          value: _checks[VehicleStorageArea.values[index]]!,
                          electricOrHybrid: _electricOrHybrid,
                          onChanged: (value) => _update(
                            () => _checks = {
                              ..._checks,
                              VehicleStorageArea.values[index]: value,
                            },
                          ),
                        ),
                        if (index < VehicleStorageArea.values.length - 1)
                          const Divider(height: 20),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('vehicle-storage-evaluate'),
                  onPressed: _saving ? null : _evaluate,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.pause_circle_outline),
                  label: const Text('Évaluer la préparation'),
                ),
                if (_assessment != null) ...[
                  const SizedBox(height: 16),
                  _StorageResult(
                    assessment: _assessment!,
                    onCopy: _copySummary,
                    onInspection: () =>
                        context.push<void>('/vehicle-inspection'),
                    onMaintenance: () =>
                        context.push<void>('/maintenance-planner'),
                    onInsurance: () => context.push<void>('/insurance-review'),
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

class _StorageIntro extends StatelessWidget {
  const _StorageIntro();

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
          Icon(Icons.pause_circle_outline, color: Colors.white, size: 34),
          SizedBox(height: 12),
          Text(
            'Préparer une pause et une reprise sans stocker le lieu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Cette checklist organise les points utiles. Elle ne remplace pas le manuel constructeur ou un contrôle professionnel.',
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
    required this.electricOrHybrid,
    required this.onChanged,
  });

  final VehicleStorageArea area;
  final VehicleStorageStatus value;
  final bool electricOrHybrid;
  final ValueChanged<VehicleStorageStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final disabled =
        area == VehicleStorageArea.tractionBattery && !electricOrHybrid;
    return DropdownButtonFormField<VehicleStorageStatus>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: area.label,
        helperText: disabled
            ? 'Non concerné pour cette motorisation'
            : (area.isSafetyCritical ? 'Point de sécurité prioritaire' : null),
      ),
      items: [
        for (final status in VehicleStorageStatus.values)
          if (!disabled || status == VehicleStorageStatus.notApplicable)
            if (disabled || status != VehicleStorageStatus.notApplicable)
              DropdownMenuItem(value: status, child: Text(status.label)),
      ],
      onChanged: disabled
          ? null
          : (status) {
              if (status != null) {
                onChanged(status);
              }
            },
    );
  }
}

class _StorageResult extends StatelessWidget {
  const _StorageResult({
    required this.assessment,
    required this.onCopy,
    required this.onInspection,
    required this.onMaintenance,
    required this.onInsurance,
  });

  final VehicleStorageAssessment assessment;
  final VoidCallback onCopy;
  final VoidCallback onInspection;
  final VoidCallback onMaintenance;
  final VoidCallback onInsurance;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('vehicle-storage-result'),
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
              '${assessment.blockingCount} point(s) déclaré(s) prioritaire(s).',
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
            'Cette checklist ne constitue ni un diagnostic, ni une garantie de conservation ou de remise en route.',
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
                onPressed: onInsurance,
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Réviser l’assurance'),
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

  final List<VehicleStorageSnapshot> items;

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
              title: Text(items[index].scenario.label),
              subtitle: Text(
                '${_formatDate(items[index].plannedStartDate)} · ${items[index].plannedWeeks} sem. · ${items[index].level.label}',
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
