import '../vehicles/vehicle.dart';
import 'sale_preparation_models.dart';

class SaleListingDraft {
  const SaleListingDraft({
    required this.title,
    required this.description,
    required this.highlights,
    required this.informationToComplete,
    required this.photoOrder,
  });

  final String title;
  final String description;
  final List<String> highlights;
  final List<String> informationToComplete;
  final List<String> photoOrder;

  String buildCopyText() {
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln()
      ..writeln(description.trim());

    if (highlights.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Points utiles à mettre en avant :');
      for (final item in highlights) {
        buffer.writeln('• $item');
      }
    }

    return buffer.toString().trim();
  }
}

class SaleListingDraftBuilder {
  static SaleListingDraft build({
    required Vehicle vehicle,
    required SalePreparationProfile profile,
    required SalePreparationContext saleContext,
  }) {
    final make = vehicle.make.trim();
    final model = vehicle.model.trim();
    final year = vehicle.vehicleYear;
    final mileage = vehicle.mileage;
    final fuel = _clean(vehicle.fuelType);

    final titleParts = <String>[
      [make, model].where((value) => value.isNotEmpty).join(' '),
      if (year != null) year.toString(),
      if (mileage != null) '${_integer(mileage)} km',
      ?fuel,
    ].where((value) => value.isNotEmpty).toList(growable: false);

    final title = titleParts.isEmpty
        ? 'Véhicule à vendre'
        : titleParts.join(' – ');

    final description = StringBuffer();
    final vehicleLabel = [
      make,
      model,
    ].where((value) => value.isNotEmpty).join(' ').trim();

    if (vehicleLabel.isNotEmpty) {
      description.write('Je vends mon $vehicleLabel');
    } else {
      description.write('Je vends mon véhicule');
    }
    if (year != null) {
      description.write(' de $year');
    }
    description.write('.');

    if (mileage != null) {
      description.write(' Kilométrage actuel : ${_integer(mileage)} km.');
    }
    if (fuel != null) {
      description.write(' Énergie : $fuel.');
    }
    if (profile.askingPrice > 0) {
      description.write(' Prix affiché : ${_money(profile.askingPrice)} €.');
    }

    final highlights = <String>[];

    if (profile.invoicesAvailable) {
      highlights.add('Factures ou justificatifs d’entretien disponibles');
    } else if (saleContext.completedDocumentCount > 0) {
      highlights.add(
        '${saleContext.completedDocumentCount} document(s) déjà '
        'centralisé(s) dans le dossier AutoClair',
      );
    }

    if (profile.histovecShared) {
      highlights.add('Rapport HistoVec prêt à être partagé');
    }

    if (profile.spareKeyCount > 0) {
      highlights.add(
        '${profile.spareKeyCount} clé(s) prévue(s) lors de la remise',
      );
    }

    final technicalControlText = switch (profile.technicalControlStatus) {
      SaleTechnicalControlStatus.favorable =>
        'Contrôle technique déclaré favorable',
      SaleTechnicalControlStatus.majorDefects =>
        'Contrôle technique avec contre-visite à prévoir',
      SaleTechnicalControlStatus.criticalDefects =>
        'Contrôle technique avec défaillance critique déclarée',
      SaleTechnicalControlStatus.notRequired =>
        'Contrôle technique déclaré non requis pour la vente envisagée',
      SaleTechnicalControlStatus.unknown => null,
    };
    if (technicalControlText != null) {
      highlights.add(technicalControlText);
    }

    if (saleContext.recentConfirmedEventCount > 0) {
      highlights.add(
        '${saleContext.recentConfirmedEventCount} événement(s) récent(s) '
        'confirmé(s) dans le carnet AutoClair',
      );
    }

    if (highlights.isNotEmpty) {
      description.write(' ');
      description.write(highlights.join('. '));
      description.write('.');
    }

    description.write(
      ' Les informations ci-dessus sont issues des données renseignées '
      'dans AutoClair et sont à relire avant publication.',
    );

    final informationToComplete = <String>[
      if (year == null) 'Année ou date de première mise en circulation',
      if (mileage == null) 'Kilométrage actuel',
      if (fuel == null) 'Motorisation / énergie',
      if (profile.askingPrice <= 0) 'Prix de vente',
      if (profile.technicalControlStatus == SaleTechnicalControlStatus.unknown)
        'Situation du contrôle technique',
      'Équipements et options principales',
      'État extérieur et intérieur, avec les défauts à signaler',
      if (saleContext.recentConfirmedEventCount > 0)
        'Entretiens ou réparations récents à sélectionner précisément',
      if (!profile.invoicesAvailable)
        'Factures ou justificatifs d’entretien disponibles, si vous en avez',
    ];

    const photoOrder = <String>[
      'Vue trois-quarts avant, véhicule propre et entièrement visible',
      'Vue trois-quarts arrière',
      'Deux côtés et principaux éléments de carrosserie',
      'Habitacle et tableau de bord',
      'Sièges avant, banquette arrière et coffre',
      'Jantes et pneus',
      'Compartiment moteur sans masquer les éventuels défauts',
      'Compteur kilométrique, sans afficher de donnée personnelle',
    ];

    return SaleListingDraft(
      title: title,
      description: description.toString(),
      highlights: List.unmodifiable(highlights),
      informationToComplete: List.unmodifiable(informationToComplete),
      photoOrder: photoOrder,
    );
  }

  static String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  static String _integer(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[index]);
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
