class TechnicalControlCatalogOption {
  const TechnicalControlCatalogOption({required this.id, required this.label});

  final String id;
  final String label;
}

class TechnicalControlCatalog {
  const TechnicalControlCatalog({
    required this.vehicleCategories,
    required this.energyCategories,
  });

  final List<TechnicalControlCatalogOption> vehicleCategories;
  final List<TechnicalControlCatalogOption> energyCategories;
}
