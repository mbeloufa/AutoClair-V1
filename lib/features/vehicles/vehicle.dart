class Vehicle {
  const Vehicle({
    required this.id,
    required this.userId,
    required this.make,
    required this.model,
    required this.isPrimary,
    required this.createdAt,
    required this.updatedAt,
    this.nickname,
    this.vehicleYear,
    this.firstRegistrationDate,
    this.fuelType,
    this.mileage,
    this.registrationNumber,
    this.vin,
  });

  final String id;
  final String userId;
  final String? nickname;
  final String make;
  final String model;
  final int? vehicleYear;
  final DateTime? firstRegistrationDate;
  final String? fuelType;
  final int? mileage;
  final String? registrationNumber;
  final String? vin;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName {
    final customName = nickname?.trim();
    if (customName != null && customName.isNotEmpty) {
      return customName;
    }
    return '$make $model';
  }

  String get makeAndModel => '$make $model';

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      nickname: json['nickname'] as String?,
      make: json['make'] as String,
      model: json['model'] as String,
      vehicleYear: (json['vehicle_year'] as num?)?.toInt(),
      firstRegistrationDate: DateTime.tryParse(
        json['first_registration_date']?.toString() ?? '',
      ),
      fuelType: json['fuel_type'] as String?,
      mileage: (json['mileage'] as num?)?.toInt(),
      registrationNumber: json['registration_number'] as String?,
      vin: json['vin'] as String?,
      isPrimary: json['is_primary'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
