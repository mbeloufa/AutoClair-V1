import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class NearbyRadiusSlider extends StatelessWidget {
  const NearbyRadiusSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    super.key,
    this.enabled = true,
    this.title = 'Rayon de recherche',
    this.unit = 'km',
    this.icon = Icons.radar_rounded,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final bool enabled;
  final String title;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      value: '${_format(value)} $unit',
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
        decoration: BoxDecoration(
          color: AppColors.softPrimary,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${_format(value)} $unit',
                  key: const ValueKey('nearby-slider-value'),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: divisions,
              label: '${_format(value)} $unit',
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }

  static String _format(double value) {
    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1).replaceAll('.', ',');
  }
}
