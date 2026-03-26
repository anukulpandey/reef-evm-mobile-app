import 'dart:convert';
import 'dart:typed_data';
import 'package:eth_sig_util/eth_sig_util.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/json_rpc.dart';
import 'package:web3dart/crypto.dart' show bytesToHex, hexToBytes;
import 'package:http/http.dart';
import '../core/config/dex_config.dart';
import '../models/account.dart';
import '../models/dapp_transaction_request.dart';
import '../utils/amount_utils.dart';
import '../utils/transaction_error_mapper.dart';

class ContractCodeRejectedException implements Exception {
  const ContractCodeRejectedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class Eip1559FeeSettings {
  const Eip1559FeeSettings({
    required this.maxPriorityFeePerGasWei,
    required this.maxFeePerGasWei,
  });

  final BigInt maxPriorityFeePerGasWei;
  final BigInt maxFeePerGasWei;
}

class Web3Service {
  static final BigInt _minimumGasPriceWei = BigInt.from(1000);
  static final BigInt _minimumPriorityFeeWei = BigInt.from(200);
  static const String defaultRpcUrl = String.fromEnvironment(
    'REEF_RPC_URL',
    defaultValue: 'http://localhost:8545',
  );
  static const bool forceRpcFromEnv = bool.fromEnvironment(
    'FORCE_RPC_FROM_ENV',
    defaultValue: false,
  );

  late Web3Client _client;
  final Client _httpClient = Client();
  late String _rpcUrl;

  Web3Service({String? rpcUrl}) {
    _rpcUrl = rpcUrl ?? defaultRpcUrl;
    _client = Web3Client(_rpcUrl, _httpClient);
  }

  void updateRpc(String rpcUrl) {
    _rpcUrl = rpcUrl;
    _client = Web3Client(rpcUrl, _httpClient);
  }

  static const String _erc20AllowanceAbiJson =
      '[{"constant":true,"inputs":[{"name":"owner","type":"address"},{"name":"spender","type":"address"}],"name":"allowance","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"spender","type":"address"},{"name":"value","type":"uint256"}],"name":"approve","outputs":[{"name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}]';
  static const String _erc20TransferAbiJson =
      '[{"constant":false,"inputs":[{"name":"to","type":"address"},{"name":"value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"stateMutability":"view","type":"function"}]';
  static const String _wrappedNativeAbiJson =
      '[{"inputs":[],"name":"deposit","outputs":[],"stateMutability":"payable","type":"function"}]';
  static const String _pairAbiJson =
      '[{"inputs":[],"name":"getReserves","outputs":[{"internalType":"uint112","name":"reserve0","type":"uint112"},{"internalType":"uint112","name":"reserve1","type":"uint112"},{"internalType":"uint32","name":"blockTimestampLast","type":"uint32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"amount0Out","type":"uint256"},{"internalType":"uint256","name":"amount1Out","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"bytes","name":"data","type":"bytes"}],"name":"swap","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"to","type":"address"}],"name":"mint","outputs":[{"internalType":"uint256","name":"liquidity","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}]';

  static const String _routerAbiJson =
      '[{"inputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"}],"name":"getAmountsOut","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountOutMin","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"swapExactETHForTokens","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"payable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"},{"internalType":"uint256","name":"amountOutMin","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"swapExactTokensForETH","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"},{"internalType":"uint256","name":"amountOutMin","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"swapExactTokensForTokens","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"nonpayable","type":"function"}]';
  static const String _routerLiquidityAbiJson =
      '[{"inputs":[{"internalType":"address","name":"tokenA","type":"address"},{"internalType":"address","name":"tokenB","type":"address"},{"internalType":"uint256","name":"amountADesired","type":"uint256"},{"internalType":"uint256","name":"amountBDesired","type":"uint256"},{"internalType":"uint256","name":"amountAMin","type":"uint256"},{"internalType":"uint256","name":"amountBMin","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"addLiquidity","outputs":[{"internalType":"uint256","name":"amountA","type":"uint256"},{"internalType":"uint256","name":"amountB","type":"uint256"},{"internalType":"uint256","name":"liquidity","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"token","type":"address"},{"internalType":"uint256","name":"amountTokenDesired","type":"uint256"},{"internalType":"uint256","name":"amountTokenMin","type":"uint256"},{"internalType":"uint256","name":"amountETHMin","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"addLiquidityETH","outputs":[{"internalType":"uint256","name":"amountToken","type":"uint256"},{"internalType":"uint256","name":"amountETH","type":"uint256"},{"internalType":"uint256","name":"liquidity","type":"uint256"}],"stateMutability":"payable","type":"function"}]';
  static const String _factoryAbiJson =
      '[{"inputs":[{"internalType":"address","name":"tokenA","type":"address"},{"internalType":"address","name":"tokenB","type":"address"}],"name":"getPair","outputs":[{"internalType":"address","name":"pair","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"tokenA","type":"address"},{"internalType":"address","name":"tokenB","type":"address"}],"name":"createPair","outputs":[{"internalType":"address","name":"pair","type":"address"}],"stateMutability":"nonpayable","type":"function"}]';
  static const String _zeroAddress =
      '0x0000000000000000000000000000000000000000';

  static const int _erc20TransferGasLimit = 350000;
  static const int _erc20ApproveGasLimit = 450000;
  static const int _swapGasLimit = 2500000;
  static const int _nativeTransferGasLimit = 21000;
  static const int _factoryCreatePairGasLimit = 800000;
  static const int _addLiquidityGasLimit = 2800000;
  static const int _addLiquidityEthGasLimit = 2600000;
  static const int _wrapNativeGasLimit = 350000;
  static const int _pairMintGasLimit = 900000;
  static const int _pairSwapGasLimit = 1200000;
  static const int _contractDeployGasLimit = 4500000;
  int get nativeTransferGasLimit => _nativeTransferGasLimit;
  int get erc20TransferGasLimit => _erc20TransferGasLimit;
  int get erc20ApproveGasLimit => _erc20ApproveGasLimit;
  int get swapGasLimit => _swapGasLimit;
  int get createPairGasLimit => _factoryCreatePairGasLimit;
  int get addLiquidityGasLimit => _addLiquidityGasLimit;
  int get addLiquidityEthGasLimit => _addLiquidityEthGasLimit;
  int get wrapNativeGasLimit => _wrapNativeGasLimit;
  int get pairMintGasLimit => _pairMintGasLimit;
  int get pairSwapGasLimit => _pairSwapGasLimit;
  int get contractDeployGasLimit => _contractDeployGasLimit;

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
    final wei = AmountUtils.parseAmountToRaw(amountStr, 18);
    final toAddress = _parseAddressOrThrow(to, field: 'recipient');
    final tx = Transaction(
      to: toAddress,
      value: EtherAmount.inWei(wei),
      maxGas: _nativeTransferGasLimit,
    );
    return _signAndBroadcast(
      account: account,
      transaction: tx,
      contextLabel: 'native_transfer',
      debugExtras: <String, dynamic>{'to': to, 'amount': amountStr},
    );
  }

  Future<int> estimateNativeTransferGasLimit({
    required String fromAddress,
    required String toAddress,
    required BigInt amountWei,
  }) async {
    final sender = _parseAddressOrThrow(fromAddress, field: 'sender');
    final recipient = _parseAddressOrThrow(toAddress, field: 'recipient');
    final gasPriceWei = await getGasPriceWei();
    final tx = Transaction(
      from: sender,
      to: recipient,
      value: EtherAmount.inWei(amountWei),
      gasPrice: EtherAmount.inWei(gasPriceWei),
      maxGas: _nativeTransferGasLimit,
    );
    return _resolveGasLimit(
      tx,
      sender,
      contextLabel: 'native_transfer/preview',
    );
  }

  Future<String> sendErc20({
    required Account account,
    required String tokenAddress,
    required String to,
    required String amountStr,
    required int decimals,
  }) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(_erc20TransferAbiJson, 'ERC20'),
      _parseAddressOrThrow(tokenAddress, field: 'token'),
    );
    final transfer = contract.function('transfer');
    final amountRaw = AmountUtils.parseAmountToRaw(amountStr, decimals);
    final toAddress = _parseAddressOrThrow(to, field: 'recipient');

    final tx = Transaction.callContract(
      contract: contract,
      function: transfer,
      parameters: <dynamic>[toAddress, amountRaw],
      maxGas: _erc20TransferGasLimit,
    );
    return _signAndBroadcast(
      account: account,
      transaction: tx,
      contextLabel: 'erc20_transfer',
      debugExtras: <String, dynamic>{
        'tokenAddress': tokenAddress,
        'to': to,
        'amount': amountStr,
        'amountRaw': amountRaw.toString(),
      },
    );
  }

  Future<dynamic> rpcRequest({
    required String method,
    List<dynamic> params = const <dynamic>[],
  }) async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse(_rpcUrl),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': method,
              'params': params,
              'id': 1,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'RPC request failed with status ${response.statusCode}',
        );
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        throw Exception('RPC returned an invalid payload.');
      }

      final error = payload['error'];
      if (error is Map<String, dynamic>) {
        throw RPCError(
          (error['code'] as num?)?.toInt() ?? -32000,
          (error['message'] ?? 'RPC request failed').toString(),
          error['data'],
        );
      }

      return payload['result'];
    } catch (error) {
      if (error is RPCError) rethrow;
      throw Exception('Unable to reach the configured RPC endpoint.');
    }
  }

  Future<int> estimateDappTransactionGasLimit({
    required String fromAddress,
    required DappTransactionRequest request,
  }) async {
    final sender = _parseAddressOrThrow(fromAddress, field: 'sender');
    final fees = _resolveDappFeeSettings(request);
    final transaction = Transaction(
      from: sender,
      to: request.to == null
          ? null
          : _parseAddressOrThrow(request.to!, field: 'recipient'),
      value: EtherAmount.inWei(request.valueWei),
      data: _hexDataToBytes(request.dataHex),
      maxGas: request.gasLimit ?? _contractDeployGasLimit,
      gasPrice: fees.$1,
      maxFeePerGas: fees.$2,
      maxPriorityFeePerGas: fees.$3,
      nonce: request.nonce,
    );
    return _resolveGasLimit(
      transaction,
      sender,
      contextLabel: 'dapp_transaction/preview',
    );
  }

  Future<String> sendDappTransaction({
    required Account account,
    required DappTransactionRequest request,
  }) async {
    final resolvedChainId = await _resolveChainId();
    if (request.chainId != null && request.chainId != resolvedChainId) {
      throw Exception(
        'Requested chain does not match the active Reef network.',
      );
    }

    final fees = _resolveDappFeeSettings(request);
    final transaction = Transaction(
      to: request.to == null
          ? null
          : _parseAddressOrThrow(request.to!, field: 'recipient'),
      value: EtherAmount.inWei(request.valueWei),
      data: _hexDataToBytes(request.dataHex),
      maxGas: request.gasLimit ?? _contractDeployGasLimit,
      gasPrice: fees.$1,
      maxFeePerGas: fees.$2,
      maxPriorityFeePerGas: fees.$3,
      nonce: request.nonce,
    );

    return _signAndBroadcast(
      account: account,
      transaction: transaction,
      contextLabel: 'dapp_transaction',
      respectTransactionFeeFields: true,
      overrideNonce: request.nonce,
      overrideChainId: request.chainId,
      debugExtras: request.toJson(),
    );
  }

  Future<String> signPersonalMessage({
    required Account account,
    required Uint8List payload,
  }) async {
    final chainId = await _resolveChainId();
    final credentials = EthPrivateKey.fromHex(account.privateKey);
    final signature = credentials.signPersonalMessageToUint8List(
      payload,
      chainId: chainId,
    );
    return bytesToHex(signature, include0x: true, padToEvenLength: true);
  }

  Future<String> signRawMessage({
    required Account account,
    required Uint8List payload,
  }) async {
    final chainId = await _resolveChainId();
    final credentials = EthPrivateKey.fromHex(account.privateKey);
    final signature = credentials.signToUint8List(payload, chainId: chainId);
    return bytesToHex(signature, include0x: true, padToEvenLength: true);
  }

  Future<String> signTypedData({
    required Account account,
    required String jsonData,
    required String method,
  }) async {
    final normalizedMethod = method.trim().toLowerCase();
    final version = switch (normalizedMethod) {
      'eth_signtypeddata_v4' => TypedDataVersion.V4,
      'eth_signtypeddata_v3' => TypedDataVersion.V3,
      _ => TypedDataVersion.V1,
    };
    return EthSigUtil.signTypedData(
      privateKey: account.privateKey,
      jsonData: jsonData,
      version: version,
    );
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
    final token = _parseAddressOrThrow(tokenAddress, field: 'token');
    final spenderAddress = _parseAddressOrThrow(spender, field: 'spender');
    final contract = DeployedContract(
      ContractAbi.fromJson(_erc20AllowanceAbiJson, 'ERC20Allowance'),
      token,
    );
    final approve = contract.function('approve');
    final tx = Transaction.callContract(
      contract: contract,
      function: approve,
      parameters: <dynamic>[spenderAddress, amount],
      maxGas: _erc20ApproveGasLimit,
    );
    return _signAndBroadcast(
      account: account,
      transaction: tx,
      contextLabel: 'erc20_approve',
      debugExtras: <String, dynamic>{
        'tokenAddress': tokenAddress,
        'spender': spender,
        'amount': amount.toString(),
      },
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
    final router = _parseAddressOrThrow(routerAddress, field: 'router');
    final toAddress = _parseAddressOrThrow(to, field: 'recipient');
    final parsedPath = path
        .map((entry) => _parseAddressOrThrow(entry, field: 'path token'))
        .toList();
    final contract = DeployedContract(
      ContractAbi.fromJson(_routerAbiJson, 'ReefswapRouter'),
      router,
    );
    final swap = contract.function('swapExactETHForTokens');
    final tx = Transaction.callContract(
      contract: contract,
      function: swap,
      parameters: <dynamic>[amountOutMin, parsedPath, toAddress, deadline],
      value: EtherAmount.inWei(amountInWei),
      maxGas: _swapGasLimit,
    );
    return _signAndBroadcast(
      account: account,
      transaction: tx,
      contextLabel: 'swap_exact_eth_for_tokens',
      debugExtras: <String, dynamic>{
        'routerAddress': routerAddress,
        'amountInWei': amountInWei.toString(),
        'amountOutMin': amountOutMin.toString(),
        'path': path,
        'to': to,
        'deadline': deadline.toString(),
      },
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
    final router = _parseAddressOrThrow(routerAddress, field: 'router');
    final toAddress = _parseAddressOrThrow(to, field: 'recipient');
    final parsedPath = path
        .map((entry) => _parseAddressOrThrow(entry, field: 'path token'))
        .toList();
    final contract = DeployedContract(
      ContractAbi.fromJson(_routerAbiJson, 'ReefswapRouter'),
      router,
    );
    final swap = contract.function('swapExactTokensForETH');
    final tx = Transaction.callContract(
      contract: contract,
      function: swap,
      parameters: <dynamic>[
        amountIn,
        amountOutMin,
        parsedPath,
        toAddress,
        deadline,
      ],
      maxGas: _swapGasLimit,
    );
    return _signAndBroadcast(
      account: account,
      transaction: tx,
      contextLabel: 'swap_exact_tokens_for_eth',
      debugExtras: <String, dynamic>{
        'routerAddress': routerAddress,
        'amountIn': amountIn.toString(),
        'amountOutMin': amountOutMin.toString(),
        'path': path,
        'to': to,
        'deadline': deadline.toString(),
      },
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
    final router = _parseAddressOrThrow(routerAddress, field: 'router');
    final toAddress = _parseAddressOrThrow(to, field: 'recipient');
    final parsedPath = path
        .map((entry) => _parseAddressOrThrow(entry, field: 'path token'))
        .toList();
    final contract = DeployedContract(
      ContractAbi.fromJson(_routerAbiJson, 'ReefswapRouter'),
      router,
    );
    final swap = contract.function('swapExactTokensForTokens');
    final tx = Transaction.callContract(
      contract: contract,
      function: swap,
      parameters: <dynamic>[
        amountIn,
        amountOutMin,
        parsedPath,
        toAddress,
        deadline,
      ],
      maxGas: _swapGasLimit,
    );
    return _signAndBroadcast(
      account: account,
      transaction: tx,
      contextLabel: 'swap_exact_tokens_for_tokens',
      debugExtras: <String, dynamic>{
        'routerAddress': routerAddress,
        'amountIn': amountIn.toString(),
        'amountOutMin': amountOutMin.toString(),
        'path': path,
        'to': to,
        'deadline': deadline.toString(),
      },
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

  Future<bool> hasContractCode(String address) async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse(_rpcUrl),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'eth_getCode',
              'params': [address, 'latest'],
              'id': 1,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) return false;
      final result = payload['result'];
      if (result is! String) return false;
      final normalized = result.trim().toLowerCase();
      return normalized.isNotEmpty && normalized != '0x';
    } catch (e) {
      print('[rpc][eth_getCode_error] address=$address error=$e');
      return false;
    }
  }

  Future<String> createPair({
    required Account account,
    required String factoryAddress,
    required String tokenA,
    required String tokenB,
  }) async {
    final factoryAddressParsed = _parseAddressOrThrow(
      factoryAddress,
      field: 'factory',
    );
    final tokenAAddress = _parseAddressOrThrow(tokenA, field: 'token A');
    final tokenBAddress = _parseAddressOrThrow(tokenB, field: 'token B');
    final factory = DeployedContract(
      ContractAbi.fromJson(_factoryAbiJson, 'ReefswapFactory'),
      factoryAddressParsed,
    );
    final createPairFn = factory.function('createPair');
    final tx = Transaction.callContract(
      contract: factory,
      function: createPairFn,
      parameters: <dynamic>[tokenAAddress, tokenBAddress],
      maxGas: _factoryCreatePairGasLimit,
    );
    return _signAndBroadcast(
      account: account,
      transaction: tx,
      contextLabel: 'create_pair',
      debugExtras: <String, dynamic>{
        'factoryAddress': factoryAddress,
        'tokenA': tokenA,
        'tokenB': tokenB,
      },
    );
  }

  Future<BigInt> getErc20BalanceRaw({
    required String tokenAddress,
    required String owner,
  }) async {
    try {
      final contract = DeployedContract(
        ContractAbi.fromJson(_erc20TransferAbiJson, 'ERC20Balance'),
        _parseAddressOrThrow(tokenAddress, field: 'token'),
      );
      final balanceOf = contract.function('balanceOf');
      final response = await _client.call(
        contract: contract,
        function: balanceOf,
        params: <dynamic>[_parseAddressOrThrow(owner, field: 'owner')],
      );
      if (response.isEmpty || response.first is! BigInt) return BigInt.zero;
      return response.first as BigInt;
    } catch (e) {
      print(
        '[erc20][balance_raw_error] token=$tokenAddress owner=$owner error=$e',
      );
      return BigInt.zero;
    }
  }

  Future<String> wrapNative({
    required Account account,
    required String wrappedTokenAddress,
    required BigInt amountWei,
  }) async {
    final wrappedAddress = _parseAddressOrThrow(
      wrappedTokenAddress,
      field: 'wrapped token',
    );
    final contract = DeployedContract(
      ContractAbi.fromJson(_wrappedNativeAbiJson, 'WrappedNative'),
      wrappedAddress,
    );
    final deposit = contract.function('deposit');
    final tx = Transaction.callContract(
      contract: contract,
      function: deposit,
      parameters: const <dynamic>[],
      value: EtherAmount.inWei(amountWei),
      maxGas: _wrapNativeGasLimit,
    );
    return _signAndBroadcast(
      account: account,
      transaction: tx,
      contextLabel: 'wrap_native',
      debugExtras: <String, dynamic>{
        'wrappedTokenAddress': wrappedTokenAddress,
        'amountWei': amountWei.toString(),
      },
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
    final routerAddressParsed = _parseAddressOrThrow(
      routerAddress,
      field: 'router',
    );
    final tokenAAddress = _parseAddressOrThrow(tokenA, field: 'token A');
    final tokenBAddress = _parseAddressOrThrow(tokenB, field: 'token B');
    final toAddress = _parseAddressOrThrow(to, field: 'recipient');
    final router = DeployedContract(
      ContractAbi.fromJson(_routerLiquidityAbiJson, 'ReefswapRouterLiquidity'),
      routerAddressParsed,
    );
    final addLiquidityFn = router.function('addLiquidity');
    final tx = Transaction.callContract(
      contract: router,
      function: addLiquidityFn,
      parameters: <dynamic>[
        tokenAAddress,
        tokenBAddress,
        amountADesired,
        amountBDesired,
        amountAMin,
        amountBMin,
        toAddress,
        deadline,
      ],
      maxGas: _addLiquidityGasLimit,
    );
    return _signAndBroadcast(
      account: account,
      transaction: tx,
      contextLabel: 'add_liquidity',
      debugExtras: <String, dynamic>{
        'routerAddress': routerAddress,
        'tokenA': tokenA,
        'tokenB': tokenB,
        'amountADesired': amountADesired.toString(),
        'amountBDesired': amountBDesired.toString(),
        'amountAMin': amountAMin.toString(),
        'amountBMin': amountBMin.toString(),
        'to': to,
        'deadline': deadline.toString(),
      },
    );
  }

  Future<String> transferErc20Raw({
    required Account account,
    required String tokenAddress,
    required String to,
    required BigInt amount,
  }) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(_erc20TransferAbiJson, 'ERC20Transfer'),
      _parseAddressOrThrow(tokenAddress, field: 'token'),
    );
    final transfer = contract.function('transfer');
    final tx = Transaction.callContract(
      contract: contract,
      function: transfer,
      parameters: <dynamic>[
        _parseAddressOrThrow(to, field: 'recipient'),
        amount,
      ],
      maxGas: _erc20TransferGasLimit,
    );
    return _signAndBroadcast(
      account: account,
      transaction: tx,
      contextLabel: 'erc20_transfer_raw',
      debugExtras: <String, dynamic>{
        'tokenAddress': tokenAddress,
        'to': to,
        'amountRaw': amount.toString(),
      },
    );
  }

  Future<(BigInt reserve0, BigInt reserve1)> getPairReservesRaw({
    required String pairAddress,
  }) async {
    final pair = DeployedContract(
      ContractAbi.fromJson(_pairAbiJson, 'ReefswapPair'),
      _parseAddressOrThrow(pairAddress, field: 'pair'),
    );
    final getReserves = pair.function('getReserves');
    final response = await _client.call(
      contract: pair,
      function: getReserves,
      params: const <dynamic>[],
    );
    if (response.length < 2 ||
        response[0] is! BigInt ||
        response[1] is! BigInt) {
      throw Exception('Unable to load pair reserves.');
    }
    return (response[0] as BigInt, response[1] as BigInt);
  }

  Future<String> swapPair({
    required Account account,
    required String pairAddress,
    required BigInt amount0Out,
    required BigInt amount1Out,
    required String to,
  }) async {
    final pair = DeployedContract(
      ContractAbi.fromJson(_pairAbiJson, 'ReefswapPair'),
      _parseAddressOrThrow(pairAddress, field: 'pair'),
    );
    final swap = pair.function('swap');
    final tx = Transaction.callContract(
      contract: pair,
      function: swap,
      parameters: <dynamic>[
        amount0Out,
        amount1Out,
        _parseAddressOrThrow(to, field: 'recipient'),
        Uint8List(0),
      ],
      maxGas: _pairSwapGasLimit,
    );
    return _signAndBroadcast(
      account: account,
      transaction: tx,
      contextLabel: 'pair_swap',
      debugExtras: <String, dynamic>{
        'pairAddress': pairAddress,
        'amount0Out': amount0Out.toString(),
        'amount1Out': amount1Out.toString(),
        'to': to,
      },
    );
  }

  Future<String> mintPair({
    required Account account,
    required String pairAddress,
    required String to,
  }) async {
    final pair = DeployedContract(
      ContractAbi.fromJson(_pairAbiJson, 'ReefswapPair'),
      _parseAddressOrThrow(pairAddress, field: 'pair'),
    );
    final mint = pair.function('mint');
    final tx = Transaction.callContract(
      contract: pair,
      function: mint,
      parameters: <dynamic>[_parseAddressOrThrow(to, field: 'recipient')],
      maxGas: _pairMintGasLimit,
    );
    return _signAndBroadcast(
      account: account,
      transaction: tx,
      contextLabel: 'pair_mint',
      debugExtras: <String, dynamic>{'pairAddress': pairAddress, 'to': to},
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
    final routerAddressParsed = _parseAddressOrThrow(
      routerAddress,
      field: 'router',
    );
    final token = _parseAddressOrThrow(tokenAddress, field: 'token');
    final toAddress = _parseAddressOrThrow(to, field: 'recipient');
    final router = DeployedContract(
      ContractAbi.fromJson(_routerLiquidityAbiJson, 'ReefswapRouterLiquidity'),
      routerAddressParsed,
    );
    final addLiquidityEthFn = router.function('addLiquidityETH');
    final tx = Transaction.callContract(
      contract: router,
      function: addLiquidityEthFn,
      parameters: <dynamic>[
        token,
        amountTokenDesired,
        amountTokenMin,
        amountEthMin,
        toAddress,
        deadline,
      ],
      value: EtherAmount.inWei(amountEthDesired),
      maxGas: _addLiquidityEthGasLimit,
    );
    return _signAndBroadcast(
      account: account,
      transaction: tx,
      contextLabel: 'add_liquidity_eth',
      debugExtras: <String, dynamic>{
        'routerAddress': routerAddress,
        'tokenAddress': tokenAddress,
        'amountTokenDesired': amountTokenDesired.toString(),
        'amountTokenMin': amountTokenMin.toString(),
        'amountEthMin': amountEthMin.toString(),
        'amountEthDesired': amountEthDesired.toString(),
        'to': to,
        'deadline': deadline.toString(),
      },
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

  Future<int> estimateContractDeploymentGasLimit({
    required String fromAddress,
    required String abiJson,
    required String bytecodeHex,
    required List<dynamic> constructorArgs,
    int? configuredGasLimit,
  }) async {
    final from = _parseAddressOrThrow(fromAddress, field: 'sender');
    final fees = await getContractDeploymentFeeSettings();
    final transaction = Transaction(
      from: from,
      maxFeePerGas: EtherAmount.inWei(fees.maxFeePerGasWei),
      maxPriorityFeePerGas: EtherAmount.inWei(fees.maxPriorityFeePerGasWei),
      data: _buildDeploymentData(
        abiJson: abiJson,
        bytecodeHex: bytecodeHex,
        constructorArgs: constructorArgs,
      ),
      maxGas: configuredGasLimit ?? _contractDeployGasLimit,
    );
    return _resolveContractDeploymentGasLimit(
      transaction: transaction,
      sender: from,
      contextLabel: 'contract_deploy/preview',
    );
  }

  Future<BigInt?> probeContractDeploymentGasEstimate({
    required String fromAddress,
    required String abiJson,
    required String bytecodeHex,
    required List<dynamic> constructorArgs,
  }) async {
    final from = _parseAddressOrThrow(fromAddress, field: 'sender');
    final fees = await getContractDeploymentFeeSettings();
    return _estimateGasLimitViaRpc(
      Transaction(
        from: from,
        maxFeePerGas: EtherAmount.inWei(fees.maxFeePerGasWei),
        maxPriorityFeePerGas: EtherAmount.inWei(fees.maxPriorityFeePerGasWei),
        data: _buildDeploymentData(
          abiJson: abiJson,
          bytecodeHex: bytecodeHex,
          constructorArgs: constructorArgs,
        ),
        maxGas: _contractDeployGasLimit,
      ),
      sender: from,
    );
  }

  Future<String> deployContract({
    required Account account,
    required String abiJson,
    required String bytecodeHex,
    required List<dynamic> constructorArgs,
    String contextLabel = 'contract_deploy',
    int? gasLimit,
  }) async {
    final signer = EthPrivateKey.fromHex(account.privateKey).address;
    final fees = await getContractDeploymentFeeSettings();
    final deploymentGasLimit = await _resolveContractDeploymentGasLimit(
      transaction: Transaction(
        from: signer,
        maxFeePerGas: EtherAmount.inWei(fees.maxFeePerGasWei),
        maxPriorityFeePerGas: EtherAmount.inWei(fees.maxPriorityFeePerGasWei),
        data: _buildDeploymentData(
          abiJson: abiJson,
          bytecodeHex: bytecodeHex,
          constructorArgs: constructorArgs,
        ),
        maxGas: gasLimit ?? _contractDeployGasLimit,
      ),
      sender: signer,
      contextLabel: '$contextLabel/prepare',
    );
    final transaction = Transaction(
      data: _buildDeploymentData(
        abiJson: abiJson,
        bytecodeHex: bytecodeHex,
        constructorArgs: constructorArgs,
      ),
      maxGas: deploymentGasLimit,
      maxFeePerGas: EtherAmount.inWei(fees.maxFeePerGasWei),
      maxPriorityFeePerGas: EtherAmount.inWei(fees.maxPriorityFeePerGasWei),
    );
    return _signAndBroadcast(
      account: account,
      transaction: transaction,
      contextLabel: contextLabel,
      skipGasEstimation: true,
      eip1559Fees: fees,
      debugExtras: <String, dynamic>{
        'constructorArgs': constructorArgs
            .map((item) => item.toString())
            .toList(),
      },
    );
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
      // Fall back to local Reef chain id.
      return DexConfig.defaultChainId;
    }
  }

  Future<int> getChainId() => _resolveChainId();

  Future<BigInt> getGasPriceWei() async {
    BigInt gasPrice = _minimumGasPriceWei;
    try {
      final fetched = await _client.getGasPrice();
      gasPrice = fetched.getInWei;
    } catch (_) {
      gasPrice = _minimumGasPriceWei;
    }

    final baseFee = await _getLatestBaseFeeWei();
    if (baseFee > gasPrice) {
      gasPrice = baseFee;
    }
    if (gasPrice <= BigInt.zero) {
      gasPrice = _minimumGasPriceWei;
    }
    return gasPrice;
  }

  Future<BigInt> getContractDeploymentGasPriceWei() async {
    final fees = await getContractDeploymentFeeSettings();
    return fees.maxFeePerGasWei;
  }

  Future<Eip1559FeeSettings> getContractDeploymentFeeSettings() async {
    final baseFeeWei = await _getLatestBaseFeeWei();
    var maxPriorityFeePerGasWei = await _getMaxPriorityFeePerGasWei();
    if (maxPriorityFeePerGasWei < _minimumPriorityFeeWei) {
      maxPriorityFeePerGasWei = _minimumPriorityFeeWei;
    }
    var maxFeePerGasWei = baseFeeWei > BigInt.zero
        ? (baseFeeWei * BigInt.from(2)) + maxPriorityFeePerGasWei
        : (await getGasPriceWei());
    if (maxFeePerGasWei < maxPriorityFeePerGasWei) {
      maxFeePerGasWei = maxPriorityFeePerGasWei;
    }
    return Eip1559FeeSettings(
      maxPriorityFeePerGasWei: maxPriorityFeePerGasWei,
      maxFeePerGasWei: maxFeePerGasWei,
    );
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

  Future<TransactionReceipt> waitForReceiptAndGet(
    String txHash, {
    Duration timeout = const Duration(minutes: 3),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final started = DateTime.now();
    while (DateTime.now().difference(started) < timeout) {
      final receipt = await _client.getTransactionReceipt(txHash);
      if (receipt != null) return receipt;
      await Future<void>.delayed(pollInterval);
    }
    throw Exception('Timed out waiting for transaction receipt');
  }

  Future<String> _signAndBroadcast({
    required Account account,
    required Transaction transaction,
    required String contextLabel,
    BigInt? minimumGasPriceWei,
    bool skipGasEstimation = false,
    Eip1559FeeSettings? eip1559Fees,
    bool respectTransactionFeeFields = false,
    int? overrideNonce,
    int? overrideChainId,
    Map<String, dynamic> debugExtras = const <String, dynamic>{},
  }) async {
    final credentials = EthPrivateKey.fromHex(account.privateKey);
    final signerAddress = credentials.address;
    final accountAddress = account.address.trim().toLowerCase();
    final signerAddressText = signerAddress.hex.toLowerCase();
    if (accountAddress.isEmpty || signerAddressText != accountAddress) {
      throw Exception(
        'Selected account credentials are invalid. Please re-import this account.',
      );
    }

    final resolvedChainId = await _resolveChainId();
    if (overrideChainId != null && overrideChainId != resolvedChainId) {
      throw Exception(
        'Requested chain does not match the active Reef network.',
      );
    }
    final chainId = overrideChainId ?? resolvedChainId;
    final nonce = overrideNonce ?? await _recommendedNonce(signerAddress);
    var gasPriceWei = BigInt.zero;
    final existingMaxFee = transaction.maxFeePerGas?.getInWei;
    final existingMaxPriorityFee = transaction.maxPriorityFeePerGas?.getInWei;
    final existingGasPrice = transaction.gasPrice?.getInWei;
    final shouldUseTransactionEip1559 =
        respectTransactionFeeFields &&
        existingMaxFee != null &&
        existingMaxPriorityFee != null &&
        existingMaxFee > BigInt.zero &&
        existingMaxPriorityFee > BigInt.zero;
    final effectiveEip1559Fees =
        eip1559Fees ??
        (shouldUseTransactionEip1559
            ? Eip1559FeeSettings(
                maxPriorityFeePerGasWei: existingMaxPriorityFee,
                maxFeePerGasWei: existingMaxFee,
              )
            : null);

    if (effectiveEip1559Fees == null) {
      if (respectTransactionFeeFields &&
          existingGasPrice != null &&
          existingGasPrice > BigInt.zero) {
        gasPriceWei = existingGasPrice;
      } else {
        gasPriceWei = await getGasPriceWei();
      }
      if (minimumGasPriceWei != null && gasPriceWei < minimumGasPriceWei) {
        gasPriceWei = minimumGasPriceWei;
      }
    }
    final txWithSignerFields = effectiveEip1559Fees != null
        ? transaction.copyWith(
            from: signerAddress,
            nonce: nonce,
            value: transaction.value ?? EtherAmount.zero(),
            data: transaction.data ?? Uint8List(0),
            maxFeePerGas: EtherAmount.inWei(
              effectiveEip1559Fees.maxFeePerGasWei,
            ),
            maxPriorityFeePerGas: EtherAmount.inWei(
              effectiveEip1559Fees.maxPriorityFeePerGasWei,
            ),
          )
        : transaction.copyWith(
            from: signerAddress,
            nonce: nonce,
            gasPrice: EtherAmount.inWei(gasPriceWei),
            value: transaction.value ?? EtherAmount.zero(),
            data: transaction.data ?? Uint8List(0),
          );
    final resolvedGasLimit = skipGasEstimation
        ? (txWithSignerFields.maxGas ?? _nativeTransferGasLimit)
        : await _resolveGasLimit(
            txWithSignerFields,
            signerAddress,
            contextLabel: contextLabel,
          );
    final preparedTx = txWithSignerFields.copyWith(maxGas: resolvedGasLimit);

    _validateTransactionPayload(
      preparedTx,
      chainId: chainId,
      fromAddress: signerAddress,
      contextLabel: contextLabel,
    );
    await _assertSufficientBalance(preparedTx, signerAddress);
    try {
      return await _signAndSendRaw(
        credentials,
        preparedTx,
        chainId: chainId,
        contextLabel: contextLabel,
        attempt: 1,
        debugExtras: debugExtras,
      );
    } on RPCError catch (rpcError) {
      print(
        '[tx][rpc_error] context=$contextLabel code=${rpcError.errorCode} msg=${rpcError.message} data=${rpcError.data}',
      );
      if (_isContractCodeRejected(rpcError) &&
          contextLabel.startsWith('contract_deploy')) {
        throw ContractCodeRejectedException(
          rpcError.message.isEmpty
              ? 'Contract bytecode was rejected by the local node.'
              : rpcError.message,
        );
      }
      if (_isRetryableInvalidTransaction(rpcError)) {
        final nextNonce = await _recommendedNonce(signerAddress);
        final retryFees = eip1559Fees == null
            ? null
            : await getContractDeploymentFeeSettings();
        BigInt bumpedGasPrice = BigInt.zero;
        BigInt bumpedMaxFeePerGas = BigInt.zero;
        BigInt bumpedMaxPriorityFeePerGas = BigInt.zero;
        if (retryFees == null) {
          final currentGasPrice = preparedTx.gasPrice?.getInWei ?? BigInt.zero;
          final networkGasPrice = await getGasPriceWei();
          bumpedGasPrice = _bumpGasPrice(
            currentGasPrice > networkGasPrice
                ? currentGasPrice
                : networkGasPrice,
          );
          if (minimumGasPriceWei != null &&
              bumpedGasPrice < minimumGasPriceWei) {
            bumpedGasPrice = minimumGasPriceWei;
          }
        } else {
          final currentMaxFeePerGas =
              preparedTx.maxFeePerGas?.getInWei ?? retryFees.maxFeePerGasWei;
          final currentMaxPriorityFeePerGas =
              preparedTx.maxPriorityFeePerGas?.getInWei ??
              retryFees.maxPriorityFeePerGasWei;
          bumpedMaxPriorityFeePerGas = _bumpGasPrice(
            currentMaxPriorityFeePerGas > retryFees.maxPriorityFeePerGasWei
                ? currentMaxPriorityFeePerGas
                : retryFees.maxPriorityFeePerGasWei,
          );
          final networkMaxFeePerGas = retryFees.maxFeePerGasWei;
          bumpedMaxFeePerGas = _bumpGasPrice(
            currentMaxFeePerGas > networkMaxFeePerGas
                ? currentMaxFeePerGas
                : networkMaxFeePerGas,
          );
          if (bumpedMaxFeePerGas < bumpedMaxPriorityFeePerGas) {
            bumpedMaxFeePerGas = bumpedMaxPriorityFeePerGas;
          }
        }
        final retriedGasLimit = skipGasEstimation
            ? (preparedTx.maxGas ?? _nativeTransferGasLimit)
            : await _resolveGasLimit(
                preparedTx.copyWith(
                  nonce: nextNonce,
                  gasPrice: retryFees == null
                      ? EtherAmount.inWei(bumpedGasPrice)
                      : null,
                  maxFeePerGas: retryFees == null
                      ? null
                      : EtherAmount.inWei(bumpedMaxFeePerGas),
                  maxPriorityFeePerGas: retryFees == null
                      ? null
                      : EtherAmount.inWei(bumpedMaxPriorityFeePerGas),
                ),
                signerAddress,
                contextLabel: '$contextLabel/retry',
              );
        final retryTx = preparedTx.copyWith(
          nonce: nextNonce,
          gasPrice: retryFees == null
              ? EtherAmount.inWei(bumpedGasPrice)
              : null,
          maxFeePerGas: retryFees == null
              ? null
              : EtherAmount.inWei(bumpedMaxFeePerGas),
          maxPriorityFeePerGas: retryFees == null
              ? null
              : EtherAmount.inWei(bumpedMaxPriorityFeePerGas),
          maxGas: retriedGasLimit,
        );
        _validateTransactionPayload(
          retryTx,
          chainId: chainId,
          fromAddress: signerAddress,
          contextLabel: '$contextLabel/retry',
        );
        await _assertSufficientBalance(retryTx, signerAddress);
        try {
          return await _signAndSendRaw(
            credentials,
            retryTx,
            chainId: chainId,
            contextLabel: contextLabel,
            attempt: 2,
            debugExtras: <String, dynamic>{
              ...debugExtras,
              'retry_reason': 'invalid_transaction',
            },
          );
        } on RPCError catch (retryError) {
          final mapped = _mapRpcErrorToUserMessage(
            retryError,
            defaultMessage: 'Transaction rejected by network.',
          );
          print(
            '[tx][rpc_error_retry] context=$contextLabel code=${retryError.errorCode} msg=${retryError.message} data=${retryError.data}',
          );
          throw Exception(mapped);
        }
      }

      final mapped = _mapRpcErrorToUserMessage(
        rpcError,
        defaultMessage: 'Transaction rejected by network.',
      );
      throw Exception(mapped);
    } catch (e) {
      print('[tx][error] context=$contextLabel error=$e');
      final raw = e.toString();
      if (raw.toLowerCase().contains('rpcerror') ||
          raw.toLowerCase().contains('contracttrapped') ||
          raw.toLowerCase().contains('failed to instantiate contract')) {
        throw Exception(TransactionErrorMapper.fromThrowable(e).message);
      }
      rethrow;
    }
  }

  Future<String> _signAndSendRaw(
    EthPrivateKey credentials,
    Transaction transaction, {
    required int chainId,
    required String contextLabel,
    required int attempt,
    required Map<String, dynamic> debugExtras,
  }) async {
    final payload = <String, dynamic>{
      'context': contextLabel,
      'attempt': attempt,
      'rpcUrl': _rpcUrl,
      'from': credentials.address.hex,
      'to': transaction.to?.hex,
      'valueWei': transaction.value?.getInWei.toString() ?? '0',
      'nonce': transaction.nonce,
      'gasLimit': transaction.maxGas,
      'gasPriceWei': transaction.gasPrice?.getInWei.toString(),
      'maxFeePerGasWei': transaction.maxFeePerGas?.getInWei.toString(),
      'maxPriorityFeePerGasWei': transaction.maxPriorityFeePerGas?.getInWei
          .toString(),
      'isEip1559': transaction.isEIP1559,
      'chainId': chainId,
      'dataHex': bytesToHex(
        transaction.data ?? Uint8List(0),
        include0x: true,
        padToEvenLength: true,
      ),
      ...debugExtras,
    };
    print('[tx][payload] ${jsonEncode(payload)}');

    final signedPayload = await _client.signTransaction(
      credentials,
      transaction,
      chainId: chainId,
    );
    final signedTx = transaction.isEIP1559
        ? prependTransactionType(0x02, signedPayload)
        : signedPayload;
    final rawTxHex = bytesToHex(
      signedTx,
      include0x: true,
      padToEvenLength: true,
    );
    print('[tx][raw] context=$contextLabel attempt=$attempt raw=$rawTxHex');

    final txHash = await _client.sendRawTransaction(signedTx);
    print('[tx][hash] context=$contextLabel attempt=$attempt hash=$txHash');
    return txHash;
  }

  Future<int> _recommendedNonce(EthereumAddress address) async {
    final pending = await _client.getTransactionCount(
      address,
      atBlock: const BlockNum.pending(),
    );
    final latest = await _client.getTransactionCount(address);
    return pending > latest ? pending : latest;
  }

  Future<int> _resolveGasLimit(
    Transaction transaction,
    EthereumAddress sender, {
    required String contextLabel,
  }) async {
    final configuredLimit = transaction.maxGas;
    final estimatedLimit = await _estimateGasLimitViaRpc(
      transaction,
      sender: sender,
    );

    if (estimatedLimit != null && estimatedLimit > BigInt.zero) {
      final estimatedInt = estimatedLimit.toInt();
      final chosen = configuredLimit != null && configuredLimit > estimatedInt
          ? configuredLimit
          : estimatedInt;
      print(
        '[tx][gas] context=$contextLabel configured=${configuredLimit ?? 'null'} estimated=$estimatedLimit chosen=$chosen',
      );
      return chosen;
    }

    final fallback = (configuredLimit != null && configuredLimit > 0)
        ? configuredLimit
        : _nativeTransferGasLimit;
    print(
      '[tx][gas] context=$contextLabel configured=${configuredLimit ?? 'null'} estimated=null chosen=$fallback',
    );
    return fallback;
  }

  Future<int> _resolveContractDeploymentGasLimit({
    required Transaction transaction,
    required EthereumAddress sender,
    required String contextLabel,
  }) async {
    final configuredLimit = transaction.maxGas ?? _contractDeployGasLimit;
    final estimatedLimit = await _estimateGasLimitViaRpc(
      transaction,
      sender: sender,
    );
    if (estimatedLimit == null || estimatedLimit <= BigInt.zero) {
      print(
        '[tx][contract_deploy_gas] context=$contextLabel configured=$configuredLimit estimated=null chosen=$configuredLimit',
      );
      return configuredLimit;
    }
    final chosen = estimatedLimit.toInt();
    print(
      '[tx][contract_deploy_gas] context=$contextLabel configured=$configuredLimit estimated=$estimatedLimit chosen=$chosen',
    );
    return chosen > configuredLimit ? chosen : configuredLimit;
  }

  Future<BigInt?> _estimateGasLimitViaRpc(
    Transaction transaction, {
    required EthereumAddress sender,
  }) async {
    try {
      final txParams = <String, dynamic>{
        'from': sender.hex,
        if (transaction.to != null) 'to': transaction.to!.hex,
        if ((transaction.value?.getInWei ?? BigInt.zero) > BigInt.zero)
          'value': _toRpcQuantity(transaction.value!.getInWei),
        if ((transaction.data ?? Uint8List(0)).isNotEmpty)
          'data': bytesToHex(
            transaction.data!,
            include0x: true,
            padToEvenLength: true,
          ),
        if ((transaction.gasPrice?.getInWei ?? BigInt.zero) > BigInt.zero)
          'gasPrice': _toRpcQuantity(transaction.gasPrice!.getInWei),
        if ((transaction.maxFeePerGas?.getInWei ?? BigInt.zero) > BigInt.zero)
          'maxFeePerGas': _toRpcQuantity(transaction.maxFeePerGas!.getInWei),
        if ((transaction.maxPriorityFeePerGas?.getInWei ?? BigInt.zero) >
            BigInt.zero)
          'maxPriorityFeePerGas': _toRpcQuantity(
            transaction.maxPriorityFeePerGas!.getInWei,
          ),
      };

      final response = await _httpClient
          .post(
            Uri.parse(_rpcUrl),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'eth_estimateGas',
              'params': <dynamic>[txParams],
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
      return _parseRpcQuantity(result);
    } catch (e) {
      print('[tx][estimate_gas_error] error=$e');
      return null;
    }
  }

  Uint8List _buildDeploymentData({
    required String abiJson,
    required String bytecodeHex,
    required List<dynamic> constructorArgs,
  }) {
    final abi = ContractAbi.fromJson(abiJson, 'DeployableContract');
    final normalizedBytecode = bytecodeHex.startsWith('0x')
        ? bytecodeHex.substring(2)
        : bytecodeHex;
    final bytecode = hexToBytes(normalizedBytecode);
    ContractFunction? constructor;
    for (final function in abi.functions) {
      if (function.isConstructor) {
        constructor = function;
        break;
      }
    }
    final encodedArgs = constructor == null
        ? Uint8List(0)
        : Uint8List.fromList(
            constructor.encodeCall(constructorArgs).sublist(4),
          );
    return Uint8List.fromList(<int>[...bytecode, ...encodedArgs]);
  }

  static String _toRpcQuantity(BigInt value) {
    if (value <= BigInt.zero) return '0x0';
    return '0x${value.toRadixString(16)}';
  }

  static BigInt _parseRpcQuantity(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return BigInt.zero;
    if (text.startsWith('0x') || text.startsWith('0X')) {
      return BigInt.tryParse(text.substring(2), radix: 16) ?? BigInt.zero;
    }
    return BigInt.tryParse(text) ?? BigInt.zero;
  }

  BigInt _bumpGasPrice(BigInt currentWei) {
    if (currentWei <= BigInt.zero) return BigInt.from(1000);
    final extra = currentWei ~/ BigInt.from(5); // +20%
    return currentWei + (extra > BigInt.zero ? extra : BigInt.one);
  }

  bool _isRetryableInvalidTransaction(RPCError rpcError) {
    final raw = <String>[
      rpcError.message,
      if (rpcError.data != null) rpcError.data.toString(),
    ].join(' ').toLowerCase();
    return rpcError.errorCode == 1010 ||
        raw.contains('temporarily banned') ||
        raw.contains('invalid transaction') ||
        raw.contains('nonce') ||
        raw.contains('underpriced') ||
        raw.contains('replacement');
  }

  bool _isContractCodeRejected(RPCError rpcError) {
    final raw = <String>[
      rpcError.message,
      if (rpcError.data != null) rpcError.data.toString(),
    ].join(' ').toLowerCase();
    return raw.contains('coderejected') ||
        raw.contains('failed to instantiate contract');
  }

  Future<void> _assertSufficientBalance(
    Transaction transaction,
    EthereumAddress signerAddress,
  ) async {
    try {
      final balance = await _client.getBalance(signerAddress);
      final gasLimit = transaction.maxGas ?? 0;
      final gasPriceWei =
          transaction.maxFeePerGas?.getInWei ??
          transaction.gasPrice?.getInWei ??
          BigInt.zero;
      final transferWei = transaction.value?.getInWei ?? BigInt.zero;
      final feeWei = BigInt.from(gasLimit) * gasPriceWei;
      final totalCostWei = transferWei + feeWei;
      if (balance.getInWei < totalCostWei) {
        throw Exception(
          'Insufficient balance to cover transaction and network fee.',
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      print('[tx][balance_check_skipped] reason=$e');
    }
  }

  void _validateTransactionPayload(
    Transaction transaction, {
    required int chainId,
    required EthereumAddress fromAddress,
    required String contextLabel,
  }) {
    if (fromAddress.hex.trim().isEmpty) {
      throw Exception(
        'Invalid transaction parameters: missing sender address.',
      );
    }

    final toAddress = transaction.to;
    final data = transaction.data ?? Uint8List(0);
    if (toAddress == null && data.isEmpty) {
      throw Exception(
        'Invalid transaction parameters: destination or calldata is required.',
      );
    }

    final valueWei = transaction.value?.getInWei ?? BigInt.zero;
    if (valueWei < BigInt.zero) {
      throw Exception('Invalid transaction parameters: negative value.');
    }

    final nonce = transaction.nonce;
    if (nonce == null || nonce < 0) {
      throw Exception('Invalid transaction parameters: nonce is invalid.');
    }

    final gasLimit = transaction.maxGas;
    if (gasLimit == null || gasLimit <= 0) {
      throw Exception('Invalid transaction parameters: gas limit is invalid.');
    }

    final gasPriceWei = transaction.gasPrice?.getInWei;
    final maxFeePerGasWei = transaction.maxFeePerGas?.getInWei;
    final maxPriorityFeePerGasWei = transaction.maxPriorityFeePerGas?.getInWei;
    final hasLegacyFees = gasPriceWei != null && gasPriceWei > BigInt.zero;
    final hasEip1559Fees =
        maxFeePerGasWei != null &&
        maxFeePerGasWei > BigInt.zero &&
        maxPriorityFeePerGasWei != null &&
        maxPriorityFeePerGasWei > BigInt.zero;
    if (!hasLegacyFees && !hasEip1559Fees) {
      throw Exception(
        'Invalid transaction parameters: gas pricing is invalid.',
      );
    }

    if (chainId <= 0) {
      throw Exception('Invalid transaction parameters: chain id is invalid.');
    }

    print(
      '[tx][validate_ok] context=$contextLabel from=${fromAddress.hex} to=${toAddress?.hex ?? 'contract_creation'} valueWei=$valueWei nonce=$nonce gasLimit=$gasLimit gasPriceWei=$gasPriceWei maxFeePerGasWei=$maxFeePerGasWei maxPriorityFeePerGasWei=$maxPriorityFeePerGasWei chainId=$chainId',
    );
  }

  String _mapRpcErrorToUserMessage(
    RPCError rpcError, {
    required String defaultMessage,
  }) {
    return TransactionErrorMapper.fromRpc(
      errorCode: rpcError.errorCode,
      message: rpcError.message,
      data: rpcError.data,
      defaultMessage: defaultMessage,
    );
  }

  Future<BigInt> _getLatestBaseFeeWei() async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse(_rpcUrl),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'eth_getBlockByNumber',
              'params': ['latest', false],
              'id': 1,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return BigInt.zero;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) return BigInt.zero;
      final result = payload['result'];
      if (result is! Map<String, dynamic>) return BigInt.zero;

      final rawBaseFee = result['baseFeePerGas'];
      if (rawBaseFee is! String || rawBaseFee.trim().isEmpty) {
        return BigInt.zero;
      }
      final text = rawBaseFee.trim();
      if (text.startsWith('0x')) {
        return BigInt.tryParse(text.substring(2), radix: 16) ?? BigInt.zero;
      }
      return BigInt.tryParse(text) ?? BigInt.zero;
    } catch (_) {
      return BigInt.zero;
    }
  }

  Future<BigInt> _getMaxPriorityFeePerGasWei() async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse(_rpcUrl),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'eth_maxPriorityFeePerGas',
              'params': <dynamic>[],
              'id': 1,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _minimumPriorityFeeWei;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) return _minimumPriorityFeeWei;
      final result = payload['result'];
      if (result is! String || result.trim().isEmpty) {
        return _minimumPriorityFeeWei;
      }
      final parsed = _parseRpcQuantity(result);
      if (parsed <= BigInt.zero) return _minimumPriorityFeeWei;
      return parsed;
    } catch (_) {
      return _minimumPriorityFeeWei;
    }
  }

  EthereumAddress _parseAddressOrThrow(String raw, {required String field}) {
    final value = raw.trim();
    if (value.isEmpty) {
      throw Exception(
        'Invalid transaction parameters: missing $field address.',
      );
    }
    try {
      return EthereumAddress.fromHex(value);
    } catch (_) {
      throw Exception(
        'Invalid transaction parameters: malformed $field address.',
      );
    }
  }

  (EtherAmount?, EtherAmount?, EtherAmount?) _resolveDappFeeSettings(
    DappTransactionRequest request,
  ) {
    final gasPrice = request.gasPriceWei != null
        ? EtherAmount.inWei(request.gasPriceWei!)
        : null;
    final maxFeePerGas = request.maxFeePerGasWei != null
        ? EtherAmount.inWei(request.maxFeePerGasWei!)
        : null;
    final maxPriorityFeePerGas = request.maxPriorityFeePerGasWei != null
        ? EtherAmount.inWei(request.maxPriorityFeePerGasWei!)
        : null;
    return (gasPrice, maxFeePerGas, maxPriorityFeePerGas);
  }

  Uint8List _hexDataToBytes(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty || text == '0x') return Uint8List(0);
    final normalized = text.startsWith('0x') ? text : '0x$text';
    return Uint8List.fromList(hexToBytes(normalized));
  }
}
