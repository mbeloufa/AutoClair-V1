import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import 'vehicle_inspection_calculator.dart';
import 'vehicle_inspection_models.dart';
import 'vehicle_inspection_service.dart';

class VehicleInspectionPage extends StatefulWidget {
  const VehicleInspectionPage({super.key});

  @override
  State<VehicleInspectionPage> createState() => _VehicleInspectionPageState();
}

class _VehicleInspectionPageState extends State<VehicleInspectionPage> {
  final _service = VehicleInspectionService();

  List<Vehicle> _vehicles = const [];
  List<VehicleInspectionSnapshot> _recent = const [];
  String? _selectedVehicleId;
  VehicleInspectionPurpose _purpose = VehicleInspectionPurpose.routine;
  Map<VehicleInspectionArea, VehicleInspectionStatus> _checks = {
    for (final area in VehicleInspectionArea.values)
      area: VehicleInspectionStatus.notChecked,
  };
  bool _roadTestCompleted = false;
  bool _photosAvailable = false;
  bool _professionalCheckPlanned = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  VehicleInspectionAssessment? _assessment;

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
      var recent = <VehicleInspectionSnapshot>[];
      if (selected != null) {
        recent = await _service.loadRecentInspections(selected);
      }
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _selectedVehicleId = selected;
        _recent = recent;
        _loading = false;
      });
    } on VehicleInspectionException catch (error) {
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

  VehicleInspectionProfile _profile() {
    return VehicleInspectionProfile(
      vehicleId: _selectedVehicleId ?? '',
      purpose: _purpose,
      checks: Map.unmodifiable(_checks),
      roadTestCompleted: _roadTestCompleted,
      photosAvailable: _photosAvailable,
      professionalCheckPlanned: _professionalCheckPlanned,
    );
  }

  void _resetAssessment(VoidCallback update) {
    setState(() {
      update();
      _assessment = null;
      _error = null;
    });
  }

  Future<void> _selectVehicle(String vehicleId) async {
    setState(() {
      _selectedVehicleId = vehicleId;
      _assessment = null;
      _error = null;
      _recent = const [];
    });
    try {
      final recent = await _service.loadRecentInspections(vehicleId);
      if (!mounted || _selectedVehicleId != vehicleId) return;
      setState(() => _recent = recent);
    } on VehicleInspectionException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _evaluate() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = _profile();
      final assessment = VehicleInspectionCalculator.assess(profile);
      await _service.saveInspection(profile: profile, assessment: assessment);
      final recent = await _service.loadRecentInspections(profile.vehicleId);
      if (!mounted) return;
      setState(() {
        _assessment = assessment;
        _recent = recent;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Inspection enregistrée.')));
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on VehicleInspectionException catch (error) {
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
          purpose: _purpose,
        ),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Résumé d’inspection copié.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inspection du véhicule')),
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
                      'Ajoutez d’abord un véhicule pour réaliser un état des lieux.',
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
              key: const ValueKey('vehicle-inspection-scroll'),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                const _InspectionIntro(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Contexte de l’inspection',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedVehicleId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Véhicule inspecté',
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
                      DropdownButtonFormField<VehicleInspectionPurpose>(
                        initialValue: _purpose,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Objectif',
                        ),
                        items: [
                          for (final purpose in VehicleInspectionPurpose.values)
                            DropdownMenuItem(
                              value: purpose,
                              child: Text(purpose.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _resetAssessment(() => _purpose = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'État apparent',
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < VehicleInspectionArea.values.length;
                        index++
                      ) ...[
                        _AreaField(
                          key: ValueKey(
                            'inspection-${_selectedVehicleId ?? 'none'}-${VehicleInspectionArea.values[index].databaseValue}',
                          ),
                          area: VehicleInspectionArea.values[index],
                          value:
                              _checks[VehicleInspectionArea.values[index]] ??
                              VehicleInspectionStatus.notChecked,
                          onChanged: (value) => _resetAssessment(
                            () => _checks = {
                              ..._checks,
                              VehicleInspectionArea.values[index]: value,
                            },
                          ),
                        ),
                        if (index < VehicleInspectionArea.values.length - 1)
                          const Divider(height: 22),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Éléments complémentaires',
                  child: Column(
                    children: [
                      _BooleanTile(
                        title: 'Essai routier réalisé',
                        subtitle:
                            'Uniquement dans un cadre autorisé et avec les précautions adaptées.',
                        value: _roadTestCompleted,
                        onChanged: (value) =>
                            _resetAssessment(() => _roadTestCompleted = value),
                      ),
                      _BooleanTile(
                        title: 'Photos personnelles disponibles',
                        subtitle:
                            'AutoClair mémorise seulement cette réponse, pas les photos dans ce lot.',
                        value: _photosAvailable,
                        onChanged: (value) =>
                            _resetAssessment(() => _photosAvailable = value),
                      ),
                      _BooleanTile(
                        title: 'Contrôle professionnel prévu',
                        subtitle:
                            'Un rendez-vous est prévu pour confirmer les points importants.',
                        value: _professionalCheckPlanned,
                        onChanged: (value) => _resetAssessment(
                          () => _professionalCheckPlanned = value,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('vehicle-inspection-submit'),
                  onPressed: _saving ? null : _evaluate,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fact_check_outlined),
                  label: Text(
                    _saving ? 'Enregistrement…' : 'Évaluer l’état apparent',
                  ),
                ),
                if (_assessment != null) ...[
                  const SizedBox(height: 18),
                  _InspectionResult(
                    assessment: _assessment!,
                    purpose: _purpose,
                    onCopy: _copySummary,
                    onProfessionalCheck: () =>
                        context.push<void>('/risk-forecast'),
                    onRelatedTool: () {
                      final route = switch (_purpose) {
                        VehicleInspectionPurpose.purchase => '/used-purchase',
                        VehicleInspectionPurpose.sale ||
                        VehicleInspectionPurpose.returnLease =>
                          '/sale-preparation',
                        VehicleInspectionPurpose.routine =>
                          '/maintenance-planner',
                      };
                      context.push<void>(route);
                    },
                  ),
                ],
                if (_recent.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _RecentInspections(items: _recent),
                ],
              ],
            ),
    );
  }
}

class _InspectionIntro extends StatelessWidget {
  const _InspectionIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.checklist_rounded, color: Colors.white, size: 34),
          SizedBox(height: 12),
          Text(
            'Un état des lieux structuré, sans expertise automatique',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Déclarez uniquement ce que vous avez réellement vérifié. Un point non contrôlé reste explicitement indiqué.',
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
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

  final VehicleInspectionArea area;
  final VehicleInspectionStatus value;
  final ValueChanged<VehicleInspectionStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(area.label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<VehicleInspectionStatus>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'État observé'),
          items: [
            for (final status in VehicleInspectionStatus.values)
              DropdownMenuItem(value: status, child: Text(status.label)),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ],
    );
  }
}

class _BooleanTile extends StatelessWidget {
  const _BooleanTile({
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

class _InspectionResult extends StatelessWidget {
  const _InspectionResult({
    required this.assessment,
    required this.purpose,
    required this.onCopy,
    required this.onProfessionalCheck,
    required this.onRelatedTool,
  });

  final VehicleInspectionAssessment assessment;
  final VehicleInspectionPurpose purpose;
  final VoidCallback onCopy;
  final VoidCallback onProfessionalCheck;
  final VoidCallback onRelatedTool;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('vehicle-inspection-result'),
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
          if (assessment.immediateAction) ...[
            const SizedBox(height: 10),
            const Text(
              'Un point de sécurité a été déclaré prioritaire. Faites contrôler le véhicule avant de poursuivre son utilisation ou la transaction.',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (assessment.findings.isEmpty)
            const Text('Aucun défaut déclaré parmi les points vérifiés.')
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
            'Cette évaluation ne remplace ni un contrôle technique, ni une expertise, ni un diagnostic professionnel.',
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
                onPressed: onRelatedTool,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(
                  purpose == VehicleInspectionPurpose.purchase
                      ? 'Sécuriser l’achat'
                      : purpose == VehicleInspectionPurpose.routine
                      ? 'Planifier l’entretien'
                      : 'Préparer la vente',
                ),
              ),
              OutlinedButton.icon(
                onPressed: onProfessionalCheck,
                icon: const Icon(Icons.query_stats_outlined),
                label: const Text('Anticiper les risques'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentInspections extends StatelessWidget {
  const _RecentInspections({required this.items});

  final List<VehicleInspectionSnapshot> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Historique récent',
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded),
              title: Text(items[index].purpose.label),
              subtitle: Text(
                '${items[index].level.label} · ${items[index].completenessPercent} % vérifié',
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
