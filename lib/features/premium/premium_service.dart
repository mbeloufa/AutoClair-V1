import 'dart:io';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'premium_catalog.dart';

class PremiumException implements Exception {
  const PremiumException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PremiumPurchaseCancelled extends PremiumException {
  const PremiumPurchaseCancelled() : super('Achat annulé.');
}

class PremiumOffer {
  const PremiumOffer({required this.package, required this.label});

  final Package package;
  final String label;

  String get price => package.storeProduct.priceString;
}

class PremiumState {
  const PremiumState({
    required this.configured,
    required this.active,
    required this.offers,
    this.managementUrl,
    this.message,
  });

  final bool configured;
  final bool active;
  final List<PremiumOffer> offers;
  final String? managementUrl;
  final String? message;
}

class PremiumService {
  PremiumService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const _iosPublicKey = String.fromEnvironment(
    'REVENUECAT_IOS_PUBLIC_KEY',
  );
  static const _androidPublicKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_PUBLIC_KEY',
  );
  static const _syncFunction = 'sync-premium-entitlement';

  final SupabaseClient _client;

  bool get _mobile => Platform.isIOS || Platform.isAndroid;

  String get _publicKey {
    if (Platform.isIOS) return _iosPublicKey.trim();
    if (Platform.isAndroid) return _androidPublicKey.trim();
    return '';
  }

  Future<PremiumState> load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const PremiumException('Reconnectez-vous pour voir Premium.');
    }

    if (!_mobile || _publicKey.isEmpty) {
      return const PremiumState(
        configured: false,
        active: false,
        offers: <PremiumOffer>[],
        message:
            'Premium sera disponible ici dès que les achats Store seront ouverts.',
      );
    }

    try {
      await _ensureConfigured(user.id);
      final customerInfo = await Purchases.getCustomerInfo();
      await _syncServerBestEffort();

      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      final offers = <PremiumOffer>[];

      final monthly = current?.monthly;
      if (monthly != null) {
        offers.add(
          PremiumOffer(package: monthly, label: PremiumCatalog.monthlyLabel),
        );
      }

      final annual = current?.annual;
      if (annual != null) {
        offers.add(
          PremiumOffer(package: annual, label: PremiumCatalog.annualLabel),
        );
      }

      return PremiumState(
        configured: true,
        active: customerInfo.entitlements.active.containsKey(
          PremiumCatalog.entitlementId,
        ),
        offers: List<PremiumOffer>.unmodifiable(offers),
        managementUrl: customerInfo.managementURL,
        message: current == null
            ? 'Aucune offre Premium n’est disponible sur ce store pour le moment.'
            : null,
      );
    } catch (_) {
      throw const PremiumException(
        'Impossible de charger Premium pour le moment. '
        'Réessayez un peu plus tard.',
      );
    }
  }

  Future<PremiumState> purchase(PremiumOffer offer) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const PremiumException('Reconnectez-vous avant votre achat.');
    }
    if (!_mobile || _publicKey.isEmpty) {
      throw const PremiumException(
        'Les achats Premium ne sont pas encore ouverts.',
      );
    }

    try {
      await _ensureConfigured(user.id);
      final result = await Purchases.purchase(
        PurchaseParams.package(offer.package),
      );
      final active = result.customerInfo.entitlements.active.containsKey(
        PremiumCatalog.entitlementId,
      );
      if (!active) {
        throw const PremiumException(
          'L’achat n’est pas encore confirmé par le store.',
        );
      }

      await _syncServerRequired();
      return load();
    } on PlatformException catch (error) {
      final code = PurchasesErrorHelper.getErrorCode(error);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        throw const PremiumPurchaseCancelled();
      }
      throw const PremiumException(
        'L’achat n’a pas pu être finalisé. '
        'Aucun accès Premium n’est accordé sans confirmation du store.',
      );
    } on PremiumException {
      rethrow;
    } catch (_) {
      throw const PremiumException(
        'L’achat n’a pas pu être finalisé. Réessayez plus tard.',
      );
    }
  }

  Future<PremiumState> restore() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const PremiumException(
        'Reconnectez-vous avant de restaurer vos achats.',
      );
    }
    if (!_mobile || _publicKey.isEmpty) {
      throw const PremiumException(
        'Les achats Premium ne sont pas encore ouverts.',
      );
    }

    try {
      await _ensureConfigured(user.id);
      await Purchases.restorePurchases();
      await _syncServerRequired();
      return load();
    } catch (_) {
      throw const PremiumException(
        'Impossible de restaurer vos achats pour le moment.',
      );
    }
  }

  Future<void> _ensureConfigured(String userId) async {
    final configured = await Purchases.isConfigured;
    if (!configured) {
      final configuration = PurchasesConfiguration(_publicKey)
        ..appUserID = userId
        ..automaticDeviceIdentifierCollectionEnabled = false
        ..diagnosticsEnabled = false;
      await Purchases.configure(configuration);
      return;
    }

    final currentId = await Purchases.appUserID;
    if (currentId != userId) {
      await Purchases.logIn(userId);
    }
  }

  Future<void> _syncServerBestEffort() async {
    try {
      await _syncServerRequired();
    } catch (_) {
      // Le statut local RevenueCat reste affichable, mais AutoClair
      // n accorde jamais un droit serveur invente.
    }
  }

  Future<void> _syncServerRequired() async {
    final response = await _client.functions.invoke(_syncFunction);
    if (response.status < 200 || response.status >= 300) {
      throw const PremiumException(
        'Votre achat est reçu mais sa synchronisation AutoClair '
        'n’est pas terminée. Utilisez « Restaurer mes achats ».',
      );
    }

    final data = response.data;
    if (data is Map && data['configured'] == false) {
      throw const PremiumException(
        'La synchronisation Premium n’est pas encore configurée.',
      );
    }
  }
}
