import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/finance/money_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'insurance_models.dart';
import 'insurance_review_service.dart';

class InsuranceReviewPage extends StatefulWidget {
  const InsuranceReviewPage({super.key});

  @override
  State<InsuranceReviewPage> createState() => _InsuranceReviewPageState();
}

class _InsuranceReviewPageState extends State<InsuranceReviewPage> {
  final _vehicleService = VehicleService();
  final _service = InsuranceReviewService();

  List<Vehicle> _vehicles = const [];
  List<InsuranceSnapshot> _snapshots = const [];
  String? _vehicleId;
  String? _previousId;
  String? _currentId;
  bool _loading = true;
  String? _error;

  InsuranceSnapshot? get _previous => _byId(_previousId);
  InsuranceSnapshot? get _current => _byId(_currentId);

  InsuranceSnapshot? _byId(String? id) {
    if (id == null) return null;
    for (final snapshot in _snapshots) {
      if (snapshot.id == id) return snapshot;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadVehicles();
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
      await _loadSnapshots();
    } on VehicleServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadSnapshots() async {
    final vehicleId = _vehicleId;
    if (vehicleId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snapshots = await _service.fetchSnapshots(vehicleId);
      if (!mounted) return;
      setState(() {
        _snapshots = snapshots;
        _currentId = snapshots.isEmpty ? null : snapshots.first.id;
        _previousId = snapshots.length < 2 ? null : snapshots[1].id;
        _loading = false;
      });
    } on InsuranceReviewException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _changeVehicle(String? value) async {
    if (value == null) return;
    setState(() {
      _vehicleId = value;
      _snapshots = const [];
      _currentId = null;
      _previousId = null;
    });
    await _loadSnapshots();
  }

  Future<void> _addSnapshot() async {
    final vehicleId = _vehicleId;
    if (vehicleId == null) return;
    final draft = await showModalBottomSheet<_InsuranceDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _InsuranceEditor(),
    );
    if (draft == null) return;
    try {
      await _service.addManualSnapshot(
        vehicleId: vehicleId,
        providerName: draft.providerName,
        annualPremium: draft.annualPremium,
        snapshotDate: draft.snapshotDate,
        expiryDate: draft.expiryDate,
        deductible: draft.deductible,
        assistanceZeroKm: draft.assistanceZeroKm,
        replacementVehicle: draft.replacementVehicle,
        contractNumber: draft.contractNumber,
        guarantees: draft.guarantees,
      );
      if (!mounted) return;
      _show('Informations d’assurance enregistrées.');
      await _loadSnapshots();
    } on InsuranceReviewException catch (error) {
      if (!mounted) return;
      _show(error.message);
    }
  }

  Future<void> _confirmSaving() async {
    final vehicleId = _vehicleId;
    final previous = _previous;
    final current = _current;
    if (vehicleId == null || previous == null || current == null) return;
    try {
      await _service.confirmSaving(
        vehicleId: vehicleId,
        previous: previous,
        selected: current,
      );
      if (!mounted) return;
      _show('Économie annuelle ajoutée au cockpit financier.');
    } on InsuranceReviewException catch (error) {
      if (!mounted) return;
      _show(error.message);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final previous = _previous;
    final current = _current;
    final review = previous != null && current != null
        ? InsuranceReviewResult(previous: previous, current: current)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Réviser mon assurance')),
      floatingActionButton: _vehicleId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addSnapshot,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un contrat'),
            ),
      body: RefreshIndicator(
        onRefresh: _loadSnapshots,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            const _InsuranceIntro(),
            const SizedBox(height: 16),
            if (_vehicles.isNotEmpty)
              DropdownButtonFormField<String>(
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
                onChanged: _changeVehicle,
              ),
            if (_loading) ...[
              const SizedBox(height: 40),
              const Center(child: CircularProgressIndicator()),
            ] else if (_vehicles.isEmpty) ...[
              const SizedBox(height: 20),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Ajoutez un véhicule pour suivre son assurance.'),
                ),
              ),
            ] else if (_error != null) ...[
              const SizedBox(height: 20),
              _InsuranceError(message: _error!, onRetry: _loadSnapshots),
            ] else if (_snapshots.isEmpty) ...[
              const SizedBox(height: 20),
              _NoInsuranceData(
                onAdd: _addSnapshot,
                onImport: () => context.push('/documents/new'),
              ),
            ] else ...[
              const SizedBox(height: 20),
              _SnapshotSelectors(
                snapshots: _snapshots,
                previousId: _previousId,
                currentId: _currentId,
                onPreviousChanged: (value) =>
                    setState(() => _previousId = value),
                onCurrentChanged: (value) => setState(() => _currentId = value),
              ),
              if (review != null) ...[
                const SizedBox(height: 18),
                _InsuranceReviewCard(review: review),
                const SizedBox(height: 14),
                _GuaranteeChanges(review: review),
                if (review.current.annualPremium <
                    review.previous.annualPremium) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _confirmSaving,
                    icon: const Icon(Icons.savings_outlined),
                    label: const Text('Confirmer cette économie annuelle'),
                  ),
                ],
              ],
              const SizedBox(height: 18),
              for (final snapshot in _snapshots) ...[
                _InsuranceSnapshotCard(snapshot: snapshot),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _InsuranceIntro extends StatelessWidget {
  const _InsuranceIntro();

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
          Icon(Icons.shield_outlined, color: AppColors.primary, size: 30),
          SizedBox(height: 10),
          Text(
            'Comparez l’évolution de votre prime, de vos franchises et de vos garanties.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Cette première version informe et prépare votre décision. Elle ne '
            'vend pas de contrat et ne remplace pas un intermédiaire autorisé.',
          ),
        ],
      ),
    );
  }
}

class _SnapshotSelectors extends StatelessWidget {
  const _SnapshotSelectors({
    required this.snapshots,
    required this.previousId,
    required this.currentId,
    required this.onPreviousChanged,
    required this.onCurrentChanged,
  });

  final List<InsuranceSnapshot> snapshots;
  final String? previousId;
  final String? currentId;
  final ValueChanged<String?> onPreviousChanged;
  final ValueChanged<String?> onCurrentChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: previousId,
              decoration: const InputDecoration(labelText: 'Ancien contrat'),
              items: snapshots
                  .map(
                    (snapshot) => DropdownMenuItem(
                      value: snapshot.id,
                      child: Text(snapshot.displayLabel),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onPreviousChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: currentId,
              decoration: const InputDecoration(
                labelText: 'Contrat actuel ou offre',
              ),
              items: snapshots
                  .map(
                    (snapshot) => DropdownMenuItem(
                      value: snapshot.id,
                      child: Text(snapshot.displayLabel),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onCurrentChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _InsuranceReviewCard extends StatelessWidget {
  const _InsuranceReviewCard({required this.review});

  final InsuranceReviewResult review;

  @override
  Widget build(BuildContext context) {
    final change = review.premiumChange;
    final color = change > 0 ? AppColors.error : AppColors.success;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Évolution de la prime',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    change > 0 ? 'Augmentation annuelle' : 'Baisse annuelle',
                  ),
                ),
                Text(
                  '${change > 0 ? '+' : ''}${MoneyFormatter.euros(change)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${review.premiumChangePercent >= 0 ? '+' : ''}'
              '${review.premiumChangePercent.toStringAsFixed(1)} %',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            if (review.deductibleChange != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(child: Text('Évolution de la franchise')),
                  Text(
                    '${review.deductibleChange! >= 0 ? '+' : ''}'
                    '${MoneyFormatter.euros(review.deductibleChange!)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuaranteeChanges extends StatelessWidget {
  const _GuaranteeChanges({required this.review});

  final InsuranceReviewResult review;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Garanties', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (review.addedGuarantees.isEmpty &&
                review.removedGuarantees.isEmpty)
              const Text(
                'Aucun changement détecté dans les garanties renseignées.',
              )
            else ...[
              for (final guarantee in review.addedGuarantees)
                _ChangeLine(
                  icon: Icons.add_circle_outline,
                  color: AppColors.success,
                  text: guarantee,
                ),
              for (final guarantee in review.removedGuarantees)
                _ChangeLine(
                  icon: Icons.remove_circle_outline,
                  color: AppColors.error,
                  text: guarantee,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangeLine extends StatelessWidget {
  const _ChangeLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _InsuranceSnapshotCard extends StatelessWidget {
  const _InsuranceSnapshotCard({required this.snapshot});

  final InsuranceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    snapshot.providerName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  MoneyFormatter.euros(snapshot.annualPremium),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Relevé du ${_formatDate(snapshot.snapshotDate)}'),
            if (snapshot.expiryDate != null)
              Text('Échéance : ${_formatDate(snapshot.expiryDate!)}'),
            if (snapshot.deductible != null)
              Text('Franchise : ${MoneyFormatter.euros(snapshot.deductible!)}'),
            if (snapshot.contractNumberMasked != null)
              Text('Contrat : ${snapshot.contractNumberMasked}'),
            if (snapshot.guarantees.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: snapshot.guarantees
                    .map((guarantee) => Chip(label: Text(guarantee)))
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _NoInsuranceData extends StatelessWidget {
  const _NoInsuranceData({required this.onAdd, required this.onImport});

  final VoidCallback onAdd;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Ajoutez votre prime actuelle ou importez un avis d’échéance analysé.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onAdd,
              child: const Text('Saisir un contrat'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onImport,
              child: const Text('Importer un document'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsuranceEditor extends StatefulWidget {
  const _InsuranceEditor();

  @override
  State<_InsuranceEditor> createState() => _InsuranceEditorState();
}

class _InsuranceEditorState extends State<_InsuranceEditor> {
  final _providerController = TextEditingController();
  final _premiumController = TextEditingController();
  final _deductibleController = TextEditingController();
  final _contractController = TextEditingController();
  final _guaranteesController = TextEditingController();
  final DateTime _snapshotDate = DateTime.now();
  DateTime? _expiryDate;
  String _assistanceChoice = 'UNKNOWN';
  String _replacementChoice = 'UNKNOWN';

  @override
  void dispose() {
    _providerController.dispose();
    _premiumController.dispose();
    _deductibleController.dispose();
    _contractController.dispose();
    _guaranteesController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (result != null) setState(() => _expiryDate = result);
  }

  void _submit() {
    final provider = _providerController.text.trim();
    final premium = double.tryParse(
      _premiumController.text.trim().replaceAll(',', '.'),
    );
    if (provider.isEmpty || premium == null || premium < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Précisez l’assureur et une prime valide.'),
        ),
      );
      return;
    }
    final deductible = double.tryParse(
      _deductibleController.text.trim().replaceAll(',', '.'),
    );
    final guarantees = _guaranteesController.text
        .split(RegExp(r'[,;\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    Navigator.of(context).pop(
      _InsuranceDraft(
        providerName: provider,
        annualPremium: premium,
        deductible: deductible,
        snapshotDate: _snapshotDate,
        expiryDate: _expiryDate,
        assistanceZeroKm: _choiceToBool(_assistanceChoice),
        replacementVehicle: _choiceToBool(_replacementChoice),
        contractNumber: _contractController.text.trim(),
        guarantees: guarantees,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajouter un contrat',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _providerController,
              decoration: const InputDecoration(labelText: 'Assureur'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _premiumController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Prime annuelle (€)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deductibleController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Franchise principale (€)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contractController,
              decoration: const InputDecoration(
                labelText: 'Numéro de contrat (masqué après saisie)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _guaranteesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Garanties séparées par des virgules',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _assistanceChoice,
              decoration: const InputDecoration(
                labelText: 'Assistance zéro km',
              ),
              items: const [
                DropdownMenuItem(value: 'UNKNOWN', child: Text('Non précisé')),
                DropdownMenuItem(value: 'YES', child: Text('Incluse')),
                DropdownMenuItem(value: 'NO', child: Text('Non incluse')),
              ],
              onChanged: (value) =>
                  setState(() => _assistanceChoice = value ?? 'UNKNOWN'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _replacementChoice,
              decoration: const InputDecoration(
                labelText: 'Véhicule de remplacement',
              ),
              items: const [
                DropdownMenuItem(value: 'UNKNOWN', child: Text('Non précisé')),
                DropdownMenuItem(value: 'YES', child: Text('Inclus')),
                DropdownMenuItem(value: 'NO', child: Text('Non inclus')),
              ],
              onChanged: (value) =>
                  setState(() => _replacementChoice = value ?? 'UNKNOWN'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickExpiry,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                _expiryDate == null
                    ? 'Ajouter la date d’échéance'
                    : 'Échéance : ${_formatDate(_expiryDate!)}',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }

  static bool? _choiceToBool(String value) {
    if (value == 'YES') return true;
    if (value == 'NO') return false;
    return null;
  }

  static String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}

class _InsuranceDraft {
  const _InsuranceDraft({
    required this.providerName,
    required this.annualPremium,
    required this.snapshotDate,
    required this.guarantees,
    this.deductible,
    this.expiryDate,
    this.assistanceZeroKm,
    this.replacementVehicle,
    this.contractNumber,
  });

  final String providerName;
  final double annualPremium;
  final double? deductible;
  final DateTime snapshotDate;
  final DateTime? expiryDate;
  final bool? assistanceZeroKm;
  final bool? replacementVehicle;
  final String? contractNumber;
  final List<String> guarantees;
}

class _InsuranceError extends StatelessWidget {
  const _InsuranceError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
