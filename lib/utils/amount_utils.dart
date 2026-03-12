import 'dart:math' as math;

class AmountUtils {
  const AmountUtils._();

  static String trimTrailingZeros(String value) {
    return value
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static double parseNumeric(String? value, {double fallback = 0}) {
    final normalized = (value ?? '').trim().replaceAll(',', '');
    if (normalized.isEmpty) return fallback;
    return double.tryParse(normalized) ?? fallback;
  }

  static bool hasPositiveBalance(String value) {
    return parseNumeric(value) > 0;
  }

  static String formatAmountFromRaw(
    BigInt raw,
    int decimals, {
    int maxPrecision = 6,
  }) {
    if (raw == BigInt.zero) return '0';
    if (decimals <= 0) return raw.toString();

    final divisor = BigInt.from(10).pow(decimals);
    final whole = raw ~/ divisor;
    final fractionRaw = raw
        .remainder(divisor)
        .toString()
        .padLeft(decimals, '0');

    final precision = math.min(maxPrecision, decimals);
    if (precision <= 0) return whole.toString();

    var fraction = fractionRaw.substring(0, precision);
    fraction = trimTrailingZeros(fraction);
    if (fraction.isEmpty) return whole.toString();
    return '$whole.$fraction';
  }

  static BigInt parseAmountToRaw(String amount, int decimals) {
    final normalized = amount.trim().replaceAll(',', '');
    if (normalized.isEmpty) {
      throw Exception('Amount is empty');
    }

    final parts = normalized.split('.');
    if (parts.length > 2) {
      throw Exception('Invalid amount');
    }

    final whole = BigInt.tryParse(parts[0].isEmpty ? '0' : parts[0]);
    if (whole == null) {
      throw Exception('Invalid amount');
    }

    final fractionInput = parts.length == 2 ? parts[1] : '';
    if (!RegExp(r'^\d*$').hasMatch(fractionInput)) {
      throw Exception('Invalid amount');
    }

    final trimmedFraction = fractionInput.length > decimals
        ? fractionInput.substring(0, decimals)
        : fractionInput;
    final paddedFraction = trimmedFraction.padRight(decimals, '0');
    final fraction = paddedFraction.isEmpty
        ? BigInt.zero
        : BigInt.parse(paddedFraction);

    return whole * BigInt.from(10).pow(decimals) + fraction;
  }

  static BigInt parsePositiveBigInt(dynamic value) {
    if (value == null) return BigInt.zero;
    final text = value.toString().trim();
    if (text.isEmpty) return BigInt.zero;

    BigInt parsed;
    if (text.startsWith('0x') || text.startsWith('0X')) {
      parsed = BigInt.tryParse(text.substring(2), radix: 16) ?? BigInt.zero;
    } else {
      final intPart = text.split('.').first;
      parsed = BigInt.tryParse(intPart) ?? BigInt.zero;
    }

    return parsed < BigInt.zero ? BigInt.zero : parsed;
  }

  static String formatReefBalance(String raw) {
    final parsed = parseNumeric(raw, fallback: double.nan);
    if (parsed.isNaN) return '...';
    if (parsed <= 0) return '0.0';
    if (parsed >= 1000) return parsed.toStringAsFixed(2);
    if (parsed >= 1) {
      return trimTrailingZeros(parsed.toStringAsFixed(3));
    }
    return trimTrailingZeros(parsed.toStringAsFixed(6));
  }

  static String formatInputAmount(double value, {int decimals = 4}) {
    return trimTrailingZeros(value.toStringAsFixed(decimals));
  }

  static String formatCompactToken(String raw) {
    final parsed = parseNumeric(raw);
    if (parsed == 0) return '0';
    if (parsed >= 1000) {
      return '${(parsed / 1000).toStringAsFixed(2)}K';
    }
    return trimTrailingZeros(parsed.toStringAsFixed(parsed < 1 ? 6 : 4));
  }

  static String formatShortUsd(double value) {
    if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}K';
    }
    return '\$${value.toStringAsFixed(2)}';
  }

  static String formatRate(double value) {
    if (value <= 0 || !value.isFinite) return '0';
    if (value < 1) return value.toStringAsFixed(6);
    if (value < 100) return value.toStringAsFixed(4);
    return value.toStringAsFixed(2);
  }
}
