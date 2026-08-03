import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';

class NearbyPage extends StatelessWidget {
  const NearbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Autour de moi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          const _NearbyIntro(),
          const SizedBox(height: 22),
          Text(
            'Que recherchez-vous ?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _NearbyServiceCard(
            icon: Icons.local_gas_station_rounded,
            title: 'Une station-service',
            description:
                'Comparez les prix des carburants et ouvrez votre itinéraire.',
            actionLabel: 'Comparer les carburants',
            foreground: AppColors.success,
            background: AppColors.successSoft,
            onTap: () => context.push('/fuel-prices'),
          ),
          const SizedBox(height: 12),
          _NearbyServiceCard(
            icon: Icons.ev_station_rounded,
            title: 'Une borne de recharge',
            description:
                'Repérez les bornes proches et consultez les tarifs disponibles.',
            actionLabel: 'Trouver une borne',
            foreground: AppColors.accent,
            background: AppColors.softPrimary,
            onTap: () => context.push('/charging-prices'),
          ),
          const SizedBox(height: 12),
          _NearbyServiceCard(
            icon: Icons.fact_check_outlined,
            title: 'Un contrôle technique',
            description:
                'Trouvez les centres proches et comparez leurs prix déclarés.',
            actionLabel: 'Comparer les centres',
            foreground: AppColors.info,
            background: AppColors.infoSoft,
            onTap: () => context.push('/technical-controls'),
          ),
          const SizedBox(height: 18),
          const _LocationPrivacyNote(),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}

class _NearbyIntro extends StatelessWidget {
  const _NearbyIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.near_me_outlined,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tout ce qui est utile sur la route',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 7),
                Text(
                  'Carburant, recharge et contrôle technique sont regroupés ici.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyServiceCard extends StatelessWidget {
  const _NearbyServiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: foreground, size: 29),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      actionLabel,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationPrivacyNote extends StatelessWidget {
  const _LocationPrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Votre position sert uniquement à afficher les résultats proches. '
              "Vous pouvez aussi saisir manuellement une ville ou un code postal.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
