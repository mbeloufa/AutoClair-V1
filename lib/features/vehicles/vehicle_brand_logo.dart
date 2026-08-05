import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'vehicle_brand_catalog.dart';

class VehicleBrandLogo extends StatelessWidget {
  const VehicleBrandLogo({
    required this.brand,
    this.size = 48,
    this.showName = false,
    this.foregroundColor,
    this.backgroundColor,
    this.borderColor,
    this.textStyle,
    super.key,
  });

  final String brand;
  final double size;
  final bool showName;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final definition = VehicleBrandCatalog.definitionFor(brand);
    final displayName = VehicleBrandCatalog.displayName(brand);
    final foreground = foregroundColor ?? AppColors.primary;
    final background = backgroundColor ?? AppColors.softPrimary;

    final badge = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.30),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: brand.trim().isEmpty
          ? Icon(
              Icons.directions_car_outlined,
              color: foreground,
              size: size * 0.52,
            )
          : definition?.icon == null
          ? Text(
              VehicleBrandCatalog.initials(brand),
              style: TextStyle(
                color: foreground,
                fontSize: size * 0.27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            )
          : Icon(definition!.icon, color: foreground, size: size * 0.56),
    );

    if (!showName) return badge;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle ?? Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}
