import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import 'lease_return_calculator.dart';
import 'lease_return_models.dart';
import 'lease_return_service.dart';

class LeaseReturnPage extends StatefulWidget {
  const LeaseReturnPage({super.key});

  @override
  State<LeaseReturnPage> createState() => _LeaseReturnPageState();
}

class _LeaseReturnPageState extends State<LeaseReturnPage> {
  final _service = LeaseReturnService();
  List<Vehicle> _vehicles = const [];
  List<LeaseReturnSnapshot> _recent = const [];
  String? _selectedVehicleId;
  DateTime _preparedAt = DateTime.now();
  LeaseReturnContext _preparationContext = LeaseReturnContext.endOfContract;
  bool _vehicleCanMoveSafely = true;
  bool _contractInstructionsAvailable = true;
  bool _allKeysAndAccessoriesAvailable = true;
  bool _warningOrMechanicalConcern = false;
  Map<LeaseReturnArea, LeaseReturnStatus> _checks = {
    for (final area in LeaseReturnArea.values)
      area: LeaseReturnStatus.notChecked,
  };
  LeaseReturnAssessment? _assessment;
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
    } on LeaseReturnException catch (error) {
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
      initialDate: _preparedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected != null) {
      _update(() => _preparedAt = selected);
    }
  }

  LeaseReturnProfile _buildProfile() => LeaseReturnProfile(
    vehicleId: _selectedVehicleId ?? '',
    preparedAt: _preparedAt,
    preparationContext: _preparationContext,
    checks: _checks,
    vehicleCanMoveSafely: _vehicleCanMoveSafely,
    contractInstructionsAvailable: _contractInstructionsAvailable,
    allKeysAndAccessoriesAvailable: _allKeysAndAccessoriesAvailable,
    warningOrMechanicalConcern: _warningOrMechanicalConcern,
  );

  Future<void> _evaluate() async {
    final profile = _buildProfile();
    try {
      profile.validate();
      final assessment = LeaseReturnCalculator.assess(profile);
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
    } on LeaseReturnException catch (error) {
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
      appBar: AppBar(title: const Text('Restitution LOA / LLD')),
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
                      'Ajoutez un véhicule avant de préparer sa restitution LOA ou LLD.',
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
              key: const ValueKey('lease-return-scroll'),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                const _LeaseReturnIntro(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Préparation',
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
                      DropdownButtonFormField<LeaseReturnContext>(
                        initialValue: _preparationContext,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Contexte',
                        ),
                        items: [
                          for (final item in LeaseReturnContext.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _update(() => _preparationContext = value);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: const Text('Date de préparation'),
                        subtitle: Text(_formatDate(_preparedAt)),
                        trailing: const Icon(Icons.edit_calendar_outlined),
                        onTap: _pickDate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Éléments disponibles',
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Le véhicule peut être déplacé sans risque manifeste déclaré',
                        ),
                        subtitle: const Text(
                          'Un voyant critique ou une anomalie importante nécessite un avis adapté avant le déplacement.',
                        ),
                        value: _vehicleCanMoveSafely,
                        onChanged: (value) =>
                            _update(() => _vehicleCanMoveSafely = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Contrat et consignes de restitution disponibles',
                        ),
                        value: _contractInstructionsAvailable,
                        onChanged: (value) => _update(
                          () => _contractInstructionsAvailable = value,
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Toutes les clés et les accessoires prévus sont disponibles',
                        ),
                        value: _allKeysAndAccessoriesAvailable,
                        onChanged: (value) => _update(
                          () => _allKeysAndAccessoriesAvailable = value,
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Voyant ou anomalie mécanique à signaler',
                        ),
                        subtitle: const Text(
                          'AutoClair ne diagnostique pas l’origine du voyant ou de l’anomalie.',
                        ),
                        value: _warningOrMechanicalConcern,
                        onChanged: (value) =>
                            _update(() => _warningOrMechanicalConcern = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Points à préparer',
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < LeaseReturnArea.values.length;
                        index++
                      ) ...[
                        _AreaField(
                          key: ValueKey(
                            'lease-return-${LeaseReturnArea.values[index].databaseValue}',
                          ),
                          area: LeaseReturnArea.values[index],
                          value: _checks[LeaseReturnArea.values[index]]!,
                          onChanged: (value) => _update(
                            () => _checks = {
                              ..._checks,
                              LeaseReturnArea.values[index]: value,
                            },
                          ),
                        ),
                        if (index < LeaseReturnArea.values.length - 1)
                          const Divider(height: 20),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('lease-return-evaluate'),
                  onPressed: _saving ? null : _evaluate,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.assignment_outlined),
                  label: const Text('Évaluer la préparation déclarée'),
                ),
                if (_assessment != null) ...[
                  const SizedBox(height: 16),
                  _LeaseReturnResult(
                    assessment: _assessment!,
                    onInspection: () =>
                        context.push<void>('/vehicle-inspection'),
                    onWorkshop: () => context.push<void>('/workshop-visit'),
                    onSale: () => context.push<void>('/sale-preparation'),
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

class _LeaseReturnIntro extends StatelessWidget {
  const _LeaseReturnIntro();

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
          Icon(Icons.assignment_outlined, color: Colors.white, size: 34),
          SizedBox(height: 12),
          Text(
            'Préparer une restitution LOA ou LLD sans oublier les éléments essentiels',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Rassemblez les éléments utiles sans saisir de numéro de contrat, de montant ou de donnée personnelle. AutoClair ne calcule aucun frais de restitution.',
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

  final LeaseReturnArea area;
  final LeaseReturnStatus value;
  final ValueChanged<LeaseReturnStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<LeaseReturnStatus>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: area.label,
        helperText: area.isPriorityArea
            ? 'Vérifiez le contrat ou demandez une confirmation écrite'
            : null,
      ),
      items: [
        for (final status in LeaseReturnStatus.values)
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

class _LeaseReturnResult extends StatelessWidget {
  const _LeaseReturnResult({
    required this.assessment,
    required this.onCopy,
    required this.onInspection,
    required this.onWorkshop,
    required this.onSale,
  });

  final LeaseReturnAssessment assessment;
  final VoidCallback onCopy;
  final VoidCallback onInspection;
  final VoidCallback onWorkshop;
  final VoidCallback onSale;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('lease-return-result'),
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
            'Indice ${assessment.score}/100 · ${assessment.completenessPercent} % préparé',
          ),
          if (assessment.urgentCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${assessment.urgentCount} point(s) prioritaire(s) déclaré(s).',
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (assessment.findings.isEmpty)
            const Text(
              'Aucun point manquant n’a été déclaré sur les éléments préparés.',
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
            'Cette préparation ne calcule aucun frais, n’interprète pas le contrat et ne garantit pas l’acceptation du véhicule.',
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
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Inspecter le véhicule'),
              ),
              OutlinedButton.icon(
                onPressed: onWorkshop,
                icon: const Icon(Icons.car_repair_outlined),
                label: const Text('Préparer le garage'),
              ),
              OutlinedButton.icon(
                onPressed: onSale,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Préparer une vente'),
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

  final List<LeaseReturnSnapshot> items;

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
              title: Text(items[index].preparationContext.label),
              subtitle: Text(
                '${_formatDate(items[index].preparedAt)} · ${items[index].level.label}',
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
