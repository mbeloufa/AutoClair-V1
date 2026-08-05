import 'package:flutter/material.dart';
import 'package:simple_icons/simple_icons.dart';

class VehicleBrandDefinition {
  const VehicleBrandDefinition({
    required this.name,
    this.aliases = const [],
    this.icon,
  });

  final String name;
  final List<String> aliases;
  final IconData? icon;

  Iterable<String> get searchableValues => [name, ...aliases];
}

abstract final class VehicleBrandCatalog {
  static const definitions = <VehicleBrandDefinition>[
    VehicleBrandDefinition(name: 'Abarth'),
    VehicleBrandDefinition(name: 'Alfa Romeo', aliases: ['Alfa']),
    VehicleBrandDefinition(name: 'Alpine'),
    VehicleBrandDefinition(name: 'Audi', icon: SimpleIcons.audi),
    VehicleBrandDefinition(name: 'BMW', icon: SimpleIcons.bmw),
    VehicleBrandDefinition(name: 'BYD'),
    VehicleBrandDefinition(
      name: 'Citroën',
      aliases: ['Citroen'],
      icon: SimpleIcons.citroen,
    ),
    VehicleBrandDefinition(name: 'CUPRA'),
    VehicleBrandDefinition(name: 'Dacia', icon: SimpleIcons.dacia),
    VehicleBrandDefinition(
      name: 'DS Automobiles',
      aliases: ['DS'],
      icon: SimpleIcons.dsautomobiles,
    ),
    VehicleBrandDefinition(name: 'Fiat', icon: SimpleIcons.fiat),
    VehicleBrandDefinition(name: 'Ford', icon: SimpleIcons.ford),
    VehicleBrandDefinition(name: 'Honda', icon: SimpleIcons.honda),
    VehicleBrandDefinition(name: 'Hyundai', icon: SimpleIcons.hyundai),
    VehicleBrandDefinition(name: 'Jaguar'),
    VehicleBrandDefinition(name: 'Jeep', icon: SimpleIcons.jeep),
    VehicleBrandDefinition(name: 'Kia', icon: SimpleIcons.kia),
    VehicleBrandDefinition(name: 'Land Rover'),
    VehicleBrandDefinition(name: 'Lexus'),
    VehicleBrandDefinition(name: 'Mazda', icon: SimpleIcons.mazda),
    VehicleBrandDefinition(
      name: 'Mercedes-Benz',
      aliases: ['Mercedes', 'Mercedes Benz'],
    ),
    VehicleBrandDefinition(name: 'MG', icon: SimpleIcons.mg),
    VehicleBrandDefinition(name: 'MINI', icon: SimpleIcons.mini),
    VehicleBrandDefinition(name: 'Mitsubishi', icon: SimpleIcons.mitsubishi),
    VehicleBrandDefinition(name: 'Nissan', icon: SimpleIcons.nissan),
    VehicleBrandDefinition(name: 'Opel', icon: SimpleIcons.opel),
    VehicleBrandDefinition(name: 'Peugeot', icon: SimpleIcons.peugeot),
    VehicleBrandDefinition(name: 'Polestar', icon: SimpleIcons.polestar),
    VehicleBrandDefinition(name: 'Porsche', icon: SimpleIcons.porsche),
    VehicleBrandDefinition(name: 'Renault', icon: SimpleIcons.renault),
    VehicleBrandDefinition(name: 'SEAT', icon: SimpleIcons.seat),
    VehicleBrandDefinition(
      name: 'Škoda',
      aliases: ['Skoda'],
      icon: SimpleIcons.skoda,
    ),
    VehicleBrandDefinition(name: 'Smart', icon: SimpleIcons.smart),
    VehicleBrandDefinition(name: 'Subaru', icon: SimpleIcons.subaru),
    VehicleBrandDefinition(name: 'Suzuki', icon: SimpleIcons.suzuki),
    VehicleBrandDefinition(name: 'Tesla', icon: SimpleIcons.tesla),
    VehicleBrandDefinition(name: 'Toyota', icon: SimpleIcons.toyota),
    VehicleBrandDefinition(
      name: 'Volkswagen',
      aliases: ['VW', 'Volkswagen France'],
      icon: SimpleIcons.volkswagen,
    ),
    VehicleBrandDefinition(name: 'Volvo', icon: SimpleIcons.volvo),
  ];

  static VehicleBrandDefinition? definitionFor(String? rawBrand) {
    final normalized = normalize(rawBrand);
    if (normalized.isEmpty) return null;

    for (final definition in definitions) {
      for (final candidate in definition.searchableValues) {
        if (normalize(candidate) == normalized) return definition;
      }
    }

    return null;
  }

  static bool isKnown(String? rawBrand) => definitionFor(rawBrand) != null;

  static String displayName(String? rawBrand) {
    final trimmed = rawBrand?.trim() ?? '';
    if (trimmed.isEmpty) return 'Marque inconnue';
    return definitionFor(trimmed)?.name ?? trimmed;
  }

  static String canonicalValue(String rawBrand) {
    final trimmed = rawBrand.trim();
    return definitionFor(trimmed)?.name ?? trimmed;
  }

  static List<VehicleBrandDefinition> search(String query) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return definitions;

    return definitions
        .where(
          (definition) => definition.searchableValues.any(
            (candidate) => normalize(candidate).contains(normalizedQuery),
          ),
        )
        .toList(growable: false);
  }

  static String initials(String? rawBrand) {
    final value = displayName(rawBrand);
    final words = value
        .split(RegExp(r'[\s-]+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);

    if (words.isEmpty) return 'AC';
    if (words.length == 1) {
      final word = words.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }

    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  static String normalize(String? value) {
    var normalized = (value ?? '').trim().toLowerCase();
    const replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'æ': 'ae',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'œ': 'oe',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'š': 's',
    };

    replacements.forEach((source, target) {
      normalized = normalized.replaceAll(source, target);
    });

    return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
