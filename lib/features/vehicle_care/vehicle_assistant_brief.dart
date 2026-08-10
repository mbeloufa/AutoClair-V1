import '../vehicles/vehicle.dart';
import 'vehicle_care_models.dart';
import 'vehicle_maintenance_presentation.dart';

enum VehicleAssistantTarget { overview, alerts, maintenance, offers, mileage }

enum VehicleAssistantImportance { urgent, attention, useful, upToDate }

class VehicleAssistantItem {
  const VehicleAssistantItem({
    required this.title,
    required this.message,
    required this.importance,
    this.actionLabel,
    this.target,
  });

  final String title;
  final String message;
  final VehicleAssistantImportance importance;
  final String? actionLabel;
  final VehicleAssistantTarget? target;
}

class VehicleAssistantBrief {
  const VehicleAssistantBrief({required this.summary, required this.items});

  final String summary;
  final List<VehicleAssistantItem> items;

  bool get isUpToDate =>
      items.length == 1 &&
      items.single.importance == VehicleAssistantImportance.upToDate;

  static VehicleAssistantBrief build({
    required Vehicle vehicle,
    required VehicleCareBundle bundle,
    int offerCount = 0,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final candidates = <_AssistantCandidate>[];
    final seenTitles = <String>{};

    void add({
      required int rank,
      required VehicleAssistantItem item,
      String? dedupeTitle,
    }) {
      final key = _normalizedTitle(dedupeTitle ?? item.title);
      if (key.isNotEmpty && !seenTitles.add(key)) return;
      candidates.add(_AssistantCandidate(rank: rank, item: item));
    }

    final scheduledRecalls = bundle.dashboard.recalls.where(
      (recall) => recall.status.toUpperCase() == 'SCHEDULED',
    );

    for (final recall in scheduledRecalls) {
      add(
        rank: 0,
        dedupeTitle: recall.title,
        item: VehicleAssistantItem(
          title: 'Rappel constructeur programmé',
          message: recall.title,
          importance: VehicleAssistantImportance.urgent,
          actionLabel: 'Voir l’intervention',
          target: VehicleAssistantTarget.alerts,
        ),
      );
    }

    for (final risk in bundle.dashboard.risks.where(
      (item) => item.status.toUpperCase() == 'ACTIVE',
    )) {
      final high = const {
        'HIGH',
        'CRITICAL',
      }.contains(risk.severity.toUpperCase());
      add(
        rank: high ? 1 : 5,
        dedupeTitle: risk.title,
        item: VehicleAssistantItem(
          title: high ? 'Point de vigilance important' : 'Point à surveiller',
          message: risk.recommendedAction.trim().isNotEmpty
              ? '${risk.title} · ${risk.recommendedAction}'
              : risk.title,
          importance: high
              ? VehicleAssistantImportance.urgent
              : VehicleAssistantImportance.attention,
          actionLabel: 'Voir l’alerte',
          target: VehicleAssistantTarget.alerts,
        ),
      );
    }

    final maintenanceGroups = groupVehicleMaintenanceSchedules(
      bundle.schedules,
      currentMileage: vehicle.mileage,
      now: reference,
    );

    for (final group in maintenanceGroups) {
      if (group.isOverdue(currentMileage: vehicle.mileage, now: reference)) {
        add(
          rank: 2,
          dedupeTitle: group.title,
          item: VehicleAssistantItem(
            title: 'Entretien à rattraper',
            message: _scheduleMessage(group),
            importance: VehicleAssistantImportance.urgent,
            actionLabel: 'Voir l’entretien',
            target: VehicleAssistantTarget.maintenance,
          ),
        );
      } else if (group.isDueSoon(
        currentMileage: vehicle.mileage,
        now: reference,
      )) {
        add(
          rank: 4,
          dedupeTitle: group.title,
          item: VehicleAssistantItem(
            title: 'Entretien bientôt à prévoir',
            message: _scheduleMessage(group),
            importance: VehicleAssistantImportance.attention,
            actionLabel: 'Voir l’échéance',
            target: VehicleAssistantTarget.maintenance,
          ),
        );
      }
    }

    for (final reminder in bundle.dashboard.upcomingActions.where(
      (item) => item.sourceType.toUpperCase() != 'RECALL',
    )) {
      final high = reminder.priority.toUpperCase() == 'HIGH';
      final displayTitle = vehicleMaintenanceDisplayTitle(reminder.title);
      final maintenanceLike = displayTitle != reminder.title.trim();
      add(
        rank: high ? 3 : 6,
        dedupeTitle: displayTitle,
        item: VehicleAssistantItem(
          title: high ? 'Échéance prioritaire' : 'À prévoir',
          message: maintenanceLike
              ? _reminderDueMessage(displayTitle, reminder)
              : reminder.message.trim().isNotEmpty
              ? '$displayTitle · ${reminder.message}'
              : _reminderDueMessage(displayTitle, reminder),
          importance: high
              ? VehicleAssistantImportance.urgent
              : VehicleAssistantImportance.attention,
          actionLabel: 'Voir l’échéance',
          target: VehicleAssistantTarget.overview,
        ),
      );
    }

    if (vehicle.mileage == null) {
      add(
        rank: 7,
        item: const VehicleAssistantItem(
          title: 'Kilométrage à renseigner',
          message:
              'Ajoutez le kilométrage actuel pour améliorer les prochaines échéances.',
          importance: VehicleAssistantImportance.useful,
          actionLabel: 'Ajouter les km',
          target: VehicleAssistantTarget.mileage,
        ),
      );
    }

    if (offerCount > 0) {
      add(
        rank: 8,
        item: VehicleAssistantItem(
          title: 'Une économie est peut-être disponible',
          message: offerCount == 1
              ? '1 offre en cours correspond à ce véhicule.'
              : '$offerCount offres en cours correspondent à ce véhicule.',
          importance: VehicleAssistantImportance.useful,
          actionLabel: 'Voir les offres',
          target: VehicleAssistantTarget.offers,
        ),
      );
    }

    candidates.sort((left, right) => left.rank.compareTo(right.rank));
    final items = candidates
        .take(3)
        .map((candidate) => candidate.item)
        .toList(growable: false);

    if (items.isEmpty) {
      return const VehicleAssistantBrief(
        summary:
            'Aucun point prioritaire détecté avec les informations disponibles.',
        items: [
          VehicleAssistantItem(
            title: 'Suivi à jour',
            message:
                'Continuez à ajouter les entretiens, documents et kilométrages au fil du temps.',
            importance: VehicleAssistantImportance.upToDate,
          ),
        ],
      );
    }

    final urgentCount = items
        .where((item) => item.importance == VehicleAssistantImportance.urgent)
        .length;

    return VehicleAssistantBrief(
      summary: urgentCount > 0
          ? 'AutoClair a classé les actions à regarder en premier.'
          : 'Voici les prochains éléments utiles pour ce véhicule.',
      items: List.unmodifiable(items),
    );
  }
}

class _AssistantCandidate {
  const _AssistantCandidate({required this.rank, required this.item});

  final int rank;
  final VehicleAssistantItem item;
}

String _scheduleMessage(VehicleMaintenanceGroup group) {
  final details = <String>[group.title];

  final dueDate = group.dueDate;
  if (dueDate != null) {
    details.add(
      'prévu le ${_two(dueDate.day)}/${_two(dueDate.month)}/${dueDate.year}',
    );
  }

  final dueMileage = group.dueMileage;
  if (dueMileage != null) {
    details.add('à ${_integer(dueMileage)} km');
  }

  return details.join(' · ');
}

String _reminderDueMessage(String title, VehicleReminder reminder) {
  final details = <String>[title];
  final dueAt = reminder.dueAt;
  if (dueAt != null) {
    details.add('le ${_two(dueAt.day)}/${_two(dueAt.month)}/${dueAt.year}');
  }
  final dueMileage = reminder.dueMileage;
  if (dueMileage != null) {
    details.add('à ${_integer(dueMileage)} km');
  }
  return details.join(' · ');
}

String _normalizedTitle(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9àâäçéèêëîïôöùûüÿ]+'), ' ')
    .trim();

String _two(int value) => value.toString().padLeft(2, '0');

String _integer(int value) {
  final digits = value.abs().toString();
  final chunks = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    chunks.insert(0, digits.substring(start, end));
  }
  final formatted = chunks.join(' ');
  return value < 0 ? '-$formatted' : formatted;
}
