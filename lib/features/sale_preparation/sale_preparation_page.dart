import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'sale_listing_draft.dart';
import 'sale_listing_draft_card.dart';
import 'sale_preparation_calculator.dart';
import 'sale_preparation_models.dart';
import 'sale_preparation_service.dart';

class SalePreparationPage extends StatefulWidget {
  const SalePreparationPage({super.key});

  @override
  State<SalePreparationPage> createState() => _SalePreparationPageState();
}

class _SalePreparationPageState extends State<SalePreparationPage> {
  static final Uri _histovecUri = Uri.parse(
    'https://histovec.interieur.gouv.fr/',
  );
  static final Uri _franceTitresUri = Uri.parse(
    'https://immatriculation.ants.gouv.fr/home/help-contact/'
    'saledonation?lang=fr',
  );
  static final Uri _simplimmatUri = Uri.parse(
    'https://immatriculation.ants.gouv.fr/simplimmat?lang=fr',
  );

  final VehicleService _vehicleService = VehicleService();
  final SalePreparationService _service = SalePreparationService();

  final TextEditingController _askingPriceController = TextEditingController();
  final TextEditingController _minimumPriceController = TextEditingController();
  final TextEditingController _preparationCostController =
      TextEditingController();

  List<Vehicle> _vehicles = const [];
  String? _selectedVehicleId;
  SalePreparationContext? _context;
  List<SalePreparationSnapshot> _snapshots = const [];

  SaleBuyerType _buyerType = SaleBuyerType.privateIndividual;
  bool _ownsVehicle = true;
  bool _registrationAvailable = true;
  bool _coHoldersReady = true;
  DateTime? _technicalControlDate;
  SaleTechnicalControlStatus _technicalControlStatus =
      SaleTechnicalControlStatus.unknown;
  DateTime? _csaIssuedAt;
  bool _histovecShared = false;
  bool _invoicesAvailable = false;
  int _spareKeyCount = 1;
  SaleCessionMethod _cessionMethod = SaleCessionMethod.undecided;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  Vehicle? get _selectedVehicle {
    for (final vehicle in _vehicles) {
      if (vehicle.id == _selectedVehicleId) return vehicle;
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
    _askingPriceController.dispose();
    _minimumPriceController.dispose();
    _preparationCostController.dispose();
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
      if (_selectedVehicleId != null) {
        await _loadSelectedVehicle();
      }
    } on VehicleServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSelectedVehicle() async {
    final vehicle = _selectedVehicle;
    if (vehicle == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _service.loadProfile(vehicle.id),
        _service.loadContext(
          vehicleId: vehicle.id,
          currentMileage: vehicle.mileage,
        ),
        _service.loadRecentSnapshots(vehicle.id),
      ]);
      final profile =
          results[0] as SalePreparationProfile? ??
          SalePreparationProfile.defaults();
      if (!mounted || vehicle.id != _selectedVehicleId) return;
      _applyProfile(profile);
      setState(() {
        _context = results[1] as SalePreparationContext;
        _snapshots = results[2] as List<SalePreparationSnapshot>;
      });
    } on SalePreparationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyProfile(SalePreparationProfile profile) {
    _buyerType = profile.buyerType;
    _ownsVehicle = profile.ownsVehicle;
    _registrationAvailable = profile.registrationAvailable;
    _coHoldersReady = profile.coHoldersReady;
    _technicalControlDate = profile.technicalControlDate;
    _technicalControlStatus = profile.technicalControlStatus;
    _csaIssuedAt = profile.csaIssuedAt;
    _histovecShared = profile.histovecShared;
    _invoicesAvailable = profile.invoicesAvailable;
    _spareKeyCount = profile.spareKeyCount;
    _cessionMethod = profile.cessionMethod;
    _askingPriceController.text = _moneyInput(profile.askingPrice);
    _minimumPriceController.text = _moneyInput(profile.minimumPrice);
    _preparationCostController.text = _moneyInput(profile.preparationCost);
  }

  Future<void> _selectVehicle(String? vehicleId) async {
    if (vehicleId == null || vehicleId == _selectedVehicleId) return;
    setState(() {
      _selectedVehicleId = vehicleId;
      _context = null;
      _snapshots = const [];
    });
    await _loadSelectedVehicle();
  }

  SalePreparationProfile _profile() {
    return SalePreparationProfile(
      buyerType: _buyerType,
      askingPrice: _money(_askingPriceController.text),
      minimumPrice: _money(_minimumPriceController.text),
      preparationCost: _money(_preparationCostController.text),
      ownsVehicle: _ownsVehicle,
      registrationAvailable: _registrationAvailable,
      coHoldersReady: _coHoldersReady,
      technicalControlDate: _technicalControlDate,
      technicalControlStatus: _technicalControlStatus,
      csaIssuedAt: _csaIssuedAt,
      histovecShared: _histovecShared,
      invoicesAvailable: _invoicesAvailable,
      spareKeyCount: _spareKeyCount,
      cessionMethod: _cessionMethod,
    );
  }

  SalePreparationAssessment? get _assessment {
    final vehicle = _selectedVehicle;
    final context = _context;
    if (vehicle == null || context == null) return null;
    try {
      return SalePreparationCalculator.assess(
        vehicle: vehicle,
        profile: _profile(),
        context: context,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> _save() async {
    final vehicle = _selectedVehicle;
    final saleContext = _context;
    if (vehicle == null || saleContext == null) {
      setState(() => _error = 'Sélectionnez un véhicule.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = _profile();
      profile.validate();
      final assessment = SalePreparationCalculator.assess(
        vehicle: vehicle,
        profile: profile,
        context: saleContext,
      );
      await _service.saveProfile(vehicleId: vehicle.id, profile: profile);
      await _service.saveSnapshot(
        vehicleId: vehicle.id,
        profile: profile,
        assessment: assessment,
      );
      final snapshots = await _service.loadRecentSnapshots(vehicle.id);
      if (!mounted) return;
      setState(() => _snapshots = snapshots);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dossier de vente enregistré.')),
      );
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SalePreparationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copySummary() async {
    final vehicle = _selectedVehicle;
    final assessment = _assessment;
    if (vehicle == null || assessment == null) {
      setState(() {
        _error = 'Corrigez les montants avant de générer le résumé.';
      });
      return;
    }
    await Clipboard.setData(
      ClipboardData(
        text: assessment.buildShareSummary(
          vehicle: vehicle,
          profile: _profile(),
        ),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Résumé de vente copié.')));
  }

  Future<void> _showListingDraft() async {
    final vehicle = _selectedVehicle;
    final saleContext = _context;
    if (vehicle == null || saleContext == null) {
      setState(() => _error = 'Sélectionnez un véhicule.');
      return;
    }

    final draft = SaleListingDraftBuilder.build(
      vehicle: vehicle,
      profile: _profile(),
      saleContext: saleContext,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: SingleChildScrollView(
            child: SaleListingDraftCard(
              draft: draft,
              onCopyTitle: () =>
                  _copyListingText(draft.title, 'Titre de l’annonce copié.'),
              onCopyAll: () => _copyListingText(
                draft.buildCopyText(),
                'Brouillon de l’annonce copié.',
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyListingText(String text, String confirmation) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(confirmation)));
  }

  Future<void> _openOfficial(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le service officiel n’a pas pu être ouvert.'),
        ),
      );
    }
  }

  Future<void> _pickTechnicalControlDate() async {
    final result = await _pickDate(
      current: _technicalControlDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (result != null && mounted) {
      setState(() => _technicalControlDate = result);
    }
  }

  Future<void> _pickCsaDate() async {
    final result = await _pickDate(
      current: _csaIssuedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (result != null && mounted) {
      setState(() => _csaIssuedAt = result);
    }
  }

  Future<DateTime?> _pickDate({
    required DateTime? current,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: current ?? lastDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Choisir une date',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _selectedVehicle;
    final assessment = _assessment;
    return Scaffold(
      appBar: AppBar(title: const Text('Préparer ma vente')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              children: [
                const _SaleIntro(),
                const SizedBox(height: 16),
                if (_vehicles.isEmpty)
                  _EmptyVehicleCard(onAdd: () => context.push('/vehicles/new'))
                else ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedVehicleId),
                    initialValue: _selectedVehicleId,
                    decoration: const InputDecoration(labelText: 'Véhicule'),
                    items: _vehicles
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.displayName),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _saving ? null : _selectVehicle,
                  ),
                  const SizedBox(height: 16),
                  if (vehicle != null && _context != null)
                    _ExistingDataCard(vehicle: vehicle, saleContext: _context!),
                  const SizedBox(height: 16),
                  _PriceCard(
                    buyerType: _buyerType,
                    askingController: _askingPriceController,
                    minimumController: _minimumPriceController,
                    preparationController: _preparationCostController,
                    enabled: !_saving,
                    onBuyerTypeChanged: (value) {
                      if (value != null) {
                        setState(() => _buyerType = value);
                      }
                    },
                    onChanged: () => setState(() => _error = null),
                  ),
                  const SizedBox(height: 16),
                  _OwnershipCard(
                    ownsVehicle: _ownsVehicle,
                    registrationAvailable: _registrationAvailable,
                    coHoldersReady: _coHoldersReady,
                    enabled: !_saving,
                    onOwnsVehicleChanged: (value) =>
                        setState(() => _ownsVehicle = value),
                    onRegistrationChanged: (value) =>
                        setState(() => _registrationAvailable = value),
                    onCoHoldersChanged: (value) =>
                        setState(() => _coHoldersReady = value),
                  ),
                  const SizedBox(height: 16),
                  _TechnicalControlCard(
                    status: _technicalControlStatus,
                    date: _technicalControlDate,
                    enabled: !_saving,
                    onStatusChanged: (value) {
                      if (value != null) {
                        setState(() => _technicalControlStatus = value);
                      }
                    },
                    onPickDate: _pickTechnicalControlDate,
                    onClearDate: () =>
                        setState(() => _technicalControlDate = null),
                  ),
                  const SizedBox(height: 16),
                  _DocumentsCard(
                    csaDate: _csaIssuedAt,
                    histovecShared: _histovecShared,
                    invoicesAvailable: _invoicesAvailable,
                    spareKeyCount: _spareKeyCount,
                    cessionMethod: _cessionMethod,
                    enabled: !_saving,
                    onPickCsaDate: _pickCsaDate,
                    onClearCsaDate: () => setState(() => _csaIssuedAt = null),
                    onHistovecChanged: (value) =>
                        setState(() => _histovecShared = value),
                    onInvoicesChanged: (value) =>
                        setState(() => _invoicesAvailable = value),
                    onSpareKeyChanged: (value) {
                      if (value != null) {
                        setState(() => _spareKeyCount = value);
                      }
                    },
                    onCessionChanged: (value) {
                      if (value != null) {
                        setState(() => _cessionMethod = value);
                      }
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                  if (assessment != null) ...[
                    const SizedBox(height: 16),
                    _AssessmentCard(assessment: assessment),
                  ],
                  const SizedBox(height: 16),
                  _ListingDraftLauncher(onPressed: _showListingDraft),
                  const SizedBox(height: 16),
                  _OfficialServicesCard(
                    onHistovec: () => _openOfficial(_histovecUri),
                    onFranceTitres: () => _openOfficial(_franceTitresUri),
                    onSimplimmat: () => _openOfficial(_simplimmatUri),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _copySummary,
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copier le résumé du dossier'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Enregistrer cette préparation'),
                  ),
                  if (_snapshots.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Évaluations récentes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    for (final snapshot in _snapshots) ...[
                      _SnapshotCard(snapshot: snapshot),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ],
            ),
    );
  }

  static double _money(String value) {
    final normalized = value.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (normalized.isEmpty) return 0;
    return double.tryParse(normalized) ?? -1;
  }

  static String _moneyInput(double value) {
    if (value <= 0) return '';
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }
}

class _SaleIntro extends StatelessWidget {
  const _SaleIntro();

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
          Icon(Icons.sell_outlined, color: AppColors.primary, size: 34),
          SizedBox(height: 12),
          Text(
            'Préparez un dossier clair avant de rencontrer un acheteur.',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'AutoClair vérifie votre checklist et calcule le produit net '
            'attendu. Il ne fixe pas la valeur de marché et ne remplace pas '
            'les démarches officielles.',
          ),
        ],
      ),
    );
  }
}

class _ListingDraftLauncher extends StatelessWidget {
  const _ListingDraftLauncher({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.softPrimary,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Créer un brouillon d’annonce',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                const Text(
                  'AutoClair réutilise les informations déjà connues et '
                  'signale ce qu’il reste à compléter, sans inventer '
                  'l’état du véhicule ni sa valeur.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Préparer mon annonce'),
                ),
              ],
            ),
          ),
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
    return _SurfaceCard(
      child: Column(
        children: [
          const Icon(Icons.directions_car_outlined, size: 36),
          const SizedBox(height: 10),
          const Text('Ajoutez un véhicule pour préparer sa vente.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un véhicule'),
          ),
        ],
      ),
    );
  }
}

class _ExistingDataCard extends StatelessWidget {
  const _ExistingDataCard({required this.vehicle, required this.saleContext});

  final Vehicle vehicle;
  final SalePreparationContext saleContext;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Données déjà disponibles',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.speed_outlined,
            label: 'Kilométrage',
            value: vehicle.mileage == null
                ? 'À compléter'
                : '${vehicle.mileage} km',
          ),
          _InfoLine(
            icon: Icons.description_outlined,
            label: 'Documents analysés',
            value: saleContext.completedDocumentCount.toString(),
          ),
          _InfoLine(
            icon: Icons.history_outlined,
            label: 'Événements confirmés récents',
            value: saleContext.recentConfirmedEventCount.toString(),
          ),
          _InfoLine(
            icon: Icons.fact_check_outlined,
            label: 'Indice de préparation du carnet',
            value: '${saleContext.saleReadinessScore}/100',
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.buyerType,
    required this.askingController,
    required this.minimumController,
    required this.preparationController,
    required this.enabled,
    required this.onBuyerTypeChanged,
    required this.onChanged,
  });

  final SaleBuyerType buyerType;
  final TextEditingController askingController;
  final TextEditingController minimumController;
  final TextEditingController preparationController;
  final bool enabled;
  final ValueChanged<SaleBuyerType?> onBuyerTypeChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Objectif de vente',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<SaleBuyerType>(
            key: ValueKey(buyerType),
            initialValue: buyerType,
            decoration: const InputDecoration(labelText: 'Acheteur envisagé'),
            items: SaleBuyerType.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(growable: false),
            onChanged: enabled ? onBuyerTypeChanged : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: askingController,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Prix affiché',
              suffixText: '€',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: minimumController,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Prix minimum acceptable',
              suffixText: '€',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: preparationController,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Budget de préparation',
              hintText: 'Nettoyage, petite réparation, contrôle…',
              suffixText: '€',
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnershipCard extends StatelessWidget {
  const _OwnershipCard({
    required this.ownsVehicle,
    required this.registrationAvailable,
    required this.coHoldersReady,
    required this.enabled,
    required this.onOwnsVehicleChanged,
    required this.onRegistrationChanged,
    required this.onCoHoldersChanged,
  });

  final bool ownsVehicle;
  final bool registrationAvailable;
  final bool coHoldersReady;
  final bool enabled;
  final ValueChanged<bool> onOwnsVehicleChanged;
  final ValueChanged<bool> onRegistrationChanged;
  final ValueChanged<bool> onCoHoldersChanged;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Propriété et carte grise',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: ownsVehicle,
            onChanged: enabled ? onOwnsVehicleChanged : null,
            title: const Text('Je suis propriétaire du véhicule'),
            subtitle: const Text(
              'Décochez notamment pour une LOA ou un véhicule appartenant '
              'à un tiers.',
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: registrationAvailable,
            onChanged: enabled ? onRegistrationChanged : null,
            title: const Text('La carte grise complète est disponible'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: coHoldersReady,
            onChanged: enabled ? onCoHoldersChanged : null,
            title: const Text('Les cotitulaires pourront signer'),
          ),
        ],
      ),
    );
  }
}

class _TechnicalControlCard extends StatelessWidget {
  const _TechnicalControlCard({
    required this.status,
    required this.date,
    required this.enabled,
    required this.onStatusChanged,
    required this.onPickDate,
    required this.onClearDate,
  });

  final SaleTechnicalControlStatus status;
  final DateTime? date;
  final bool enabled;
  final ValueChanged<SaleTechnicalControlStatus?> onStatusChanged;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contrôle technique',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'AutoClair estime l’obligation à partir de l’année du véhicule. '
            'La date exacte de première mise en circulation reste la référence.',
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<SaleTechnicalControlStatus>(
            key: ValueKey(status),
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Résultat connu'),
            items: SaleTechnicalControlStatus.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(growable: false),
            onChanged: enabled ? onStatusChanged : null,
          ),
          const SizedBox(height: 12),
          _DateSelector(
            label: 'Date du procès-verbal',
            date: date,
            enabled: enabled,
            onPick: onPickDate,
            onClear: onClearDate,
          ),
        ],
      ),
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({
    required this.csaDate,
    required this.histovecShared,
    required this.invoicesAvailable,
    required this.spareKeyCount,
    required this.cessionMethod,
    required this.enabled,
    required this.onPickCsaDate,
    required this.onClearCsaDate,
    required this.onHistovecChanged,
    required this.onInvoicesChanged,
    required this.onSpareKeyChanged,
    required this.onCessionChanged,
  });

  final DateTime? csaDate;
  final bool histovecShared;
  final bool invoicesAvailable;
  final int spareKeyCount;
  final SaleCessionMethod cessionMethod;
  final bool enabled;
  final VoidCallback onPickCsaDate;
  final VoidCallback onClearCsaDate;
  final ValueChanged<bool> onHistovecChanged;
  final ValueChanged<bool> onInvoicesChanged;
  final ValueChanged<int?> onSpareKeyChanged;
  final ValueChanged<SaleCessionMethod?> onCessionChanged;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documents et remise',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          _DateSelector(
            label: 'Date du certificat de situation administrative',
            date: csaDate,
            enabled: enabled,
            onPick: onPickCsaDate,
            onClear: onClearCsaDate,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<SaleCessionMethod>(
            key: ValueKey(cessionMethod),
            initialValue: cessionMethod,
            decoration: const InputDecoration(
              labelText: 'Mode de déclaration prévu',
            ),
            items: SaleCessionMethod.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(growable: false),
            onChanged: enabled ? onCessionChanged : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey(spareKeyCount),
            initialValue: spareKeyCount,
            decoration: const InputDecoration(
              labelText: 'Nombre de clés remises',
            ),
            items: List.generate(
              11,
              (index) =>
                  DropdownMenuItem(value: index, child: Text(index.toString())),
            ),
            onChanged: enabled ? onSpareKeyChanged : null,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: histovecShared,
            onChanged: enabled ? onHistovecChanged : null,
            title: const Text('Rapport HistoVec prêt à partager'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: invoicesAvailable,
            onChanged: enabled ? onInvoicesChanged : null,
            title: const Text('Carnet et factures disponibles'),
          ),
        ],
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.assessment});

  final SalePreparationAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final color = assessment.blockingCount > 0
        ? AppColors.error
        : assessment.warningCount > 0
        ? AppColors.warning
        : AppColors.success;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  assessment.statusLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: color),
                ),
              ),
              Text(
                '${assessment.score}/100',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: assessment.score / 100,
            color: color,
            backgroundColor: AppColors.border,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricPill(
                label: 'Net au prix affiché',
                value: _euro(assessment.expectedNetAtAsking),
              ),
              _MetricPill(
                label: 'Net au prix minimum',
                value: _euro(assessment.expectedNetAtMinimum),
              ),
              _MetricPill(
                label: 'Marge de négociation',
                value: _euro(assessment.negotiationMargin),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final item in assessment.items) ...[
            _ChecklistRow(item: item),
            const Divider(height: 20),
          ],
        ],
      ),
    );
  }

  static String _euro(double value) => '${value.toStringAsFixed(0)} €';
}

class _OfficialServicesCard extends StatelessWidget {
  const _OfficialServicesCard({
    required this.onHistovec,
    required this.onFranceTitres,
    required this.onSimplimmat,
  });

  final VoidCallback onHistovec;
  final VoidCallback onFranceTitres;
  final VoidCallback onSimplimmat;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services officiels',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'AutoClair n’effectue pas la cession à votre place. Ouvrez les '
            'services de l’État pour générer et finaliser les documents.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onHistovec,
            icon: const Icon(Icons.history_outlined),
            label: const Text('Ouvrir HistoVec'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onSimplimmat,
            icon: const Icon(Icons.phone_android_outlined),
            label: const Text('Découvrir Simplimmat'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onFranceTitres,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Ouvrir France Titres'),
          ),
        ],
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.snapshot});

  final SalePreparationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.softPrimary,
            child: Text('${snapshot.score}'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_formatDate(snapshot.createdAt)} · '
              '${snapshot.blockingCount} blocage(s), '
              '${snapshot.warningCount} vigilance(s)',
            ),
          ),
          Text(
            '${snapshot.expectedNetAtAsking.toStringAsFixed(0)} €',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.label,
    required this.date,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? date;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Row(
        children: [
          Expanded(
            child: Text(date == null ? 'Non renseignée' : _formatDate(date!)),
          ),
          IconButton(
            onPressed: enabled ? onPick : null,
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Choisir',
          ),
          if (date != null)
            IconButton(
              onPressed: enabled ? onClear : null,
              icon: const Icon(Icons.close),
              tooltip: 'Effacer',
            ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item});

  final SaleChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.level) {
      SaleChecklistLevel.ready => (Icons.check_circle, AppColors.success),
      SaleChecklistLevel.warning => (Icons.warning_amber, AppColors.warning),
      SaleChecklistLevel.blocking => (Icons.cancel, AppColors.error),
      SaleChecklistLevel.optional => (Icons.lightbulb_outline, AppColors.info),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
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
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
