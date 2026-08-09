import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'document_analysis_result.dart';

class TechnicalInspectionAnalysisCard extends StatelessWidget {
  const TechnicalInspectionAnalysisCard({required this.result, super.key});

  final DocumentAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final inspection = result.technicalInspection;
    final defects = result.technicalInspectionDefects;
    final requiresReinspection = result.technicalInspectionRequiresReinspection;
    final deadline = result.technicalInspectionReinspectionDeadline;

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
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contrôle technique',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(result.technicalInspectionResultLabel),
                  ],
                ),
              ),
            ],
          ),
          if (requiresReinspection != null || deadline != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (requiresReinspection != null)
                  _InspectionTag(
                    label: requiresReinspection
                        ? 'Contre-visite à prévoir'
                        : 'Pas de contre-visite détectée',
                  ),
                if (deadline != null)
                  _InspectionTag(label: 'Avant le $deadline'),
              ],
            ),
          ],
          if (defects.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              defects.length == 1
                  ? '1 défaillance relevée'
                  : '${defects.length} défaillances relevées',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final defect in defects) _DefectLine(defect: defect),
          ] else if (inspection.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Aucune défaillance structurée n’a été extraite. '
              'Le procès-verbal original reste la référence.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _InspectionTag extends StatelessWidget {
  const _InspectionTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.softPrimary,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DefectLine extends StatelessWidget {
  const _DefectLine({required this.defect});

  final Map<String, dynamic> defect;

  @override
  Widget build(BuildContext context) {
    final severity = defect['severity']?.toString();
    final wording = defect['wording']?.toString().trim();
    final explanation = defect['explanation']?.toString().trim();
    final action = defect['recommended_action']?.toString().trim();

    final severityLabel = switch (severity) {
      'critical' => 'Critique',
      'major' => 'Majeure',
      'minor' => 'Mineure',
      _ => 'À vérifier',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              severityLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            if (wording != null && wording.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                wording,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            if (explanation != null && explanation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(explanation),
            ],
            if (action != null && action.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'À faire : $action',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
