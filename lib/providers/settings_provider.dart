import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'service_providers.dart';
import '../constants/storage_keys.dart';

class SettingsState {
  final String rpcUrl;
  final bool? useBiometrics;
  final bool? goHomeOnSwitch;
  final bool? developerExpanded;

  SettingsState({
    required this.rpcUrl,
    required this.useBiometrics,
    required this.goHomeOnSwitch,
    this.developerExpanded,
  });

  SettingsState copyWith({
    String? rpcUrl,
    bool? useBiometrics,
    bool? goHomeOnSwitch,
    bool? developerExpanded,
  }) {
    return SettingsState(
      rpcUrl: rpcUrl ?? this.rpcUrl,
      useBiometrics: useBiometrics ?? this.useBiometrics,
      goHomeOnSwitch: goHomeOnSwitch ?? this.goHomeOnSwitch,
      developerExpanded: developerExpanded ?? this.developerExpanded,
    );
  }

  bool get isDeveloperExpanded => developerExpanded ?? false;
  bool get biometricsEnabled => useBiometrics ?? false;
  bool get goHomeEnabled => goHomeOnSwitch ?? true;
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
      developerExpanded: false,
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final rpc = prefs.getString(StorageKeys.rpcUrl) ?? _defaultRpcUrl;
    final biometrics = prefs.getBool(StorageKeys.useBiometrics) ?? false;
    final goHome = prefs.getBool(StorageKeys.goHomeOnSwitch) ?? true;

    state = state.copyWith(
      rpcUrl: rpc,
      useBiometrics: biometrics,
      goHomeOnSwitch: goHome,
      developerExpanded: state.developerExpanded,
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

  void setDeveloperExpanded(bool expanded) {
    state = state.copyWith(developerExpanded: expanded);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
