class QuoteLine {
  const QuoteLine({
    required this.description,
    required this.normalizedCategory,
    required this.amount,
    this.quantity,
    this.unitPrice,
  });

  final String description;
  final String normalizedCategory;
  final double amount;
  final double? quantity;
  final double? unitPrice;

  factory QuoteLine.fromMap(Map<String, dynamic> map) {
    final description =
        _text(map['description'] ?? map['label'] ?? map['name']) ??
        'Ligne non précisée';
    final quantity = _decimalOrNull(map['quantity'] ?? map['qty']);
    final unitPrice = _decimalOrNull(
      map['unit_price'] ?? map['price_unit'] ?? map['unit_amount'],
    );
    final explicitTotal = _decimalOrNull(
      map['line_total'] ??
          map['total'] ??
          map['amount'] ??
          map['total_including_tax'],
    );
    final amount =
        explicitTotal ??
        (quantity != null && unitPrice != null ? quantity * unitPrice : 0);

    return QuoteLine(
      description: description,
      normalizedCategory: QuoteNormalizer.categoryFor(description),
      amount: amount,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }
}

class QuoteSnapshot {
  const QuoteSnapshot({
    required this.documentId,
    required this.label,
    required this.providerName,
    required this.documentDate,
    required this.total,
    required this.lines,
    required this.confidence,
  });

  final String documentId;
  final String label;
  final String providerName;
  final DateTime? documentDate;
  final double total;
  final List<QuoteLine> lines;
  final double confidence;

  Map<String, double> get totalsByCategory {
    final result = <String, double>{};
    for (final line in lines) {
      result.update(
        line.normalizedCategory,
        (current) => current + line.amount,
        ifAbsent: () => line.amount,
      );
    }
    return result;
  }

  factory QuoteSnapshot.fromAnalysis({
    required String documentId,
    required String label,
    required Map<String, dynamic> analysis,
    required double confidence,
  }) {
    final resultJson = analysis['result_json'] is Map
        ? Map<String, dynamic>.from(analysis['result_json'] as Map)
        : analysis;
    final rawLines = resultJson['line_items'];
    final lines = rawLines is List
        ? rawLines
              .whereType<Map>()
              .map((line) => QuoteLine.fromMap(Map<String, dynamic>.from(line)))
              .where((line) => line.amount >= 0)
              .toList(growable: false)
        : const <QuoteLine>[];
    final parties = resultJson['parties'] is Map
        ? Map<String, dynamic>.from(resultJson['parties'] as Map)
        : const <String, dynamic>{};
    final amounts = resultJson['amounts'] is Map
        ? Map<String, dynamic>.from(resultJson['amounts'] as Map)
        : const <String, dynamic>{};
    final dates = resultJson['dates'] is Map
        ? Map<String, dynamic>.from(resultJson['dates'] as Map)
        : const <String, dynamic>{};
    final calculatedTotal = lines.fold<double>(
      0,
      (sum, line) => sum + line.amount,
    );
    final explicitTotal = _decimalOrNull(
      amounts['total_including_tax'] ??
          amounts['total'] ??
          resultJson['amount'],
    );

    return QuoteSnapshot(
      documentId: documentId,
      label: label,
      providerName:
          _text(
            parties['garage_name'] ??
                parties['provider_name'] ??
                resultJson['provider_name'],
          ) ??
          'Professionnel non identifié',
      documentDate: DateTime.tryParse(
        _text(dates['document_date'] ?? resultJson['document_date']) ?? '',
      ),
      total: explicitTotal ?? calculatedTotal,
      lines: lines,
      confidence: confidence,
    );
  }
}

class QuoteComparisonResult {
  const QuoteComparisonResult({required this.quotes, required this.categories});

  final List<QuoteSnapshot> quotes;
  final List<String> categories;

  double? get minimumTotal {
    if (quotes.isEmpty) return null;
    return quotes
        .map((quote) => quote.total)
        .reduce((left, right) => left < right ? left : right);
  }

  double? get maximumTotal {
    if (quotes.isEmpty) return null;
    return quotes
        .map((quote) => quote.total)
        .reduce((left, right) => left > right ? left : right);
  }

  double get totalGap => (maximumTotal ?? 0) - (minimumTotal ?? 0);

  factory QuoteComparisonResult.fromQuotes(List<QuoteSnapshot> quotes) {
    final categories = <String>{};
    for (final quote in quotes) {
      categories.addAll(quote.totalsByCategory.keys);
    }
    final sorted = categories.toList()..sort();
    return QuoteComparisonResult(
      quotes: List.unmodifiable(quotes),
      categories: List.unmodifiable(sorted),
    );
  }
}

abstract final class QuoteNormalizer {
  static String categoryFor(String description) {
    final text = _normalize(description);
    if (_containsAny(text, const ['vidange', 'huile moteur', 'filtre huile'])) {
      return 'Vidange moteur';
    }
    if (_containsAny(text, const ['frein', 'plaquette', 'disque'])) {
      return 'Freinage';
    }
    if (_containsAny(text, const ['distribution', 'courroie', 'chaine'])) {
      return 'Distribution';
    }
    if (_containsAny(text, const ['pneu', 'roue', 'paralleli', 'geometrie'])) {
      return 'Pneumatiques';
    }
    if (_containsAny(text, const ['batterie', 'alternateur', 'demarreur'])) {
      return 'Batterie et électricité';
    }
    if (_containsAny(text, const ['climatisation', 'clim ', 'recharge clim'])) {
      return 'Climatisation';
    }
    if (_containsAny(text, const ['diagnostic', 'valise', 'code defaut'])) {
      return 'Diagnostic';
    }
    if (_containsAny(text, const ['carrosserie', 'peinture', 'pare choc'])) {
      return 'Carrosserie';
    }
    if (_containsAny(text, const ['pare brise', 'vitrage', 'vitre'])) {
      return 'Vitrage';
    }
    if (_containsAny(text, const ['embrayage', 'volant moteur'])) {
      return 'Embrayage';
    }
    if (_containsAny(text, const ['main oeuvre', 'mo ', 'temps atelier'])) {
      return 'Main-d’œuvre';
    }
    return 'Autres opérations';
  }

  static bool _containsAny(String text, List<String> terms) {
    return terms.any(text.contains);
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâä]'), 'a')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }
}

double? _decimalOrNull(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
