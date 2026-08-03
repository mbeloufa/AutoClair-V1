import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'vehicle_care_models.dart';
import 'vehicle_care_service.dart';

enum _CareSection { overview, timeline, maintenance, alerts }

class VehicleCarePage extends StatefulWidget {
  const VehicleCarePage({
    required this.vehicleId,
    this.initialSection,
    super.key,
  });

  final String vehicleId;
  final String? initialSection;

  @override
  State<VehicleCarePage> createState() => _VehicleCarePageState();
}

class _VehicleCarePageState extends State<VehicleCarePage> {
  final _vehicleService = VehicleService();
  final _careService = VehicleCareService();

  Vehicle? _vehicle;
  VehicleCareBundle? _bundle;
  late _CareSection _section;
  bool _loading = true;
  bool _actionInProgress = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _section = switch (widget.initialSection) {
      'timeline' => _CareSection.timeline,
      'maintenance' => _CareSection.maintenance,
      'alerts' => _CareSection.alerts,
      _ => _CareSection.overview,
    };
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
      final vehicle = await _vehicleService.fetchVehicle(widget.vehicleId);
      final bundle = await _careService.loadBundle(widget.vehicleId);
      if (!mounted) return;
      setState(() {
        _vehicle = vehicle;
        _bundle = bundle;
      });
    } on VehicleServiceException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on VehicleCareException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEventForm({String? eventType}) async {
    final changed = await context.push<bool>(
      '/vehicles/${widget.vehicleId}/care/events/new',
      extra: eventType,
    );
    if (changed == true) await _load();
  }

  Future<void> _openOdometer() async {
    final changed = await context.push<bool>(
      '/vehicles/${widget.vehicleId}/care/odometer/new',
      extra: _vehicle?.mileage,
    );
    if (changed == true) await _load();
  }

  Future<void> _applyPlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Créer l'échéancier indicatif ?"),
        content: const Text(
          "AutoClair ajoutera un plan générique adapté à l'énergie du véhicule. "
          "Les échéances restent indicatives et doivent être confirmées avec "
          "le carnet du constructeur.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Créer le plan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runAction(() async {
      final count = await _careService.applyDefaultMaintenancePlan(
        widget.vehicleId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? '$count échéance(s) ajoutée(s).'
                  : "L'échéancier est déjà en place.",
            ),
          ),
        );
      }
      await _load();
      if (mounted) setState(() => _section = _CareSection.maintenance);
    });
  }

  Future<void> _extractSuggestions() async {
    final documentCount = _bundle?.completedDocumentCount ?? 0;
    if (documentCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Aucun document analysé n'est associé à ce véhicule."),
        ),
      );
      return;
    }

    await _runAction(() async {
      final count = await _careService.extractDocumentSuggestions(
        widget.vehicleId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? '$count nouvelle(s) suggestion(s) préparée(s).'
                  : 'Les documents ont été vérifiés. Aucune nouvelle suggestion.',
            ),
          ),
        );
      }
      await _load();
    });
  }

  Future<void> _confirmSuggestion(VehicleDocumentSuggestion suggestion) async {
    await _runAction(() async {
      await _careService.confirmSuggestion(
        suggestionId: suggestion.id,
        vehicleId: widget.vehicleId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Information ajoutée au carnet.')),
        );
      }
      await _load();
    });
  }

  Future<void> _dismissSuggestion(VehicleDocumentSuggestion suggestion) async {
    await _runAction(() async {
      await _careService.dismissSuggestion(suggestion.id);
      await _load();
    });
  }

  Future<void> _updateRecall(VehicleRecallAlert recall, String status) async {
    await _runAction(() async {
      await _careService.updateRecallStatus(
        matchId: recall.matchId,
        status: status,
      );
      await _load();
    });
  }

  Future<void> _openRecallUrl(String? rawUrl) async {
    final uri = Uri.tryParse(rawUrl ?? '');
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Le lien du rappel n'a pas pu être ouvert."),
          ),
        );
      }
    }
  }

  Future<void> _completeSchedule(VehicleMaintenanceSchedule schedule) async {
    final result = await showModalBottomSheet<_ScheduleCompletionData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _ScheduleCompletionSheet(
        schedule: schedule,
        currentMileage: _vehicle?.mileage,
      ),
    );
    if (result == null) return;

    await _runAction(() async {
      await _careService.completeSchedule(
        scheduleId: schedule.id,
        completedAt: result.completedAt,
        mileage: result.mileage,
        amount: result.amount,
        providerName: result.providerName,
        notes: result.notes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Entretien enregistré et prochaine échéance recalculée.",
            ),
          ),
        );
      }
      await _load();
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      await action();
    } on VehicleCareException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _vehicle;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi du véhicule'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Actualiser',
          ),
          if (vehicle != null)
            IconButton(
              onPressed: () async {
                final changed = await context.push<bool>(
                  '/vehicles/${vehicle.id}/edit',
                );
                if (changed == true) await _load();
              },
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier le véhicule',
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _section == _CareSection.timeline && !_loading
          ? FloatingActionButton.extended(
              onPressed: _actionInProgress ? null : _openEventForm,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading && _bundle == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _bundle == null) {
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
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: _load,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final vehicle = _vehicle!;
    final bundle = _bundle!;
    final visibleRecalls = bundle.dashboard.recalls
        .where(
          (recall) =>
              recall.requiresAttention && recall.isPlausibleFor(vehicle.model),
        )
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
        children: [
          _VehicleHealthHeader(
            vehicle: vehicle,
            health: bundle.dashboard.health,
          ),
          const SizedBox(height: 14),
          _QuickActions(
            disabled: _actionInProgress,
            onEvent: _openEventForm,
            onMileage: _openOdometer,
            onPlan: _applyPlan,
            onDocuments: _extractSuggestions,
          ),
          const SizedBox(height: 18),
          _SectionPicker(
            selected: _section,
            badgeCount: visibleRecalls.length + bundle.dashboard.risks.length,
            onSelected: (value) => setState(() => _section = value),
          ),
          const SizedBox(height: 18),
          if (_actionInProgress) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 14),
          ],
          switch (_section) {
            _CareSection.overview => _OverviewSection(
              bundle: bundle,
              onAddEvent: _openEventForm,
              onExtractSuggestions: _extractSuggestions,
              onConfirmSuggestion: _confirmSuggestion,
              onDismissSuggestion: _dismissSuggestion,
              onOpenTimeline: () =>
                  setState(() => _section = _CareSection.timeline),
            ),
            _CareSection.timeline => _TimelineSection(
              events: bundle.dashboard.recentEvents,
              onAddEvent: _openEventForm,
            ),
            _CareSection.maintenance => _MaintenanceSection(
              vehicle: vehicle,
              schedules: bundle.schedules,
              events: bundle.dashboard.recentEvents,
              onApplyPlan: _applyPlan,
              onComplete: _completeSchedule,
            ),
            _CareSection.alerts => _AlertsSection(
              recalls: visibleRecalls,
              risks: bundle.dashboard.risks,
              onRecallStatus: _updateRecall,
              onOpenRecall: _openRecallUrl,
            ),
          },
        ],
      ),
    );
  }
}

class _VehicleHealthHeader extends StatelessWidget {
  const _VehicleHealthHeader({required this.vehicle, required this.health});

  final Vehicle vehicle;
  final VehicleHealthSummary health;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _StatusStyle.from(health.overallStatus);
    final details = <String>[
      if (vehicle.vehicleYear != null) vehicle.vehicleYear.toString(),
      if (vehicle.fuelType?.trim().isNotEmpty == true) vehicle.fuelType!,
      if (vehicle.mileage != null) '${_formatInteger(vehicle.mileage!)} km',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
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
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.directions_car_filled_outlined,
                  color: Colors.white,
                  size: 30,
                ),
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
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusStyle.background.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusStyle.icon, size: 18, color: statusStyle.foreground),
                const SizedBox(width: 7),
                Text(
                  health.statusLabel,
                  style: TextStyle(
                    color: statusStyle.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeaderScore(
                  label: 'Entretien',
                  value: health.maintenanceScore,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderScore(
                  label: 'Sécurité',
                  value: health.safetyScore,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderScore(
                  label: 'Historique',
                  value: health.historyScore,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderScore extends StatelessWidget {
  const _HeaderScore({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            '$value %',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.disabled,
    required this.onEvent,
    required this.onMileage,
    required this.onPlan,
    required this.onDocuments,
  });

  final bool disabled;
  final VoidCallback onEvent;
  final VoidCallback onMileage;
  final VoidCallback onPlan;
  final VoidCallback onDocuments;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickActionTile(
              width: width,
              icon: Icons.add_task_outlined,
              label: 'Ajouter au carnet',
              onTap: disabled ? null : onEvent,
            ),
            _QuickActionTile(
              width: width,
              icon: Icons.speed_outlined,
              label: 'Kilométrage',
              onTap: disabled ? null : onMileage,
            ),
            _QuickActionTile(
              width: width,
              icon: Icons.event_repeat_outlined,
              label: "Plan d'entretien",
              onTap: disabled ? null : onPlan,
            ),
            _QuickActionTile(
              width: width,
              icon: Icons.auto_awesome_outlined,
              label: 'Lire mes documents',
              onTap: disabled ? null : onDocuments,
            ),
          ],
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.softPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    style: Theme.of(context).textTheme.labelLarge,
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

class _SectionPicker extends StatelessWidget {
  const _SectionPicker({
    required this.selected,
    required this.badgeCount,
    required this.onSelected,
  });

  final _CareSection selected;
  final int badgeCount;
  final ValueChanged<_CareSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(_CareSection.overview, 'Synthèse', Icons.dashboard_outlined),
          const SizedBox(width: 8),
          _chip(_CareSection.timeline, 'Carnet', Icons.timeline_outlined),
          const SizedBox(width: 8),
          _chip(
            _CareSection.maintenance,
            'Entretien',
            Icons.build_circle_outlined,
          ),
          const SizedBox(width: 8),
          _chip(
            _CareSection.alerts,
            badgeCount > 0 ? 'Sécurité ($badgeCount)' : 'Sécurité',
            Icons.notifications_active_outlined,
          ),
        ],
      ),
    );
  }

  Widget _chip(_CareSection value, String label, IconData icon) {
    return ChoiceChip(
      selected: selected == value,
      onSelected: (_) => onSelected(value),
      avatar: Icon(icon, size: 18),
      label: Text(label),
      showCheckmark: false,
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.bundle,
    required this.onAddEvent,
    required this.onExtractSuggestions,
    required this.onConfirmSuggestion,
    required this.onDismissSuggestion,
    required this.onOpenTimeline,
  });

  final VehicleCareBundle bundle;
  final VoidCallback onAddEvent;
  final VoidCallback onExtractSuggestions;
  final ValueChanged<VehicleDocumentSuggestion> onConfirmSuggestion;
  final ValueChanged<VehicleDocumentSuggestion> onDismissSuggestion;
  final VoidCallback onOpenTimeline;

  @override
  Widget build(BuildContext context) {
    final dashboard = bundle.dashboard;
    final upcomingActions = dashboard.upcomingActions
        .where((reminder) => reminder.sourceType != 'RECALL')
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Santé du dossier',
          subtitle:
              'Des indicateurs expliqués, jamais une note mécanique absolue',
        ),
        const SizedBox(height: 10),
        _HealthDetailsCard(health: dashboard.health),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'À faire bientôt',
          subtitle: 'Échéances et actions calculées pour ce véhicule',
        ),
        const SizedBox(height: 10),
        if (upcomingActions.isEmpty)
          const _EmptyPanel(
            icon: Icons.task_alt_outlined,
            title: 'Aucune action urgente',
            message:
                "Ajoutez un plan d'entretien ou mettez à jour le kilométrage "
                'pour obtenir des échéances plus précises.',
          )
        else
          ...upcomingActions
              .take(5)
              .map(
                (reminder) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReminderCard(reminder: reminder),
                ),
              ),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Informations détectées',
          subtitle:
              '${bundle.completedDocumentCount} document(s) analysé(s) associé(s)',
          actionLabel: 'Vérifier',
          onAction: onExtractSuggestions,
        ),
        const SizedBox(height: 10),
        if (bundle.suggestions.isEmpty)
          _EmptyPanel(
            icon: Icons.auto_awesome_outlined,
            title: 'Aucune suggestion en attente',
            message:
                'AutoClair peut relire les analyses existantes et vous proposer '
                'les opérations, kilométrages et dépenses à ajouter.',
            actionLabel: bundle.completedDocumentCount > 0
                ? 'Analyser mes documents'
                : null,
            onAction: bundle.completedDocumentCount > 0
                ? onExtractSuggestions
                : null,
          )
        else
          ...bundle.suggestions
              .take(8)
              .map(
                (suggestion) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SuggestionCard(
                    suggestion: suggestion,
                    onConfirm: () => onConfirmSuggestion(suggestion),
                    onDismiss: () => onDismissSuggestion(suggestion),
                  ),
                ),
              ),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Budget',
          subtitle: 'Dépenses enregistrées automatiquement ou manuellement',
        ),
        const SizedBox(height: 10),
        _BudgetCard(expenses: dashboard.expenses),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Derniers événements',
          subtitle: 'Les 20 événements les plus récents sont conservés ici',
          actionLabel: 'Tout voir',
          onAction: onOpenTimeline,
        ),
        const SizedBox(height: 10),
        if (dashboard.recentEvents.isEmpty)
          _EmptyPanel(
            icon: Icons.history_toggle_off_outlined,
            title: 'Le carnet est encore vide',
            message:
                'Ajoutez un entretien, une réparation, un contrôle technique '
                'ou tout autre événement.',
            actionLabel: 'Ajouter un événement',
            onAction: onAddEvent,
          )
        else
          ...dashboard.recentEvents
              .take(3)
              .map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TimelineEventCard(event: event, compact: true),
                ),
              ),
      ],
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.events, required this.onAddEvent});

  final List<VehicleTimelineEvent> events;
  final VoidCallback onAddEvent;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return _EmptyPanel(
        icon: Icons.timeline_outlined,
        title: 'Aucun événement enregistré',
        message:
            'Créez la première ligne de vie du véhicule en moins de trente secondes.',
        actionLabel: 'Ajouter un événement',
        onAction: onAddEvent,
      );
    }

    return Column(
      children: [
        for (var index = 0; index < events.length; index++)
          _TimelineRow(
            event: events[index],
            isLast: index == events.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});

  final VehicleTimelineEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final style = _EventStyle.from(event.eventType);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: style.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, size: 18, color: style.foreground),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: _TimelineEventCard(event: event),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEventCard extends StatelessWidget {
  const _TimelineEventCard({required this.event, this.compact = false});

  final VehicleTimelineEvent event;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      _formatDate(event.occurredAt),
      if (event.mileage != null) '${_formatInteger(event.mileage!)} km',
      if (event.amount != null) '${event.amount!.toStringAsFixed(2)} €',
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 15 : 17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              _SmallTag(label: event.typeLabel),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            details.join(' • '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (event.providerName != null) ...[
            const SizedBox(height: 5),
            Text(
              event.providerName!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (!compact && event.description != null) ...[
            const SizedBox(height: 8),
            Text(event.description!),
          ],
          if (event.sourceType == 'DOCUMENT_AI' ||
              event.sourceType == 'USER_CONFIRMED') ...[
            const SizedBox(height: 9),
            const Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 15,
                  color: AppColors.info,
                ),
                SizedBox(width: 5),
                Text(
                  'Issu d’un document confirmé',
                  style: TextStyle(color: AppColors.info, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MaintenanceSection extends StatelessWidget {
  const _MaintenanceSection({
    required this.vehicle,
    required this.schedules,
    required this.events,
    required this.onApplyPlan,
    required this.onComplete,
  });

  final Vehicle vehicle;
  final List<VehicleMaintenanceSchedule> schedules;
  final List<VehicleTimelineEvent> events;
  final VoidCallback onApplyPlan;
  final ValueChanged<VehicleMaintenanceSchedule> onComplete;

  @override
  Widget build(BuildContext context) {
    const maintenanceTypes = <String>{
      'MAINTENANCE',
      'REPAIR',
      'INSPECTION',
      'REINSPECTION',
      'TYRES',
    };
    final maintenanceEvents = events
        .where((event) => maintenanceTypes.contains(event.eventType))
        .take(8)
        .toList(growable: false);
    final orderedSchedules = orderedMaintenanceSchedules(
      schedules,
      currentMileage: vehicle.mileage,
    );
    final overdueCount = orderedSchedules
        .where(
          (schedule) => schedule.isOverdue(currentMileage: vehicle.mileage),
        )
        .length;
    final dueSoonCount = orderedSchedules
        .where(
          (schedule) => schedule.isDueSoon(currentMileage: vehicle.mileage),
        )
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (orderedSchedules.isEmpty)
          _EmptyPanel(
            icon: Icons.event_repeat_outlined,
            title: "Créez votre timeline d'entretien",
            message:
                "AutoClair préparera gratuitement des repères adaptés à l'énergie "
                'du véhicule. Vous gardez toujours la décision finale.',
            actionLabel: 'Créer mon échéancier',
            onAction: onApplyPlan,
          )
        else ...[
          _MaintenanceSummary(
            scheduleCount: orderedSchedules.length,
            overdueCount: overdueCount,
            dueSoonCount: dueSoonCount,
            nextSchedule: orderedSchedules.first,
            currentMileage: vehicle.mileage,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.info),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Les échéances sont des repères. Le carnet constructeur et '
                    'les préconisations du garage restent prioritaires.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            title: 'À venir',
            subtitle: overdueCount > 0
                ? '$overdueCount opération(s) à régulariser en priorité'
                : 'Vos prochaines opérations, dans l’ordre',
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < orderedSchedules.length; index++)
            _MaintenanceTimelineRow(
              schedule: orderedSchedules[index],
              currentMileage: vehicle.mileage,
              isLast: index == orderedSchedules.length - 1,
              onComplete: () => onComplete(orderedSchedules[index]),
            ),
        ],
        if (maintenanceEvents.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionTitle(
            title: 'Déjà réalisé',
            subtitle: 'L’historique utile de l’entretien et des réparations',
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < maintenanceEvents.length; index++)
            _TimelineRow(
              event: maintenanceEvents[index],
              isLast: index == maintenanceEvents.length - 1,
            ),
        ] else if (orderedSchedules.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _EmptyPanel(
            icon: Icons.history_toggle_off_outlined,
            title: 'Aucun entretien confirmé',
            message:
                'Les opérations validées apparaîtront ici pour former '
                'progressivement l’historique du véhicule.',
          ),
        ],
      ],
    );
  }
}

class _MaintenanceSummary extends StatelessWidget {
  const _MaintenanceSummary({
    required this.scheduleCount,
    required this.overdueCount,
    required this.dueSoonCount,
    required this.nextSchedule,
    required this.currentMileage,
  });

  final int scheduleCount;
  final int overdueCount;
  final int dueSoonCount;
  final VehicleMaintenanceSchedule nextSchedule;
  final int? currentMileage;

  @override
  Widget build(BuildContext context) {
    final nextState = nextSchedule.isOverdue(currentMileage: currentMileage)
        ? 'À régulariser'
        : nextSchedule.isDueSoon(currentMileage: currentMileage)
        ? 'À prévoir bientôt'
        : 'À anticiper';

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Votre entretien en un coup d’œil',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MaintenanceMetric(
                  value: '$scheduleCount',
                  label: 'à venir',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _MaintenanceMetric(
                  value: '$dueSoonCount',
                  label: 'bientôt',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _MaintenanceMetric(
                  value: '$overdueCount',
                  label: 'en retard',
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            nextState,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nextSchedule.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceMetric extends StatelessWidget {
  const _MaintenanceMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceTimelineRow extends StatelessWidget {
  const _MaintenanceTimelineRow({
    required this.schedule,
    required this.currentMileage,
    required this.isLast,
    required this.onComplete,
  });

  final VehicleMaintenanceSchedule schedule;
  final int? currentMileage;
  final bool isLast;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final overdue = schedule.isOverdue(currentMileage: currentMileage);
    final dueSoon = schedule.isDueSoon(currentMileage: currentMileage);
    final foreground = overdue
        ? AppColors.error
        : dueSoon
        ? AppColors.warning
        : AppColors.success;
    final background = overdue
        ? AppColors.errorSoft
        : dueSoon
        ? AppColors.warningSoft
        : AppColors.successSoft;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: foreground.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    overdue
                        ? Icons.priority_high
                        : dueSoon
                        ? Icons.schedule_outlined
                        : Icons.build_outlined,
                    size: 18,
                    color: foreground,
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: _ScheduleTimelineCard(
                schedule: schedule,
                overdue: overdue,
                dueSoon: dueSoon,
                foreground: foreground,
                background: background,
                onComplete: onComplete,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTimelineCard extends StatelessWidget {
  const _ScheduleTimelineCard({
    required this.schedule,
    required this.overdue,
    required this.dueSoon,
    required this.foreground,
    required this.background,
    required this.onComplete,
  });

  final VehicleMaintenanceSchedule schedule;
  final bool overdue;
  final bool dueSoon;
  final Color foreground;
  final Color background;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final dueParts = <String>[
      if (schedule.dueDate != null)
        'avant le ${_formatDate(schedule.dueDate!)}',
      if (schedule.dueMileage != null)
        'vers ${_formatInteger(schedule.dueMileage!)} km',
    ];
    final status = overdue
        ? 'En retard'
        : dueSoon
        ? 'À prévoir bientôt'
        : 'À venir';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  schedule.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            dueParts.isEmpty ? 'Échéance à préciser' : dueParts.join(' ou '),
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
          ),
          if (schedule.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(schedule.reason, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onComplete,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('C’est fait'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsSection extends StatelessWidget {
  const _AlertsSection({
    required this.recalls,
    required this.risks,
    required this.onRecallStatus,
    required this.onOpenRecall,
  });

  final List<VehicleRecallAlert> recalls;
  final List<VehicleRiskAlert> risks;
  final void Function(VehicleRecallAlert recall, String status) onRecallStatus;
  final ValueChanged<String?> onOpenRecall;

  @override
  Widget build(BuildContext context) {
    if (recalls.isEmpty && risks.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.verified_user_outlined,
        title: 'Aucune alerte pertinente',
        message:
            'Aucun rappel mentionnant explicitement ce modèle n’est à vérifier. '
            'AutoClair continuera de contrôler les nouvelles publications.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recalls.isNotEmpty) ...[
          const _RecallExplanationCard(),
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'Rappels à confirmer',
            subtitle: recalls.length == 1
                ? 'Un rapprochement suffisamment précis a été trouvé'
                : '${recalls.length} rapprochements suffisamment précis ont été trouvés',
          ),
          const SizedBox(height: 10),
          for (final recall in recalls) ...[
            _RecallCard(
              recall: recall,
              onStatus: (status) => onRecallStatus(recall, status),
              onOpenSource: () => onOpenRecall(recall.recallUrl),
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (risks.isNotEmpty) ...[
          if (recalls.isNotEmpty) const SizedBox(height: 18),
          _SectionTitle(
            title: 'Points de vigilance',
            subtitle:
                'Conseils documentés, à distinguer d’un défaut certain du véhicule',
          ),
          const SizedBox(height: 10),
          for (final risk in risks) ...[
            _RiskCard(risk: risk),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _RecallExplanationCard extends StatelessWidget {
  const _RecallExplanationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.16)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.info),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'AutoClair n’affiche un rappel que lorsque le modèle est '
              'explicitement cité. Cela reste une présélection : seul le '
              'constructeur peut confirmer le véhicule avec son VIN.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder});

  final VehicleReminder reminder;

  @override
  Widget build(BuildContext context) {
    final style = _PriorityStyle.from(reminder.priority);
    final due = <String>[
      if (reminder.dueAt != null) _formatRelativeDate(reminder.dueAt!),
      if (reminder.dueMileage != null)
        '${_formatInteger(reminder.dueMileage!)} km',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(style.icon, color: style.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reminder.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (due.isNotEmpty) _SmallTag(label: due.join(' • ')),
                  ],
                ),
                if (reminder.message.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(reminder.message),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.onConfirm,
    required this.onDismiss,
  });

  final VehicleDocumentSuggestion suggestion;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final payload = suggestion.payload;
    final details = <String>[
      if (payload['mileage'] != null) '${payload['mileage']} km',
      if (payload['amount'] != null) '${payload['amount']} €',
      if (suggestion.confidence != null)
        'Confiance ${(suggestion.confidence! * 100).round()} %',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.info),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  suggestion.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _SmallTag(label: suggestion.typeLabel),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              details.join(' • '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  child: const Text('Ignorer'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  child: const Text('Ajouter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthDetailsCard extends StatelessWidget {
  const _HealthDetailsCard({required this.health});

  final VehicleHealthSummary health;

  @override
  Widget build(BuildContext context) {
    final scores = <(String, int, IconData)>[
      ('Entretien', health.maintenanceScore, Icons.build_outlined),
      ('Sécurité', health.safetyScore, Icons.health_and_safety_outlined),
      ('Administratif', health.administrativeScore, Icons.badge_outlined),
      ('Historique', health.historyScore, Icons.history_outlined),
      (
        'Suivi budget',
        health.budgetTrackingScore,
        Icons.account_balance_wallet_outlined,
      ),
      ('Préparation vente', health.saleReadinessScore, Icons.sell_outlined),
    ];

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 15,
            children: [
              for (final score in scores)
                SizedBox(
                  width: itemWidth,
                  child: _HealthScoreLine(
                    label: score.$1,
                    value: score.$2,
                    icon: score.$3,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HealthScoreLine extends StatelessWidget {
  const _HealthScoreLine({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = value >= 75
        ? AppColors.success
        : value >= 50
        ? AppColors.warning
        : AppColors.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Text(
              '$value %',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 7,
            color: color,
            backgroundColor: AppColors.border,
          ),
        ),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.expenses});

  final VehicleExpenseSummary expenses;

  @override
  Widget build(BuildContext context) {
    final categories = expenses.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _BudgetValue(
                  label: '12 derniers mois',
                  value: expenses.totalLast12Months,
                ),
              ),
              Container(width: 1, height: 48, color: AppColors.border),
              Expanded(
                child: _BudgetValue(
                  label: 'Depuis le début',
                  value: expenses.totalAllTime,
                ),
              ),
            ],
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            for (final category in categories.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(_expenseCategoryLabel(category.key))),
                    Text(
                      '${category.value.toStringAsFixed(2)} €',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

class _BudgetValue extends StatelessWidget {
  const _BudgetValue({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${value.toStringAsFixed(2)} €',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _RecallCard extends StatelessWidget {
  const _RecallCard({
    required this.recall,
    required this.onStatus,
    required this.onOpenSource,
  });

  final VehicleRecallAlert recall;
  final ValueChanged<String> onStatus;
  final VoidCallback onOpenSource;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.errorSoft,
          child: Icon(Icons.campaign_outlined, color: AppColors.error),
        ),
        title: Text(recall.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _SmallTag(label: recall.statusLabel),
              _SmallTag(label: recall.confidenceLabel),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Ce rappel est proposé parce que le modèle est explicitement '
              'mentionné dans la publication officielle. Vérifiez ensuite le '
              'VIN auprès du constructeur ou du réseau de la marque.',
            ),
          ),
          if (recall.modelsReferences.isNotEmpty)
            _DetailLine(
              label: 'Modèles mentionnés',
              value: recall.modelsReferences,
            ),
          if (recall.risks.isNotEmpty)
            _DetailLine(label: 'Risque décrit', value: recall.risks),
          if (recall.consumerActions.isNotEmpty)
            _DetailLine(
              label: 'Action recommandée',
              value: recall.consumerActions,
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (recall.recallUrl != null) ...[
                TextButton.icon(
                  onPressed: onOpenSource,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Voir la source'),
                ),
                const Spacer(),
              ] else
                const Spacer(),
              PopupMenuButton<String>(
                onSelected: onStatus,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'TO_CHECK',
                    child: Text('À vérifier avec le VIN'),
                  ),
                  PopupMenuItem(
                    value: 'POSSIBLE',
                    child: Text('Compatibilité confirmée par la marque'),
                  ),
                  PopupMenuItem(
                    value: 'NOT_CONCERNED',
                    child: Text('Mon véhicule n’est pas concerné'),
                  ),
                  PopupMenuItem(
                    value: 'SCHEDULED',
                    child: Text('Intervention programmée'),
                  ),
                  PopupMenuItem(
                    value: 'COMPLETED',
                    child: Text('Rappel effectué'),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Mettre à jour',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.risk});

  final VehicleRiskAlert risk;

  @override
  Widget build(BuildContext context) {
    final style = _PriorityStyle.from(risk.severity);
    final mileage = switch ((risk.mileageMin, risk.mileageMax)) {
      (final min?, final max?) =>
        'Fenêtre indicative : ${_formatInteger(min)} à ${_formatInteger(max)} km',
      (final min?, null) => 'À partir de ${_formatInteger(min)} km',
      (null, final max?) => "Jusqu'à ${_formatInteger(max)} km",
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
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
                  color: style.background,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(style.icon, color: style.foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  risk.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _SmallTag(
                label: 'Confiance ${_confidenceLabel(risk.confidence)}',
              ),
            ],
          ),
          if (risk.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(risk.description),
          ],
          if (mileage != null) ...[
            const SizedBox(height: 9),
            Text(mileage, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
          if (risk.recommendedAction.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text('Conseil : ${risk.recommendedAction}'),
          ],
          if (risk.sourceName.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              'Source : ${risk.sourceName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleCompletionData {
  const _ScheduleCompletionData({
    required this.completedAt,
    this.mileage,
    this.amount,
    this.providerName,
    this.notes,
  });

  final DateTime completedAt;
  final int? mileage;
  final double? amount;
  final String? providerName;
  final String? notes;
}

class _ScheduleCompletionSheet extends StatefulWidget {
  const _ScheduleCompletionSheet({
    required this.schedule,
    required this.currentMileage,
  });

  final VehicleMaintenanceSchedule schedule;
  final int? currentMileage;

  @override
  State<_ScheduleCompletionSheet> createState() =>
      _ScheduleCompletionSheetState();
}

class _ScheduleCompletionSheetState extends State<_ScheduleCompletionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _mileageController;
  final _amountController = TextEditingController();
  final _providerController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _completedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _mileageController = TextEditingController(
      text: widget.currentMileage?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _mileageController.dispose();
    _amountController.dispose();
    _providerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _completedAt,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) {
      setState(
        () => _completedAt = DateTime(date.year, date.month, date.day, 12),
      );
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _ScheduleCompletionData(
        completedAt: _completedAt,
        mileage: _parseInteger(_mileageController.text),
        amount: _parseDecimal(_amountController.text),
        providerName: _nullable(_providerController.text),
        notes: _nullable(_notesController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Entretien réalisé',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 5),
              Text(widget.schedule.title),
              const SizedBox(height: 18),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date de réalisation',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(_formatDate(_completedAt)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mileageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kilométrage',
                  suffixText: 'km',
                  prefixIcon: Icon(Icons.speed_outlined),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  return _parseInteger(text) == null
                      ? 'Kilométrage invalide.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Montant',
                  suffixText: '€',
                  prefixIcon: Icon(Icons.euro_outlined),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  return _parseDecimal(text) == null
                      ? 'Montant invalide.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _providerController,
                decoration: const InputDecoration(
                  labelText: 'Garage ou intervenant',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Valider et recalculer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.softPrimary,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: AppColors.primary, size: 29),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 15),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(value),
        ],
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.softPrimary,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle(this.background, this.foreground, this.icon);

  final Color background;
  final Color foreground;
  final IconData icon;

  factory _StatusStyle.from(String status) => switch (status) {
    'GOOD' => const _StatusStyle(
      AppColors.successSoft,
      AppColors.success,
      Icons.verified_outlined,
    ),
    'WATCH' => const _StatusStyle(
      AppColors.warningSoft,
      AppColors.warning,
      Icons.visibility_outlined,
    ),
    'ACTION_NEEDED' => const _StatusStyle(
      AppColors.errorSoft,
      AppColors.error,
      Icons.priority_high,
    ),
    _ => const _StatusStyle(
      AppColors.infoSoft,
      AppColors.info,
      Icons.fact_check_outlined,
    ),
  };
}

class _PriorityStyle {
  const _PriorityStyle(this.background, this.foreground, this.icon);

  final Color background;
  final Color foreground;
  final IconData icon;

  factory _PriorityStyle.from(String priority) => switch (priority) {
    'CRITICAL' || 'HIGH' => const _PriorityStyle(
      AppColors.errorSoft,
      AppColors.error,
      Icons.priority_high,
    ),
    'MEDIUM' => const _PriorityStyle(
      AppColors.warningSoft,
      AppColors.warning,
      Icons.schedule_outlined,
    ),
    _ => const _PriorityStyle(
      AppColors.infoSoft,
      AppColors.info,
      Icons.info_outline,
    ),
  };
}

class _EventStyle {
  const _EventStyle(this.background, this.foreground, this.icon);

  final Color background;
  final Color foreground;
  final IconData icon;

  factory _EventStyle.from(String type) => switch (type) {
    'MAINTENANCE' => const _EventStyle(
      AppColors.successSoft,
      AppColors.success,
      Icons.build_outlined,
    ),
    'REPAIR' => const _EventStyle(
      AppColors.warningSoft,
      AppColors.warning,
      Icons.handyman_outlined,
    ),
    'INSPECTION' || 'REINSPECTION' => const _EventStyle(
      AppColors.infoSoft,
      AppColors.info,
      Icons.fact_check_outlined,
    ),
    'ACCIDENT' || 'RECALL' => const _EventStyle(
      AppColors.errorSoft,
      AppColors.error,
      Icons.warning_amber_outlined,
    ),
    'TYRES' => const _EventStyle(
      AppColors.softPrimary,
      AppColors.primary,
      Icons.tire_repair_outlined,
    ),
    'ODOMETER' => const _EventStyle(
      AppColors.softPrimary,
      AppColors.primary,
      Icons.speed_outlined,
    ),
    _ => const _EventStyle(
      AppColors.softPrimary,
      AppColors.primary,
      Icons.event_note_outlined,
    ),
  };
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String _formatRelativeDate(DateTime value) {
  final today = DateTime.now();
  final base = DateTime(today.year, today.month, today.day);
  final target = value.toLocal();
  final targetDay = DateTime(target.year, target.month, target.day);
  final days = targetDay.difference(base).inDays;
  if (days == 0) return "Aujourd'hui";
  if (days == 1) return 'Demain';
  if (days > 1 && days <= 60) return 'Dans $days jours';
  if (days == -1) return 'Hier';
  if (days < -1) return 'En retard de ${days.abs()} jours';
  return _formatDate(value);
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

String _expenseCategoryLabel(String value) => switch (value) {
  'MAINTENANCE' => 'Entretien',
  'REPAIR' => 'Réparations',
  'TYRES' => 'Pneus',
  'INSPECTION' => 'Contrôle technique',
  'INSURANCE' => 'Assurance',
  'FUEL' => 'Carburant',
  'CHARGING' => 'Recharge',
  'EQUIPMENT' => 'Équipements',
  'PURCHASE' => 'Achat',
  _ => 'Autres',
};

String _confidenceLabel(String value) => switch (value) {
  'CONFIRMED' => 'confirmée',
  'HIGH' => 'élevée',
  'LOW' => 'faible',
  _ => 'moyenne',
};

int? _parseInteger(String value) {
  final text = value.trim().replaceAll(' ', '');
  if (text.isEmpty) return null;
  final parsed = int.tryParse(text);
  return parsed != null && parsed >= 0 ? parsed : null;
}

double? _parseDecimal(String value) {
  final text = value.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (text.isEmpty) return null;
  final parsed = double.tryParse(text);
  return parsed != null && parsed >= 0 ? parsed : null;
}

String? _nullable(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}
