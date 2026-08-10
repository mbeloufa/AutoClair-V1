import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class VehicleIdentificationDetailsView extends StatelessWidget {
  const VehicleIdentificationDetailsView({
    required this.identity,
    required this.technical,
    required this.administrative,
    required this.aftersales,
    this.compact = false,
    super.key,
  });

  final Map<String, dynamic> identity;
  final Map<String, dynamic> technical;
  final Map<String, dynamic> administrative;
  final Map<String, dynamic> aftersales;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final groups =
        <_DetailGroup>[
              _DetailGroup(
                title: 'Identification',
                icon: Icons.fingerprint_rounded,
                entries: [
                  _entry(identity, 'vin', 'VIN'),
                  _entry(identity, 'full_label', 'Désignation complète'),
                  _entry(identity, 'version', 'Version'),
                  _entry(identity, 'trim', 'Finition'),
                  _entry(
                    identity,
                    'first_registration_date',
                    '1re mise en circulation',
                  ),
                  _entry(
                    identity,
                    'registration_certificate_date',
                    'Date carte grise',
                  ),
                  _entry(identity, 'color', 'Couleur'),
                ],
              ),
              _DetailGroup(
                title: 'Technique',
                icon: Icons.settings_suggest_outlined,
                entries: [
                  _entry(technical, 'power_kw', 'Puissance', suffix: ' kW'),
                  _entry(
                    technical,
                    'horsepower',
                    'Puissance moteur',
                    suffix: ' ch',
                  ),
                  _entry(
                    technical,
                    'fiscal_power',
                    'Puissance fiscale',
                    suffix: ' CV',
                  ),
                  _entry(technical, 'engine_label', 'Moteur'),
                  _entry(technical, 'engine_code', 'Code moteur'),
                  _entry(technical, 'gearbox_type', 'Boîte de vitesses'),
                  _entry(technical, 'transmission_mode', 'Transmission'),
                  _entry(technical, 'body_style', 'Carrosserie'),
                  _entry(technical, 'seats', 'Places'),
                  _entry(technical, 'doors', 'Portes'),
                  _entry(technical, 'ptac_kg', 'PTAC', suffix: ' kg'),
                  _entry(
                    technical,
                    'co2_g_km',
                    'CO₂',
                    suffix: ' g/km',
                    allowZero: true,
                  ),
                  _entry(technical, 'euro_standard', 'Norme Euro'),
                  _entry(technical, 'critair_code', 'Code Crit’Air'),
                  _entry(
                    technical,
                    'max_speed_kmh',
                    'Vitesse max.',
                    suffix: ' km/h',
                  ),
                  _entry(technical, 'tyres', 'Pneumatiques'),
                ],
              ),
              _DetailGroup(
                title: 'Carte grise',
                icon: Icons.badge_outlined,
                entries: [
                  _entry(administrative, 'vehicle_category', 'Catégorie'),
                  _entry(administrative, 'genre_label', 'Genre'),
                  _entry(administrative, 'type_mine', 'Type mine / CNIT'),
                  _entry(
                    administrative,
                    'type_variant_version',
                    'Type / variante / version',
                  ),
                  _entry(
                    administrative,
                    'european_approval',
                    'Réception européenne',
                  ),
                  _entry(administrative, 'country', 'Pays'),
                  _entry(administrative, 'collection', 'Collection'),
                ],
              ),
              _DetailGroup(
                title: 'Après-vente & pièces',
                icon: Icons.build_circle_outlined,
                entries: [
                  _entry(aftersales, 'k_type', 'K-Type TecDoc'),
                  _entry(aftersales, 'k_types', 'K-Types compatibles'),
                  _entry(aftersales, 'sra_code', 'Code SRA'),
                  _entry(aftersales, 'sra_codes', 'Codes SRA'),
                  _entry(aftersales, 'tecdoc_model_id', 'ID modèle TecDoc'),
                  _entry(aftersales, 'tecdoc_vehicle_id', 'ID véhicule TecDoc'),
                  _entry(
                    aftersales,
                    'tecdoc_model_description',
                    'Description TecDoc',
                  ),
                  _entry(
                    aftersales,
                    'manufacturer_group',
                    'Groupe constructeur',
                  ),
                ],
              ),
            ]
            .map((group) => group.visible())
            .where((group) => group.entries.isNotEmpty)
            .toList();

    if (groups.isEmpty) return const SizedBox.shrink();

    if (compact) {
      final items = groups.expand((group) => group.entries).take(6).toList();
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map(
              (item) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${item.label} : ${item.text}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
            .toList(growable: false),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < groups.length; index++) ...[
          _DetailGroupView(group: groups[index]),
          if (index != groups.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  static _DetailEntry _entry(
    Map<String, dynamic> map,
    String key,
    String label, {
    String suffix = '',
    bool allowZero = false,
  }) {
    final value = map[key];
    return _DetailEntry(
      label: label,
      text: _valueText(value, suffix: suffix, allowZero: allowZero),
    );
  }

  static String? _valueText(
    Object? value, {
    required String suffix,
    required bool allowZero,
  }) {
    if (value == null) return null;
    if (value is List) {
      final parts = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty && item.toUpperCase() != 'INCONNU')
          .toList(growable: false);
      return parts.isEmpty ? null : parts.join(', ');
    }
    final text = value.toString().trim();
    if (text.isEmpty || text.toUpperCase() == 'INCONNU') return null;
    final number = num.tryParse(text.replaceAll(',', '.'));
    if (!allowZero && number != null && number == 0) return null;
    return '$text$suffix';
  }
}

class _DetailGroupView extends StatelessWidget {
  const _DetailGroupView({required this.group});

  final _DetailGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(group.icon, size: 19, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                group.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final entry in group.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 126,
                    child: Text(
                      entry.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.text!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailGroup {
  const _DetailGroup({
    required this.title,
    required this.icon,
    required this.entries,
  });

  final String title;
  final IconData icon;
  final List<_DetailEntry> entries;

  _DetailGroup visible() => _DetailGroup(
    title: title,
    icon: icon,
    entries: entries
        .where((entry) => entry.text != null)
        .toList(growable: false),
  );
}

class _DetailEntry {
  const _DetailEntry({required this.label, required this.text});

  final String label;
  final String? text;
}
