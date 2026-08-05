import 'package:flutter/material.dart';

class DocumentTypeDefinition {
  const DocumentTypeDefinition({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;
}

abstract final class DocumentTypeCatalog {
  static const definitions = <DocumentTypeDefinition>[
    DocumentTypeDefinition(
      value: 'estimate',
      label: 'Devis',
      icon: Icons.request_quote_outlined,
    ),
    DocumentTypeDefinition(
      value: 'invoice',
      label: 'Facture',
      icon: Icons.receipt_long_outlined,
    ),
    DocumentTypeDefinition(
      value: 'repair_order',
      label: 'Ordre de réparation',
      icon: Icons.car_repair_outlined,
    ),
    DocumentTypeDefinition(
      value: 'technical_inspection_report',
      label: 'Contrôle technique',
      icon: Icons.fact_check_outlined,
    ),
    DocumentTypeDefinition(
      value: 'other',
      label: 'Autre',
      icon: Icons.description_outlined,
    ),
  ];

  static DocumentTypeDefinition? definitionFor(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;

    for (final definition in definitions) {
      if (definition.value == normalized) return definition;
    }

    return null;
  }

  static String labelFor(String? value, {String fallback = 'Document'}) {
    return definitionFor(value)?.label ?? fallback;
  }

  static bool isSelectable(String? value) => definitionFor(value) != null;
}
