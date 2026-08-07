import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'commercial_offer_actions.dart';
import 'commercial_offer_vehicle_selector.dart';
import 'commercial_offer_models.dart';
import 'commercial_offers_service.dart';

enum _OfferScope { currentVehicle, purchase }

enum _OfferView { relevant, all, saved }

class CommercialOffersPage extends StatefulWidget {
  const CommercialOffersPage({this.vehicleId, super.key});

  final String? vehicleId;

  @override
  State<CommercialOffersPage> createState() => _CommercialOffersPageState();
}

class _CommercialOffersPageState extends State<CommercialOffersPage> {
  final _vehicleService = VehicleService();
  final _offersService = CommercialOffersService();

  List<Vehicle> _vehicles = const [];
  String? _selectedVehicleId;
  Vehicle? _vehicle;
  CommercialOfferBundle? _bundle;
  bool _loading = true;
  bool _actionInProgress = false;
  bool _initialSelectionResolved = false;
  String? _errorMessage;
  _OfferScope _scope = _OfferScope.currentVehicle;
  _OfferView _view = _OfferView.relevant;
  String _category = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final vehicles = _vehicles.isEmpty
          ? await _vehicleService.fetchVehicles()
          : _vehicles;

      if (vehicles.isEmpty) {
        if (!mounted) return;
        setState(() {
          _vehicles = const [];
          _selectedVehicleId = null;
          _vehicle = null;
          _bundle = null;
          _loading = false;
        });
        return;
      }

      final requestedId = _selectedVehicleId ?? widget.vehicleId;
      final selectedId = vehicles.any((vehicle) => vehicle.id == requestedId)
          ? requestedId!
          : vehicles
                .firstWhere(
                  (vehicle) => vehicle.isPrimary,
                  orElse: () => vehicles.first,
                )
                .id;

      final vehicle = vehicles.firstWhere(
        (candidate) => candidate.id == selectedId,
      );
      final bundle = await _offersService.fetchVehicleOffers(selectedId);

      if (!mounted) return;

      setState(() {
        _vehicles = vehicles;
        _selectedVehicleId = selectedId;
        _vehicle = vehicle;
        _bundle = bundle;

        if (!_initialSelectionResolved) {
          if (bundle.currentVehicleCount > 0) {
            _scope = _OfferScope.currentVehicle;
            _view = bundle.relevantNowCount > 0
                ? _OfferView.relevant
                : _OfferView.all;
          }
          _initialSelectionResolved = true;
        }

        final categories = {
          for (final offer in _offersForScope(bundle)) offer.category,
        };
        if (_category != 'ALL' && !categories.contains(_category)) {
          _category = 'ALL';
        }
      });
    } on VehicleServiceException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on CommercialOffersException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CommercialOffer> _offersForScope(CommercialOfferBundle bundle) {
    return bundle.offers
        .where((offer) => !offer.isPurchaseOffer)
        .toList(growable: false);
  }

  List<CommercialOffer> get _visibleOffers {
    final bundle = _bundle;
    if (bundle == null) return const [];

    return _offersForScope(bundle)
        .where((offer) {
          if (_view == _OfferView.relevant && !offer.relevantNow) {
            return false;
          }
          if (_view == _OfferView.saved && !offer.isSaved) {
            return false;
          }
          if (_category != 'ALL' && offer.category != _category) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  Future<void> _selectVehicle(String vehicleId) async {
    if (vehicleId == _selectedVehicleId || _loading) return;

    setState(() {
      _selectedVehicleId = vehicleId;
      _vehicle = null;
      _bundle = null;
      _category = 'ALL';
      _scope = _OfferScope.currentVehicle;
      _view = _OfferView.relevant;
      _initialSelectionResolved = false;
    });

    await _load();
  }

  Future<void> _toggleSaved(CommercialOffer offer) async {
    await _runAction(() async {
      if (offer.isSaved) {
        await _offersService.unsaveOffer(
          vehicleId: _selectedVehicleId!,
          offerId: offer.id,
        );
      } else {
        await _offersService.saveOffer(
          vehicleId: _selectedVehicleId!,
          offerId: offer.id,
        );
      }

      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              offer.isSaved
                  ? 'Offre retirée des éléments enregistrés.'
                  : 'Offre enregistrée.',
            ),
          ),
        );
      }
    });
  }

  Future<void> _dismiss(CommercialOffer offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Masquer cette offre ?'),
        content: Text(
          '« ${offer.title} » ne sera plus proposée pour '
          '${_vehicle?.displayName ?? 'ce véhicule'}. '
          'Vous pourrez rétablir toutes les offres masquées depuis le menu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Masquer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _runAction(() async {
      await _offersService.dismissOffer(
        vehicleId: _selectedVehicleId!,
        offerId: offer.id,
      );
      await _load();
    });
  }

  Future<void> _resetDismissed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rétablir les offres masquées ?'),
        content: const Text(
          'Les offres encore actives et compatibles pourront de nouveau '
          'apparaître.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Rétablir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _runAction(() async {
      await _offersService.resetDismissedOffers(_selectedVehicleId!);
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offres masquées rétablies.')),
        );
      }
    });
  }

  Future<void> _openOfficialOffer(CommercialOffer offer) async {
    try {
      final opened = await CommercialOfferActions.openOfficialOffer(
        offer.officialUrl,
      );

      if (!opened && mounted) {
        _showMessage(
          "Le lien officiel n'a pas pu être ouvert. "
          'Aucune redirection non sécurisée n’a été utilisée.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage("Le lien officiel n'a pas pu être ouvert.");
      }
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_actionInProgress) return;

    setState(() => _actionInProgress = true);

    try {
      await action();
    } on CommercialOffersException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offres après-vente'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser les résultats',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') _resetDismissed();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restore_rounded),
                    SizedBox(width: 10),
                    Text('Rétablir les offres masquées'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _bundle == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _bundle == null) {
      return _ErrorState(message: _errorMessage!, onRetry: _load);
    }

    if (_vehicles.isEmpty) {
      return const _NoVehicleOffersState();
    }

    final vehicle = _vehicle!;
    final bundle = _bundle!;
    final scopeOffers = _offersForScope(bundle);
    final visibleOffers = _visibleOffers;
    final relevantCount = scopeOffers
        .where((offer) => offer.relevantNow)
        .length;
    final savedCount = scopeOffers.where((offer) => offer.isSaved).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        children: [
          if (_vehicles.length > 1 || widget.vehicleId == null) ...[
            CommercialOfferVehicleSelector(
              vehicles: _vehicles,
              selectedVehicleId: _selectedVehicleId,
              enabled: !_loading && !_actionInProgress,
              onChanged: _selectVehicle,
            ),
            const SizedBox(height: 14),
          ],
          _OffersHero(vehicle: vehicle, scope: _scope, offers: scopeOffers),
          const SizedBox(height: 16),
          _ScopeSelector(currentVehicleCount: bundle.currentVehicleCount),
          const SizedBox(height: 14),
          _GoodSensePanel(scope: _scope),
          const SizedBox(height: 18),
          _ViewSelector(
            selected: _view,
            showRelevant: _scope == _OfferScope.currentVehicle,
            relevantCount: relevantCount,
            totalCount: scopeOffers.length,
            savedCount: savedCount,
            onSelected: (value) => setState(() => _view = value),
          ),
          const SizedBox(height: 12),
          _CategorySelector(
            key: ValueKey('${_scope.name}-$_category'),
            selected: _category,
            offers: scopeOffers,
            onSelected: (value) => setState(() => _category = value),
          ),
          if (_actionInProgress) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 18),
          if (visibleOffers.isEmpty)
            _EmptyOffersState(
              scope: _scope,
              view: _view,
              category: _category,
              hasAnyOffers: scopeOffers.isNotEmpty,
            )
          else
            for (var index = 0; index < visibleOffers.length; index++) ...[
              _CommercialOfferCard(
                offer: visibleOffers[index],
                disabled: _actionInProgress,
                onOpen: () => _openOfficialOffer(visibleOffers[index]),
                onSave: () => _toggleSaved(visibleOffers[index]),
                onDismiss: () => _dismiss(visibleOffers[index]),
              ),
              if (index < visibleOffers.length - 1) const SizedBox(height: 13),
            ],
          const SizedBox(height: 20),
          _SourceStatusPanel(bundle: bundle),
          const SizedBox(height: 14),
          const _DisclaimerPanel(),
        ],
      ),
    );
  }
}

class _NoVehicleOffersState extends StatelessWidget {
  const _NoVehicleOffersState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.directions_car_outlined,
              size: 58,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Ajoutez un véhicule pour voir les promotions compatibles.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _OffersHero extends StatelessWidget {
  const _OffersHero({
    required this.vehicle,
    required this.scope,
    required this.offers,
  });

  final Vehicle vehicle;
  final _OfferScope scope;
  final List<CommercialOffer> offers;

  @override
  Widget build(BuildContext context) {
    final top = offers.isEmpty ? null : offers.first;
    final isPurchase = scope == _OfferScope.purchase;

    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isPurchase
                      ? Icons.directions_car_filled_outlined
                      : Icons.local_offer_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPurchase
                          ? 'Offres pour changer de ${vehicle.model}'
                          : 'Offres pour ${vehicle.displayName}',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isPurchase
                          ? '${offers.length} offre(s) identifient le même '
                                'modèle dans une source surveillée.'
                          : '${offers.length} offre(s) correspondent aux '
                                'informations connues du véhicule.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.80),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (top != null) ...[
            const SizedBox(height: 17),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    top.relevantNow
                        ? 'À regarder maintenant'
                        : 'Meilleure correspondance actuelle',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    top.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    top.benefitLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.84),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({required this.currentVehicleCount});

  final int currentVehicleCount;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: const Icon(Icons.build_circle_outlined, size: 18),
        label: Text(
          currentVehicleCount == 1
              ? 'Après-vente · 1 offre'
              : 'Après-vente · $currentVehicleCount offres',
        ),
      ),
    );
  }
}

class _GoodSensePanel extends StatelessWidget {
  const _GoodSensePanel({required this.scope});

  final _OfferScope scope;

  @override
  Widget build(BuildContext context) {
    final isPurchase = scope == _OfferScope.purchase;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPurchase
                  ? 'Même modèle identifié. Vérifiez le prix final et les conditions.'
                  : 'Offres filtrées selon ce véhicule et ses prochaines échéances.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({
    required this.selected,
    required this.showRelevant,
    required this.relevantCount,
    required this.totalCount,
    required this.savedCount,
    required this.onSelected,
  });

  final _OfferView selected;
  final bool showRelevant;
  final int relevantCount;
  final int totalCount;
  final int savedCount;
  final ValueChanged<_OfferView> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (showRelevant)
          ChoiceChip(
            selected: selected == _OfferView.relevant,
            onSelected: (_) => onSelected(_OfferView.relevant),
            avatar: const Icon(Icons.bolt_outlined, size: 18),
            label: Text('Maintenant ($relevantCount)'),
          ),
        ChoiceChip(
          selected: selected == _OfferView.all,
          onSelected: (_) => onSelected(_OfferView.all),
          avatar: const Icon(Icons.list_alt_rounded, size: 18),
          label: Text('Toutes ($totalCount)'),
        ),
        ChoiceChip(
          selected: selected == _OfferView.saved,
          onSelected: (_) => onSelected(_OfferView.saved),
          avatar: const Icon(Icons.bookmark_outline_rounded, size: 18),
          label: Text('Gardées ($savedCount)'),
        ),
      ],
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.selected,
    required this.offers,
    required this.onSelected,
    super.key,
  });

  final String selected;
  final List<CommercialOffer> offers;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final categories = <String>{
      for (final offer in offers) offer.category,
    }.toList()..sort();

    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: const InputDecoration(
        labelText: 'Type d’offre',
        prefixIcon: Icon(Icons.filter_alt_outlined),
      ),
      items: [
        const DropdownMenuItem(
          value: 'ALL',
          child: Text('Toutes les catégories'),
        ),
        for (final category in categories)
          DropdownMenuItem(
            value: category,
            child: Text(_categoryLabel(category)),
          ),
      ],
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
    );
  }
}

class _CommercialOfferCard extends StatelessWidget {
  const _CommercialOfferCard({
    required this.offer,
    required this.disabled,
    required this.onOpen,
    required this.onSave,
    required this.onDismiss,
  });

  final CommercialOffer offer;
  final bool disabled;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final compatibilityColor = switch (offer.compatibility) {
      'COMPATIBLE' => AppColors.success,
      'LIKELY' => AppColors.info,
      _ => AppColors.warning,
    };

    final compatibilityBackground = switch (offer.compatibility) {
      'COMPATIBLE' => AppColors.successSoft,
      'LIKELY' => AppColors.infoSoft,
      _ => AppColors.warningSoft,
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: offer.relevantNow
              ? AppColors.success.withValues(alpha: 0.45)
              : AppColors.border,
          width: offer.relevantNow ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: offer.relevantNow
                      ? AppColors.successSoft
                      : AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  _categoryIcon(offer.category),
                  color: offer.relevantNow
                      ? AppColors.success
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _SmallBadge(
                          label: offer.categoryLabel,
                          foreground: AppColors.primary,
                          background: AppColors.softPrimary,
                        ),
                        _SmallBadge(
                          label: offer.contextLabel,
                          foreground: offer.isPurchaseOffer
                              ? AppColors.info
                              : AppColors.success,
                          background: offer.isPurchaseOffer
                              ? AppColors.infoSoft
                              : AppColors.successSoft,
                        ),
                        if (offer.relevantNow)
                          const _SmallBadge(
                            label: 'Utile maintenant',
                            foreground: AppColors.success,
                            background: AppColors.successSoft,
                          ),
                        if (offer.expiresSoon)
                          const _SmallBadge(
                            label: 'Se termine bientôt',
                            foreground: AppColors.warning,
                            background: AppColors.warningSoft,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      offer.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: disabled ? null : onSave,
                icon: Icon(
                  offer.isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  color: offer.isSaved
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
                tooltip: offer.isSaved
                    ? 'Retirer des offres enregistrées'
                    : 'Enregistrer cette offre',
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: compatibilityBackground,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Icon(
                  offer.compatibility == 'COMPATIBLE'
                      ? Icons.verified_outlined
                      : Icons.fact_check_outlined,
                  color: compatibilityColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    offer.compatibilityLabel,
                    style: TextStyle(
                      color: compatibilityColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Text(
            offer.benefitLabel,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.primary),
          ),
          if (offer.summary.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(offer.summary),
          ],
          if (offer.why.isNotEmpty) ...[
            const SizedBox(height: 13),
            for (final reason in offer.why.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 17,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        reason,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.event_outlined,
                size: 17,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  offer.validityLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: const Text('Conditions et source'),
            children: [
              if (offer.conditionsSummary.isNotEmpty)
                _InfoLine(
                  title: 'Conditions principales',
                  value: offer.conditionsSummary,
                ),
              if (offer.eligibilityNotes.isNotEmpty)
                _InfoLine(title: 'À confirmer', value: offer.eligibilityNotes),
              if (offer.requiresExistingContract)
                const _InfoLine(
                  title: 'Condition',
                  value: 'Un contrat existant doit être confirmé.',
                ),
              if (offer.requiresNetworkParticipation)
                const _InfoLine(
                  title: 'Réseau',
                  value:
                      'La participation du réparateur ou du point de vente '
                      'doit être confirmée.',
                ),
              if (offer.autoExtracted)
                _InfoLine(
                  title: 'Extraction',
                  value: offer.extractionConfidence == null
                      ? 'Offre structurée automatiquement puis contrôlée.'
                      : 'Offre structurée automatiquement avec un niveau de '
                            'confiance de ${offer.extractionConfidence}/100.',
                ),
              _InfoLine(
                title: 'Source',
                value: '${offer.sourceName}\n${offer.verificationLabel}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: disabled ? null : onOpen,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Voir l’offre à la source'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: disabled ? null : onDismiss,
              icon: const Icon(Icons.visibility_off_outlined),
              label: const Text('Ne plus me la proposer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$title : ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: value),
            ],
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _EmptyOffersState extends StatelessWidget {
  const _EmptyOffersState({
    required this.scope,
    required this.view,
    required this.category,
    required this.hasAnyOffers,
  });

  final _OfferScope scope;
  final _OfferView view;
  final String category;
  final bool hasAnyOffers;

  @override
  Widget build(BuildContext context) {
    final purchase = scope == _OfferScope.purchase;

    final title = switch (view) {
      _OfferView.relevant => 'Aucune offre prioritaire maintenant',
      _OfferView.saved => 'Aucune offre enregistrée',
      _ =>
        hasAnyOffers
            ? 'Aucune offre dans cette catégorie'
            : purchase
            ? 'Aucune offre du même modèle vérifiée'
            : 'Aucune offre compatible vérifiée',
    };

    final message = switch (view) {
      _OfferView.relevant =>
        'Consultez Toutes pour voir les offres compatibles qui ne '
            'correspondent pas encore à une échéance du carnet.',
      _OfferView.saved =>
        'Utilisez le marque-page sur une offre pour la retrouver ici.',
      _ =>
        category == 'ALL'
            ? purchase
                  ? 'Le moteur ne montre pas une campagne de la même marque '
                        'si le modèle configuré n’est pas clairement identifié.'
                  : 'AutoClair préfère ne rien afficher plutôt qu’une promotion '
                        'expirée, ambiguë ou insuffisamment vérifiée.'
            : 'Choisissez une autre catégorie.',
    };

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 42,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SourceStatusPanel extends StatelessWidget {
  const _SourceStatusPanel({required this.bundle});

  final CommercialOfferBundle bundle;

  @override
  Widget build(BuildContext context) {
    final sync = bundle.lastSuccessfulSyncAt;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sync_rounded, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${bundle.activeSourceCount} source(s) surveillée(s). '
              '${sync == null ? 'La première exploration est en cours.' : 'Dernière synchronisation réussie : ${_dateTime(sync)}.'} '
              'Les extractions sûres sont publiées ; les cas ambigus restent '
              'en quarantaine.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerPanel extends StatelessWidget {
  const _DisclaimerPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'AutoClair n’est ni le vendeur ni l’organisateur de ces offres. '
        'Le prix total, le premier loyer, la reprise, le kilométrage, '
        'l’éligibilité, la disponibilité et la participation du réseau '
        'doivent être confirmés à la source. Aucun VIN ni numéro '
        'd’immatriculation n’est transmis aux sites surveillés.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 54,
              color: AppColors.error,
            ),
            const SizedBox(height: 15),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 17),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

String _categoryLabel(String category) {
  return switch (category) {
    'MAINTENANCE' => 'Entretien',
    'TYRES' => 'Pneumatiques',
    'BATTERY' => 'Batterie',
    'CLIMATE' => 'Climatisation',
    'ACCESSORIES' => 'Accessoires',
    'INSPECTION' => 'Contrôle technique',
    'WINDSCREEN' => 'Pare-brise',
    'CONTRACT' => 'Contrat d’entretien',
    'BODYWORK' => 'Carrosserie',
    'PARTS' => 'Pièces',
    'NEW_VEHICLE' => 'Véhicule neuf',
    'USED_VEHICLE' => 'Véhicule d’occasion',
    'FINANCE' => 'Financement',
    'INSURANCE' => 'Assurance',
    'ASSISTANCE' => 'Assistance',
    _ => 'Autres services',
  };
}

IconData _categoryIcon(String category) {
  return switch (category) {
    'MAINTENANCE' => Icons.build_circle_outlined,
    'TYRES' => Icons.tire_repair_outlined,
    'BATTERY' => Icons.battery_charging_full_outlined,
    'CLIMATE' => Icons.ac_unit_rounded,
    'ACCESSORIES' => Icons.shopping_bag_outlined,
    'INSPECTION' => Icons.fact_check_outlined,
    'WINDSCREEN' => Icons.car_repair_outlined,
    'CONTRACT' => Icons.assignment_outlined,
    'BODYWORK' => Icons.format_paint_outlined,
    'PARTS' => Icons.settings_outlined,
    'NEW_VEHICLE' => Icons.directions_car_filled_outlined,
    'USED_VEHICLE' => Icons.car_rental_outlined,
    'FINANCE' => Icons.payments_outlined,
    'INSURANCE' => Icons.shield_outlined,
    'ASSISTANCE' => Icons.support_agent_outlined,
    _ => Icons.local_offer_outlined,
  };
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} à $hour:$minute';
}
