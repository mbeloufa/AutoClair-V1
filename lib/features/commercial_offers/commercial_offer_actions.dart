import 'package:url_launcher/url_launcher.dart';

class CommercialOfferActions {
  const CommercialOfferActions._();

  static Future<bool> openOfficialOffer(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());

    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return false;
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
