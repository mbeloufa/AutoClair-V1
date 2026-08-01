import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/app_controller.dart';
import 'core/config/app_env.dart';
import 'core/storage/onboarding_store.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppEnv.isConfigured) {
    runApp(const _ConfigurationErrorApp());
    return;
  }

  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    publishableKey: AppEnv.supabasePublishableKey,
  );

  final onboardingStore = OnboardingStore();
  final onboardingCompleted = await onboardingStore.isCompleted();

  final controller = AppController(
    supabase: Supabase.instance.client,
    onboardingStore: onboardingStore,
    onboardingCompleted: onboardingCompleted,
  );

  runApp(AutoClairApp(controller: controller));
}

class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoClair',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.settings_suggest_outlined,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Configuration Supabase manquante',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Lance l’application avec les variables '
                      'SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY. '
                      'Le fichier README.md contient la commande exacte.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
