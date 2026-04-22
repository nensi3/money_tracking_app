import 'package:intl/intl.dart';

const Map<String, String> _currencySymbols = {
  'USD': r'$',
  'EUR': '€',
  'GBP': '£',
  'INR': '₹',
  'JPY': '¥',
};

String normalizeCurrencyCode(dynamic value) {
  final code = (value ?? 'USD').toString().trim().toUpperCase();
  if (_currencySymbols.containsKey(code)) return code;
  return 'USD';
}

String currencySymbolForCode(String code) {
  final normalized = normalizeCurrencyCode(code);
  return _currencySymbols[normalized] ?? r'$';
}

String formatCurrency(double amount, {required String currencyCode}) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: currencySymbolForCode(currencyCode),
    decimalDigits: 0,
  ).format(amount);
}
