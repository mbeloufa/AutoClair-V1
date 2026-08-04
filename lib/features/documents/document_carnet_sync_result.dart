class DocumentCarnetSyncResult {
  const DocumentCarnetSyncResult({
    required this.status,
    required this.message,
    required this.userConfirmationRequired,
    required this.userConfirmed,
    required this.suggestionCount,
    this.vehicleId,
    this.eventId,
    this.eventTitle,
    this.reasonCode,
    this.matchMethod,
    this.matchScore,
    this.suggestionPreparationFailed = false,
  });

  final String status;
  final String message;
  final bool userConfirmationRequired;
  final bool userConfirmed;
  final int suggestionCount;
  final String? vehicleId;
  final String? eventId;
  final String? eventTitle;
  final String? reasonCode;
  final String? matchMethod;
  final double? matchScore;
  final bool suggestionPreparationFailed;

  bool get wasAutomaticallyAdded =>
      status == 'AUTO_CREATED' || status == 'ALREADY_CREATED';

  bool get needsReview => status == 'REVIEW_REQUIRED';

  bool get isNotApplicable =>
      status == 'NOT_APPLICABLE' || status == 'NO_EVENT_DETECTED';

  bool get canOpenCarnet => vehicleId != null && vehicleId!.isNotEmpty;

  String get matchLabel {
    return switch (matchMethod) {
      'VIN_EXACT' => 'VIN identique',
      'REGISTRATION_EXACT' => 'Immatriculation identique',
      'VIN_AND_REGISTRATION_EXACT' => 'VIN et immatriculation identiques',
      'MAKE_MODEL_MATCH' => 'Marque et modèle concordants',
      'SELECTED_VEHICLE_ONLY' => 'Véhicule sélectionné uniquement',
      _ => 'Correspondance non déterminée',
    };
  }

  factory DocumentCarnetSyncResult.fromMap(Map<String, dynamic> map) {
    return DocumentCarnetSyncResult(
      status: map['status']?.toString().trim() ?? 'UNKNOWN',
      message:
          map['message']?.toString().trim() ??
          'Le rattachement au carnet n’a pas pu être déterminé.',
      userConfirmationRequired: map['user_confirmation_required'] == true,
      userConfirmed: map['user_confirmed'] == true,
      suggestionCount: _integer(map['suggestion_count']),
      vehicleId: _optionalText(map['vehicle_id']),
      eventId: _optionalText(map['event_id']),
      eventTitle: _optionalText(map['event_title']),
      reasonCode: _optionalText(map['reason_code']),
      matchMethod: _optionalText(map['match_method']),
      matchScore: _decimal(map['match_score']),
      suggestionPreparationFailed: map['suggestion_preparation_failed'] == true,
    );
  }

  DocumentCarnetSyncResult copyWith({
    int? suggestionCount,
    bool? suggestionPreparationFailed,
    String? message,
  }) {
    return DocumentCarnetSyncResult(
      status: status,
      message: message ?? this.message,
      userConfirmationRequired: userConfirmationRequired,
      userConfirmed: userConfirmed,
      suggestionCount: suggestionCount ?? this.suggestionCount,
      vehicleId: vehicleId,
      eventId: eventId,
      eventTitle: eventTitle,
      reasonCode: reasonCode,
      matchMethod: matchMethod,
      matchScore: matchScore,
      suggestionPreparationFailed:
          suggestionPreparationFailed ?? this.suggestionPreparationFailed,
    );
  }

  static int _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _decimal(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
