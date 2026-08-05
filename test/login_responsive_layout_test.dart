import 'package:autoclair_app/features/auth/forgot_password_page.dart';
import 'package:autoclair_app/features/auth/login_page.dart';
import 'package:autoclair_app/features/auth/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpAuthPage(
  WidgetTester tester, {
  required Widget page,
  required Size size,
}) async {
  await tester.binding.setSurfaceSize(size);

  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();

  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('login stays responsive at 280 and 320 pixels', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAuthPage(
      tester,
      page: const LoginPage(),
      size: const Size(280, 568),
    );
    expect(find.text('Créer un compte'), findsOneWidget);

    await _pumpAuthPage(
      tester,
      page: const LoginPage(),
      size: const Size(320, 568),
    );
    expect(find.text('Accéder à mon espace'), findsOneWidget);
  });

  testWidgets('registration stays responsive at 280 pixels', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAuthPage(
      tester,
      page: const RegisterPage(),
      size: const Size(280, 640),
    );

    expect(find.text('Créer mon compte'), findsWidgets);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('forgotten password stays responsive at 280 pixels', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAuthPage(
      tester,
      page: const ForgotPasswordPage(),
      size: const Size(280, 568),
    );

    expect(find.text('Envoyer le lien'), findsOneWidget);
    expect(find.text('Retour à la connexion'), findsOneWidget);
  });
}
