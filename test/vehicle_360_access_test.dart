import 'package:autoclair_app/features/vehicle_insights/vehicle_360_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('premium entitlement grants access without consuming a credit', () {
    final access = Vehicle360Access.fromMaps(
      access: {'authenticated': true, 'entitled': true, 'credit_balance': 0},
      trial: {'entitled': true, 'credit_balance': 0, 'trial_claimed': true},
    );

    expect(access.canGenerate, isTrue);
    expect(access.entitled, isTrue);
    expect(access.statusLabel, 'Premium actif');
  });

  test('one credit grants access and reports the remaining balance', () {
    final access = Vehicle360Access.fromMaps(
      access: {'authenticated': true, 'entitled': false, 'credit_balance': 1},
      trial: {'entitled': false, 'credit_balance': 1, 'trial_claimed': true},
    );

    expect(access.canGenerate, isTrue);
    expect(access.creditBalance, 1);
    expect(access.statusLabel, '1 crédit disponible');
  });

  test('new account exposes one trial without pretending it is premium', () {
    final access = Vehicle360Access.fromMaps(
      access: {'authenticated': true, 'entitled': false, 'credit_balance': 0},
      trial: {'entitled': false, 'credit_balance': 0, 'trial_claimed': false},
    );

    expect(access.canGenerate, isFalse);
    expect(access.trialAvailable, isTrue);
    expect(access.statusLabel, '1 essai gratuit disponible');
  });

  test('used trial without credit requires premium access', () {
    final access = Vehicle360Access.fromMaps(
      access: {'authenticated': true, 'entitled': false, 'credit_balance': 0},
      trial: {'entitled': false, 'credit_balance': 0, 'trial_claimed': true},
    );

    expect(access.canGenerate, isFalse);
    expect(access.trialAvailable, isFalse);
    expect(access.statusLabel, 'Accès Premium requis');
  });
}
