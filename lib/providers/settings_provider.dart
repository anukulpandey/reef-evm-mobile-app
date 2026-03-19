import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'service_providers.dart';
import '../constants/storage_keys.dart';
import 'package:flutter/material.dart';
import '../core/config/dex_config.dart';
import '../models/fiat_currency.dart';

class SettingsState {
  final String rpcUrl;
  final bool? useBiometrics;
  final bool? goHomeOnSwitch;
  final bool? developerMode;
  final bool? developerExpanded;
  final ThemeMode themeMode;
  final FiatCurrency fiatCurrency;
  final double defaultSlippagePercent;

  SettingsState({
    required this.rpcUrl,
    required this.useBiometrics,
    required this.goHomeOnSwitch,
    this.developerMode,
    this.developerExpanded,
    required this.themeMode,
    required this.fiatCurrency,
    required this.defaultSlippagePercent,
  });

  SettingsState copyWith({
    String? rpcUrl,
    bool? useBiometrics,
    bool? goHomeOnSwitch,
    bool? developerMode,
    bool? developerExpanded,
    ThemeMode? themeMode,
    FiatCurrency? fiatCurrency,
    double? defaultSlippagePercent,
  }) {
    return SettingsState(
      rpcUrl: rpcUrl ?? this.rpcUrl,
      useBiometrics: useBiometrics ?? this.useBiometrics,
      goHomeOnSwitch: goHomeOnSwitch ?? this.goHomeOnSwitch,
      developerMode: developerMode ?? this.developerMode,
      developerExpanded: developerExpanded ?? this.developerExpanded,
      themeMode: themeMode ?? this.themeMode,
      fiatCurrency: fiatCurrency ?? this.fiatCurrency,
      defaultSlippagePercent:
          defaultSlippagePercent ?? this.defaultSlippagePercent,
    );
  }

  bool get developerModeEnabled => developerMode ?? false;
  bool get isDeveloperExpanded => developerExpanded ?? false;
  bool get biometricsEnabled => useBiometrics ?? false;
  bool get goHomeEnabled => goHomeOnSwitch ?? true;
  bool get darkModeEnabled => themeMode == ThemeMode.dark;
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const String _defaultRpcUrl = 'http://localhost:8545';

  @override
  SettingsState build() {
    // Initial state
    Future.microtask(() => _loadSettings());
    return SettingsState(
      rpcUrl: _defaultRpcUrl,
      useBiometrics: false,
      goHomeOnSwitch: true,
      developerMode: false,
      developerExpanded: false,
      themeMode: ThemeMode.dark,
      fiatCurrency: FiatCurrency.usd,
      defaultSlippagePercent: DexConfig.defaultSlippagePercent,
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final rpc = prefs.getString(StorageKeys.rpcUrl) ?? _defaultRpcUrl;
    final biometrics = prefs.getBool(StorageKeys.useBiometrics) ?? false;
    final goHome = prefs.getBool(StorageKeys.goHomeOnSwitch) ?? true;
    final developerMode = prefs.getBool(StorageKeys.developerMode) ?? false;
    final themeModeRaw = prefs.getString(StorageKeys.themeMode);
    final fiatCurrencyRaw = prefs.getString(StorageKeys.fiatCurrency);
    final slippageRaw = prefs.getDouble(StorageKeys.defaultSlippagePercent);

    state = state.copyWith(
      rpcUrl: rpc,
      useBiometrics: biometrics,
      goHomeOnSwitch: goHome,
      developerMode: developerMode,
      developerExpanded: state.developerExpanded,
      themeMode: _parseThemeMode(themeModeRaw),
      fiatCurrency: FiatCurrencyX.fromCode(fiatCurrencyRaw),
      defaultSlippagePercent: _sanitizeSlippage(slippageRaw),
    );

    // Update Web3 Service
    ref.read(web3ServiceProvider).updateRpc(rpc);
  }

  Future<void> setRpcUrl(String rpcUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.rpcUrl, rpcUrl);
    state = state.copyWith(rpcUrl: rpcUrl);

    // Update Web3 Service
    ref.read(web3ServiceProvider).updateRpc(rpcUrl);
  }

  Future<void> setBiometrics(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.useBiometrics, enabled);
    state = state.copyWith(useBiometrics: enabled);
  }

  Future<void> setGoHomeOnSwitch(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.goHomeOnSwitch, enabled);
    state = state.copyWith(goHomeOnSwitch: enabled);
  }

  Future<void> setDeveloperMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.developerMode, enabled);
    state = state.copyWith(
      developerMode: enabled,
      developerExpanded: enabled ? state.developerExpanded : false,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.themeMode, _themeModeToStorage(mode));
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setFiatCurrency(FiatCurrency currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.fiatCurrency, currency.code);
    state = state.copyWith(fiatCurrency: currency);
  }

  Future<void> setDefaultSlippagePercent(double percent) async {
    final normalized = _sanitizeSlippage(percent);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(StorageKeys.defaultSlippagePercent, normalized);
    state = state.copyWith(defaultSlippagePercent: normalized);
  }

  void setDeveloperExpanded(bool expanded) {
    state = state.copyWith(developerExpanded: expanded);
  }

  static ThemeMode _parseThemeMode(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.dark;
    }
  }

  static String _themeModeToStorage(ThemeMode mode) {
    return mode == ThemeMode.light ? 'light' : 'dark';
  }

  static double _sanitizeSlippage(double? raw) {
    if (raw == null || !raw.isFinite) {
      return DexConfig.defaultSlippagePercent;
    }
    return raw.clamp(0.1, 20.0);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
