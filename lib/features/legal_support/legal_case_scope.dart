import 'legal_case_models.dart';

enum LegalScopeLevel {
  supported,
  needsInformation,
  dossierOnly,
  escalationRequired,
}

class LegalScopeDecision {
  const LegalScopeDecision({
    required this.level,
    required this.title,
    required this.message,
  });

  final LegalScopeLevel level;
  final String title;
  final String message;

  bool get canAnalyze => level == LegalScopeLevel.supported;

  static LegalScopeDecision evaluate({
    required LegalCaseCategory category,
    required String counterpartyType,
    required String description,
    required bool bodilyInjury,
    required bool courtStarted,
    required bool criminalIssue,
    required bool crossBorder,
  }) {
    if (bodilyInjury || courtStarted || criminalIssue || crossBorder) {
      return const LegalScopeDecision(
        level: LegalScopeLevel.escalationRequired,
        title: 'Préparation du dossier uniquement',
        message:
            'Cette situation dépasse le périmètre d’analyse automatisée de la V1. '
            'AutoClair peut organiser les faits et les pièces, mais une analyse professionnelle est recommandée.',
      );
    }

    if (category == LegalCaseCategory.other ||
        counterpartyType == 'private_individual') {
      return const LegalScopeDecision(
        level: LegalScopeLevel.dossierOnly,
        title: 'Dossier et orientation',
        message:
            'La V1 n’effectue pas d’analyse juridique personnalisée pour ce cas. '
            'Elle peut néanmoins structurer votre dossier et vos prochaines questions.',
      );
    }

    if (description.trim().length < 30) {
      return const LegalScopeDecision(
        level: LegalScopeLevel.needsInformation,
        title: 'Quelques précisions sont nécessaires',
        message:
            'Décrivez les faits, les dates importantes et ce que le professionnel vous a répondu avant de lancer l’analyse.',
      );
    }

    return const LegalScopeDecision(
      level: LegalScopeLevel.supported,
      title: 'Analyse V1 disponible',
      message:
          'AutoClair peut rechercher les sources officielles pertinentes et préparer une lecture structurée de votre dossier.',
    );
  }
}
