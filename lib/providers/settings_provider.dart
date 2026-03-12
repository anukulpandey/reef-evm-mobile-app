import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'service_providers.dart';

class SettingsState {
  final String rpcUrl;
  final bool useBiometrics;

  SettingsState({
    required this.rpcUrl,
    required this.useBiometrics,
  });

  SettingsState copyWith({
    String? rpcUrl,
    bool? useBiometrics,
  }) {
    return SettingsState(
      rpcUrl: rpcUrl ?? this.rpcUrl,
      useBiometrics: useBiometrics ?? this.useBiometrics,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    // Initial state
    Future.microtask(() => _loadSettings());
    return SettingsState(rpcUrl: 'http://localhost:8545', useBiometrics: false);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final rpc = prefs.getString('rpc_url') ?? 'http://localhost:8545';
    final biometrics = prefs.getBool('use_biometrics') ?? false;
    
    state = state.copyWith(rpcUrl: rpc, useBiometrics: biometrics);
    
    // Update Web3 Service
    ref.read(web3ServiceProvider).updateRpc(rpc);
  }

  Future<void> setRpcUrl(String rpcUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rpc_url', rpcUrl);
    state = state.copyWith(rpcUrl: rpcUrl);
    
    // Update Web3 Service
    ref.read(web3ServiceProvider).updateRpc(rpcUrl);
  }

  Future<void> setBiometrics(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_biometrics', enabled);
    state = state.copyWith(useBiometrics: enabled);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
