import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'document_analysis_result.dart';

class ServiceDocumentAnalysisCard extends StatelessWidget {
  const ServiceDocumentAnalysisCard({required this.result, super.key});

  final DocumentAnalysisResult result;

  static bool supports(DocumentAnalysisResult result) {
    final type = result.effectiveDocumentType;
    return type == 'estimate' || type == 'invoice' || type == 'repair_order';
  }

  @override
  Widget build(BuildContext context) {
    final items = result.objectListAt('line_items');
    final dates = result.objectAt('dates');
    final amounts = result.objectAt('amounts');
    final total = _asDouble(amounts['total_including_tax']);
    final currency = _cleanText(amounts['currency']) ?? 'EUR';
    final validityEndDate = _cleanText(dates['validity_end_date']);
    final clarificationCount = items
        .where((item) => item['necessity_assessment'] == 'unclear')
        .length;
    final showValidity =
        result.effectiveDocumentType == 'estimate' && validityEndDate != null;
    final hasSummary = total != null || showValidity || clarificationCount > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconForType(result), color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleForType(result),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _messageForType(result),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasSummary) ...[
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (total != null)
                  _SummaryPill(
                    icon: Icons.payments_outlined,
                    label:
                        'Total TTC ${_money(total)} ${_currencyLabel(currency)}',
                  ),
                if (showValidity)
                  _SummaryPill(
                    icon: Icons.event_available_outlined,
                    label: 'Valable jusqu’au $validityEndDate',
                  ),
                if (clarificationCount > 0)
                  _SummaryPill(
                    icon: Icons.help_outline_rounded,
                    label: clarificationCount == 1
                        ? '1 point à clarifier'
                        : '$clarificationCount points à clarifier',
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text(
              'Aucune opération détaillée n’a été extraite de ce document.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) const Divider(height: 24),
              _ServiceLine(item: items[index], currency: currency),
            ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.info,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AutoClair explique ce que dit le document. Sans donnée '
                    'constructeur ou tarif de référence vérifié, il ne confirme '
                    'ni la nécessité technique ni le niveau de prix.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceLine extends StatelessWidget {
  const _ServiceLine({required this.item, required this.currency});

  final Map<String, dynamic> item;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final description =
        _cleanText(item['description']) ?? 'Opération non nommée';
    final explanation = _cleanText(item['explanation']);
    final style = _NecessityStyle.from(
      item['necessity_assessment']?.toString(),
    );
    final totalIncludingTax = _asDouble(item['total_including_tax']);
    final totalExcludingTax = _asDouble(item['total_excluding_tax']);
    final amountLabel = totalIncludingTax != null
        ? '${_money(totalIncludingTax)} ${_currencyLabel(currency)} TTC'
        : totalExcludingTax != null
        ? '${_money(totalExcludingTax)} ${_currencyLabel(currency)} HT'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(description, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StatusPill(style: style),
            if (amountLabel != null)
              Text(
                amountLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
          ],
        ),
        if (explanation != null) ...[
          const SizedBox(height: 8),
          Text(explanation, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.softPrimary,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.style});

  final _NecessityStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 15, color: style.foreground),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: TextStyle(
              color: style.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NecessityStyle {
  const _NecessityStyle({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;

  factory _NecessityStyle.from(String? value) {
    return switch (value) {
      'explicitly_required' => const _NecessityStyle(
        label: 'Présenté comme nécessaire',
        background: AppColors.warningSoft,
        foreground: AppColors.warning,
        icon: Icons.priority_high_rounded,
      ),
      'recommended' => const _NecessityStyle(
        label: 'Recommandé sur le document',
        background: AppColors.infoSoft,
        foreground: AppColors.info,
        icon: Icons.thumb_up_alt_outlined,
      ),
      'optional' => const _NecessityStyle(
        label: 'Optionnel sur le document',
        background: AppColors.softPrimary,
        foreground: AppColors.primary,
        icon: Icons.tune_rounded,
      ),
      _ => const _NecessityStyle(
        label: 'À clarifier',
        background: AppColors.errorSoft,
        foreground: AppColors.error,
        icon: Icons.help_outline_rounded,
      ),
    };
  }
}

String _titleForType(DocumentAnalysisResult result) {
  return switch (result.effectiveDocumentType) {
    'estimate' => 'Ce que le garage vous propose',
    'invoice' => 'Ce qui a été facturé',
    'repair_order' => 'Ce qui est demandé au garage',
    _ => 'Opérations du document',
  };
}

String _messageForType(DocumentAnalysisResult result) {
  return switch (result.effectiveDocumentType) {
    'estimate' =>
      'Distinguez ce que le garage présente comme nécessaire, recommande ou laisse optionnel.',
    'invoice' =>
      'Retrouvez les opérations facturées et les éléments qui méritent une clarification.',
    'repair_order' =>
      'Vérifiez les travaux demandés au garage avant de valider l’intervention.',
    _ => 'Vérifiez les opérations relevées dans le document.',
  };
}

IconData _iconForType(DocumentAnalysisResult result) {
  return switch (result.effectiveDocumentType) {
    'estimate' => Icons.request_quote_outlined,
    'invoice' => Icons.receipt_long_outlined,
    'repair_order' => Icons.car_repair_outlined,
    _ => Icons.build_outlined,
  };
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }
  return null;
}

String? _cleanText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String _money(double value) => value.toStringAsFixed(2).replaceAll('.', ',');

String _currencyLabel(String value) =>
    value.toUpperCase() == 'EUR' ? '€' : value;
