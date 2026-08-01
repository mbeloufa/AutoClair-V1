abstract final class Validators {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? requiredText(
    String? value, {
    String message = 'Ce champ est obligatoire.',
  }) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? fullName(String? value) {
    final required = requiredText(
      value,
      message: 'Saisissez votre nom complet.',
    );
    if (required != null) {
      return required;
    }
    if (value!.trim().length < 2) {
      return 'Le nom doit contenir au moins 2 caractères.';
    }
    return null;
  }

  static String? email(String? value) {
    final required = requiredText(
      value,
      message: 'Saisissez votre adresse e-mail.',
    );
    if (required != null) {
      return required;
    }
    if (!_emailPattern.hasMatch(value!.trim())) {
      return 'Saisissez une adresse e-mail valide.';
    }
    return null;
  }

  static String? password(String? value) {
    final required = requiredText(
      value,
      message: 'Saisissez votre mot de passe.',
    );
    if (required != null) {
      return required;
    }
    if (value!.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères.';
    }
    return null;
  }
}
