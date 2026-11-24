/// Catalogue de référence de la commercialisation AutoClair V1.
///
/// Tarifs et volumes provisoires en test fermé. Valider les autres coûts
/// fournisseurs, les prix du Play Store et la marge avant activation.
/// Les achats restent fermés jusqu'à l'activation des compteurs serveur
/// et à la recette des paiements (tickets 04-14).
enum CommercialProductType { subscription, documentPack, vehicle360 }

class CommercialProduct {
  const CommercialProduct({
    required this.code,
    required this.name,
    required this.type,
    required this.description,
    this.priceCentsTtc,
    this.quantity,
    this.storeProductId,
  });

  final String code;
  final String name;
  final CommercialProductType type;
  final String description;
  final int? priceCentsTtc;
  final int? quantity;
  final String? storeProductId;

  bool get fullySpecified =>
      priceCentsTtc != null &&
      storeProductId != null &&
      (type == CommercialProductType.subscription || quantity != null);
}

class CommercialFeatureRule {
  const CommercialFeatureRule({
    required this.code,
    required this.name,
    required this.free,
    required this.subscription,
    required this.singlePurchase,
    required this.requiresServerMetering,
  });

  final String code;
  final String name;
  final String free;
  final String subscription;
  final String singlePurchase;
  final bool requiresServerMetering;
}

class PremiumCatalog {
  const PremiumCatalog._();

  static const entitlementId = 'premium';
  static const freeTitle = 'AutoClair Gratuit';
  static const premiumTitle = 'AutoClair Premium';

  // Prix cible validé dans la feuille de route du 19/10/2026.
  // Le montant définitif présenté et encaissé est toujours celui du Store.
  static const annualPriceCentsTtc = 2999;
  static const annualLabel = 'Annuel';

  // Aucun paiement n'est possible sans commercial_settings.sales_enabled
  // ET produits actifs ET vérification serveur des identifiants du Store.
  // Champ historique conservé pour la compatibilité des tests.
  static const checkoutEnabled = false;

  static const annualDocumentCredits = 20;
  static const annualVehicle360Credits = 5;

  static const annual = CommercialProduct(
    code: 'premium_annual',
    name: 'Premium annuel',
    type: CommercialProductType.subscription,
    description: '20 analyses de documents et 5 Bilans 360 par période '
        'annuelle, sous réserve de validation des prix.',
    priceCentsTtc: annualPriceCentsTtc,
  );

  static const packs = <CommercialProduct>[
    CommercialProduct(
      code: 'analysis_small',
      name: 'Pack 5 analyses documentaires',
      type: CommercialProductType.documentPack,
      description: '5 nouveaux traitements documentaires sans abonnement.',
      quantity: 5,
      priceCentsTtc: 399,
    ),
    CommercialProduct(
      code: 'analysis_large',
      name: 'Pack 15 analyses documentaires',
      type: CommercialProductType.documentPack,
      description: '15 nouveaux traitements documentaires sans abonnement.',
      quantity: 15,
      priceCentsTtc: 899,
    ),
    CommercialProduct(
      code: 'vehicle360_single',
      name: 'Bilan 360 à l’unité',
      type: CommercialProductType.vehicle360,
      description: 'Un nouveau Bilan AutoClair 360 sans abonnement.',
      quantity: 1,
      priceCentsTtc: 499,
    ),
  ];

  static const freeBenefits = <String>[
    'Gérer vos véhicules, votre carnet et vos rappels',
    'Consulter vos documents et résultats déjà acquis',
    '1 première analyse documentaire offerte',
    '1 premier Bilan AutoClair 360 offert',
  ];

  static const premiumBenefits = <String>[
    'Objectif tarifaire : 29,99 € TTC par an',
    '20 analyses de documents et 5 Bilans 360 par an',
    'Conserver les résultats acquis après la fin de l’abonnement',
  ];

  // Matrice couvrant les services exposés. « À définir » = NON AUTORISÉ
  // à devenir illimité ; les fonctions payantes requièrent un compteur serveur.
  static const featureRights = <CommercialFeatureRule>[
    CommercialFeatureRule(code: 'vehicles', name: 'Véhicules et carnet',
      free: 'Gestion et consultation ; limite de véhicules à figer',
      subscription: 'Gestion et consultation ; limite à figer',
      singlePurchase: 'Aucun véhicule supplémentaire attribué',
      requiresServerMetering: false),
    CommercialFeatureRule(code: 'saved_results', name: 'Résultats et documents acquis',
      free: 'Consultation conservée', subscription: 'Consultation conservée',
      singlePurchase: 'Consultation conservée',
      requiresServerMetering: false),
    CommercialFeatureRule(code: 'document_analysis', name: 'Scan et analyse documentaire',
      free: '1 première analyse offerte par compte',
      subscription: '20 nouvelles analyses par an',
      singlePurchase: 'Débit de 1 unité documentaire par nouvelle analyse',
      requiresServerMetering: true),
    CommercialFeatureRule(code: 'vehicle360', name: 'Bilan AutoClair 360',
      free: '1 Bilan offert par compte',
      subscription: '5 nouveaux Bilans par an',
      singlePurchase: 'Débit de 1 unité Bilan 360 par nouveau résultat',
      requiresServerMetering: true),
    CommercialFeatureRule(code: 'tire_ai', name: 'Analyse IA des pneus',
      free: 'Quota à définir', subscription: 'Quota à définir',
      singlePurchase: 'Pas compris dans les packs documentaires',
      requiresServerMetering: true),
    CommercialFeatureRule(code: 'maintenance_plan', name: 'Plan entretien actualisé',
      free: 'Quota à définir', subscription: 'Quota à définir',
      singlePurchase: 'Pas compris dans les packs documentaires',
      requiresServerMetering: true),
    CommercialFeatureRule(code: 'smart_trip', name: 'Assistant trajet',
      free: 'Quota à définir', subscription: 'Quota à définir',
      singlePurchase: 'Pas compris dans les packs documentaires',
      requiresServerMetering: true),
    CommercialFeatureRule(code: 'legal', name: 'Assistant litiges',
      free: 'Quota à définir', subscription: 'Quota à définir',
      singlePurchase: 'Pas compris dans les packs documentaires',
      requiresServerMetering: true),
    CommercialFeatureRule(code: 'emergency', name: 'Assistant urgence',
      free: 'Consignes critiques accessibles ; analyse IA à limiter',
      subscription: 'Analyse IA à limiter',
      singlePurchase: 'Pas compris dans les packs documentaires',
      requiresServerMetering: true),
    CommercialFeatureRule(code: 'identification', name: 'Identification véhicule',
      free: 'Quota API à définir', subscription: 'Quota API à définir',
      singlePurchase: 'Pas compris dans les packs documentaires',
      requiresServerMetering: true),
    CommercialFeatureRule(code: 'valuation', name: 'Cote et actualisation',
      free: 'Quota fournisseur à définir',
      subscription: 'Quota fournisseur à définir',
      singlePurchase: 'Pas compris dans les packs documentaires',
      requiresServerMetering: true),
    CommercialFeatureRule(code: 'recalls', name: 'Rappels constructeur / contrôle technique',
      free: 'Consultation ; actualisations limitées si facturées',
      subscription: 'Consultation ; actualisations limitées si facturées',
      singlePurchase: 'Non concerné',
      requiresServerMetering: true),
    CommercialFeatureRule(code: 'nearby_offers', name: 'Services proches, prix et offres',
      free: 'Consultation selon disponibilité du fournisseur',
      subscription: 'Consultation selon disponibilité du fournisseur',
      singlePurchase: 'Non concerné',
      requiresServerMetering: true),
  ];
}
