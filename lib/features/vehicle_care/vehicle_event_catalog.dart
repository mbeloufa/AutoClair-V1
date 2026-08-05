import 'package:flutter/material.dart';

class VehicleEventCategory {
  const VehicleEventCategory({
    required this.code,
    required this.label,
    required this.icon,
    required this.subcategories,
  });

  final String code;
  final String label;
  final IconData icon;
  final List<VehicleEventSubcategory> subcategories;
}

class VehicleEventSubcategory {
  const VehicleEventSubcategory({
    required this.code,
    required this.label,
    required this.eventType,
    required this.defaultTitle,
  });

  final String code;
  final String label;
  final String eventType;
  final String defaultTitle;
}

class VehicleEventClassification {
  const VehicleEventClassification({
    required this.category,
    required this.subcategory,
  });

  final VehicleEventCategory category;
  final VehicleEventSubcategory subcategory;
}

class VehicleEventCatalog {
  VehicleEventCatalog._();

  static const categories = <VehicleEventCategory>[
    VehicleEventCategory(
      code: 'MAINTENANCE',
      label: 'Entretien',
      icon: Icons.build_outlined,
      subcategories: [
        VehicleEventSubcategory(
          code: 'SERVICE_OIL',
          label: 'Révision et vidange',
          eventType: 'MAINTENANCE',
          defaultTitle: 'Révision et vidange',
        ),
        VehicleEventSubcategory(
          code: 'FILTERS_FLUIDS',
          label: 'Filtres et fluides',
          eventType: 'MAINTENANCE',
          defaultTitle: 'Filtres et fluides',
        ),
        VehicleEventSubcategory(
          code: 'TIMING',
          label: 'Distribution',
          eventType: 'MAINTENANCE',
          defaultTitle: 'Distribution',
        ),
        VehicleEventSubcategory(
          code: 'CLIMATE',
          label: 'Climatisation',
          eventType: 'MAINTENANCE',
          defaultTitle: 'Entretien de la climatisation',
        ),
      ],
    ),
    VehicleEventCategory(
      code: 'SAFETY',
      label: 'Sécurité',
      icon: Icons.health_and_safety_outlined,
      subcategories: [
        VehicleEventSubcategory(
          code: 'BRAKES',
          label: 'Freinage',
          eventType: 'REPAIR',
          defaultTitle: 'Intervention sur le freinage',
        ),
        VehicleEventSubcategory(
          code: 'TYRES',
          label: 'Pneus',
          eventType: 'TYRES',
          defaultTitle: 'Intervention sur les pneus',
        ),
        VehicleEventSubcategory(
          code: 'LIGHTING_VISIBILITY',
          label: 'Éclairage et visibilité',
          eventType: 'REPAIR',
          defaultTitle: 'Éclairage ou visibilité',
        ),
        VehicleEventSubcategory(
          code: 'TECHNICAL_INSPECTION',
          label: 'Contrôle technique',
          eventType: 'INSPECTION',
          defaultTitle: 'Contrôle technique',
        ),
        VehicleEventSubcategory(
          code: 'ANTI_POLLUTION',
          label: 'Antipollution',
          eventType: 'INSPECTION',
          defaultTitle: 'Contrôle antipollution',
        ),
      ],
    ),
    VehicleEventCategory(
      code: 'REPAIR',
      label: 'Réparation',
      icon: Icons.car_repair_outlined,
      subcategories: [
        VehicleEventSubcategory(
          code: 'ENGINE_TRANSMISSION',
          label: 'Moteur et transmission',
          eventType: 'REPAIR',
          defaultTitle: 'Réparation moteur ou transmission',
        ),
        VehicleEventSubcategory(
          code: 'DIAGNOSTICS',
          label: 'Diagnostic',
          eventType: 'REPAIR',
          defaultTitle: 'Diagnostic du véhicule',
        ),
        VehicleEventSubcategory(
          code: 'BATTERY_ELECTRICAL',
          label: 'Batterie et électricité',
          eventType: 'REPAIR',
          defaultTitle: 'Batterie ou électricité',
        ),
        VehicleEventSubcategory(
          code: 'STEERING_SUSPENSION',
          label: 'Direction et suspension',
          eventType: 'REPAIR',
          defaultTitle: 'Direction ou suspension',
        ),
        VehicleEventSubcategory(
          code: 'EXHAUST',
          label: 'Échappement',
          eventType: 'REPAIR',
          defaultTitle: 'Échappement',
        ),
        VehicleEventSubcategory(
          code: 'BODY_GLASS',
          label: 'Carrosserie et vitrage',
          eventType: 'REPAIR',
          defaultTitle: 'Carrosserie ou vitrage',
        ),
      ],
    ),
    VehicleEventCategory(
      code: 'ADMINISTRATIVE',
      label: 'Administratif',
      icon: Icons.description_outlined,
      subcategories: [
        VehicleEventSubcategory(
          code: 'INSURANCE',
          label: 'Assurance',
          eventType: 'INSURANCE',
          defaultTitle: 'Assurance',
        ),
        VehicleEventSubcategory(
          code: 'ACCIDENT_CLAIM',
          label: 'Sinistre',
          eventType: 'ACCIDENT',
          defaultTitle: 'Sinistre automobile',
        ),
        VehicleEventSubcategory(
          code: 'REGISTRATION',
          label: 'Immatriculation',
          eventType: 'ADMINISTRATIVE',
          defaultTitle: 'Démarche d’immatriculation',
        ),
        VehicleEventSubcategory(
          code: 'PURCHASE_SALE',
          label: 'Achat et vente',
          eventType: 'ADMINISTRATIVE',
          defaultTitle: 'Achat ou vente du véhicule',
        ),
        VehicleEventSubcategory(
          code: 'WARRANTY_RECALL',
          label: 'Garantie et rappel',
          eventType: 'WARRANTY',
          defaultTitle: 'Garantie ou rappel constructeur',
        ),
      ],
    ),
    VehicleEventCategory(
      code: 'OTHER',
      label: 'Autre',
      icon: Icons.more_horiz_rounded,
      subcategories: [
        VehicleEventSubcategory(
          code: 'OTHER',
          label: 'Autre événement',
          eventType: 'OTHER',
          defaultTitle: 'Autre événement',
        ),
      ],
    ),
  ];

  static VehicleEventCategory categoryByCode(String? code) {
    for (final category in categories) {
      if (category.code == code) return category;
    }
    return categories.last;
  }

  static VehicleEventSubcategory subcategoryByCode(
    String? code, {
    String? categoryCode,
  }) {
    final preferred = categoryByCode(categoryCode);
    for (final subcategory in preferred.subcategories) {
      if (subcategory.code == code) return subcategory;
    }
    for (final category in categories) {
      for (final subcategory in category.subcategories) {
        if (subcategory.code == code) return subcategory;
      }
    }
    return categories.last.subcategories.first;
  }

  static VehicleEventClassification fromEventType(
    String? eventType, {
    String? title,
  }) {
    return classify(
      [eventType, title].whereType<String>().join(' '),
      fallbackEventType: eventType,
    );
  }

  static VehicleEventClassification classify(
    String? value, {
    String? fallbackEventType,
  }) {
    final normalized = _normalize(value ?? '');

    VehicleEventClassification pick(String category, String subcategory) {
      final categoryValue = categoryByCode(category);
      return VehicleEventClassification(
        category: categoryValue,
        subcategory: subcategoryByCode(
          subcategory,
          categoryCode: categoryValue.code,
        ),
      );
    }

    if (_containsAny(normalized, [
      'controle technique',
      'contre visite',
      'inspection technique',
      'proces verbal controle',
      'pv controle technique',
    ])) {
      return pick('SAFETY', 'TECHNICAL_INSPECTION');
    }
    if (_containsAny(normalized, [
      'antipollution',
      'anti pollution',
      'controle pollution',
      'controle emission',
      'emissions polluantes',
      'opacite fumee',
    ])) {
      return pick('SAFETY', 'ANTI_POLLUTION');
    }
    if (_containsAny(normalized, [
      'plaquette',
      'disque de frein',
      'freinage',
      'liquide de frein',
      'etrier',
      'maitre cylindre',
    ])) {
      return pick('SAFETY', 'BRAKES');
    }
    if (_containsAny(normalized, [
      'pneu',
      'pneumatique',
      'roue',
      'jante',
      'equilibrage',
      'geometrie',
      'parallellisme',
    ])) {
      return pick('SAFETY', 'TYRES');
    }
    if (_containsAny(normalized, [
      'essuie glace',
      'pare brise',
      'phare',
      'ampoule',
      'eclairage',
      'visibilite',
      'balai essuie glace',
    ])) {
      return pick('SAFETY', 'LIGHTING_VISIBILITY');
    }
    if (_containsAny(normalized, [
      'filtre a huile',
      'filtre a air',
      'filtre habitacle',
      'filtre carburant',
      'liquide refroidissement',
      'liquide lave glace',
      'liquide direction',
      'fluide',
    ])) {
      return pick('MAINTENANCE', 'FILTERS_FLUIDS');
    }
    if (_containsAny(normalized, [
      'vidange',
      'revision constructeur',
      'revision complete',
      'revision annuelle',
      'entretien periodique',
      'huile moteur',
      'service entretien',
    ])) {
      return pick('MAINTENANCE', 'SERVICE_OIL');
    }
    if (_containsAny(normalized, [
      'distribution',
      'courroie distribution',
      'chaine distribution',
      'pompe a eau',
      'galet tendeur',
    ])) {
      return pick('MAINTENANCE', 'TIMING');
    }
    if (_containsAny(normalized, [
      'climatisation',
      'recharge clim',
      'recharge gaz',
      'compresseur clim',
      'circuit clim',
    ])) {
      return pick('MAINTENANCE', 'CLIMATE');
    }
    if (_containsAny(normalized, [
      'diagnostic',
      'lecture defaut',
      'lecture code erreur',
      'passage valise',
      'voyant moteur',
      'recherche de panne',
    ])) {
      return pick('REPAIR', 'DIAGNOSTICS');
    }
    if (_containsAny(normalized, [
      'batterie',
      'alternateur',
      'demarreur',
      'electricite',
      'faisceau',
      'fusible',
    ])) {
      return pick('REPAIR', 'BATTERY_ELECTRICAL');
    }
    if (_containsAny(normalized, [
      'amortisseur',
      'suspension',
      'direction',
      'rotule',
      'triangle',
      'biellette',
      'roulement',
    ])) {
      return pick('REPAIR', 'STEERING_SUSPENSION');
    }
    if (_containsAny(normalized, [
      'echappement',
      'silencieux',
      'catalyseur',
      'filtre a particules',
      'fap',
      'vanne egr',
    ])) {
      return pick('REPAIR', 'EXHAUST');
    }
    if (_containsAny(normalized, [
      'carrosserie',
      'vitrage',
      'pare choc',
      'portiere',
      'peinture',
      'debosselage',
      'impact pare brise',
    ])) {
      return pick('REPAIR', 'BODY_GLASS');
    }
    if (_containsAny(normalized, [
      'moteur',
      'embrayage',
      'boite de vitesse',
      'transmission',
      'injecteur',
      'turbo',
      'joint de culasse',
      'cardan',
    ])) {
      return pick('REPAIR', 'ENGINE_TRANSMISSION');
    }
    if (_containsAny(normalized, [
      'sinistre',
      'accident',
      'constat amiable',
      'expertise assurance',
      'indemnisation',
    ])) {
      return pick('ADMINISTRATIVE', 'ACCIDENT_CLAIM');
    }
    if (_containsAny(normalized, [
      'assurance',
      'attestation assurance',
      'carte verte',
      'cotisation assurance',
    ])) {
      return pick('ADMINISTRATIVE', 'INSURANCE');
    }
    if (_containsAny(normalized, [
      'immatriculation',
      'carte grise',
      'certificat immatriculation',
      'changement titulaire',
      'changement adresse carte grise',
    ])) {
      return pick('ADMINISTRATIVE', 'REGISTRATION');
    }
    if (_containsAny(normalized, [
      'achat vehicule',
      'vente vehicule',
      'certificat de cession',
      'declaration de cession',
      'reprise vehicule',
      'bon de commande',
    ])) {
      return pick('ADMINISTRATIVE', 'PURCHASE_SALE');
    }
    if (_containsAny(normalized, [
      'garantie',
      'rappel constructeur',
      'campagne rappel',
      'action de rappel',
      'prise en charge constructeur',
    ])) {
      return pick('ADMINISTRATIVE', 'WARRANTY_RECALL');
    }

    return switch (fallbackEventType) {
      'MAINTENANCE' => pick('MAINTENANCE', 'SERVICE_OIL'),
      'INSPECTION' || 'REINSPECTION' => pick('SAFETY', 'TECHNICAL_INSPECTION'),
      'TYRES' => pick('SAFETY', 'TYRES'),
      'INSURANCE' => pick('ADMINISTRATIVE', 'INSURANCE'),
      'ACCIDENT' => pick('ADMINISTRATIVE', 'ACCIDENT_CLAIM'),
      'WARRANTY' || 'RECALL' => pick('ADMINISTRATIVE', 'WARRANTY_RECALL'),
      'ADMINISTRATIVE' => pick('ADMINISTRATIVE', 'REGISTRATION'),
      'REPAIR' ||
      'CONDITION' ||
      'EQUIPMENT' => pick('REPAIR', 'ENGINE_TRANSMISSION'),
      _ => pick('OTHER', 'OTHER'),
    };
  }

  static String categoryLabelFor({
    required String? eventType,
    required String? title,
  }) => fromEventType(eventType, title: title).category.label;

  static String subcategoryLabelFor({
    required String? eventType,
    required String? title,
  }) => fromEventType(eventType, title: title).subcategory.label;

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâäãå]'), 'a')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[òóôöõ]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  static bool _containsAny(String value, List<String> patterns) {
    final tokens = value.split(' ').where((token) => token.isNotEmpty).toSet();
    final paddedValue = ' $value ';

    for (final pattern in patterns) {
      final normalizedPattern = _normalize(pattern);
      if (normalizedPattern.isEmpty) continue;

      if (normalizedPattern.contains(' ')) {
        if (paddedValue.contains(' $normalizedPattern ')) return true;
        continue;
      }

      if (tokens.contains(normalizedPattern) ||
          tokens.contains('${normalizedPattern}s')) {
        return true;
      }
    }
    return false;
  }
}
