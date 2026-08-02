import 'package:url_launcher/url_launcher.dart';

import 'technical_control_offer.dart';

class TechnicalControlActions {
  static Future<bool> callCenter(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) return Future.value(false);

    return launchUrl(Uri(scheme: 'tel', path: normalized));
  }

  static Future<bool> openWebsite(String website) {
    final trimmed = website.trim();
    if (trimmed.isEmpty) return Future.value(false);

    final normalized =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return Future.value(false);

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openDirections(TechnicalControlOffer offer) {
    final latitude = offer.latitude;
    final longitude = offer.longitude;
    if (latitude == null || longitude == null) {
      return Future.value(false);
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    });

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
