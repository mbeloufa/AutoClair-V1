enum SavingStatus {
  detected,
  accepted,
  confirmed,
  rejected,
  expired;

  String get databaseValue => name.toUpperCase();

  String get label => switch (this) {
    SavingStatus.detected => 'Potentielle',
    SavingStatus.accepted => 'Acceptée',
    SavingStatus.confirmed => 'Confirmée',
    SavingStatus.rejected => 'Écartée',
    SavingStatus.expired => 'Expirée',
  };

  static SavingStatus fromDatabase(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return SavingStatus.values.firstWhere(
      (status) => status.name == normalized,
      orElse: () => SavingStatus.detected,
    );
  }
}
