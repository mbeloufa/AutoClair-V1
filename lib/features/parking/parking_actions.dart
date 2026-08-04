import 'package:url_launcher/url_launcher.dart';

import 'parking_offer.dart';

class ParkingActions {
  static Future<bool> openDirections(ParkingOffer offer) {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${offer.latitude},${offer.longitude}',
    });

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> callOperator(ParkingOffer offer) {
    final phone = offer.phone?.trim();
    if (phone == null || phone.isEmpty) return Future.value(false);
    return launchUrl(Uri(scheme: 'tel', path: phone));
  }

  static Future<bool> openWebsite(ParkingOffer offer) {
    final value = offer.website?.trim();
    if (value == null || value.isEmpty) return Future.value(false);

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return Future.value(false);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
