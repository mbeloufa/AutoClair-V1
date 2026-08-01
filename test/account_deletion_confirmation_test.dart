import 'package:autoclair_app/features/account/account_deletion_confirmation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountDeletionConfirmation', () {
    test('accepte la bonne adresse sans tenir compte de la casse', () {
      final error = AccountDeletionConfirmation.validateEmail(
        value: ' Test@Example.com ',
        expectedEmail: 'test@example.com',
      );

      expect(error, isNull);
    });

    test('refuse une adresse différente', () {
      final error = AccountDeletionConfirmation.validateEmail(
        value: 'autre@example.com',
        expectedEmail: 'test@example.com',
      );

      expect(error, isNotNull);
    });

    test('accepte uniquement la phrase exacte', () {
      expect(
        AccountDeletionConfirmation.validatePhrase(
          AccountDeletionConfirmation.requiredPhrase,
        ),
        isNull,
      );

      expect(
        AccountDeletionConfirmation.validatePhrase('supprimer mon compte'),
        isNotNull,
      );
    });
  });
}
