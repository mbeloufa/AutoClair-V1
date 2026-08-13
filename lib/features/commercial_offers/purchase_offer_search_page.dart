import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'commercial_offer_actions.dart';
import 'commercial_offer_models.dart';
import 'commercial_offers_service.dart';
import 'purchase_offer_search_service.dart';

class PurchaseOfferSearchPage extends StatefulWidget {
  const PurchaseOfferSearchPage({super.key});

  @override
  State<PurchaseOfferSearchPage> createState() =>
      _PurchaseOfferSearchPageState();
}

class _PurchaseOfferSearchPageState extends State<PurchaseOfferSearchPage> {
  final _service = PurchaseOfferSearchService();
  final _modelController = TextEditingController();

  PurchaseOfferSearchBundle? _bundle;
  String? _selectedBrand;
  String _vehicleKind = 'ALL';
  String _fuel = 'ALL';
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.search(
        criteria: PurchaseOfferSearchCriteria(
          brand: _selectedBrand,
          model: _modelController.text,
          fuel: _fuel == 'ALL' ? null : _fuel,
          vehicleKind: _vehicleKind,
        ),
      );
      if (!mounted) return;
      setState(() => _bundle = result);
    } on CommercialOffersException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    _modelController.clear();
    setState(() {
      _selectedBrand = null;
      _vehicleKind = 'ALL';
      _fuel = 'ALL';
    });
    await _search();
  }

  Future<void> _openOffer(CommercialOffer offer) async {
    try {
      final opened = await CommercialOfferActions.openOfficialOffer(
        offer.officialUrl,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Le lien officiel n'a pas pu être ouvert."),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Le lien officiel n'a pas pu être ouvert."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Offres d'achat"),
        actions: [
          IconButton(
            onPressed: _loading ? null : _search,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _search,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const _PurchaseHero(),
            const SizedBox(height: 16),
            _SearchPanel(
              brands: _bundle?.availableBrands ?? const [],
              selectedBrand: _selectedBrand,
              modelController: _modelController,
              vehicleKind: _vehicleKind,
              fuel: _fuel,
              loading: _loading,
              onBrandChanged: (value) => setState(() => _selectedBrand = value),
              onKindChanged: (value) => setState(() => _vehicleKind = value),
              onFuelChanged: (value) => setState(() => _fuel = value),
              onSearch: _search,
              onReset: _reset,
            ),
            if (_loading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 18),
            if (_errorMessage != null)
              _MessagePanel(
                icon: Icons.cloud_off_rounded,
                message: _errorMessage!,
              )
            else if (_bundle != null && _bundle!.offers.isEmpty)
              const _MessagePanel(
                icon: Icons.search_off_rounded,
                message:
                    "Aucune offre de vente ne correspond encore à ces critères. "
                    "Élargissez la recherche ou réessayez après la prochaine collecte.",
              )
            else if (_bundle != null) ...[
              Text(
                _bundle!.totalCount == 1
                    ? '1 offre trouvée'
                    : '${_bundle!.totalCount} offres trouvées',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < _bundle!.offers.length; index++) ...[
                _PurchaseOfferCard(
                  offer: _bundle!.offers[index],
                  onOpen: () => _openOffer(_bundle!.offers[index]),
                ),
                if (index < _bundle!.offers.length - 1)
                  const SizedBox(height: 12),
              ],
            ],
            const SizedBox(height: 18),
            const _MessagePanel(
              icon: Icons.verified_user_outlined,
              message:
                  "Les résultats proviennent des sources suivies par AutoClair. "
                  "Le prix final, la disponibilité, la reprise, le financement et "
                  "l'éligibilité doivent toujours être confirmés sur la source officielle.",
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseHero extends StatelessWidget {
  const _PurchaseHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.search_rounded, color: Colors.white, size: 30),
          SizedBox(height: 12),
          Text(
            "Trouver une offre pour votre prochain véhicule",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            "Cette recherche est indépendante des véhicules déjà enregistrés dans AutoClair.",
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.brands,
    required this.selectedBrand,
    required this.modelController,
    required this.vehicleKind,
    required this.fuel,
    required this.loading,
    required this.onBrandChanged,
    required this.onKindChanged,
    required this.onFuelChanged,
    required this.onSearch,
    required this.onReset,
  });

  final List<String> brands;
  final String? selectedBrand;
  final TextEditingController modelController;
  final String vehicleKind;
  final String fuel;
  final bool loading;
  final ValueChanged<String?> onBrandChanged;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<String> onFuelChanged;
  final VoidCallback onSearch;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final sortedBrands = [...brands]..sort();
    final safeBrand =
        selectedBrand != null && sortedBrands.contains(selectedBrand)
        ? selectedBrand
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Critères de recherche',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String?>(
            key: const ValueKey('purchase-offer-brand-filter'),
            initialValue: safeBrand,
            decoration: const InputDecoration(
              labelText: 'Marque',
              prefixIcon: Icon(Icons.directions_car_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Toutes les marques'),
              ),
              for (final brand in sortedBrands)
                DropdownMenuItem<String?>(value: brand, child: Text(brand)),
            ],
            onChanged: loading ? null : onBrandChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('purchase-offer-model-filter'),
            controller: modelController,
            enabled: !loading,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: const InputDecoration(
              labelText: 'Modèle',
              hintText: 'Ex. A1, 208, Captur…',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('purchase-offer-kind-filter'),
            initialValue: vehicleKind,
            decoration: const InputDecoration(
              labelText: 'Type de véhicule',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('Neuf et occasion')),
              DropdownMenuItem(value: 'NEW', child: Text('Neuf')),
              DropdownMenuItem(value: 'USED', child: Text('Occasion')),
            ],
            onChanged: loading
                ? null
                : (value) => onKindChanged(value ?? 'ALL'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('purchase-offer-fuel-filter'),
            initialValue: fuel,
            decoration: const InputDecoration(
              labelText: 'Énergie',
              prefixIcon: Icon(Icons.local_gas_station_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'ALL',
                child: Text('Toutes les énergies'),
              ),
              DropdownMenuItem(value: 'petrol', child: Text('Essence')),
              DropdownMenuItem(value: 'diesel', child: Text('Diesel')),
              DropdownMenuItem(value: 'hybrid', child: Text('Hybride')),
              DropdownMenuItem(
                value: 'plug_in_hybrid',
                child: Text('Hybride rechargeable'),
              ),
              DropdownMenuItem(value: 'electric', child: Text('Électrique')),
            ],
            onChanged: loading
                ? null
                : (value) => onFuelChanged(value ?? 'ALL'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('purchase-offer-search-button'),
            onPressed: loading ? null : onSearch,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Rechercher les offres'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: loading ? null : onReset,
            child: const Text('Réinitialiser les critères'),
          ),
        ],
      ),
    );
  }
}

class _PurchaseOfferCard extends StatelessWidget {
  const _PurchaseOfferCard({required this.offer, required this.onOpen});

  final CommercialOffer offer;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final conditions = offer.conditionsPreview;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final badge in offer.purchaseBadgeLabels) _Tag(label: badge),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            offer.clearBenefitLabel,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            offer.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (offer.priceAmount != null) ...[
            const SizedBox(height: 6),
            Text(
              'Prix affiché : ${offer.priceLabel}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
          if (conditions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conditions essentielles',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conditions,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            offer.validityLabel,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Voir l’offre officielle'),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.softPrimary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
