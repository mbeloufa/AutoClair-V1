import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'vehicle_360_models.dart';

class VehicleValueChart extends StatelessWidget {
  const VehicleValueChart({required this.marketData, super.key});

  final Vehicle360MarketData marketData;

  @override
  Widget build(BuildContext context) {
    final data = VehicleValueChartData.fromMarketData(marketData);
    if (data.points.isEmpty) {
      return const _ChartEmptyState();
    }

    return Semantics(
      label: data.semanticsLabel,
      image: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 250,
            width: double.infinity,
            child: CustomPaint(
              painter: _VehicleValuePainter(
                data: data,
                textDirection: Directionality.of(context),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: const [
              _LegendItem(label: 'Valeurs observées', color: AppColors.primary),
              _LegendItem(
                label: 'Projection centrale',
                color: AppColors.warning,
                dashed: true,
              ),
              _LegendItem(
                label: 'Fourchette projetée',
                color: AppColors.warning,
                translucent: true,
              ),
            ],
          ),
          if (data.observedCount <= 1) ...[
            const SizedBox(height: 10),
            Text(
              "L'historique se construira à chaque nouvelle valorisation.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class VehicleValueChartData {
  const VehicleValueChartData({
    required this.points,
    required this.lowForecasts,
    required this.centralForecasts,
    required this.highForecasts,
    required this.currentDate,
    required this.observedCount,
  });

  final List<VehicleValueChartPoint> points;
  final List<VehicleValueChartPoint> lowForecasts;
  final List<VehicleValueChartPoint> centralForecasts;
  final List<VehicleValueChartPoint> highForecasts;
  final DateTime? currentDate;
  final int observedCount;

  factory VehicleValueChartData.fromMarketData(
    Vehicle360MarketData marketData,
  ) {
    final observed = <VehicleValueChartPoint>[
      for (final valuation in marketData.history)
        VehicleValueChartPoint(
          date: valuation.valuationDate,
          value: valuation.valueMid,
        ),
    ];

    final current = marketData.privateSale;
    if (current != null &&
        !observed.any(
          (point) =>
              _sameDay(point.date, current.valuationDate) &&
              (point.value - current.valueMid).abs() < 0.01,
        )) {
      observed.add(
        VehicleValueChartPoint(
          date: current.valuationDate,
          value: current.valueMid,
        ),
      );
    }
    observed.sort((left, right) => left.date.compareTo(right.date));

    List<VehicleValueChartPoint> forecastsOf(String scenario) {
      return marketData.forecasts
          .where((item) => item.scenario == scenario)
          .map(
            (item) => VehicleValueChartPoint(
              date: item.forecastDate,
              value: item.value,
            ),
          )
          .toList(growable: false)
        ..sort((left, right) => left.date.compareTo(right.date));
    }

    return VehicleValueChartData(
      points: observed,
      lowForecasts: forecastsOf('low'),
      centralForecasts: forecastsOf('central'),
      highForecasts: forecastsOf('high'),
      currentDate: current?.valuationDate,
      observedCount: observed.length,
    );
  }

  Iterable<VehicleValueChartPoint> get allPoints sync* {
    yield* points;
    yield* lowForecasts;
    yield* centralForecasts;
    yield* highForecasts;
  }

  String get semanticsLabel {
    final values = allPoints.toList(growable: false);
    if (values.isEmpty) return 'Aucune donnée de valeur disponible.';
    final first = values.reduce(
      (left, right) => left.date.isBefore(right.date) ? left : right,
    );
    final last = values.reduce(
      (left, right) => left.date.isAfter(right.date) ? left : right,
    );
    return 'Courbe de valeur du véhicule, de ${_monthYear(first.date)} '
        'à ${_monthYear(last.date)}, entre ${_euro(first.value)} et '
        '${_euro(last.value)}. Les projections sont indicatives.';
  }
}

class VehicleValueChartPoint {
  const VehicleValueChartPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

class _VehicleValuePainter extends CustomPainter {
  const _VehicleValuePainter({required this.data, required this.textDirection});

  final VehicleValueChartData data;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final all = data.allPoints.toList(growable: false);
    if (all.isEmpty) return;

    const left = 48.0;
    const right = 12.0;
    const top = 14.0;
    const bottom = 34.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );

    final minDate = all
        .map((item) => item.date.millisecondsSinceEpoch)
        .reduce((left, right) => left < right ? left : right);
    final maxDate = all
        .map((item) => item.date.millisecondsSinceEpoch)
        .reduce((left, right) => left > right ? left : right);
    final rawMin = all
        .map((item) => item.value)
        .reduce((left, right) => left < right ? left : right);
    final rawMax = all
        .map((item) => item.value)
        .reduce((left, right) => left > right ? left : right);
    final valuePadding = math.max(500.0, (rawMax - rawMin) * 0.18).toDouble();
    final minValue = math.max(0.0, rawMin - valuePadding).toDouble();
    final maxValue = rawMax + valuePadding;

    double x(DateTime date) {
      if (maxDate == minDate) return plot.center.dx;
      return plot.left +
          ((date.millisecondsSinceEpoch - minDate) / (maxDate - minDate)) *
              plot.width;
    }

    double y(double value) {
      if (maxValue == minValue) return plot.center.dy;
      return plot.bottom -
          ((value - minValue) / (maxValue - minValue)) * plot.height;
    }

    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var index = 0; index <= 3; index++) {
      final dy = plot.top + plot.height * index / 3;
      canvas.drawLine(Offset(plot.left, dy), Offset(plot.right, dy), gridPaint);
      final value = maxValue - (maxValue - minValue) * index / 3;
      _drawText(
        canvas,
        _compactEuro(value),
        Offset(0, dy - 7),
        const TextStyle(fontSize: 10, color: AppColors.textMuted),
        maxWidth: left - 6,
        align: TextAlign.right,
      );
    }

    _drawForecastBand(canvas, x, y);
    _drawObserved(canvas, x, y);
    _drawCentralForecast(canvas, x, y);

    final dates = <DateTime>[
      DateTime.fromMillisecondsSinceEpoch(minDate),
      if (maxDate != minDate)
        DateTime.fromMillisecondsSinceEpoch((minDate + maxDate) ~/ 2),
      if (maxDate != minDate) DateTime.fromMillisecondsSinceEpoch(maxDate),
    ];
    for (var index = 0; index < dates.length; index++) {
      final date = dates[index];
      final align = index == 0
          ? TextAlign.left
          : index == dates.length - 1
          ? TextAlign.right
          : TextAlign.center;
      final width = index == 1 ? 100.0 : 86.0;
      final dx = index == 0
          ? plot.left
          : index == dates.length - 1
          ? plot.right - width
          : x(date) - width / 2;
      _drawText(
        canvas,
        _monthYear(date),
        Offset(dx, plot.bottom + 9),
        const TextStyle(fontSize: 10, color: AppColors.textMuted),
        maxWidth: width,
        align: align,
      );
    }
  }

  void _drawObserved(
    Canvas canvas,
    double Function(DateTime) x,
    double Function(double) y,
  ) {
    final points = data.points;
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (points.length > 1) {
      final path = Path()..moveTo(x(points.first.date), y(points.first.value));
      for (final point in points.skip(1)) {
        path.lineTo(x(point.date), y(point.value));
      }
      canvas.drawPath(path, paint);
    }

    final markerPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;
    final markerBorder = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    for (final point in points) {
      final offset = Offset(x(point.date), y(point.value));
      canvas.drawCircle(offset, 4.5, markerPaint);
      canvas.drawCircle(offset, 4.5, markerBorder);
    }
  }

  void _drawCentralForecast(
    Canvas canvas,
    double Function(DateTime) x,
    double Function(double) y,
  ) {
    final forecast = data.centralForecasts;
    if (forecast.isEmpty) return;

    final series = <VehicleValueChartPoint>[
      if (data.points.isNotEmpty) data.points.last,
      ...forecast,
    ];
    final paint = Paint()
      ..color = AppColors.warning
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var index = 0; index < series.length - 1; index++) {
      _drawDashedLine(
        canvas,
        Offset(x(series[index].date), y(series[index].value)),
        Offset(x(series[index + 1].date), y(series[index + 1].value)),
        paint,
      );
    }

    final marker = Paint()
      ..color = AppColors.warning
      ..style = PaintingStyle.fill;
    for (final point in forecast) {
      canvas.drawCircle(Offset(x(point.date), y(point.value)), 4, marker);
    }
  }

  void _drawForecastBand(
    Canvas canvas,
    double Function(DateTime) x,
    double Function(double) y,
  ) {
    if (data.lowForecasts.isEmpty || data.highForecasts.isEmpty) return;

    final lows = <DateTime, double>{
      for (final point in data.lowForecasts) point.date: point.value,
    };
    final highs = <DateTime, double>{
      for (final point in data.highForecasts) point.date: point.value,
    };
    final dates = lows.keys.where(highs.containsKey).toList(growable: false)
      ..sort();
    if (dates.isEmpty) return;

    final path = Path()..moveTo(x(dates.first), y(highs[dates.first]!));
    for (final date in dates.skip(1)) {
      path.lineTo(x(date), y(highs[date]!));
    }
    for (final date in dates.reversed) {
      path.lineTo(x(date), y(lows[date]!));
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.warning.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 7.0;
    const gap = 5.0;
    final distance = (end - start).distance;
    if (distance <= 0) return;
    final direction = (end - start) / distance;
    var travelled = 0.0;
    while (travelled < distance) {
      final segmentEnd = math.min(travelled + dash, distance).toDouble();
      canvas.drawLine(
        start + direction * travelled,
        start + direction * segmentEnd,
        paint,
      );
      travelled += dash + gap;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    required double maxWidth,
    required TextAlign align,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textAlign: align,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _VehicleValuePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.textDirection != textDirection;
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.color,
    this.dashed = false,
    this.translucent = false,
  });

  final String label;
  final Color color;
  final bool dashed;
  final bool translucent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: translucent ? 10 : 3,
          decoration: BoxDecoration(
            color: translucent ? color.withValues(alpha: 0.16) : color,
            borderRadius: BorderRadius.circular(6),
            border: dashed ? Border.all(color: color) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.show_chart_outlined, color: AppColors.textMuted, size: 34),
          SizedBox(height: 10),
          Text(
            'La courbe apparaîtra dès qu’une cote professionnelle sera disponible.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _monthYear(DateTime date) {
  const months = <String>[
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String _compactEuro(double value) {
  if (value >= 1000) {
    final thousands = value / 1000;
    final decimals = thousands >= 10 ? 0 : 1;
    return '${thousands.toStringAsFixed(decimals)} k€';
  }
  return '${value.round()} €';
}

String _euro(double value) {
  final raw = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    if (index > 0 && (raw.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(raw[index]);
  }
  return '${buffer.toString()} €';
}
