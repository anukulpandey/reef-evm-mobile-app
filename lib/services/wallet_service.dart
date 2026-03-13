import 'package:bip39/bip39.dart' as bip39;
import 'package:web3dart/web3dart.dart';
import 'package:hex/hex.dart';
import '../models/account.dart';
import 'secure_storage_service.dart';

class WalletService {
  final SecureStorageService _storageService;

  WalletService(this._storageService);

  Future<Account> createWallet() async {
    final draft = await createWalletDraft();
    await persistAccount(draft);
    return draft;
  }

  Future<Account> createWalletDraft() async {
    final mnemonic = bip39.generateMnemonic();
    return deriveAccountFromMnemonic(mnemonic);
  }

  Future<Account> importFromMnemonic(String mnemonic) async {
    final account = deriveAccountFromMnemonic(mnemonic);
    await persistAccount(account);
    return account;
  }

  Account deriveAccountFromMnemonic(String mnemonic) {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw Exception("Invalid mnemonic phrase");
    }

    final seed = bip39.mnemonicToSeed(mnemonic);
    final privateKey = HEX.encode(seed.sublist(0, 32));
    return deriveAccountFromPrivateKey(privateKey, mnemonic: mnemonic);
  }

  Future<Account> importFromPrivateKey(
    String privateKey, {
    String mnemonic = '',
  }) async {
    final account = deriveAccountFromPrivateKey(privateKey, mnemonic: mnemonic);
    await persistAccount(account);
    return account;
  }

  Account deriveAccountFromPrivateKey(
    String privateKey, {
    String mnemonic = '',
  }) {
    final cleanPk = normalizePrivateKey(privateKey);
    final credentials = EthPrivateKey.fromHex(cleanPk);
    final address = credentials.address.hex;
    return Account(address: address, privateKey: cleanPk, mnemonic: mnemonic);
  }

  Future<void> persistAccount(Account account, {String? name}) async {
    await _storageService.saveAccount(
      account.address,
      account.privateKey,
      mnemonic: account.mnemonic,
    );
    final trimmedName = name?.trim() ?? '';
    if (trimmedName.isNotEmpty) {
      await _storageService.saveAccountName(account.address, trimmedName);
    }
  }

  String normalizePrivateKey(String privateKey) {
    var cleanPk = privateKey.trim();
    if (cleanPk.startsWith('0x')) {
      cleanPk = cleanPk.substring(2);
    }
    return cleanPk;
  }

  Future<List<String>> getAccounts() async {
    return await _storageService.getAccounts();
  }

  Future<Account?> loadAccount(String address) async {
    final pk = await _storageService.getPrivateKey(address);
    if (pk == null) return null;

    final mn = await _storageService.getMnemonic(address);
    return Account(address: address, privateKey: pk, mnemonic: mn ?? '');
  }

  Future<void> saveAccountName(String address, String name) async {
    await _storageService.saveAccountName(address, name);
  }

  Future<String?> getAccountName(String address) async {
    return _storageService.getAccountName(address);
  }

  Future<void> setLastActiveAccount(String address) async {
    await _storageService.setLastActiveAccount(address);
  }

  Future<String?> getLastActiveAccount() async {
    return _storageService.getLastActiveAccount();
  }

  Future<void> clearAccount(String address) async {
    await _storageService.clearAccount(address);
  }
}
