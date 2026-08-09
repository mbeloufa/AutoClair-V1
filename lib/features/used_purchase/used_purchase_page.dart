import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import 'used_listing_analysis.dart';
import 'used_listing_analysis_card.dart';
import 'used_purchase_calculator.dart';
import 'used_purchase_models.dart';
import 'used_purchase_service.dart';

class UsedPurchasePage extends StatefulWidget {
  const UsedPurchasePage({super.key});

  @override
  State<UsedPurchasePage> createState() => _UsedPurchasePageState();
}

class _UsedPurchasePageState extends State<UsedPurchasePage> {
  static final Uri _histovecUri = Uri.parse(
    'https://histovec.interieur.gouv.fr/',
  );
  static final Uri _simplimmatUri = Uri.parse(
    'https://immatriculation.ants.gouv.fr/simplimmat?lang=fr',
  );
  static final Uri _registrationUri = Uri.parse(
    'https://www.service-public.fr/particuliers/vosdroits/F34300',
  );

  final UsedPurchaseService _service = UsedPurchaseService();
  final TextEditingController _listingController = TextEditingController();
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _mileageController = TextEditingController();
  final TextEditingController _askingPriceController = TextEditingController();
  final TextEditingController _registrationCostController =
      TextEditingController();
  final TextEditingController _repairsController = TextEditingController();
  final TextEditingController _inspectionController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  PurchaseSellerType _sellerType = PurchaseSellerType.privateIndividual;
  PurchaseTechnicalControlStatus _technicalControlStatus =
      PurchaseTechnicalControlStatus.unknown;
  DateTime? _csaIssuedAt;
  DateTime? _technicalControlDate;
  bool _sellerRightToSellVerified = false;
  bool _registrationAvailable = false;
  bool _vinMatchesRegistration = false;
  bool _csaClear = false;
  bool _histovecReviewed = false;
  bool _mileageHistoryCoherent = false;
  bool _maintenanceEvidence = false;
  bool _coldStartObserved = false;
  bool _warningLightsClear = false;
  bool _testDriveCompleted = false;
  bool _brakingSteeringHealthy = false;
  bool _leaksOrSmokeDetected = false;
  bool _bodyStructureConcern = false;
  bool _securePaymentPlanned = false;
  bool _depositBeforeChecks = false;

  List<UsedPurchaseSnapshot> _snapshots = const [];
  UsedPurchaseAssessment? _assessment;
  UsedListingAnalysis? _listingAnalysis;
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
    _listingController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _mileageController.dispose();
    _askingPriceController.dispose();
    _registrationCostController.dispose();
    _repairsController.dispose();
    _inspectionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _service.loadProfile(),
        _service.loadRecentAssessments(),
      ]);
      final profile =
          results[0] as UsedPurchaseProfile? ?? UsedPurchaseProfile.defaults();
      if (!mounted) return;
      _applyProfile(profile);
      setState(() {
        _snapshots = results[1] as List<UsedPurchaseSnapshot>;
        _assessment = _hasMeaningfulData(profile)
            ? UsedPurchaseCalculator.assess(profile: profile)
            : null;
      });
    } on UsedPurchaseException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyProfile(UsedPurchaseProfile profile) {
    _sellerType = profile.sellerType;
    _makeController.text = profile.make;
    _modelController.text = profile.model;
    _yearController.text = profile.vehicleYear?.toString() ?? '';
    _mileageController.text = profile.mileage?.toString() ?? '';
    _askingPriceController.text = _moneyInput(profile.askingPrice);
    _registrationCostController.text = _moneyInput(profile.registrationCost);
    _repairsController.text = _moneyInput(profile.immediateRepairBudget);
    _inspectionController.text = _moneyInput(profile.inspectionCost);
    _budgetController.text = _moneyInput(profile.availableBudget);
    _sellerRightToSellVerified = profile.sellerRightToSellVerified;
    _registrationAvailable = profile.registrationAvailable;
    _vinMatchesRegistration = profile.vinMatchesRegistration;
    _csaIssuedAt = profile.csaIssuedAt;
    _csaClear = profile.csaClear;
    _histovecReviewed = profile.histovecReviewed;
    _technicalControlDate = profile.technicalControlDate;
    _technicalControlStatus = profile.technicalControlStatus;
    _mileageHistoryCoherent = profile.mileageHistoryCoherent;
    _maintenanceEvidence = profile.maintenanceEvidence;
    _coldStartObserved = profile.coldStartObserved;
    _warningLightsClear = profile.warningLightsClear;
    _testDriveCompleted = profile.testDriveCompleted;
    _brakingSteeringHealthy = profile.brakingSteeringHealthy;
    _leaksOrSmokeDetected = profile.leaksOrSmokeDetected;
    _bodyStructureConcern = profile.bodyStructureConcern;
    _securePaymentPlanned = profile.securePaymentPlanned;
    _depositBeforeChecks = profile.depositBeforeChecks;
  }

  UsedPurchaseProfile _profile() {
    return UsedPurchaseProfile(
      sellerType: _sellerType,
      make: _makeController.text,
      model: _modelController.text,
      vehicleYear: _integerOrNull(_yearController.text),
      mileage: _integerOrNull(_mileageController.text),
      askingPrice: _money(_askingPriceController.text),
      registrationCost: _money(_registrationCostController.text),
      immediateRepairBudget: _money(_repairsController.text),
      inspectionCost: _money(_inspectionController.text),
      availableBudget: _money(_budgetController.text),
      sellerRightToSellVerified: _sellerRightToSellVerified,
      registrationAvailable: _registrationAvailable,
      vinMatchesRegistration: _vinMatchesRegistration,
      csaIssuedAt: _csaIssuedAt,
      csaClear: _csaClear,
      histovecReviewed: _histovecReviewed,
      technicalControlDate: _technicalControlDate,
      technicalControlStatus: _technicalControlStatus,
      mileageHistoryCoherent: _mileageHistoryCoherent,
      maintenanceEvidence: _maintenanceEvidence,
      coldStartObserved: _coldStartObserved,
      warningLightsClear: _warningLightsClear,
      testDriveCompleted: _testDriveCompleted,
      brakingSteeringHealthy: _brakingSteeringHealthy,
      leaksOrSmokeDetected: _leaksOrSmokeDetected,
      bodyStructureConcern: _bodyStructureConcern,
      securePaymentPlanned: _securePaymentPlanned,
      depositBeforeChecks: _depositBeforeChecks,
    );
  }

  void _analyzeListing() {
    final source = _listingController.text.trim();
    if (source.length < 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Collez un peu plus de texte de l’annonce pour obtenir une lecture utile.',
          ),
        ),
      );
      return;
    }

    final analysis = UsedListingAnalyzer.analyze(source);
    var prefilled = false;

    if (_yearController.text.trim().isEmpty && analysis.detectedYear != null) {
      _yearController.text = analysis.detectedYear.toString();
      prefilled = true;
    }
    if (_mileageController.text.trim().isEmpty &&
        analysis.detectedMileage != null) {
      _mileageController.text = analysis.detectedMileage.toString();
      prefilled = true;
    }
    if (_askingPriceController.text.trim().isEmpty &&
        analysis.detectedPrice != null) {
      _askingPriceController.text = analysis.detectedPrice!.toStringAsFixed(0);
      prefilled = true;
    }

    setState(() => _listingAnalysis = analysis);

    if (prefilled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Les informations détectées ont prérempli les champs encore vides.',
          ),
        ),
      );
    }
  }

  Future<void> _copyListingQuestions() async {
    final analysis = _listingAnalysis;
    if (analysis == null || analysis.questions.isEmpty) return;

    final text = analysis.questions.map((question) => '• $question').join('\n');
    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Questions au vendeur copiées.')),
    );
  }

  Future<void> _evaluateAndSave() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = _profile();
      final assessment = UsedPurchaseCalculator.assess(profile: profile);
      await _service.saveProfile(profile);
      await _service.saveAssessment(profile: profile, assessment: assessment);
      final snapshots = await _service.loadRecentAssessments();
      if (!mounted) return;
      setState(() {
        _assessment = assessment;
        _snapshots = snapshots;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Évaluation d’achat enregistrée.')),
      );
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on UsedPurchaseException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copySummary() async {
    final assessment = _assessment;
    if (assessment == null) return;
    await Clipboard.setData(
      ClipboardData(text: assessment.buildShareSummary(_profile())),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Résumé copié.')));
  }

  Future<void> _open(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir ce service.')),
      );
    }
  }

  Future<void> _pickCsaDate() async {
    final date = await _pickDate(_csaIssuedAt);
    if (date != null && mounted) setState(() => _csaIssuedAt = date);
  }

  Future<void> _pickTechnicalControlDate() async {
    final date = await _pickDate(_technicalControlDate);
    if (date != null && mounted) {
      setState(() => _technicalControlDate = date);
    }
  }

  Future<DateTime?> _pickDate(DateTime? current) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acheter sans mauvaise surprise')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                children: [
                  const _IntroCard(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorCard(message: _error!),
                  ],
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '0. Lire l’annonce',
                    icon: Icons.search_rounded,
                    children: [
                      TextField(
                        controller: _listingController,
                        minLines: 5,
                        maxLines: 9,
                        maxLength: 6000,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(6000),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Texte de l’annonce',
                          hintText:
                              'Collez ici le texte publié par le vendeur.',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _analyzeListing,
                        icon: const Icon(Icons.manage_search_rounded),
                        label: const Text('Lire cette annonce'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Le texte reste sur l’appareil et n’est pas enregistré '
                        'dans votre dossier d’achat.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_listingAnalysis != null) ...[
                        const SizedBox(height: 14),
                        UsedListingAnalysisCard(
                          analysis: _listingAnalysis!,
                          onCopyQuestions: _copyListingQuestions,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '1. Véhicule et budget',
                    icon: Icons.directions_car_outlined,
                    children: [
                      DropdownButtonFormField<PurchaseSellerType>(
                        initialValue: _sellerType,
                        decoration: const InputDecoration(
                          labelText: 'Type de vendeur',
                        ),
                        items: PurchaseSellerType.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _sellerType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _TextField(
                              controller: _makeController,
                              label: 'Marque',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TextField(
                              controller: _modelController,
                              label: 'Modèle',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _TextField(
                              controller: _yearController,
                              label: 'Année',
                              numeric: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TextField(
                              controller: _mileageController,
                              label: 'Kilométrage',
                              numeric: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _MoneyGrid(
                        askingPriceController: _askingPriceController,
                        registrationCostController: _registrationCostController,
                        repairsController: _repairsController,
                        inspectionController: _inspectionController,
                        budgetController: _budgetController,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '2. Documents avant rendez-vous',
                    icon: Icons.folder_copy_outlined,
                    children: [
                      _CheckTile(
                        title: 'Le vendeur justifie son droit de vendre',
                        value: _sellerRightToSellVerified,
                        onChanged: (value) =>
                            setState(() => _sellerRightToSellVerified = value),
                      ),
                      _CheckTile(
                        title: 'Carte grise originale disponible',
                        value: _registrationAvailable,
                        onChanged: (value) =>
                            setState(() => _registrationAvailable = value),
                      ),
                      _CheckTile(
                        title: 'VIN identique sur le véhicule et les documents',
                        value: _vinMatchesRegistration,
                        onChanged: (value) =>
                            setState(() => _vinMatchesRegistration = value),
                      ),
                      _DateRow(
                        label: 'Date du certificat administratif',
                        value: _csaIssuedAt,
                        onPressed: _pickCsaDate,
                        onClear: () => setState(() => _csaIssuedAt = null),
                      ),
                      _CheckTile(
                        title: 'Certificat sans opposition bloquante',
                        value: _csaClear,
                        onChanged: (value) => setState(() => _csaClear = value),
                      ),
                      _CheckTile(
                        title: 'Rapport HistoVec consulté',
                        value: _histovecReviewed,
                        onChanged: (value) =>
                            setState(() => _histovecReviewed = value),
                      ),
                      _CheckTile(
                        title: 'Kilométrage cohérent avec l’historique',
                        value: _mileageHistoryCoherent,
                        onChanged: (value) =>
                            setState(() => _mileageHistoryCoherent = value),
                      ),
                      _CheckTile(
                        title: 'Factures ou preuves d’entretien disponibles',
                        value: _maintenanceEvidence,
                        onChanged: (value) =>
                            setState(() => _maintenanceEvidence = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '3. Contrôle technique',
                    icon: Icons.fact_check_outlined,
                    children: [
                      DropdownButtonFormField<PurchaseTechnicalControlStatus>(
                        initialValue: _technicalControlStatus,
                        decoration: const InputDecoration(
                          labelText: 'Résultat du contrôle technique',
                        ),
                        items: PurchaseTechnicalControlStatus.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _technicalControlStatus = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      _DateRow(
                        label: 'Date du contrôle technique',
                        value: _technicalControlDate,
                        onPressed: _pickTechnicalControlDate,
                        onClear: () =>
                            setState(() => _technicalControlDate = null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '4. Inspection et essai',
                    icon: Icons.manage_search_outlined,
                    children: [
                      _CheckTile(
                        title: 'Démarrage à froid observé',
                        value: _coldStartObserved,
                        onChanged: (value) =>
                            setState(() => _coldStartObserved = value),
                      ),
                      _CheckTile(
                        title: 'Aucun voyant persistant',
                        value: _warningLightsClear,
                        onChanged: (value) =>
                            setState(() => _warningLightsClear = value),
                      ),
                      _CheckTile(
                        title: 'Essai routier réalisé',
                        value: _testDriveCompleted,
                        onChanged: (value) =>
                            setState(() => _testDriveCompleted = value),
                      ),
                      _CheckTile(
                        title: 'Freinage et direction sans anomalie évidente',
                        value: _brakingSteeringHealthy,
                        onChanged: (value) =>
                            setState(() => _brakingSteeringHealthy = value),
                      ),
                      _CheckTile(
                        title: 'Fuite ou fumée anormale détectée',
                        value: _leaksOrSmokeDetected,
                        danger: true,
                        onChanged: (value) =>
                            setState(() => _leaksOrSmokeDetected = value),
                      ),
                      _CheckTile(
                        title: 'Doute sur la structure ou les alignements',
                        value: _bodyStructureConcern,
                        danger: true,
                        onChanged: (value) =>
                            setState(() => _bodyStructureConcern = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '5. Paiement et décision',
                    icon: Icons.payments_outlined,
                    children: [
                      _CheckTile(
                        title: 'Paiement traçable et vérifié avec la banque',
                        value: _securePaymentPlanned,
                        onChanged: (value) =>
                            setState(() => _securePaymentPlanned = value),
                      ),
                      _CheckTile(
                        title: 'Un acompte est demandé avant les vérifications',
                        value: _depositBeforeChecks,
                        danger: true,
                        onChanged: (value) =>
                            setState(() => _depositBeforeChecks = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _evaluateAndSave,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.rule_folder_outlined),
                    label: Text(
                      _saving ? 'Analyse en cours…' : 'Analyser cet achat',
                    ),
                  ),
                  if (_assessment != null) ...[
                    const SizedBox(height: 16),
                    _AssessmentCard(
                      assessment: _assessment!,
                      onCopy: _copySummary,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _OfficialLinksCard(
                    onHistovec: () => _open(_histovecUri),
                    onSimplimmat: () => _open(_simplimmatUri),
                    onRegistration: () => _open(_registrationUri),
                  ),
                  if (_snapshots.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _HistoryCard(snapshots: _snapshots),
                  ],
                ],
              ),
            ),
    );
  }

  static bool _hasMeaningfulData(UsedPurchaseProfile profile) {
    return profile.make.trim().isNotEmpty ||
        profile.model.trim().isNotEmpty ||
        profile.askingPrice > 0;
  }

  static int? _integerOrNull(String value) {
    return int.tryParse(value.trim());
  }

  static double _money(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
  }

  static String _moneyInput(double value) {
    return value == 0 ? '' : value.toStringAsFixed(2);
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.softPrimary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.car_rental_outlined, color: AppColors.primary, size: 32),
          SizedBox(height: 10),
          Text(
            'Vérifiez avant de vous engager',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'AutoClair rassemble les documents, l’inspection, l’essai et le budget. '
            'Il ne remplace pas une expertise mécanique indépendante.',
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.numeric = false,
  });

  final TextEditingController controller;
  final String label;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: false)
          : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _MoneyGrid extends StatelessWidget {
  const _MoneyGrid({
    required this.askingPriceController,
    required this.registrationCostController,
    required this.repairsController,
    required this.inspectionController,
    required this.budgetController,
  });

  final TextEditingController askingPriceController;
  final TextEditingController registrationCostController;
  final TextEditingController repairsController;
  final TextEditingController inspectionController;
  final TextEditingController budgetController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MoneyField(
                controller: askingPriceController,
                label: 'Prix demandé',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MoneyField(
                controller: registrationCostController,
                label: 'Carte grise estimée',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MoneyField(
                controller: repairsController,
                label: 'Travaux immédiats',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MoneyField(
                controller: inspectionController,
                label: 'Expertise / déplacement',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MoneyField(
          controller: budgetController,
          label: 'Budget maximum tout compris',
        ),
      ],
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
      decoration: InputDecoration(labelText: label, suffixText: '€'),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.danger = false,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      activeThumbColor: danger ? AppColors.error : AppColors.primary,
      onChanged: onChanged,
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onPressed,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPressed;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              value == null ? label : '$label : ${_formatDate(value!)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (value != null) ...[
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Effacer la date',
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
        ],
      ],
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.assessment, required this.onCopy});

  final UsedPurchaseAssessment assessment;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (assessment.decisionLevel) {
      PurchaseDecisionLevel.ready => (AppColors.successSoft, AppColors.success),
      PurchaseDecisionLevel.caution => (
        AppColors.warningSoft,
        AppColors.warning,
      ),
      PurchaseDecisionLevel.stop => (AppColors.errorSoft, AppColors.error),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: foreground.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, color: foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  assessment.decisionLevel.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: foreground),
                ),
              ),
              Text(
                '${assessment.score}/100',
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Metric(
                label: 'Coût total',
                value: _formatMoney(assessment.totalAcquisitionCost),
              ),
              _Metric(
                label: 'Marge budget',
                value: _formatMoney(assessment.remainingBudget),
              ),
              _Metric(
                label: 'Bloquants',
                value: assessment.blockingCount.toString(),
              ),
              _Metric(
                label: 'À vérifier',
                value: assessment.warningCount.toString(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in assessment.items) ...[
            _ChecklistLine(item: item),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copier le résumé'),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ChecklistLine extends StatelessWidget {
  const _ChecklistLine({required this.item});

  final PurchaseChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.level) {
      PurchaseCheckLevel.ready => AppColors.success,
      PurchaseCheckLevel.warning => AppColors.warning,
      PurchaseCheckLevel.blocking => AppColors.error,
      PurchaseCheckLevel.optional => AppColors.info,
    };
    final icon = switch (item.level) {
      PurchaseCheckLevel.ready => Icons.check_circle_outline,
      PurchaseCheckLevel.warning => Icons.warning_amber_outlined,
      PurchaseCheckLevel.blocking => Icons.block_outlined,
      PurchaseCheckLevel.optional => Icons.info_outline,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(item.detail),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfficialLinksCard extends StatelessWidget {
  const _OfficialLinksCard({
    required this.onHistovec,
    required this.onSimplimmat,
    required this.onRegistration,
  });

  final VoidCallback onHistovec;
  final VoidCallback onSimplimmat;
  final VoidCallback onRegistration;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Services officiels',
      icon: Icons.open_in_new_outlined,
      children: [
        const Text(
          'Utilisez uniquement les services officiels pour vérifier l’historique '
          'et préparer l’immatriculation.',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: onHistovec,
              child: const Text('HistoVec'),
            ),
            OutlinedButton(
              onPressed: onSimplimmat,
              child: const Text('Simplimmat'),
            ),
            OutlinedButton(
              onPressed: onRegistration,
              child: const Text('Immatriculation'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.snapshots});

  final List<UsedPurchaseSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Dernières évaluations',
      icon: Icons.history_outlined,
      children: [
        for (final snapshot in snapshots) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(snapshot.score.toString())),
            title: Text(
              [
                snapshot.make,
                snapshot.model,
              ].where((value) => value.trim().isNotEmpty).join(' '),
            ),
            subtitle: Text(
              '${snapshot.decisionLevel.label} · '
              '${_formatDate(snapshot.createdAt)}',
            ),
            trailing: Text(_formatMoney(snapshot.totalAcquisitionCost)),
          ),
          const Divider(),
        ],
      ],
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
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String _formatMoney(double value) => '${value.toStringAsFixed(2)} €';
