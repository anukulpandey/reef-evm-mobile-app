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

  static const String _erc20AllowanceAbiJson =
      '[{"constant":true,"inputs":[{"name":"owner","type":"address"},{"name":"spender","type":"address"}],"name":"allowance","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"spender","type":"address"},{"name":"value","type":"uint256"}],"name":"approve","outputs":[{"name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}]';

  static const String _routerAbiJson =
      '[{"inputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"}],"name":"getAmountsOut","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountOutMin","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"swapExactETHForTokens","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"payable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"},{"internalType":"uint256","name":"amountOutMin","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"swapExactTokensForETH","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"},{"internalType":"uint256","name":"amountOutMin","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"swapExactTokensForTokens","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"nonpayable","type":"function"}]';

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

  BigInt parseAmountToRaw(String amount, int decimals) =>
      _parseAmountToRaw(amount, decimals);

  String formatAmountFromRaw(BigInt raw, int decimals) =>
      _formatTokenAmount(raw, decimals);

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
      final chainId = await _resolveChainId();
      final txHash = await _client.sendTransaction(
        credentials,
        Transaction(
          to: EthereumAddress.fromHex(to),
          value: EtherAmount.inWei(wei),
        ),
        chainId: chainId,
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
      final chainId = await _resolveChainId();
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
        chainId: chainId,
      );
      return txHash;
    } catch (e) {
      print("Error sending ERC20: $e");
      rethrow;
    }
  }

  Future<BigInt> getAmountsOut({
    required String routerAddress,
    required BigInt amountIn,
    required List<String> path,
  }) async {
    if (amountIn <= BigInt.zero) return BigInt.zero;
    if (path.length < 2) {
      throw Exception('Swap path must contain at least 2 tokens');
    }

    final contract = DeployedContract(
      ContractAbi.fromJson(_routerAbiJson, 'ReefswapRouter'),
      EthereumAddress.fromHex(routerAddress),
    );
    final function = contract.function('getAmountsOut');
    final amountPath = await _client.call(
      contract: contract,
      function: function,
      params: <dynamic>[amountIn, path.map(EthereumAddress.fromHex).toList()],
    );
    if (amountPath.isEmpty) return BigInt.zero;
    final values = amountPath.first;
    if (values is! List || values.isEmpty) return BigInt.zero;
    final last = values.last;
    return last is BigInt ? last : BigInt.zero;
  }

  Future<BigInt> getErc20Allowance({
    required String tokenAddress,
    required String owner,
    required String spender,
  }) async {
    try {
      final contract = DeployedContract(
        ContractAbi.fromJson(_erc20AllowanceAbiJson, 'ERC20Allowance'),
        EthereumAddress.fromHex(tokenAddress),
      );
      final function = contract.function('allowance');
      final response = await _client.call(
        contract: contract,
        function: function,
        params: <dynamic>[
          EthereumAddress.fromHex(owner),
          EthereumAddress.fromHex(spender),
        ],
      );
      if (response.isEmpty || response.first is! BigInt) return BigInt.zero;
      return response.first as BigInt;
    } catch (e) {
      print('Error getting allowance: $e');
      return BigInt.zero;
    }
  }

  Future<String> approveErc20({
    required Account account,
    required String tokenAddress,
    required String spender,
    required BigInt amount,
  }) async {
    final credentials = EthPrivateKey.fromHex(account.privateKey);
    final chainId = await _resolveChainId();
    final contract = DeployedContract(
      ContractAbi.fromJson(_erc20AllowanceAbiJson, 'ERC20Allowance'),
      EthereumAddress.fromHex(tokenAddress),
    );
    final approve = contract.function('approve');

    return _client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: contract,
        function: approve,
        parameters: <dynamic>[EthereumAddress.fromHex(spender), amount],
      ),
      chainId: chainId,
    );
  }

  Future<String> swapExactEthForTokens({
    required Account account,
    required String routerAddress,
    required BigInt amountInWei,
    required BigInt amountOutMin,
    required List<String> path,
    required String to,
    required BigInt deadline,
  }) async {
    final credentials = EthPrivateKey.fromHex(account.privateKey);
    final chainId = await _resolveChainId();
    final contract = DeployedContract(
      ContractAbi.fromJson(_routerAbiJson, 'ReefswapRouter'),
      EthereumAddress.fromHex(routerAddress),
    );
    final swap = contract.function('swapExactETHForTokens');

    return _client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: contract,
        function: swap,
        parameters: <dynamic>[
          amountOutMin,
          path.map(EthereumAddress.fromHex).toList(),
          EthereumAddress.fromHex(to),
          deadline,
        ],
        value: EtherAmount.inWei(amountInWei),
      ),
      chainId: chainId,
    );
  }

  Future<String> swapExactTokensForEth({
    required Account account,
    required String routerAddress,
    required BigInt amountIn,
    required BigInt amountOutMin,
    required List<String> path,
    required String to,
    required BigInt deadline,
  }) async {
    final credentials = EthPrivateKey.fromHex(account.privateKey);
    final chainId = await _resolveChainId();
    final contract = DeployedContract(
      ContractAbi.fromJson(_routerAbiJson, 'ReefswapRouter'),
      EthereumAddress.fromHex(routerAddress),
    );
    final swap = contract.function('swapExactTokensForETH');

    return _client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: contract,
        function: swap,
        parameters: <dynamic>[
          amountIn,
          amountOutMin,
          path.map(EthereumAddress.fromHex).toList(),
          EthereumAddress.fromHex(to),
          deadline,
        ],
      ),
      chainId: chainId,
    );
  }

  Future<String> swapExactTokensForTokens({
    required Account account,
    required String routerAddress,
    required BigInt amountIn,
    required BigInt amountOutMin,
    required List<String> path,
    required String to,
    required BigInt deadline,
  }) async {
    final credentials = EthPrivateKey.fromHex(account.privateKey);
    final chainId = await _resolveChainId();
    final contract = DeployedContract(
      ContractAbi.fromJson(_routerAbiJson, 'ReefswapRouter'),
      EthereumAddress.fromHex(routerAddress),
    );
    final swap = contract.function('swapExactTokensForTokens');

    return _client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: contract,
        function: swap,
        parameters: <dynamic>[
          amountIn,
          amountOutMin,
          path.map(EthereumAddress.fromHex).toList(),
          EthereumAddress.fromHex(to),
          deadline,
        ],
      ),
      chainId: chainId,
    );
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

  Future<int> _resolveChainId() async {
    try {
      final response = await _httpClient.post(
        Uri.parse(_rpcUrl),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'eth_chainId',
          'params': <dynamic>[],
          'id': 1,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = jsonDecode(response.body);
        if (payload is Map<String, dynamic>) {
          final result = payload['result'];
          if (result is String && result.trim().isNotEmpty) {
            final text = result.trim();
            if (text.startsWith('0x')) {
              return int.parse(text.substring(2), radix: 16);
            }
            return int.parse(text);
          }
        }
      }
    } catch (_) {
      // Fall through to net_version below.
    }

    try {
      return await _client.getNetworkId();
    } catch (_) {
      // Default Ethereum mainnet ID only as last fallback.
      return 1;
    }
  }
}
