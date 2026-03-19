class DexConfig {
  const DexConfig._();

  static const String wrappedReefAddress = String.fromEnvironment(
    'REEFSWAP_WREEF',
    defaultValue: '0xfDFBc0843889FD11BaF6EB0e01522D1a2116Ef4B',
  );

  static const String factoryAddress = String.fromEnvironment(
    'REEFSWAP_FACTORY',
    defaultValue: '0x8cF3B3a7BA07ff6B06cE8D4686E363054B4783a0',
  );

  static const String routerAddress = String.fromEnvironment(
    'REEFSWAP_ROUTER',
    defaultValue: '0xc0b241faE336D672CE58bd572ab8A3f0fbBC831d',
  );

  static const int defaultChainId = int.fromEnvironment(
    'REEF_CHAIN_ID',
    defaultValue: 13939,
  );

  static const double defaultSlippagePercent = 0.8;
  static const int defaultDeadlineMinutes = 20;
}
