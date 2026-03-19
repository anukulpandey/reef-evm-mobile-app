import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/secure_storage_service.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../services/web3_service.dart';
import '../services/pool_service.dart';
import '../services/fcm_service.dart';
import '../services/explorer_service.dart';
import '../services/activity_service.dart';
import '../services/created_token_registry_service.dart';
import '../services/dapp_browser_service.dart';
import '../services/token_creator_service.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final walletServiceProvider = Provider<WalletService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return WalletService(storage);
});

final web3ServiceProvider = Provider<Web3Service>((ref) {
  return Web3Service();
});

final poolServiceProvider = Provider<PoolService>((ref) {
  return PoolService();
});

final explorerServiceProvider = Provider<ExplorerService>((ref) {
  return ExplorerService();
});

final activityServiceProvider = Provider<ActivityService>((ref) {
  return ActivityService();
});

final dappBrowserServiceProvider = Provider<DappBrowserService>((ref) {
  return const DappBrowserService();
});

final fcmServiceProvider = Provider<FCMService>((ref) {
  return FCMService();
});

final createdTokenRegistryServiceProvider =
    Provider<CreatedTokenRegistryService>((ref) {
      return const CreatedTokenRegistryService();
    });

final tokenCreatorServiceProvider = Provider<TokenCreatorService>((ref) {
  final registry = ref.watch(createdTokenRegistryServiceProvider);
  return TokenCreatorService(registry);
});
