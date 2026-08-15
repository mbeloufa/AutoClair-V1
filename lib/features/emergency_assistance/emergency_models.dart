import 'emergency_safety_engine.dart';

enum EmergencyRoadContext { unknown, parking, city, road, motorway }

extension EmergencyRoadContextX on EmergencyRoadContext {
  String get dbValue => switch (this) {
    EmergencyRoadContext.unknown => 'unknown',
    EmergencyRoadContext.parking => 'parking',
    EmergencyRoadContext.city => 'city',
    EmergencyRoadContext.road => 'road',
    EmergencyRoadContext.motorway => 'motorway',
  };

  String get label => switch (this) {
    EmergencyRoadContext.unknown => 'Je ne sais pas',
    EmergencyRoadContext.parking => 'Parking / lieu privé',
    EmergencyRoadContext.city => 'Ville',
    EmergencyRoadContext.road => 'Route',
    EmergencyRoadContext.motorway => 'Autoroute / voie rapide',
  };
}

class EmergencyVehicleOption {
  const EmergencyVehicleOption({
    required this.id,
    required this.displayName,
    required this.make,
    required this.model,
    this.registrationNumber,
    this.mileage,
    this.year,
    this.fuelType,
  });

  final String id;
  final String displayName;
  final String make;
  final String model;
  final String? registrationNumber;
  final int? mileage;
  final int? year;
  final String? fuelType;

  factory EmergencyVehicleOption.fromMap(Map<String, dynamic> map) {
    final nickname = (map['nickname'] as String?)?.trim();
    final make = (map['make'] as String? ?? '').trim();
    final model = (map['model'] as String? ?? '').trim();
    final fallback = '$make $model'.trim();
    return EmergencyVehicleOption(
      id: map['id'].toString(),
      displayName: nickname?.isNotEmpty == true ? nickname! : fallback,
      make: make,
      model: model,
      registrationNumber: (map['registration_number'] as String?)?.trim(),
      mileage: (map['mileage'] as num?)?.round(),
      year: (map['vehicle_year'] as num?)?.round(),
      fuelType: (map['fuel_type'] as String?)?.trim(),
    );
  }
}

class EmergencyAssistanceProfile {
  const EmergencyAssistanceProfile({
    required this.providerName,
    required this.phoneNumber,
    required this.contractNumber,
    required this.coverageNote,
  });

  final String providerName;
  final String phoneNumber;
  final String contractNumber;
  final String coverageNote;

  bool get hasPhone => phoneNumber.trim().isNotEmpty;

  factory EmergencyAssistanceProfile.fromMap(Map<String, dynamic>? map) =>
      EmergencyAssistanceProfile(
        providerName: map?['provider_name']?.toString() ?? '',
        phoneNumber: map?['phone_number']?.toString() ?? '',
        contractNumber: map?['contract_number']?.toString() ?? '',
        coverageNote: map?['coverage_note']?.toString() ?? '',
      );

  static const empty = EmergencyAssistanceProfile(
    providerName: '',
    phoneNumber: '',
    contractNumber: '',
    coverageNote: '',
  );
}

class EmergencyAction {
  const EmergencyAction({
    required this.priority,
    required this.title,
    required this.description,
  });

  final int priority;
  final String title;
  final String description;

  factory EmergencyAction.fromMap(Map<String, dynamic> map) => EmergencyAction(
    priority: (map['priority'] as num?)?.round() ?? 99,
    title: map['title']?.toString() ?? '',
    description: map['description']?.toString() ?? '',
  );
}

class EmergencyAssessmentResult {
  const EmergencyAssessmentResult({
    required this.status,
    required this.level,
    required this.headline,
    required this.summary,
    required this.reasons,
    required this.actions,
    required this.followUpQuestions,
    required this.imageObservations,
    required this.uncertainties,
    required this.callEmergencyServices,
    required this.audioNote,
    required this.disclaimer,
  });

  final String status;
  final EmergencySafetyLevel level;
  final String headline;
  final String summary;
  final List<String> reasons;
  final List<EmergencyAction> actions;
  final List<String> followUpQuestions;
  final List<String> imageObservations;
  final List<String> uncertainties;
  final bool callEmergencyServices;
  final String audioNote;
  final String disclaimer;

  bool get needsInformation =>
      status == 'needs_information' && followUpQuestions.isNotEmpty;

  factory EmergencyAssessmentResult.fromMap(Map<String, dynamic> map) {
    List<String> strings(String key) => (map[key] as List? ?? const [])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    final actions =
        (map['actions'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (value) =>
                  EmergencyAction.fromMap(Map<String, dynamic>.from(value)),
            )
            .toList(growable: false)
          ..sort((a, b) => a.priority.compareTo(b.priority));

    return EmergencyAssessmentResult(
      status: map['status']?.toString() ?? 'needs_information',
      level: EmergencySafetyLevelX.fromDbValue(
        map['safety_level']?.toString() ?? 'prompt_check',
      ),
      headline: map['headline']?.toString() ?? 'Assistance immédiate',
      summary: map['summary']?.toString() ?? '',
      reasons: strings('reasons'),
      actions: actions,
      followUpQuestions: strings('follow_up_questions'),
      imageObservations: strings('image_observations'),
      uncertainties: strings('uncertainties'),
      callEmergencyServices: map['call_emergency_services'] == true,
      audioNote: map['audio_note']?.toString() ?? '',
      disclaimer: map['disclaimer']?.toString() ?? '',
    );
  }
}

class EmergencyPendingMedia {
  const EmergencyPendingMedia({
    required this.kind,
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final String kind;
  final List<int> bytes;
  final String fileName;
  final String mimeType;

  bool get isPhoto => kind == 'photo';
  bool get isAudio => kind == 'audio';
}
