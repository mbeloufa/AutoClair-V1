import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/app_logo.dart';
import '../documents/document_analysis_service.dart';
import '../documents/document_history_item.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _vehicleService = VehicleService();
  final _analysisService = DocumentAnalysisService();

  Vehicle? _primaryVehicle;
  List<DocumentHistoryItem> _recentDocuments = const [];
  bool _loading = true;
  String? _dashboardError;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _dashboardError = null;
      });
    }

    Vehicle? primaryVehicle;
    List<DocumentHistoryItem> documents = const [];
    final errors = <String>[];

    try {
      final vehicles = await _vehicleService.fetchVehicles();
      primaryVehicle = vehicles.isEmpty ? null : vehicles.first;
    } on VehicleServiceException catch (error) {
      errors.add(error.message);
    }

    try {
      documents = await _analysisService.fetchDocuments();
    } on DocumentAnalysisException catch (error) {
      errors.add(error.message);
    }

    if (!mounted) return;

    setState(() {
      _primaryVehicle = primaryVehicle;
      _recentDocuments = documents.take(3).toList(growable: false);
      _dashboardError = errors.isEmpty ? null : errors.first;
      _loading = false;
    });
  }

  Future<void> _openPrimaryAction() async {
    if (_primaryVehicle == null) {
      final changed = await context.push<bool>('/vehicles/new');
      if (changed == true) await _loadDashboard();
      return;
    }

    await context.push('/documents/new');
    if (mounted) await _loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name']?.toString().trim();
    final firstName = fullName == null || fullName.isEmpty
        ? null
        : fullName.split(RegExp(r'\s+')).first;

    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(compact: true),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              firstName == null ? 'Bienvenue' : 'Bonjour $firstName',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 7),
            Text(
              'Votre espace pour comprendre et suivre vos documents auto.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            _PrimaryActionCard(
              hasVehicle: _primaryVehicle != null,
              onPressed: _loading ? null : _openPrimaryAction,
            ),
            const SizedBox(height: 14),
            _TechnicalControlPromoCard(
              onPressed: () => context.push('/technical-controls'),
            ),
            const SizedBox(height: 14),
            _FuelPricePromoCard(onPressed: () => context.push('/fuel-prices')),
            const SizedBox(height: 14),
            _ChargingPricePromoCard(
              onPressed: () => context.push('/charging-prices'),
            ),
            if (_dashboardError != null) ...[
              const SizedBox(height: 14),
              _DashboardWarning(
                message: _dashboardError!,
                onRetry: _loadDashboard,
              ),
            ],
            const SizedBox(height: 28),
            _SectionHeading(
              title: 'Mon véhicule',
              actionLabel: 'Voir tous',
              onAction: () => context.go('/vehicles'),
            ),
            const SizedBox(height: 12),
            _buildVehicleSection(context),
            const SizedBox(height: 28),
            _SectionHeading(
              title: 'Analyses récentes',
              actionLabel: 'Tout voir',
              onAction: () => context.go('/history'),
            ),
            const SizedBox(height: 12),
            _buildRecentAnalyses(context),
            const SizedBox(height: 20),
            const _PrivacyCard(),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildVehicleSection(BuildContext context) {
    if (_loading && _primaryVehicle == null) {
      return const _LoadingCard(height: 132);
    }

    final vehicle = _primaryVehicle;
    if (vehicle == null) {
      return _EmptyCard(
        icon: Icons.directions_car_outlined,
        title: 'Aucun véhicule enregistré',
        description:
            'Ajoutez votre véhicule pour rattacher correctement vos documents.',
        buttonLabel: 'Ajouter un véhicule',
        onPressed: _openPrimaryAction,
      );
    }

    final details = <String>[
      if (vehicle.vehicleYear != null) vehicle.vehicleYear.toString(),
      if (vehicle.fuelType?.trim().isNotEmpty == true) vehicle.fuelType!,
      if (vehicle.mileage != null) '${vehicle.mileage} km',
    ];

    return InkWell(
      onTap: () async {
        await context.push<void>('/vehicles/${vehicle.id}/care');
        await _loadDashboard();
      },
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDark, AppColors.primary],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.directions_car_filled_outlined,
                color: Colors.white,
                size: 31,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  if (vehicle.nickname?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      vehicle.makeAndModel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                      ),
                    ),
                  ],
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      details.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAnalyses(BuildContext context) {
    if (_loading && _recentDocuments.isEmpty) {
      return const Column(
        children: [
          _LoadingCard(height: 92),
          SizedBox(height: 10),
          _LoadingCard(height: 92),
        ],
      );
    }

    if (_recentDocuments.isEmpty) {
      return _EmptyCard(
        icon: Icons.manage_search_outlined,
        title: 'Aucune analyse pour le moment',
        description:
            'Ajoutez un document pour obtenir votre première synthèse AutoClair.',
        buttonLabel: _primaryVehicle == null
            ? 'Ajouter un véhicule'
            : 'Analyser un document',
        onPressed: _openPrimaryAction,
      );
    }

    return Column(
      children: [
        for (var index = 0; index < _recentDocuments.length; index++) ...[
          _RecentDocumentCard(
            document: _recentDocuments[index],
            onTap: () {
              final document = _recentDocuments[index];
              if (document.isCompleted) {
                context.push('/history/${document.id}/analysis');
              } else {
                context.go('/history');
              }
            },
          ),
          if (index < _recentDocuments.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({required this.hasVehicle, required this.onPressed});

  final bool hasVehicle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.softPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.document_scanner_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasVehicle
                ? 'Un document à comprendre ?'
                : 'Commençons par votre véhicule',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          Text(
            hasVehicle
                ? 'Ajoutez un devis, une facture ou un ordre de réparation '
                      'pour lancer une analyse.'
                : 'Chaque document est rattaché au véhicule concerné.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(hasVehicle ? Icons.add_rounded : Icons.directions_car),
            label: Text(
              hasVehicle ? 'Ajouter un document' : 'Ajouter mon véhicule',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _RecentDocumentCard extends StatelessWidget {
  const _RecentDocumentCard({required this.document, required this.onTap});

  final DocumentHistoryItem document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final day = document.createdAt.day.toString().padLeft(2, '0');
    final month = document.createdAt.month.toString().padLeft(2, '0');
    final status = _DocumentStatusStyle.from(document);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: status.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(status.icon, color: status.foreground),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.typeLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${status.label} • $day/$month/${document.createdAt.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: status.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _DocumentStatusStyle {
  const _DocumentStatusStyle({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  factory _DocumentStatusStyle.from(DocumentHistoryItem document) {
    if (document.isCompleted) {
      return const _DocumentStatusStyle(
        label: 'Analyse terminée',
        icon: Icons.check_circle_outline,
        foreground: AppColors.success,
        background: AppColors.successSoft,
      );
    }
    if (document.isProcessing || document.status == 'queued') {
      return const _DocumentStatusStyle(
        label: 'Analyse en cours',
        icon: Icons.hourglass_top_rounded,
        foreground: AppColors.info,
        background: AppColors.infoSoft,
      );
    }
    if (document.status == 'failed') {
      return const _DocumentStatusStyle(
        label: 'À relancer',
        icon: Icons.refresh_rounded,
        foreground: AppColors.error,
        background: AppColors.errorSoft,
      );
    }
    return const _DocumentStatusStyle(
      label: 'Prêt à analyser',
      icon: Icons.schedule_rounded,
      foreground: AppColors.warning,
      background: AppColors.warningSoft,
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppColors.primary),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}

class _DashboardWarning extends StatelessWidget {
  const _DashboardWarning({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_problem_outlined, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Réessayer',
          ),
        ],
      ),
    );
  }
}

class _TechnicalControlPromoCard extends StatelessWidget {
  const _TechnicalControlPromoCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.infoSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.price_check_rounded,
                color: AppColors.info,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comparer les contrôles techniques',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Trouvez les centres proches et comparez leurs tarifs.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.info),
          ],
        ),
      ),
    );
  }
}

class _FuelPricePromoCard extends StatelessWidget {
  const _FuelPricePromoCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.successSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.local_gas_station_rounded,
                color: AppColors.success,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comparer les prix des carburants',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Trouvez les stations proches et le meilleur prix au litre.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.success),
          ],
        ),
      ),
    );
  }
}

class _ChargingPricePromoCard extends StatelessWidget {
  const _ChargingPricePromoCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.infoSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.ev_station_rounded,
                color: AppColors.info,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comparer les tarifs de recharge',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bornes compatibles, puissance, distance et estimation du cout.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.info),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: AppColors.success),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Vos documents sont conservés dans un stockage privé et '
              'restent accessibles uniquement depuis votre compte.',
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
