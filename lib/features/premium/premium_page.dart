import 'package:flutter/material.dart';

import 'premium_catalog.dart';
import 'premium_service.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  final _service = PremiumService();

  PremiumState? _state;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final state = await _service.load();
      if (!mounted) return;
      setState(() => _state = state);
    } on PremiumException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _purchase(PremiumOffer offer) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final state = await _service.purchase(offer);
      if (!mounted) return;
      setState(() => _state = state);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium est actif. Merci !')),
      );
    } on PremiumPurchaseCancelled {
      // Une annulation utilisateur ne doit pas etre affichee comme une erreur.
    } on PremiumException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final state = await _service.restore();
      if (!mounted) return;
      setState(() => _state = state);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.active
                ? 'Vos achats ont été restaurés.'
                : 'Aucun abonnement Premium actif trouvé.',
          ),
        ),
      );
    } on PremiumException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AutoClair Premium')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              const _PremiumHero(),
              const SizedBox(height: 20),
              const _PlanSummary(
                title: PremiumCatalog.freeTitle,
                benefits: PremiumCatalog.freeBenefits,
              ),
              const SizedBox(height: 14),
              const _PlanSummary(
                title: PremiumCatalog.premiumTitle,
                benefits: PremiumCatalog.premiumBenefits,
                highlighted: true,
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                _buildPurchaseArea(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseArea(BuildContext context) {
    final state = _state;

    if (_error != null) {
      return _MessageCard(
        icon: Icons.error_outline,
        title: 'Impossible de continuer',
        message: _error!,
        actionLabel: 'Réessayer',
        onAction: _busy ? null : _load,
      );
    }

    if (state == null) {
      return _MessageCard(
        icon: Icons.refresh,
        title: 'Actualisation nécessaire',
        message: 'Actualisez Premium pour continuer.',
        actionLabel: 'Actualiser',
        onAction: _busy ? null : _load,
      );
    }

    if (state.active) {
      return Column(
        children: [
          const _MessageCard(
            icon: Icons.verified_outlined,
            title: 'Premium actif',
            message:
                'Vous pouvez lancer vos Bilans AutoClair 360 sans utiliser de crédit.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.restore),
            label: const Text('Restaurer mes achats'),
          ),
        ],
      );
    }

    if (!state.configured) {
      return _MessageCard(
        icon: Icons.lock_clock_outlined,
        title: 'Premium bientôt disponible',
        message:
            state.message ??
            'Les abonnements seront proposés ici dès que les achats Store seront ouverts.',
      );
    }

    if (state.offers.isEmpty) {
      return Column(
        children: [
          _MessageCard(
            icon: Icons.storefront_outlined,
            title: 'Offres indisponibles',
            message:
                state.message ??
                'Aucune offre Premium n’est disponible sur ce store pour le moment.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.restore),
            label: const Text('Restaurer mes achats'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choisissez votre formule',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Le prix affiché est celui de votre store.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        for (final offer in state.offers) ...[
          _OfferCard(
            offer: offer,
            busy: _busy,
            onPressed: () => _purchase(offer),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 2),
        OutlinedButton.icon(
          onPressed: _busy ? null : _restore,
          icon: const Icon(Icons.restore),
          label: const Text('Restaurer mes achats'),
        ),
        const SizedBox(height: 10),
        Text(
          'L’abonnement se renouvelle via votre App Store ou Google Play. '
          'Vous pouvez le gérer depuis les réglages de votre store.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PremiumHero extends StatelessWidget {
  const _PremiumHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.auto_awesome,
            size: 36,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Gardez une vision claire de votre voiture',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Premium prolonge l’accès au Bilan AutoClair 360 après votre essai offert.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({
    required this.title,
    required this.benefits,
    this.highlighted = false,
  });

  final String title;
  final List<String> benefits;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: highlighted ? 1 : 0,
      color: highlighted
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (final benefit in benefits)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: highlighted
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(benefit)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.busy,
    required this.onPressed,
  });

  final PremiumOffer offer;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    offer.price,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: busy ? null : onPressed,
              child: const Text('Choisir'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 34),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
