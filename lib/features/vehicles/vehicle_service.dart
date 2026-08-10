import 'package:supabase_flutter/supabase_flutter.dart';

import 'vehicle.dart';

class VehicleServiceException implements Exception {
  const VehicleServiceException(this.message);

  final String message;
}

class VehicleService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Vehicle>> fetchVehicles() async {
    try {
      final data = await _client
          .from('vehicles')
          .select()
          .order('is_primary', ascending: false)
          .order('created_at', ascending: true);

      return (data as List<dynamic>)
          .map((row) => Vehicle.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } catch (error) {
      throw VehicleServiceException(_message(error));
    }
  }

  Future<Vehicle> fetchVehicle(String vehicleId) async {
    try {
      final data = await _client
          .from('vehicles')
          .select()
          .eq('id', vehicleId)
          .single();

      return Vehicle.fromJson(Map<String, dynamic>.from(data));
    } catch (error) {
      throw VehicleServiceException(_message(error));
    }
  }

  Future<Vehicle> saveVehicle({
    String? vehicleId,
    required String make,
    required String model,
    String? nickname,
    int? vehicleYear,
    DateTime? firstRegistrationDate,
    String? fuelType,
    int? mileage,
    String? registrationNumber,
    String? vin,
    required bool isPrimary,
  }) async {
    try {
      final data = await _client.rpc(
        'save_vehicle',
        params: {
          'p_make': make.trim(),
          'p_model': model.trim(),
          'p_vehicle_id': vehicleId,
          'p_nickname': _nullIfEmpty(nickname),
          'p_vehicle_year': vehicleYear,
          'p_fuel_type': _nullIfEmpty(fuelType),
          'p_mileage': mileage,
          'p_registration_number': _nullIfEmpty(registrationNumber),
          'p_vin': _nullIfEmpty(vin),
          'p_is_primary': isPrimary,
        },
      );

      late final Vehicle savedVehicle;
      if (data is List && data.isNotEmpty) {
        savedVehicle = Vehicle.fromJson(
          Map<String, dynamic>.from(data.first as Map),
        );
      } else if (data is Map) {
        savedVehicle = Vehicle.fromJson(Map<String, dynamic>.from(data));
      } else {
        throw const VehicleServiceException(
          "Le serveur n'a pas renvoyé le véhicule enregistré.",
        );
      }

      await _client.rpc(
        'set_vehicle_first_registration_date',
        params: {
          'p_vehicle_id': savedVehicle.id,
          'p_first_registration_date': _dateOnly(firstRegistrationDate),
        },
      );

      await _client.rpc(
        'match_vehicle_recalls',
        params: {'p_vehicle_id': savedVehicle.id},
      );

      return fetchVehicle(savedVehicle.id);
    } on VehicleServiceException {
      rethrow;
    } catch (error) {
      throw VehicleServiceException(_message(error));
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    try {
      await _client.rpc('delete_vehicle', params: {'p_vehicle_id': vehicleId});
    } catch (error) {
      throw VehicleServiceException(_message(error));
    }
  }

  static String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  static String? _nullIfEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _message(Object error) {
    final rawMessage = switch (error) {
      PostgrestException() => error.message,
      _ => error.toString(),
    };

    final normalized = rawMessage.toLowerCase();

    if (rawMessage.contains('VEHICLE_MAKE_REQUIRED')) {
      return 'Saisissez la marque du véhicule.';
    }
    if (rawMessage.contains('VEHICLE_MODEL_REQUIRED')) {
      return 'Saisissez le modèle du véhicule.';
    }
    if (rawMessage.contains('VEHICLE_YEAR_INVALID')) {
      return "L'année du véhicule est invalide.";
    }
    if (rawMessage.contains('VEHICLE_MILEAGE_INVALID')) {
      return 'Le kilométrage doit être positif.';
    }
    if (rawMessage.contains('VEHICLE_VIN_INVALID')) {
      return 'Le VIN doit contenir exactement 17 caractères.';
    }
    if (rawMessage.contains('VEHICLE_NOT_FOUND')) {
      return "Ce véhicule n'existe plus ou ne vous appartient pas.";
    }
    if (rawMessage.contains('AUTH_REQUIRED')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (normalized.contains('vehicles_unique_registration_per_user')) {
      return 'Cette immatriculation est déjà associée à un de vos véhicules.';
    }
    if (normalized.contains('vehicles_unique_vin_per_user')) {
      return 'Ce VIN est déjà associé à un de vos véhicules.';
    }
    if (normalized.contains('duplicate key value')) {
      return 'Un véhicule possédant ces informations existe déjà.';
    }

    return 'Une erreur est survenue pendant le traitement du véhicule.';
  }
}
