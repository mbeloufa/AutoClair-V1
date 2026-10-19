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

class PackOffer {
  const PackOffer({
    required this.product,
    required this.catalog,
    required this.quantity,
  });

  final StoreProduct product;
  final CommercialProduct catalog;
  final int quantity;

  String get price => product.priceString;
}

class PremiumState {
  const PremiumState({
    required this.configured,
    required this.active,
    required this.offers,
    this.managementUrl,
    this.message,
    this.packOffers = const <PackOffer>[],
    this.balances = const <String, dynamic>{},
  });

  final bool configured;
  final bool active;
  final List<PremiumOffer> offers;
  final String? managementUrl;
  final String? message;
  final List<PackOffer> packOffers;
  final Map<String, dynamic> balances;
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

      final annual = current?.annual;
      if (annual != null) {
        offers.add(
          PremiumOffer(package: annual, label: PremiumCatalog.annualLabel),
        );
      }

      final packOffers = <PackOffer>[];
      Map<String, dynamic> balances = const <String, dynamic>{};
      try {
        final rows = await _client
            .from('commercial_products')
            .select('code,store_product_id,quantity,active')
            .eq('active', true)
            .eq('kind', 'consumable');
        final wanted = <String, (CommercialProduct, int)>{};
        for (final row in rows) {
          final code = row['code']?.toString() ?? '';
          final id = row['store_product_id']?.toString() ?? '';
          final count = row['quantity'];
          if (id.isEmpty || count is! int || count <= 0) continue;
          for (final pack in PremiumCatalog.packs) {
            if (pack.code == code) wanted[id] = (pack, count);
          }
        }
        if (wanted.isNotEmpty) {
          final products = await Purchases.getProducts(
            wanted.keys.toList(),
            productCategory: ProductCategory.nonSubscription,
          );
          for (final product in products) {
            final config = wanted[product.identifier];
            if (config == null) continue;
            packOffers.add(PackOffer(
              product: product,
              catalog: config.$1,
              quantity: config.$2,
            ));
          }
        }
        final result = await _client.rpc('get_commercial_balances');
        if (result is Map) balances = Map<String, dynamic>.from(result);
      } catch (_) {
        // Versions serveur plus anciennes : achats bloqués, solde non inventé.
      }

      return PremiumState(
        packOffers: List<PackOffer>.unmodifiable(packOffers),
        balances: balances,
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
    if (!PremiumCatalog.checkoutEnabled) {
      throw const PremiumException(
        'Les achats ouvriront après validation des quotas et des crédits serveur.',
      );
    }
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
      return await load();
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

  /// Les packs sont des consommables : ils ne donnent jamais Premium.
  /// Le solde utilisable provient exclusivement de la réconciliation serveur.
  Future<PremiumState> purchasePack(PackOffer offer) async {
    if (!PremiumCatalog.checkoutEnabled) {
      throw const PremiumException('Les achats ponctuels ne sont pas encore ouverts.');
    }
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const PremiumException('Reconnectez-vous pour acheter un pack.');
    }
    try {
      await _ensureConfigured(user.id);
      await Purchases.purchase(PurchaseParams.storeProduct(offer.product));
      final response = await _client.functions.invoke('sync-commercial-purchases');
      if (response.status < 200 || response.status >= 300 ||
          response.data is! Map ||
          (response.data as Map)['success'] != true) {
        throw const PremiumException(
          'Achat reçu. Attribution des crédits en attente. '
          'Vous pourrez les récupérer dans « Restaurer mes achats ».',
        );
      }
      return await load();
    } on PlatformException catch (error) {
      if (PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError) {
        throw const PremiumPurchaseCancelled();
      }
      throw const PremiumException('Achat non finalisé. Vérifiez votre Store.');
    } on PremiumException {
      rethrow;
    } catch (_) {
      throw const PremiumException(
        'Achat en attente de synchronisation. '
        'Retrouvez-le depuis votre compte.',
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
      try {
        await _client.functions.invoke('sync-commercial-purchases');
      } catch (_) {
        // Ne jamais recréditer localement : réconciliation asynchrone.
      }
      return await load();
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
