class PremiumCatalog {
  const PremiumCatalog._();

  static const entitlementId = 'premium';

  static const freeTitle = 'AutoClair Gratuit';
  static const premiumTitle = 'AutoClair Premium';

  static const freeBenefits = <String>[
    'Gérer votre véhicule et vos documents',
    'Suivre vos échéances et rappels',
    'Utiliser les outils pratiques AutoClair',
    '1 premier Bilan AutoClair 360 offert',
  ];

  static const premiumBenefits = <String>[
    'Bilans AutoClair 360 sans crédit',
    'Synthèse entretien, valeur et revente',
    'Accès tant que votre abonnement est actif',
  ];

  static const monthlyLabel = 'Mensuel';
  static const annualLabel = 'Annuel';
}
