import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../vehicle_care/vehicle_event_catalog.dart';
import 'document_analysis_result.dart';
import 'contract_document_analysis_card.dart';
import 'document_analysis_service.dart';
import 'document_carnet_sync_result.dart';
import 'service_document_analysis_card.dart';
import 'technical_inspection_analysis_card.dart';

class AnalysisResultPage extends StatefulWidget {
  const AnalysisResultPage({required this.documentId, super.key});

  final String documentId;

  @override
  State<AnalysisResultPage> createState() => _AnalysisResultPageState();
}

class _AnalysisResultPageState extends State<AnalysisResultPage> {
  final _service = DocumentAnalysisService();

  DocumentAnalysisResult? _result;
  DocumentCarnetSyncResult? _carnetSync;
  String? _errorMessage;
  String? _carnetSyncError;
  bool _loading = true;
  bool _syncingCarnet = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _carnetSyncError = null;
    });

    try {
      final result = await _service.fetchAnalysis(widget.documentId);
      if (!mounted) return;
      setState(() => _result = result);
      if (result.supportsCarnetSync) {
        await _syncCarnet();
      }
    } on DocumentAnalysisException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncCarnet() async {
    if (_syncingCarnet) return;
    setState(() {
      _syncingCarnet = true;
      _carnetSyncError = null;
    });

    try {
      final sync = await _service.syncDocumentToCarnet(widget.documentId);
      if (mounted) setState(() => _carnetSync = sync);
    } on DocumentAnalysisException catch (error) {
      if (mounted) setState(() => _carnetSyncError = error.message);
    } finally {
      if (mounted) setState(() => _syncingCarnet = false);
    }
  }

  Future<void> _confirmCarnetEvent() async {
    final result = _result;
    if (result == null || _syncingCarnet) return;

    final operation = result.detectedOperation;
    final details = await showModalBottomSheet<_OperationConfirmationData>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _OperationConfirmationSheet(operation: operation),
    );
    if (details == null || !mounted) return;

    setState(() {
      _syncingCarnet = true;
      _carnetSyncError = null;
    });

    try {
      final confirmed = await _service.confirmDocumentCarnetEvent(
        widget.documentId,
        mileage: details.mileage,
        amount: details.amount,
        categoryCode: details.categoryCode,
        subcategoryCode: details.subcategoryCode,
      );
      if (!mounted) return;
      setState(() => _carnetSync = confirmed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${operation.title} ajouté au carnet.')),
      );
    } on DocumentAnalysisException catch (error) {
      if (mounted) setState(() => _carnetSyncError = error.message);
    } finally {
      if (mounted) setState(() => _syncingCarnet = false);
    }
  }

  void _openVehicleCarnet() {
    final vehicleId = _carnetSync?.vehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;
    context.push<void>('/vehicles/$vehicleId/care?section=timeline');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultat de l’analyse'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _result == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _result == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 54,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final result = _result!;
    final operation = result.detectedOperation;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          _OperationHero(result: result, operation: operation),
          if (result.isTechnicalInspection) ...[
            const SizedBox(height: 14),
            TechnicalInspectionAnalysisCard(result: result),
          ],
          if (ServiceDocumentAnalysisCard.supports(result)) ...[
            const SizedBox(height: 14),
            ServiceDocumentAnalysisCard(result: result),
          ],
          if (ContractDocumentAnalysisCard.supports(result)) ...[
            const SizedBox(height: 14),
            ContractDocumentAnalysisCard(result: result),
          ],
          if (result.supportsCarnetSync) ...[
            const SizedBox(height: 14),
            _CarnetOperationCard(
              operation: operation,
              sync: _carnetSync,
              loading: _syncingCarnet,
              errorMessage: _carnetSyncError,
              onConfirm: _confirmCarnetEvent,
              onOpenCarnet: _openVehicleCarnet,
              onRetry: _syncCarnet,
            ),
          ],
          if (!result.isContractDocument) ...[
            const SizedBox(height: 14),
            _UsefulDetailsCard(result: result, operation: operation),
          ],
          if (!ServiceDocumentAnalysisCard.supports(result) &&
              result.objectListAt('line_items').isNotEmpty) ...[
            const SizedBox(height: 14),
            _OperationsListCard(result: result),
          ],
          if (result.usefulObservations.isNotEmpty ||
              result.usefulQuestions.isNotEmpty) ...[
            const SizedBox(height: 14),
            _OptionalAdviceCard(result: result),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => context.go('/history'),
            icon: const Icon(Icons.folder_outlined),
            label: const Text('Mes documents'),
          ),
          const SizedBox(height: 8),
          Text(
            'AutoClair utilise uniquement les informations utiles à l’analyse. '
            'Le nom et les coordonnées du particulier ne sont pas affichés.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _OperationHero extends StatelessWidget {
  const _OperationHero({required this.result, required this.operation});

  final DocumentAnalysisResult result;
  final DetectedVehicleOperation operation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.isContractDocument
                      ? 'Document expliqué'
                      : operation.heading,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            result.isContractDocument
                ? result.detectedTypeLabel
                : operation.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            result.isContractDocument
                ? 'Engagements, coûts et clauses à vérifier'
                : operation.categoryPath,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroTag(label: result.detectedTypeLabel),
              _HeroTag(label: 'Lisibilité ${result.readabilityLabel}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CarnetOperationCard extends StatelessWidget {
  const _CarnetOperationCard({
    required this.operation,
    required this.sync,
    required this.loading,
    required this.errorMessage,
    required this.onConfirm,
    required this.onOpenCarnet,
    required this.onRetry,
  });

  final DetectedVehicleOperation operation;
  final DocumentCarnetSyncResult? sync;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onConfirm;
  final VoidCallback onOpenCarnet;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading && sync == null) {
      return const _SimpleCard(
        icon: Icons.sync_rounded,
        title: 'Mise à jour du carnet…',
        message: 'AutoClair vérifie le véhicule et l’opération.',
        child: LinearProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return _SimpleCard(
        icon: Icons.sync_problem_rounded,
        title: 'Carnet non mis à jour',
        message: errorMessage!,
        child: OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Réessayer'),
        ),
      );
    }

    final value = sync;
    if (value == null) {
      return _SimpleCard(
        icon: Icons.menu_book_outlined,
        title: 'Ajouter cette opération au carnet',
        message: operation.title,
        child: FilledButton.icon(
          onPressed: onConfirm,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Vérifier et ajouter'),
        ),
      );
    }

    if (value.wasAutomaticallyAdded) {
      final eventTitle = operation.title;
      return _SimpleCard(
        icon: value.userConfirmed
            ? Icons.check_circle_rounded
            : Icons.edit_note_rounded,
        title: value.userConfirmed
            ? 'Ajouté au carnet'
            : 'Opération prête à confirmer',
        message: eventTitle,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!value.userConfirmed)
              FilledButton.icon(
                onPressed: loading ? null : onConfirm,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Vérifier et confirmer'),
              ),
            if (value.canOpenCarnet)
              OutlinedButton.icon(
                onPressed: onOpenCarnet,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Voir dans le carnet'),
              ),
          ],
        ),
      );
    }

    if (value.needsReview) {
      return _SimpleCard(
        icon: Icons.rule_rounded,
        title: 'À vérifier avant ajout',
        message: value.suggestionCount > 0
            ? '${value.suggestionCount} opération(s) sont prêtes dans le carnet.'
            : 'Ouvrez le carnet pour vérifier l’opération détectée.',
        child: FilledButton.icon(
          onPressed: value.canOpenCarnet ? onOpenCarnet : onRetry,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Vérifier dans le carnet'),
        ),
      );
    }

    return _SimpleCard(
      icon: Icons.info_outline_rounded,
      title: 'Aucun événement ajouté',
      message: value.message,
      child: value.canOpenCarnet
          ? OutlinedButton.icon(
              onPressed: onOpenCarnet,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Ouvrir le carnet'),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _UsefulDetailsCard extends StatelessWidget {
  const _UsefulDetailsCard({required this.result, required this.operation});

  final DocumentAnalysisResult result;
  final DetectedVehicleOperation operation;

  @override
  Widget build(BuildContext context) {
    final vehicle = result.objectAt('vehicle');
    final make = vehicle['make']?.toString().trim();
    final model = vehicle['model']?.toString().trim();
    final vehicleName = [
      make,
      model,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' ');

    final rows = <(String, String)>[
      if (vehicleName.isNotEmpty) ('Véhicule', vehicleName),
      if (operation.documentDate != null) ('Date', operation.documentDate!),
      if (operation.providerName != null) ('Garage', operation.providerName!),
      if (operation.mileage != null)
        ('Kilométrage', '${_integer(operation.mileage!)} km'),
      if (operation.amount != null)
        ('Prix', '${_money(operation.amount!)} ${operation.currency}'),
    ];

    return _SimpleCard(
      icon: Icons.fact_check_outlined,
      title: 'Informations utiles',
      message: rows.isEmpty
          ? 'Le kilométrage et le prix pourront être ajoutés au carnet.'
          : 'Vérifiez uniquement les informations utiles au suivi.',
      child: rows.isEmpty
          ? const SizedBox.shrink()
          : Column(
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  if (index > 0) const Divider(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 98,
                        child: Text(
                          rows[index].$1,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          rows[index].$2,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _OperationsListCard extends StatelessWidget {
  const _OperationsListCard({required this.result});

  final DocumentAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final items = result.objectListAt('line_items');
    return _SimpleCard(
      icon: Icons.build_outlined,
      title: items.length == 1 ? 'Opération relevée' : 'Opérations relevées',
      message: 'Les contrôles comptables restent en arrière-plan.',
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const Divider(height: 22),
            _OperationLine(item: items[index]),
          ],
        ],
      ),
    );
  }
}

class _OperationLine extends StatelessWidget {
  const _OperationLine({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final title = item['description']?.toString().trim();
    final amount = _asDouble(
      item['total_including_tax'] ?? item['total_excluding_tax'],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title == null || title.isEmpty ? 'Opération non nommée' : title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (amount != null) ...[
          const SizedBox(width: 10),
          Text('${_money(amount)} €'),
        ],
      ],
    );
  }
}

class _OptionalAdviceCard extends StatelessWidget {
  const _OptionalAdviceCard({required this.result});

  final DocumentAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.help_outline_rounded),
        title: const Text('À vérifier si nécessaire'),
        subtitle: const Text('Conseils complémentaires'),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: [
          for (final observation in result.usefulObservations)
            _AdviceLine(
              text: [
                observation['title'],
                observation['explanation'],
              ].whereType<Object>().join(' — '),
            ),
          for (final question in result.usefulQuestions)
            _AdviceLine(text: question),
        ],
      ),
    );
  }
}

class _AdviceLine extends StatelessWidget {
  const _AdviceLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.circle, size: 7, color: AppColors.primary),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  const _SimpleCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(message),
                  ],
                ),
              ),
            ],
          ),
          if (child is! SizedBox) ...[
            const SizedBox(height: 14),
            child,
          ] else
            child,
        ],
      ),
    );
  }
}

class _OperationConfirmationData {
  const _OperationConfirmationData({
    required this.categoryCode,
    required this.subcategoryCode,
    this.mileage,
    this.amount,
  });

  final String categoryCode;
  final String subcategoryCode;
  final int? mileage;
  final double? amount;
}

class _OperationConfirmationSheet extends StatefulWidget {
  const _OperationConfirmationSheet({required this.operation});

  final DetectedVehicleOperation operation;

  @override
  State<_OperationConfirmationSheet> createState() =>
      _OperationConfirmationSheetState();
}

class _OperationConfirmationSheetState
    extends State<_OperationConfirmationSheet> {
  late final TextEditingController _mileageController;
  late final TextEditingController _amountController;
  late String _categoryCode;
  late String _subcategoryCode;

  @override
  void initState() {
    super.initState();
    _mileageController = TextEditingController(
      text: widget.operation.mileage?.toString() ?? '',
    );
    _amountController = TextEditingController(
      text: widget.operation.amount == null
          ? ''
          : widget.operation.amount!.toStringAsFixed(2).replaceAll('.', ','),
    );
    final initialCategory = VehicleEventCatalog.categoryByCode(
      widget.operation.categoryCode,
    );
    final initialSubcategory = VehicleEventCatalog.subcategoryByCode(
      widget.operation.subcategoryCode,
      categoryCode: initialCategory.code,
    );
    _categoryCode = initialCategory.code;
    _subcategoryCode =
        initialCategory.subcategories.any(
          (subcategory) => subcategory.code == initialSubcategory.code,
        )
        ? initialSubcategory.code
        : initialCategory.subcategories.first.code;
  }

  @override
  void dispose() {
    _mileageController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.operation.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 5),
          Text(
            'Vérifiez la catégorie détectée avant l’ajout au carnet.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            key: const ValueKey('analysis-event-category'),
            initialValue: _categoryCode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Grande catégorie',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: VehicleEventCatalog.categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category.code,
                    child: Text(category.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null || value == _categoryCode) return;
              final category = VehicleEventCatalog.categoryByCode(value);
              setState(() {
                _categoryCode = category.code;
                _subcategoryCode = category.subcategories.first.code;
              });
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey('analysis-event-subcategory-$_categoryCode'),
            initialValue: _subcategoryCode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sous-catégorie',
              prefixIcon: Icon(Icons.build_outlined),
            ),
            items: VehicleEventCatalog.categoryByCode(_categoryCode)
                .subcategories
                .map(
                  (subcategory) => DropdownMenuItem(
                    value: subcategory.code,
                    child: Text(
                      subcategory.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setState(() => _subcategoryCode = value);
            },
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _mileageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Kilométrage (facultatif)',
              suffixText: 'km',
              prefixIcon: Icon(Icons.speed_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Prix (facultatif)',
              suffixText: '€',
              prefixIcon: Icon(Icons.euro_outlined),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              final mileageText = _mileageController.text.trim();
              final amountText = _amountController.text.trim().replaceAll(
                ',',
                '.',
              );
              final mileage = mileageText.isEmpty
                  ? null
                  : int.tryParse(mileageText);
              final amount = amountText.isEmpty
                  ? null
                  : double.tryParse(amountText);

              if (mileageText.isNotEmpty && (mileage == null || mileage < 0)) {
                _message(context, 'Kilométrage invalide.');
                return;
              }
              if (amountText.isNotEmpty && (amount == null || amount < 0)) {
                _message(context, 'Prix invalide.');
                return;
              }

              Navigator.of(context).pop(
                _OperationConfirmationData(
                  categoryCode: _categoryCode,
                  subcategoryCode: _subcategoryCode,
                  mileage: mileage,
                  amount: amount,
                ),
              );
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Ajouter au carnet'),
          ),
        ],
      ),
    );
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _integer(int value) {
  final chars = value.toString().split('').reversed.toList();
  final groups = <String>[];
  for (var index = 0; index < chars.length; index += 3) {
    groups.add(chars.skip(index).take(3).toList().reversed.join());
  }
  return groups.reversed.join(' ');
}

String _money(double value) {
  final fixed = value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return fixed.replaceAll('.', ',');
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
}
