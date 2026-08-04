import 'package:autoclair_app/features/documents/document_carnet_sync_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identifies an automatically created event', () {
    final result = DocumentCarnetSyncResult.fromMap({
      'status': 'AUTO_CREATED',
      'message': 'Événement ajouté.',
      'vehicle_id': 'vehicle-1',
      'event_id': 'event-1',
      'event_title': 'Vidange moteur',
      'match_method': 'VIN_EXACT',
      'match_score': 1,
      'user_confirmation_required': false,
      'user_confirmed': false,
      'suggestion_count': 0,
    });

    expect(result.wasAutomaticallyAdded, isTrue);
    expect(result.userConfirmed, isFalse);
    expect(result.needsReview, isFalse);
    expect(result.canOpenCarnet, isTrue);
    expect(result.matchLabel, 'VIN identique');
  });

  test('keeps an ambiguous document in review', () {
    final result = DocumentCarnetSyncResult.fromMap({
      'status': 'REVIEW_REQUIRED',
      'message': 'Le véhicule doit être confirmé.',
      'vehicle_id': 'vehicle-1',
      'match_method': 'SELECTED_VEHICLE_ONLY',
      'match_score': 0.8,
      'user_confirmation_required': true,
      'user_confirmed': false,
      'suggestion_count': 2,
    });

    expect(result.wasAutomaticallyAdded, isFalse);
    expect(result.needsReview, isTrue);
    expect(result.suggestionCount, 2);
    expect(result.matchLabel, 'Véhicule sélectionné uniquement');
  });

  test('recognises non applicable documents', () {
    final result = DocumentCarnetSyncResult.fromMap({
      'status': 'NOT_APPLICABLE',
      'message': 'Un devis doit être confirmé.',
      'user_confirmation_required': true,
      'user_confirmed': false,
      'suggestion_count': 0,
    });

    expect(result.isNotApplicable, isTrue);
    expect(result.wasAutomaticallyAdded, isFalse);
  });

  test('identifies a user-confirmed automatic event', () {
    final result = DocumentCarnetSyncResult.fromMap({
      'status': 'ALREADY_CREATED',
      'message': 'Événement confirmé.',
      'vehicle_id': 'vehicle-1',
      'event_id': 'event-1',
      'event_title': 'Vidange moteur',
      'match_method': 'VIN_EXACT',
      'match_score': 1,
      'user_confirmation_required': false,
      'user_confirmed': true,
      'suggestion_count': 0,
    });

    expect(result.wasAutomaticallyAdded, isTrue);
    expect(result.userConfirmed, isTrue);
  });
}
