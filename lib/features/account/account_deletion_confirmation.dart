abstract final class AccountDeletionConfirmation {
  static const requiredPhrase = 'SUPPRIMER MON COMPTE';

  static String? validateEmail({
    required String? value,
    required String expectedEmail,
  }) {
    final entered = value?.trim().toLowerCase() ?? '';
    final expected = expectedEmail.trim().toLowerCase();

    if (entered.isEmpty) {
      return 'Saisissez votre adresse e-mail.';
    }

    if (entered != expected) {
      return "L'adresse e-mail ne correspond pas au compte connecté.";
    }

    return null;
  }

  static String? validatePhrase(String? value) {
    final entered = value?.trim() ?? '';

    if (entered.isEmpty) {
      return 'Saisissez la phrase de confirmation.';
    }

    if (entered != requiredPhrase) {
      return 'La phrase doit être saisie exactement comme indiqué.';
    }

    return null;
  }
}
