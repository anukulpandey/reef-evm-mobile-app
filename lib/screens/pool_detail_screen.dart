import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

import '../core/config/dex_config.dart';
import '../core/theme/styles.dart';
import '../models/pool.dart';
import '../models/pool_transaction.dart';
import '../providers/pool_provider.dart';
import '../providers/service_providers.dart';
import '../providers/wallet_provider.dart';

enum _ChartMetric { price, volume, liquidity, fees }

enum _ChartTimeframe { h1, d1, w1, m1 }

class PoolDetailScreen extends ConsumerStatefulWidget {
  const PoolDetailScreen({super.key, required this.pool});

  final Pool pool;

  @override
  ConsumerState<PoolDetailScreen> createState() => _PoolDetailScreenState();
}

class _PoolDetailScreenState extends ConsumerState<PoolDetailScreen> {
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

    final authorized = await _authenticateTransaction(
      reason: 'Authenticate to approve token spending',
    );
    if (!authorized) return;

    setState(() {
      _isApproving = true;
      _swapError = null;
    });

    try {
      final maxApproval = BigInt.parse(
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        radix: 16,
      );
      final txHash = await ref
          .read(web3ServiceProvider)
          .approveErc20(
            account: account,
            tokenAddress: inAsset.address,
            spender: DexConfig.routerAddress,
            amount: maxApproval,
          );
      if (!mounted) return;
      setState(() {
        _lastTxHash = txHash;
        _allowanceEnough = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approval submitted: ${_shortHash(txHash)}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _swapError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isApproving = false);
      }
    }
  }

  Future<void> _executeSwap() async {
    final walletState = ref.read(walletProvider);
    final account = walletState.activeAccount;
    if (account == null) return;
    if (_inputRaw <= BigInt.zero || _quotedOutRaw <= BigInt.zero) return;

    final authorized = await _authenticateTransaction(
      reason: 'Authenticate to confirm this swap',
    );
    if (!authorized) return;

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

    setState(() {
      _isSubmittingSwap = true;
      _swapError = null;
    });

    try {
      final web3 = ref.read(web3ServiceProvider);
      late final String txHash;
      if (inAsset.isNative) {
        txHash = await web3.swapExactEthForTokens(
          account: account,
          routerAddress: DexConfig.routerAddress,
          amountInWei: _inputRaw,
          amountOutMin: amountOutMin,
          path: path,
          to: account.address,
          deadline: deadline,
        );
      } else if (outAsset.isNative) {
        txHash = await web3.swapExactTokensForEth(
          account: account,
          routerAddress: DexConfig.routerAddress,
          amountIn: _inputRaw,
          amountOutMin: amountOutMin,
          path: path,
          to: account.address,
          deadline: deadline,
        );
      } else {
        txHash = await web3.swapExactTokensForTokens(
          account: account,
          routerAddress: DexConfig.routerAddress,
          amountIn: _inputRaw,
          amountOutMin: amountOutMin,
          path: path,
          to: account.address,
          deadline: deadline,
        );
      }

      if (!mounted) return;
      setState(() {
        _lastTxHash = txHash;
        _amountController.clear();
        _quotedOutRaw = BigInt.zero;
        _quotedOutDisplay = '0';
      });
      ref.invalidate(walletProvider);
      ref.invalidate(poolsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Swap submitted: ${_shortHash(txHash)}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _swapError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmittingSwap = false);
      }
    }
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

  Future<bool> _authenticateTransaction({required String reason}) async {
    final authService = ref.read(authServiceProvider);
    final ok = await authService.authenticateForTransaction(
      localizedReason: reason,
    );
    if (ok) return true;
    if (!mounted) return false;
    setState(() {
      _swapError = 'Biometric authentication failed';
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final poolService = ref.read(poolServiceProvider);
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
      backgroundColor: const Color(0xFF2B0052),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B0052),
        elevation: 0,
        title: Text(
          '${widget.pool.token0Symbol} / ${widget.pool.token1Symbol}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
                    color: Color(0xFFC9B6EC),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildPoolHeaderCard(Pool pool) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFECEAF1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    _buildTokenAvatar(
                      iconUrl: pool.tokenIcons.isNotEmpty
                          ? pool.tokenIcons[0]
                          : null,
                      fallbackSeed: pool.token0Symbol,
                      size: 34,
                    ),
                    Positioned(
                      left: 20,
                      child: _buildTokenAvatar(
                        iconUrl: pool.tokenIcons.length > 1
                            ? pool.tokenIcons[1]
                            : null,
                        fallbackSeed: pool.token1Symbol,
                        size: 34,
                      ),
                    ),
                  ],
                ),
                const Gap(44),
                Expanded(
                  child: Text(
                    '${pool.token0Symbol} - ${pool.token1Symbol}',
                    style: const TextStyle(
                      color: Color(0xFF221C2E),
                      fontWeight: FontWeight.w900,
                      fontSize: Styles.fsCardTitle,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(10),
            _statLine('TVL', _formatUsd(pool.reserveUsd)),
            const Gap(4),
            _statLine('24h Volume', _formatUsd(pool.volumeUsd)),
            const Gap(4),
            _statLine(
              'Rate',
              '1 ${pool.token0Symbol} = ${_formatRate(pool.token0Price)} ${pool.token1Symbol}',
            ),
            const Gap(2),
            _statLine(
              '',
              '1 ${pool.token1Symbol} = ${_formatRate(pool.token1Price)} ${pool.token0Symbol}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _statLine(String label, String value) {
    return Row(
      children: [
        if (label.isNotEmpty)
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF4A455B),
              fontWeight: FontWeight.w800,
              fontSize: Styles.fsBody,
            ),
          ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF4A455B),
              fontWeight: FontWeight.w700,
              fontSize: Styles.fsBody,
            ),
          ),
        ),
      ],
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
        color: const Color(0xFFECEAF1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pool Chart',
              style: TextStyle(
                color: Color(0xFF221C2E),
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
                    color: selected ? Colors.white : const Color(0xFF4E4862),
                    fontWeight: FontWeight.w700,
                  ),
                  selectedColor: const Color(0xFF7B39C8),
                  backgroundColor: Colors.white,
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
                          ? const Color(0xFF7B39C8)
                          : const Color(0xFFC7C2D6),
                    ),
                    foregroundColor: selected
                        ? const Color(0xFF7B39C8)
                        : const Color(0xFF7F7A90),
                    backgroundColor: selected
                        ? const Color(0xFFF3EFFF)
                        : Colors.transparent,
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
                          color: Color(0xFF7E7892),
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
                            color: Color(0xFFDDD8E9),
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
                                    color: Color(0xFF7E7892),
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
                                    color: Color(0xFF7E7892),
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
                            color: const Color(0xFFA72FB8),
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x66A72FB8), Color(0x00A72FB8)],
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
        color: const Color(0xFFECEAF1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Swap',
              style: TextStyle(
                color: Color(0xFF221C2E),
                fontWeight: FontWeight.w900,
                fontSize: Styles.fsSectionTitle,
              ),
            ),
            const Gap(12),
            _tokenRow(asset: inAsset, balance: inBalance),
            const Gap(8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: Color(0xFF241F31),
                fontWeight: FontWeight.w800,
                fontSize: Styles.fsCardTitle,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD3CEDF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD3CEDF)),
                ),
                hintText: '0.0',
                hintStyle: const TextStyle(color: Color(0xFFA09BB1)),
                suffixIcon: IconButton(
                  onPressed: () {
                    _amountController.text = _maxInputAmount(inBalance);
                  },
                  icon: const Icon(
                    Icons.auto_fix_high,
                    color: Color(0xFF7B39C8),
                  ),
                ),
              ),
            ),
            const Gap(8),
            Align(
              alignment: Alignment.center,
              child: IconButton(
                onPressed: _flipPair,
                icon: const Icon(
                  Icons.swap_vert_circle_rounded,
                  color: Color(0xFF7B39C8),
                  size: 34,
                ),
              ),
            ),
            _tokenRow(asset: outAsset, balance: outBalance),
            const Gap(8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated Output',
                    style: TextStyle(
                      color: Color(0xFF7E7892),
                      fontWeight: FontWeight.w700,
                      fontSize: Styles.fsSmall,
                    ),
                  ),
                  const Gap(2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _quotedOutDisplay,
                          style: const TextStyle(
                            color: Color(0xFF241F31),
                            fontWeight: FontWeight.w900,
                            fontSize: Styles.fsCardTitle,
                          ),
                        ),
                      ),
                      Text(
                        outAsset.symbol,
                        style: const TextStyle(
                          color: Color(0xFF6A6482),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(10),
            if (_isLoadingQuote)
              const LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFF7B39C8),
              ),
            const Gap(12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: requiresApproval
                    ? (_isApproving ? null : _approveIfNeeded)
                    : (canSwap ? _executeSwap : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D34C0),
                  disabledBackgroundColor: const Color(0xFFC8C2D6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
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
                    fontSize: Styles.fsBodyStrong,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildTokenAvatar(
            iconUrl: asset.iconUrl,
            fallbackSeed: asset.symbol,
            size: 30,
          ),
          const Gap(8),
          Expanded(
            child: Text(
              asset.symbol,
              style: const TextStyle(
                color: Color(0xFF241F31),
                fontWeight: FontWeight.w900,
                fontSize: Styles.fsBodyStrong,
              ),
            ),
          ),
          Text(
            '${_formatCompactToken(balance)} ${asset.symbol}',
            style: const TextStyle(
              color: Color(0xFF6A6482),
              fontWeight: FontWeight.w700,
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
    final parsed = double.tryParse(balance) ?? 0;
    if (parsed <= 0) return '0';
    return parsed
        .toStringAsFixed(parsed >= 10 ? 4 : 6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
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
    return _formatUsd(value);
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

  static String _formatUsd(double value) {
    if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}K';
    }
    return '\$${value.toStringAsFixed(2)}';
  }

  static String _formatRate(double value) {
    if (value <= 0 || !value.isFinite) return '0';
    if (value < 1) return value.toStringAsFixed(6);
    if (value < 100) return value.toStringAsFixed(4);
    return value.toStringAsFixed(2);
  }

  static String _formatCompactToken(String value) {
    final parsed = double.tryParse(value) ?? 0;
    if (parsed == 0) return '0';
    if (parsed >= 1000) {
      return '${(parsed / 1000).toStringAsFixed(2)}K';
    }
    return parsed
        .toStringAsFixed(parsed < 1 ? 6 : 4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
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

  static Widget _buildTokenAvatar({
    required String? iconUrl,
    required String fallbackSeed,
    required double size,
  }) {
    final provider = _resolveImageProvider(iconUrl);
    final svgData = _resolveSvgData(iconUrl);
    final fallback = _buildDeterministicFallbackIcon(fallbackSeed, size);
    return SizedBox(
      width: size,
      height: size,
      child: svgData != null
          ? ClipOval(
              child: SvgPicture.string(
                svgData,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            )
          : provider == null
          ? fallback
          : ClipOval(
              child: Image(
                image: provider,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            ),
    );
  }

  static Widget _buildDeterministicFallbackIcon(String seed, double size) {
    final initial = seed.isEmpty ? '?' : seed.substring(0, 1).toUpperCase();
    final bg = Color(0xFF000000 + (seed.hashCode.abs() % 0x00FFFFFF));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: math.max(10, size * 0.45),
        ),
      ),
    );
  }

  static ImageProvider? _resolveImageProvider(String? iconUrl) {
    if (iconUrl == null || iconUrl.trim().isEmpty) return null;
    final normalized = iconUrl.trim();
    final dataUri = _tryParseDataUri(normalized);
    if (dataUri != null) {
      if (dataUri.mimeType.contains('svg')) return null;
      final bytes = dataUri.contentAsBytes();
      if (bytes.isNotEmpty) return MemoryImage(bytes);
      return null;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return NetworkImage(normalized);
  }

  static String? _resolveSvgData(String? iconUrl) {
    if (iconUrl == null || iconUrl.trim().isEmpty) return null;
    final data = _tryParseDataUri(iconUrl.trim());
    if (data == null) return null;
    if (!data.mimeType.contains('svg')) return null;
    final bytes = data.contentAsBytes();
    if (bytes.isEmpty) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  static UriData? _tryParseDataUri(String value) {
    if (!value.startsWith('data:')) return null;
    try {
      return UriData.parse(value);
    } catch (_) {
      return null;
    }
  }

  static String _shortHash(String hash) {
    final value = hash.trim();
    if (value.length < 12) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
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
