import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/app_logo.dart';
import '../documents/document_analysis_service.dart';
import '../documents/document_history_item.dart';
import '../vehicle_care/vehicle_care_models.dart';
import '../vehicle_care/vehicle_care_service.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_brand_logo.dart';
import '../vehicles/vehicle_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _vehicleService = VehicleService();
  final _analysisService = DocumentAnalysisService();
  final _careService = VehicleCareService();

  List<Vehicle> _vehicles = const [];
  List<DocumentHistoryItem> _documents = const [];
  VehicleCareBundle? _primaryCare;
  bool _loading = true;
  String? _dashboardError;

  Vehicle? get _primaryVehicle {
    for (final vehicle in _vehicles) {
      if (vehicle.isPrimary) return vehicle;
    }
    return _vehicles.isEmpty ? null : _vehicles.first;
  }

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

    var vehicles = <Vehicle>[];
    var documents = <DocumentHistoryItem>[];
    VehicleCareBundle? primaryCare;
    final errors = <String>[];

    try {
      vehicles = await _vehicleService.fetchVehicles();
    } on VehicleServiceException catch (error) {
      errors.add(error.message);
    }

    try {
      documents = await _analysisService.fetchDocuments();
    } on DocumentAnalysisException catch (error) {
      errors.add(error.message);
    }

    Vehicle? primary;
    for (final vehicle in vehicles) {
      if (vehicle.isPrimary) {
        primary = vehicle;
        break;
      }
    }
    primary ??= vehicles.isEmpty ? null : vehicles.first;

    if (primary != null) {
      try {
        primaryCare = await _careService.loadBundle(primary.id);
      } on VehicleCareException catch (error) {
        errors.add(error.message);
      }
    }

    if (!mounted) return;

    setState(() {
      _vehicles = vehicles;
      _documents = documents;
      _primaryCare = primaryCare;
      _dashboardError = errors.isEmpty ? null : errors.first;
      _loading = false;
    });
  }

  Future<void> _openDocumentUpload() async {
    if (_primaryVehicle == null) {
      final changed = await context.push<bool>('/vehicles/new');
      if (changed == true) await _loadDashboard();
      return;
    }

    await context.push<void>('/documents/new');
    if (mounted) await _loadDashboard();
  }

  Future<void> _openVehicleCare({String? section}) async {
    final vehicle = _primaryVehicle;
    if (vehicle == null) {
      final changed = await context.push<bool>('/vehicles/new');
      if (changed == true) await _loadDashboard();
      return;
    }

    final suffix = section == null ? '' : '?section=$section';
    await context.push<void>('/vehicles/${vehicle.id}/care$suffix');
    if (mounted) await _loadDashboard();
  }

  Future<void> _openMileage() async {
    final vehicle = _primaryVehicle;
    if (vehicle == null) {
      await _openVehicleCare();
      return;
    }

    final changed = await context.push<bool>(
      '/vehicles/${vehicle.id}/care/odometer/new',
      extra: vehicle.mileage,
    );
    if (changed == true) await _loadDashboard();
  }

  Future<void> _openEvent() async {
    final vehicle = _primaryVehicle;
    if (vehicle == null) {
      await _openVehicleCare();
      return;
    }

    final changed = await context.push<bool>(
      '/vehicles/${vehicle.id}/care/events/new',
    );
    if (changed == true) await _loadDashboard();
  }

  Future<void> _openOffers() async {
    await context.push<void>('/offers');
    if (mounted) await _loadDashboard();
  }

  List<_HomeActionItem> _buildPriorityItems() {
    final vehicle = _primaryVehicle;
    if (vehicle == null) {
      return [
        _HomeActionItem(
          icon: Icons.directions_car_outlined,
          title: 'Ajoutez votre premier véhicule',
          subtitle: 'AutoClair pourra ensuite organiser votre suivi.',
          priority: _HomeActionPriority.info,
          onTap: () => _openVehicleCare(),
        ),
      ];
    }

    final items = <_HomeActionItem>[];
    final care = _primaryCare;

    if (care != null) {
      final overdue = care.schedules
          .where(
            (schedule) => schedule.isOverdue(currentMileage: vehicle.mileage),
          )
          .length;
      final dueSoon = care.schedules
          .where(
            (schedule) => schedule.isDueSoon(currentMileage: vehicle.mileage),
          )
          .length;
      final recalls = care.dashboard.recalls
          .where(
            (recall) =>
                recall.requiresAttention &&
                recall.isPlausibleFor(vehicle.model),
          )
          .length;

      if (overdue > 0) {
        items.add(
          _HomeActionItem(
            icon: Icons.build_circle_outlined,
            title: overdue == 1
                ? 'Un entretien semble en retard'
                : '$overdue entretiens semblent en retard',
            subtitle: 'Consultez la timeline et confirmez ce qui a été fait.',
            priority: _HomeActionPriority.urgent,
            onTap: () => _openVehicleCare(section: 'maintenance'),
          ),
        );
      }

      if (recalls > 0) {
        items.add(
          _HomeActionItem(
            icon: Icons.campaign_outlined,
            title: recalls == 1
                ? 'Un rappel constructeur est à vérifier'
                : '$recalls rappels constructeur sont à vérifier',
            subtitle:
                'Le modèle correspond. La confirmation se fait avec le VIN.',
            priority: _HomeActionPriority.urgent,
            onTap: () => _openVehicleCare(section: 'alerts'),
          ),
        );
      }

      if (care.suggestions.isNotEmpty) {
        final count = care.suggestions.length;
        items.add(
          _HomeActionItem(
            icon: Icons.auto_awesome_outlined,
            title: count == 1
                ? 'Une information de document à confirmer'
                : '$count informations de documents à confirmer',
            subtitle: 'Validez uniquement les éléments utiles au carnet.',
            priority: _HomeActionPriority.info,
            onTap: () => _openVehicleCare(section: 'overview'),
          ),
        );
      }

      if (overdue == 0 && dueSoon > 0) {
        items.add(
          _HomeActionItem(
            icon: Icons.event_available_outlined,
            title: dueSoon == 1
                ? 'Un entretien approche'
                : '$dueSoon entretiens approchent',
            subtitle:
                'Anticipez la prochaine opération sans attendre une panne.',
            priority: _HomeActionPriority.warning,
            onTap: () => _openVehicleCare(section: 'maintenance'),
          ),
        );
      }
    }

    if (vehicle.mileage == null) {
      items.add(
        _HomeActionItem(
          icon: Icons.speed_outlined,
          title: 'Renseignez le kilométrage actuel',
          subtitle:
              'Il rend les échéances d’entretien beaucoup plus pertinentes.',
          priority: _HomeActionPriority.info,
          onTap: _openMileage,
        ),
      );
    }

    final failedDocuments = _documents
        .where((document) => document.status == 'failed')
        .length;
    if (failedDocuments > 0) {
      items.add(
        _HomeActionItem(
          icon: Icons.refresh_rounded,
          title: failedDocuments == 1
              ? 'Une analyse doit être relancée'
              : '$failedDocuments analyses doivent être relancées',
          subtitle: 'Retrouvez-les dans vos documents.',
          priority: _HomeActionPriority.warning,
          onTap: () => context.go('/history'),
        ),
      );
    }

    return items.take(3).toList(growable: false);
  }

  String? _nextVehicleAction(Vehicle vehicle) {
    final care = _primaryCare;
    if (care == null || care.schedules.isEmpty) return null;

    final orderedSchedules = orderedMaintenanceSchedules(
      care.schedules,
      currentMileage: vehicle.mileage,
    );
    final schedule = orderedSchedules.first;
    if (schedule.isOverdue(currentMileage: vehicle.mileage)) {
      return '${schedule.title} à régulariser';
    }
    if (schedule.dueMileage != null) {
      return '${schedule.title} vers ${_formatInteger(schedule.dueMileage!)} km';
    }
    if (schedule.dueDate != null) {
      return '${schedule.title} avant le ${_formatDate(schedule.dueDate!)}';
    }
    return schedule.title;
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name']?.toString().trim();
    final firstName = fullName == null || fullName.isEmpty
        ? null
        : fullName.split(RegExp(r'\s+')).first;
    final vehicle = _primaryVehicle;
    final priorityItems = _buildPriorityItems();

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
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            Text(
              firstName == null ? 'Bienvenue' : 'Bonjour $firstName',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Que souhaitez-vous faire aujourd’hui ?',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            _ActionCenterBanner(onTap: () => context.push<void>('/actions')),
            const SizedBox(height: 20),
            if (_loading && vehicle == null)
              const _LoadingCard(height: 132)
            else if (priorityItems.isNotEmpty)
              _PriorityPanel(items: priorityItems)
            else if (vehicle != null)
              const _UpToDateLine(),
            if (_dashboardError != null) ...[
              const SizedBox(height: 12),
              _DashboardWarning(
                message: _dashboardError!,
                onRetry: _loadDashboard,
              ),
            ],
            const SizedBox(height: 24),
            _SectionHeading(
              title: 'Mon véhicule',
              actionLabel: _vehicles.length > 1
                  ? 'Voir les véhicules'
                  : 'Gérer',
              onAction: () => context.go('/vehicles'),
            ),
            const SizedBox(height: 11),
            if (_loading && vehicle == null)
              const _LoadingCard(height: 145)
            else if (vehicle == null)
              _EmptyVehicleCard(onTap: () => _openVehicleCare())
            else
              _PrimaryVehicleCard(
                vehicle: vehicle,
                health: _primaryCare?.dashboard.health,
                nextAction: _nextVehicleAction(vehicle),
                onTap: () => _openVehicleCare(),
              ),
            const SizedBox(height: 26),
            Text('Vos espaces', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _HomeMenuGrid(
              hasVehicle: vehicle != null,
              documentCount: _documents.length,
              onVehicles: () => context.go('/vehicles'),
              onActions: () => context.push<void>('/actions'),
              onNearby: () => context.go('/nearby'),
              onSavings: () => context.go('/savings'),
              onAnalyze: _openDocumentUpload,
              onDocuments: () => context.go('/history'),
            ),
            if (vehicle != null) ...[
              const SizedBox(height: 26),
              Text(
                'Actions rapides',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _QuickVehicleActions(
                onEvent: _openEvent,
                onMileage: _openMileage,
                onOffers: _openOffers,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}

class _ActionCenterBanner extends StatelessWidget {
  const _ActionCenterBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('home-action-center-banner'),
      color: AppColors.primaryDark,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.apps_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tous les outils AutoClair',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Panne, accident, vol, départ, immobilisation, contrôle technique, garage, pneus, batterie, niveaux, visibilité, freinage, carrosserie, inspection, risques, achat, vente, entretien, conduite, '
                      'budget et économies.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ouvrir les 25 outils',
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icon(Icons.chevron_right_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpToDateLine extends StatelessWidget {
  const _UpToDateLine();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Votre suivi est à jour',
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Vous êtes à jour',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityPanel extends StatelessWidget {
  const _PriorityPanel({required this.items});

  final List<_HomeActionItem> items;

  @override
  Widget build(BuildContext context) {
    final actionableCount = items.where((item) => item.onTap != null).length;
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'À faire',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '$actionableCount',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          for (var index = 0; index < items.length; index++) ...[
            _PriorityRow(item: items[index]),
            if (index < items.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _PriorityRow extends StatelessWidget {
  const _PriorityRow({required this.item});

  final _HomeActionItem item;

  @override
  Widget build(BuildContext context) {
    final style = _HomeActionStyle.from(item.priority);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, color: style.foreground, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (item.onTap != null) ...[
            const SizedBox(width: 4),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Icon(Icons.chevron_right, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );

    if (item.onTap == null) return content;

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(15),
      child: content,
    );
  }
}

class _PrimaryVehicleCard extends StatelessWidget {
  const _PrimaryVehicleCard({
    required this.vehicle,
    required this.health,
    required this.nextAction,
    required this.onTap,
  });

  final Vehicle vehicle;
  final VehicleHealthSummary? health;
  final String? nextAction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (vehicle.nickname?.trim().isNotEmpty == true) vehicle.makeAndModel,
      if (vehicle.vehicleYear != null) vehicle.vehicleYear.toString(),
      if (vehicle.fuelType?.trim().isNotEmpty == true) vehicle.fuelType!,
      if (vehicle.mileage != null) '${_formatInteger(vehicle.mileage!)} km',
    ];
    final healthStyle = _VehicleHealthStyle.from(health?.overallStatus);

    return Material(
      color: AppColors.primaryDark,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  VehicleBrandLogo(
                    brand: vehicle.make,
                    size: 54,
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.13),
                  ),
                  const SizedBox(width: 14),
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
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            details.join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.74),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: healthStyle.background,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          healthStyle.icon,
                          color: healthStyle.foreground,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          health?.statusLabel ?? 'Suivi à compléter',
                          style: TextStyle(
                            color: healthStyle.foreground,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (nextAction != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Prochaine étape',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  nextAction!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyVehicleCard extends StatelessWidget {
  const _EmptyVehicleCard({required this.onTap});

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
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.add_road_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajouter mon véhicule',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Une seule saisie pour organiser le carnet et les documents.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMenuGrid extends StatelessWidget {
  const _HomeMenuGrid({
    required this.hasVehicle,
    required this.documentCount,
    required this.onVehicles,
    required this.onActions,
    required this.onNearby,
    required this.onSavings,
    required this.onAnalyze,
    required this.onDocuments,
  });

  final bool hasVehicle;
  final int documentCount;
  final VoidCallback onVehicles;
  final VoidCallback onActions;
  final VoidCallback onNearby;
  final VoidCallback onSavings;
  final VoidCallback onAnalyze;
  final VoidCallback onDocuments;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _HomeMenuTile(
              key: const ValueKey('home-all-tools-tile'),
              width: tileWidth,
              icon: Icons.apps_rounded,
              title: 'Tous les outils',
              subtitle:
                  'Panne, accident, vol, départ, immobilisation, contrôle technique, garage, pneus, batterie, niveaux, visibilité, freinage, carrosserie, inspection, risques, achat, vente et budget',
              foreground: AppColors.error,
              background: AppColors.errorSoft,
              onTap: onActions,
            ),
            _HomeMenuTile(
              width: tileWidth,
              icon: Icons.directions_car_outlined,
              title: 'Mes véhicules',
              subtitle: 'Suivi et entretien',
              foreground: AppColors.primary,
              background: AppColors.softPrimary,
              onTap: onVehicles,
            ),
            _HomeMenuTile(
              width: tileWidth,
              icon: Icons.near_me_outlined,
              title: 'Autour de moi',
              subtitle: 'Stations, bornes et parking',
              foreground: AppColors.success,
              background: AppColors.successSoft,
              onTap: onNearby,
            ),
            _HomeMenuTile(
              width: tileWidth,
              icon: Icons.savings_outlined,
              title: 'Mes économies',
              subtitle: 'Budget, plein, devis et assurance',
              foreground: AppColors.primary,
              background: AppColors.softPrimary,
              onTap: onSavings,
            ),
            _HomeMenuTile(
              width: tileWidth,
              icon: Icons.document_scanner_outlined,
              title: hasVehicle ? 'Analyser un document' : 'Démarrer mon suivi',
              subtitle: hasVehicle
                  ? 'Facture, devis ou contrôle'
                  : 'Ajoutez d’abord votre véhicule',
              foreground: AppColors.info,
              background: AppColors.infoSoft,
              onTap: onAnalyze,
            ),
            _HomeMenuTile(
              width: tileWidth,
              icon: Icons.folder_copy_outlined,
              title: 'Mes documents',
              subtitle: documentCount == 0
                  ? 'Tous vos documents'
                  : '$documentCount document${documentCount > 1 ? 's' : ''} suivi${documentCount > 1 ? 's' : ''}',
              foreground: AppColors.warning,
              background: AppColors.warningSoft,
              onTap: onDocuments,
            ),
          ],
        );
      },
    );
  }
}

class _HomeMenuTile extends StatelessWidget {
  const _HomeMenuTile({
    super.key,
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 188,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(21),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(21),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: foreground, size: 24),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickVehicleActions extends StatelessWidget {
  const _QuickVehicleActions({
    required this.onEvent,
    required this.onMileage,
    required this.onOffers,
  });

  final VoidCallback onEvent;
  final VoidCallback onMileage;
  final VoidCallback onOffers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 420;
        final width = twoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _CompactAction(
                icon: Icons.add_task_outlined,
                label: 'Ajouter au carnet',
                onTap: onEvent,
              ),
            ),
            SizedBox(
              width: width,
              child: _CompactAction(
                icon: Icons.speed_outlined,
                label: 'Kilométrage',
                onTap: onMileage,
              ),
            ),
            SizedBox(
              width: width,
              child: _CompactAction(
                icon: Icons.local_offer_outlined,
                label: 'Promos en cours',
                onTap: onOffers,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
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

class _DashboardWarning extends StatelessWidget {
  const _DashboardWarning({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_problem_outlined, color: AppColors.warning),
          const SizedBox(width: 9),
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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }
}

enum _HomeActionPriority { urgent, warning, info, success }

class _HomeActionItem {
  const _HomeActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.priority,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _HomeActionPriority priority;
  final VoidCallback? onTap;
}

class _HomeActionStyle {
  const _HomeActionStyle(this.background, this.foreground);

  final Color background;
  final Color foreground;

  factory _HomeActionStyle.from(_HomeActionPriority priority) =>
      switch (priority) {
        _HomeActionPriority.urgent => const _HomeActionStyle(
          AppColors.errorSoft,
          AppColors.error,
        ),
        _HomeActionPriority.warning => const _HomeActionStyle(
          AppColors.warningSoft,
          AppColors.warning,
        ),
        _HomeActionPriority.info => const _HomeActionStyle(
          AppColors.infoSoft,
          AppColors.info,
        ),
        _HomeActionPriority.success => const _HomeActionStyle(
          AppColors.successSoft,
          AppColors.success,
        ),
      };
}

class _VehicleHealthStyle {
  const _VehicleHealthStyle(this.background, this.foreground, this.icon);

  final Color background;
  final Color foreground;
  final IconData icon;

  factory _VehicleHealthStyle.from(String? status) => switch (status) {
    'GOOD' => const _VehicleHealthStyle(
      AppColors.successSoft,
      AppColors.success,
      Icons.verified_outlined,
    ),
    'WATCH' => const _VehicleHealthStyle(
      AppColors.warningSoft,
      AppColors.warning,
      Icons.visibility_outlined,
    ),
    'ACTION_NEEDED' => const _VehicleHealthStyle(
      AppColors.errorSoft,
      AppColors.error,
      Icons.priority_high,
    ),
    _ => const _VehicleHealthStyle(
      AppColors.infoSoft,
      AppColors.info,
      Icons.fact_check_outlined,
    ),
  };
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String _formatInteger(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    if (index > 0 && (raw.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(raw[index]);
  }
  return buffer.toString();
}
