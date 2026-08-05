import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/finance/money_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../vehicle_care/vehicle_care_models.dart';
import '../vehicle_care/vehicle_event_reminder.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'maintenance_planner_calculator.dart';
import 'maintenance_planner_models.dart';
import 'maintenance_planner_service.dart';

class MaintenancePlannerPage extends StatefulWidget {
  const MaintenancePlannerPage({super.key});

  @override
  State<MaintenancePlannerPage> createState() => _MaintenancePlannerPageState();
}

class _MaintenancePlannerPageState extends State<MaintenancePlannerPage> {
  final _vehicleService = VehicleService();
  final _plannerService = MaintenancePlannerService();
  final _annualMileageController = TextEditingController(text: '12000');
  final _bufferController = TextEditingController(text: '10');

  List<Vehicle> _vehicles = const [];
  List<VehicleMaintenanceSchedule> _schedules = const [];
  String? _vehicleId;
  int _reminderDaysBefore = 30;
  MaintenancePlanSummary? _summary;
  bool _loading = true;
  bool _saving = false;
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
    _loadVehicles();
  }

  @override
  void dispose() {
    _annualMileageController.dispose();
    _bufferController.dispose();
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
      });
      if (selected != null) {
        await _loadVehicleData(selected.id);
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } on VehicleServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadVehicleData(String vehicleId) async {
    setState(() {
      _loading = true;
      _error = null;
      _summary = null;
    });
    try {
      final results = await Future.wait<Object?>([
        _plannerService.loadProfile(vehicleId),
        _plannerService.loadSchedules(vehicleId),
      ]);
      if (!mounted || vehicleId != _vehicleId) return;
      final profile =
          results[0] as MaintenancePlannerProfile? ??
          MaintenancePlannerProfile.defaults();
      final schedules = results[1] as List<VehicleMaintenanceSchedule>;
      _applyProfile(profile);
      setState(() {
        _schedules = schedules;
        _loading = false;
      });
      _calculate(showError: false);
    } on MaintenancePlannerException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  void _applyProfile(MaintenancePlannerProfile profile) {
    _annualMileageController.text = profile.annualMileageKm.toString();
    _bufferController.text = profile.budgetBufferPercent.toStringAsFixed(0);
    _reminderDaysBefore = profile.reminderDaysBefore;
  }

  Future<void> _changeVehicle(String? vehicleId) async {
    if (vehicleId == null || vehicleId == _vehicleId) return;
    setState(() {
      _vehicleId = vehicleId;
      _schedules = const [];
      _summary = null;
    });
    await _loadVehicleData(vehicleId);
  }

  MaintenancePlannerProfile? _readProfile({bool showError = true}) {
    final annualMileage = int.tryParse(
      _annualMileageController.text.trim().replaceAll(' ', ''),
    );
    final buffer = double.tryParse(
      _bufferController.text.trim().replaceAll(',', '.'),
    );
    if (annualMileage == null || buffer == null) {
      if (showError) _show('Vérifiez le kilométrage annuel et la marge.');
      return null;
    }
    final profile = MaintenancePlannerProfile(
      annualMileageKm: annualMileage,
      budgetBufferPercent: buffer,
      reminderDaysBefore: _reminderDaysBefore,
    );
    try {
      profile.validate();
      return profile;
    } on FormatException catch (error) {
      if (showError) _show(error.message);
      return null;
    }
  }

  Future<void> _calculate({bool showError = true}) async {
    final vehicle = _selectedVehicle;
    final profile = _readProfile(showError: showError);
    if (vehicle == null || profile == null) return;

    try {
      await _plannerService.saveProfile(
        vehicleId: vehicle.id,
        profile: profile,
      );
      final summary = MaintenancePlannerCalculator.build(
        vehicle: vehicle,
        schedules: _schedules,
        profile: profile,
      );
      if (!mounted) return;
      setState(() => _summary = summary);
    } on MaintenancePlannerException catch (error) {
      if (mounted) _show(error.message);
    } on FormatException catch (error) {
      if (mounted) _show(error.message);
    }
  }

  Future<void> _createPlan() async {
    final vehicle = _selectedVehicle;
    if (vehicle == null || _saving) return;
    setState(() => _saving = true);
    try {
      final created = await _plannerService.createIndicativePlan(vehicle.id);
      final schedules = await _plannerService.loadSchedules(vehicle.id);
      if (!mounted) return;
      setState(() {
        _schedules = schedules;
        _saving = false;
      });
      await _calculate(showError: false);
      if (!mounted) return;
      _show(
        created > 0
            ? '$created échéance(s) indicative(s) ajoutée(s).'
            : 'Le plan indicatif est déjà complet.',
      );
    } on MaintenancePlannerException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _show(error.message);
    }
  }

  Future<void> _planItem(MaintenanceForecastItem item) async {
    final vehicle = _selectedVehicle;
    final profile = _readProfile();
    if (vehicle == null || profile == null || _saving) return;
    setState(() => _saving = true);
    try {
      await _plannerService.planInVehicleLog(
        vehicleId: vehicle.id,
        item: item,
        profile: profile,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      _show('Entretien planifié dans le carnet avec un rappel.');
    } on MaintenancePlannerException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _show(error.message);
    }
  }

  void _openVehicleCare() {
    final vehicle = _selectedVehicle;
    if (vehicle == null) return;
    context.push('/vehicles/${vehicle.id}/care?section=maintenance');
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan d’entretien intelligent')),
      body: RefreshIndicator(
        onRefresh: () async {
          final vehicleId = _vehicleId;
          if (vehicleId != null) await _loadVehicleData(vehicleId);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const _PlannerIntro(),
            const SizedBox(height: 16),
            if (_vehicles.isNotEmpty)
              DropdownButtonFormField<String>(
                key: const ValueKey('maintenance-planner-vehicle-selector'),
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
                onChanged: _saving ? null : _changeVehicle,
              ),
            if (_loading) ...[
              const SizedBox(height: 40),
              const Center(child: CircularProgressIndicator()),
            ] else if (_vehicles.isEmpty) ...[
              const SizedBox(height: 20),
              const _EmptyPanel(
                icon: Icons.directions_car_outlined,
                title: 'Aucun véhicule',
                message: 'Ajoutez un véhicule pour préparer son entretien.',
              ),
            ] else if (_error != null) ...[
              const SizedBox(height: 20),
              _ErrorPanel(message: _error!, onRetry: _loadVehicles),
            ] else ...[
              const SizedBox(height: 16),
              _ProfileCard(
                annualMileageController: _annualMileageController,
                bufferController: _bufferController,
                reminderDaysBefore: _reminderDaysBefore,
                enabled: !_saving,
                onReminderChanged: (value) {
                  if (value == null) return;
                  setState(() => _reminderDaysBefore = value);
                },
                onCalculate: () => _calculate(),
              ),
              const SizedBox(height: 18),
              if (_schedules.isEmpty)
                _EmptyPlan(
                  saving: _saving,
                  onCreate: _createPlan,
                  onOpenCare: _openVehicleCare,
                )
              else if (_summary != null) ...[
                _SummaryCard(summary: _summary!),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Échéances estimées',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: _openVehicleCare,
                      child: const Text('Voir le carnet'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final item in _summary!.items) ...[
                  _ForecastCard(
                    item: item,
                    disabled: _saving,
                    onPlan: () => _planItem(item),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 18),
              const _DisclaimerCard(),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlannerIntro extends StatelessWidget {
  const _PlannerIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.softPrimary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_repeat_outlined, color: AppColors.primary, size: 30),
          SizedBox(height: 12),
          Text(
            'Anticipez les entretiens et leur budget.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'AutoClair rapproche les échéances du carnet, votre kilométrage '
            'et votre usage annuel pour établir une projection indicative.',
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.annualMileageController,
    required this.bufferController,
    required this.reminderDaysBefore,
    required this.enabled,
    required this.onReminderChanged,
    required this.onCalculate,
  });

  final TextEditingController annualMileageController;
  final TextEditingController bufferController;
  final int reminderDaysBefore;
  final bool enabled;
  final ValueChanged<int?> onReminderChanged;
  final VoidCallback onCalculate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Votre usage', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          TextField(
            controller: annualMileageController,
            enabled: enabled,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Kilométrage annuel estimé',
              suffixText: 'km/an',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bufferController,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Marge de sécurité budgétaire',
              suffixText: '%',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: reminderDaysBefore,
            decoration: const InputDecoration(
              labelText: 'Rappel avant échéance',
            ),
            items: supportedVehicleEventReminderDays
                .map(
                  (days) => DropdownMenuItem(
                    value: days,
                    child: Text('$days jour(s) avant'),
                  ),
                )
                .toList(growable: false),
            onChanged: enabled ? onReminderChanged : null,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: enabled ? onCalculate : null,
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Recalculer le plan'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final MaintenancePlanSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget prévisionnel sur 12 mois',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            '${MoneyFormatter.compactEuros(summary.twelveMonthCost.minimum)} '
            'à ${MoneyFormatter.compactEuros(summary.twelveMonthCost.maximum)}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Réserve conseillée : '
            '${MoneyFormatter.compactEuros(summary.monthlyReserve.minimum)} '
            'à ${MoneyFormatter.compactEuros(summary.monthlyReserve.maximum)} par mois.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CountChip(
                label: '${summary.overdueCount} en retard',
                color: AppColors.error,
                background: AppColors.errorSoft,
              ),
              _CountChip(
                label: '${summary.dueSoonCount} bientôt',
                color: AppColors.warning,
                background: AppColors.warningSoft,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({
    required this.item,
    required this.disabled,
    required this.onPlan,
  });

  final MaintenanceForecastItem item;
  final bool disabled;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.urgency) {
      MaintenanceForecastUrgency.overdue => AppColors.error,
      MaintenanceForecastUrgency.dueSoon => AppColors.warning,
      MaintenanceForecastUrgency.nextTwelveMonths => AppColors.info,
      MaintenanceForecastUrgency.later => AppColors.success,
      MaintenanceForecastUrgency.unknown => AppColors.textMuted,
    };
    final due = <String>[
      if (item.projectedDate != null) _date(item.projectedDate!),
      if (item.projectedMileage != null) '${item.projectedMileage} km',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.schedule.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.urgency.label,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (due.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(due.join(' • ')),
          ],
          const SizedBox(height: 6),
          Text(
            '${MoneyFormatter.compactEuros(item.costRange.minimum)} à '
            '${MoneyFormatter.compactEuros(item.costRange.maximum)} estimés',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(item.reason),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: disabled ? null : onPlan,
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Planifier dans le carnet'),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan({
    required this.saving,
    required this.onCreate,
    required this.onOpenCare,
  });

  final bool saving;
  final VoidCallback onCreate;
  final VoidCallback onOpenCare;

  @override
  Widget build(BuildContext context) {
    return _EmptyPanel(
      icon: Icons.event_repeat_outlined,
      title: 'Aucune échéance active',
      message:
          'Créez le plan indicatif AutoClair, puis adaptez-le au carnet constructeur.',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: saving ? null : onCreate,
            icon: const Icon(Icons.add_task_outlined),
            label: const Text('Créer le plan indicatif'),
          ),
          TextButton(
            onPressed: onOpenCare,
            child: const Text('Ouvrir le carnet'),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final actionWidget = action;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, color: AppColors.primary, size: 32),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message),
          if (actionWidget != null) ...[
            const SizedBox(height: 16),
            actionWidget,
          ],
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ces échéances et fourchettes de prix sont indicatives. Le carnet '
              'constructeur, l’état réel du véhicule et l’avis d’un professionnel '
              'restent prioritaires. AutoClair ne réalise pas de diagnostic mécanique.',
            ),
          ),
        ],
      ),
    );
  }
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year}';
}
