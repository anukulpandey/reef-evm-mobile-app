class DexConfig {
  const DexConfig._();

  static const String wrappedReefAddress = String.fromEnvironment(
    'REEFSWAP_WREEF',
    defaultValue: '0xc14FA2CFcaB2F88Cdd8a7E8Be7222DB74b3e970b',
  );

  static const String factoryAddress = String.fromEnvironment(
    'REEFSWAP_FACTORY',
    defaultValue: '0xFCB548Cced2360b298Bf9f02F21CB086A662cBB2',
  );

  static const String routerAddress = String.fromEnvironment(
    'REEFSWAP_ROUTER',
    defaultValue: '0xD5B9E82936554CA8D65dE341574AA62877D1A7F1',
  );

  static const int defaultChainId = int.fromEnvironment(
    'REEF_CHAIN_ID',
    defaultValue: 13939,
  );

  static const double defaultSlippagePercent = 0.8;
  static const int defaultDeadlineMinutes = 20;
}
