import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'breakdown_assistant_calculator.dart';
import 'breakdown_assistant_models.dart';
import 'breakdown_assistant_service.dart';

class BreakdownAssistantPage extends StatefulWidget {
  const BreakdownAssistantPage({super.key});

  @override
  State<BreakdownAssistantPage> createState() => _BreakdownAssistantPageState();
}

class _BreakdownAssistantPageState extends State<BreakdownAssistantPage> {
  final VehicleService _vehicleService = VehicleService();
  final BreakdownAssistantService _service = BreakdownAssistantService();
  final TextEditingController _mileageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _providerController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _contractController = TextEditingController();

  List<Vehicle> _vehicles = const [];
  List<BreakdownCaseSummary> _recentCases = const [];
  String? _selectedVehicleId;
  BreakdownLocationType _locationType = BreakdownLocationType.safeParking;
  final Set<BreakdownSymptom> _symptoms = {};
  bool _safelyParked = true;
  bool _vehicleInTrafficLane = false;
  bool _injuredPerson = false;
  bool _vehicleCanMove = true;
  String _assistanceCoverage = 'UNKNOWN';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _mileageController.dispose();
    _notesController.dispose();
    _providerController.dispose();
    _phoneController.dispose();
    _contractController.dispose();
    super.dispose();
  }

  Vehicle? get _selectedVehicle {
    for (final vehicle in _vehicles) {
      if (vehicle.id == _selectedVehicleId) return vehicle;
    }
    return null;
  }

  BreakdownAssessmentInput get _input => BreakdownAssessmentInput(
    locationType: _locationType,
    symptoms: Set.unmodifiable(_symptoms),
    safelyParked: _safelyParked,
    vehicleInTrafficLane: _vehicleInTrafficLane,
    injuredPerson: _injuredPerson,
    vehicleCanMove: _vehicleCanMove,
  );

  BreakdownAssessment get _assessment =>
      BreakdownAssistantCalculator.assess(_input);

  Future<void> _loadInitial() async {
    try {
      final vehicles = await _vehicleService.fetchVehicles();
      if (!mounted) return;
      final preferred = vehicles
          .where((vehicle) => vehicle.isPrimary)
          .firstOrNull;
      setState(() {
        _vehicles = vehicles;
        _selectedVehicleId = preferred?.id ?? vehicles.firstOrNull?.id;
        _mileageController.text =
            (preferred ?? vehicles.firstOrNull)?.mileage?.toString() ?? '';
      });
      await _loadVehicleData();
    } on VehicleServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadVehicleData() async {
    final vehicleId = _selectedVehicleId;
    if (vehicleId == null) return;
    final profile = await _service.loadProfile(vehicleId);
    final cases = await _service.loadRecentCases(vehicleId);
    if (!mounted || vehicleId != _selectedVehicleId) return;
    setState(() {
      _providerController.text = profile?.assistanceProvider ?? '';
      _phoneController.text = profile?.assistancePhone ?? '';
      _contractController.text = profile?.contractReference ?? '';
      _assistanceCoverage = switch (profile?.assistanceZeroKm) {
        true => 'YES',
        false => 'NO',
        null => 'UNKNOWN',
      };
      _recentCases = cases;
    });
  }

  Future<void> _selectVehicle(String? vehicleId) async {
    if (vehicleId == null || vehicleId == _selectedVehicleId) return;
    final vehicle = _vehicles.firstWhere((item) => item.id == vehicleId);
    setState(() {
      _selectedVehicleId = vehicleId;
      _mileageController.text = vehicle.mileage?.toString() ?? '';
      _error = null;
      _recentCases = const [];
    });
    await _loadVehicleData();
  }

  BreakdownAssistantProfile _profile() {
    return BreakdownAssistantProfile(
      assistanceProvider: _providerController.text,
      assistancePhone: _phoneController.text,
      contractReference: _contractController.text,
      assistanceZeroKm: switch (_assistanceCoverage) {
        'YES' => true,
        'NO' => false,
        _ => null,
      },
    );
  }

  int? _mileage() => int.tryParse(_mileageController.text.trim());

  String _summary() {
    final vehicle = _selectedVehicle;
    return _assessment.buildShareSummary(
      vehicleName: vehicle?.displayName ?? 'Véhicule',
      input: _input,
      notes: _notesController.text,
      mileage: _mileage(),
    );
  }

  Future<void> _copySummary() async {
    await Clipboard.setData(ClipboardData(text: _summary()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Résumé copié.')));
  }

  Future<void> _launch(Uri uri, String errorMessage) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  Future<void> _call112() => _launch(
    Uri(scheme: 'tel', path: '112'),
    'L’appel vers le 112 n’a pas pu être lancé.',
  );

  Future<void> _sms114() => _launch(
    Uri(scheme: 'sms', path: '114', queryParameters: {'body': _summary()}),
    'Le SMS vers le 114 n’a pas pu être préparé.',
  );

  Future<void> _callAssistance() async {
    try {
      final profile = _profile();
      profile.validate();
      final phone = profile.callablePhone;
      if (phone == null) {
        throw const FormatException(
          'Renseignez le numéro de votre assistance.',
        );
      }
      await _launch(
        Uri(scheme: 'tel', path: phone),
        'L’appel vers votre assistance n’a pas pu être lancé.',
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _saveIncident() async {
    final vehicle = _selectedVehicle;
    if (vehicle == null) {
      setState(() => _error = 'Ajoutez ou sélectionnez un véhicule.');
      return;
    }
    if (_symptoms.isEmpty && !_injuredPerson && !_vehicleInTrafficLane) {
      setState(
        () => _error = 'Sélectionnez au moins un symptôme ou un danger.',
      );
      return;
    }
    final mileage = _mileage();
    if (_mileageController.text.trim().isNotEmpty && mileage == null) {
      setState(() => _error = 'Le kilométrage doit être un nombre entier.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = _profile();
      profile.validate();
      final occurredAt = DateTime.now();
      final assessment = _assessment;
      final summary = _summary();
      await _service.saveProfile(vehicleId: vehicle.id, profile: profile);
      final eventId = await _service.recordInVehicleLog(
        vehicleId: vehicle.id,
        assessment: assessment,
        summary: summary,
        occurredAt: occurredAt,
        mileage: mileage,
      );
      await _service.saveCase(
        vehicleId: vehicle.id,
        input: _input,
        assessment: assessment,
        summary: summary,
        occurredAt: occurredAt,
        timelineEventId: eventId,
      );
      final cases = await _service.loadRecentCases(vehicle.id);
      if (!mounted) return;
      setState(() => _recentCases = cases);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incident ajouté au carnet du véhicule.')),
      );
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on BreakdownAssistantException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assessment = _assessment;
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant panne')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              children: [
                const _SafetyIntro(),
                const SizedBox(height: 16),
                if (_vehicles.isEmpty)
                  _EmptyVehicleCard(onAdd: () => context.push('/vehicles/new'))
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedVehicleId,
                    decoration: const InputDecoration(labelText: 'Véhicule'),
                    items: _vehicles
                        .map(
                          (vehicle) => DropdownMenuItem(
                            value: vehicle.id,
                            child: Text(vehicle.displayName),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _saving ? null : _selectVehicle,
                  ),
                  const SizedBox(height: 16),
                  _SituationCard(
                    locationType: _locationType,
                    safelyParked: _safelyParked,
                    vehicleInTrafficLane: _vehicleInTrafficLane,
                    injuredPerson: _injuredPerson,
                    vehicleCanMove: _vehicleCanMove,
                    enabled: !_saving,
                    onLocationChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _locationType = value;
                        if (value == BreakdownLocationType.safeParking) {
                          _safelyParked = true;
                          _vehicleInTrafficLane = false;
                        }
                      });
                    },
                    onSafelyParkedChanged: (value) =>
                        setState(() => _safelyParked = value),
                    onTrafficLaneChanged: (value) =>
                        setState(() => _vehicleInTrafficLane = value),
                    onInjuredChanged: (value) =>
                        setState(() => _injuredPerson = value),
                    onCanMoveChanged: (value) =>
                        setState(() => _vehicleCanMove = value),
                  ),
                  const SizedBox(height: 16),
                  _SymptomsCard(
                    selected: _symptoms,
                    enabled: !_saving,
                    onChanged: (symptom, selected) {
                      setState(() {
                        if (selected) {
                          _symptoms.add(symptom);
                        } else {
                          _symptoms.remove(symptom);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _AssessmentCard(
                    assessment: assessment,
                    onCall112: _call112,
                    onSms114: _sms114,
                    onCallAssistance: _callAssistance,
                    onOpenGarages: () => context.push('/nearby'),
                  ),
                  const SizedBox(height: 16),
                  _AssistanceProfileCard(
                    providerController: _providerController,
                    phoneController: _phoneController,
                    contractController: _contractController,
                    coverage: _assistanceCoverage,
                    enabled: !_saving,
                    onCoverageChanged: (value) {
                      if (value != null) {
                        setState(() => _assistanceCoverage = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _mileageController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kilométrage actuel facultatif',
                      suffixText: 'km',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 800,
                    decoration: const InputDecoration(
                      labelText: 'Observations utiles',
                      hintText: 'Message affiché, circonstances, bruit, odeur…',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _copySummary,
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copier le résumé pour l’assistance'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveIncident,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Ajouter l’incident au carnet'),
                  ),
                  if (_recentCases.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Incidents récents',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    for (final item in _recentCases) ...[
                      _RecentCaseCard(item: item),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ],
            ),
    );
  }
}

class _SafetyIntro extends StatelessWidget {
  const _SafetyIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            color: AppColors.error,
            size: 32,
          ),
          SizedBox(height: 12),
          Text(
            'Commencez toujours par sécuriser les personnes.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'AutoClair aide à organiser les informations et les prochaines actions. '
            'Il ne remplace ni les secours, ni l’assistance, ni un diagnostic professionnel.',
          ),
        ],
      ),
    );
  }
}

class _SituationCard extends StatelessWidget {
  const _SituationCard({
    required this.locationType,
    required this.safelyParked,
    required this.vehicleInTrafficLane,
    required this.injuredPerson,
    required this.vehicleCanMove,
    required this.enabled,
    required this.onLocationChanged,
    required this.onSafelyParkedChanged,
    required this.onTrafficLaneChanged,
    required this.onInjuredChanged,
    required this.onCanMoveChanged,
  });

  final BreakdownLocationType locationType;
  final bool safelyParked;
  final bool vehicleInTrafficLane;
  final bool injuredPerson;
  final bool vehicleCanMove;
  final bool enabled;
  final ValueChanged<BreakdownLocationType?> onLocationChanged;
  final ValueChanged<bool> onSafelyParkedChanged;
  final ValueChanged<bool> onTrafficLaneChanged;
  final ValueChanged<bool> onInjuredChanged;
  final ValueChanged<bool> onCanMoveChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '1. Situation et sécurité',
      child: Column(
        children: [
          DropdownButtonFormField<BreakdownLocationType>(
            initialValue: locationType,
            decoration: const InputDecoration(labelText: 'Où êtes-vous ?'),
            items: BreakdownLocationType.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(growable: false),
            onChanged: enabled ? onLocationChanged : null,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Le véhicule est hors de la circulation'),
            value: safelyParked,
            onChanged: enabled ? onSafelyParkedChanged : null,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Le véhicule occupe encore une voie'),
            value: vehicleInTrafficLane,
            onChanged: enabled ? onTrafficLaneChanged : null,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Une personne est blessée ou en détresse'),
            value: injuredPerson,
            onChanged: enabled ? onInjuredChanged : null,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Le véhicule peut encore se déplacer'),
            value: vehicleCanMove,
            onChanged: enabled ? onCanMoveChanged : null,
          ),
        ],
      ),
    );
  }
}

class _SymptomsCard extends StatelessWidget {
  const _SymptomsCard({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final Set<BreakdownSymptom> selected;
  final bool enabled;
  final void Function(BreakdownSymptom symptom, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '2. Symptômes observés',
      child: Column(
        children: [
          for (final symptom in BreakdownSymptom.values)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(symptom.label),
              value: selected.contains(symptom),
              onChanged: enabled
                  ? (value) => onChanged(symptom, value ?? false)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.assessment,
    required this.onCall112,
    required this.onSms114,
    required this.onCallAssistance,
    required this.onOpenGarages,
  });

  final BreakdownAssessment assessment;
  final VoidCallback onCall112;
  final VoidCallback onSms114;
  final VoidCallback onCallAssistance;
  final VoidCallback onOpenGarages;

  @override
  Widget build(BuildContext context) {
    final style = _actionStyle(assessment.actionLevel);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: style.foreground.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(style.icon, color: style.foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assessment.actionLevel.label,
                      style: TextStyle(
                        color: style.foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      assessment.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(assessment.explanation),
          const SizedBox(height: 14),
          _InstructionList(
            title: 'À faire maintenant',
            items: assessment.immediateSteps,
          ),
          if (assessment.safeChecks.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InstructionList(
              title: 'Vérifications sans démontage',
              items: assessment.safeChecks,
            ),
          ],
          const SizedBox(height: 12),
          _InstructionList(
            title: 'À ne pas faire',
            items: assessment.thingsToAvoid,
          ),
          const SizedBox(height: 14),
          if (assessment.shouldCall112) ...[
            FilledButton.icon(
              onPressed: onCall112,
              icon: const Icon(Icons.call),
              label: const Text('Appeler le 112'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onSms114,
              icon: const Icon(Icons.sms_outlined),
              label: const Text('Préparer un SMS au 114'),
            ),
          ],
          if (assessment.shouldCallAssistance) ...[
            if (assessment.shouldCall112) const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onCallAssistance,
              icon: const Icon(Icons.support_agent_outlined),
              label: const Text('Appeler mon assistance'),
            ),
          ],
          if (!assessment.shouldCall112 && !assessment.shouldCallAssistance)
            OutlinedButton.icon(
              onPressed: onOpenGarages,
              icon: const Icon(Icons.car_repair_outlined),
              label: const Text('Rechercher un garage proche'),
            ),
        ],
      ),
    );
  }
}

class _InstructionList extends StatelessWidget {
  const _InstructionList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );
  }
}

class _AssistanceProfileCard extends StatelessWidget {
  const _AssistanceProfileCard({
    required this.providerController,
    required this.phoneController,
    required this.contractController,
    required this.coverage,
    required this.enabled,
    required this.onCoverageChanged,
  });

  final TextEditingController providerController;
  final TextEditingController phoneController;
  final TextEditingController contractController;
  final String coverage;
  final bool enabled;
  final ValueChanged<String?> onCoverageChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '3. Mon assistance',
      child: Column(
        children: [
          TextField(
            controller: providerController,
            enabled: enabled,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Assureur ou assistance',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phoneController,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            maxLength: 30,
            decoration: const InputDecoration(labelText: 'Numéro d’assistance'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: contractController,
            enabled: enabled,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Référence de contrat facultative',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: coverage,
            decoration: const InputDecoration(labelText: 'Assistance 0 km'),
            items: const [
              DropdownMenuItem(value: 'UNKNOWN', child: Text('Je ne sais pas')),
              DropdownMenuItem(value: 'YES', child: Text('Oui')),
              DropdownMenuItem(value: 'NO', child: Text('Non')),
            ],
            onChanged: enabled ? onCoverageChanged : null,
          ),
        ],
      ),
    );
  }
}

class _RecentCaseCard extends StatelessWidget {
  const _RecentCaseCard({required this.item});

  final BreakdownCaseSummary item;

  @override
  Widget build(BuildContext context) {
    final date = item.occurredAt.toLocal();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(item.actionLevel.replaceAll('_', ' ')),
          const SizedBox(height: 6),
          Text(item.summary, maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

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
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptyVehicleCard extends StatelessWidget {
  const _EmptyVehicleCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Aucun véhicule',
      child: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un véhicule'),
      ),
    );
  }
}

_ActionStyle _actionStyle(BreakdownActionLevel level) {
  return switch (level) {
    BreakdownActionLevel.emergency => const _ActionStyle(
      background: AppColors.errorSoft,
      foreground: AppColors.error,
      icon: Icons.emergency_outlined,
    ),
    BreakdownActionLevel.motorwaySafety => const _ActionStyle(
      background: AppColors.errorSoft,
      foreground: AppColors.error,
      icon: Icons.add_road_outlined,
    ),
    BreakdownActionLevel.stopAndAssistance => const _ActionStyle(
      background: AppColors.warningSoft,
      foreground: AppColors.warning,
      icon: Icons.do_not_disturb_on_outlined,
    ),
    BreakdownActionLevel.assistanceRecommended => const _ActionStyle(
      background: AppColors.infoSoft,
      foreground: AppColors.info,
      icon: Icons.support_agent_outlined,
    ),
    BreakdownActionLevel.garageSoon => const _ActionStyle(
      background: AppColors.softPrimary,
      foreground: AppColors.primary,
      icon: Icons.car_repair_outlined,
    ),
    BreakdownActionLevel.monitor => const _ActionStyle(
      background: AppColors.successSoft,
      foreground: AppColors.success,
      icon: Icons.visibility_outlined,
    ),
  };
}

class _ActionStyle {
  const _ActionStyle({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
