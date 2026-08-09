import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'document_analysis_result.dart';

class ContractDocumentAnalysisCard extends StatelessWidget {
  const ContractDocumentAnalysisCard({required this.result, super.key});

  final DocumentAnalysisResult result;

  static bool supports(DocumentAnalysisResult result) =>
      result.isContractDocument;

  @override
  Widget build(BuildContext context) {
    final obligations = result.contractObligations;
    final costs = result.contractCosts;
    final clauses = result.contractImportantClauses;
    final missing = result.contractMissingInformation;
    final summary = result.contractCommitmentSummary;

    return Container(
      key: const ValueKey('contract-document-analysis-card'),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.detectedTypeLabel,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Les engagements importants, expliqués simplement.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (summary != null) ...[
            const SizedBox(height: 16),
            _Highlight(text: summary),
          ],
          if (obligations.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle(
              icon: Icons.task_alt_outlined,
              title: 'Vos engagements à retenir',
            ),
            const SizedBox(height: 8),
            for (final item in obligations) _FactLine(item: item),
          ],
          if (costs.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle(
              icon: Icons.euro_outlined,
              title: 'Coûts et paiements repérés',
            ),
            const SizedBox(height: 8),
            for (final item in costs) _CostLine(item: item),
          ],
          if (clauses.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle(
              icon: Icons.rule_folder_outlined,
              title: 'Clauses à relire attentivement',
            ),
            const SizedBox(height: 8),
            for (final item in clauses) _FactLine(item: item),
          ],
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle(
              icon: Icons.help_outline_rounded,
              title: 'Informations à vérifier',
            ),
            const SizedBox(height: 8),
            for (final item in missing) _SimpleLine(text: item),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.info),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AutoClair explique uniquement ce qui est lisible dans le '
                    'document. Cette analyse ne remplace pas un conseil '
                    'juridique et ne juge pas la validité d’une clause.',
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

class _Highlight extends StatelessWidget {
  const _Highlight({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softPrimary,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString().trim();
    final explanation = item['explanation']?.toString().trim();

    return _LabeledLine(
      title: title == null || title.isEmpty ? 'Point à retenir' : title,
      explanation: explanation,
    );
  }
}

class _CostLine extends StatelessWidget {
  const _CostLine({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final label = item['label']?.toString().trim();
    final explanation = item['explanation']?.toString().trim();
    final frequency = item['frequency']?.toString().trim();
    final amount = _asDouble(item['amount']);
    final currency = item['currency']?.toString().trim();

    final parts = <String>[
      if (amount != null)
        '${_money(amount)} ${currency == null || currency.isEmpty ? 'EUR' : currency}',
      if (frequency != null && frequency.isNotEmpty) frequency,
    ];

    return _LabeledLine(
      title: label == null || label.isEmpty ? 'Coût relevé' : label,
      value: parts.isEmpty ? null : parts.join(' • '),
      explanation: explanation,
    );
  }
}

class _LabeledLine extends StatelessWidget {
  const _LabeledLine({required this.title, this.value, this.explanation});

  final String title;
  final String? value;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 7, color: AppColors.primary),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (value != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        value!,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ],
                ),
                if (explanation != null && explanation!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    explanation!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleLine extends StatelessWidget {
  const _SimpleLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(
              Icons.help_outline_rounded,
              size: 18,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
}

String _money(double value) => value.toStringAsFixed(2).replaceAll('.', ',');
