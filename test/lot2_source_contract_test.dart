import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('lot 2 keeps the vehicle page simple', () {
    final source = _read('lib/features/vehicle_care/vehicle_care_page.dart');

    expect(source, contains('VehicleCarePrimaryActions'));
    expect(source, contains('Lancer le Bilan AutoClair 360'));
    expect(source, contains('promo en cours pour'));
    expect(source, isNot(contains('Préparation vente')));
    expect(source, isNot(contains('_Vehicle360EntryCard')));
    expect(source, isNot(contains('_CommercialOffersEntryCard')));
  });

  test('lot 2 exposes a general promotions route without score display', () {
    final router = _read('lib/core/router/app_router.dart');
    final offers = _read(
      'lib/features/commercial_offers/commercial_offers_page.dart',
    );

    expect(router, contains("path: '/offers'"));
    expect(offers, contains('CommercialOfferVehicleSelector'));
    expect(offers, isNot(contains('relevanceScore')));
  });

  test('event form exposes only completed and planned statuses', () {
    final source = _read(
      'lib/features/vehicle_care/vehicle_event_form_page.dart',
    );

    expect(source, contains("label: const Text('Réalisé')"));
    expect(source, contains("label: const Text('Prévu')"));
    expect(source, isNot(contains('Conseillé')));
    expect(source, isNot(contains('DropdownButtonFormField')));
  });

  test('document result excludes accounting and customer identity UI', () {
    final page = _read('lib/features/documents/analysis_result_page.dart');
    final model = _read('lib/features/documents/document_analysis_result.dart');

    expect(model, contains("String get heading => 'Opération détectée';"));
    expect(page, contains('Kilométrage (facultatif)'));
    expect(page, contains('Prix (facultatif)'));
    expect(page, isNot(contains("MapEntry('TVA'")));
    expect(page, isNot(contains("MapEntry('Total TTC'")));
    expect(model, contains('_sanitizeMap'));
    expect(model, contains('client_name'));
    expect(model, contains('owner_name'));
  });

  test('event form supports documents, reminders and nearby garages', () {
    final form = _read(
      'lib/features/vehicle_care/vehicle_event_form_page.dart',
    );
    final service = _read(
      'lib/features/vehicle_care/vehicle_care_service.dart',
    );

    expect(form, contains('Joindre un nouveau document'));
    expect(form, contains('Lier un document existant'));
    expect(form, contains('Me le rappeler'));
    expect(form, contains('Rechercher autour de moi'));
    expect(service, contains("'p_source_document_id'"));
    expect(service, contains("'p_location_text'"));
    expect(service, contains("'reminder_days_before'"));
  });
}
