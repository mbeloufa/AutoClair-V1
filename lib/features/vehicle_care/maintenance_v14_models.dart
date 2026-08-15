import 'vehicle_care_models.dart';

String maintenanceV14StableKey(VehicleMaintenanceSchedule schedule) {
  final sourceKey = (schedule.sourceKey ?? '').toUpperCase();
  final title = schedule.title.toLowerCase();

  if (sourceKey.contains('TECHNICAL') ||
      sourceKey.contains('CONTROL') ||
      title.contains('contrôle technique')) {
    return 'regulatory:technical-control';
  }
  if (sourceKey.contains('BRAKE_FLUID') ||
      sourceKey.contains('BRAKE-FLUID') ||
      title.contains('liquide de frein')) {
    return 'maintenance:brake-fluid';
  }
  if (sourceKey.contains('CABIN_FILTER') ||
      sourceKey.contains('CABIN-FILTER') ||
      title.contains('filtre habitacle')) {
    return 'maintenance:cabin-filter';
  }
  if (sourceKey.contains('TIMING_BELT') ||
      sourceKey.contains('TIMING-BELT') ||
      title.contains('distribution')) {
    return 'maintenance:timing-belt';
  }
  if (sourceKey.contains('SPARK_PLUG') ||
      sourceKey.contains('SPARK-PLUG') ||
      title.contains('bougie')) {
    return 'maintenance:spark-plugs';
  }
  if (sourceKey.contains('TRANSMISSION_OIL') ||
      sourceKey.contains('TRANSMISSION-OIL') ||
      title.contains('huile de boîte') ||
      title.contains('huile boite')) {
    return 'maintenance:transmission-oil';
  }
  if (sourceKey.contains('COOLANT') ||
      title.contains('liquide de refroidissement')) {
    return 'maintenance:coolant';
  }
  if (sourceKey.contains('SEASONAL:CLIMATE') ||
      title.contains('climatisation')) {
    return 'seasonal:climate';
  }
  if (sourceKey.contains('SERVICE') ||
      sourceKey.contains('ENGINE_OIL') ||
      sourceKey.contains('OIL_FILTER') ||
      title.contains('révision') ||
      title.contains('vidange')) {
    return 'maintenance:service';
  }

  final normalized = title
      .replaceAll(RegExp(r'[^a-z0-9àâäçéèêëîïôöùûüÿ]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return normalized.isEmpty
      ? 'maintenance:${schedule.id}'
      : 'maintenance:$normalized';
}

String maintenanceV14BadgeForSchedule(VehicleMaintenanceSchedule schedule) {
  if (maintenanceV14StableKey(schedule) == 'regulatory:technical-control') {
    return 'Réglementaire';
  }
  if (schedule.isManufacturerPlan && schedule.isHistoryConfirmed) {
    return 'Constructeur + historique';
  }
  if (schedule.isManufacturerPlan) return 'Constructeur';
  return 'Repère AutoClair';
}

List<int> maintenanceV14DefaultLeadDays(String key) {
  if (key == 'regulatory:technical-control' || key == 'maintenance:service') {
    return const [30, 7, 0];
  }
  if (key == 'maintenance:timing-belt') {
    return const [60, 30, 0];
  }
  if (key == 'maintenance:brake-fluid') {
    return const [30, 7, 0];
  }
  if (key == 'routine:quick-check') return const [0];
  if (key == 'seasonal:climate' || key == 'seasonal:wipers') {
    return const [14, 0];
  }
  return const [14, 0];
}

DateTime maintenanceV14NextSeasonDate({
  required DateTime now,
  required int month,
  required int day,
}) {
  var candidate = DateTime(now.year, month, day, 9);
  final today = DateTime(now.year, now.month, now.day);
  if (!candidate.isAfter(today)) {
    candidate = DateTime(now.year + 1, month, day, 9);
  }
  return candidate;
}

DateTime? maintenanceV14ProjectMileageDate({
  required int? currentMileage,
  required int? dueMileage,
  required int annualMileageKm,
  required DateTime now,
}) {
  if (currentMileage == null ||
      dueMileage == null ||
      annualMileageKm <= 0 ||
      dueMileage <= currentMileage) {
    return null;
  }
  final remaining = dueMileage - currentMileage;
  final days = (remaining * 365 / annualMileageKm).ceil();
  return DateTime(now.year, now.month, now.day).add(Duration(days: days));
}

DateTime? maintenanceV14FirstDueDate({
  required DateTime? calendarDue,
  required DateTime? mileageProjectedDue,
}) {
  if (calendarDue == null) return mileageProjectedDue;
  if (mileageProjectedDue == null) return calendarDue;
  return calendarDue.isBefore(mileageProjectedDue)
      ? calendarDue
      : mileageProjectedDue;
}

String maintenanceV14WhyText(VehicleMaintenanceSchedule schedule) {
  if (maintenanceV14StableKey(schedule) == 'regulatory:technical-control') {
    return 'Échéance réglementaire calculée à partir des informations connues '
        'sur le véhicule et son historique de contrôle technique.';
  }
  if (schedule.isManufacturerPlan && schedule.isHistoryConfirmed) {
    return 'L’intervalle constructeur est recalé sur une intervention '
        'confirmée dans l’historique du véhicule.';
  }
  if (schedule.isManufacturerPlan) {
    return 'L’échéance reprend l’intervalle constructeur disponible pour ce '
        'véhicule. Ajoutez vos factures pour la recaler sur l’historique réel.';
  }
  final benefit = schedule.benefitText.trim();
  return benefit.isEmpty
      ? 'Repère pratique AutoClair, distinct d’une préconisation constructeur.'
      : benefit;
}
