import 'package:bip39/bip39.dart' as bip39;
import 'package:web3dart/web3dart.dart';
import 'package:hex/hex.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart'
    as ed; // or use web3dart logic
import 'dart:typed_data';
import '../models/account.dart';
import 'secure_storage_service.dart';

class WalletService {
  final SecureStorageService _storageService;

  WalletService(this._storageService);

  Future<Account> createWallet() async {
    // Generate Mnemonic
    String mnemonic = bip39.generateMnemonic();
    return importFromMnemonic(mnemonic);
  }

  Future<Account> importFromMnemonic(String mnemonic) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw Exception("Invalid mnemonic phrase");
    }

    // Seed from mnemonic
    final seed = bip39.mnemonicToSeed(mnemonic);
    // Simple derivation for example purposes (ideally use a BIP44 library for full paths)
    // For now, we take the first 32 bytes of seed as private key
    final privateKey = HEX.encode(seed.sublist(0, 32));

    return importFromPrivateKey(privateKey, mnemonic: mnemonic);
  }

  Future<Account> importFromPrivateKey(
    String privateKey, {
    String mnemonic = '',
  }) async {
    // Ensure PK format
    String cleanPk = privateKey;
    if (cleanPk.startsWith('0x')) {
      cleanPk = cleanPk.substring(2);
    }

    final credentials = EthPrivateKey.fromHex(cleanPk);
    final address = credentials.address.hex;

    // Save to secure storage
    await _storageService.saveAccount(address, cleanPk, mnemonic: mnemonic);

    return Account(address: address, privateKey: cleanPk, mnemonic: mnemonic);
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
