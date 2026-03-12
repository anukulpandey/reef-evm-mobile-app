import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../core/config/dex_config.dart';
import '../core/theme/styles.dart';
import '../models/pool.dart';
import '../models/pool_transaction.dart';
import '../models/transaction_preview.dart';
import '../providers/pool_provider.dart';
import '../providers/service_providers.dart';
import '../providers/wallet_provider.dart';
import '../utils/address_utils.dart';
import '../utils/amount_utils.dart';
import '../widgets/blurable_content.dart';
import '../widgets/common/token_avatar.dart';
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
  static const Color _screenBg = Color(0xFF17002D);
  static const Color _cardBg = Color(0xFF22123E);
  static const Color _cardBgAlt = Color(0xFF271648);
  static const Color _cardBorder = Color(0xFF4A2F73);
  static const Color _titleText = Color(0xFFF3EEFF);
  static const Color _bodyText = Color(0xFFD1C6EB);
  static const Color _mutedText = Color(0xFFA79BBC);
  static const Color _inputBg = Color(0xFF312151);
  static const Color _inputBorder = Color(0xFF6C4AA0);
  static const Color _accent = Color(0xFFA742D5);

  final TextEditingController _amountController = TextEditingController();
  int _quoteRequestId = 0;

  _ChartMetric _chartMetric = _ChartMetric.price;
  _ChartTimeframe _chartTimeframe = _ChartTimeframe.d1;
  bool _inputToken0 = true;

  bool _isLoadingQuote = false;
  bool _isSubmittingSwap = false;
  bool _isApproving = false;
  bool _allowanceEnough = true;

  BigInt _inputRaw = BigInt.zero;
  BigInt _quotedOutRaw = BigInt.zero;
  String _quotedOutDisplay = '0';
  String? _swapError;
  String? _lastTxHash;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshQuoteAndAllowance();
    });
  }

  @override
  void dispose() {
    _amountController
      ..removeListener(_onAmountChanged)
      ..dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    _refreshQuoteAndAllowance();
  }

  _PoolAsset get _assetIn => _inputToken0
      ? _PoolAsset.fromPool(widget.pool, isToken0: true)
      : _PoolAsset.fromPool(widget.pool, isToken0: false);

  _PoolAsset get _assetOut => _inputToken0
      ? _PoolAsset.fromPool(widget.pool, isToken0: false)
      : _PoolAsset.fromPool(widget.pool, isToken0: true);

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
      });
      return;
    }

    setState(() {
      _inputRaw = rawIn;
      _isLoadingQuote = true;
      _swapError = null;
    });

    try {
      final path = <String>[inAsset.routerAddress, outAsset.routerAddress];
      final outRaw = await web3.getAmountsOut(
        routerAddress: DexConfig.routerAddress,
        amountIn: rawIn,
        path: path,
      );

      var hasAllowance = true;
      if (!inAsset.isNative) {
        final allowance = await web3.getErc20Allowance(
          tokenAddress: inAsset.address,
          owner: account.address,
          spender: DexConfig.routerAddress,
        );
        hasAllowance = allowance >= rawIn;
      }

      if (!mounted || reqId != _quoteRequestId) return;
      setState(() {
        _quotedOutRaw = outRaw;
        _quotedOutDisplay = web3.formatAmountFromRaw(outRaw, outAsset.decimals);
        _allowanceEnough = hasAllowance;
        _isLoadingQuote = false;
      });
    } catch (e) {
      if (!mounted || reqId != _quoteRequestId) return;
      setState(() {
        _quotedOutRaw = BigInt.zero;
        _quotedOutDisplay = '0';
        _allowanceEnough = inAsset.isNative;
        _isLoadingQuote = false;
        _swapError = e.toString().replaceFirst('Exception: ', '');
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
      setState(() {
        _swapError = e.toString().replaceFirst('Exception: ', '');
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
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final deadline = BigInt.from(
      nowSec + (DexConfig.defaultDeadlineMinutes * 60),
    );
    final slippageBps = BigInt.from(
      (DexConfig.defaultSlippagePercent * 100).round(),
    );
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
              });
            }
            try {
              final web3 = ref.read(web3ServiceProvider);
              if (inAsset.isNative) {
                return await web3.swapExactEthForTokens(
                  account: account,
                  routerAddress: DexConfig.routerAddress,
                  amountInWei: _inputRaw,
                  amountOutMin: amountOutMin,
                  path: path,
                  to: account.address,
                  deadline: deadline,
                );
              }
              if (outAsset.isNative) {
                return await web3.swapExactTokensForEth(
                  account: account,
                  routerAddress: DexConfig.routerAddress,
                  amountIn: _inputRaw,
                  amountOutMin: amountOutMin,
                  path: path,
                  to: account.address,
                  deadline: deadline,
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

  void _flipPair() {
    setState(() {
      _inputToken0 = !_inputToken0;
      _amountController.clear();
      _inputRaw = BigInt.zero;
      _quotedOutRaw = BigInt.zero;
      _quotedOutDisplay = '0';
      _allowanceEnough = true;
      _swapError = null;
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
      final hasSufficientBalance =
          _inputRaw == BigInt.zero || _inputRaw <= inputBalanceRaw;
      final canSwap =
          _inputRaw > BigInt.zero &&
          _quotedOutRaw > BigInt.zero &&
          hasSufficientBalance &&
          !_isSubmittingSwap &&
          !_isApproving &&
          !_isLoadingQuote &&
          (_allowanceEnough || inAsset.isNative);
      final requiresApproval =
          _inputRaw > BigInt.zero && !inAsset.isNative && !_allowanceEnough;

      return Scaffold(
        backgroundColor: _screenBg,
        appBar: AppBar(
          backgroundColor: _screenBg,
          elevation: 0,
          title: Text(
            appBarTitle,
            style: const TextStyle(
              color: _titleText,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          iconTheme: const IconThemeData(color: _titleText),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          children: [
            _buildPoolHeaderCard(widget.pool),
            const Gap(14),
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
              Text(
                _swapError!,
                style: const TextStyle(
                  color: Color(0xFFFF6C6C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_lastTxHash != null) ...[
              const Gap(6),
              Text(
                'Last tx: ${_shortHash(_lastTxHash!)}',
                style: const TextStyle(
                  color: _bodyText,
                  fontWeight: FontWeight.w600,
                ),
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
        title: Text(
          appBarTitle,
          style: const TextStyle(
            color: _titleText,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: _titleText),
      ),
      body: FutureBuilder<List<PoolTransactionEvent>>(
        future: poolService.getPairTransactions(widget.pool.id),
        builder: (context, snapshot) {
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
          const Text(
            'Trade',
            style: TextStyle(
              color: _titleText,
              fontSize: Styles.fsCardTitle,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Gap(6),
          const Text(
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
                backgroundColor: const Color(0xFF7A3ED5),
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cardBg, _cardBgAlt],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x660C0418),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  avatarSize: 40,
                  overlapOffset: 24,
                  resolveFallbackIcon: true,
                  imageFit: BoxFit.contain,
                  imagePadding: const EdgeInsets.all(4),
                  avatarBackgroundColor: Colors.white,
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pairTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _titleText,
                          fontWeight: FontWeight.w900,
                          fontSize: Styles.fsSectionTitle,
                          height: 1.05,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        ticker,
                        style: const TextStyle(
                          color: _bodyText,
                          fontWeight: FontWeight.w700,
                          fontSize: Styles.fsCaption,
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
            const Gap(2),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _mutedText,
              fontWeight: FontWeight.w800,
              fontSize: Styles.fsSmall,
            ),
          ),
          const Gap(2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _titleText,
              fontWeight: FontWeight.w900,
              fontSize: Styles.fsBodyStrong,
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
      style: const TextStyle(
        color: _bodyText,
        fontWeight: FontWeight.w700,
        fontSize: Styles.fsBody,
      ),
    );
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
            const Text(
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
                  backgroundColor: const Color(0xFF301E54),
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
                      color: selected ? _accent : const Color(0xFF5C4588),
                    ),
                    foregroundColor: selected
                        ? const Color(0xFFD8C6FF)
                        : _bodyText,
                    backgroundColor: selected
                        ? const Color(0xFF38215C)
                        : const Color(0x1AFFFFFF),
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
                  ? const Center(
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
                          getDrawingHorizontalLine: (_) => const FlLine(
                            color: Color(0x305E4E82),
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
                                  style: const TextStyle(
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
                                  style: const TextStyle(
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
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Swap',
              style: TextStyle(
                color: _titleText,
                fontWeight: FontWeight.w900,
                fontSize: 48 / 2,
              ),
            ),
            const Gap(12),
            _tokenRow(asset: inAsset, balance: inBalance),
            const Gap(10),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: _titleText,
                fontWeight: FontWeight.w800,
                fontSize: Styles.fsCardTitle,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: _inputBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: _inputBorder, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: _inputBorder, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: _accent, width: 2),
                ),
                hintText: '0.0',
                hintStyle: const TextStyle(color: _mutedText),
                suffixIcon: IconButton(
                  onPressed: () {
                    _amountController.text = _maxInputAmount(inBalance);
                  },
                  icon: const Icon(
                    Icons.auto_fix_high_rounded,
                    color: _accent,
                    size: 30,
                  ),
                ),
              ),
            ),
            const Gap(12),
            Center(
              child: GestureDetector(
                onTap: _flipPair,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFA14DE8), Color(0xFF6E31C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x66090514),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.swap_vert_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
            const Gap(12),
            _tokenRow(asset: outAsset, balance: outBalance),
            const Gap(10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: _inputBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimated Output',
                    style: TextStyle(
                      color: _mutedText,
                      fontWeight: FontWeight.w800,
                      fontSize: Styles.fsBodyStrong,
                    ),
                  ),
                  const Gap(4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _quotedOutDisplay,
                          style: const TextStyle(
                            color: _titleText,
                            fontWeight: FontWeight.w900,
                            fontSize: Styles.fsSectionTitle,
                            height: 1.0,
                          ),
                        ),
                      ),
                      Text(
                        outAsset.symbol,
                        style: const TextStyle(
                          color: _bodyText,
                          fontWeight: FontWeight.w800,
                          fontSize: Styles.fsSectionTitle,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(12),
            if (_isLoadingQuote)
              const LinearProgressIndicator(minHeight: 2, color: _accent),
            const Gap(14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: requiresApproval
                    ? (_isApproving ? null : _approveIfNeeded)
                    : (canSwap ? _executeSwap : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A3ED5),
                  disabledBackgroundColor: const Color(0xFF5F4B84),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  elevation: 0,
                ),
                child: Text(
                  requiresApproval
                      ? (_isApproving
                            ? 'Approving...'
                            : 'Approve ${inAsset.symbol}')
                      : (!hasSufficientBalance
                            ? 'Insufficient ${inAsset.symbol}'
                            : (_isSubmittingSwap
                                  ? 'Swapping...'
                                  : 'Confirm Swap')),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 40 / 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tokenRow({required _PoolAsset asset, required String balance}) {
    final showBalance = ref.watch(
      walletProvider.select((state) => state.showBalance),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF49346F), width: 1),
      ),
      child: Row(
        children: [
          TokenAvatar(
            size: 42,
            iconUrl: asset.iconUrl,
            fallbackSeed: asset.symbol,
            resolveFallbackIcon: true,
            useDeterministicFallback: true,
            imageFit: BoxFit.contain,
            imagePadding: const EdgeInsets.all(4),
            avatarBackgroundColor: Colors.white,
          ),
          const Gap(10),
          Expanded(
            child: Text(
              asset.symbol,
              style: const TextStyle(
                color: _titleText,
                fontWeight: FontWeight.w900,
                fontSize: 44 / 2,
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: BlurableContent(
              showContent: showBalance,
              child: Text(
                '${AmountUtils.formatCompactToken(balance)} ${asset.symbol}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: _bodyText,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    if (asset.isNative) return state.balance;
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
  }) async {
    final web3 = ref.read(web3ServiceProvider);
    final chainId = await web3.getChainId();
    final gasPriceWei = await web3.getGasPriceWei();
    final gasLimit = web3.swapGasLimit;
    final feeWei = gasPriceWei * BigInt.from(gasLimit);

    final methodName = inAsset.isNative
        ? 'swapExactETHForTokens'
        : (outAsset.isNative
              ? 'swapExactTokensForETH'
              : 'swapExactTokensForTokens');
    final calldata = inAsset.isNative
        ? '0x7ff36ab5…'
        : (outAsset.isNative ? '0x18cbafe5…' : '0x38ed1739…');

    return TransactionPreview(
      title: 'Swap Tokens',
      methodName: '$methodName(...)',
      recipientAddress: accountAddress,
      amountDisplay:
          '${_amountController.text.trim()} ${inAsset.symbol} -> $_quotedOutDisplay ${outAsset.symbol}',
      networkName: _networkNameForChainId(chainId),
      chainId: chainId,
      contractAddress: DexConfig.routerAddress,
      gasLimit: gasLimit,
      gasPriceWei: gasPriceWei,
      estimatedFeeDisplay: _formatFeeDisplay(feeWei),
      calldataHex: calldata,
      fields: <TransactionPreviewField>[
        TransactionPreviewField(
          label: 'Router',
          value: DexConfig.routerAddress,
        ),
        TransactionPreviewField(
          label: 'Amount In (raw)',
          value: _inputRaw.toString(),
        ),
        TransactionPreviewField(
          label: 'Amount Out Min (raw)',
          value: amountOutMin.toString(),
        ),
        TransactionPreviewField(label: 'Path', value: path.join(' -> ')),
        TransactionPreviewField(label: 'To', value: accountAddress),
        TransactionPreviewField(label: 'Deadline', value: deadline.toString()),
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
  });

  final String symbol;
  final String address;
  final String routerAddress;
  final int decimals;
  final String? iconUrl;
  final bool isNative;

  static _PoolAsset fromPool(Pool pool, {required bool isToken0}) {
    final symbol = isToken0 ? pool.token0Symbol : pool.token1Symbol;
    final address = isToken0 ? pool.token0Address : pool.token1Address;
    final decimals = isToken0 ? pool.token0Decimals : pool.token1Decimals;
    final icon = isToken0
        ? (pool.tokenIcons.isNotEmpty ? pool.tokenIcons[0] : null)
        : (pool.tokenIcons.length > 1 ? pool.tokenIcons[1] : null);
    final isReefLike =
        symbol.toUpperCase() == 'REEF' ||
        symbol.toUpperCase() == 'WREEF' ||
        address.toLowerCase() == DexConfig.wrappedReefAddress.toLowerCase();

    return _PoolAsset(
      symbol: isReefLike ? 'REEF' : symbol,
      address: address,
      routerAddress: isReefLike
          ? (address.isNotEmpty ? address : DexConfig.wrappedReefAddress)
          : address,
      decimals: decimals,
      iconUrl: icon,
      isNative: isReefLike,
    );
  }
}

class _ChartPoint {
  const _ChartPoint(this.timestamp, this.value);

  final int timestamp;
  final double value;
}
