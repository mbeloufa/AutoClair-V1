import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 38 : 48,
          height: compact ? 38 : 48,
          decoration: BoxDecoration(
            color: AppColors.softPrimary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.menu_book_rounded,
            color: AppColors.primary,
            size: compact ? 24 : 30,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'AutoClair',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 20 : 24,
          ),
        ),
      ],
    );
  }
}
