import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('V1 sale preparation can generate a factual listing draft locally', () {
    final page = _read(
      'lib/features/sale_preparation/sale_preparation_page.dart',
    );
    final builder = _read(
      'lib/features/sale_preparation/sale_listing_draft.dart',
    );
    final card = _read(
      'lib/features/sale_preparation/sale_listing_draft_card.dart',
    );

    expect(page, contains('SaleListingDraftBuilder.build'));
    expect(page, contains('SaleListingDraftCard'));
    expect(page, contains('_showListingDraft'));
    expect(builder, contains('class SaleListingDraftBuilder'));
    expect(builder, contains('informationToComplete'));
    expect(builder, isNot(contains('registrationNumber')));
    expect(builder, isNot(contains('.vin')));
    expect(builder, isNot(contains('supabase')));
    expect(builder, isNot(contains('http')));
    expect(card, contains('Aucun de ces éléments n’est inventé'));
  });
}
