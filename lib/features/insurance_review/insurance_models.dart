class InsuranceSnapshot {
  const InsuranceSnapshot({
    required this.id,
    required this.vehicleId,
    required this.providerName,
    required this.annualPremium,
    required this.snapshotDate,
    required this.sourceType,
    required this.guarantees,
    this.deductible,
    this.expiryDate,
    this.assistanceZeroKm,
    this.replacementVehicle,
    this.contractNumberMasked,
    this.documentId,
  });

  final String id;
  final String vehicleId;
  final String providerName;
  final double annualPremium;
  final double? deductible;
  final DateTime snapshotDate;
  final DateTime? expiryDate;
  final bool? assistanceZeroKm;
  final bool? replacementVehicle;
  final String? contractNumberMasked;
  final String? documentId;
  final String sourceType;
  final List<String> guarantees;

  String get displayLabel => '$providerName · ${snapshotDate.year}';

  factory InsuranceSnapshot.fromMap(Map<String, dynamic> map) {
    return InsuranceSnapshot(
      id: map['id']?.toString() ?? '',
      vehicleId: map['vehicle_id']?.toString() ?? '',
      providerName: _text(map['provider_name']) ?? 'Assureur non précisé',
      annualPremium: _decimal(map['annual_premium']),
      deductible: _decimalOrNull(map['deductible_amount']),
      snapshotDate:
          DateTime.tryParse(map['snapshot_date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      expiryDate: DateTime.tryParse(map['expiry_date']?.toString() ?? ''),
      assistanceZeroKm: map['assistance_zero_km'] as bool?,
      replacementVehicle: map['replacement_vehicle'] as bool?,
      contractNumberMasked: _text(map['contract_number_masked']),
      documentId: _text(map['document_id']),
      sourceType: map['source_type']?.toString() ?? 'MANUAL',
      guarantees: _strings(map['guarantees']),
    );
  }

  factory InsuranceSnapshot.fromAnalysis({
    required String documentId,
    required String vehicleId,
    required DateTime createdAt,
    required Map<String, dynamic> analysis,
  }) {
    final result = analysis['result_json'] is Map
        ? Map<String, dynamic>.from(analysis['result_json'] as Map)
        : analysis;
    final parties = result['parties'] is Map
        ? Map<String, dynamic>.from(result['parties'] as Map)
        : const <String, dynamic>{};
    final amounts = result['amounts'] is Map
        ? Map<String, dynamic>.from(result['amounts'] as Map)
        : const <String, dynamic>{};
    final insurance = result['insurance'] is Map
        ? Map<String, dynamic>.from(result['insurance'] as Map)
        : result;
    final dates = result['dates'] is Map
        ? Map<String, dynamic>.from(result['dates'] as Map)
        : const <String, dynamic>{};

    return InsuranceSnapshot(
      id: 'document-$documentId',
      vehicleId: vehicleId,
      providerName:
          _text(
            insurance['provider_name'] ??
                insurance['company'] ??
                parties['provider_name'] ??
                parties['insurer_name'],
          ) ??
          'Assureur extrait du document',
      annualPremium: _decimal(
        insurance['annual_premium'] ??
            insurance['premium_annual'] ??
            amounts['annual_total'] ??
            amounts['total_including_tax'] ??
            amounts['total'],
      ),
      deductible: _decimalOrNull(
        insurance['deductible'] ?? insurance['deductible_amount'],
      ),
      snapshotDate:
          DateTime.tryParse(
            _text(dates['document_date'] ?? result['document_date']) ?? '',
          ) ??
          createdAt,
      expiryDate: DateTime.tryParse(
        _text(
              insurance['expiry_date'] ??
                  insurance['renewal_date'] ??
                  dates['expiry_date'],
            ) ??
            '',
      ),
      assistanceZeroKm: _boolOrNull(
        insurance['assistance_zero_km'] ?? insurance['zero_km_assistance'],
      ),
      replacementVehicle: _boolOrNull(
        insurance['replacement_vehicle'] ?? insurance['courtesy_car'],
      ),
      contractNumberMasked: maskContractNumber(
        _text(insurance['contract_number'] ?? result['contract_number']),
      ),
      documentId: documentId,
      sourceType: 'DOCUMENT_ANALYSIS',
      guarantees: _strings(
        insurance['guarantees'] ??
            insurance['coverages'] ??
            result['guarantees'],
      ),
    );
  }

  static String? maskContractNumber(String? value) {
    final clean = value?.replaceAll(RegExp(r'\s+'), '').trim();
    if (clean == null || clean.isEmpty) return null;
    if (clean.length <= 4) return '••••';
    return '${List<String>.filled(clean.length - 4, '•').join()}${clean.substring(clean.length - 4)}';
  }
}

class InsuranceReviewResult {
  const InsuranceReviewResult({required this.previous, required this.current});

  final InsuranceSnapshot previous;
  final InsuranceSnapshot current;

  double get premiumChange => current.annualPremium - previous.annualPremium;

  double get premiumChangePercent {
    if (previous.annualPremium <= 0) return 0;
    return premiumChange / previous.annualPremium * 100;
  }

  bool get premiumIncreased => premiumChange > 0.01;

  List<String> get removedGuarantees => previous.guarantees
      .where((item) => !current.guarantees.contains(item))
      .toList(growable: false);

  List<String> get addedGuarantees => current.guarantees
      .where((item) => !previous.guarantees.contains(item))
      .toList(growable: false);

  double? get deductibleChange {
    final before = previous.deductible;
    final after = current.deductible;
    if (before == null || after == null) return null;
    return after - before;
  }
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

double _decimal(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

double? _decimalOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.'));
}

bool? _boolOrNull(Object? value) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase();
  if (text == 'true' || text == 'yes' || text == 'oui') return true;
  if (text == 'false' || text == 'no' || text == 'non') return false;
  return null;
}

List<String> _strings(Object? value) {
  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
  final text = _text(value);
  if (text == null) return const [];
  return text
      .split(RegExp(r'[,;\n]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);
}
