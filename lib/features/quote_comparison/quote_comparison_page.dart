import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/finance/money_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'quote_comparison_service.dart';
import 'quote_models.dart';

class QuoteComparisonPage extends StatefulWidget {
  const QuoteComparisonPage({super.key});

  @override
  State<QuoteComparisonPage> createState() => _QuoteComparisonPageState();
}

class _QuoteComparisonPageState extends State<QuoteComparisonPage> {
  final _service = QuoteComparisonService();
  final _vehicleService = VehicleService();

  List<QuoteDocumentOption> _documents = const [];
  List<Vehicle> _vehicles = const [];
  final Set<String> _selectedIds = <String>{};
  String? _vehicleId;
  QuoteComparisonResult? _comparison;
  bool _loading = true;
  bool _comparing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final documents = await _service.fetchQuoteDocuments();
      final vehicles = await _vehicleService.fetchVehicles();
      if (!mounted) return;
      setState(() {
        _documents = documents;
        _vehicles = vehicles;
        _vehicleId = vehicles.isEmpty
            ? null
            : vehicles
                  .firstWhere(
                    (vehicle) => vehicle.isPrimary,
                    orElse: () => vehicles.first,
                  )
                  .id;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is QuoteComparisonException
            ? error.message
            : error is VehicleServiceException
            ? error.message
            : "Les données nécessaires n'ont pas pu être chargées.";
        _loading = false;
      });
    }
  }

  void _toggleDocument(String id) {
    setState(() {
      _comparison = null;
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 3) {
        _selectedIds.add(id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous pouvez comparer trois devis maximum.'),
          ),
        );
      }
    });
  }

  Future<void> _compare() async {
    final selected = _documents
        .where((document) => _selectedIds.contains(document.id))
        .toList(growable: false);
    setState(() {
      _comparing = true;
      _error = null;
    });
    try {
      final result = await _service.compare(selected);
      if (!mounted) return;
      setState(() {
        _comparison = result;
        _comparing = false;
      });
    } on QuoteComparisonException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _comparing = false;
      });
    }
  }

  Future<void> _confirmChoice(QuoteSnapshot quote) async {
    final vehicleId = _vehicleId;
    final comparison = _comparison;
    if (vehicleId == null || comparison == null) {
      _show('Sélectionnez le véhicule concerné.');
      return;
    }
    try {
      await _service.confirmChoice(
        vehicleId: vehicleId,
        comparison: comparison,
        chosen: quote,
      );
      if (!mounted) return;
      _show('Choix confirmé et économie ajoutée au cockpit financier.');
    } on QuoteComparisonException catch (error) {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Comparer mes devis')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const _QuoteIntro(),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null) ...[
              _QuoteError(message: _error!, onRetry: _load),
              const SizedBox(height: 16),
            ],
            if (!_loading) ...[
              if (_documents.length < 2)
                _NoQuotes(onImport: () => context.push('/documents/new'))
              else ...[
                _DocumentSelector(
                  documents: _documents,
                  selectedIds: _selectedIds,
                  onToggle: _toggleDocument,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const ValueKey('quote-comparison-run'),
                  onPressed: _selectedIds.length >= 2 && !_comparing
                      ? _compare
                      : null,
                  icon: const Icon(Icons.compare_arrows),
                  label: Text(
                    _comparing
                        ? 'Comparaison…'
                        : 'Comparer les devis sélectionnés',
                  ),
                ),
              ],
            ],
            if (_comparison != null) ...[
              const SizedBox(height: 24),
              if (_vehicles.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _vehicleId,
                  decoration: const InputDecoration(
                    labelText: 'Véhicule concerné',
                  ),
                  items: _vehicles
                      .map(
                        (vehicle) => DropdownMenuItem(
                          value: vehicle.id,
                          child: Text(vehicle.displayName),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _vehicleId = value),
                ),
              const SizedBox(height: 16),
              _ComparisonSummary(comparison: _comparison!),
              const SizedBox(height: 16),
              _ComparisonTable(comparison: _comparison!),
              const SizedBox(height: 16),
              for (final quote in _comparison!.quotes) ...[
                _QuoteChoiceCard(
                  quote: quote,
                  reference:
                      quote.documentId == _comparison!.quotes.first.documentId,
                  onConfirm: () => _confirmChoice(quote),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _QuoteIntro extends StatelessWidget {
  const _QuoteIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.receipt_long_outlined, color: AppColors.info, size: 30),
          SizedBox(height: 10),
          Text(
            'Comparez des devis réellement reçus, ligne par ligne.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'AutoClair regroupe les formulations équivalentes, mais ne qualifie '
            'jamais un garage de trop cher sans base suffisamment robuste.',
          ),
        ],
      ),
    );
  }
}

class _DocumentSelector extends StatelessWidget {
  const _DocumentSelector({
    required this.documents,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<QuoteDocumentOption> documents;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choisissez 2 ou 3 devis',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final document in documents)
              CheckboxListTile(
                key: ValueKey('quote-document-${document.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(document.label),
                subtitle: Text(_formatDate(document.createdAt)),
                value: selectedIds.contains(document.id),
                onChanged: (_) => onToggle(document.id),
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

class _ComparisonSummary extends StatelessWidget {
  const _ComparisonSummary({required this.comparison});

  final QuoteComparisonResult comparison;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.successSoft,
              child: Icon(Icons.savings_outlined, color: AppColors.success),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Écart total observé',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    MoneyFormatter.euros(comparison.totalGap),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.comparison});

  final QuoteComparisonResult comparison;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Opération')),
              for (final quote in comparison.quotes)
                DataColumn(label: Text(quote.providerName)),
            ],
            rows: [
              for (final category in comparison.categories)
                DataRow(
                  cells: [
                    DataCell(Text(category)),
                    for (final quote in comparison.quotes)
                      DataCell(
                        Text(
                          quote.totalsByCategory.containsKey(category)
                              ? MoneyFormatter.euros(
                                  quote.totalsByCategory[category]!,
                                )
                              : '—',
                        ),
                      ),
                  ],
                ),
              DataRow(
                cells: [
                  const DataCell(
                    Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  for (final quote in comparison.quotes)
                    DataCell(
                      Text(
                        MoneyFormatter.euros(quote.total),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteChoiceCard extends StatelessWidget {
  const _QuoteChoiceCard({
    required this.quote,
    required this.reference,
    required this.onConfirm,
  });

  final QuoteSnapshot quote;
  final bool reference;
  final VoidCallback onConfirm;

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
                    quote.providerName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (reference) const Chip(label: Text('Référence')),
              ],
            ),
            Text(quote.label),
            const SizedBox(height: 10),
            Text(
              MoneyFormatter.euros(quote.total),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Confiance d’extraction : ${(quote.confidence * 100).round()} %',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!reference) ...[
              const SizedBox(height: 14),
              FilledButton.tonal(
                onPressed: onConfirm,
                child: const Text('Je choisis ce devis'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoQuotes extends StatelessWidget {
  const _NoQuotes({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Deux devis analysés sont nécessaires pour lancer une comparaison.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Importer un devis'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteError extends StatelessWidget {
  const _QuoteError({required this.message, required this.onRetry});

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
