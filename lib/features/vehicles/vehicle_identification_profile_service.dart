import 'package:supabase_flutter/supabase_flutter.dart';

import 'vehicle_identification_profile.dart';

class VehicleIdentificationProfileService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<VehicleIdentificationProfile?> fetchForVehicle(
    String vehicleId,
  ) async {
    try {
      final data = await _client
          .from('vehicle_identification_profiles')
          .select(
            'id,vehicle_id,registration_number,vin,source_label,retrieved_at,'
            'identity,technical,administrative,aftersales,media',
          )
          .eq('vehicle_id', vehicleId)
          .order('retrieved_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;
      return VehicleIdentificationProfile.fromMap(data);
    } on PostgrestException {
      return null;
    } on FormatException {
      return null;
    }
  }
}
