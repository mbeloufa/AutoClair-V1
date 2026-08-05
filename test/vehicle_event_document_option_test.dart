import 'package:autoclair_app/features/vehicle_care/vehicle_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event document option exposes a readable label', () {
    final document = VehicleEventDocumentOption.fromMap({
      'id': 'document-1',
      'document_type': 'invoice',
      'status': 'completed',
      'created_at': '2026-08-05T08:00:00Z',
      'vehicle_id': 'vehicle-1',
      'comment': 'Révision annuelle',
    });

    expect(document.typeLabel, 'Facture');
    expect(document.statusLabel, 'Analysé');
    expect(document.displayLabel, 'Facture · Révision annuelle');
  });
}
