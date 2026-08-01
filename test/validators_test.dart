import 'package:autoclair_app/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.email', () {
    test('refuse une adresse vide', () {
      expect(Validators.email(''), 'Saisissez votre adresse e-mail.');
    });

    test('refuse une adresse invalide', () {
      expect(Validators.email('test'), 'Saisissez une adresse e-mail valide.');
    });

    test('accepte une adresse valide', () {
      expect(Validators.email('test@example.com'), isNull);
    });
  });

  group('Validators.password', () {
    test('refuse moins de huit caractères', () {
      expect(
        Validators.password('1234567'),
        'Le mot de passe doit contenir au moins 8 caractères.',
      );
    });

    test('accepte huit caractères ou plus', () {
      expect(Validators.password('12345678'), isNull);
    });
  });
}
