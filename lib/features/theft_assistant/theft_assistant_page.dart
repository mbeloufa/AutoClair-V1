import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import 'theft_assistant_calculator.dart';
import 'theft_assistant_models.dart';
import 'theft_assistant_service.dart';

class TheftAssistantPage extends StatefulWidget {
  const TheftAssistantPage({super.key});

  @override
  State<TheftAssistantPage> createState() => _TheftAssistantPageState();
}

class _TheftAssistantPageState extends State<TheftAssistantPage> {
  static final Uri _officialGuideUri = Uri.parse(
    'https://www.service-public.fr/particuliers/vosdroits/F34300/22?idFicheParent=N367',
  );
  static final Uri _onlineComplaintUri = Uri.parse(
    'https://aab.plainte-en-ligne.masecurite.interieur.gouv.fr/accueil',
  );

  final TheftAssistantService _service = TheftAssistantService();
  final TextEditingController _insurerController = TextEditingController();
  final TextEditingController _claimPhoneController = TextEditingController();
  final TextEditingController _assistancePhoneController =
      TextEditingController();
  final TextEditingController _contractController = TextEditingController();

  List<Vehicle> _vehicles = const [];
  List<TheftCaseSnapshot> _recentCases = const [];
  String? _selectedVehicleId;
  DateTime _occurredAt = DateTime.now();
  TheftIncidentType _incidentType = TheftIncidentType.vehicleTheft;
  TheftContextType _contextType = TheftContextType.publicRoad;
  bool _incidentInProgress = false;
  bool _authorKnown = false;
  bool _vehicleMissing = true;
  bool _impoundChecked = false;
  bool _policeReported = false;
  bool _complaintReceiptAvailable = false;
  bool _insurerNotified = false;
  bool _registrationDocumentStolen = false;
  bool _insuranceDocumentsStolen = false;
  bool _drivingLicenceStolen = false;
  int _keysAvailableCount = 2;
  bool _photosTaken = false;
  bool _invoicesAvailable = false;
  bool _trackerDeclaredToPolice = false;
  bool _vehicleFound = false;
  bool _trackerAvailable = false;
  bool _theftCoverageKnown = false;
  TheftAssessment? _assessment;
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
      final selected = vehicles.isEmpty ? null : vehicles.first.id;
      setState(() {
        _vehicles = vehicles;
        _selectedVehicleId = selected;
      });
      if (selected != null) {
        await _loadVehicleData(selected);
      }
    } on TheftAssistantException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadVehicleData(String vehicleId) async {
    final results = await Future.wait([
      _service.loadProfile(vehicleId),
      _service.loadRecentCases(vehicleId),
    ]);
    if (!mounted || _selectedVehicleId != vehicleId) return;

    final profile = results[0] as TheftAssistantProfile?;
    final recent = results[1] as List<TheftCaseSnapshot>;
    final effective = profile ?? TheftAssistantProfile.defaults(vehicleId);
    setState(() {
      _insurerController.text = effective.insurerName;
      _claimPhoneController.text = effective.claimPhone;
      _assistancePhoneController.text = effective.assistancePhone;
      _contractController.text = effective.contractReference;
      _trackerAvailable = effective.trackerAvailable;
      _theftCoverageKnown = effective.theftCoverageKnown;
      _recentCases = recent;
      _assessment = null;
    });
  }

  TheftAssistantProfile _profile() {
    return TheftAssistantProfile(
      vehicleId: _selectedVehicleId ?? '',
      insurerName: _insurerController.text,
      claimPhone: _claimPhoneController.text,
      assistancePhone: _assistancePhoneController.text,
      contractReference: _contractController.text,
      trackerAvailable: _trackerAvailable,
      theftCoverageKnown: _theftCoverageKnown,
    );
  }

  TheftCaseInput _input() {
    return TheftCaseInput(
      vehicleId: _selectedVehicleId ?? '',
      occurredAt: _occurredAt,
      incidentType: _incidentType,
      contextType: _contextType,
      incidentInProgress: _incidentInProgress,
      authorKnown: _authorKnown,
      vehicleMissing: _vehicleMissing,
      impoundChecked: _impoundChecked,
      policeReported: _policeReported,
      complaintReceiptAvailable: _complaintReceiptAvailable,
      insurerNotified: _insurerNotified,
      registrationDocumentStolen: _registrationDocumentStolen,
      insuranceDocumentsStolen: _insuranceDocumentsStolen,
      drivingLicenceStolen: _drivingLicenceStolen,
      keysAvailableCount: _keysAvailableCount,
      photosTaken: _photosTaken,
      invoicesAvailable: _invoicesAvailable,
      trackerDeclaredToPolice: _trackerDeclaredToPolice,
      vehicleFound: _vehicleFound,
    );
  }

  Vehicle? get _selectedVehicle {
    for (final vehicle in _vehicles) {
      if (vehicle.id == _selectedVehicleId) return vehicle;
    }
    return null;
  }

  Future<void> _evaluateAndSave() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = _profile();
      final input = _input();
      final assessment = TheftAssistantCalculator.assess(
        profile: profile,
        input: input,
      );
      final vehicle = _selectedVehicle;
      if (vehicle == null) {
        throw const FormatException('Sélectionnez un véhicule.');
      }
      await _service.saveProfile(profile);
      await _service.saveCase(
        profile: profile,
        input: input,
        assessment: assessment,
        vehicleLabel: vehicle.displayName,
      );
      final recent = await _service.loadRecentCases(vehicle.id);
      if (!mounted) return;
      setState(() {
        _assessment = assessment;
        _recentCases = recent;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dossier enregistré dans AutoClair.')),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on TheftAssistantException catch (error) {
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
    final summary = assessment.buildShareSummary(
      input: _input(),
      vehicleLabel: vehicle.displayName,
    );
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Résumé copié.')));
  }

  Future<void> _call(String number) async {
    final normalized = normalizePhone(number);
    if (normalized != '17' && normalized.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro de téléphone non renseigné.')),
      );
      return;
    }
    final uri = Uri.parse('tel:$normalized');
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le téléphone.')),
      );
    }
  }

  Future<void> _open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir ce service.')),
      );
    }
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDate: _occurredAt,
    );
    if (picked != null && mounted) {
      setState(() {
        _occurredAt = picked;
        _assessment = null;
      });
    }
  }

  void _updateIncidentType(TheftIncidentType value) {
    setState(() {
      _incidentType = value;
      _vehicleMissing = value == TheftIncidentType.vehicleTheft;
      _assessment = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vol, effraction ou vandalisme')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ajoutez d’abord un véhicule pour préparer ce dossier.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                const _SafetyBanner(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Véhicule et assurance',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedVehicleId,
                        decoration: const InputDecoration(
                          labelText: 'Véhicule concerné',
                        ),
                        items: [
                          for (final vehicle in _vehicles)
                            DropdownMenuItem(
                              value: vehicle.id,
                              child: Text(vehicle.displayName),
                            ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          setState(() {
                            _selectedVehicleId = value;
                            _assessment = null;
                          });
                          await _loadVehicleData(value);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _insurerController,
                        decoration: const InputDecoration(
                          labelText: 'Assureur',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _claimPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone sinistre',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _assistancePhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone assistance',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _contractController,
                        decoration: const InputDecoration(
                          labelText: 'Référence du contrat',
                        ),
                      ),
                      _BooleanTile(
                        title: 'Traceur antivol présent',
                        value: _trackerAvailable,
                        onChanged: (value) => setState(() {
                          _trackerAvailable = value;
                          _assessment = null;
                        }),
                      ),
                      _BooleanTile(
                        title: 'Garanties vol ou dommages vérifiées',
                        value: _theftCoverageKnown,
                        onChanged: (value) => setState(() {
                          _theftCoverageKnown = value;
                          _assessment = null;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Situation constatée',
                  child: Column(
                    children: [
                      DropdownButtonFormField<TheftIncidentType>(
                        isExpanded: true,
                        initialValue: _incidentType,
                        decoration: const InputDecoration(
                          labelText: 'Type de situation',
                        ),
                        items: [
                          for (final type in TheftIncidentType.values)
                            DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) _updateIncidentType(value);
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<TheftContextType>(
                        isExpanded: true,
                        initialValue: _contextType,
                        decoration: const InputDecoration(
                          labelText: 'Contexte général',
                        ),
                        items: [
                          for (final type in TheftContextType.values)
                            DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _contextType = value;
                            _assessment = null;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _chooseDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text('Date : ${_formatDate(_occurredAt)}'),
                      ),
                      _BooleanTile(
                        title: 'Les faits sont en cours maintenant',
                        value: _incidentInProgress,
                        onChanged: (value) => setState(() {
                          _incidentInProgress = value;
                          _assessment = null;
                        }),
                      ),
                      _BooleanTile(
                        title: 'Je connais l’identité de l’auteur',
                        value: _authorKnown,
                        onChanged: (value) => setState(() {
                          _authorKnown = value;
                          _assessment = null;
                        }),
                      ),
                      _BooleanTile(
                        title: 'Le véhicule est introuvable',
                        value: _vehicleMissing,
                        onChanged: (value) => setState(() {
                          _vehicleMissing = value;
                          _assessment = null;
                        }),
                      ),
                      _BooleanTile(
                        title: 'La fourrière a été vérifiée',
                        value: _impoundChecked,
                        onChanged: (value) => setState(() {
                          _impoundChecked = value;
                          _assessment = null;
                        }),
                      ),
                      _BooleanTile(
                        title: 'Le véhicule a été retrouvé',
                        value: _vehicleFound,
                        onChanged: (value) => setState(() {
                          _vehicleFound = value;
                          _assessment = null;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Démarches et preuves',
                  child: Column(
                    children: [
                      _BooleanTile(
                        title: 'Plainte déposée',
                        value: _policeReported,
                        onChanged: (value) => setState(() {
                          _policeReported = value;
                          _assessment = null;
                        }),
                      ),
                      _BooleanTile(
                        title: 'Récépissé ou copie de plainte disponible',
                        value: _complaintReceiptAvailable,
                        onChanged: (value) => setState(() {
                          _complaintReceiptAvailable = value;
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
                      _BooleanTile(
                        title: 'Photos réalisées',
                        value: _photosTaken,
                        onChanged: (value) => setState(() {
                          _photosTaken = value;
                          _assessment = null;
                        }),
                      ),
                      _BooleanTile(
                        title: 'Factures et justificatifs disponibles',
                        value: _invoicesAvailable,
                        onChanged: (value) => setState(() {
                          _invoicesAvailable = value;
                          _assessment = null;
                        }),
                      ),
                      _BooleanTile(
                        title: 'Traceur signalé aux forces de l’ordre',
                        value: _trackerDeclaredToPolice,
                        onChanged: (value) => setState(() {
                          _trackerDeclaredToPolice = value;
                          _assessment = null;
                        }),
                      ),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _keysAvailableCount,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de clés disponibles',
                        ),
                        items: [
                          for (var count = 0; count <= 4; count++)
                            DropdownMenuItem(
                              value: count,
                              child: Text('$count'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _keysAvailableCount = value;
                            _assessment = null;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _BooleanTile(
                        title: 'Certificat d’immatriculation volé',
                        value: _registrationDocumentStolen,
                        onChanged: (value) => setState(() {
                          _registrationDocumentStolen = value;
                          _assessment = null;
                        }),
                      ),
                      _BooleanTile(
                        title: 'Documents d’assurance volés',
                        value: _insuranceDocumentsStolen,
                        onChanged: (value) => setState(() {
                          _insuranceDocumentsStolen = value;
                          _assessment = null;
                        }),
                      ),
                      _BooleanTile(
                        title: 'Permis de conduire volé',
                        value: _drivingLicenceStolen,
                        onChanged: (value) => setState(() {
                          _drivingLicenceStolen = value;
                          _assessment = null;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _QuickActions(
                  onPolice: () => _call('17'),
                  onComplaint: () => _open(_onlineComplaintUri),
                  onGuide: () => _open(_officialGuideUri),
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
          Icon(Icons.security_outlined, color: AppColors.error),
          SizedBox(height: 10),
          Text(
            'Ne vous mettez jamais en danger',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Si le vol ou la dégradation est en cours, éloignez-vous et appelez le 17. Ne confrontez personne et ne poursuivez pas le véhicule.',
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onPolice,
    required this.onComplaint,
    required this.onGuide,
    required this.onClaim,
    required this.onAssistance,
  });

  final VoidCallback onPolice;
  final VoidCallback onComplaint;
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
            onPressed: onPolice,
            icon: const Icon(Icons.local_police_outlined),
            label: const Text('Appeler le 17'),
          ),
          FilledButton.tonalIcon(
            onPressed: onComplaint,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Ouvrir Plainte en ligne'),
          ),
          FilledButton.tonalIcon(
            onPressed: onGuide,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Guide officiel vol'),
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

  final TheftAssessment assessment;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final color = switch (assessment.actionLevel) {
      TheftActionLevel.emergency => AppColors.error,
      TheftActionLevel.checkImpound => AppColors.warning,
      TheftActionLevel.policeReport => AppColors.error,
      TheftActionLevel.insurerDeclaration => AppColors.warning,
      TheftActionLevel.followUp => AppColors.success,
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
                  '(hors jours fériés, contrat prioritaire).',
                ),
                Text(
                  assessment.onlineComplaintEligible
                      ? 'Plainte en ligne potentiellement possible si l’auteur est inconnu.'
                      : 'La plainte en ligne ne correspond pas au scénario déclaré.',
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
          Text(
            'Éléments utiles',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final suggestion in assessment.evidenceSuggestions)
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

  final TheftChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.level) {
      TheftCheckLevel.ready => AppColors.success,
      TheftCheckLevel.warning => AppColors.warning,
      TheftCheckLevel.blocking => AppColors.error,
      TheftCheckLevel.information => AppColors.info,
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

  final TheftCaseSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.security_outlined),
      title: Text(snapshot.incidentType.label),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            child,
          ],
        ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
