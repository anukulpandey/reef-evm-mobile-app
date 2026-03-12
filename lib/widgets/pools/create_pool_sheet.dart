import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/config/dex_config.dart';
import '../../core/theme/styles.dart';
import '../../models/token.dart';
import '../../models/transaction_preview.dart';
import '../../providers/pool_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/wallet_provider.dart';
import '../../screens/transaction_confirmation_screen.dart';
import '../../utils/amount_utils.dart';

class CreatePoolSheet extends ConsumerStatefulWidget {
  const CreatePoolSheet({
    super.key,
    required this.portfolioTokens,
    this.onPoolCreated,
  });

  final List<Token> portfolioTokens;
  final VoidCallback? onPoolCreated;

  @override
  ConsumerState<CreatePoolSheet> createState() => _CreatePoolSheetState();
}

class _CreatePoolSheetState extends ConsumerState<CreatePoolSheet> {
  static const String _zeroAddress = '0x0000000000000000000000000000000000000000';
  final TextEditingController _amountAController = TextEditingController();
  final TextEditingController _amountBController = TextEditingController();

  late final List<Token> _tokenOptions;
  Token? _tokenA;
  Token? _tokenB;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _tokenOptions = _dedupeTokens(widget.portfolioTokens);
    if (_tokenOptions.isNotEmpty) {
      _tokenA = _tokenOptions.first;
      _tokenB =
          _tokenOptions.length > 1 ? _tokenOptions[1] : _tokenOptions.first;
    }
  }

  @override
  void dispose() {
    _amountAController.dispose();
    _amountBController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canCreate =
        !_isSubmitting &&
        _tokenA != null &&
        _tokenB != null &&
        _tokenOptions.length >= 2;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Styles.primaryBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Create Pool',
                    style: TextStyle(
                      color: Styles.textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Styles.textColor),
                  ),
                ],
              ),
              const Gap(8),
              _tokenDropdown(
                title: 'Token A',
                value: _tokenA,
                onChanged: (next) {
                  if (next == null) return;
                  setState(() {
                    _tokenA = next;
                    if (_isSameToken(_tokenA!, _tokenB)) {
                      _tokenB = _tokenOptions.firstWhere(
                        (token) => !_isSameToken(token, _tokenA),
                        orElse: () => _tokenOptions.first,
                      );
                    }
                  });
                },
              ),
              const Gap(10),
              _amountField(
                label: 'Amount A',
                controller: _amountAController,
              ),
              const Gap(12),
              _tokenDropdown(
                title: 'Token B',
                value: _tokenB,
                onChanged: (next) {
                  if (next == null) return;
                  setState(() {
                    _tokenB = next;
                    if (_isSameToken(_tokenA!, _tokenB)) {
                      _tokenA = _tokenOptions.firstWhere(
                        (token) => !_isSameToken(token, _tokenB),
                        orElse: () => _tokenOptions.first,
                      );
                    }
                  });
                },
              ),
              const Gap(10),
              _amountField(
                label: 'Amount B',
                controller: _amountBController,
              ),
              const Gap(10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'If pool does not exist, pair creation and token approvals may be submitted before adding liquidity.',
                  style: TextStyle(
                    color: Styles.textLightColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const Gap(8),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: Styles.errorColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const Gap(14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canCreate ? _onCreatePoolPressed : null,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: canCreate
                        ? Styles.secondaryAccentColorDark
                        : const Color(0xFFCBC6D9),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : const Text(
                          'Create Pool',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tokenDropdown({
    required String title,
    required Token? value,
    required ValueChanged<Token?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Styles.textLightColor,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const Gap(6),
        DropdownButtonFormField<Token>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD0C9E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD0C9E0)),
            ),
          ),
          items: _tokenOptions
              .map(
                (token) => DropdownMenuItem<Token>(
                  value: token,
                  child: Text(
                    _tokenLabel(token),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Styles.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: _isSubmitting ? null : onChanged,
        ),
      ],
    );
  }

  Widget _amountField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isSubmitting,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD0C9E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD0C9E0)),
        ),
      ),
    );
  }

  Future<void> _onCreatePoolPressed() async {
    if (_isSubmitting) return;
    final tokenA = _tokenA;
    final tokenB = _tokenB;
    if (tokenA == null || tokenB == null) return;

    final walletState = ref.read(walletProvider);
    final account = walletState.activeAccount;
    if (account == null) {
      setState(() => _errorText = 'No active account selected.');
      return;
    }

    if (_isSameToken(tokenA, tokenB)) {
      setState(() => _errorText = 'Token A and Token B must be different.');
      return;
    }

    final amountAText = _amountAController.text.trim();
    final amountBText = _amountBController.text.trim();
    if (amountAText.isEmpty || amountBText.isEmpty) {
      setState(() => _errorText = 'Enter both token amounts.');
      return;
    }

    final web3 = ref.read(web3ServiceProvider);
    BigInt rawA;
    BigInt rawB;
    try {
      rawA = web3.parseAmountToRaw(amountAText, tokenA.decimals);
      rawB = web3.parseAmountToRaw(amountBText, tokenB.decimals);
    } catch (_) {
      setState(() => _errorText = 'Invalid amount format.');
      return;
    }
    if (rawA <= BigInt.zero || rawB <= BigInt.zero) {
      setState(() => _errorText = 'Amounts must be greater than zero.');
      return;
    }

    final preview = await _buildPreview(
      accountAddress: account.address,
      tokenA: tokenA,
      tokenB: tokenB,
      amountAText: amountAText,
      amountBText: amountBText,
      rawA: rawA,
      rawB: rawB,
    );
    if (!mounted) return;

    final result = await Navigator.of(context).push<TransactionApprovalResult>(
      MaterialPageRoute(
        builder: (_) => TransactionConfirmationScreen(
          preview: preview,
          approveButtonText: 'Approve & Create',
          rejectButtonText: 'Reject',
          onApprove: () async {
            if (mounted) {
              setState(() {
                _isSubmitting = true;
                _errorText = null;
              });
            }
            try {
              return await _createPoolTransaction(
                accountAddress: account.address,
                tokenA: tokenA,
                tokenB: tokenB,
                rawA: rawA,
                rawB: rawB,
              );
            } finally {
              if (mounted) {
                setState(() => _isSubmitting = false);
              }
            }
          },
        ),
      ),
    );
    if (!mounted) return;
    if (result == null || !result.approved || (result.txHash ?? '').isEmpty) {
      return;
    }

    ref.invalidate(poolsProvider);
    widget.onPoolCreated?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pool creation submitted: ${result.txHash!.substring(0, 10)}...'),
      ),
    );
    Navigator.of(context).pop(true);
  }

  Future<TransactionPreview> _buildPreview({
    required String accountAddress,
    required Token tokenA,
    required Token tokenB,
    required String amountAText,
    required String amountBText,
    required BigInt rawA,
    required BigInt rawB,
  }) async {
    final web3 = ref.read(web3ServiceProvider);
    final chainId = await web3.getChainId();
    final gasPriceWei = await web3.getGasPriceWei();
    final hasNativeSide = _isNative(tokenA) || _isNative(tokenB);
    final gasLimit = hasNativeSide
        ? web3.addLiquidityEthGasLimit
        : web3.addLiquidityGasLimit;
    final feeWei = gasPriceWei * BigInt.from(gasLimit);
    final feeDisplay = AmountUtils.formatInputAmount(
      AmountUtils.parseNumeric(web3.formatAmountFromRaw(feeWei, 18)),
      decimals: 8,
    );

    return TransactionPreview(
      title: 'Create Pool',
      methodName: hasNativeSide ? 'addLiquidityETH' : 'addLiquidity',
      recipientAddress: accountAddress,
      amountDisplay:
          '$amountAText ${tokenA.symbol.toUpperCase()} + $amountBText ${tokenB.symbol.toUpperCase()}',
      networkName: chainId == DexConfig.defaultChainId ? 'Reef' : 'Chain $chainId',
      chainId: chainId,
      contractAddress: DexConfig.routerAddress,
      gasLimit: gasLimit,
      gasPriceWei: gasPriceWei,
      estimatedFeeDisplay: '$feeDisplay REEF',
      calldataHex: hasNativeSide ? '0xf305d719…' : '0xe8e33700…',
      fields: <TransactionPreviewField>[
        TransactionPreviewField(label: 'Token A', value: _tokenLabel(tokenA)),
        TransactionPreviewField(label: 'Token B', value: _tokenLabel(tokenB)),
        TransactionPreviewField(label: 'Amount A (raw)', value: rawA.toString()),
        TransactionPreviewField(label: 'Amount B (raw)', value: rawB.toString()),
        const TransactionPreviewField(
          label: 'Router',
          value: DexConfig.routerAddress,
        ),
        const TransactionPreviewField(
          label: 'Factory',
          value: DexConfig.factoryAddress,
        ),
      ],
    );
  }

  Future<String> _createPoolTransaction({
    required String accountAddress,
    required Token tokenA,
    required Token tokenB,
    required BigInt rawA,
    required BigInt rawB,
  }) async {
    final walletState = ref.read(walletProvider);
    final account = walletState.activeAccount;
    if (account == null) {
      throw Exception('No active account selected');
    }

    final web3 = ref.read(web3ServiceProvider);
    final tokenAIsNative = _isNative(tokenA);
    final tokenBIsNative = _isNative(tokenB);
    if (tokenAIsNative && tokenBIsNative) {
      throw Exception('Cannot create pool with two native tokens');
    }

    final deadline = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
          (DexConfig.defaultDeadlineMinutes * 60),
    );

    Future<void> ensureAllowance({
      required Token token,
      required BigInt amount,
    }) async {
      if (_isNative(token)) return;
      final allowance = await web3.getErc20Allowance(
        tokenAddress: token.address,
        owner: account.address,
        spender: DexConfig.routerAddress,
      );
      if (allowance >= amount) return;

      final approveHash = await web3.approveErc20(
        account: account,
        tokenAddress: token.address,
        spender: DexConfig.routerAddress,
        amount: amount,
      );
      await web3.waitForReceipt(approveHash);
    }

    if (tokenAIsNative || tokenBIsNative) {
      final nativeRaw = tokenAIsNative ? rawA : rawB;
      final erc20Token = tokenAIsNative ? tokenB : tokenA;
      final erc20Raw = tokenAIsNative ? rawB : rawA;
      await ensureAllowance(token: erc20Token, amount: erc20Raw);
      return web3.addLiquidityEth(
        account: account,
        routerAddress: DexConfig.routerAddress,
        tokenAddress: erc20Token.address,
        amountTokenDesired: erc20Raw,
        amountTokenMin: BigInt.zero,
        amountEthMin: BigInt.zero,
        to: accountAddress,
        deadline: deadline,
        amountEthDesired: nativeRaw,
      );
    }

    await ensureAllowance(token: tokenA, amount: rawA);
    await ensureAllowance(token: tokenB, amount: rawB);

    var pairAddress = await web3.getPairAddress(
      factoryAddress: DexConfig.factoryAddress,
      tokenA: tokenA.address,
      tokenB: tokenB.address,
    );
    if (pairAddress.trim().toLowerCase() == _zeroAddress) {
      final createPairHash = await web3.createPair(
        account: account,
        factoryAddress: DexConfig.factoryAddress,
        tokenA: tokenA.address,
        tokenB: tokenB.address,
      );
      await web3.waitForReceipt(createPairHash);
      pairAddress = await web3.getPairAddress(
        factoryAddress: DexConfig.factoryAddress,
        tokenA: tokenA.address,
        tokenB: tokenB.address,
      );
      if (pairAddress.trim().toLowerCase() == _zeroAddress) {
        throw Exception('Failed to create pair for selected tokens');
      }
    }

    return web3.addLiquidity(
      account: account,
      routerAddress: DexConfig.routerAddress,
      tokenA: tokenA.address,
      tokenB: tokenB.address,
      amountADesired: rawA,
      amountBDesired: rawB,
      amountAMin: BigInt.zero,
      amountBMin: BigInt.zero,
      to: accountAddress,
      deadline: deadline,
    );
  }

  List<Token> _dedupeTokens(List<Token> tokens) {
    final unique = <String, Token>{};
    for (final token in tokens) {
      final key = _tokenIdentity(token);
      if (!unique.containsKey(key)) unique[key] = token;
    }
    return unique.values.toList();
  }

  static String _tokenIdentity(Token token) {
    if (_isNative(token)) return 'native';
    return token.address.trim().toLowerCase();
  }

  static bool _isSameToken(Token a, Token? b) {
    if (b == null) return false;
    return _tokenIdentity(a) == _tokenIdentity(b);
  }

  static bool _isNative(Token token) {
    final symbol = token.symbol.trim().toUpperCase();
    final address = token.address.trim().toLowerCase();
    return address == 'native' || symbol == 'REEF';
  }

  static String _tokenLabel(Token token) {
    final symbol = token.symbol.trim().isEmpty ? 'TOKEN' : token.symbol.trim();
    if (_isNative(token)) return '$symbol (Native)';
    final address = token.address.trim();
    final short = address.length > 8 ? '${address.substring(0, 8)}...' : address;
    return '$symbol ($short)';
  }
}
