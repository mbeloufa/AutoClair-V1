import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'storage/onboarding_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    required SupabaseClient supabase,
    required OnboardingStore onboardingStore,
    required bool onboardingCompleted,
  }) : _supabase = supabase,
       _onboardingStore = onboardingStore,
       _onboardingCompleted = onboardingCompleted,
       _session = supabase.auth.currentSession {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((event) {
      _session = event.session;
      notifyListeners();
    });
  }

  final SupabaseClient _supabase;
  final OnboardingStore _onboardingStore;

  StreamSubscription<AuthState>? _authSubscription;
  Session? _session;
  bool _onboardingCompleted;

  bool get isAuthenticated => _session != null;
  bool get onboardingCompleted => _onboardingCompleted;

  Future<void> completeOnboarding() async {
    await _onboardingStore.setCompleted(true);
    _onboardingCompleted = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
