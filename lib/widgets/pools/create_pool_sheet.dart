import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/config/dex_config.dart';
import '../../core/theme/reef_theme_colors.dart';
import '../../core/theme/styles.dart';
import '../../models/token.dart';
import '../../models/transaction_preview.dart';
import '../../providers/pool_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/wallet_provider.dart';
import '../../screens/transaction_confirmation_screen.dart';
import '../../utils/amount_utils.dart';
import '../common/token_avatar.dart';

class CreatePoolSheet extends ConsumerStatefulWidget {
  const CreatePoolSheet({
    super.key,
    required this.portfolioTokens,
    this.preferredTokenAddress,
    this.onPoolCreated,
  });

  final List<Token> portfolioTokens;
  final String? preferredTokenAddress;
  final VoidCallback? onPoolCreated;

  @override
  ConsumerState<CreatePoolSheet> createState() => _CreatePoolSheetState();
}

class _CreatePoolSheetState extends ConsumerState<CreatePoolSheet> {
  static const String _zeroAddress =
      '0x0000000000000000000000000000000000000000';
  final TextEditingController _amountAController = TextEditingController();
  final TextEditingController _amountBController = TextEditingController();

  late final List<Token> _tokenOptions;
  Token? _tokenA;
  Token? _tokenB;
  bool _isSubmitting = false;
  bool _isResolvingPair = false;
  bool? _poolExists;
  String? _resolvedPairAddress;
  BigInt? _reserveA;
  BigInt? _reserveB;
  String? _errorText;
  bool _isAutoSyncingAmounts = false;

  @override
  void initState() {
    super.initState();
    _tokenOptions = _dedupeTokens(widget.portfolioTokens);
    if (_tokenOptions.isNotEmpty) {
      final preferredAddress = widget.preferredTokenAddress
          ?.trim()
          .toLowerCase();
      Token? preferredToken;
      if (preferredAddress != null) {
        for (final token in _tokenOptions) {
          if (token.address.trim().toLowerCase() == preferredAddress) {
            preferredToken = token;
            break;
          }
        }
      }
      _tokenA = preferredToken ?? _tokenOptions.first;
      _tokenB = _tokenOptions.firstWhere(
        (token) => !_isSameToken(token, _tokenA),
        orElse: () => _tokenOptions.first,
      );
    }
    _amountAController.addListener(() => _handleAmountChanged(_AmountField.a));
    _amountBController.addListener(() => _handleAmountChanged(_AmountField.b));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPoolState();
    });
  }

  @override
  void dispose() {
    _amountAController.dispose();
    _amountBController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    final actionLabel = _actionButtonLabel;
    final canCreate =
        !_isSubmitting &&
        !_isResolvingPair &&
        _tokenA != null &&
        _tokenB != null &&
        _tokenOptions.length >= 2;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.pageBackground,
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
                  Text(
                    actionLabel,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: colors.textPrimary),
                  ),
                ],
              ),
              const Gap(8),
              _tokenDropdown(
                title: 'Token A',
                value: _tokenA,
                onChanged: (next) async {
                  if (next == null) return;
                  setState(() {
                    _tokenA = next;
                    _poolExists = null;
                    _resolvedPairAddress = null;
                    _reserveA = null;
                    _reserveB = null;
                    if (_isSameToken(_tokenA!, _tokenB)) {
                      _tokenB = _tokenOptions.firstWhere(
                        (token) => !_isSameToken(token, _tokenA),
                        orElse: () => _tokenOptions.first,
                      );
                    }
                  });
                  await _refreshPoolState();
                },
              ),
              const Gap(10),
              _amountField(label: 'Amount A', controller: _amountAController),
              const Gap(12),
              _tokenDropdown(
                title: 'Token B',
                value: _tokenB,
                onChanged: (next) async {
                  if (next == null) return;
                  setState(() {
                    _tokenB = next;
                    _poolExists = null;
                    _resolvedPairAddress = null;
                    _reserveA = null;
                    _reserveB = null;
                    if (_isSameToken(_tokenA!, _tokenB)) {
                      _tokenA = _tokenOptions.firstWhere(
                        (token) => !_isSameToken(token, _tokenB),
                        orElse: () => _tokenOptions.first,
                      );
                    }
                  });
                  await _refreshPoolState();
                },
              ),
              const Gap(10),
              _amountField(label: 'Amount B', controller: _amountBController),
              const Gap(10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.cardBackground.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isResolvingPair) ...[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.accentStrong,
                        ),
                      ),
                      const Gap(8),
                    ],
                    Expanded(
                      child: Text(
                        _statusBannerText,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_resolvedPairAddress != null && _poolExists == true) ...[
                const Gap(8),
                Text(
                  _existingPairSummaryText,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
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
                        ? colors.accentStrong
                        : colors.textMuted.withOpacity(0.4),
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
                      : Text(
                          actionLabel,
                          style: const TextStyle(
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
    final colors = context.reefColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const Gap(6),
        DropdownButtonFormField<Token>(
          value: value,
          isExpanded: true,
          isDense: false,
          itemHeight: null,
          menuMaxHeight: 280,
          alignment: AlignmentDirectional.centerStart,
          dropdownColor: colors.cardBackground,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          iconEnabledColor: colors.textSecondary,
          iconDisabledColor: colors.textMuted,
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.inputFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.accentStrong, width: 1.5),
            ),
          ),
          selectedItemBuilder: (context) => _tokenOptions
              .map((token) => _buildTokenOptionRow(token: token, compact: true))
              .toList(),
          items: _tokenOptions
              .map(
                (token) => DropdownMenuItem<Token>(
                  value: token,
                  child: _buildTokenOptionRow(token: token),
                ),
              )
              .toList(),
          onChanged: _isSubmitting ? null : onChanged,
        ),
      ],
    );
  }

  Widget _buildTokenOptionRow({required Token token, bool compact = false}) {
    final colors = context.reefColors;
    final title = _tokenLabel(token);
    final subtitle = _tokenOptionSubtitle(token);
    final symbol = token.symbol.trim().isEmpty ? 'TOKEN' : token.symbol.trim();

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TokenAvatar(
            size: compact ? 24 : 28,
            iconUrl: token.iconUrl,
            fallbackSeed: symbol,
            resolveFallbackIcon: true,
            useDeterministicFallback: true,
            avatarBackgroundColor: colors.cardBackgroundSecondary,
            badgeText: symbol.toUpperCase() == 'WETH' ? 'W' : null,
          ),
          Gap(compact ? 8 : 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: compact ? 15 : 16,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  Gap(compact ? 1 : 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: compact ? 11 : 12,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountField({
    required String label,
    required TextEditingController controller,
  }) {
    final colors = context.reefColors;
    return TextField(
      controller: controller,
      enabled: !_isSubmitting,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      cursorColor: colors.accentStrong,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: colors.textMuted,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: TextStyle(
          color: colors.accentStrong,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: colors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.accentStrong, width: 1.5),
        ),
      ),
    );
  }

  String get _actionButtonLabel {
    if (_poolExists == true) return 'Add Liquidity';
    return 'Create Pool';
  }

  String get _statusBannerText {
    if (_tokenA == null || _tokenB == null) {
      return 'Select both tokens to check whether this pool already exists.';
    }
    if (_poolExists == true) {
      return 'Pool already exists. Liquidity will be added to the existing pair instead of creating a new pool.';
    }
    if (_poolExists == false) {
      return 'Pool does not exist yet. Pair creation and token approvals may be submitted before adding liquidity.';
    }
    if (_isResolvingPair) {
      return 'Checking whether the selected pool already exists...';
    }
    return 'Select both tokens to check whether this pool already exists.';
  }

  Future<void> _refreshPoolState() async {
    final tokenA = _tokenA;
    final tokenB = _tokenB;
    if (tokenA == null || tokenB == null) return;

    if (_isSameToken(tokenA, tokenB)) {
      if (!mounted) return;
      setState(() {
        _poolExists = null;
        _resolvedPairAddress = null;
        _reserveA = null;
        _reserveB = null;
      });
      return;
    }

    setState(() {
      _isResolvingPair = true;
      _errorText = null;
    });

    try {
      final resolution = await _resolvePoolState(
        tokenA: tokenA,
        tokenB: tokenB,
      );
      if (!mounted || tokenA != _tokenA || tokenB != _tokenB) return;
      setState(() {
        _poolExists = resolution.exists;
        _resolvedPairAddress = resolution.pairAddress;
        _reserveA = resolution.reserveA;
        _reserveB = resolution.reserveB;
      });
      _syncAmountsFromExistingPool();
    } catch (error) {
      debugPrint('[create_pool][pair_check_error] $error');
      if (!mounted) return;
      setState(() {
        _poolExists = null;
        _resolvedPairAddress = null;
        _reserveA = null;
        _reserveB = null;
        _errorText = 'Unable to check whether this pool already exists.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingPair = false;
        });
      }
    }
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

    late final _PoolResolution poolState;
    try {
      poolState = await _resolvePoolState(tokenA: tokenA, tokenB: tokenB);
    } catch (error) {
      debugPrint('[create_pool][pair_check_before_submit_error] $error');
      if (mounted) {
        setState(() {
          _errorText = 'Unable to confirm whether this pool already exists.';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _poolExists = poolState.exists;
      _resolvedPairAddress = poolState.pairAddress;
      _reserveA = poolState.reserveA;
      _reserveB = poolState.reserveB;
    });

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

    final balanceValidation = _validateAvailableBalances(
      tokenA: tokenA,
      tokenB: tokenB,
      rawA: rawA,
      rawB: rawB,
    );
    if (balanceValidation != null) {
      setState(() => _errorText = balanceValidation);
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
      poolExists: poolState.exists,
      pairAddress: poolState.pairAddress,
    );
    if (!mounted) return;

    final result = await Navigator.of(context).push<TransactionApprovalResult>(
      MaterialPageRoute(
        builder: (_) => TransactionConfirmationScreen(
          preview: preview,
          approveButtonText: poolState.exists
              ? 'Approve & Add Liquidity'
              : 'Approve & Create',
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
        content: Text(
          '${poolState.exists ? 'Liquidity add' : 'Pool creation'} submitted: ${result.txHash!.substring(0, 10)}...',
        ),
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
    required bool poolExists,
    required String? pairAddress,
  }) async {
    final web3 = ref.read(web3ServiceProvider);
    final chainId = await web3.getChainId();
    final gasPriceWei = await web3.getGasPriceWei();
    final gasLimit = web3.addLiquidityGasLimit;
    final feeWei = gasPriceWei * BigInt.from(gasLimit);
    final feeDisplay = AmountUtils.formatInputAmount(
      AmountUtils.parseNumeric(web3.formatAmountFromRaw(feeWei, 18)),
      decimals: 8,
    );

    return TransactionPreview(
      title: poolExists ? 'Add Liquidity' : 'Create Pool',
      methodName: 'addLiquidity',
      recipientAddress: accountAddress,
      amountDisplay:
          '$amountAText ${tokenA.symbol.toUpperCase()} + $amountBText ${tokenB.symbol.toUpperCase()}',
      networkName: chainId == DexConfig.defaultChainId
          ? 'Reef'
          : 'Chain $chainId',
      chainId: chainId,
      contractAddress: DexConfig.routerAddress,
      gasLimit: gasLimit,
      gasPriceWei: gasPriceWei,
      estimatedFeeDisplay: '$feeDisplay REEF',
      calldataHex: '0xe8e33700…',
      fields: <TransactionPreviewField>[
        if (pairAddress != null && poolExists)
          TransactionPreviewField(label: 'Pair', value: pairAddress),
        if (_isNative(tokenA) || _isNative(tokenB))
          const TransactionPreviewField(
            label: 'Native handling',
            value: 'REEF is wrapped to WREEF before adding liquidity.',
          ),
        TransactionPreviewField(label: 'Token A', value: _tokenLabel(tokenA)),
        TransactionPreviewField(label: 'Token B', value: _tokenLabel(tokenB)),
        TransactionPreviewField(
          label: 'Amount A (raw)',
          value: rawA.toString(),
        ),
        TransactionPreviewField(
          label: 'Amount B (raw)',
          value: rawB.toString(),
        ),
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

    final normalizedTokenA = _factoryPairTokenAddress(tokenA);
    final normalizedTokenB = _factoryPairTokenAddress(tokenB);
    if (normalizedTokenA.toLowerCase() == normalizedTokenB.toLowerCase()) {
      throw Exception('Token A and Token B resolve to the same pool token.');
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

    Future<void> ensureWrappedNativeBalance(BigInt requiredAmount) async {
      if (requiredAmount <= BigInt.zero) return;
      final wrappedBalance = await web3.getErc20BalanceRaw(
        tokenAddress: DexConfig.wrappedReefAddress,
        owner: account.address,
      );
      if (wrappedBalance >= requiredAmount) return;

      final wrapAmount = requiredAmount - wrappedBalance;
      final wrapHash = await web3.wrapNative(
        account: account,
        wrappedTokenAddress: DexConfig.wrappedReefAddress,
        amountWei: wrapAmount,
      );
      await web3.waitForReceipt(wrapHash);
    }

    Future<String> resolveOrCreatePair() async {
      var pairAddress = await web3.getPairAddress(
        factoryAddress: DexConfig.factoryAddress,
        tokenA: normalizedTokenA,
        tokenB: normalizedTokenB,
      );
      if (pairAddress.trim().toLowerCase() != _zeroAddress) {
        return pairAddress;
      }

      final createPairHash = await web3.createPair(
        account: account,
        factoryAddress: DexConfig.factoryAddress,
        tokenA: normalizedTokenA,
        tokenB: normalizedTokenB,
      );
      await web3.waitForReceipt(createPairHash);
      pairAddress = await web3.getPairAddress(
        factoryAddress: DexConfig.factoryAddress,
        tokenA: normalizedTokenA,
        tokenB: normalizedTokenB,
      );
      if (pairAddress.trim().toLowerCase() == _zeroAddress) {
        throw Exception('Failed to create pair for selected tokens');
      }
      return pairAddress;
    }

    Future<String> addLiquidityViaPairMint() async {
      final pairAddress = await resolveOrCreatePair();
      final transferAHash = await web3.transferErc20Raw(
        account: account,
        tokenAddress: normalizedTokenA,
        to: pairAddress,
        amount: rawA,
      );
      await web3.waitForReceipt(transferAHash);
      final transferBHash = await web3.transferErc20Raw(
        account: account,
        tokenAddress: normalizedTokenB,
        to: pairAddress,
        amount: rawB,
      );
      await web3.waitForReceipt(transferBHash);
      return web3.mintPair(
        account: account,
        pairAddress: pairAddress,
        to: accountAddress,
      );
    }

    if (tokenAIsNative) {
      await ensureWrappedNativeBalance(rawA);
    }
    if (tokenBIsNative) {
      await ensureWrappedNativeBalance(rawB);
    }

    await ensureAllowance(
      token: tokenAIsNative
          ? Token(
              symbol: 'WREEF',
              name: 'Wrapped Reef',
              address: DexConfig.wrappedReefAddress,
              balance: '0',
              decimals: 18,
            )
          : tokenA,
      amount: rawA,
    );
    await ensureAllowance(
      token: tokenBIsNative
          ? Token(
              symbol: 'WREEF',
              name: 'Wrapped Reef',
              address: DexConfig.wrappedReefAddress,
              balance: '0',
              decimals: 18,
            )
          : tokenB,
      amount: rawB,
    );

    final hasRouterCode = await web3.hasContractCode(DexConfig.routerAddress);
    if (hasRouterCode) {
      try {
        return await web3.addLiquidity(
          account: account,
          routerAddress: DexConfig.routerAddress,
          tokenA: normalizedTokenA,
          tokenB: normalizedTokenB,
          amountADesired: rawA,
          amountBDesired: rawB,
          amountAMin: BigInt.zero,
          amountBMin: BigInt.zero,
          to: accountAddress,
          deadline: deadline,
        );
      } catch (error) {
        if (_looksLikeUserRejection(error)) rethrow;
        debugPrint('[create_pool][router_add_fallback] error=$error');
      }
      return addLiquidityViaPairMint();
    }

    debugPrint('[create_pool][router_missing] using direct pair mint fallback');
    return addLiquidityViaPairMint();
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
    return _factoryPairTokenAddress(token).trim().toLowerCase();
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
    final short = address.length > 8
        ? '${address.substring(0, 8)}...'
        : address;
    return '$symbol ($short)';
  }

  static String? _tokenOptionSubtitle(Token token) {
    if (_isNative(token)) return token.name.trim().isEmpty ? null : token.name;
    final address = token.address.trim();
    if (address.isEmpty) return null;
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  static String _shortAddress(String address) {
    final value = address.trim();
    if (value.length <= 12) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
  }

  Future<_PoolResolution> _resolvePoolState({
    required Token tokenA,
    required Token tokenB,
  }) async {
    if (_isSameToken(tokenA, tokenB)) {
      return const _PoolResolution(exists: false, pairAddress: null);
    }

    if (_isNative(tokenA) && _isNative(tokenB)) {
      return const _PoolResolution(exists: false, pairAddress: null);
    }

    final web3 = ref.read(web3ServiceProvider);
    final resolvedTokenA = _factoryPairTokenAddress(tokenA);
    final resolvedTokenB = _factoryPairTokenAddress(tokenB);
    final pairAddress = await web3.getPairAddress(
      factoryAddress: DexConfig.factoryAddress,
      tokenA: resolvedTokenA,
      tokenB: resolvedTokenB,
    );
    final normalized = pairAddress.trim().toLowerCase();
    if (normalized.isEmpty || normalized == _zeroAddress) {
      return const _PoolResolution(
        exists: false,
        pairAddress: null,
        reserveA: null,
        reserveB: null,
      );
    }

    final reserves = await web3.getPairReservesRaw(pairAddress: pairAddress);
    final token0IsTokenA =
        _compareNormalizedAddresses(
          resolvedTokenA.trim().toLowerCase(),
          resolvedTokenB.trim().toLowerCase(),
        ) <=
        0;

    return _PoolResolution(
      exists: true,
      pairAddress: pairAddress,
      reserveA: token0IsTokenA ? reserves.$1 : reserves.$2,
      reserveB: token0IsTokenA ? reserves.$2 : reserves.$1,
    );
  }

  void _handleAmountChanged(_AmountField field) {
    if (_isAutoSyncingAmounts) return;
    if (_poolExists != true) return;

    if (field == _AmountField.a) {
      _syncCounterAmount(
        sourceController: _amountAController,
        targetController: _amountBController,
        sourceToken: _tokenA,
        targetToken: _tokenB,
        sourceReserve: _reserveA,
        targetReserve: _reserveB,
      );
      return;
    }

    _syncCounterAmount(
      sourceController: _amountBController,
      targetController: _amountAController,
      sourceToken: _tokenB,
      targetToken: _tokenA,
      sourceReserve: _reserveB,
      targetReserve: _reserveA,
    );
  }

  void _syncAmountsFromExistingPool() {
    if (_poolExists != true) return;
    if (_amountAController.text.trim().isNotEmpty) {
      _syncCounterAmount(
        sourceController: _amountAController,
        targetController: _amountBController,
        sourceToken: _tokenA,
        targetToken: _tokenB,
        sourceReserve: _reserveA,
        targetReserve: _reserveB,
      );
      return;
    }
    if (_amountBController.text.trim().isNotEmpty) {
      _syncCounterAmount(
        sourceController: _amountBController,
        targetController: _amountAController,
        sourceToken: _tokenB,
        targetToken: _tokenA,
        sourceReserve: _reserveB,
        targetReserve: _reserveA,
      );
    }
  }

  void _syncCounterAmount({
    required TextEditingController sourceController,
    required TextEditingController targetController,
    required Token? sourceToken,
    required Token? targetToken,
    required BigInt? sourceReserve,
    required BigInt? targetReserve,
  }) {
    if (sourceToken == null || targetToken == null) return;
    if (sourceReserve == null ||
        targetReserve == null ||
        sourceReserve <= BigInt.zero ||
        targetReserve <= BigInt.zero) {
      return;
    }

    final sourceText = sourceController.text.trim();
    if (sourceText.isEmpty) {
      if (targetController.text.isEmpty) return;
      _setControllerText(targetController, '');
      return;
    }

    try {
      final web3 = ref.read(web3ServiceProvider);
      final sourceRaw = web3.parseAmountToRaw(sourceText, sourceToken.decimals);
      if (sourceRaw <= BigInt.zero) {
        _setControllerText(targetController, '');
        return;
      }

      final targetRaw = (sourceRaw * targetReserve) ~/ sourceReserve;
      final formatted = AmountUtils.trimTrailingZeros(
        web3.formatAmountFromRaw(targetRaw, targetToken.decimals),
      );
      _setControllerText(targetController, formatted);
    } catch (_) {
      // Ignore partial/invalid numeric input while user is typing.
    }
  }

  void _setControllerText(TextEditingController controller, String text) {
    if (controller.text == text) return;
    _isAutoSyncingAmounts = true;
    controller.value = controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
    _isAutoSyncingAmounts = false;
  }

  String get _existingPairSummaryText {
    final address = _resolvedPairAddress;
    if (address == null) return '';
    final reserveA = _reserveA;
    final reserveB = _reserveB;
    if (reserveA == null ||
        reserveB == null ||
        reserveA <= BigInt.zero ||
        reserveB <= BigInt.zero ||
        _tokenA == null ||
        _tokenB == null) {
      return 'Existing pair: ${_shortAddress(address)}';
    }

    final web3 = ref.read(web3ServiceProvider);
    final formattedReserveA = AmountUtils.formatCompactToken(
      web3.formatAmountFromRaw(reserveA, _tokenA!.decimals),
    );
    final formattedReserveB = AmountUtils.formatCompactToken(
      web3.formatAmountFromRaw(reserveB, _tokenB!.decimals),
    );

    return 'Existing pair: ${_shortAddress(address)}  •  Ratio $formattedReserveA:${formattedReserveB}';
  }

  String? _validateAvailableBalances({
    required Token tokenA,
    required Token tokenB,
    required BigInt rawA,
    required BigInt rawB,
  }) {
    final tokenABalanceRaw = _tokenBalanceToRaw(tokenA);
    final tokenBBalanceRaw = _tokenBalanceToRaw(tokenB);

    if (tokenABalanceRaw != null && rawA > tokenABalanceRaw) {
      return 'Amount A exceeds your available ${tokenA.symbol.toUpperCase()} balance.';
    }
    if (tokenBBalanceRaw != null && rawB > tokenBBalanceRaw) {
      return 'Amount B exceeds your available ${tokenB.symbol.toUpperCase()} balance.';
    }
    return null;
  }

  BigInt? _tokenBalanceToRaw(Token token) {
    final balance = token.balance.trim();
    if (balance.isEmpty) return null;
    try {
      return ref
          .read(web3ServiceProvider)
          .parseAmountToRaw(balance, token.decimals);
    } catch (_) {
      return null;
    }
  }

  static String _factoryPairTokenAddress(Token token) {
    if (_isNative(token)) return DexConfig.wrappedReefAddress;
    return token.address;
  }

  static bool _looksLikeUserRejection(Object error) {
    final normalized = error.toString().toLowerCase();
    return normalized.contains('rejected before broadcast') ||
        normalized.contains('transaction rejected') ||
        normalized.contains('cancelled by user') ||
        normalized.contains('canceled by user') ||
        normalized.contains('user rejected');
  }

  static int _compareNormalizedAddresses(String left, String right) {
    return left.compareTo(right);
  }
}

class _PoolResolution {
  const _PoolResolution({
    required this.exists,
    this.pairAddress,
    this.reserveA,
    this.reserveB,
  });

  final bool exists;
  final String? pairAddress;
  final BigInt? reserveA;
  final BigInt? reserveB;
}

enum _AmountField { a, b }
