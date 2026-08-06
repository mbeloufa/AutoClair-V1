import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class FinancialToolsPage extends StatelessWidget {
  const FinancialToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const tools = <_FinancialTool>[
      _FinancialTool(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Mon budget automobile',
        description: 'Coût mensuel, coût au kilomètre et économies confirmées.',
        route: '/budget',
        background: AppColors.softPrimary,
        foreground: AppColors.primary,
      ),
      _FinancialTool(
        icon: Icons.local_gas_station_outlined,
        title: 'Optimiser mon plein',
        description: 'Comparez les stations après déduction du coût du détour.',
        route: '/fuel-optimizer',
        background: AppColors.successSoft,
        foreground: AppColors.success,
      ),
      _FinancialTool(
        icon: Icons.electric_bolt_outlined,
        title: 'Optimiser ma recharge',
        description: 'Comparez le tarif, l’accès et la durée théorique.',
        route: '/charging-optimizer',
        background: AppColors.softPrimary,
        foreground: AppColors.primary,
      ),
      _FinancialTool(
        icon: Icons.eco_outlined,
        title: 'Améliorer ma conduite',
        description: 'Analysez un trajet sans conserver votre parcours.',
        route: '/eco-driving',
        background: AppColors.successSoft,
        foreground: AppColors.success,
      ),
      _FinancialTool(
        icon: Icons.event_repeat_outlined,
        title: 'Planifier mon entretien',
        description:
            'Anticipez les échéances et le budget des 12 prochains mois.',
        route: '/maintenance-planner',
        background: AppColors.infoSoft,
        foreground: AppColors.info,
      ),
      _FinancialTool(
        icon: Icons.query_stats_outlined,
        title: 'Anticiper les risques',
        description:
            'Repérez les facteurs de panne sans prétendre établir un diagnostic.',
        route: '/risk-forecast',
        background: AppColors.warningSoft,
        foreground: AppColors.warning,
      ),
      _FinancialTool(
        icon: Icons.checklist_rounded,
        title: 'Inspecter mon véhicule',
        description:
            'Réalisez un état des lieux structuré sans expertise automatique.',
        route: '/vehicle-inspection',
        background: AppColors.infoSoft,
        foreground: AppColors.info,
      ),
      _FinancialTool(
        icon: Icons.route_outlined,
        title: 'Préparer mon départ',
        description:
            'Vérifiez les points essentiels avant un trajet important.',
        route: '/trip-readiness',
        background: AppColors.successSoft,
        foreground: AppColors.success,
      ),
      _FinancialTool(
        icon: Icons.pause_circle_outline,
        title: 'Gérer une immobilisation',
        description:
            'Préparez le véhicule avant une pause et sa remise en service.',
        route: '/vehicle-storage',
        background: AppColors.warningSoft,
        foreground: AppColors.warning,
      ),
      _FinancialTool(
        icon: Icons.fact_check_outlined,
        title: 'Préparer mon contrôle technique',
        description:
            'Passez en revue les points visibles avant le rendez-vous.',
        route: '/technical-control-readiness',
        background: AppColors.infoSoft,
        foreground: AppColors.info,
      ),
      _FinancialTool(
        icon: Icons.car_repair_outlined,
        title: 'Préparer ma visite au garage',
        description:
            'Préparez les symptômes, documents, devis et décisions à clarifier.',
        route: '/workshop-visit',
        background: AppColors.softPrimary,
        foreground: AppColors.primary,
      ),
      _FinancialTool(
        icon: Icons.tire_repair_outlined,
        title: 'Suivre mes pneus',
        description:
            'Vérifiez les signes visibles et préparez les actions utiles.',
        route: '/tire-care',
        background: AppColors.warningSoft,
        foreground: AppColors.warning,
      ),
      _FinancialTool(
        icon: Icons.car_crash_outlined,
        title: 'Gérer une panne',
        description:
            'Sécurisez la situation et préparez un résumé pour l’assistance.',
        route: '/breakdown-assistant',
        background: AppColors.errorSoft,
        foreground: AppColors.error,
      ),
      _FinancialTool(
        icon: Icons.sell_outlined,
        title: 'Préparer ma vente',
        description:
            'Vérifiez le dossier, les documents et le produit net attendu.',
        route: '/sale-preparation',
        background: AppColors.warningSoft,
        foreground: AppColors.warning,
      ),
      _FinancialTool(
        icon: Icons.car_rental_outlined,
        title: 'Sécuriser mon achat',
        description:
            'Vérifiez les documents, l’essai et le budget total avant de payer.',
        route: '/used-purchase',
        background: AppColors.infoSoft,
        foreground: AppColors.info,
      ),
      _FinancialTool(
        icon: Icons.car_crash_outlined,
        title: 'Gérer un accident',
        description:
            'Sécurisez les personnes, préparez le constat et le dossier assureur.',
        route: '/accident-assistant',
        background: AppColors.errorSoft,
        foreground: AppColors.error,
      ),
      _FinancialTool(
        icon: Icons.lock_open_outlined,
        title: 'Réagir à un vol',
        description:
            'Organisez la plainte, les preuves et la déclaration à l’assureur.',
        route: '/theft-assistant',
        background: AppColors.warningSoft,
        foreground: AppColors.warning,
      ),
      _FinancialTool(
        icon: Icons.verified_user_outlined,
        title: 'À vérifier',
        description: 'Contrôle technique, assurance, rappels et échéances.',
        route: '/compliance',
        background: AppColors.warningSoft,
        foreground: AppColors.warning,
      ),
      _FinancialTool(
        icon: Icons.compare_arrows_outlined,
        title: 'Comparer mes devis',
        description: 'Comparez deux ou trois devis réellement reçus.',
        route: '/quote-comparison',
        background: AppColors.infoSoft,
        foreground: AppColors.info,
      ),
      _FinancialTool(
        icon: Icons.shield_outlined,
        title: 'Réviser mon assurance',
        description: 'Suivez la prime, les franchises et les garanties.',
        route: '/insurance-review',
        background: AppColors.errorSoft,
        foreground: AppColors.error,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Mes économies')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.savings_outlined,
                  color: AppColors.primary,
                  size: 32,
                ),
                SizedBox(height: 12),
                Text(
                  'AutoClair transforme les informations de votre véhicule en décisions financières concrètes.',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 7),
                Text(
                  'Une économie potentielle n’est comptée comme réalisée qu’après votre confirmation.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final tool in tools) ...[
            _FinancialToolCard(tool: tool),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _FinancialToolCard extends StatelessWidget {
  const _FinancialToolCard({required this.tool});

  final _FinancialTool tool;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(tool.route),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: tool.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(tool.icon, color: tool.foreground),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(tool.description),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinancialTool {
  const _FinancialTool({
    required this.icon,
    required this.title,
    required this.description,
    required this.route,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String title;
  final String description;
  final String route;
  final Color background;
  final Color foreground;
}
