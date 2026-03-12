import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account.dart';
import 'service_providers.dart';

class WalletState {
  final Account? activeAccount;
  final String balance;
  final bool isLoading;
  final String? error;
  final bool showBalance;

  WalletState({
    this.activeAccount,
    this.balance = '0.0',
    this.isLoading = false,
    this.error,
    this.showBalance = true,
  });

  WalletState copyWith({
    Account? activeAccount,
    String? balance,
    bool? isLoading,
    String? error,
    bool? showBalance,
  }) {
    return WalletState(
      activeAccount: activeAccount ?? this.activeAccount,
      balance: balance ?? this.balance,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      showBalance: showBalance ?? this.showBalance,
    );
  }
}

class WalletNotifier extends Notifier<WalletState> {
  @override
  WalletState build() {
    // Return initial state immediately
    final initialState = WalletState();
    
    // Trigger async load after first frame or using microtask to avoid circularity
    Future.microtask(() => _loadFirstAccount());
    
    return initialState;
  }

  Future<void> _loadFirstAccount() async {
    state = state.copyWith(isLoading: true);
    final walletService = ref.read(walletServiceProvider);
    final accounts = await walletService.getAccounts();
    
    if (accounts.isNotEmpty) {
      final account = await walletService.loadAccount(accounts.first);
      if (account != null) {
        state = state.copyWith(activeAccount: account, isLoading: false);
        await refreshBalance();
      } else {
        state = state.copyWith(isLoading: false);
      }
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refreshBalance() async {
    if (state.activeAccount == null) return;
    
    final web3Service = ref.read(web3ServiceProvider);
    final balance = await web3Service.getBalance(state.activeAccount!.address);
    state = state.copyWith(balance: balance);
  }

  void toggleBalanceVisibility() {
    state = state.copyWith(showBalance: !state.showBalance);
  }

  Future<void> createAccount() async {
    state = state.copyWith(isLoading: true);
    try {
      final walletService = ref.read(walletServiceProvider);
      final newAccount = await walletService.createWallet();
      state = state.copyWith(activeAccount: newAccount, isLoading: false, balance: '0.0');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> importMnemonic(String mnemonic) async {
    state = state.copyWith(isLoading: true);
    try {
      final walletService = ref.read(walletServiceProvider);
      final newAccount = await walletService.importFromMnemonic(mnemonic);
      state = state.copyWith(activeAccount: newAccount, isLoading: false);
      await refreshBalance();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  
  Future<void> importPrivateKey(String pk) async {
    state = state.copyWith(isLoading: true);
    try {
      final walletService = ref.read(walletServiceProvider);
      final newAccount = await walletService.importFromPrivateKey(pk);
      state = state.copyWith(activeAccount: newAccount, isLoading: false);
      await refreshBalance();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void logout() {
    state = WalletState();
  }
}

final walletProvider = NotifierProvider<WalletNotifier, WalletState>(() {
  return WalletNotifier();
});
