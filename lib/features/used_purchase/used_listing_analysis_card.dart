import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'used_listing_analysis.dart';

class UsedListingAnalysisCard extends StatelessWidget {
  const UsedListingAnalysisCard({
    required this.analysis,
    required this.onCopyQuestions,
    super.key,
  });

  final UsedListingAnalysis analysis;
  final VoidCallback onCopyQuestions;

  @override
  Widget build(BuildContext context) {
    final facts = <String>[];
    final year = analysis.detectedYear;
    final mileage = analysis.detectedMileage;
    final price = analysis.detectedPrice;
    if (year != null) facts.add('$year');
    if (mileage != null) facts.add('${_integer(mileage)} km');
    if (price != null) facts.add('${_money(price)} €');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
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
                  color: analysis.hasPointsToCheck
                      ? AppColors.warningSoft
                      : AppColors.successSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  analysis.hasPointsToCheck
                      ? Icons.manage_search_rounded
                      : Icons.check_circle_outline,
                  color: analysis.hasPointsToCheck
                      ? AppColors.warning
                      : AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Première lecture de l’annonce',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      analysis.hasPointsToCheck
                          ? 'AutoClair a repéré des éléments à vérifier avant le rendez-vous.'
                          : 'Aucun signal particulier n’a été repéré dans le texte fourni.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: facts.map((value) => _FactChip(value: value)).toList(),
            ),
          ],
          if (analysis.findings.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Points à vérifier',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final finding in analysis.findings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FindingLine(finding: finding),
              ),
          ],
          if (analysis.mentionedEvidence.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Ce que l’annonce mentionne',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 7),
            for (final evidence in analysis.mentionedEvidence)
              _BulletLine(
                icon: Icons.check_circle_outline,
                text: evidence,
                color: AppColors.success,
              ),
          ],
          if (analysis.missingEssentials.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Informations non repérées',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 7),
            Text(
              analysis.missingEssentials.join(' • '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (analysis.questions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Questions à poser au vendeur',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: onCopyQuestions,
                  tooltip: 'Copier les questions',
                  icon: const Icon(Icons.content_copy_outlined),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final question in analysis.questions)
              _BulletLine(
                icon: Icons.help_outline,
                text: question,
                color: AppColors.primary,
              ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 20),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Lecture locale du texte uniquement : AutoClair ne vérifie '
                    'ni l’identité du vendeur, ni l’historique réel du véhicule, '
                    'ni sa valeur de marché.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _integer(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < raw.length; index++) {
      if (index > 0 && (raw.length - index) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(raw[index]);
    }
    return buffer.toString();
  }

  static String _money(double value) {
    if (value == value.roundToDouble()) {
      return _integer(value.round());
    }
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.softPrimary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FindingLine extends StatelessWidget {
  const _FindingLine({required this.finding});

  final UsedListingFinding finding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 21,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding.title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  finding.detail,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
