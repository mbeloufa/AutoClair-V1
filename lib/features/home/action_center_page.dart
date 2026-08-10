import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ActionCenterPage extends StatelessWidget {
  const ActionCenterPage({super.key});

  static const _sections = <_V1Section>[
    _V1Section(
      title: 'Mon véhicule',
      actions: [
        _V1Action(
          title: 'Mon véhicule & carnet',
          subtitle:
              'Historique, échéances, rappels, tableau de bord et Bilan 360.',
          icon: Icons.directions_car_outlined,
          route: '/vehicles',
        ),
      ],
    ),
    _V1Section(
      title: 'Documents',
      actions: [
        _V1Action(
          title: 'Analyser un document',
          subtitle:
              'Facture, devis, contrôle technique, achat, vente, LOA/LLD ou assurance.',
          icon: Icons.document_scanner_outlined,
          route: '/documents/new',
        ),
      ],
    ),
    _V1Section(
      title: 'Autour de moi',
      actions: [
        _V1Action(
          title: 'Services autour de moi',
          subtitle:
              'Parking, carburant, recharge et contrôle technique au même endroit.',
          icon: Icons.near_me_outlined,
          route: '/nearby',
        ),
      ],
    ),
    _V1Section(
      title: 'Achat / vente',
      actions: [
        _V1Action(
          title: 'Acheter un véhicule',
          subtitle: 'Analyse d’annonce et checklist pour sécuriser l’achat.',
          icon: Icons.search_outlined,
          route: '/used-purchase',
        ),
        _V1Action(
          title: 'Vendre mon véhicule',
          subtitle:
              'Préparation du dossier et génération d’une annonce claire.',
          icon: Icons.sell_outlined,
          route: '/sale-preparation',
        ),
        _V1Action(
          title: 'Offres automobiles',
          subtitle:
              'Offres commerciales pertinentes avec source et conditions.',
          icon: Icons.local_offer_outlined,
          route: '/offers',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AutoClair')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 700 ? 32.0 : 16.0;
            final maxContentWidth = constraints.maxWidth >= 900
                ? 860.0
                : double.infinity;

            return SingleChildScrollView(
              key: const ValueKey('action-center-v1-scroll'),
              padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 28),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _IntroCard(),
                      const SizedBox(height: 20),
                      for (
                        var index = 0;
                        index < _sections.length;
                        index++
                      ) ...[
                        _V1SectionCard(section: _sections[index]),
                        if (index < _sections.length - 1)
                          const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('v1-product-intro'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'De quoi avez-vous besoin ?',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            'AutoClair vous accompagne dans les moments utiles de la vie de votre véhicule.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _V1SectionCard extends StatelessWidget {
  const _V1SectionCard({required this.section});

  final _V1Section section;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('v1-section-${section.title}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < section.actions.length; index++) ...[
            _V1ActionTile(action: section.actions[index]),
            if (index < section.actions.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _V1ActionTile extends StatelessWidget {
  const _V1ActionTile({required this.action});

  final _V1Action action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: ValueKey('v1-action-${action.route}'),
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push<void>(action.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(action.icon, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _V1Section {
  const _V1Section({required this.title, required this.actions});

  final String title;
  final List<_V1Action> actions;
}

class _V1Action {
  const _V1Action({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}
