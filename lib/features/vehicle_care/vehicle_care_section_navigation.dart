import 'package:flutter/material.dart';

Future<bool> ensureVehicleCareSectionVisible({
  required GlobalKey contentKey,
  required GlobalKey fallbackKey,
  Duration duration = const Duration(milliseconds: 360),
}) async {
  final targetContext = contentKey.currentContext ?? fallbackKey.currentContext;
  if (targetContext == null) {
    return false;
  }

  await Scrollable.ensureVisible(
    targetContext,
    duration: duration,
    curve: Curves.easeOutCubic,
    alignment: 0.04,
  );
  return true;
}
