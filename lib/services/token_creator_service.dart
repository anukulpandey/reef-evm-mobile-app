import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/account.dart';
import '../models/token.dart';
import '../models/token_creation_result.dart';
import '../models/token_creator_request.dart';
import '../models/transaction_preview.dart';
import '../utils/amount_utils.dart';
import '../utils/token_icon_resolver.dart';
import 'created_token_registry_service.dart';
import 'web3_service.dart';

class TokenCreatorService {
  TokenCreatorService(this._registry);

  final CreatedTokenRegistryService _registry;

  _TokenCreatorBundle? _cachedBundle;

  String? validate(TokenCreatorRequest request) {
    if (request.normalizedName.isEmpty) return 'Set token name';
    if (request.normalizedSymbol.isEmpty) return 'Set token symbol';
    if (request.initialSupply.trim().isEmpty) return 'Set initial supply';

    final normalizedSupply = request.initialSupply.trim();
    final parsed = int.tryParse(normalizedSupply);
    if (parsed == null || parsed <= 0) {
      return 'Initial supply must be a positive whole number';
    }

    try {
      AmountUtils.parseAmountToRaw(normalizedSupply, 18);
    } catch (_) {
      return 'Initial supply is too large';
    }

    return null;
  }

  Future<TransactionPreview> buildPreview({
    required Account account,
    required TokenCreatorRequest request,
    required Web3Service web3Service,
  }) async {
    final bundle = await _loadBundle();
    final standard = _selectStandardContract(bundle, request);
    final fallback = bundle.fallback;
    final initialSupplyRaw = AmountUtils.parseAmountToRaw(
      request.initialSupply,
      18,
    );

    final gasPriceWei = await web3Service.getGasPriceWei();
    var gasLimit = web3Service.contractDeployGasLimit;

    try {
      gasLimit = await web3Service.estimateContractDeploymentGasLimit(
        fromAddress: account.address,
        abiJson: standard.abiJson,
        bytecodeHex: standard.bytecodeHex,
        constructorArgs: <dynamic>[
          request.normalizedName,
          request.normalizedSymbol,
          initialSupplyRaw,
        ],
        configuredGasLimit: gasLimit,
      );
    } catch (error) {
      if (_isCodeRejectedError(error)) {
        gasLimit = await web3Service.estimateContractDeploymentGasLimit(
          fromAddress: account.address,
          abiJson: fallback.abiJson,
          bytecodeHex: fallback.bytecodeHex,
          constructorArgs: <dynamic>[
            request.normalizedName,
            request.normalizedSymbol,
            initialSupplyRaw,
          ],
          configuredGasLimit: gasLimit,
        );
      }
    }

    final feeWei = gasPriceWei * BigInt.from(gasLimit);
    final feeDisplay = AmountUtils.formatInputAmount(
      AmountUtils.parseNumeric(web3Service.formatAmountFromRaw(feeWei, 18)),
      decimals: 8,
    );

    return TransactionPreview(
      title: 'Create Token',
      methodName: 'contractCreation',
      recipientLabel: 'Owner',
      recipientAddress: account.address,
      amountDisplay: '${request.initialSupply} ${request.normalizedSymbol}',
      networkName: 'Reef',
      chainId: await web3Service.getChainId(),
      gasLimit: gasLimit,
      gasPriceWei: gasPriceWei,
      estimatedFeeDisplay: '$feeDisplay REEF',
      calldataHex: 'contract deploy',
      fields: <TransactionPreviewField>[
        TransactionPreviewField(
          label: 'Token name',
          value: request.normalizedName,
        ),
        TransactionPreviewField(
          label: 'Token symbol',
          value: request.normalizedSymbol,
        ),
        TransactionPreviewField(
          label: 'Initial supply (raw)',
          value: initialSupplyRaw.toString(),
        ),
        TransactionPreviewField(
          label: 'Burnable',
          value: request.burnable ? 'Yes' : 'No',
        ),
        TransactionPreviewField(
          label: 'Mintable',
          value: request.mintable ? 'Yes' : 'No',
        ),
        const TransactionPreviewField(
          label: 'Fallback',
          value:
              'PolkaVM-compatible simple token bytecode is used if standard bytecode is rejected.',
        ),
      ],
    );
  }

  Future<TokenCreationSubmission> submitCreation({
    required Account account,
    required TokenCreatorRequest request,
    required Web3Service web3Service,
  }) async {
    final bundle = await _loadBundle();
    final standard = _selectStandardContract(bundle, request);
    final fallback = bundle.fallback;
    final constructorArgs = <dynamic>[
      request.normalizedName,
      request.normalizedSymbol,
      AmountUtils.parseAmountToRaw(request.initialSupply, 18),
    ];

    try {
      final txHash = await web3Service.deployContract(
        account: account,
        abiJson: standard.abiJson,
        bytecodeHex: standard.bytecodeHex,
        constructorArgs: constructorArgs,
        contextLabel: 'contract_deploy/token_standard',
      );
      return TokenCreationSubmission(
        txHash: txHash,
        usedFallback: false,
        request: request,
      );
    } catch (error) {
      if (!_isCodeRejectedError(error)) rethrow;

      final txHash = await web3Service.deployContract(
        account: account,
        abiJson: fallback.abiJson,
        bytecodeHex: fallback.bytecodeHex,
        constructorArgs: constructorArgs,
        contextLabel: 'contract_deploy/token_fallback',
      );
      return TokenCreationSubmission(
        txHash: txHash,
        usedFallback: true,
        request: request,
      );
    }
  }

  Future<TokenCreationResult> completeCreation({
    required TokenCreationSubmission submission,
    required Web3Service web3Service,
  }) async {
    final receipt = await web3Service.waitForReceiptAndGet(submission.txHash);
    final contractAddress = receipt.contractAddress?.hexEip55;
    if ((receipt.status ?? true) == false) {
      throw Exception('Token deployment failed on chain.');
    }
    if (contractAddress == null || contractAddress.trim().isEmpty) {
      throw Exception(
        'Token deployment confirmed but contract address was not returned.',
      );
    }

    final token = Token(
      symbol: submission.request.normalizedSymbol,
      name: submission.request.normalizedName,
      decimals: 18,
      balance: submission.request.initialSupply,
      address: contractAddress,
      iconUrl: TokenIconResolver.resolveIpfsUrl(
        submission.request.normalizedIconUrl,
      ),
    );
    await _registry.saveToken(token);

    return TokenCreationResult(
      txHash: submission.txHash,
      contractAddress: contractAddress,
      usedFallback: submission.usedFallback,
      token: token,
    );
  }

  Future<_TokenCreatorBundle> _loadBundle() async {
    if (_cachedBundle != null) return _cachedBundle!;

    final raw = await rootBundle.loadString(
      'assets/data/token_creator_deploy_data.json',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final standard = (decoded['standard'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        key,
        _TokenCreatorContract.fromJson(value as Map<String, dynamic>),
      ),
    );

    _cachedBundle = _TokenCreatorBundle(
      standard: standard,
      fallback: _TokenCreatorContract.fromJson(
        decoded['fallback'] as Map<String, dynamic>,
      ),
    );
    return _cachedBundle!;
  }

  _TokenCreatorContract _selectStandardContract(
    _TokenCreatorBundle bundle,
    TokenCreatorRequest request,
  ) {
    if (!request.burnable && !request.mintable) {
      return bundle.standard['noMintNoBurn']!;
    }
    if (request.burnable && !request.mintable) {
      return bundle.standard['noMintBurn']!;
    }
    if (!request.burnable && request.mintable) {
      return bundle.standard['mintNoBurn']!;
    }
    return bundle.standard['mintBurn']!;
  }

  bool _isCodeRejectedError(Object error) {
    final normalized = error.toString().toLowerCase();
    return normalized.contains('coderejected') ||
        normalized.contains('failed to instantiate contract');
  }
}

class _TokenCreatorBundle {
  const _TokenCreatorBundle({required this.standard, required this.fallback});

  final Map<String, _TokenCreatorContract> standard;
  final _TokenCreatorContract fallback;
}

class _TokenCreatorContract {
  const _TokenCreatorContract({
    required this.abiJson,
    required this.bytecodeHex,
  });

  factory _TokenCreatorContract.fromJson(Map<String, dynamic> json) {
    return _TokenCreatorContract(
      abiJson: jsonEncode(json['abi']),
      bytecodeHex: (json['bytecode'] ?? '').toString(),
    );
  }

  final String abiJson;
  final String bytecodeHex;
}
