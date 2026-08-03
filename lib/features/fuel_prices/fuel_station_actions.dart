import 'package:url_launcher/url_launcher.dart';

import 'fuel_station_offer.dart';

class FuelStationActions {
  static Future<bool> openDirections(FuelStationOffer offer) {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${offer.latitude},${offer.longitude}',
    });

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
