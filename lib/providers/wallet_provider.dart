import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../models/account.dart';
import '../models/token.dart';
import '../services/web3_service.dart';
import '../utils/token_icon_resolver.dart';
import 'service_providers.dart';

class WalletState {
  final Account? activeAccount;
  final String? accountName;
  final String balance;
  final List<Token>? tokens;
  final bool isLoading;
  final String? error;
  final bool showBalance;
  final double portfolioUsd;

  WalletState({
    this.activeAccount,
    this.accountName,
    this.balance = '0.0',
    this.tokens,
    this.isLoading = false,
    this.error,
    this.showBalance = true,
    this.portfolioUsd = 0,
  });

  WalletState copyWith({
    Account? activeAccount,
    String? accountName,
    String? balance,
    List<Token>? tokens,
    bool? isLoading,
    String? error,
    bool? showBalance,
    double? portfolioUsd,
  }) {
    return WalletState(
      activeAccount: activeAccount ?? this.activeAccount,
      accountName: accountName ?? this.accountName,
      balance: balance ?? this.balance,
      tokens: tokens ?? this.tokens ?? const <Token>[],
      isLoading: isLoading ?? this.isLoading,
      error: error,
      showBalance: showBalance ?? this.showBalance,
      portfolioUsd: portfolioUsd ?? this.portfolioUsd,
    );
  }

  String get displayAccountName {
    final value = accountName?.trim() ?? '';
    final hasCustomName = value.isNotEmpty && value != '<No Name>';
    if (hasCustomName) return value;

    final address = activeAccount?.address ?? '';
    if (address.length >= 10) {
      return '${address.substring(0, 4)}...${address.substring(address.length - 4)}';
    }
    return value.isEmpty ? '<No Name>' : value;
  }

  List<Token> get portfolioTokens => tokens ?? const <Token>[];
}

class WalletNotifier extends Notifier<WalletState> {
  Timer? _refreshTimer;

  @override
  WalletState build() {
    // Return initial state immediately
    final initialState = WalletState();

    ref.onDispose(() {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    });

    // Trigger async load after first frame or using microtask to avoid circularity
    Future.microtask(() => _loadFirstAccount());

    return initialState;
  }

  Future<void> _loadFirstAccount() async {
    state = state.copyWith(isLoading: true);
    final walletService = ref.read(walletServiceProvider);
    final accounts = await walletService.getAccounts();

    if (accounts.isNotEmpty) {
      final lastActive = await walletService.getLastActiveAccount();
      final preferredAddress =
          lastActive != null && accounts.contains(lastActive)
          ? lastActive
          : accounts.first;
      final account = await walletService.loadAccount(preferredAddress);
      if (account != null) {
        final savedName = await walletService.getAccountName(account.address);
        state = state.copyWith(
          activeAccount: account,
          accountName: savedName ?? '<No Name>',
          isLoading: false,
          tokens: const <Token>[],
        );
        await walletService.setLastActiveAccount(account.address);
        _ensureAutoRefresh();
        await refreshPortfolio();
      } else {
        state = state.copyWith(isLoading: false);
      }
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refreshBalance() async {
    await refreshPortfolio();
  }

  Future<void> refreshPortfolio() async {
    if (state.activeAccount == null) return;

    final web3Service = ref.read(web3ServiceProvider);
    final explorerService = ref.read(explorerServiceProvider);
    final poolService = ref.read(poolServiceProvider);
    final accountAddress = state.activeAccount!.address;

    try {
      final rpcBalanceFuture = web3Service.getBalance(accountAddress);
      final explorerNativeFuture = explorerService.fetchNativeBalanceForAddress(
        accountAddress,
      );
      final reefUsdFuture = poolService.getReefUsdPrice();
      final tokenUsdFuture = poolService.getTokenUsdPrices();
      final explorerBalances = await explorerService.fetchErc20TokensForAddress(
        accountAddress,
      );
      List<Token> erc20Tokens = explorerBalances;

      // Fallback only when explorer wallet token balances are unavailable.
      if (erc20Tokens.isEmpty) {
        final tokenCatalog = await explorerService.fetchAllErc20Tokens();
        erc20Tokens = await _buildErc20Portfolio(
          accountAddress: accountAddress,
          web3Service: web3Service,
          tokenCatalog: tokenCatalog,
        );
      } else {
        // Explorer can lag indexing; hydrate discovered tokens from on-chain balanceOf.
        erc20Tokens = await _buildErc20Portfolio(
          accountAddress: accountAddress,
          web3Service: web3Service,
          tokenCatalog: erc20Tokens,
        );
      }

      final rpcBalance = await rpcBalanceFuture;
      final explorerNativeBalance = await explorerNativeFuture;
      final balance = _pickBestNativeBalance(
        rpcBalance: rpcBalance,
        explorerBalance: explorerNativeBalance,
      );
      final reefUsd = await reefUsdFuture;
      final tokenUsd = await tokenUsdFuture;

      final allTokens =
          <Token>[
                Token(
                  symbol: 'REEF',
                  name: 'Reef',
                  decimals: 18,
                  balance: balance,
                  address: 'native',
                  iconUrl: TokenIconResolver.resolveTokenIconUrl(
                    symbol: 'REEF',
                  ),
                  usdPrice: reefUsd,
                  usdValue: _safeDouble(balance) * reefUsd,
                ),
                ...erc20Tokens,
              ]
              .map(
                (token) => _decorateTokenWithUsd(
                  token: token,
                  reefUsd: reefUsd,
                  tokenUsdByAddress: tokenUsd,
                ),
              )
              .where((token) => _hasPositiveBalance(token.balance))
              .toList();

      final totalUsd = allTokens.fold<double>(
        0,
        (sum, token) => sum + (token.usdValue ?? 0),
      );

      state = state.copyWith(
        balance: balance,
        tokens: allTokens,
        portfolioUsd: totalUsd,
        error: null,
      );
    } catch (e) {
      print('Error refreshing portfolio: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  void _ensureAutoRefresh() {
    _refreshTimer ??= Timer.periodic(const Duration(seconds: 20), (_) {
      if (state.activeAccount == null) return;
      refreshPortfolio();
    });
  }

  Future<List<Token>> _buildErc20Portfolio({
    required String accountAddress,
    required Web3Service web3Service,
    required List<Token> tokenCatalog,
  }) async {
    final byAddress = <String, Token>{
      for (final token in tokenCatalog) token.address.toLowerCase(): token,
    };

    final tokens = byAddress.values.toList();
    if (tokens.isEmpty) return const <Token>[];

    final hydrated = await Future.wait(
      tokens.map((token) async {
        final chainBalance = await web3Service.getERC20Balance(
          accountAddress,
          token.address,
          decimalsHint: token.decimals,
        );
        final effectiveBalance = _hasPositiveBalance(chainBalance)
            ? chainBalance
            : token.balance;
        return Token(
          symbol: token.symbol,
          name: token.name,
          decimals: token.decimals,
          balance: effectiveBalance,
          address: token.address,
          iconUrl: token.iconUrl,
        );
      }),
    );

    hydrated.sort((a, b) {
      final aVal = double.tryParse(a.balance) ?? 0;
      final bVal = double.tryParse(b.balance) ?? 0;
      if (aVal != bVal) return bVal.compareTo(aVal);
      return a.symbol.compareTo(b.symbol);
    });
    return hydrated
        .where((token) => _hasPositiveBalance(token.balance))
        .toList();
  }

  static bool _hasPositiveBalance(String value) {
    final normalized = value.trim().replaceAll(',', '');
    if (normalized.isEmpty) return false;
    final parsed = double.tryParse(normalized);
    if (parsed == null) return false;
    return parsed > 0;
  }

  static double _safeDouble(String value) {
    final normalized = value.trim().replaceAll(',', '');
    return double.tryParse(normalized) ?? 0;
  }

  static String _pickBestNativeBalance({
    required String rpcBalance,
    required String? explorerBalance,
  }) {
    final rpc = _safeDouble(rpcBalance);
    final explorer = _safeDouble(explorerBalance ?? '0');

    if (explorer > 0 && rpc <= 0) return explorerBalance!;
    if (rpc > 0 && explorer <= 0) return rpcBalance;
    if (explorer > rpc) return explorerBalance ?? rpcBalance;
    return rpcBalance;
  }

  Token _decorateTokenWithUsd({
    required Token token,
    required double reefUsd,
    required Map<String, double> tokenUsdByAddress,
  }) {
    final isReefLike =
        token.address == 'native' ||
        token.symbol.toUpperCase() == 'REEF' ||
        token.symbol.toUpperCase() == 'WREEF';

    final usdPrice = isReefLike
        ? reefUsd
        : (tokenUsdByAddress[token.address.toLowerCase()] ?? 0);
    final usdValue = _safeDouble(token.balance) * usdPrice;
    return token.copyWith(usdPrice: usdPrice, usdValue: usdValue);
  }

  void toggleBalanceVisibility() {
    state = state.copyWith(showBalance: !state.showBalance);
  }

  Future<Account?> createAccount() async {
    state = state.copyWith(isLoading: true);
    try {
      final walletService = ref.read(walletServiceProvider);
      final newAccount = await walletService.createWallet();
      state = state.copyWith(
        activeAccount: newAccount,
        accountName: '<No Name>',
        isLoading: false,
        balance: '0.0',
        tokens: const <Token>[],
      );
      await walletService.setLastActiveAccount(newAccount.address);
      await refreshPortfolio();
      return newAccount;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> importMnemonic(String mnemonic) async {
    state = state.copyWith(isLoading: true);
    try {
      final walletService = ref.read(walletServiceProvider);
      final newAccount = await walletService.importFromMnemonic(mnemonic);
      final savedName = await walletService.getAccountName(newAccount.address);
      state = state.copyWith(
        activeAccount: newAccount,
        accountName: savedName ?? '<No Name>',
        isLoading: false,
        tokens: const <Token>[],
      );
      await walletService.setLastActiveAccount(newAccount.address);
      await refreshPortfolio();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> importPrivateKey(String pk) async {
    state = state.copyWith(isLoading: true);
    try {
      final walletService = ref.read(walletServiceProvider);
      final newAccount = await walletService.importFromPrivateKey(pk);
      final savedName = await walletService.getAccountName(newAccount.address);
      state = state.copyWith(
        activeAccount: newAccount,
        accountName: savedName ?? '<No Name>',
        isLoading: false,
        tokens: const <Token>[],
      );
      await walletService.setLastActiveAccount(newAccount.address);
      await refreshPortfolio();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void logout() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    state = WalletState();
  }

  Future<void> setAccountName(String name) async {
    final trimmed = name.trim();
    final value = trimmed.isEmpty ? '<No Name>' : trimmed;
    final activeAddress = state.activeAccount?.address;
    if (activeAddress != null) {
      final walletService = ref.read(walletServiceProvider);
      await walletService.saveAccountName(activeAddress, value);
    }
    state = state.copyWith(accountName: value);
  }

  Future<void> selectAccount(String address) async {
    final normalized = address.trim();
    if (normalized.isEmpty) return;

    final current = state.activeAccount?.address.toLowerCase();
    if (current == normalized.toLowerCase()) return;

    final walletService = ref.read(walletServiceProvider);
    final account = await walletService.loadAccount(normalized);
    if (account == null) {
      throw Exception('Account not found');
    }
    final savedName = await walletService.getAccountName(account.address);
    state = state.copyWith(
      activeAccount: account,
      accountName: savedName ?? '<No Name>',
      isLoading: false,
      tokens: const <Token>[],
      error: null,
    );
    await walletService.setLastActiveAccount(account.address);
    _ensureAutoRefresh();
    await refreshPortfolio();
  }

  Future<void> deleteAccount(String address) async {
    final normalized = address.trim();
    if (normalized.isEmpty) return;

    final walletService = ref.read(walletServiceProvider);
    await walletService.clearAccount(normalized);

    final wasActive =
        state.activeAccount?.address.toLowerCase() == normalized.toLowerCase();
    if (!wasActive) {
      // Trigger rebuild so account lists refresh.
      state = state.copyWith(error: null);
      return;
    }

    final remaining = await walletService.getAccounts();
    if (remaining.isEmpty) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      state = WalletState();
      return;
    }

    final nextAddress = remaining.first;
    final nextAccount = await walletService.loadAccount(nextAddress);
    if (nextAccount == null) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      state = WalletState();
      return;
    }

    final nextName = await walletService.getAccountName(nextAccount.address);
    state = state.copyWith(
      activeAccount: nextAccount,
      accountName: nextName ?? '<No Name>',
      balance: '0.0',
      tokens: const <Token>[],
      isLoading: false,
      error: null,
    );
    await walletService.setLastActiveAccount(nextAccount.address);
    _ensureAutoRefresh();
    await refreshPortfolio();
  }

  Future<String> transferToken({
    required Token token,
    required String to,
    required String amount,
  }) async {
    final account = state.activeAccount;
    if (account == null) {
      throw Exception('No active account selected');
    }

    final authService = ref.read(authServiceProvider);
    final authorized = await authService.authenticateForTransaction(
      localizedReason: 'Authenticate to send this transaction',
    );
    if (!authorized) {
      throw Exception('Biometric authentication failed');
    }

    final web3Service = ref.read(web3ServiceProvider);
    state = state.copyWith(isLoading: true, error: null);
    try {
      final isNative =
          token.address == 'native' ||
          token.symbol.toUpperCase() == 'REEF' ||
          token.symbol.toUpperCase() == 'WREEF';

      final txHash = isNative
          ? await web3Service.sendEth(account, to, amount)
          : await web3Service.sendErc20(
              account: account,
              tokenAddress: token.address,
              to: to,
              amountStr: amount,
              decimals: token.decimals,
            );

      await refreshPortfolio();
      state = state.copyWith(isLoading: false);
      return txHash;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final walletProvider = NotifierProvider<WalletNotifier, WalletState>(() {
  return WalletNotifier();
});
