import 'package:url_launcher/url_launcher.dart';

import 'charging_station_offer.dart';

class ChargingActions {
  static Future<bool> openDirections(ChargingStationOffer offer) {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${offer.latitude},${offer.longitude}',
    });
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> callOperator(ChargingStationOffer offer) {
    final phone = offer.operatorPhone?.replaceAll(RegExp(r'[^+0-9]'), '');
    if (phone == null || phone.isEmpty) return Future.value(false);
    return launchUrl(Uri(scheme: 'tel', path: phone));
  }
}
