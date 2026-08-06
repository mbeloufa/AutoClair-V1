import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import 'accident_assistant_calculator.dart';
import 'accident_assistant_models.dart';
import 'accident_assistant_service.dart';

class AccidentAssistantPage extends StatefulWidget {
  const AccidentAssistantPage({super.key});

  @override
  State<AccidentAssistantPage> createState() => _AccidentAssistantPageState();
}

class _AccidentAssistantPageState extends State<AccidentAssistantPage> {
  static final Uri _eConstatUri = Uri.parse(
    'https://www.service-public.fr/particuliers/vosdroits/R68773',
  );
  static final Uri _constatGuideUri = Uri.parse(
    'https://www.service-public.fr/particuliers/vosdroits/F2149',
  );

  final AccidentAssistantService _service = AccidentAssistantService();
  final TextEditingController _insurerController = TextEditingController();
  final TextEditingController _claimPhoneController = TextEditingController();
  final TextEditingController _assistancePhoneController =
      TextEditingController();
  final TextEditingController _contractController = TextEditingController();

  List<Vehicle> _vehicles = const [];
  List<AccidentCaseSnapshot> _recentCases = const [];
  String? _selectedVehicleId;
  DateTime _occurredAt = DateTime.now();
  AccidentLocationType _locationType = AccidentLocationType.urban;
  int _vehicleCount = 2;
  bool _injured = false;
  bool _immediateDanger = false;
  bool _foreignVehicle = false;
  bool _materialDamageOnly = true;
  bool _otherPartyRefused = false;
  bool _emergencyCalled = false;
  bool _policeAttended = false;
  bool _witnessesPresent = false;
  bool _photosTaken = false;
  bool _sketchPrepared = false;
  bool _reportSigned = false;
  bool _insurerNotified = false;
  bool _memoAvailable = false;
  AccidentAssessment? _assessment;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _insurerController.dispose();
    _claimPhoneController.dispose();
    _assistancePhoneController.dispose();
    _contractController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vehicles = await _service.loadVehicles();
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _selectedVehicleId = vehicles.isEmpty
            ? null
            : vehicles
                  .firstWhere(
                    (vehicle) => vehicle.isPrimary,
                    orElse: () => vehicles.first,
                  )
                  .id;
      });
      await _loadVehicleData();
    } on AccidentAssistantException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadVehicleData() async {
    final vehicleId = _selectedVehicleId;
    if (vehicleId == null) return;
    try {
      final results = await Future.wait<dynamic>([
        _service.loadProfile(vehicleId),
        _service.loadRecentCases(vehicleId),
      ]);
      if (!mounted) return;
      final profile =
          results[0] as AccidentAssistantProfile? ??
          AccidentAssistantProfile.defaults(vehicleId);
      _applyProfile(profile);
      setState(() {
        _recentCases = results[1] as List<AccidentCaseSnapshot>;
        _assessment = null;
      });
    } on AccidentAssistantException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  void _applyProfile(AccidentAssistantProfile profile) {
    _insurerController.text = profile.insurerName;
    _claimPhoneController.text = profile.claimPhone;
    _assistancePhoneController.text = profile.assistancePhone;
    _contractController.text = profile.contractReference;
    _memoAvailable = profile.memoVehicleInsuredAvailable;
  }

  Vehicle? get _selectedVehicle {
    final vehicleId = _selectedVehicleId;
    if (vehicleId == null) return null;
    for (final vehicle in _vehicles) {
      if (vehicle.id == vehicleId) return vehicle;
    }
    return null;
  }

  AccidentAssistantProfile _profile() {
    final vehicleId = _selectedVehicleId ?? '';
    return AccidentAssistantProfile(
      vehicleId: vehicleId,
      insurerName: _insurerController.text,
      claimPhone: _claimPhoneController.text,
      assistancePhone: _assistancePhoneController.text,
      contractReference: _contractController.text,
      memoVehicleInsuredAvailable: _memoAvailable,
    );
  }

  AccidentCaseInput _input() {
    return AccidentCaseInput(
      vehicleId: _selectedVehicleId ?? '',
      occurredAt: _occurredAt,
      locationType: _locationType,
      injured: _injured,
      immediateDanger: _immediateDanger,
      vehicleCount: _vehicleCount,
      foreignVehicle: _foreignVehicle,
      materialDamageOnly: _materialDamageOnly,
      otherPartyRefused: _otherPartyRefused,
      emergencyCalled: _emergencyCalled,
      policeAttended: _policeAttended,
      witnessesPresent: _witnessesPresent,
      photosTaken: _photosTaken,
      sketchPrepared: _sketchPrepared,
      reportSigned: _reportSigned,
      insurerNotified: _insurerNotified,
      memoAvailable: _memoAvailable,
    );
  }

  Future<void> _evaluateAndSave() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = _profile();
      final input = _input();
      profile.validate();
      input.validate();
      final assessment = AccidentAssistantCalculator.assess(input: input);
      final vehicle = _selectedVehicle;
      await _service.saveProfile(profile);
      await _service.saveCase(
        profile: profile,
        input: input,
        assessment: assessment,
        vehicleLabel: vehicle?.displayName ?? 'Véhicule',
      );
      final recentCases = await _service.loadRecentCases(input.vehicleId);
      if (!mounted) return;
      setState(() {
        _assessment = assessment;
        _recentCases = recentCases;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dossier accident enregistré dans le carnet.'),
        ),
      );
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on AccidentAssistantException catch (error) {
      if (mounted) setState(() => _error = error.message);
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
          input: _input(),
          vehicleLabel: vehicle.displayName,
        ),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Résumé factuel copié.')));
  }

  Future<void> _call(String phone) async {
    final normalized = normalizePhone(phone);
    final isEmergencyNumber = normalized == '112';
    if (!isEmergencyNumber && normalized.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro de téléphone indisponible.')),
      );
      return;
    }
    await _open(Uri.parse('tel:$normalized'));
  }

  Future<void> _open(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir ce service.')),
      );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (selected != null && mounted) {
      setState(() {
        _occurredAt = selected;
        _assessment = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accident et constat')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                const _SafetyBanner(),
                const SizedBox(height: 14),
                if (_error != null) ...[
                  _ErrorCard(message: _error!),
                  const SizedBox(height: 14),
                ],
                if (_vehicles.isEmpty)
                  const _EmptyVehicleCard()
                else ...[
                  _SectionCard(
                    title: 'Véhicule et assurance',
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          key: ValueKey(_selectedVehicleId),
                          initialValue: _selectedVehicleId,
                          decoration: const InputDecoration(
                            labelText: 'Véhicule concerné',
                          ),
                          items: _vehicles
                              .map(
                                (vehicle) => DropdownMenuItem<String>(
                                  value: vehicle.id,
                                  child: Text(vehicle.displayName),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() {
                              _selectedVehicleId = value;
                              _assessment = null;
                              _error = null;
                            });
                            await _loadVehicleData();
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _insurerController,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Assureur',
                          ),
                        ),
                        TextField(
                          controller: _claimPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Téléphone déclaration de sinistre',
                          ),
                        ),
                        TextField(
                          controller: _assistancePhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Téléphone assistance',
                          ),
                        ),
                        TextField(
                          controller: _contractController,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Référence du contrat',
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _memoAvailable,
                          title: const Text('Mémo Véhicule Assuré disponible'),
                          onChanged: (value) => setState(() {
                            _memoAvailable = value;
                            _assessment = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Situation',
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_month_outlined),
                          title: const Text('Date de l’accident'),
                          subtitle: Text(_formatDate(_occurredAt)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _pickDate,
                        ),
                        DropdownButtonFormField<AccidentLocationType>(
                          initialValue: _locationType,
                          decoration: const InputDecoration(
                            labelText: 'Type de voie',
                          ),
                          items: AccidentLocationType.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _locationType = value;
                              _assessment = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _vehicleCount,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de véhicules impliqués',
                          ),
                          items: List.generate(
                            10,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('${index + 1}'),
                            ),
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _vehicleCount = value;
                              _assessment = null;
                            });
                          },
                        ),
                        _BooleanTile(
                          title: 'Une personne est blessée ou se plaint',
                          value: _injured,
                          onChanged: (value) => setState(() {
                            _injured = value;
                            if (value) _materialDamageOnly = false;
                            _assessment = null;
                          }),
                        ),
                        _BooleanTile(
                          title: 'Un danger immédiat subsiste',
                          value: _immediateDanger,
                          onChanged: (value) => setState(() {
                            _immediateDanger = value;
                            _assessment = null;
                          }),
                        ),
                        _BooleanTile(
                          title: 'Dommages uniquement matériels',
                          value: _materialDamageOnly,
                          onChanged: (value) => setState(() {
                            _materialDamageOnly = value;
                            _assessment = null;
                          }),
                        ),
                        _BooleanTile(
                          title: 'Un véhicule étranger est impliqué',
                          value: _foreignVehicle,
                          onChanged: (value) => setState(() {
                            _foreignVehicle = value;
                            _assessment = null;
                          }),
                        ),
                        _BooleanTile(
                          title:
                              'L’autre partie refuse ou conteste la signature',
                          value: _otherPartyRefused,
                          onChanged: (value) => setState(() {
                            _otherPartyRefused = value;
                            _assessment = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Éléments préparés',
                    child: Column(
                      children: [
                        _BooleanTile(
                          title: 'Secours appelés',
                          value: _emergencyCalled,
                          onChanged: (value) => setState(() {
                            _emergencyCalled = value;
                            _assessment = null;
                          }),
                        ),
                        _BooleanTile(
                          title: 'Police ou gendarmerie présente',
                          value: _policeAttended,
                          onChanged: (value) => setState(() {
                            _policeAttended = value;
                            _assessment = null;
                          }),
                        ),
                        _BooleanTile(
                          title: 'Témoins indépendants présents',
                          value: _witnessesPresent,
                          onChanged: (value) => setState(() {
                            _witnessesPresent = value;
                            _assessment = null;
                          }),
                        ),
                        _BooleanTile(
                          title: 'Photos factuelles réalisées',
                          value: _photosTaken,
                          onChanged: (value) => setState(() {
                            _photosTaken = value;
                            _assessment = null;
                          }),
                        ),
                        _BooleanTile(
                          title: 'Croquis et circonstances préparés',
                          value: _sketchPrepared,
                          onChanged: (value) => setState(() {
                            _sketchPrepared = value;
                            _assessment = null;
                          }),
                        ),
                        _BooleanTile(
                          title: 'Constat relu et signé',
                          value: _reportSigned,
                          onChanged: (value) => setState(() {
                            _reportSigned = value;
                            _assessment = null;
                          }),
                        ),
                        _BooleanTile(
                          title: 'Assureur déjà prévenu',
                          value: _insurerNotified,
                          onChanged: (value) => setState(() {
                            _insurerNotified = value;
                            _assessment = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _QuickActions(
                    onEmergency: () => _call('112'),
                    onEConstat: () => _open(_eConstatUri),
                    onGuide: () => _open(_constatGuideUri),
                    onClaim: () => _call(_claimPhoneController.text),
                    onAssistance: () => _call(_assistancePhoneController.text),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _saving ? null : _evaluateAndSave,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fact_check_outlined),
                    label: const Text('Préparer et enregistrer le dossier'),
                  ),
                  if (_assessment != null) ...[
                    const SizedBox(height: 14),
                    _AssessmentCard(
                      assessment: _assessment!,
                      onCopy: _copySummary,
                    ),
                  ],
                  if (_recentCases.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'Derniers dossiers',
                      child: Column(
                        children: [
                          for (final item in _recentCases)
                            _RecentCaseTile(snapshot: item),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_outlined, color: AppColors.error),
          SizedBox(height: 10),
          Text(
            'Sécurisez d’abord les personnes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'En cas de blessé ou de danger, appelez le 112. AutoClair organise les faits saisis, mais ne détermine jamais les responsabilités.',
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onEmergency,
    required this.onEConstat,
    required this.onGuide,
    required this.onClaim,
    required this.onAssistance,
  });

  final VoidCallback onEmergency;
  final VoidCallback onEConstat;
  final VoidCallback onGuide;
  final VoidCallback onClaim;
  final VoidCallback onAssistance;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Actions utiles',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: onEmergency,
            icon: const Icon(Icons.emergency_outlined),
            label: const Text('Appeler le 112'),
          ),
          FilledButton.tonalIcon(
            onPressed: onEConstat,
            icon: const Icon(Icons.phone_android_outlined),
            label: const Text('Ouvrir e-constat'),
          ),
          FilledButton.tonalIcon(
            onPressed: onGuide,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Guide du constat'),
          ),
          OutlinedButton.icon(
            onPressed: onClaim,
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Appeler mon assureur'),
          ),
          OutlinedButton.icon(
            onPressed: onAssistance,
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Appeler l’assistance'),
          ),
        ],
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.assessment, required this.onCopy});

  final AccidentAssessment assessment;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final color = switch (assessment.actionLevel) {
      AccidentActionLevel.emergency => AppColors.error,
      AccidentActionLevel.paperReport => AppColors.warning,
      AccidentActionLevel.electronicReport => AppColors.success,
      AccidentActionLevel.insurerDeclaration => AppColors.info,
    };
    return _SectionCard(
      title: 'Orientation AutoClair',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assessment.actionLevel.label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Dossier préparé à ${assessment.score}/100'),
                Text(
                  'Déclaration indicative avant le '
                  '${_formatDate(assessment.declarationDueDate)} '
                  '(hors jours fériés).',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final item in assessment.items) ...[
            _ChecklistTile(item: item),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Text('Photos utiles', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final suggestion in assessment.photoSuggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.photo_camera_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(suggestion)),
                ],
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copier le résumé factuel'),
          ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({required this.item});

  final AccidentChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.level) {
      AccidentCheckLevel.ready => AppColors.success,
      AccidentCheckLevel.warning => AppColors.warning,
      AccidentCheckLevel.blocking => AppColors.error,
      AccidentCheckLevel.information => AppColors.info,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(item.detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentCaseTile extends StatelessWidget {
  const _RecentCaseTile({required this.snapshot});

  final AccidentCaseSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.description_outlined),
      title: Text(snapshot.actionLevel.label),
      subtitle: Text(
        '${_formatDate(snapshot.occurredAt)} · '
        '${snapshot.insurerNotified ? 'Assureur prévenu' : 'Déclaration à suivre'}',
      ),
      trailing: Text('${snapshot.score}/100'),
    );
  }
}

class _BooleanTile extends StatelessWidget {
  const _BooleanTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: onChanged,
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}

class _EmptyVehicleCard extends StatelessWidget {
  const _EmptyVehicleCard();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      title: 'Aucun véhicule',
      child: Text(
        'Ajoutez d’abord un véhicule dans AutoClair pour préparer un dossier accident.',
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
