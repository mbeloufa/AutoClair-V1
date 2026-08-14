import 'package:supabase_flutter/supabase_flutter.dart';
import 'smart_trip_models.dart';

class SmartTripException implements Exception {
  const SmartTripException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SmartTripService {
  SmartTripService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;
  Future<SmartTripResult> analyze({
    required String vehicleId,
    required Map<String, dynamic> origin,
    required Map<String, dynamic> destination,
    required double consumptionPer100,
    required double energyPrice,
    required int maxExtraMinutes,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'analyze-smart-trip',
        body: {
          'vehicle_id': vehicleId,
          'origin': origin,
          'destination': destination,
          'consumption_per_100': consumptionPer100,
          'energy_price': energyPrice,
          'max_extra_minutes': maxExtraMinutes,
        },
      );
      final raw = response.data;
      if (raw is! Map) {
        throw const SmartTripException(
          'Le service trajet a renvoyé une réponse illisible.',
        );
      }
      final data = Map<String, dynamic>.from(raw);
      if (data['success'] != true) {
        throw SmartTripException(_message(data['error']?.toString()));
      }
      return SmartTripResult.fromJson(data);
    } on SmartTripException {
      rethrow;
    } catch (error) {
      final text = error.toString();
      for (final code in const [
        'AUTH_REQUIRED',
        'VEHICLE_NOT_FOUND',
        'INVALID_FINANCIAL_INPUT',
        'PLACE_REQUIRED',
        'PLACE_NOT_FOUND',
        'NO_ROUTE',
        'EV_NOT_SUPPORTED_V1',
        'SMART_TRIP_NOT_CONFIGURED',
        'ROUTING_CONFIGURATION_ERROR',
        'ROUTING_TEMPORARILY_BUSY',
        'ROUTING_TIMEOUT',
        'ROUTING_SERVICE_ERROR',
      ]) {
        if (text.contains(code)) {
          throw SmartTripException(_message(code));
        }
      }
      throw const SmartTripException(
        'Le calcul du trajet est momentanément indisponible.',
      );
    }
  }

  static String _message(String? code) => switch (code) {
    'AUTH_REQUIRED' => 'Votre session a expiré. Reconnectez-vous.',
    'VEHICLE_NOT_FOUND' => 'Le véhicule sélectionné n’est plus disponible.',
    'INVALID_FINANCIAL_INPUT' =>
      'Vérifiez la consommation, le prix de l’énergie et le temps accepté.',
    'PLACE_REQUIRED' => 'Renseignez le départ et la destination.',
    'PLACE_NOT_FOUND' => 'AutoClair n’a pas trouvé l’un des lieux indiqués.',
    'NO_ROUTE' => 'Aucun trajet routier exploitable n’a été trouvé.',
    'EV_NOT_SUPPORTED_V1' =>
      'La V1 électrique intégrera autonomie, recharge et prix des bornes. AutoClair préfère ne pas afficher un calcul incomplet.',
    'SMART_TRIP_NOT_CONFIGURED' || 'ROUTING_CONFIGURATION_ERROR' =>
      'Le service Trajet intelligent n’est pas encore configuré.',
    'ROUTING_TEMPORARILY_BUSY' || 'ROUTING_TIMEOUT' =>
      'Le calcul routier est très sollicité. Réessayez dans quelques instants.',
    'ROUTING_SERVICE_ERROR' =>
      'Le fournisseur d’itinéraires est momentanément indisponible.',
    _ => 'Le calcul du trajet est momentanément indisponible.',
  };
}
