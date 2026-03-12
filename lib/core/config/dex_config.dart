class DexConfig {
  const DexConfig._();

  static const String wrappedReefAddress = String.fromEnvironment(
    'REEFSWAP_WREEF',
    defaultValue: '0xF98A2F57B4bFA3a8AcF28841eDDca0865d8B0365',
  );

  static const String factoryAddress = String.fromEnvironment(
    'REEFSWAP_FACTORY',
    defaultValue: '0xC250F1F99C12DcdDB1dbAac59e75A4F054BBf276',
  );

  static const String routerAddress = String.fromEnvironment(
    'REEFSWAP_ROUTER',
    defaultValue: '0xCFF0d9b4c6377aB3188094dB096fB958d55C4f10',
  );

  static const int defaultChainId = int.fromEnvironment(
    'REEF_CHAIN_ID',
    defaultValue: 13939,
  );

  static const double defaultSlippagePercent = 0.8;
  static const int defaultDeadlineMinutes = 20;
}
