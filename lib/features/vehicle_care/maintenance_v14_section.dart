import 'dart:async';

import 'package:flutter/material.dart';

import '../vehicles/vehicle.dart';
import 'maintenance_v14_models.dart';
import 'maintenance_v14_service.dart';
import 'vehicle_care_models.dart';
import 'vehicle_event_notification_service.dart';
import 'vehicle_maintenance_presentation.dart';
import 'vehicle_smart_reminder.dart';
import 'vehicle_smart_reminder_store.dart';

enum _MaintenanceV14Tab { todo, history, reminders }

class MaintenanceV14Section extends StatefulWidget {
  const MaintenanceV14Section({
    required this.vehicle,
    required this.schedules,
    required this.reminders,
    required this.onRefreshPlan,
    required this.onComplete,
    required this.onOpenSource,
    super.key,
  });

  final Vehicle vehicle;
  final List<VehicleMaintenanceSchedule> schedules;
  final List<VehicleReminder> reminders;
  final VoidCallback onRefreshPlan;
  final ValueChanged<VehicleMaintenanceGroup> onComplete;
  final ValueChanged<String> onOpenSource;

  @override
  State<MaintenanceV14Section> createState() => _MaintenanceV14SectionState();
}

class _MaintenanceV14SectionState extends State<MaintenanceV14Section> {
  final _service = MaintenanceV14Service();
  final _store = VehicleSmartReminderStore();
  final _notifications = VehicleEventNotificationService.instance;

  MaintenanceV14State? _state;
  _MaintenanceV14Tab _tab = _MaintenanceV14Tab.todo;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant MaintenanceV14Section oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicle.id != widget.vehicle.id ||
        oldWidget.schedules.length != widget.schedules.length ||
        oldWidget.reminders.length != widget.reminders.length) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var loaded = await _service.load(widget.vehicle.id);
      final localEnabled = await _store.isEnabled(widget.vehicle.id);

      // Migration douce de l'ancien opt-in local vers le nouveau réglage
      // synchronisé. On ne réactive jamais un rappel que l'utilisateur avait
      // désactivé localement.
      if (localEnabled && !loaded.masterEnabled) {
        await _service.setMasterEnabled(
          vehicleId: widget.vehicle.id,
          enabled: true,
        );
        loaded = await _service.load(widget.vehicle.id);
      } else if (loaded.masterEnabled && !localEnabled) {
        await _store.setEnabled(widget.vehicle.id, true);
      }

      if (!mounted) return;
      setState(() => _state = loaded);
      await _synchronizeNotifications(loaded);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Les rappels d’entretien ne peuvent pas être chargés pour le moment.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setMaster(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (enabled) {
        await _notifications.ensurePermission();
      }
      await _store.setEnabled(widget.vehicle.id, enabled);
      await _service.setMasterEnabled(
        vehicleId: widget.vehicle.id,
        enabled: enabled,
      );
      if (!enabled) {
        await _notifications.cancelEssentialReminders(widget.vehicle.id);
      }
      await _load();
      if (mounted) {
        _message(
          enabled
              ? 'Rappels d’entretien activés.'
              : 'Rappels d’entretien désactivés.',
        );
      }
    } on VehicleEventNotificationException catch (error) {
      await _store.setEnabled(widget.vehicle.id, false);
      await _service.setMasterEnabled(
        vehicleId: widget.vehicle.id,
        enabled: false,
      );
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) {
        _message('Impossible de modifier les rappels pour le moment.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setItemEnabled(_MaintenanceItem item, bool enabled) async {
    final state = _state;
    if (state == null || _busy) return;
    setState(() => _busy = true);
    try {
      final existing = state.preferences[item.key];
      await _service.setPreference(
        vehicleId: widget.vehicle.id,
        key: item.key,
        enabled: enabled,
        leadDays: existing?.leadDays ?? item.defaultLeadDays,
        frequencyMonths: existing?.frequencyMonths ?? item.frequencyMonths,
        preferredMonth: existing?.preferredMonth ?? item.preferredMonth,
      );
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setQuickCheckFrequency(int months) async {
    final state = _state;
    if (state == null || _busy) return;
    final item = _items(
      state,
    ).firstWhere((value) => value.key == 'routine:quick-check');
    final existing = state.preferences[item.key];
    setState(() => _busy = true);
    try {
      await _service.setPreference(
        vehicleId: widget.vehicle.id,
        key: item.key,
        enabled: existing?.enabled ?? true,
        leadDays: existing?.leadDays ?? item.defaultLeadDays,
        frequencyMonths: months,
        preferredMonth: existing?.preferredMonth,
        lastCompletedAt: existing?.lastCompletedAt,
        lastCompletedMileage: existing?.lastCompletedMileage,
      );
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markDone(_MaintenanceItem item) async {
    if (_busy) return;
    if (item.group != null) {
      widget.onComplete(item.group!);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${item.title} effectué ?'),
        content: Text(
          'AutoClair enregistrera cette opération aujourd’hui'
          '${widget.vehicle.mileage == null ? '' : ' à ${_km(widget.vehicle.mileage!)} km'} '
          'et recalculera son prochain rappel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final state = _state;
    if (state == null) return;
    final preference = state.preferences[item.key];
    setState(() => _busy = true);
    try {
      await _service.markManualDone(
        vehicleId: widget.vehicle.id,
        key: item.key,
        title: item.title,
        eventType: item.eventType,
        enabled: preference?.enabled ?? true,
        leadDays: preference?.leadDays ?? item.defaultLeadDays,
        frequencyMonths: preference?.frequencyMonths ?? item.frequencyMonths,
        preferredMonth: preference?.preferredMonth ?? item.preferredMonth,
        mileage: widget.vehicle.mileage,
      );
      await _load();
      if (mounted) _message('Opération ajoutée à l’historique.');
    } catch (_) {
      if (mounted) _message('Impossible d’enregistrer cette opération.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _synchronizeNotifications(MaintenanceV14State state) async {
    if (!state.masterEnabled) {
      await _notifications.cancelEssentialReminders(widget.vehicle.id);
      return;
    }

    final now = DateTime.now();
    final plans = <VehicleSmartReminderPlan>[];
    for (final item in _items(state)) {
      final preference = state.preferences[item.key];
      final enabled = preference?.enabled ?? true;
      if (!enabled || item.dueDate == null) continue;

      final leadDays = preference?.leadDays ?? item.defaultLeadDays;
      for (final lead in leadDays) {
        final due = DateTime(
          item.dueDate!.year,
          item.dueDate!.month,
          item.dueDate!.day,
          9,
        );
        final reminderAt = due.subtract(Duration(days: lead));
        if (!reminderAt.isAfter(now)) continue;
        plans.add(
          VehicleSmartReminderPlan(
            vehicleId: widget.vehicle.id,
            key: 'v14:${item.key}:$lead',
            title: item.title,
            dueAt: due,
            reminderAt: reminderAt,
          ),
        );
      }
    }

    await _notifications.synchronizeEssentialReminders(
      vehicleId: widget.vehicle.id,
      plans: plans,
      vehicleLabel: widget.vehicle.displayName,
    );
  }

  List<_MaintenanceItem> _items(MaintenanceV14State state) {
    final now = DateTime.now();
    final groups = groupVehicleMaintenanceSchedules(
      widget.schedules,
      currentMileage: widget.vehicle.mileage,
      now: now,
    );
    final items = <_MaintenanceItem>[];
    final keys = <String>{};

    for (final group in groups) {
      final schedule = group.primary;
      final key = maintenanceV14StableKey(schedule);
      if (!keys.add(key)) continue;

      final projected = maintenanceV14ProjectMileageDate(
        currentMileage: widget.vehicle.mileage,
        dueMileage: group.dueMileage,
        annualMileageKm: state.annualMileageKm,
        now: now,
      );
      final due = maintenanceV14FirstDueDate(
        calendarDue: group.dueDate,
        mileageProjectedDue: projected,
      );

      items.add(
        _MaintenanceItem(
          key: key,
          title: group.title,
          badge: maintenanceV14BadgeForSchedule(schedule),
          dueDate: due,
          calendarDueDate: group.dueDate,
          projectedMileageDate: projected,
          dueMileage: group.dueMileage,
          explanation: maintenanceV14WhyText(schedule),
          sourceUrl: schedule.sourceUrl,
          sourceLabel: schedule.sourceLabel,
          defaultLeadDays: maintenanceV14DefaultLeadDays(key),
          eventType: key == 'regulatory:technical-control'
              ? 'INSPECTION'
              : 'MAINTENANCE',
          group: group,
        ),
      );
    }

    if (!keys.contains('regulatory:technical-control')) {
      final technicalControl = _technicalControlFallback(state);
      if (technicalControl != null) {
        items.add(technicalControl);
        keys.add(technicalControl.key);
      }
    }

    if (!keys.contains('routine:quick-check')) {
      final preference = state.preferences['routine:quick-check'];
      final months = preference?.frequencyMonths ?? 2;
      final base = preference?.lastCompletedAt ?? now;
      final due = _addMonths(base, months);
      items.add(
        _MaintenanceItem(
          key: 'routine:quick-check',
          title: 'Check-up rapide',
          badge: 'Repère AutoClair',
          dueDate: due,
          explanation:
              'Pression des pneus, niveaux essentiels et éclairage. AutoClair '
              'regroupe ces contrôles en un seul rappel tous les $months mois '
              'pour rester utile sans multiplier les notifications.',
          note:
              'Bon à savoir : certains garages et centres auto proposent '
              'gratuitement ce type de contrôle ou l’incluent dans une '
              'prestation. Vérifiez les conditions avant de vous déplacer. '
              'Pour la pression des pneus, un contrôle mensuel et avant un '
              'long trajet reste conseillé.',
          defaultLeadDays: const [0],
          frequencyMonths: months,
          eventType: 'INSPECTION',
        ),
      );
      keys.add('routine:quick-check');
    }

    if (!keys.contains('seasonal:climate')) {
      items.add(
        _MaintenanceItem(
          key: 'seasonal:climate',
          title: 'Tester la climatisation',
          badge: 'Repère AutoClair',
          dueDate: maintenanceV14NextSeasonDate(now: now, month: 4, day: 15),
          explanation:
              'Contrôle saisonnier avant les fortes chaleurs. Il s’agit de '
              'vérifier le fonctionnement, pas de programmer une recharge '
              'systématique du circuit.',
          defaultLeadDays: const [14, 0],
          preferredMonth: 4,
          eventType: 'INSPECTION',
        ),
      );
      keys.add('seasonal:climate');
    }

    if (!keys.contains('seasonal:wipers')) {
      items.add(
        _MaintenanceItem(
          key: 'seasonal:wipers',
          title: 'Contrôler les essuie-glaces',
          badge: 'Repère AutoClair',
          dueDate: maintenanceV14NextSeasonDate(now: now, month: 10, day: 1),
          explanation:
              'Contrôle annuel avant la saison la plus humide. Remplacez les '
              'balais s’ils laissent des traces, sautent ou deviennent bruyants.',
          defaultLeadDays: const [14, 0],
          preferredMonth: 10,
          eventType: 'MAINTENANCE',
        ),
      );
      keys.add('seasonal:wipers');
    }

    if (!keys.contains('maintenance:cabin-filter')) {
      final preference = state.preferences['maintenance:cabin-filter'];
      final base = preference?.lastCompletedAt ?? now;
      items.add(
        _MaintenanceItem(
          key: 'maintenance:cabin-filter',
          title: 'Filtre d’habitacle',
          badge: 'Repère AutoClair',
          dueDate: _addMonths(base, 12),
          explanation:
              'Repère annuel lorsqu’aucune échéance constructeur plus précise '
              'n’est disponible. Si le filtre est inclus dans une révision, '
              'AutoClair privilégie la révision plutôt qu’une visite séparée.',
          defaultLeadDays: const [14, 0],
          frequencyMonths: 12,
          eventType: 'MAINTENANCE',
        ),
      );
    }

    items.sort((left, right) {
      final leftDue = left.dueDate;
      final rightDue = right.dueDate;
      if (leftDue == null && rightDue == null) {
        return left.title.compareTo(right.title);
      }
      if (leftDue == null) {
        return 1;
      }
      if (rightDue == null) {
        return -1;
      }
      return leftDue.compareTo(rightDue);
    });
    return items;
  }

  _MaintenanceItem? _technicalControlFallback(MaintenanceV14State state) {
    VehicleTimelineEvent? lastControl;
    for (final event in state.events) {
      final title = event.title.toLowerCase();
      if (event.status.toUpperCase() == 'COMPLETED' &&
          (title.contains('contrôle technique') ||
              title.contains('controle technique'))) {
        lastControl = event;
        break;
      }
    }

    if (lastControl != null) {
      return _MaintenanceItem(
        key: 'regulatory:technical-control',
        title: 'Contrôle technique',
        badge: 'Réglementaire',
        dueDate: _addYears(lastControl.occurredAt, 2),
        explanation:
            'Échéance calculée depuis le dernier contrôle technique enregistré '
            'le ${_date(lastControl.occurredAt)}.',
        defaultLeadDays: const [30, 7, 0],
        eventType: 'INSPECTION',
      );
    }

    final firstRegistration = state.firstRegistrationDate;
    if (firstRegistration == null) return null;
    return _MaintenanceItem(
      key: 'regulatory:technical-control',
      title: 'Contrôle technique',
      badge: 'Réglementaire',
      dueDate: _addYears(firstRegistration, 4),
      explanation:
          'Aucun contrôle précédent n’est enregistré. AutoClair utilise la '
          'première mise en circulation comme point de départ et affiche la '
          'date limite théorique du premier contrôle.',
      defaultLeadDays: const [30, 7, 0],
      eventType: 'INSPECTION',
    );
  }

  bool _itemEnabled(_MaintenanceItem item) =>
      _state?.preferences[item.key]?.enabled ?? true;

  @override
  Widget build(BuildContext context) {
    if (_loading && _state == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_state == null) {
      return _ErrorCard(
        message: _error ?? 'Impossible de charger le carnet.',
        onRetry: _load,
      );
    }

    final state = _state!;
    final items = _items(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Carnet d’entretien',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text('Ce qu’il faut faire, quand le faire et pourquoi.'),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Actualiser le plan',
              onPressed: _busy ? null : widget.onRefreshPlan,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _TabBar(
          selected: _tab,
          onSelected: (value) => setState(() => _tab = value),
        ),
        if (_busy || _loading) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        switch (_tab) {
          _MaintenanceV14Tab.todo => _todo(items, state),
          _MaintenanceV14Tab.history => _history(state),
          _MaintenanceV14Tab.reminders => _reminders(items, state),
        },
      ],
    );
  }

  Widget _todo(List<_MaintenanceItem> items, MaintenanceV14State state) {
    if (items.isEmpty) {
      return _ErrorCard(
        message:
            'Aucune échéance exploitable. Actualisez le plan ou ajoutez votre historique.',
        onRetry: widget.onRefreshPlan,
      );
    }

    final next = items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroDueCard(
          item: next,
          reminderEnabled: state.masterEnabled && _itemEnabled(next),
          onReminderChanged: state.masterEnabled
              ? (value) => unawaited(_setItemEnabled(next, value))
              : null,
          onDone: () => unawaited(_markDone(next)),
          onOpen: () => _openDetails(next),
        ),
        const SizedBox(height: 18),
        Text(
          'À faire et à prévoir',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        for (final item in items.skip(1)) ...[
          _MaintenanceCard(
            item: item,
            reminderEnabled: state.masterEnabled && _itemEnabled(item),
            reminderAvailable: state.masterEnabled,
            onReminderChanged: (value) =>
                unawaited(_setItemEnabled(item, value)),
            onDone: () => unawaited(_markDone(item)),
            onOpen: () => _openDetails(item),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _history(MaintenanceV14State state) {
    final events = state.events
        .where((event) {
          if (event.status.toUpperCase() != 'COMPLETED') return false;
          return const {
            'MAINTENANCE',
            'REPAIR',
            'INSPECTION',
            'REINSPECTION',
            'TYRES',
          }.contains(event.eventType.toUpperCase());
        })
        .toList(growable: false);

    if (events.isEmpty) {
      return const _InfoCard(
        icon: Icons.menu_book_outlined,
        title: 'Aucun entretien enregistré',
        message:
            'Les opérations confirmées, factures analysées et contrôles '
            'techniques apparaîtront ici.',
      );
    }

    return Column(
      children: [
        for (var index = 0; index < events.length; index++)
          _HistoryRow(
            event: events[index],
            first: index == 0,
            last: index == events.length - 1,
          ),
      ],
    );
  }

  Widget _reminders(List<_MaintenanceItem> items, MaintenanceV14State state) {
    final activeCount = items
        .where((item) => state.preferences[item.key]?.enabled ?? true)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MasterReminderCard(
          enabled: state.masterEnabled,
          busy: _busy,
          activeCount: activeCount,
          onChanged: (value) => unawaited(_setMaster(value)),
        ),
        const SizedBox(height: 12),
        for (final item in items) ...[
          _ReminderRow(
            item: item,
            enabled: _itemEnabled(item),
            masterEnabled: state.masterEnabled,
            busy: _busy,
            frequencyMonths:
                state.preferences[item.key]?.frequencyMonths ??
                item.frequencyMonths,
            onChanged: (value) => unawaited(_setItemEnabled(item, value)),
            onQuickCheckFrequency: item.key == 'routine:quick-check'
                ? (value) => unawaited(_setQuickCheckFrequency(value))
                : null,
            onOpen: () => _openDetails(item),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        const _InfoCard(
          icon: Icons.info_outline_rounded,
          title: 'Rappels intelligents',
          message:
              'Le bouton général coupe toutes les notifications d’entretien '
              'sans effacer vos choix individuels. Les rappels d’événements '
              'créés manuellement restent indépendants.',
        ),
      ],
    );
  }

  void _openDetails(_MaintenanceItem item) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.title,
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Badge(label: item.badge),
                if (item.dueDate != null)
                  _Badge(label: _dueLabel(item, compact: true)),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Pourquoi cette date ?',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(item.explanation),
            if (item.note != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(
                    sheetContext,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(item.note!),
              ),
            ],
            if (item.sourceUrl != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  widget.onOpenSource(item.sourceUrl!);
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(item.sourceLabel ?? 'Voir la source'),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                unawaited(_markDone(item));
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Marquer comme fait'),
            ),
          ],
        ),
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MaintenanceItem {
  const _MaintenanceItem({
    required this.key,
    required this.title,
    required this.badge,
    required this.explanation,
    required this.defaultLeadDays,
    required this.eventType,
    this.dueDate,
    this.calendarDueDate,
    this.projectedMileageDate,
    this.dueMileage,
    this.note,
    this.sourceUrl,
    this.sourceLabel,
    this.frequencyMonths,
    this.preferredMonth,
    this.group,
  });

  final String key;
  final String title;
  final String badge;
  final DateTime? dueDate;
  final DateTime? calendarDueDate;
  final DateTime? projectedMileageDate;
  final int? dueMileage;
  final String explanation;
  final String? note;
  final String? sourceUrl;
  final String? sourceLabel;
  final List<int> defaultLeadDays;
  final int? frequencyMonths;
  final int? preferredMonth;
  final String eventType;
  final VehicleMaintenanceGroup? group;
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelected});

  final _MaintenanceV14Tab selected;
  final ValueChanged<_MaintenanceV14Tab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'À faire',
            selected: selected == _MaintenanceV14Tab.todo,
            onTap: () => onSelected(_MaintenanceV14Tab.todo),
          ),
          _TabButton(
            label: 'Historique',
            selected: selected == _MaintenanceV14Tab.history,
            onTap: () => onSelected(_MaintenanceV14Tab.history),
          ),
          _TabButton(
            label: 'Rappels',
            selected: selected == _MaintenanceV14Tab.reminders,
            onTap: () => onSelected(_MaintenanceV14Tab.reminders),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.surface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      blurRadius: 8,
                      offset: Offset(0, 2),
                      color: Color(0x12000000),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroDueCard extends StatelessWidget {
  const _HeroDueCard({
    required this.item,
    required this.reminderEnabled,
    required this.onReminderChanged,
    required this.onDone,
    required this.onOpen,
  });

  final _MaintenanceItem item;
  final bool reminderEnabled;
  final ValueChanged<bool>? onReminderChanged;
  final VoidCallback onDone;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Prochaine échéance',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ItemIcon(keyName: item.key, large: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: reminderEnabled,
                    onChanged: onReminderChanged,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _dueLabel(item),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              _Badge(label: item.badge),
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: onDone,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Marquer comme fait'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({
    required this.item,
    required this.reminderEnabled,
    required this.reminderAvailable,
    required this.onReminderChanged,
    required this.onDone,
    required this.onOpen,
  });

  final _MaintenanceItem item;
  final bool reminderEnabled;
  final bool reminderAvailable;
  final ValueChanged<bool> onReminderChanged;
  final VoidCallback onDone;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ItemIcon(keyName: item.key),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dueLabel(item),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    _Badge(label: item.badge),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: onDone,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Marquer comme fait'),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: reminderEnabled,
                onChanged: reminderAvailable ? onReminderChanged : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MasterReminderCard extends StatelessWidget {
  const _MasterReminderCard({
    required this.enabled,
    required this.busy,
    required this.activeCount,
    required this.onChanged,
  });

  final bool enabled;
  final bool busy;
  final int activeCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tous les rappels d’entretien',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text('$activeCount opération(s) configurée(s)'),
              ],
            ),
          ),
          Switch.adaptive(
            key: const ValueKey('maintenance-v14-master-switch'),
            value: enabled,
            onChanged: busy ? null : onChanged,
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.item,
    required this.enabled,
    required this.masterEnabled,
    required this.busy,
    required this.frequencyMonths,
    required this.onChanged,
    required this.onQuickCheckFrequency,
    required this.onOpen,
  });

  final _MaintenanceItem item;
  final bool enabled;
  final bool masterEnabled;
  final bool busy;
  final int? frequencyMonths;
  final ValueChanged<bool> onChanged;
  final ValueChanged<int>? onQuickCheckFrequency;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          _ItemIcon(keyName: item.key),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.key == 'routine:quick-check'
                        ? 'Tous les ${frequencyMonths ?? 2} mois'
                        : _dueLabel(item, compact: true),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (onQuickCheckFrequency != null) ...[
                    const SizedBox(height: 4),
                    PopupMenuButton<int>(
                      tooltip: 'Changer la fréquence',
                      onSelected: onQuickCheckFrequency,
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 1, child: Text('Tous les mois')),
                        PopupMenuItem(value: 2, child: Text('Tous les 2 mois')),
                        PopupMenuItem(value: 3, child: Text('Tous les 3 mois')),
                      ],
                      child: const Text(
                        'Modifier la fréquence',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Switch.adaptive(
            key: ValueKey('maintenance-v14-switch-${item.key}'),
            value: enabled,
            onChanged: masterEnabled && !busy ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.event,
    required this.first,
    required this.last,
  });

  final VehicleTimelineEvent event;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      _date(event.occurredAt),
      if (event.mileage != null) '${_km(event.mileage!)} km',
      if (event.amount != null) '${event.amount!.toStringAsFixed(0)} €',
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              if (!first)
                Container(
                  width: 2,
                  height: 10,
                  color: Theme.of(context).dividerColor,
                )
              else
                const SizedBox(height: 10),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              if (!last)
                Container(
                  width: 2,
                  height: 72,
                  color: Theme.of(context).dividerColor,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(details.join(' · ')),
                  if (event.providerName != null) ...[
                    const SizedBox(height: 3),
                    Text(event.providerName!),
                  ],
                  if (event.sourceDocumentId != null) ...[
                    const SizedBox(height: 5),
                    const Row(
                      children: [
                        Icon(Icons.description_outlined, size: 16),
                        SizedBox(width: 5),
                        Text('Justificatif lié'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ItemIcon extends StatelessWidget {
  const _ItemIcon({required this.keyName, this.large = false});

  final String keyName;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final icon = switch (keyName) {
      'regulatory:technical-control' => Icons.fact_check_outlined,
      'routine:quick-check' => Icons.checklist_rounded,
      'seasonal:climate' => Icons.ac_unit_rounded,
      'seasonal:wipers' => Icons.water_drop_outlined,
      'maintenance:brake-fluid' => Icons.science_outlined,
      'maintenance:cabin-filter' => Icons.air_rounded,
      'maintenance:timing-belt' => Icons.settings_outlined,
      _ => Icons.build_outlined,
    };
    final size = large ? 50.0 : 42.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoCard(
          icon: Icons.info_outline_rounded,
          title: 'Carnet indisponible',
          message: message,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Réessayer'),
        ),
      ],
    );
  }
}

String _dueLabel(_MaintenanceItem item, {bool compact = false}) {
  final date = item.dueDate;
  final dueMileage = item.dueMileage;

  if (date != null && dueMileage != null) {
    final projectedFirst =
        item.projectedMileageDate != null &&
        (item.calendarDueDate == null ||
            item.projectedMileageDate!.isBefore(item.calendarDueDate!));
    if (projectedFirst) {
      return compact
          ? '${_km(dueMileage)} km · vers ${_monthYear(date)}'
          : 'À ${_km(dueMileage)} km · vers ${_monthYear(date)}';
    }
    return compact
        ? '${_date(date)} ou ${_km(dueMileage)} km'
        : '${_date(date)} ou ${_km(dueMileage)} km · première limite atteinte';
  }
  if (date != null) return compact ? _date(date) : _relativeDate(date);
  if (dueMileage != null) return 'À ${_km(dueMileage)} km';
  return 'Date à préciser';
}

String _relativeDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(date.year, date.month, date.day);
  final days = due.difference(today).inDays;
  if (days < 0) return 'À rattraper · ${_date(date)}';
  if (days == 0) return 'Aujourd’hui';
  if (days <= 31) return 'Dans $days jour(s) · ${_date(date)}';
  if (days <= 92) {
    final months = (days / 30).round();
    return 'Dans environ $months mois · ${_date(date)}';
  }
  return _date(date);
}

String _date(DateTime value) {
  const months = <String>[
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String _monthYear(DateTime value) {
  const months = <String>[
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${months[value.month - 1]} ${value.year}';
}

String _km(int value) {
  final digits = value.abs().toString();
  final chunks = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    chunks.insert(0, digits.substring(start, end));
  }
  final formatted = chunks.join('\u202F');
  return value < 0 ? '-$formatted' : formatted;
}

DateTime _addMonths(DateTime date, int months) {
  final zeroBased = date.month - 1 + months;
  final year = date.year + zeroBased ~/ 12;
  final month = zeroBased % 12 + 1;
  final maxDay = DateTime(year, month + 1, 0).day;
  final day = date.day > maxDay ? maxDay : date.day;
  return DateTime(year, month, day, 9);
}

DateTime _addYears(DateTime date, int years) {
  final year = date.year + years;
  final maxDay = DateTime(year, date.month + 1, 0).day;
  final day = date.day > maxDay ? maxDay : date.day;
  return DateTime(year, date.month, day, 9);
}
