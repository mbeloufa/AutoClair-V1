import 'package:flutter/material.dart';

import '../../core/finance/money_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'vehicle_budget_models.dart';
import 'vehicle_budget_service.dart';

class VehicleBudgetPage extends StatefulWidget {
  const VehicleBudgetPage({super.key});

  @override
  State<VehicleBudgetPage> createState() => _VehicleBudgetPageState();
}

class _VehicleBudgetPageState extends State<VehicleBudgetPage> {
  final _vehicleService = VehicleService();
  final _budgetService = VehicleBudgetService();

  List<Vehicle> _vehicles = const [];
  String? _vehicleId;
  VehicleBudgetSummary? _summary;
  bool _loading = true;
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

  Future<void> _loadVehicles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vehicles = await _vehicleService.fetchVehicles();
      if (!mounted) return;
      final selected = vehicles.firstWhere(
        (vehicle) => vehicle.isPrimary,
        orElse: () => vehicles.isEmpty
            ? throw const _NoVehicleException()
            : vehicles.first,
      );
      setState(() {
        _vehicles = vehicles;
        _vehicleId = selected.id;
      });
      await _loadSummary();
    } on _NoVehicleException {
      if (!mounted) return;
      setState(() {
        _vehicles = const [];
        _vehicleId = null;
        _summary = null;
        _loading = false;
      });
    } on VehicleServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadSummary() async {
    final vehicle = _selectedVehicle;
    if (vehicle == null) {
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
      final summary = await _budgetService.loadSummary(
        vehicleId: vehicle.id,
        currentMileage: vehicle.mileage,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } on VehicleBudgetException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _changeVehicle(String? vehicleId) async {
    if (vehicleId == null || vehicleId == _vehicleId) return;
    setState(() {
      _vehicleId = vehicleId;
      _summary = null;
    });
    await _loadSummary();
  }

  Future<void> _addExpense() async {
    final vehicle = _selectedVehicle;
    if (vehicle == null) return;

    final result = await showModalBottomSheet<_ExpenseDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _ExpenseEditor(),
    );
    if (result == null) return;

    try {
      await _budgetService.addExpense(
        vehicleId: vehicle.id,
        category: result.category,
        subcategory: result.subcategory,
        amount: result.amount,
        date: result.date,
        mileage: result.mileage,
        note: result.note,
        recurring: result.recurring,
        recurrenceMonths: result.recurrenceMonths,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dépense ajoutée au budget.')),
      );
      await _loadSummary();
    } on Object catch (error) {
      if (!mounted) return;
      final message = error is VehicleBudgetException
          ? error.message
          : "La dépense n'a pas pu être ajoutée.";
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon budget automobile')),
      floatingActionButton: _selectedVehicle == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addExpense,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une dépense'),
            ),
      body: RefreshIndicator(
        onRefresh: _loadSummary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            const _BudgetIntro(),
            const SizedBox(height: 16),
            if (_vehicles.isNotEmpty)
              DropdownButtonFormField<String>(
                key: const ValueKey('budget-vehicle-selector'),
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
              const _EmptyBudget(),
            ] else if (_error != null) ...[
              const SizedBox(height: 20),
              _ErrorCard(message: _error!, onRetry: _loadSummary),
            ] else if (_summary != null) ...[
              const SizedBox(height: 20),
              _BudgetSummaryGrid(summary: _summary!),
              const SizedBox(height: 20),
              _SavingsCard(summary: _summary!),
              const SizedBox(height: 20),
              _BreakdownCard(summary: _summary!),
              const SizedBox(height: 20),
              _RecentExpenses(entries: _summary!.entries),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetIntro extends StatelessWidget {
  const _BudgetIntro();

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
          Icon(Icons.savings_outlined, color: AppColors.primary, size: 30),
          SizedBox(height: 12),
          Text(
            'Visualisez ce que votre voiture vous coûte réellement.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Les économies potentielles restent séparées des économies '
            'réellement confirmées.',
          ),
        ],
      ),
    );
  }
}

class _BudgetSummaryGrid extends StatelessWidget {
  const _BudgetSummaryGrid({required this.summary});

  final VehicleBudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              width: width,
              title: '12 derniers mois',
              value: MoneyFormatter.compactEuros(summary.totalLast12Months),
              icon: Icons.calendar_month_outlined,
            ),
            _MetricCard(
              width: width,
              title: 'Moyenne mensuelle',
              value: MoneyFormatter.compactEuros(summary.monthlyAverage),
              icon: Icons.auto_graph_outlined,
            ),
            _MetricCard(
              width: width,
              title: 'Coût au kilomètre',
              value: summary.costPerKm == null
                  ? 'À calculer'
                  : '${summary.costPerKm!.toStringAsFixed(2)} €/km',
              icon: Icons.route_outlined,
            ),
            _MetricCard(
              width: width,
              title: 'Dépenses suivies',
              value: '${summary.entries.length}',
              icon: Icons.receipt_long_outlined,
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
  });

  final double width;
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavingsCard extends StatelessWidget {
  const _SavingsCard({required this.summary});

  final VehicleBudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Économies AutoClair',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _SavingLine(
              label: 'Confirmées',
              amount: summary.confirmedSavings,
              color: AppColors.success,
            ),
            const SizedBox(height: 10),
            _SavingLine(
              label: 'Encore possibles',
              amount: summary.potentialSavings,
              color: AppColors.warning,
            ),
            if (summary.opportunities.isEmpty) ...[
              const SizedBox(height: 14),
              Text(
                "Les économies détectées par l'optimiseur de plein, les devis "
                "et l'assurance apparaîtront ici.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SavingLine extends StatelessWidget {
  const _SavingLine({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        Text(
          MoneyFormatter.euros(amount),
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.summary});

  final VehicleBudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final rows = summary.byCategory.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Répartition', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              const Text(
                'Aucune dépense enregistrée sur les douze derniers mois.',
              )
            else
              for (final row in rows) ...[
                _BreakdownLine(
                  label: _categoryLabel(row.key),
                  amount: row.value,
                  total: summary.totalLast12Months,
                ),
                if (row != rows.last) const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  static String _categoryLabel(String value) => switch (value.toUpperCase()) {
    'FUEL' => 'Carburant',
    'CHARGING' => 'Recharge',
    'MAINTENANCE' => 'Entretien',
    'REPAIR' => 'Réparation',
    'INSURANCE' => 'Assurance',
    'TECHNICAL_CONTROL' => 'Contrôle technique',
    'PARKING' => 'Parking',
    'TOLL' => 'Péage',
    'ACCESSORIES' => 'Accessoires',
    _ => 'Autre',
  };
}

class _BreakdownLine extends StatelessWidget {
  const _BreakdownLine({
    required this.label,
    required this.amount,
    required this.total,
  });

  final String label;
  final double amount;
  final double total;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : (amount / total).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(MoneyFormatter.euros(amount)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: AppColors.border,
        ),
      ],
    );
  }
}

class _RecentExpenses extends StatelessWidget {
  const _RecentExpenses({required this.entries});

  final List<VehicleCostEntry> entries;

  @override
  Widget build(BuildContext context) {
    final visible = entries.take(10).toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dernières dépenses',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (visible.isEmpty)
              const Text('Ajoutez une première dépense pour démarrer le suivi.')
            else
              for (final entry in visible)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.softPrimary,
                    child: Icon(Icons.euro, color: AppColors.primary),
                  ),
                  title: Text(entry.subcategory),
                  subtitle: Text(
                    '${entry.categoryLabel} · ${_formatDate(entry.eventDate)}',
                  ),
                  trailing: Text(
                    MoneyFormatter.euros(entry.amount),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
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

class _EmptyBudget extends StatelessWidget {
  const _EmptyBudget();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Ajoutez un véhicule pour suivre son coût automobile.'),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _ExpenseEditor extends StatefulWidget {
  const _ExpenseEditor();

  @override
  State<_ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends State<_ExpenseEditor> {
  final _formKey = GlobalKey<FormState>();
  final _subcategoryController = TextEditingController();
  final _amountController = TextEditingController();
  final _mileageController = TextEditingController();
  final _noteController = TextEditingController();
  String _category = 'MAINTENANCE';
  final DateTime _date = DateTime.now();
  bool _recurring = false;
  int _recurrenceMonths = 12;

  @override
  void dispose() {
    _subcategoryController.dispose();
    _amountController.dispose();
    _mileageController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    final mileage = int.tryParse(_mileageController.text.trim());
    Navigator.of(context).pop(
      _ExpenseDraft(
        category: _category,
        subcategory: _subcategoryController.text.trim(),
        amount: amount,
        mileage: mileage,
        note: _noteController.text.trim(),
        date: _date,
        recurring: _recurring,
        recurrenceMonths: _recurring ? _recurrenceMonths : null,
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajouter une dépense',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: const [
                  DropdownMenuItem(value: 'FUEL', child: Text('Carburant')),
                  DropdownMenuItem(value: 'CHARGING', child: Text('Recharge')),
                  DropdownMenuItem(
                    value: 'MAINTENANCE',
                    child: Text('Entretien'),
                  ),
                  DropdownMenuItem(value: 'REPAIR', child: Text('Réparation')),
                  DropdownMenuItem(
                    value: 'INSURANCE',
                    child: Text('Assurance'),
                  ),
                  DropdownMenuItem(
                    value: 'TECHNICAL_CONTROL',
                    child: Text('Contrôle technique'),
                  ),
                  DropdownMenuItem(value: 'PARKING', child: Text('Parking')),
                  DropdownMenuItem(value: 'TOLL', child: Text('Péage')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Autre')),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subcategoryController,
                decoration: const InputDecoration(labelText: 'Libellé'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Précisez la dépense.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Montant TTC (€)'),
                validator: (value) {
                  final amount = double.tryParse(
                    value?.trim().replaceAll(',', '.') ?? '',
                  );
                  return amount == null || amount < 0
                      ? 'Saisissez un montant valide.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mileageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kilométrage (facultatif)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (facultatif)',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dépense récurrente'),
                value: _recurring,
                onChanged: (value) => setState(() => _recurring = value),
              ),
              if (_recurring)
                DropdownButtonFormField<int>(
                  initialValue: _recurrenceMonths,
                  decoration: const InputDecoration(labelText: 'Fréquence'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Tous les mois')),
                    DropdownMenuItem(value: 3, child: Text('Tous les 3 mois')),
                    DropdownMenuItem(value: 6, child: Text('Tous les 6 mois')),
                    DropdownMenuItem(value: 12, child: Text('Tous les ans')),
                  ],
                  onChanged: (value) => setState(
                    () => _recurrenceMonths = value ?? _recurrenceMonths,
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseDraft {
  const _ExpenseDraft({
    required this.category,
    required this.subcategory,
    required this.amount,
    required this.date,
    required this.recurring,
    this.mileage,
    this.note,
    this.recurrenceMonths,
  });

  final String category;
  final String subcategory;
  final double amount;
  final DateTime date;
  final bool recurring;
  final int? mileage;
  final String? note;
  final int? recurrenceMonths;
}

class _NoVehicleException implements Exception {
  const _NoVehicleException();
}
