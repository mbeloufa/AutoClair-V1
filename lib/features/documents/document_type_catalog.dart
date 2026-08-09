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

  static const detectedOnlyDefinitions = <DocumentTypeDefinition>[
    DocumentTypeDefinition(
      value: 'purchase_order',
      label: 'Bon de commande',
      icon: Icons.shopping_cart_outlined,
    ),
    DocumentTypeDefinition(
      value: 'sale_contract',
      label: 'Contrat de vente',
      icon: Icons.handshake_outlined,
    ),
    DocumentTypeDefinition(
      value: 'lease_contract',
      label: 'Contrat de location',
      icon: Icons.assignment_outlined,
    ),
    DocumentTypeDefinition(
      value: 'loa_contract',
      label: 'Contrat LOA',
      icon: Icons.event_repeat_outlined,
    ),
    DocumentTypeDefinition(
      value: 'lld_contract',
      label: 'Contrat LLD',
      icon: Icons.calendar_month_outlined,
    ),
    DocumentTypeDefinition(
      value: 'insurance_contract',
      label: 'Contrat d’assurance',
      icon: Icons.shield_outlined,
    ),
  ];

  static Iterable<DocumentTypeDefinition> get allDefinitions sync* {
    yield* definitions;
    yield* detectedOnlyDefinitions;
  }

  static DocumentTypeDefinition? definitionFor(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;

    for (final definition in allDefinitions) {
      if (definition.value == normalized) return definition;
    }

    return null;
  }

  static String labelFor(String? value, {String fallback = 'Document'}) {
    return definitionFor(value)?.label ?? fallback;
  }

  static bool isSelectable(String? value) {
    final normalized = value?.trim().toLowerCase();
    return definitions.any((definition) => definition.value == normalized);
  }

  static bool isKnown(String? value) => definitionFor(value) != null;
}
