import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import '../models/account.dart';

class Web3Service {
  late Web3Client _client;
  final Client _httpClient = Client();

  Web3Service({String rpcUrl = "http://localhost:8545"}) {
    _client = Web3Client(rpcUrl, _httpClient);
  }

  void updateRpc(String rpcUrl) {
    _client = Web3Client(rpcUrl, _httpClient);
  }

  Future<String> getBalance(String address) async {
    try {
      final balance = await _client.getBalance(EthereumAddress.fromHex(address));
      return balance.getValueInUnit(EtherUnit.ether).toString();
    } catch (e) {
      print("Error getting balance: $e");
      return "0.0";
    }
  }

  Future<String> sendEth(Account account, String to, String amountStr) async {
    try {
      final credentials = EthPrivateKey.fromHex(account.privateKey);
      final txHash = await _client.sendTransaction(
        credentials,
        Transaction(
          to: EthereumAddress.fromHex(to),
          value: EtherAmount.fromUnitAndValue(EtherUnit.ether, (double.parse(amountStr) * 1e18).toInt()),
        ),
        chainId: null, // Fetches automatically if null in some versions, or specify if known
      );
      return txHash;
    } catch (e) {
      print("Error sending eth: $e");
      rethrow;
    }
  }

  Future<String> getERC20Balance(String accountAddress, String tokenAddress) async {
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

      final decimals = await _client.call(
        contract: contract,
        function: decimalsFunction,
        params: [],
      );

      final BigInt balanceVal = balance.first as BigInt;
      final int decimalsVal = (decimals.first as BigInt).toInt();

      return (balanceVal.toDouble() / (10 * decimalsVal)).toString();
    } catch (e) {
      print("Error getting ERC20 balance: $e");
      return "0.0";
    }
  }
}
