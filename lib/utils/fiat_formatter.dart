import 'package:intl/intl.dart';

import '../models/fiat_currency.dart';
import 'amount_utils.dart';

class FiatFormatter {
  const FiatFormatter._();

  static double convertFromUsd(double usdValue, FiatCurrency currency) {
    if (!usdValue.isFinite) return 0;
    return usdValue * currency.fromUsdRate;
  }

  static String formatValue(
    double usdValue,
    FiatCurrency currency, {
    bool compact = false,
  }) {
    final converted = convertFromUsd(usdValue, currency);
    if (!converted.isFinite || converted <= 0) {
      return _zeroValue(currency);
    }

    if (compact) {
      return '${currency.symbol}${AmountUtils.formatCompactNumber(converted, fractionDecimals: converted >= 100000 ? 1 : 2)}';
    }

    final decimals = converted >= 0.01 ? currency.standardDecimals : 6;
    return NumberFormat.currency(
      symbol: currency.symbol,
      decimalDigits: decimals,
    ).format(converted);
  }

  static String formatPrice(
    double usdPrice,
    FiatCurrency currency, {
    String prefix = 'Price:',
  }) {
    final converted = convertFromUsd(usdPrice, currency);
    if (!converted.isFinite || converted <= 0) {
      return '$prefix ${_zeroValue(currency)}';
    }

    final decimals = converted >= 1 ? currency.standardDecimals : 6;
    final formatted = NumberFormat.currency(
      symbol: currency.symbol,
      decimalDigits: decimals,
    ).format(converted);
    return '$prefix $formatted';
  }

  static String formatShortValue(double usdValue, FiatCurrency currency) {
    return formatValue(usdValue, currency, compact: true);
  }

  static String _zeroValue(FiatCurrency currency) {
    final decimals = currency.standardDecimals;
    if (decimals <= 0) return '${currency.symbol}0';
    return '${currency.symbol}0.${'0' * decimals}';
  }
}
