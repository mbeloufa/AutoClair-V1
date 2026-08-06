import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class ActionCenterPage extends StatelessWidget {
  const ActionCenterPage({super.key});

  static const _sections = <_ActionSection>[
    _ActionSection(
      keyName: 'emergency',
      title: 'Urgence et imprévus',
      subtitle: 'Réagir vite, sans chercher le bon écran.',
      icon: Icons.health_and_safety_outlined,
      foreground: AppColors.error,
      background: AppColors.errorSoft,
      tools: [
        _ActionTool(
          title: 'Gérer une panne',
          subtitle: 'Sécurisation, assistance et résumé pour le dépanneur.',
          icon: Icons.warning_amber_rounded,
          route: '/breakdown-assistant',
        ),
        _ActionTool(
          title: 'Gérer un accident',
          subtitle: 'Constat, photos, assureur et enregistrement au carnet.',
          icon: Icons.car_crash_outlined,
          route: '/accident-assistant',
        ),
        _ActionTool(
          title: 'Réagir à un vol',
          subtitle: 'Fourrière, plainte, preuves et déclaration à l’assureur.',
          icon: Icons.lock_open_outlined,
          route: '/theft-assistant',
        ),
      ],
    ),
    _ActionSection(
      keyName: 'buy-sell',
      title: 'Acheter et vendre',
      subtitle: 'Préparer une décision importante avec une checklist claire.',
      icon: Icons.swap_horiz_rounded,
      foreground: AppColors.info,
      background: AppColors.infoSoft,
      tools: [
        _ActionTool(
          title: 'Sécuriser mon achat',
          subtitle: 'Documents, inspection, essai et budget total.',
          icon: Icons.shopping_cart_outlined,
          route: '/used-purchase',
        ),
        _ActionTool(
          title: 'Préparer ma vente',
          subtitle: 'Documents, prix, marge et dossier à partager.',
          icon: Icons.sell_outlined,
          route: '/sale-preparation',
        ),
      ],
    ),
    _ActionSection(
      keyName: 'care-driving',
      title: 'Entretenir et conduire',
      subtitle: 'Anticiper les opérations et mieux utiliser le véhicule.',
      icon: Icons.build_circle_outlined,
      foreground: AppColors.success,
      background: AppColors.successSoft,
      tools: [
        _ActionTool(
          title: 'Planifier mon entretien',
          subtitle: 'Échéances, kilométrage et budget sur douze mois.',
          icon: Icons.event_note_outlined,
          route: '/maintenance-planner',
        ),
        _ActionTool(
          title: 'Anticiper les risques',
          subtitle:
              'Repérer les facteurs de panne et les contrôles prioritaires.',
          icon: Icons.query_stats_outlined,
          route: '/risk-forecast',
        ),
        _ActionTool(
          title: 'Inspecter mon véhicule',
          subtitle: 'État des lieux guidé avant achat, vente ou restitution.',
          icon: Icons.checklist_rounded,
          route: '/vehicle-inspection',
        ),
        _ActionTool(
          title: 'Préparer mon départ',
          subtitle: 'Checklist véhicule, documents, chargement et vigilance.',
          icon: Icons.route_outlined,
          route: '/trip-readiness',
        ),
        _ActionTool(
          title: 'Gérer une immobilisation',
          subtitle: 'Préparer une pause, un hivernage ou une remise en route.',
          icon: Icons.pause_circle_outline,
          route: '/vehicle-storage',
        ),
        _ActionTool(
          title: 'Préparer mon contrôle technique',
          subtitle: 'Vérifications visibles avant visite ou contre-visite.',
          icon: Icons.fact_check_outlined,
          route: '/technical-control-readiness',
        ),
        _ActionTool(
          title: 'Améliorer ma conduite',
          subtitle: 'Bilan volontaire d’écoconduite après le trajet.',
          icon: Icons.eco_outlined,
          route: '/eco-driving',
        ),
      ],
    ),
    _ActionSection(
      keyName: 'budget-savings',
      title: 'Budget et économies',
      subtitle: 'Comprendre les coûts et préparer les prochaines dépenses.',
      icon: Icons.account_balance_wallet_outlined,
      foreground: AppColors.warning,
      background: AppColors.warningSoft,
      tools: [
        _ActionTool(
          title: 'Mon budget automobile',
          subtitle: 'Coût mensuel, coût au kilomètre et prévision annuelle.',
          icon: Icons.pie_chart_outline,
          route: '/budget',
        ),
        _ActionTool(
          title: 'Optimiser mon plein',
          subtitle: 'Comparer le prix affiché au coût réel du détour.',
          icon: Icons.local_gas_station_outlined,
          route: '/fuel-optimizer',
        ),
        _ActionTool(
          title: 'Optimiser ma recharge',
          subtitle: 'Comparer énergie, durée, frais et budget de session.',
          icon: Icons.ev_station_outlined,
          route: '/charging-optimizer',
        ),
        _ActionTool(
          title: 'Comparer mes devis',
          subtitle: 'Normaliser les lignes et expliquer les différences.',
          icon: Icons.request_quote_outlined,
          route: '/quote-comparison',
        ),
        _ActionTool(
          title: 'Vérifier ma conformité',
          subtitle: 'Contrôle technique, documents et points à surveiller.',
          icon: Icons.fact_check_outlined,
          route: '/compliance',
        ),
        _ActionTool(
          title: 'Réviser mon assurance',
          subtitle: 'Prime, garanties, franchises et échéance du contrat.',
          icon: Icons.shield_outlined,
          route: '/insurance-review',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tous les outils AutoClair')),
      body: ListView(
        key: const ValueKey('action-center-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _ActionCenterIntro(),
          const SizedBox(height: 22),
          for (var index = 0; index < _sections.length; index++) ...[
            _ActionSectionCard(section: _sections[index]),
            if (index < _sections.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _ActionCenterIntro extends StatelessWidget {
  const _ActionCenterIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('action-center-intro'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.apps_rounded, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'Une action, un accès direct',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Les outils sont regroupés par moment de vie. Chaque bouton ouvre '
            'directement la fonctionnalité correspondante.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionSectionCard extends StatelessWidget {
  const _ActionSectionCard({required this.section});

  final _ActionSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('action-section-${section.keyName}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: section.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(section.icon, color: section.foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      section.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 600;
              final width = twoColumns
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  for (final tool in section.tools)
                    SizedBox(
                      width: width,
                      child: _ActionToolTile(tool: tool),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionToolTile extends StatelessWidget {
  const _ActionToolTile({required this.tool});

  final _ActionTool tool;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        key: ValueKey('action-tool-${tool.route}'),
        onTap: () => context.push<void>(tool.route),
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(tool.icon, color: AppColors.primary, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tool.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionSection {
  const _ActionSection({
    required this.keyName,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.tools,
  });

  final String keyName;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color foreground;
  final Color background;
  final List<_ActionTool> tools;
}

class _ActionTool {
  const _ActionTool({
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
