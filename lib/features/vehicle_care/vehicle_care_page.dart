import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../commercial_offers/commercial_offer_models.dart';
import '../commercial_offers/commercial_offers_service.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_brand_logo.dart';
import '../vehicles/vehicle_service.dart';
import '../vehicles/vehicle_identification_profile.dart';
import '../vehicles/vehicle_identification_profile_card.dart';
import '../vehicles/vehicle_identification_profile_service.dart';
import 'vehicle_assistant_brief.dart';
import 'vehicle_assistant_brief_card.dart';
import 'vehicle_care_models.dart';
import 'vehicle_maintenance_presentation.dart';
import 'vehicle_care_service.dart';
import 'vehicle_event_notification_service.dart';
import 'vehicle_smart_reminder.dart';
import 'vehicle_smart_reminder_card.dart';
import 'vehicle_smart_reminder_store.dart';

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
  final _identificationProfileService = VehicleIdentificationProfileService();
  final _careService = VehicleCareService();
  final _offersService = CommercialOffersService();
  final _notificationService = VehicleEventNotificationService.instance;
  final _smartReminderStore = VehicleSmartReminderStore();
  final _careSectionKey = GlobalKey();

  Vehicle? _vehicle;
  VehicleIdentificationProfile? _identificationProfile;
  VehicleCareBundle? _bundle;
  CommercialOfferBundle? _offerBundle;
  late _CareSection _section;
  bool _loading = true;
  bool _identificationProfileLoading = false;
  bool _actionInProgress = false;
  bool _offersLoading = true;
  bool _smartRemindersEnabled = false;
  bool _smartReminderBusy = false;
  bool _smartReminderPreferenceLoaded = false;
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
        _loading = false;
        _smartReminderPreferenceLoaded = false;
      });
      unawaited(_loadOfferPreview());
      unawaited(_loadIdentificationProfile());
      unawaited(_synchronizeEventReminders(vehicle));
      unawaited(_loadSmartReminderPreference(vehicle, bundle));
    } on VehicleServiceException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on VehicleCareException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadIdentificationProfile() async {
    if (!mounted) return;
    setState(() => _identificationProfileLoading = true);
    try {
      final profile = await _identificationProfileService.fetchForVehicle(
        widget.vehicleId,
      );
      if (mounted) setState(() => _identificationProfile = profile);
    } finally {
      if (mounted) setState(() => _identificationProfileLoading = false);
    }
  }

  Future<void> _synchronizeEventReminders(Vehicle vehicle) async {
    try {
      final plans = await _careService.fetchPlannedEventReminders(vehicle.id);
      await _notificationService.synchronizeReminders(
        vehicleId: vehicle.id,
        plans: plans,
        vehicleLabel: vehicle.displayName,
      );
    } on VehicleCareException {
      // La page du carnet reste utilisable si la synchronisation locale échoue.
    } on VehicleEventNotificationException {
      // Une permission refusée ne bloque jamais le suivi du véhicule.
    }
  }

  Future<void> _loadSmartReminderPreference(
    Vehicle vehicle,
    VehicleCareBundle bundle,
  ) async {
    try {
      final enabled = await _smartReminderStore.isEnabled(vehicle.id);
      if (!mounted) return;
      setState(() => _smartRemindersEnabled = enabled);
      if (enabled) {
        await _synchronizeSmartReminders(vehicle, bundle);
      }
    } catch (_) {
      // Les préférences locales de rappel ne doivent jamais bloquer la fiche.
    } finally {
      if (mounted) setState(() => _smartReminderPreferenceLoaded = true);
    }
  }

  Future<void> _synchronizeSmartReminders(
    Vehicle vehicle,
    VehicleCareBundle bundle,
  ) async {
    final plans = buildVehicleSmartReminderPlans(
      vehicleId: vehicle.id,
      schedules: bundle.schedules,
      reminders: bundle.dashboard.upcomingActions,
    );
    try {
      await _notificationService.synchronizeEssentialReminders(
        vehicleId: vehicle.id,
        plans: plans,
        vehicleLabel: vehicle.displayName,
      );
    } catch (_) {
      // La fiche reste utilisable si la programmation locale échoue.
    }
  }

  Future<void> _setSmartReminders(bool enabled) async {
    final vehicle = _vehicle;
    final bundle = _bundle;
    if (vehicle == null || bundle == null || _smartReminderBusy) return;

    setState(() => _smartReminderBusy = true);

    try {
      if (enabled) {
        await _notificationService.ensurePermission();
        await _smartReminderStore.setEnabled(vehicle.id, true);
        await _synchronizeSmartReminders(vehicle, bundle);
      } else {
        await _smartReminderStore.setEnabled(vehicle.id, false);
        await _notificationService.cancelEssentialReminders(vehicle.id);
      }

      if (!mounted) return;
      setState(() => _smartRemindersEnabled = enabled);
      _message(
        enabled
            ? 'Rappels essentiels activés sur cet appareil.'
            : 'Rappels essentiels désactivés.',
      );
    } on VehicleEventNotificationException catch (error) {
      await _smartReminderStore.setEnabled(vehicle.id, false);
      if (!mounted) return;
      setState(() => _smartRemindersEnabled = false);
      _message(error.message);
    } catch (_) {
      if (mounted) {
        _message('Impossible de modifier les rappels pour le moment.');
      }
    } finally {
      if (mounted) setState(() => _smartReminderBusy = false);
    }
  }

  Future<void> _loadOfferPreview() async {
    if (!mounted) return;
    setState(() => _offersLoading = true);

    try {
      final bundle = await _offersService.fetchVehicleOffers(
        widget.vehicleId,
        limit: 12,
      );
      if (mounted) setState(() => _offerBundle = bundle);
    } on CommercialOffersException {
      if (mounted) setState(() => _offerBundle = null);
    } finally {
      if (mounted) setState(() => _offersLoading = false);
    }
  }

  Future<void> _openEventForm({String? eventType}) async {
    final changed = await context.push<bool>(
      '/vehicles/${widget.vehicleId}/care/events/new',
      extra: eventType,
    );
    if (!mounted) return;
    if (changed == true) await _load();
  }

  Future<void> _openOdometer() async {
    final changed = await context.push<bool>(
      '/vehicles/${widget.vehicleId}/care/odometer/new',
      extra: _vehicle?.mileage,
    );
    if (!mounted) return;
    if (changed == true) await _load();
  }

  Future<void> _openDocumentUpload() async {
    await context.push<void>('/documents/new');
    if (!mounted) return;
    await _load();
  }

  Future<void> _openCommercialOffers() async {
    await context.push<void>('/vehicles/${widget.vehicleId}/offers');
    if (!mounted) return;
    await _loadOfferPreview();
  }

  Future<void> _openVehicle360() async {
    await context.push<void>('/vehicles/${widget.vehicleId}/insight-report');
  }

  Future<void> _applyPlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Créer le plan d’entretien ?"),
        content: const Text(
          'AutoClair ajoutera des échéances indicatives. '
          'Le carnet du constructeur reste la référence.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runAction(() async {
      final count = await _careService.applyDefaultMaintenancePlan(
        widget.vehicleId,
      );
      if (mounted) {
        _message(
          count > 0
              ? '$count échéance(s) ajoutée(s).'
              : 'Le plan est déjà en place.',
        );
      }
      await _load();
      if (mounted) setState(() => _section = _CareSection.maintenance);
    });
  }

  Future<void> _extractSuggestions() async {
    final count = _bundle?.completedDocumentCount ?? 0;
    if (count == 0) {
      _message('Aucun document analysé pour ce véhicule.');
      return;
    }

    await _runAction(() async {
      final created = await _careService.extractDocumentSuggestions(
        widget.vehicleId,
      );
      if (mounted) {
        _message(
          created > 0
              ? '$created opération(s) détectée(s).'
              : 'Aucune nouvelle opération détectée.',
        );
      }
      await _load();
    });
  }

  Future<void> _confirmSuggestion(VehicleDocumentSuggestion suggestion) async {
    final data = await showModalBottomSheet<_SuggestionReviewData>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SuggestionReviewSheet(suggestion: suggestion),
    );
    if (data == null || !mounted) return;

    await _runAction(() async {
      await _careService.confirmSuggestion(
        suggestionId: suggestion.id,
        vehicleId: widget.vehicleId,
        categoryCode: suggestion.classification.category.code,
        subcategoryCode: suggestion.classification.subcategory.code,
        mileage: data.mileage,
        amount: data.amount,
      );
      if (mounted) _message('${suggestion.operationTitle} ajouté au carnet.');
      await _load();
    });
  }

  Future<void> _dismissSuggestion(VehicleDocumentSuggestion suggestion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ne pas ajouter cette opération ?'),
        content: Text(
          '« ${suggestion.operationTitle} » sera retirée de la liste.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ne pas ajouter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

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
      if (mounted) _message("Le lien du rappel n'a pas pu être ouvert.");
    }
  }

  Future<void> _completeSchedules(VehicleMaintenanceGroup group) async {
    final data = await showModalBottomSheet<_ScheduleCompletionData>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ScheduleCompletionSheet(
        schedule: group.primary,
        displayTitle: group.title,
        currentMileage: _vehicle?.mileage,
      ),
    );
    if (data == null || !mounted) return;

    await _runAction(() async {
      for (final schedule in group.schedules) {
        await _careService.completeSchedule(
          scheduleId: schedule.id,
          completedAt: data.completedAt,
          mileage: data.mileage,
          amount: data.amount,
          providerName: data.providerName,
          notes: data.notes,
        );
      }
      if (mounted) _message('Entretien enregistré.');
      await _load();
    });
  }

  void _showCareSection(_CareSection section) {
    setState(() => _section = section);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sectionContext = _careSectionKey.currentContext;
      if (sectionContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          sectionContext,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          alignment: 0.04,
        ),
      );
    });
  }

  void _handleAssistantTarget(VehicleAssistantTarget target) {
    switch (target) {
      case VehicleAssistantTarget.overview:
        _showCareSection(_CareSection.overview);
        return;
      case VehicleAssistantTarget.alerts:
        _showCareSection(_CareSection.alerts);
        return;
      case VehicleAssistantTarget.maintenance:
        _showCareSection(_CareSection.maintenance);
        return;
      case VehicleAssistantTarget.offers:
        unawaited(_openCommercialOffers());
        return;
      case VehicleAssistantTarget.mileage:
        unawaited(_openOdometer());
        return;
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      await action();
    } on VehicleCareException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon véhicule'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
          ),
          if (_vehicle != null)
            IconButton(
              onPressed: () async {
                final changed = await context.push<bool>(
                  '/vehicles/${widget.vehicleId}/edit',
                );
                if (changed == true) await _load();
              },
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier le véhicule',
            ),
        ],
      ),
      body: _body(),
      floatingActionButton: _section == _CareSection.timeline && !_loading
          ? FloatingActionButton.extended(
              onPressed: _actionInProgress ? null : _openEventForm,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter'),
            )
          : null,
    );
  }

  Widget _body() {
    if (_loading && _bundle == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _bundle == null) {
      return _ErrorPanel(message: _errorMessage!, onRetry: _load);
    }

    final vehicle = _vehicle!;
    final bundle = _bundle!;
    final recalls = bundle.dashboard.recalls
        .where(
          (recall) =>
              recall.requiresAttention && recall.isPlausibleFor(vehicle.model),
        )
        .toList(growable: false);
    final assistantBrief = VehicleAssistantBrief.build(
      vehicle: vehicle,
      bundle: bundle,
      offerCount: _offerBundle?.currentVehicleCount ?? 0,
    );
    final smartReminderPlans = buildVehicleSmartReminderPlans(
      vehicleId: vehicle.id,
      schedules: bundle.schedules,
      reminders: bundle.dashboard.upcomingActions,
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
        children: [
          _VehicleHeader(vehicle: vehicle, health: bundle.dashboard.health),
          if (_identificationProfileLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ] else if (_identificationProfile != null) ...[
            const SizedBox(height: 12),
            VehicleIdentificationProfileCard(profile: _identificationProfile!),
          ],
          const SizedBox(height: 14),
          VehicleAssistantBriefCard(
            brief: assistantBrief,
            onAction: _handleAssistantTarget,
          ),
          const SizedBox(height: 12),
          VehicleSmartReminderCard(
            enabled: _smartRemindersEnabled,
            busy: _smartReminderBusy || !_smartReminderPreferenceLoaded,
            availableCount: smartReminderPlans.length,
            onChanged: (value) => unawaited(_setSmartReminders(value)),
          ),
          const SizedBox(height: 14),
          VehicleCarePrimaryActions(
            disabled: _actionInProgress,
            onEvent: _openEventForm,
            onMileage: _openOdometer,
            onOffers: _openCommercialOffers,
            onDocument: _openDocumentUpload,
          ),
          const SizedBox(height: 18),
          KeyedSubtree(
            key: _careSectionKey,
            child: _SectionPicker(
              selected: _section,
              alertCount: recalls.length + bundle.dashboard.risks.length,
              onSelected: (value) => setState(() => _section = value),
            ),
          ),
          if (_actionInProgress) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 18),
          switch (_section) {
            _CareSection.overview => _OverviewSection(
              vehicle: vehicle,
              bundle: bundle,
              offerBundle: _offerBundle,
              offersLoading: _offersLoading,
              onOpenOffers: _openCommercialOffers,
              onOpenVehicle360: _openVehicle360,
              onExtractSuggestions: _extractSuggestions,
              onConfirmSuggestion: _confirmSuggestion,
              onDismissSuggestion: _dismissSuggestion,
              onAddEvent: _openEventForm,
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
              onApplyPlan: _applyPlan,
              onComplete: _completeSchedules,
            ),
            _CareSection.alerts => _AlertsSection(
              recalls: recalls,
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

class _VehicleHeader extends StatelessWidget {
  const _VehicleHeader({required this.vehicle, required this.health});

  final Vehicle vehicle;
  final VehicleHealthSummary health;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (vehicle.nickname?.trim().isNotEmpty == true) vehicle.makeAndModel,
      if (vehicle.vehicleYear != null) vehicle.vehicleYear.toString(),
      if (vehicle.fuelType?.trim().isNotEmpty == true) vehicle.fuelType!,
      if (vehicle.mileage != null) '${_integer(vehicle.mileage!)} km',
    ];
    final needsAction = health.overallStatus == 'ACTION_NEEDED';
    final watch = health.overallStatus == 'WATCH';
    final label = needsAction
        ? 'Une action est à prévoir'
        : watch
        ? 'Quelques points à surveiller'
        : 'Suivi à jour';
    final color = needsAction
        ? AppColors.error
        : watch
        ? AppColors.warning
        : AppColors.success;

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
              VehicleBrandLogo(
                brand: vehicle.make,
                size: 54,
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
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

class VehicleCarePrimaryActions extends StatelessWidget {
  const VehicleCarePrimaryActions({
    required this.disabled,
    required this.onEvent,
    required this.onMileage,
    required this.onOffers,
    required this.onDocument,
    super.key,
  });

  final bool disabled;
  final VoidCallback onEvent;
  final VoidCallback onMileage;
  final VoidCallback onOffers;
  final VoidCallback onDocument;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final width = compact
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ActionTile(
              width: width,
              icon: Icons.add_task_outlined,
              label: 'Ajouter au carnet',
              onTap: disabled ? null : onEvent,
            ),
            _ActionTile(
              width: width,
              icon: Icons.speed_outlined,
              label: 'Mettre à jour les km',
              onTap: disabled ? null : onMileage,
            ),
            _ActionTile(
              width: width,
              icon: Icons.local_offer_outlined,
              label: 'Voir les promos',
              onTap: disabled ? null : onOffers,
            ),
            _ActionTile(
              width: width,
              icon: Icons.document_scanner_outlined,
              label: 'Ajouter un document',
              onTap: disabled ? null : onDocument,
            ),
          ],
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
      height: 74,
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
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
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
    required this.alertCount,
    required this.onSelected,
  });

  final _CareSection selected;
  final int alertCount;
  final ValueChanged<_CareSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(_CareSection.overview, 'Résumé', Icons.home_outlined),
          const SizedBox(width: 8),
          _chip(_CareSection.timeline, 'Carnet', Icons.menu_book_outlined),
          const SizedBox(width: 8),
          _chip(_CareSection.maintenance, 'Entretien', Icons.build_outlined),
          const SizedBox(width: 8),
          _chip(
            _CareSection.alerts,
            alertCount > 0 ? 'Alertes ($alertCount)' : 'Alertes',
            Icons.notifications_none_rounded,
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
    required this.vehicle,
    required this.bundle,
    required this.offerBundle,
    required this.offersLoading,
    required this.onOpenOffers,
    required this.onOpenVehicle360,
    required this.onExtractSuggestions,
    required this.onConfirmSuggestion,
    required this.onDismissSuggestion,
    required this.onAddEvent,
    required this.onOpenTimeline,
  });

  final Vehicle vehicle;
  final VehicleCareBundle bundle;
  final CommercialOfferBundle? offerBundle;
  final bool offersLoading;
  final VoidCallback onOpenOffers;
  final VoidCallback onOpenVehicle360;
  final VoidCallback onExtractSuggestions;
  final ValueChanged<VehicleDocumentSuggestion> onConfirmSuggestion;
  final ValueChanged<VehicleDocumentSuggestion> onDismissSuggestion;
  final VoidCallback onAddEvent;
  final VoidCallback onOpenTimeline;

  @override
  Widget build(BuildContext context) {
    final reminders = bundle.dashboard.upcomingActions
        .where((item) => item.sourceType != 'RECALL')
        .toList(growable: false);
    final offerCount = offerBundle?.currentVehicleCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onOpenVehicle360,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Lancer le Bilan AutoClair 360'),
        ),
        if (offerCount > 0) ...[
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: onOpenOffers,
            icon: const Icon(Icons.local_offer_outlined),
            label: Text(
              offerCount == 1
                  ? '1 promo en cours pour ${vehicle.displayName}'
                  : '$offerCount promos en cours pour ${vehicle.displayName}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else if (offersLoading) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 22),
        _SectionTitle(title: 'À faire'),
        const SizedBox(height: 10),
        if (reminders.isEmpty)
          const _UpToDatePanel()
        else
          for (final reminder in reminders.take(4)) ...[
            _ReminderCard(reminder: reminder),
            const SizedBox(height: 9),
          ],
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Opérations détectées',
          actionLabel: bundle.completedDocumentCount > 0 ? 'Rechercher' : null,
          onAction: bundle.completedDocumentCount > 0
              ? onExtractSuggestions
              : null,
        ),
        const SizedBox(height: 10),
        if (bundle.suggestions.isEmpty)
          Text(
            bundle.completedDocumentCount == 0
                ? 'Analysez une facture ou un contrôle technique pour alimenter le carnet.'
                : 'Aucune opération à vérifier.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          )
        else
          for (final suggestion in bundle.suggestions.take(6)) ...[
            _SuggestionCard(
              suggestion: suggestion,
              onConfirm: () => onConfirmSuggestion(suggestion),
              onDismiss: () => onDismissSuggestion(suggestion),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 22),
        _SectionTitle(
          title: 'Derniers événements',
          actionLabel: 'Tout voir',
          onAction: onOpenTimeline,
        ),
        const SizedBox(height: 10),
        if (bundle.dashboard.recentEvents.isEmpty)
          _EmptyPanel(
            icon: Icons.menu_book_outlined,
            title: 'Le carnet est vide',
            message: 'Ajoutez le premier événement de ce véhicule.',
            actionLabel: 'Ajouter',
            onAction: onAddEvent,
          )
        else
          for (final event in bundle.dashboard.recentEvents.take(3)) ...[
            _EventCard(event: event, compact: true),
            const SizedBox(height: 9),
          ],
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
        icon: Icons.menu_book_outlined,
        title: 'Le carnet est vide',
        message: 'Ajoutez un entretien, une réparation ou une démarche.',
        actionLabel: 'Ajouter un événement',
        onAction: onAddEvent,
      );
    }

    return Column(
      children: [
        for (final event in events) ...[
          _EventCard(event: event),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, this.compact = false});

  final VehicleTimelineEvent event;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      _date(event.occurredAt),
      if (event.mileage != null) '${_integer(event.mileage!)} km',
      if (event.amount != null) '${_money(event.amount!)} €',
    ];
    final planned = event.status == 'PLANNED';

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
              color: planned ? AppColors.warningSoft : AppColors.softPrimary,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              planned ? Icons.schedule_outlined : Icons.check_rounded,
              color: planned ? AppColors.warning : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${event.categoryLabel} • ${event.typeLabel}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(details.join(' • ')),
                if (!compact && event.providerName != null) ...[
                  const SizedBox(height: 4),
                  Text(event.providerName!),
                ],
                if (!compact && event.locationText != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 17),
                      const SizedBox(width: 5),
                      Expanded(child: Text(event.locationText!)),
                    ],
                  ),
                ],
                if (!compact && planned && event.reminderEnabled) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, size: 17),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          event.reminderDaysBefore == null
                              ? 'Rappel activé'
                              : 'Rappel ${event.reminderDaysBefore} jour(s) avant',
                        ),
                      ),
                    ],
                  ),
                ],
                if (!compact && event.sourceDocumentId != null) ...[
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.push<void>(
                        '/history/${event.sourceDocumentId}/analysis',
                      ),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Voir le document'),
                    ),
                  ),
                ],
                if (!compact && event.description != null) ...[
                  const SizedBox(height: 5),
                  Text(event.description!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceSection extends StatelessWidget {
  const _MaintenanceSection({
    required this.vehicle,
    required this.schedules,
    required this.onApplyPlan,
    required this.onComplete,
  });

  final Vehicle vehicle;
  final List<VehicleMaintenanceSchedule> schedules;
  final VoidCallback onApplyPlan;
  final ValueChanged<VehicleMaintenanceGroup> onComplete;

  @override
  Widget build(BuildContext context) {
    final groups = groupVehicleMaintenanceSchedules(
      schedules,
      currentMileage: vehicle.mileage,
    );

    if (groups.isEmpty) {
      return _EmptyPanel(
        icon: Icons.event_repeat_outlined,
        title: 'Aucun plan d’entretien',
        message: 'Créez un plan indicatif, puis adaptez-le à votre véhicule.',
        actionLabel: 'Créer le plan',
        onAction: onApplyPlan,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onApplyPlan,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Compléter le plan'),
        ),
        const SizedBox(height: 12),
        for (final group in groups) ...[
          _ScheduleCard(
            group: group,
            currentMileage: vehicle.mileage,
            onComplete: () => onComplete(group),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.group,
    required this.currentMileage,
    required this.onComplete,
  });

  final VehicleMaintenanceGroup group;
  final int? currentMileage;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final overdue = group.isOverdue(currentMileage: currentMileage);
    final dueSoon = group.isDueSoon(currentMileage: currentMileage);
    final due = <String>[
      if (group.dueDate != null) _date(group.dueDate!),
      if (group.dueMileage != null) '${_integer(group.dueMileage!)} km',
    ];
    final status = overdue
        ? 'En retard'
        : dueSoon
        ? 'À prévoir bientôt'
        : 'À venir';
    final color = overdue
        ? AppColors.error
        : dueSoon
        ? AppColors.warning
        : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                status,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (due.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(due.join(' • ')),
          ],
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onComplete,
            child: const Text('Marquer comme réalisé'),
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
      return const _UpToDatePanel(message: 'Aucune alerte pour ce véhicule.');
    }

    return Column(
      children: [
        for (final recall in recalls) ...[
          _RecallCard(
            recall: recall,
            onStatus: (status) => onRecallStatus(recall, status),
            onOpen: () => onOpenRecall(recall.recallUrl),
          ),
          const SizedBox(height: 10),
        ],
        for (final risk in risks) ...[
          _RiskCard(risk: risk),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder});

  final VehicleReminder reminder;

  @override
  Widget build(BuildContext context) {
    final displayTitle = vehicleMaintenanceDisplayTitle(reminder.title);
    final normalizedMaintenance = displayTitle != reminder.title.trim();
    final due = <String>[
      if (reminder.dueAt != null) _date(reminder.dueAt!),
      if (reminder.dueMileage != null) '${_integer(reminder.dueMileage!)} km',
    ];
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
          const Icon(Icons.event_outlined, color: AppColors.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (due.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(due.join(' • ')),
                ],
                if (!normalizedMaintenance && reminder.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
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
    final details = <String>[
      if (suggestion.detectedMileage != null)
        '${_integer(suggestion.detectedMileage!)} km',
      if (suggestion.detectedAmount != null)
        '${_money(suggestion.detectedAmount!)} €',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            suggestion.operationTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          Text(
            '${suggestion.categoryLabel} • ${suggestion.typeLabel}',
            style: const TextStyle(
              color: AppColors.info,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(details.join(' • ')),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Vérifier et ajouter'),
          ),
          TextButton(onPressed: onDismiss, child: const Text('Ne pas ajouter')),
        ],
      ),
    );
  }
}

class _RecallCard extends StatelessWidget {
  const _RecallCard({
    required this.recall,
    required this.onStatus,
    required this.onOpen,
  });

  final VehicleRecallAlert recall;
  final ValueChanged<String> onStatus;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheduled = recall.status.toUpperCase() == 'SCHEDULED';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheduled ? AppColors.errorSoft : AppColors.warningSoft,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: (scheduled ? AppColors.error : AppColors.warning).withValues(
            alpha: 0.22,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            scheduled
                ? 'Rappel constructeur programmé'
                : 'Campagne constructeur à vérifier',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            scheduled
                ? 'Une intervention a été indiquée comme programmée pour ce véhicule.'
                : 'AutoClair a trouvé une campagne qui peut correspondre au modèle. Cela ne confirme pas que ce véhicule est concerné. Vérifiez avec le VIN auprès du constructeur ou de son réseau.',
          ),
          const SizedBox(height: 9),
          Text(
            recall.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (recall.modelsReferences.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text('Modèles indiqués : ${recall.modelsReferences}'),
          ],
          if (recall.risks.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text('Risque indiqué par la source : ${recall.risks}'),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: onOpen,
                child: const Text('Vérifier la source'),
              ),
              PopupMenuButton<String>(
                onSelected: onStatus,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'SCHEDULED',
                    child: Text('Intervention programmée'),
                  ),
                  PopupMenuItem(
                    value: 'COMPLETED',
                    child: Text('Rappel effectué'),
                  ),
                  PopupMenuItem(
                    value: 'NOT_CONCERNED',
                    child: Text('Véhicule non concerné'),
                  ),
                ],
                child: const Chip(label: Text('Mettre à jour')),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(risk.title, style: Theme.of(context).textTheme.titleMedium),
          if (risk.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(risk.description),
          ],
          if (risk.recommendedAction.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              risk.recommendedAction,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _UpToDatePanel extends StatelessWidget {
  const _UpToDatePanel({this.message = 'Tout est à jour pour le moment.'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

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
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionReviewData {
  const _SuggestionReviewData({this.mileage, this.amount});

  final int? mileage;
  final double? amount;
}

class _SuggestionReviewSheet extends StatefulWidget {
  const _SuggestionReviewSheet({required this.suggestion});

  final VehicleDocumentSuggestion suggestion;

  @override
  State<_SuggestionReviewSheet> createState() => _SuggestionReviewSheetState();
}

class _SuggestionReviewSheetState extends State<_SuggestionReviewSheet> {
  late final TextEditingController _mileageController;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _mileageController = TextEditingController(
      text: widget.suggestion.detectedMileage?.toString() ?? '',
    );
    _amountController = TextEditingController(
      text: widget.suggestion.detectedAmount == null
          ? ''
          : widget.suggestion.detectedAmount!
                .toStringAsFixed(2)
                .replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    _mileageController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.suggestion.operationTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 5),
          Text(
            '${widget.suggestion.categoryLabel} • ${widget.suggestion.typeLabel}',
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _mileageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Kilométrage (facultatif)',
              suffixText: 'km',
              prefixIcon: Icon(Icons.speed_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Prix (facultatif)',
              suffixText: '€',
              prefixIcon: Icon(Icons.euro_outlined),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              final mileageText = _mileageController.text.trim();
              final amountText = _amountController.text.trim().replaceAll(
                ',',
                '.',
              );
              final mileage = mileageText.isEmpty
                  ? null
                  : int.tryParse(mileageText);
              final amount = amountText.isEmpty
                  ? null
                  : double.tryParse(amountText);
              if (mileageText.isNotEmpty && (mileage == null || mileage < 0)) {
                _sheetMessage(context, 'Kilométrage invalide.');
                return;
              }
              if (amountText.isNotEmpty && (amount == null || amount < 0)) {
                _sheetMessage(context, 'Prix invalide.');
                return;
              }
              Navigator.of(
                context,
              ).pop(_SuggestionReviewData(mileage: mileage, amount: amount));
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Ajouter au carnet'),
          ),
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
    required this.displayTitle,
    required this.currentMileage,
  });

  final VehicleMaintenanceSchedule schedule;
  final String displayTitle;
  final int? currentMileage;

  @override
  State<_ScheduleCompletionSheet> createState() =>
      _ScheduleCompletionSheetState();
}

class _ScheduleCompletionSheetState extends State<_ScheduleCompletionSheet> {
  late DateTime _completedAt;
  late final TextEditingController _mileageController;
  final _amountController = TextEditingController();
  final _providerController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _completedAt = DateTime.now();
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
    final value = await showDatePicker(
      context: context,
      initialDate: _completedAt,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (value != null) setState(() => _completedAt = value);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.displayTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _selectDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date'),
              child: Text(_date(_completedAt)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mileageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Kilométrage',
              suffixText: 'km',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Prix',
              suffixText: '€',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _providerController,
            decoration: const InputDecoration(labelText: 'Garage'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              final mileage = int.tryParse(_mileageController.text.trim());
              final amount = double.tryParse(
                _amountController.text.trim().replaceAll(',', '.'),
              );
              Navigator.of(context).pop(
                _ScheduleCompletionData(
                  completedAt: _completedAt,
                  mileage: mileage,
                  amount: amount,
                  providerName: _nullIfEmpty(_providerController.text),
                  notes: _nullIfEmpty(_notesController.text),
                ),
              );
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

void _sheetMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String? _nullIfEmpty(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}

String _date(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String _integer(int value) {
  final chars = value.toString().split('').reversed.toList();
  final groups = <String>[];
  for (var index = 0; index < chars.length; index += 3) {
    groups.add(chars.skip(index).take(3).toList().reversed.join());
  }
  return groups.reversed.join(' ');
}

String _money(double value) {
  return value
      .toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)
      .replaceAll('.', ',');
}
