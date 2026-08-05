import 'package:intl/intl.dart';

abstract final class MoneyFormatter {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  );

  static String euros(num value) => _currency.format(value);

  static String compactEuros(num value) {
    final digits = value.abs() >= 100 ? 0 : 2;
    return NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '€',
      decimalDigits: digits,
    ).format(value);
  }
}
