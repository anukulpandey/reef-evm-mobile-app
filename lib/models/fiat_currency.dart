enum FiatCurrency { usd, eur, inr, gbp, jpy }

extension FiatCurrencyX on FiatCurrency {
  String get code => switch (this) {
    FiatCurrency.usd => 'USD',
    FiatCurrency.eur => 'EUR',
    FiatCurrency.inr => 'INR',
    FiatCurrency.gbp => 'GBP',
    FiatCurrency.jpy => 'JPY',
  };

  String get label => switch (this) {
    FiatCurrency.usd => 'US Dollar',
    FiatCurrency.eur => 'Euro',
    FiatCurrency.inr => 'Indian Rupee',
    FiatCurrency.gbp => 'British Pound',
    FiatCurrency.jpy => 'Japanese Yen',
  };

  String get symbol => switch (this) {
    FiatCurrency.usd => '\$',
    FiatCurrency.eur => '€',
    FiatCurrency.inr => '₹',
    FiatCurrency.gbp => '£',
    FiatCurrency.jpy => '¥',
  };

  double get fromUsdRate => switch (this) {
    FiatCurrency.usd => 1.0,
    FiatCurrency.eur => 0.92,
    FiatCurrency.inr => 83.0,
    FiatCurrency.gbp => 0.79,
    FiatCurrency.jpy => 149.5,
  };

  int get standardDecimals => this == FiatCurrency.jpy ? 0 : 2;

  static FiatCurrency fromCode(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'EUR':
        return FiatCurrency.eur;
      case 'INR':
        return FiatCurrency.inr;
      case 'GBP':
        return FiatCurrency.gbp;
      case 'JPY':
        return FiatCurrency.jpy;
      case 'USD':
      default:
        return FiatCurrency.usd;
    }
  }
}
