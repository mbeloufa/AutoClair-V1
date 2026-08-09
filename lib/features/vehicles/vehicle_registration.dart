abstract final class VehicleRegistration {
  static final RegExp _siv = RegExp(
    r'^([A-HJ-NP-TV-Z]{2})(\d{3})([A-HJ-NP-TV-Z]{2})$',
  );

  static final RegExp _fni = RegExp(
    r'^(\d{1,4})([A-HJ-NP-TV-Z]{1,3})(\d{2,3})$',
  );

  static String compact(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').trim();
  }

  static bool isSupportedFrenchFormat(String value) {
    final normalized = compact(value);
    return _siv.hasMatch(normalized) || _fni.hasMatch(normalized);
  }

  static String format(String value) {
    final normalized = compact(value);

    final sivMatch = _siv.firstMatch(normalized);
    if (sivMatch != null) {
      return '${sivMatch.group(1)}-${sivMatch.group(2)}-${sivMatch.group(3)}';
    }

    final fniMatch = _fni.firstMatch(normalized);
    if (fniMatch != null) {
      return '${fniMatch.group(1)} ${fniMatch.group(2)} ${fniMatch.group(3)}';
    }

    return value.trim().toUpperCase();
  }

  static String? lookupValidationMessage(String value) {
    if (value.trim().isEmpty) {
      return 'Saisissez une immatriculation.';
    }

    if (!isSupportedFrenchFormat(value)) {
      return 'Format français attendu : AB-123-CD ou ancien format 1234 AB 75.';
    }

    return null;
  }
}
