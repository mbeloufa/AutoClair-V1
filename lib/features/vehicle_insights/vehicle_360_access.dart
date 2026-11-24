class Vehicle360Access {
  const Vehicle360Access({
    required this.authenticated,
    required this.entitled,
    required this.creditBalance,
    required this.trialClaimed,
    this.commercialMode = false,
  });

  final bool authenticated;
  final bool entitled;
  final int creditBalance;
  final bool trialClaimed;
  final bool commercialMode;

  bool get canGenerate => entitled || creditBalance > 0;
  bool get trialAvailable => authenticated && !trialClaimed && !entitled;

  String get statusLabel {
    if (entitled) return 'Premium actif';
    if (creditBalance > 1) return '$creditBalance crédits disponibles';
    if (creditBalance == 1) return '1 crédit disponible';
    if (trialAvailable) return '1 essai gratuit disponible';
    return 'Accès Premium requis';
  }

  factory Vehicle360Access.fromMaps({
    required Map<String, dynamic> access,
    required Map<String, dynamic> trial,
    bool commercialMode = false,
    int? commercialBalance,
    bool? commercialTrialClaimed,
  }) {
    return Vehicle360Access(
      authenticated: access['authenticated'] == true,
      entitled: !commercialMode &&
          (access['entitled'] == true || trial['entitled'] == true),
      creditBalance: commercialMode ? (commercialBalance ?? 0) : _intValue(
        trial['credit_balance'] ?? access['credit_balance'],
      ),
      trialClaimed: commercialTrialClaimed ?? trial['trial_claimed'] == true,
      commercialMode: commercialMode,
    );
  }

  Vehicle360Access copyWith({
    bool? authenticated,
    bool? entitled,
    int? creditBalance,
    bool? trialClaimed,
    bool? commercialMode,
  }) {
    return Vehicle360Access(
      authenticated: authenticated ?? this.authenticated,
      entitled: entitled ?? this.entitled,
      creditBalance: creditBalance ?? this.creditBalance,
      trialClaimed: trialClaimed ?? this.trialClaimed,
      commercialMode: commercialMode ?? this.commercialMode,
    );
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
