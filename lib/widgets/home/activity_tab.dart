import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/theme/reef_theme_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/activity_item.dart';
import '../../providers/activity_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/activity_service.dart';
import '../../utils/amount_utils.dart';
import '../../utils/token_icon_resolver.dart';
import '../../widgets/blurable_content.dart';
import '../../widgets/common/token_avatar.dart';
import '../../widgets/common/reef_loading_widgets.dart';

class ActivityTab extends ConsumerStatefulWidget {
  const ActivityTab({
    super.key,
    required this.address,
    required this.showBalances,
  });

  final String address;
  final bool showBalances;

  @override
  ConsumerState<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<ActivityTab> {
  static const int _itemsPerPage = 8;

  int _page = 1;
  final Set<String> _expandedSwapIds = <String>{};

  ReefThemeColors get _colors => context.reefColors;
  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activityState = ref.watch(activityProvider(widget.address));
    final activityService = ref.watch(activityServiceProvider);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 28, 12, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.activity,
                  style: TextStyle(
                    color: _colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _ExplorerButton(
                  onTap: () => _copyExplorerLink(
                    activityService.accountExplorerUrl(widget.address),
                  ),
                ),
              ],
            ),
            const Gap(18),
            activityState.when(
              data: (items) => _buildLoaded(items, activityService, l10n),
              loading: () => _buildLoadingCard(),
              error: (_, __) => _buildErrorCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoaded(
    List<ActivityItem> items,
    ActivityService activityService,
    AppLocalizations l10n,
  ) {
    if (items.isEmpty) {
      return _buildEmptyCard(l10n);
    }

    final totalPages = (items.length / _itemsPerPage).ceil().clamp(1, 9999);
    if (_page > totalPages) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _page = totalPages);
      });
    }

    final start = (_page - 1) * _itemsPerPage;
    final pagedItems = items.skip(start).take(_itemsPerPage).toList();

    return Container(
      decoration: BoxDecoration(
        color: _colors.cardBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _colors.borderColor),
        boxShadow: [
          BoxShadow(
            color: _isDarkTheme
                ? Colors.black.withOpacity(0.24)
                : const Color(0x12000000),
            blurRadius: 22,
            offset: const Offset(0, 12),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < pagedItems.length; index++) ...[
            _buildActivityRow(pagedItems[index], activityService),
            if (index < pagedItems.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: _colors.borderColor.withOpacity(0.75),
                ),
              ),
          ],
          if (items.length > _itemsPerPage) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: _PaginationBar(
                currentPage: _page,
                totalPages: totalPages,
                onPageChanged: (page) => setState(() => _page = page),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityRow(ActivityItem item, ActivityService activityService) {
    final timestampLabel =
        '${activityService.formatDate(item.timestamp)} · ${activityService.formatTime(item.timestamp)}';

    if (item.type == ActivityItemType.swap && item.swapDetails != null) {
      final isExpanded = _expandedSwapIds.contains(item.id);
      final swapDetails = item.swapDetails!;

      return Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(28),
              bottom: isExpanded ? Radius.zero : const Radius.circular(28),
            ),
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedSwapIds.remove(item.id);
              } else {
                _expandedSwapIds.add(item.id);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Row(
                children: [
                  _LeadingActivityIcon(
                    icon: Icons.swap_horiz_rounded,
                    colors: _colors,
                  ),
                  const Gap(14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Swapped ${swapDetails.fromSymbol} for ${swapDetails.toSymbol}',
                          style: TextStyle(
                            color: _colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          timestampLabel,
                          style: TextStyle(
                            color: _colors.textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BlurableContent(
                        showContent: widget.showBalances,
                        child: Text(
                          '+${_formatAmount(swapDetails.toAmount)}',
                          style: TextStyle(
                            color: _colors.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const Gap(8),
                      TokenAvatar(
                        size: 20,
                        iconUrl: item.tokenIconUrl,
                        fallbackSeed: swapDetails.toSymbol,
                        resolveFallbackIcon: true,
                      ),
                    ],
                  ),
                  const Gap(8),
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: _colors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _colors.cardBackgroundSecondary,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _colors.borderColor),
                ),
                child: Column(
                  children: [
                    _buildSwapDetailRow(
                      'From',
                      _InlineTokenValue(
                        amount: _formatAmount(swapDetails.fromAmount),
                        symbol: swapDetails.fromSymbol,
                        tokenAddress: swapDetails.fromTokenAddress,
                      ),
                    ),
                    const Gap(10),
                    _buildSwapDetailRow(
                      'To',
                      _InlineTokenValue(
                        amount: _formatAmount(swapDetails.toAmount),
                        symbol: swapDetails.toSymbol,
                        tokenAddress: swapDetails.toTokenAddress,
                      ),
                    ),
                    const Gap(10),
                    _buildSwapDetailRow(
                      'Fees',
                      _InlineTokenValue(
                        amount: _formatAmount(swapDetails.feeAmount),
                        symbol: swapDetails.feeSymbol,
                        tokenAddress: null,
                      ),
                    ),
                    if ((item.txHash ?? '').isNotEmpty) ...[
                      const Gap(14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () => _copyExplorerLink(
                            activityService.transactionExplorerUrl(
                              item.txHash!,
                            ),
                          ),
                          child: Text(
                            'Copy transaction link',
                            style: TextStyle(
                              color: _colors.accent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    }

    final isSent = item.type == ActivityItemType.sent;
    return InkWell(
      onTap: item.txHash == null
          ? null
          : () => _copyExplorerLink(
              activityService.transactionExplorerUrl(item.txHash!),
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Row(
          children: [
            _LeadingActivityIcon(
              icon: isSent
                  ? Icons.north_east_rounded
                  : Icons.south_west_rounded,
              colors: _colors,
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isSent ? 'Sent' : 'Received'} ${item.symbol}',
                    style: TextStyle(
                      color: _colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    timestampLabel,
                    style: TextStyle(
                      color: _colors.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BlurableContent(
                  showContent: widget.showBalances,
                  child: Text(
                    '${isSent ? '-' : '+'}${_formatAmount(item.amount)}',
                    style: TextStyle(
                      color: _colors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.showBalances) ...[
                  const Gap(8),
                  TokenAvatar(
                    size: 20,
                    iconUrl: item.tokenIconUrl,
                    fallbackSeed: item.symbol,
                    resolveFallbackIcon: true,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwapDetailRow(String label, _InlineTokenValue value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: _colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        BlurableContent(
          showContent: widget.showBalances,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.amount,
                style: TextStyle(
                  color: _colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(6),
              TokenAvatar(
                size: 16,
                iconUrl: value.tokenAddress == null
                    ? null
                    : TokenIconResolver.resolveTokenIconUrl(
                        address: value.tokenAddress,
                        symbol: value.symbol,
                      ),
                fallbackSeed: value.symbol,
                resolveFallbackIcon: true,
              ),
              const Gap(4),
              Text(
                value.symbol,
                style: TextStyle(
                  color: _colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return const ReefLoadingCard(
      title: 'Loading activity',
      subtitle: 'Fetching transfers, swaps, and account history.',
      compact: true,
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _colors.cardBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _colors.borderColor),
      ),
      child: Text(
        'Unable to load activity right now.',
        style: TextStyle(
          color: _colors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyCard(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: _colors.cardBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _colors.borderColor),
      ),
      child: Text(
        l10n.noTransactionsYet,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _colors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatAmount(double value) {
    final absolute = value.abs();
    if (absolute >= 1000) {
      return _formatCompactNumber(value);
    }
    if (absolute > 0 && absolute < 1) {
      return AmountUtils.trimTrailingZeros(value.toStringAsFixed(6));
    }
    return AmountUtils.trimTrailingZeros(value.toStringAsFixed(2));
  }

  String _formatCompactNumber(double value) {
    return AmountUtils.formatCompactNumber(
      value,
      wholeDecimals: 0,
      fractionDecimals: 2,
    );
  }

  Future<void> _copyExplorerLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Explorer link copied')));
  }
}

class _ExplorerButton extends StatelessWidget {
  const _ExplorerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colors.cardBackgroundSecondary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new_rounded, size: 16, color: colors.accent),
            const Gap(6),
            Text(
              'Open Explorer',
              style: TextStyle(
                color: colors.accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadingActivityIcon extends StatelessWidget {
  const _LeadingActivityIcon({required this.icon, required this.colors});

  final IconData icon;
  final ReefThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: colors.cardBackgroundSecondary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: colors.textMuted, size: 24),
    );
  }
}

class _InlineTokenValue {
  const _InlineTokenValue({
    required this.amount,
    required this.symbol,
    required this.tokenAddress,
  });

  final String amount;
  final String symbol;
  final String? tokenAddress;
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    final items = _paginationItems();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PaginationButton(
          label: '‹',
          enabled: currentPage > 1,
          active: false,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        for (final item in items) ...[
          const Gap(6),
          if (item == null)
            Text(
              '...',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            _PaginationButton(
              label: '$item',
              enabled: true,
              active: item == currentPage,
              onTap: () => onPageChanged(item),
            ),
        ],
        const Gap(6),
        _PaginationButton(
          label: '›',
          enabled: currentPage < totalPages,
          active: false,
          onTap: () => onPageChanged(currentPage + 1),
        ),
      ],
    );
  }

  List<int?> _paginationItems() {
    if (totalPages <= 7) {
      return List<int?>.generate(totalPages, (index) => index + 1);
    }

    final pages = <int>{
      1,
      totalPages,
      currentPage - 1,
      currentPage,
      currentPage + 1,
    };
    if (currentPage <= 3) {
      pages.addAll(<int>{2, 3});
    }
    if (currentPage >= totalPages - 2) {
      pages.addAll(<int>{totalPages - 1, totalPages - 2});
    }

    final sorted =
        pages.where((page) => page >= 1 && page <= totalPages).toList()..sort();

    final output = <int?>[];
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) {
        output.add(null);
      }
      output.add(sorted[i]);
    }
    return output;
  }
}

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({
    required this.label,
    required this.enabled,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: active
                ? LinearGradient(
                    colors: <Color>[colors.accent, colors.accentStrong],
                  )
                : null,
            color: active ? null : colors.cardBackgroundSecondary,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
