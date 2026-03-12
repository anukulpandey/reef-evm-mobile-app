import 'dart:convert';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import '../models/account.dart';
import 'dart:math' as math;

class Web3Service {
  late Web3Client _client;
  final Client _httpClient = Client();
  late String _rpcUrl;

  Web3Service({String rpcUrl = "http://localhost:8545"}) {
    _rpcUrl = rpcUrl;
    _client = Web3Client(rpcUrl, _httpClient);
  }

  void updateRpc(String rpcUrl) {
    _rpcUrl = rpcUrl;
    _client = Web3Client(rpcUrl, _httpClient);
  }

  Future<String> getBalance(String address) async {
    final rpcBalance = await _getBalanceViaRpc(address);
    if (rpcBalance != null) return rpcBalance;

    try {
      final balance = await _client.getBalance(
        EthereumAddress.fromHex(address),
      );
      return balance.getValueInUnit(EtherUnit.ether).toString();
    } catch (e) {
      print("Error getting balance: $e");
      return "0.0";
    }
  }

  Future<String?> _getBalanceViaRpc(String address) async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse(_rpcUrl),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'eth_getBalance',
              'params': [address, 'latest'],
              'id': 1,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) return null;
      final result = payload['result'];
      if (result is! String || result.trim().isEmpty) return null;
      final hex = result.trim();
      final normalized = hex.startsWith('0x') ? hex.substring(2) : hex;
      if (normalized.isEmpty) return '0';
      final raw = BigInt.tryParse(normalized, radix: 16);
      if (raw == null) return null;
      return _formatTokenAmount(raw, 18);
    } catch (_) {
      return null;
    }
  }

  Future<String> sendEth(Account account, String to, String amountStr) async {
    try {
      final credentials = EthPrivateKey.fromHex(account.privateKey);
      final wei = _parseAmountToRaw(amountStr, 18);
      final txHash = await _client.sendTransaction(
        credentials,
        Transaction(
          to: EthereumAddress.fromHex(to),
          value: EtherAmount.inWei(wei),
        ),
        chainId: null,
      );
      return txHash;
    } catch (e) {
      print("Error sending eth: $e");
      rethrow;
    }
  }

  Future<String> sendErc20({
    required Account account,
    required String tokenAddress,
    required String to,
    required String amountStr,
    required int decimals,
  }) async {
    try {
      final credentials = EthPrivateKey.fromHex(account.privateKey);
      final contract = DeployedContract(
        ContractAbi.fromJson(
          '[{"constant":false,"inputs":[{"name":"to","type":"address"},{"name":"value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}]',
          'ERC20',
        ),
        EthereumAddress.fromHex(tokenAddress),
      );
      final transfer = contract.function('transfer');
      final amountRaw = _parseAmountToRaw(amountStr, decimals);

      final txHash = await _client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract,
          function: transfer,
          parameters: <dynamic>[EthereumAddress.fromHex(to), amountRaw],
        ),
        chainId: null,
      );
      return txHash;
    } catch (e) {
      print("Error sending ERC20: $e");
      rethrow;
    }
  }

  Future<String> getERC20Balance(
    String accountAddress,
    String tokenAddress, {
    int? decimalsHint,
  }) async {
    try {
      final contract = DeployedContract(
        ContractAbi.fromJson(
          '[{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"payable":false,"type":"function"}]',
          'ERC20',
        ),
        EthereumAddress.fromHex(tokenAddress),
      );

      final balanceFunction = contract.function('balanceOf');
      final decimalsFunction = contract.function('decimals');

      final balance = await _client.call(
        contract: contract,
        function: balanceFunction,
        params: [EthereumAddress.fromHex(accountAddress)],
      );

      int decimalsVal;
      if (decimalsHint != null) {
        decimalsVal = decimalsHint;
      } else {
        final decimals = await _client.call(
          contract: contract,
          function: decimalsFunction,
          params: [],
        );
        decimalsVal = (decimals.first as BigInt).toInt();
      }

      final BigInt balanceVal = balance.first as BigInt;
      return _formatTokenAmount(balanceVal, decimalsVal);
    } catch (e) {
      print("Error getting ERC20 balance: $e");
      return "0.0";
    }
  }

  static String _formatTokenAmount(BigInt raw, int decimals) {
    if (raw == BigInt.zero) return "0";
    if (decimals <= 0) return raw.toString();

    final divisor = BigInt.from(10).pow(decimals);
    final whole = raw ~/ divisor;
    final fractionRaw = raw
        .remainder(divisor)
        .toString()
        .padLeft(decimals, '0');

    final precision = math.min(6, decimals);
    var fraction = fractionRaw.substring(0, precision);
    fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    if (fraction.isEmpty) return whole.toString();
    return '$whole.$fraction';
  }

  static BigInt _parseAmountToRaw(String amount, int decimals) {
    final normalized = amount.trim().replaceAll(',', '');
    if (normalized.isEmpty) {
      throw Exception('Amount is empty');
    }

    final parts = normalized.split('.');
    if (parts.length > 2) {
      throw Exception('Invalid amount');
    }

    final whole = BigInt.tryParse(parts[0].isEmpty ? '0' : parts[0]);
    if (whole == null) {
      throw Exception('Invalid amount');
    }

    final fractionInput = parts.length == 2 ? parts[1] : '';
    if (!RegExp(r'^\d*$').hasMatch(fractionInput)) {
      throw Exception('Invalid amount');
    }
    final trimmedFraction = fractionInput.length > decimals
        ? fractionInput.substring(0, decimals)
        : fractionInput;
    final paddedFraction = trimmedFraction.padRight(decimals, '0');
    final fraction = paddedFraction.isEmpty
        ? BigInt.zero
        : BigInt.parse(paddedFraction);

    return whole * BigInt.from(10).pow(decimals) + fraction;
  }
}
