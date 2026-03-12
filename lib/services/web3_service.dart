import 'dart:convert';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import '../models/account.dart';
import '../utils/amount_utils.dart';

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
  static const String _routerLiquidityAbiJson =
      '[{"inputs":[{"internalType":"address","name":"tokenA","type":"address"},{"internalType":"address","name":"tokenB","type":"address"},{"internalType":"uint256","name":"amountADesired","type":"uint256"},{"internalType":"uint256","name":"amountBDesired","type":"uint256"},{"internalType":"uint256","name":"amountAMin","type":"uint256"},{"internalType":"uint256","name":"amountBMin","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"addLiquidity","outputs":[{"internalType":"uint256","name":"amountA","type":"uint256"},{"internalType":"uint256","name":"amountB","type":"uint256"},{"internalType":"uint256","name":"liquidity","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"token","type":"address"},{"internalType":"uint256","name":"amountTokenDesired","type":"uint256"},{"internalType":"uint256","name":"amountTokenMin","type":"uint256"},{"internalType":"uint256","name":"amountETHMin","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"addLiquidityETH","outputs":[{"internalType":"uint256","name":"amountToken","type":"uint256"},{"internalType":"uint256","name":"amountETH","type":"uint256"},{"internalType":"uint256","name":"liquidity","type":"uint256"}],"stateMutability":"payable","type":"function"}]';
  static const String _factoryAbiJson =
      '[{"inputs":[{"internalType":"address","name":"tokenA","type":"address"},{"internalType":"address","name":"tokenB","type":"address"}],"name":"getPair","outputs":[{"internalType":"address","name":"pair","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"tokenA","type":"address"},{"internalType":"address","name":"tokenB","type":"address"}],"name":"createPair","outputs":[{"internalType":"address","name":"pair","type":"address"}],"stateMutability":"nonpayable","type":"function"}]';
  static const String _zeroAddress = '0x0000000000000000000000000000000000000000';

  static const int _erc20TransferGasLimit = 350000;
  static const int _erc20ApproveGasLimit = 450000;
  static const int _swapGasLimit = 2500000;
  static const int _nativeTransferGasLimit = 21000;
  static const int _factoryCreatePairGasLimit = 800000;
  static const int _addLiquidityGasLimit = 2800000;
  static const int _addLiquidityEthGasLimit = 2600000;

  int get nativeTransferGasLimit => _nativeTransferGasLimit;
  int get erc20TransferGasLimit => _erc20TransferGasLimit;
  int get erc20ApproveGasLimit => _erc20ApproveGasLimit;
  int get swapGasLimit => _swapGasLimit;
  int get createPairGasLimit => _factoryCreatePairGasLimit;
  int get addLiquidityGasLimit => _addLiquidityGasLimit;
  int get addLiquidityEthGasLimit => _addLiquidityEthGasLimit;

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
      AmountUtils.parseAmountToRaw(amount, decimals);

  String formatAmountFromRaw(BigInt raw, int decimals) =>
      AmountUtils.formatAmountFromRaw(raw, decimals);

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
      return AmountUtils.formatAmountFromRaw(raw, 18);
    } catch (_) {
      return null;
    }
  }

  Future<String> sendEth(Account account, String to, String amountStr) async {
    try {
      final credentials = EthPrivateKey.fromHex(account.privateKey);
      final wei = AmountUtils.parseAmountToRaw(amountStr, 18);
      final chainId = await _resolveChainId();
      final txHash = await _client.sendTransaction(
        credentials,
        Transaction(
          to: EthereumAddress.fromHex(to),
          value: EtherAmount.inWei(wei),
          maxGas: _nativeTransferGasLimit,
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
      final amountRaw = AmountUtils.parseAmountToRaw(amountStr, decimals);

      final txHash = await _client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract,
          function: transfer,
          parameters: <dynamic>[EthereumAddress.fromHex(to), amountRaw],
          maxGas: _erc20TransferGasLimit,
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
        maxGas: _erc20ApproveGasLimit,
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
        maxGas: _swapGasLimit,
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
        maxGas: _swapGasLimit,
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
        maxGas: _swapGasLimit,
      ),
      chainId: chainId,
    );
  }

  Future<String> getPairAddress({
    required String factoryAddress,
    required String tokenA,
    required String tokenB,
  }) async {
    final factory = DeployedContract(
      ContractAbi.fromJson(_factoryAbiJson, 'ReefswapFactory'),
      EthereumAddress.fromHex(factoryAddress),
    );
    final getPair = factory.function('getPair');
    final response = await _client.call(
      contract: factory,
      function: getPair,
      params: <dynamic>[
        EthereumAddress.fromHex(tokenA),
        EthereumAddress.fromHex(tokenB),
      ],
    );
    if (response.isEmpty) return _zeroAddress;
    final value = response.first;
    if (value is EthereumAddress) return value.hexEip55;
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return _zeroAddress;
  }

  Future<String> createPair({
    required Account account,
    required String factoryAddress,
    required String tokenA,
    required String tokenB,
  }) async {
    final credentials = EthPrivateKey.fromHex(account.privateKey);
    final chainId = await _resolveChainId();
    final factory = DeployedContract(
      ContractAbi.fromJson(_factoryAbiJson, 'ReefswapFactory'),
      EthereumAddress.fromHex(factoryAddress),
    );
    final createPairFn = factory.function('createPair');

    return _client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: factory,
        function: createPairFn,
        parameters: <dynamic>[
          EthereumAddress.fromHex(tokenA),
          EthereumAddress.fromHex(tokenB),
        ],
        maxGas: _factoryCreatePairGasLimit,
      ),
      chainId: chainId,
    );
  }

  Future<String> addLiquidity({
    required Account account,
    required String routerAddress,
    required String tokenA,
    required String tokenB,
    required BigInt amountADesired,
    required BigInt amountBDesired,
    required BigInt amountAMin,
    required BigInt amountBMin,
    required String to,
    required BigInt deadline,
  }) async {
    final credentials = EthPrivateKey.fromHex(account.privateKey);
    final chainId = await _resolveChainId();
    final router = DeployedContract(
      ContractAbi.fromJson(_routerLiquidityAbiJson, 'ReefswapRouterLiquidity'),
      EthereumAddress.fromHex(routerAddress),
    );
    final addLiquidityFn = router.function('addLiquidity');

    return _client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: router,
        function: addLiquidityFn,
        parameters: <dynamic>[
          EthereumAddress.fromHex(tokenA),
          EthereumAddress.fromHex(tokenB),
          amountADesired,
          amountBDesired,
          amountAMin,
          amountBMin,
          EthereumAddress.fromHex(to),
          deadline,
        ],
        maxGas: _addLiquidityGasLimit,
      ),
      chainId: chainId,
    );
  }

  Future<String> addLiquidityEth({
    required Account account,
    required String routerAddress,
    required String tokenAddress,
    required BigInt amountTokenDesired,
    required BigInt amountTokenMin,
    required BigInt amountEthMin,
    required String to,
    required BigInt deadline,
    required BigInt amountEthDesired,
  }) async {
    final credentials = EthPrivateKey.fromHex(account.privateKey);
    final chainId = await _resolveChainId();
    final router = DeployedContract(
      ContractAbi.fromJson(_routerLiquidityAbiJson, 'ReefswapRouterLiquidity'),
      EthereumAddress.fromHex(routerAddress),
    );
    final addLiquidityEthFn = router.function('addLiquidityETH');

    return _client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: router,
        function: addLiquidityEthFn,
        parameters: <dynamic>[
          EthereumAddress.fromHex(tokenAddress),
          amountTokenDesired,
          amountTokenMin,
          amountEthMin,
          EthereumAddress.fromHex(to),
          deadline,
        ],
        value: EtherAmount.inWei(amountEthDesired),
        maxGas: _addLiquidityEthGasLimit,
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
      return AmountUtils.formatAmountFromRaw(balanceVal, decimalsVal);
    } catch (e) {
      print("Error getting ERC20 balance: $e");
      return "0.0";
    }
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

  Future<int> getChainId() => _resolveChainId();

  Future<BigInt> getGasPriceWei() async {
    try {
      final gasPrice = await _client.getGasPrice();
      return gasPrice.getInWei;
    } catch (_) {
      return BigInt.from(1000000000);
    }
  }

  Future<void> waitForReceipt(
    String txHash, {
    Duration timeout = const Duration(minutes: 3),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final started = DateTime.now();
    while (DateTime.now().difference(started) < timeout) {
      final receipt = await _client.getTransactionReceipt(txHash);
      if (receipt != null) return;
      await Future<void>.delayed(pollInterval);
    }
    throw Exception('Timed out waiting for transaction receipt');
  }
}
