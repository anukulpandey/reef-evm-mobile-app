import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../core/config/dex_config.dart';
import '../core/theme/reef_theme_colors.dart';
import '../core/theme/styles.dart';
import '../models/account.dart';
import '../models/pool.dart';
import '../models/pool_transaction.dart';
import '../models/transaction_preview.dart';
import '../providers/pool_provider.dart';
import '../providers/service_providers.dart';
import '../providers/wallet_provider.dart';
import '../utils/address_utils.dart';
import '../utils/amount_utils.dart';
import '../utils/transaction_error_mapper.dart';
import '../widgets/common/always_visible_slider_thumb_shape.dart';
import '../widgets/blurable_content.dart';
import '../widgets/common/reef_loading_widgets.dart';
import '../widgets/common/token_avatar.dart';
import '../widgets/send/send_amount_slider.dart';
import 'transaction_confirmation_screen.dart';

enum _ChartMetric { price, volume, liquidity, fees }

enum _ChartTimeframe { h1, d1, w1, m1 }

class PoolDetailScreen extends ConsumerStatefulWidget {
  const PoolDetailScreen({
    super.key,
    required this.pool,
    this.swapOnly = false,
  });

  final Pool pool;
  final bool swapOnly;

  @override
  ConsumerState<PoolDetailScreen> createState() => _PoolDetailScreenState();
}

class _PoolDetailScreenState extends ConsumerState<PoolDetailScreen> {
  ReefThemeColors get _themeColors => context.reefColors;
  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;
  Color get _screenBg => _themeColors.deepBackground;
  Color get _cardBg => _themeColors.cardBackground;
  Color get _cardBgAlt => _themeColors.cardBackgroundSecondary;
  Color get _cardBorder => _themeColors.borderColor;
  Color get _titleText => _themeColors.textPrimary;
  Color get _bodyText => _themeColors.textSecondary;
  Color get _mutedText => _themeColors.textMuted;
  Color get _inputBg => _themeColors.inputFill;
  Color get _inputBorder => _themeColors.inputBorder;
  Color get _accent => _themeColors.accent;
  Color get _headerTitleColor => Colors.white;
  Color get _swapSurface => _isDarkTheme ? const Color(0xFF251343) : _cardBg;
  Color get _swapSurfaceAlt =>
      _isDarkTheme ? const Color(0xFF3C2A5F) : _cardBgAlt;
  Color get _swapFieldFill => _isDarkTheme ? const Color(0xFF352254) : _inputBg;
  Color get _swapBorder => _isDarkTheme ? const Color(0xFF4D3478) : _cardBorder;
  Color get _swapFieldBorder =>
      _isDarkTheme ? const Color(0xFF7550AB) : _inputBorder;
  Color get _swapHint => _isDarkTheme ? const Color(0xFFB8AAD6) : _mutedText;
  Color get _swapButtonDisabled => _isDarkTheme
      ? const Color(0xFF6C5A92)
      : _themeColors.textMuted.withOpacity(0.45);

  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  Timer? _quoteDebounce;
  int _quoteRequestId = 0;

  _ChartMetric _chartMetric = _ChartMetric.price;
  _ChartTimeframe _chartTimeframe = _ChartTimeframe.d1;
  bool _inputToken0 = true;

  bool _isLoadingQuote = false;
  bool _isSubmittingSwap = false;
  bool _isApproving = false;
  bool _allowanceEnough = true;
  double _slippagePercent = DexConfig.defaultSlippagePercent;

  BigInt _inputRaw = BigInt.zero;
  BigInt _quotedOutRaw = BigInt.zero;
  String _quotedOutDisplay = '0';
  String? _swapError;
  String? _quoteNote;
  String? _lastTxHash;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
    _amountFocusNode.addListener(_onAmountFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleQuoteRefresh(immediate: true);
    });
  }

  @override
  void dispose() {
    _quoteDebounce?.cancel();
    _amountController
      ..removeListener(_onAmountChanged)
      ..dispose();
    _amountFocusNode
      ..removeListener(_onAmountFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    _scheduleQuoteRefresh();
  }

  void _onAmountFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  _PoolAsset get _assetIn => _inputToken0
      ? _PoolAsset.fromPool(widget.pool, isToken0: true)
      : _PoolAsset.fromPool(widget.pool, isToken0: false);

  _PoolAsset get _assetOut => _inputToken0
      ? _PoolAsset.fromPool(widget.pool, isToken0: false)
      : _PoolAsset.fromPool(widget.pool, isToken0: true);

  void _scheduleQuoteRefresh({bool immediate = false}) {
    _quoteDebounce?.cancel();
    if (immediate) {
      unawaited(_refreshQuoteAndAllowance());
      return;
    }

    final hasAmount = _amountController.text.trim().isNotEmpty;
    if (mounted) {
      setState(() {
        _swapError = null;
        _quoteNote = null;
        _isLoadingQuote = hasAmount;
      });
    }

    _quoteDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_refreshQuoteAndAllowance());
    });
  }

  Future<void> _refreshQuoteAndAllowance() async {
    final reqId = ++_quoteRequestId;
    final web3 = ref.read(web3ServiceProvider);
    final walletState = ref.read(walletProvider);
    final account = walletState.activeAccount;
    final amount = _amountController.text.trim();
    final inAsset = _assetIn;
    final outAsset = _assetOut;

    if (amount.isEmpty || account == null) {
      if (!mounted || reqId != _quoteRequestId) return;
      setState(() {
        _inputRaw = BigInt.zero;
        _quotedOutRaw = BigInt.zero;
        _quotedOutDisplay = '0';
        _isLoadingQuote = false;
        _allowanceEnough = true;
        _quoteNote = null;
      });
      return;
    }

    BigInt rawIn;
    try {
      rawIn = web3.parseAmountToRaw(amount, inAsset.decimals);
    } catch (_) {
      if (!mounted || reqId != _quoteRequestId) return;
      setState(() {
        _inputRaw = BigInt.zero;
        _quotedOutRaw = BigInt.zero;
        _quotedOutDisplay = '0';
        _isLoadingQuote = false;
        _quoteNote = null;
      });
      return;
    }

    if (rawIn <= BigInt.zero) {
      if (!mounted || reqId != _quoteRequestId) return;
      setState(() {
        _inputRaw = BigInt.zero;
        _quotedOutRaw = BigInt.zero;
        _quotedOutDisplay = '0';
        _isLoadingQuote = false;
        _quoteNote = null;
      });
      return;
    }

    setState(() {
      _inputRaw = rawIn;
      _isLoadingQuote = true;
      _swapError = null;
      _quoteNote = null;
    });

    try {
      final useDirectPair = _canUseDirectPairSwap(inAsset, outAsset);
      final path = <String>[inAsset.routerAddress, outAsset.routerAddress];

      BigInt outRaw;
      String? quoteNote;
      try {
        outRaw = await web3.getAmountsOut(
          routerAddress: DexConfig.routerAddress,
          amountIn: rawIn,
          path: path,
        );
        if (outRaw <= BigInt.zero) {
          throw Exception('No route found on router for this pair and amount.');
        }
      } catch (_) {
        try {
          outRaw = await _quoteDirectPairSwap(
            amountIn: rawIn,
            inAsset: inAsset,
            outAsset: outAsset,
          );
          if (outRaw <= BigInt.zero) {
            throw Exception('No route found for this pair and amount.');
          }
          quoteNote = 'Router quote unavailable; using pool reserve fallback.';
        } catch (_) {
          if (!mounted || reqId != _quoteRequestId) return;
          setState(() {
            _quotedOutRaw = BigInt.zero;
            _quotedOutDisplay = '0';
            _allowanceEnough = useDirectPair;
            _isLoadingQuote = false;
            _quoteNote = null;
            _swapError = 'No route found for this pair and amount.';
          });
          return;
        }
      }

      var hasAllowance = useDirectPair;
      if (!useDirectPair) {
        try {
          final allowance = await web3.getErc20Allowance(
            tokenAddress: inAsset.address,
            owner: account.address,
            spender: DexConfig.routerAddress,
          );
          hasAllowance = allowance >= rawIn;
        } catch (_) {
          hasAllowance = false;
        }
      }

      if (!mounted || reqId != _quoteRequestId) return;
      setState(() {
        _quotedOutRaw = outRaw;
        _quotedOutDisplay = web3.formatAmountFromRaw(outRaw, outAsset.decimals);
        _allowanceEnough = hasAllowance;
        _isLoadingQuote = false;
        _quoteNote = quoteNote;
      });
    } catch (e) {
      if (!mounted || reqId != _quoteRequestId) return;
      setState(() {
        _quotedOutRaw = BigInt.zero;
        _quotedOutDisplay = '0';
        _allowanceEnough = _canUseDirectPairSwap(inAsset, outAsset);
        _isLoadingQuote = false;
        _quoteNote = null;
        _swapError = 'No route found for this pair and amount.';
      });
    }
  }

  Future<void> _approveIfNeeded() async {
    final walletState = ref.read(walletProvider);
    final account = walletState.activeAccount;
    final inAsset = _assetIn;
    if (account == null || inAsset.isNative) return;
    final approvalAmount = _inputRaw > BigInt.zero ? _inputRaw : BigInt.one;
    final preview = await _buildApprovePreview(
      ownerAddress: account.address,
      inAsset: inAsset,
      approvalAmount: approvalAmount,
    );
    if (!mounted) return;

    final result = await Navigator.of(context).push<TransactionApprovalResult>(
      MaterialPageRoute(
        builder: (_) => TransactionConfirmationScreen(
          preview: preview,
          approveButtonText: 'Approve',
          rejectButtonText: 'Reject',
          onApprove: () async {
            if (mounted) {
              setState(() {
                _isApproving = true;
                _swapError = null;
                _quoteNote = null;
              });
            }
            try {
              return await ref
                  .read(web3ServiceProvider)
                  .approveErc20(
                    account: account,
                    tokenAddress: inAsset.address,
                    spender: DexConfig.routerAddress,
                    amount: approvalAmount,
                  );
            } finally {
              if (mounted) {
                setState(() => _isApproving = false);
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

    try {
      setState(() {
        _lastTxHash = result.txHash;
      });
      await _refreshQuoteAndAllowance();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approval submitted: ${_shortHash(result.txHash!)}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final userError = TransactionErrorMapper.fromThrowable(e);
      setState(() {
        _swapError = userError.message;
      });
    }
  }

  Future<void> _executeSwap() async {
    final walletState = ref.read(walletProvider);
    final account = walletState.activeAccount;
    if (account == null) return;
    if (_inputRaw <= BigInt.zero || _quotedOutRaw <= BigInt.zero) return;

    final inAsset = _assetIn;
    final outAsset = _assetOut;
    final useDirectPair = _canUseDirectPairSwap(inAsset, outAsset);
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final deadline = BigInt.from(
      nowSec + (DexConfig.defaultDeadlineMinutes * 60),
    );
    final slippageBps = BigInt.from((_slippagePercent * 100).round());
    final amountOutMin =
        _quotedOutRaw - ((_quotedOutRaw * slippageBps) ~/ BigInt.from(10000));
    final path = <String>[inAsset.routerAddress, outAsset.routerAddress];
    final preview = await _buildSwapPreview(
      accountAddress: account.address,
      inAsset: inAsset,
      outAsset: outAsset,
      amountOutMin: amountOutMin,
      deadline: deadline,
      path: path,
      useDirectPair: useDirectPair,
    );
    if (!mounted) return;

    final result = await Navigator.of(context).push<TransactionApprovalResult>(
      MaterialPageRoute(
        builder: (_) => TransactionConfirmationScreen(
          preview: preview,
          approveButtonText: 'Approve Swap',
          rejectButtonText: 'Reject',
          onApprove: () async {
            if (mounted) {
              setState(() {
                _isSubmittingSwap = true;
                _swapError = null;
                _quoteNote = null;
              });
            }
            try {
              final web3 = ref.read(web3ServiceProvider);
              if (useDirectPair) {
                return await _executeDirectPairSwap(
                  account: account,
                  inAsset: inAsset,
                  outAsset: outAsset,
                  amountOutMin: amountOutMin,
                );
              }
              return await web3.swapExactTokensForTokens(
                account: account,
                routerAddress: DexConfig.routerAddress,
                amountIn: _inputRaw,
                amountOutMin: amountOutMin,
                path: path,
                to: account.address,
                deadline: deadline,
              );
            } finally {
              if (mounted) {
                setState(() => _isSubmittingSwap = false);
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

    setState(() {
      _lastTxHash = result.txHash;
      _amountController.clear();
      _quotedOutRaw = BigInt.zero;
      _quotedOutDisplay = '0';
    });
    ref.invalidate(walletProvider);
    ref.invalidate(poolsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Swap submitted: ${_shortHash(result.txHash!)}')),
    );
  }

  Future<String> _executeDirectPairSwap({
    required Account account,
    required _PoolAsset inAsset,
    required _PoolAsset outAsset,
    required BigInt amountOutMin,
  }) async {
    final web3 = ref.read(web3ServiceProvider);
    final pairAddress = widget.pool.id;
    if (pairAddress.trim().isEmpty) {
      throw Exception('Direct pair swap is unavailable for this pool.');
    }

    final (reserve0, reserve1) = await web3.getPairReservesRaw(
      pairAddress: pairAddress,
    );
    var transferAmount = _inputRaw;
    if (inAsset.isCanonicalReef) {
      final wrappedBalance = await web3.getErc20BalanceRaw(
        tokenAddress: inAsset.address,
        owner: account.address,
      );
      if (wrappedBalance < transferAmount) {
        final wrapAmount = transferAmount - wrappedBalance;
        final wrapHash = await web3.wrapNative(
          account: account,
          wrappedTokenAddress: inAsset.address,
          amountWei: wrapAmount,
        );
        await web3.waitForReceipt(wrapHash);
      }
    }

    final inputIsToken0 =
        widget.pool.token0Address.toLowerCase() ==
        inAsset.address.toLowerCase();
    final reserveIn = inputIsToken0 ? reserve0 : reserve1;
    final reserveOut = inputIsToken0 ? reserve1 : reserve0;
    final quotedOut = _getAmountOutRaw(transferAmount, reserveIn, reserveOut);
    if (quotedOut <= BigInt.zero) {
      throw Exception('No output amount available for this pool.');
    }
    final slippageBps = BigInt.from((_slippagePercent * 100).round());
    final discountedOut =
        quotedOut - ((quotedOut * slippageBps) ~/ BigInt.from(10000));
    final amountOut = discountedOut > BigInt.zero ? discountedOut : quotedOut;
    final amount0Out = inputIsToken0 ? BigInt.zero : amountOut;
    final amount1Out = inputIsToken0 ? amountOut : BigInt.zero;

    final transferHash = await web3.transferErc20Raw(
      account: account,
      tokenAddress: inAsset.address,
      to: pairAddress,
      amount: transferAmount,
    );
    await web3.waitForReceipt(transferHash);
    return web3.swapPair(
      account: account,
      pairAddress: pairAddress,
      amount0Out: amount0Out,
      amount1Out: amount1Out,
      to: account.address,
    );
  }

  void _flipPair() {
    setState(() {
      _inputToken0 = !_inputToken0;
      _amountController.clear();
      _inputRaw = BigInt.zero;
      _quotedOutRaw = BigInt.zero;
      _quotedOutDisplay = '0';
      _allowanceEnough = true;
      _swapError = null;
      _quoteNote = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pairLabel =
        '${widget.pool.token0Symbol} / ${widget.pool.token1Symbol}';
    final appBarTitle = widget.swapOnly ? 'Swap $pairLabel' : pairLabel;

    if (widget.swapOnly) {
      final walletState = ref.watch(walletProvider);
      final inAsset = _assetIn;
      final outAsset = _assetOut;
      final inBalance = _balanceForAsset(walletState, inAsset);
      final outBalance = _balanceForAsset(walletState, outAsset);
      final inputBalanceRaw =
          _toRawFromBalance(inBalance, inAsset.decimals) ?? BigInt.zero;
      final useDirectPair = _canUseDirectPairSwap(inAsset, outAsset);
      final hasSufficientBalance =
          _inputRaw == BigInt.zero || _inputRaw <= inputBalanceRaw;
      final canSwap =
          _inputRaw > BigInt.zero &&
          _quotedOutRaw > BigInt.zero &&
          hasSufficientBalance &&
          !_isSubmittingSwap &&
          !_isApproving &&
          !_isLoadingQuote &&
          (_allowanceEnough || useDirectPair);
      final requiresApproval =
          _inputRaw > BigInt.zero && !useDirectPair && !_allowanceEnough;

      return Scaffold(
        backgroundColor: _isDarkTheme
            ? const Color(0xFF1E0B3B)
            : Styles.greyColor,
        appBar: AppBar(
          backgroundColor: _isDarkTheme
              ? const Color(0xFF5A23A5)
              : Colors.deepPurple.shade700,
          elevation: 0,
          centerTitle: false,
          title: Text(
            'Swap Tokens',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
          children: [
            const Gap(24),
            _buildSwapCard(
              inAsset: inAsset,
              outAsset: outAsset,
              inBalance: inBalance,
              outBalance: outBalance,
              requiresApproval: requiresApproval,
              canSwap: canSwap,
              hasSufficientBalance: hasSufficientBalance,
            ),
            if (_swapError != null) ...[
              const Gap(10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _themeColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _themeColors.danger.withOpacity(0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: _themeColors.danger,
                      size: 20,
                    ),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        _swapError!,
                        style: TextStyle(
                          color: _themeColors.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_swapError == null && _quoteNote != null) ...[
              const Gap(8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _quoteNote!,
                  style: TextStyle(
                    color: _bodyText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            if (_lastTxHash != null) ...[
              const Gap(6),
              Text(
                'Last tx: ${_shortHash(_lastTxHash!)}',
                style: TextStyle(color: _bodyText, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      );
    }

    final poolService = ref.read(poolServiceProvider);
    return Scaffold(
      backgroundColor: _screenBg,
      appBar: AppBar(
        backgroundColor: _screenBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          appBarTitle,
          style: TextStyle(
            color: _headerTitleColor,
            fontWeight: FontWeight.w900,
            fontSize: 21,
          ),
        ),
        iconTheme: IconThemeData(color: _headerTitleColor),
      ),
      body: FutureBuilder<List<PoolTransactionEvent>>(
        future: poolService.getPairTransactions(widget.pool.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                _buildPoolHeaderCard(widget.pool),
                const Gap(14),
                const ReefLoadingCard(
                  title: 'Loading pool activity',
                  subtitle:
                      'Fetching chart data and recent transactions for this pair.',
                ),
                const Gap(14),
                _buildTradeCtaCard(),
              ],
            );
          }

          final transactions = snapshot.data ?? const <PoolTransactionEvent>[];
          final chartSeries = _buildChartSeries(transactions, widget.pool);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              _buildPoolHeaderCard(widget.pool),
              const Gap(14),
              _buildChartCard(chartSeries),
              const Gap(14),
              _buildTradeCtaCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTradeCtaCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trade',
            style: TextStyle(
              color: _titleText,
              fontSize: Styles.fsCardTitle,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Gap(6),
          Text(
            'Open swap for this pair in a dedicated screen.',
            style: TextStyle(
              color: _bodyText,
              fontWeight: FontWeight.w600,
              fontSize: Styles.fsCaption,
            ),
          ),
          const Gap(14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openSwapScreen,
              icon: const Icon(
                Icons.swap_horiz_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'Trade This Pair',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: Styles.fsBodyStrong,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _themeColors.accentStrong,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSwapScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PoolDetailScreen(pool: widget.pool, swapOnly: true),
      ),
    );
  }

  Widget _buildPoolHeaderCard(Pool pool) {
    final pairTitle = '${pool.token0Symbol} - ${pool.token1Symbol}';
    final ticker =
        '${pool.token0Symbol.toUpperCase()}/${pool.token1Symbol.toUpperCase()}';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_swapSurface, _swapSurfaceAlt],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _swapBorder),
        boxShadow: [
          BoxShadow(
            color: _isDarkTheme
                ? const Color(0x55070412)
                : const Color(0x220C0418),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TokenPairAvatar(
                  firstIconUrl: pool.tokenIcons.isNotEmpty
                      ? pool.tokenIcons[0]
                      : null,
                  secondIconUrl: pool.tokenIcons.length > 1
                      ? pool.tokenIcons[1]
                      : null,
                  firstSeed: pool.token0Symbol,
                  secondSeed: pool.token1Symbol,
                  avatarSize: 48,
                  overlapOffset: 30,
                  resolveFallbackIcon: true,
                  imageFit: BoxFit.contain,
                  imagePadding: const EdgeInsets.all(4),
                  avatarBackgroundColor: Colors.white,
                ),
                const Gap(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pairTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _titleText,
                          fontWeight: FontWeight.w900,
                          fontSize: 42 / 2,
                          height: 1.05,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        ticker,
                        style: TextStyle(
                          color: _swapHint,
                          fontWeight: FontWeight.w700,
                          fontSize: Styles.fsBodyStrong,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(14),
            Row(
              children: [
                Expanded(
                  child: _metricTile(
                    label: 'TVL',
                    value: AmountUtils.formatShortUsd(pool.reserveUsd),
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: _metricTile(
                    label: '24h Volume',
                    value: AmountUtils.formatShortUsd(pool.volumeUsd),
                  ),
                ),
              ],
            ),
            const Gap(10),
            _rateLine(
              '1 ${pool.token0Symbol} = ${AmountUtils.formatRate(pool.token0Price)} ${pool.token1Symbol}',
            ),
            const Gap(3),
            _rateLine(
              '1 ${pool.token1Symbol} = ${AmountUtils.formatRate(pool.token1Price)} ${pool.token0Symbol}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _swapSurfaceAlt.withOpacity(_isDarkTheme ? 0.88 : 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _swapBorder.withOpacity(0.7), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _swapHint,
              fontWeight: FontWeight.w800,
              fontSize: Styles.fsSmall,
            ),
          ),
          const Gap(2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _titleText,
              fontWeight: FontWeight.w900,
              fontSize: 40 / 2,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rateLine(String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: _bodyText.withOpacity(_isDarkTheme ? 0.96 : 1),
        fontWeight: FontWeight.w800,
        fontSize: Styles.fsBodyStrong,
      ),
    );
  }

  List<BoxShadow> _swapPageCardShadow() {
    if (_isDarkTheme) {
      return const [
        BoxShadow(
          color: Color(0x55080416),
          offset: Offset(10, 10),
          blurRadius: 20,
          spreadRadius: -5,
        ),
        BoxShadow(
          color: Color(0x1E6E35D4),
          offset: Offset(-10, -10),
          blurRadius: 20,
          spreadRadius: -5,
        ),
      ];
    }

    return const [
      BoxShadow(
        color: Color(0x26B9AFD8),
        offset: Offset(10, 10),
        blurRadius: 20,
        spreadRadius: -5,
      ),
      BoxShadow(
        color: Colors.white,
        offset: Offset(-10, -10),
        blurRadius: 20,
        spreadRadius: -5,
      ),
    ];
  }

  Widget _buildChartCard(List<_ChartPoint> points) {
    final maxY = points.isEmpty
        ? 1.0
        : (points
                      .map((e) => e.value)
                      .reduce(math.max)
                      .clamp(1e-9, double.infinity)
                  as num)
              .toDouble();
    final minY = points.isEmpty
        ? 0.0
        : points.map((e) => e.value).reduce(math.min);
    final range = (maxY - minY).abs();
    final pad = range == 0 ? maxY * 0.15 : range * 0.2;
    final chartMinY = (minY - pad).clamp(0.0, double.infinity);
    final chartMaxY = maxY + pad;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pool Chart',
              style: TextStyle(
                color: _titleText,
                fontWeight: FontWeight.w900,
                fontSize: Styles.fsSectionTitle,
              ),
            ),
            const Gap(10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _ChartMetric.values.map((metric) {
                final selected = metric == _chartMetric;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _chartMetric = metric),
                  label: Text(_chartMetricLabel(metric)),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : _bodyText,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedColor: _accent,
                  backgroundColor: _cardBgAlt,
                );
              }).toList(),
            ),
            const Gap(8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _ChartTimeframe.values.map((frame) {
                final selected = frame == _chartTimeframe;
                return OutlinedButton(
                  onPressed: () => setState(() => _chartTimeframe = frame),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: selected
                          ? _accent
                          : _themeColors.borderColor.withOpacity(0.7),
                    ),
                    foregroundColor: selected
                        ? _themeColors.textSecondary
                        : _bodyText,
                    backgroundColor: selected
                        ? _themeColors.accentStrong.withOpacity(0.3)
                        : _themeColors.inputFill.withOpacity(0.18),
                    visualDensity: const VisualDensity(
                      horizontal: -3,
                      vertical: -3,
                    ),
                    minimumSize: const Size(52, 32),
                  ),
                  child: Text(_chartTimeframeLabel(frame)),
                );
              }).toList(),
            ),
            const Gap(10),
            SizedBox(
              height: 220,
              child: points.isEmpty
                  ? Center(
                      child: Text(
                        'No chart data yet.',
                        style: TextStyle(
                          color: _mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minY: chartMinY,
                        maxY: chartMaxY,
                        minX: 0,
                        maxX: (points.length - 1).toDouble(),
                        clipData: const FlClipData.all(),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: (chartMaxY - chartMinY) / 4,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: _themeColors.borderColor.withOpacity(0.4),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 54,
                              interval: (chartMaxY - chartMinY) / 3,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  _formatChartValue(value),
                                  style: TextStyle(
                                    color: _mutedText,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: (math.max(
                                1.0,
                                points.length / 4,
                              )).toDouble(),
                              getTitlesWidget: (value, meta) {
                                final idx = value.round();
                                if (idx < 0 || idx >= points.length) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  _formatChartTime(points[idx].timestamp),
                                  style: TextStyle(
                                    color: _mutedText,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List<FlSpot>.generate(
                              points.length,
                              (idx) =>
                                  FlSpot(idx.toDouble(), points[idx].value),
                            ),
                            isCurved: true,
                            color: const Color(0xFFB84CFF),
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x77B84CFF), Color(0x00B84CFF)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwapCard({
    required _PoolAsset inAsset,
    required _PoolAsset outAsset,
    required String inBalance,
    required String outBalance,
    required bool requiresApproval,
    required bool canSwap,
    required bool hasSufficientBalance,
  }) {
    final inputBalanceRaw =
        _toRawFromBalance(inBalance, inAsset.decimals) ?? BigInt.zero;
    final sliderValue = inputBalanceRaw > BigInt.zero && _inputRaw > BigInt.zero
        ? (_inputRaw.toDouble() / inputBalanceRaw.toDouble()).clamp(0.0, 1.0)
        : 0.0;
    final isEnabled = requiresApproval ? !_isApproving : canSwap;

    return Container(
      decoration: BoxDecoration(
        color: _isDarkTheme
            ? const Color(0xFF251343)
            : Styles.primaryBackgroundColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: _swapPageCardShadow(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSwapTokenField(
              asset: inAsset,
              balance: inBalance,
              amountText: _amountController.text,
              focusNode: _amountFocusNode,
              showMaxButton: true,
              onTapMax: () {
                _amountController.text = _maxInputAmount(inBalance);
              },
            ),
            const Gap(16),
            Row(
              children: [
                GestureDetector(
                  onTap: _flipPair,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color:
                          _quotedOutRaw > BigInt.zero ||
                              _inputRaw == BigInt.zero
                          ? null
                          : _swapFieldFill,
                      gradient:
                          _quotedOutRaw > BigInt.zero ||
                              _inputRaw == BigInt.zero
                          ? const LinearGradient(
                              colors: [Color(0xFFAE27A5), Color(0xFF742CB2)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : null,
                    ),
                    child: Icon(
                      Icons.repeat_rounded,
                      size: 20,
                      color:
                          _quotedOutRaw > BigInt.zero ||
                              _inputRaw == BigInt.zero
                          ? Colors.white
                          : _swapHint,
                    ),
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: SendAmountSlider(
                    value: sliderValue,
                    enabled: !_isSubmittingSwap && !_isApproving,
                    onChanged: (value) => _setSwapAmountFromSlider(
                      balance: inBalance,
                      ratio: value,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(16),
            _buildSwapTokenField(
              asset: outAsset,
              balance: outBalance,
              amountText: _quotedOutDisplay,
              readOnly: true,
            ),
            const Gap(16),
            _buildSlippageSlider(),
            const Gap(16),
            _buildSwapSummary(
              inAsset: inAsset,
              outAsset: outAsset,
              inputAmount: _amountController.text,
            ),
            if (_isLoadingQuote) ...[
              const Gap(14),
              LinearProgressIndicator(
                minHeight: 2,
                color: _accent,
                backgroundColor: _swapSurfaceAlt.withOpacity(0.7),
              ),
            ],
            const Gap(16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: requiresApproval
                    ? (_isApproving ? null : _approveIfNeeded)
                    : (canSwap ? _executeSwap : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: EdgeInsets.zero,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                ),
                child: Ink(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    color: isEnabled ? null : _swapButtonDisabled,
                    gradient: isEnabled
                        ? const LinearGradient(
                            colors: [Color(0xFFAE27A5), Color(0xFF742CB2)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 22,
                    ),
                    child: Text(
                      requiresApproval
                          ? (_isApproving
                                ? 'Approving...'
                                : 'Approve ${inAsset.symbol}')
                          : (!hasSufficientBalance
                                ? 'Insufficient ${inAsset.symbol}'
                                : (_isSubmittingSwap ? 'Swapping...' : 'Swap')),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(isEnabled ? 1 : 0.92),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwapTokenField({
    required _PoolAsset asset,
    required String balance,
    required String amountText,
    FocusNode? focusNode,
    VoidCallback? onTapMax,
    bool readOnly = false,
    bool showMaxButton = false,
  }) {
    final showBalance = ref.watch(
      walletProvider.select((state) => state.showBalance),
    );
    final isFocused = focusNode?.hasFocus ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFocused
            ? (_isDarkTheme ? _swapFieldFill : const Color(0xFFEEEBF6))
            : _swapSurfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused ? const Color(0xFFA328AB) : Colors.transparent,
        ),
        boxShadow: [
          if (isFocused)
            const BoxShadow(
              blurRadius: 15,
              spreadRadius: -8,
              offset: Offset(0, 10),
              color: Color(0x40A328AB),
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              TokenAvatar(
                size: 48,
                iconUrl: asset.iconUrl,
                fallbackSeed: asset.symbol,
                resolveFallbackIcon: true,
                useDeterministicFallback: true,
                imageFit: BoxFit.contain,
                imagePadding: const EdgeInsets.all(4),
                avatarBackgroundColor: Colors.white,
              ),
              const Gap(13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _titleText,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const Gap(2),
                    BlurableContent(
                      showContent: showBalance,
                      child: Text(
                        '${AmountUtils.formatCompactToken(balance)} ${asset.symbol}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _swapHint,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: readOnly
                    ? BlurableContent(
                        showContent: showBalance,
                        child: Text(
                          '${AmountUtils.trimTrailingZeros(amountText)} ${asset.symbol}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: _titleText,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      )
                    : TextField(
                        focusNode: focusNode,
                        controller: _amountController,
                        readOnly: _isSubmittingSwap || _isApproving,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: _titleText,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          enabledBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          hintText: '0.0',
                          hintStyle: TextStyle(
                            color: _swapHint,
                            fontWeight: FontWeight.w600,
                          ),
                          suffixIcon: onTapMax == null
                              ? null
                              : IconButton(
                                  onPressed: onTapMax,
                                  splashRadius: 18,
                                  icon: Icon(
                                    Icons.auto_fix_high_rounded,
                                    color: _accent,
                                    size: 22,
                                  ),
                                ),
                        ),
                      ),
              ),
            ],
          ),
          if (showMaxButton) ...[
            const Gap(8),
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  BlurableContent(
                    showContent: showBalance,
                    child: Text(
                      'Balance: ${_formatBalanceText(balance)} ${asset.symbol}',
                      style: TextStyle(
                        color: _swapHint,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onTapMax != null)
                    TextButton(
                      onPressed: onTapMax,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(30, 10),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Max',
                        style: TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _setSwapAmountFromSlider({
    required String balance,
    required double ratio,
  }) {
    final parsedBalance = AmountUtils.parseNumeric(balance);
    if (parsedBalance <= 0 || ratio <= 0) {
      _amountController.text = '0';
      return;
    }
    final amount = parsedBalance * ratio;
    _amountController.text = AmountUtils.formatInputAmount(
      amount,
      decimals: amount >= 10 ? 4 : 6,
    );
  }

  Widget _buildSwapSummary({
    required _PoolAsset inAsset,
    required _PoolAsset outAsset,
    required String inputAmount,
  }) {
    final rate = _inputToken0
        ? AmountUtils.formatRate(widget.pool.token0Price)
        : AmountUtils.formatRate(widget.pool.token1Price);
    final inputValue = AmountUtils.parseNumeric(inputAmount);
    final inputUsdPrice = _inputToken0
        ? widget.pool.token0Price
        : widget.pool.token1Price;
    final estimatedFeeUsd = math.max(inputValue * inputUsdPrice * 0.003, 0);
    final slippage = '${_slippagePercent.toStringAsFixed(2)}%';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: _swapSurfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _buildSwapSummaryRow(
            label: 'Rate',
            value: '1 ${inAsset.symbol} = $rate ${outAsset.symbol}',
          ),
          const Gap(8),
          _buildSwapSummaryRow(
            label: 'Fee',
            value: '\$${estimatedFeeUsd.toStringAsFixed(4)}',
          ),
          const Gap(8),
          _buildSwapSummaryRow(label: 'Slippage', value: slippage),
        ],
      ),
    );
  }

  Widget _buildSwapSummaryRow({required String label, required String value}) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: _accent,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _titleText,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlippageSlider() {
    return Row(
      children: [
        Text(
          'Slippage :',
          style: TextStyle(
            color: _swapHint,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              showValueIndicator: ShowValueIndicator.never,
              overlayShape: SliderComponentShape.noOverlay,
              valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
              valueIndicatorColor: _themeColors.accentStrong,
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              thumbColor: _themeColors.accentStrong,
              inactiveTrackColor: _themeColors.inputBorder.withOpacity(0.32),
              activeTrackColor: _themeColors.accent,
              inactiveTickMarkColor: _themeColors.inputBorder.withOpacity(0.45),
              activeTickMarkColor: Colors.white,
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3),
              thumbShape: const AlwaysVisibleSliderThumbShape(),
              disabledInactiveTrackColor: _themeColors.inputBorder.withOpacity(
                0.18,
              ),
              disabledActiveTrackColor: _themeColors.accentStrong.withOpacity(
                0.2,
              ),
            ),
            child: Slider(
              value: _slippagePercent.clamp(0.0, 20.0),
              min: 0,
              max: 20,
              divisions: 200,
              label: '${_slippagePercent.toStringAsFixed(1)}%',
              onChanged: (_isSubmittingSwap || _isApproving)
                  ? null
                  : (value) => setState(() => _slippagePercent = value),
            ),
          ),
        ),
      ],
    );
  }

  String _formatBalanceText(String balance) {
    final parsed = AmountUtils.parseNumeric(balance);
    if (parsed <= 0) return '0';
    return AmountUtils.formatInputAmount(
      parsed,
      decimals: parsed >= 10 ? 4 : 6,
    );
  }

  bool _canUseDirectPairSwap(_PoolAsset inAsset, _PoolAsset outAsset) {
    return widget.pool.id.trim().isNotEmpty &&
        inAsset.address.trim().isNotEmpty &&
        outAsset.address.trim().isNotEmpty &&
        inAsset.address.toLowerCase() != outAsset.address.toLowerCase();
  }

  Future<BigInt> _quoteDirectPairSwap({
    required BigInt amountIn,
    required _PoolAsset inAsset,
    required _PoolAsset outAsset,
  }) async {
    if (amountIn <= BigInt.zero) return BigInt.zero;

    final web3 = ref.read(web3ServiceProvider);
    final (reserve0, reserve1) = await web3.getPairReservesRaw(
      pairAddress: widget.pool.id,
    );
    final inputIsToken0 =
        widget.pool.token0Address.toLowerCase() ==
        inAsset.address.toLowerCase();
    final reserveIn = inputIsToken0 ? reserve0 : reserve1;
    final reserveOut = inputIsToken0 ? reserve1 : reserve0;
    return _getAmountOutRaw(amountIn, reserveIn, reserveOut);
  }

  BigInt _getAmountOutRaw(
    BigInt amountIn,
    BigInt reserveIn,
    BigInt reserveOut,
  ) {
    if (amountIn <= BigInt.zero ||
        reserveIn <= BigInt.zero ||
        reserveOut <= BigInt.zero) {
      return BigInt.zero;
    }
    final amountInWithFee = amountIn * BigInt.from(997);
    final numerator = amountInWithFee * reserveOut;
    final denominator = (reserveIn * BigInt.from(1000)) + amountInWithFee;
    if (denominator <= BigInt.zero) return BigInt.zero;
    return numerator ~/ denominator;
  }

  List<_ChartPoint> _buildChartSeries(
    List<PoolTransactionEvent> transactions,
    Pool pool,
  ) {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final lookback = switch (_chartTimeframe) {
      _ChartTimeframe.h1 => 60 * 60,
      _ChartTimeframe.d1 => 24 * 60 * 60,
      _ChartTimeframe.w1 => 7 * 24 * 60 * 60,
      _ChartTimeframe.m1 => 30 * 24 * 60 * 60,
    };
    final bucket = switch (_chartTimeframe) {
      _ChartTimeframe.h1 => 2 * 60,
      _ChartTimeframe.d1 => 15 * 60,
      _ChartTimeframe.w1 => 2 * 60 * 60,
      _ChartTimeframe.m1 => 6 * 60 * 60,
    };
    final start = nowSec - lookback;

    if (_chartMetric == _ChartMetric.price) {
      final points = transactions
          .where(
            (tx) =>
                tx.type == PoolTransactionType.swap && tx.timestamp >= start,
          )
          .map((tx) {
            final price = tx.token0Amount > 0
                ? tx.token1Amount / tx.token0Amount
                : 0.0;
            return _ChartPoint(tx.timestamp, price);
          })
          .where((it) => it.value.isFinite && it.value > 0)
          .toList();

      if (points.isEmpty) {
        final fallback = (pool.token0Price > 0 ? pool.token0Price : 0)
            .toDouble();
        return <_ChartPoint>[
          _ChartPoint(start, fallback),
          _ChartPoint(nowSec, fallback),
        ];
      }
      return _withContinuity(_aggregateLast(points, bucket), start, nowSec);
    }

    final byBucket = <int, double>{};
    double rollingLiquidity = pool.reserveUsd;
    final liqPoints = <_ChartPoint>[];

    for (final tx in transactions.where((t) => t.timestamp >= start)) {
      final bucketTs = (tx.timestamp ~/ bucket) * bucket;
      final usd = tx.usdAmount > 0 ? tx.usdAmount : 0;
      if (_chartMetric == _ChartMetric.volume) {
        byBucket[bucketTs] = (byBucket[bucketTs] ?? 0) + usd;
      } else if (_chartMetric == _ChartMetric.fees) {
        byBucket[bucketTs] = (byBucket[bucketTs] ?? 0) + (usd * 0.003);
      } else if (_chartMetric == _ChartMetric.liquidity) {
        if (tx.type == PoolTransactionType.mint) {
          rollingLiquidity += usd;
        } else if (tx.type == PoolTransactionType.burn) {
          rollingLiquidity = math.max(0, rollingLiquidity - usd);
        }
        liqPoints.add(_ChartPoint(bucketTs, rollingLiquidity));
      }
    }

    if (_chartMetric == _ChartMetric.liquidity) {
      final aggregated = _aggregateLast(liqPoints, bucket);
      if (aggregated.isEmpty) {
        return <_ChartPoint>[
          _ChartPoint(start, pool.reserveUsd),
          _ChartPoint(nowSec, pool.reserveUsd),
        ];
      }
      return _withContinuity(aggregated, start, nowSec);
    }

    final points =
        byBucket.entries.map((e) => _ChartPoint(e.key, e.value)).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return _withVolumeShape(points, start, nowSec, bucket);
  }

  static List<_ChartPoint> _aggregateLast(
    List<_ChartPoint> points,
    int bucketSeconds,
  ) {
    if (points.isEmpty) return const <_ChartPoint>[];
    final buckets = <int, double>{};
    for (final point in points) {
      final bucketTs = (point.timestamp ~/ bucketSeconds) * bucketSeconds;
      buckets[bucketTs] = point.value;
    }
    final out = buckets.entries.map((e) => _ChartPoint(e.key, e.value)).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return out;
  }

  static List<_ChartPoint> _withContinuity(
    List<_ChartPoint> points,
    int start,
    int end,
  ) {
    if (points.isEmpty) return const <_ChartPoint>[];
    final out = <_ChartPoint>[];
    final first = points.first;
    if (first.timestamp > start) {
      out.add(_ChartPoint(start, first.value));
    }
    out.addAll(points);
    final last = points.last;
    if (last.timestamp < end) {
      out.add(_ChartPoint(end, last.value));
    }
    return out;
  }

  static List<_ChartPoint> _withVolumeShape(
    List<_ChartPoint> points,
    int start,
    int end,
    int bucket,
  ) {
    final out = <_ChartPoint>[_ChartPoint(start, 0)];
    if (points.isNotEmpty) {
      var cursor = (start ~/ bucket) * bucket;
      final map = <int, double>{for (final p in points) p.timestamp: p.value};
      while (cursor <= end) {
        out.add(_ChartPoint(cursor, map[cursor] ?? 0));
        cursor += bucket;
      }
    }
    out.add(_ChartPoint(end, 0));
    return out;
  }

  String _balanceForAsset(WalletState state, _PoolAsset asset) {
    if (asset.isCanonicalReef) {
      final nativeBalance = AmountUtils.parseNumeric(state.balance);
      final wrappedBalance = state.portfolioTokens
          .where(
            (token) =>
                token.address.toLowerCase() == asset.address.toLowerCase(),
          )
          .fold<double>(
            0,
            (sum, token) => sum + AmountUtils.parseNumeric(token.balance),
          );
      return AmountUtils.formatInputAmount(
        nativeBalance + wrappedBalance,
        decimals: 6,
      );
    }
    for (final token in state.portfolioTokens) {
      if (token.address.toLowerCase() == asset.address.toLowerCase()) {
        return token.balance;
      }
    }
    return '0';
  }

  String _maxInputAmount(String balance) {
    final parsed = AmountUtils.parseNumeric(balance);
    if (parsed <= 0) return '0';
    return AmountUtils.formatInputAmount(
      parsed,
      decimals: parsed >= 10 ? 4 : 6,
    );
  }

  BigInt? _toRawFromBalance(String value, int decimals) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    try {
      return ref.read(web3ServiceProvider).parseAmountToRaw(trimmed, decimals);
    } catch (_) {
      return null;
    }
  }

  String _formatChartValue(double value) {
    if (_chartMetric == _ChartMetric.price) {
      return value.toStringAsFixed(value < 1 ? 6 : 4);
    }
    return AmountUtils.formatShortUsd(value);
  }

  String _formatChartTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return switch (_chartTimeframe) {
      _ChartTimeframe.h1 =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
      _ChartTimeframe.d1 =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
      _ChartTimeframe.w1 => '${dt.month}/${dt.day}',
      _ChartTimeframe.m1 => '${dt.month}/${dt.day}',
    };
  }

  static String _chartMetricLabel(_ChartMetric metric) => switch (metric) {
    _ChartMetric.price => 'Price',
    _ChartMetric.volume => 'Volume',
    _ChartMetric.liquidity => 'Liquidity',
    _ChartMetric.fees => 'Fees',
  };

  static String _chartTimeframeLabel(_ChartTimeframe frame) => switch (frame) {
    _ChartTimeframe.h1 => '1H',
    _ChartTimeframe.d1 => '1D',
    _ChartTimeframe.w1 => '1W',
    _ChartTimeframe.m1 => '1M',
  };

  static String _shortHash(String hash) {
    return AddressUtils.shorten(hash);
  }

  Future<TransactionPreview> _buildApprovePreview({
    required String ownerAddress,
    required _PoolAsset inAsset,
    required BigInt approvalAmount,
  }) async {
    final web3 = ref.read(web3ServiceProvider);
    final chainId = await web3.getChainId();
    final gasPriceWei = await web3.getGasPriceWei();
    final gasLimit = web3.erc20ApproveGasLimit;
    final feeWei = gasPriceWei * BigInt.from(gasLimit);

    return TransactionPreview(
      title: 'Approve Token',
      methodName: 'approve(address,uint256)',
      recipientAddress: DexConfig.routerAddress,
      amountDisplay:
          '${AmountUtils.formatInputAmount(AmountUtils.parseNumeric(_amountController.text), decimals: 6)} ${inAsset.symbol}',
      networkName: _networkNameForChainId(chainId),
      chainId: chainId,
      contractAddress: inAsset.address,
      gasLimit: gasLimit,
      gasPriceWei: gasPriceWei,
      estimatedFeeDisplay: _formatFeeDisplay(feeWei),
      calldataHex: '0x095ea7b3…',
      fields: <TransactionPreviewField>[
        TransactionPreviewField(label: 'Owner', value: ownerAddress),
        TransactionPreviewField(
          label: 'Spender',
          value: DexConfig.routerAddress,
        ),
        TransactionPreviewField(
          label: 'Amount (raw)',
          value: approvalAmount.toString(),
        ),
      ],
    );
  }

  Future<TransactionPreview> _buildSwapPreview({
    required String accountAddress,
    required _PoolAsset inAsset,
    required _PoolAsset outAsset,
    required BigInt amountOutMin,
    required BigInt deadline,
    required List<String> path,
    required bool useDirectPair,
  }) async {
    final web3 = ref.read(web3ServiceProvider);
    final chainId = await web3.getChainId();
    final gasPriceWei = await web3.getGasPriceWei();
    final gasLimit = useDirectPair ? web3.pairSwapGasLimit : web3.swapGasLimit;
    final feeWei = gasPriceWei * BigInt.from(gasLimit);

    final methodName = useDirectPair ? 'pair.swap' : 'swapExactTokensForTokens';
    final calldata = useDirectPair ? 'pair transfer + swap' : '0x38ed1739…';

    return TransactionPreview(
      title: 'Swap Tokens',
      methodName: '$methodName(...)',
      recipientAddress: accountAddress,
      amountDisplay:
          '${_amountController.text.trim()} ${inAsset.symbol} -> $_quotedOutDisplay ${outAsset.symbol}',
      networkName: _networkNameForChainId(chainId),
      chainId: chainId,
      contractAddress: useDirectPair ? widget.pool.id : DexConfig.routerAddress,
      gasLimit: gasLimit,
      gasPriceWei: gasPriceWei,
      estimatedFeeDisplay: _formatFeeDisplay(feeWei),
      calldataHex: calldata,
      fields: <TransactionPreviewField>[
        TransactionPreviewField(
          label: useDirectPair ? 'Pair' : 'Router',
          value: useDirectPair ? widget.pool.id : DexConfig.routerAddress,
        ),
        TransactionPreviewField(
          label: 'Amount In (raw)',
          value: _inputRaw.toString(),
        ),
        TransactionPreviewField(
          label: 'Amount Out Min (raw)',
          value: amountOutMin.toString(),
        ),
        TransactionPreviewField(
          label: useDirectPair ? 'Trade Path' : 'Path',
          value: path.join(' -> '),
        ),
        TransactionPreviewField(label: 'To', value: accountAddress),
        if (!useDirectPair)
          TransactionPreviewField(
            label: 'Deadline',
            value: deadline.toString(),
          ),
      ],
    );
  }

  static String _networkNameForChainId(int chainId) {
    if (chainId == DexConfig.defaultChainId) return 'Reef';
    return switch (chainId) {
      1 => 'Ethereum',
      11155111 => 'Sepolia',
      _ => 'Chain $chainId',
    };
  }

  static String _formatFeeDisplay(BigInt feeWei) {
    final fee = feeWei.toDouble() / 1000000000000000000;
    return '${NumberFormat('0.########').format(fee)} REEF';
  }
}

class _PoolAsset {
  const _PoolAsset({
    required this.symbol,
    required this.address,
    required this.routerAddress,
    required this.decimals,
    required this.iconUrl,
    required this.isNative,
    required this.isCanonicalReef,
  });

  final String symbol;
  final String address;
  final String routerAddress;
  final int decimals;
  final String? iconUrl;
  final bool isNative;
  final bool isCanonicalReef;

  static _PoolAsset fromPool(Pool pool, {required bool isToken0}) {
    final symbol = isToken0 ? pool.token0Symbol : pool.token1Symbol;
    final rawAddress = isToken0 ? pool.token0Address : pool.token1Address;
    final decimals = isToken0 ? pool.token0Decimals : pool.token1Decimals;
    final icon = isToken0
        ? (pool.tokenIcons.isNotEmpty ? pool.tokenIcons[0] : null)
        : (pool.tokenIcons.length > 1 ? pool.tokenIcons[1] : null);
    final isReefLike =
        symbol.toUpperCase() == 'REEF' ||
        symbol.toUpperCase() == 'WREEF' ||
        rawAddress.toLowerCase() == DexConfig.wrappedReefAddress.toLowerCase();
    final resolvedAddress = isReefLike
        ? DexConfig.wrappedReefAddress
        : rawAddress;

    return _PoolAsset(
      symbol: isReefLike ? 'REEF' : symbol,
      address: resolvedAddress,
      routerAddress: resolvedAddress,
      decimals: decimals,
      iconUrl: icon,
      isNative: false,
      isCanonicalReef: isReefLike,
    );
  }
}

class _ChartPoint {
  const _ChartPoint(this.timestamp, this.value);

  final int timestamp;
  final double value;
}
