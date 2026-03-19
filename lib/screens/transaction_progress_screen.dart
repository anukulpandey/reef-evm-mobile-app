import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/reef_theme_colors.dart';
import '../models/transaction_preview.dart';
import '../providers/service_providers.dart';
import '../utils/address_utils.dart';
import '../utils/transaction_error_mapper.dart';

class TransactionProgressOutcome {
  const TransactionProgressOutcome({
    required this.completed,
    this.txHash,
    this.blockNumber,
  });

  final bool completed;
  final String? txHash;
  final int? blockNumber;
}

class TransactionProgressScreen extends ConsumerStatefulWidget {
  const TransactionProgressScreen({
    super.key,
    required this.preview,
    required this.runTransaction,
  });

  final TransactionPreview preview;
  final Future<String> Function() runTransaction;

  @override
  ConsumerState<TransactionProgressScreen> createState() =>
      _TransactionProgressScreenState();
}

enum _TransactionStepState { pending, loading, complete, error }

class _TransactionProgressScreenState
    extends ConsumerState<TransactionProgressScreen> {
  String? _txHash;
  int? _blockNumber;
  String? _errorTitle;
  String? _errorMessage;
  int _activeStepIndex = 1;
  bool _isRunning = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runFlow());
  }

  Future<void> _runFlow() async {
    final web3Service = ref.read(web3ServiceProvider);

    try {
      setState(() {
        _txHash = null;
        _blockNumber = null;
        _errorTitle = null;
        _errorMessage = null;
        _activeStepIndex = 1;
        _isRunning = true;
      });

      final txHash = await widget.runTransaction();
      if (!mounted) return;
      setState(() {
        _txHash = txHash;
        _activeStepIndex = 2;
      });

      final receipt = await web3Service.waitForReceiptAndGet(txHash);
      if (!mounted) return;
      setState(() {
        _blockNumber = receipt.blockNumber.blockNum;
        _activeStepIndex = 3;
        _isRunning = false;
      });
    } catch (error, stackTrace) {
      print('[tx_progress][error] error=$error');
      print('[tx_progress][error][stack]=$stackTrace');
      final userError = TransactionErrorMapper.fromThrowable(error);
      if (!mounted) return;
      setState(() {
        _errorTitle = userError.title;
        _errorMessage = userError.message;
        _isRunning = false;
      });
    }
  }

  _TransactionStepState _stepState(int stepIndex) {
    if (_errorMessage != null && stepIndex == _activeStepIndex) {
      return _TransactionStepState.error;
    }
    if (stepIndex < _activeStepIndex) return _TransactionStepState.complete;
    if (_isRunning && stepIndex == _activeStepIndex) {
      return _TransactionStepState.loading;
    }
    if (!_isRunning && _errorMessage == null && stepIndex <= _activeStepIndex) {
      return _TransactionStepState.complete;
    }
    return _TransactionStepState.pending;
  }

  String _completionTitle() {
    final title = widget.preview.title.toLowerCase();
    final method = widget.preview.methodName.toLowerCase();
    if (method.contains('approve')) return 'Approval completed';
    if (title.contains('liquidity') || method.contains('liquidity')) {
      return 'Liquidity submitted';
    }
    if (title.contains('swap') || method.contains('swap')) {
      return 'Swap completed';
    }
    if (title.contains('send') || method.contains('transfer')) {
      return 'Transfer completed';
    }
    return 'Transaction completed';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final screenBackground = isDarkTheme
        ? colors.deepBackground
        : colors.appBackground;
    final headerBackground = isDarkTheme
        ? const Color(0xFF5A23A5)
        : Colors.deepPurple.shade700;

    return PopScope(
      canPop: !_isRunning,
      child: Scaffold(
        backgroundColor: screenBackground,
        appBar: AppBar(
          backgroundColor: headerBackground,
          elevation: 0,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: !_isRunning,
          title: Text(
            widget.preview.title,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 21,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroCard(colors),
                      const Gap(18),
                      _buildStepsCard(colors),
                      if (_errorMessage != null) ...[
                        const Gap(16),
                        _buildErrorCard(colors),
                      ],
                    ],
                  ),
                ),
              ),
              _buildBottomActions(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(ReefThemeColors colors) {
    final accentGlow = _errorMessage != null
        ? colors.danger
        : colors.accentStrong;
    final subtitle = _errorMessage == null
        ? 'We are pushing the signed transaction to Reef, waiting for inclusion, and confirming the result.'
        : 'The transaction hit an issue before we could complete the flow.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.cardBackground,
            colors.cardBackgroundSecondary.withOpacity(0.96),
          ],
        ),
        border: Border.all(color: colors.borderColor),
        boxShadow: [
          BoxShadow(
            color: accentGlow.withOpacity(0.16),
            blurRadius: 30,
            offset: const Offset(0, 14),
            spreadRadius: -12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.topBarChipBackground,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.borderColor.withOpacity(0.7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _errorMessage == null
                      ? Icons.bolt_rounded
                      : Icons.error_outline_rounded,
                  size: 16,
                  color: _errorMessage == null
                      ? colors.accentStrong
                      : colors.danger,
                ),
                const Gap(8),
                Text(
                  _errorMessage == null
                      ? 'Transaction workflow'
                      : 'Needs attention',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Gap(18),
          Text(
            widget.preview.amountDisplay,
            style: GoogleFonts.spaceGrotesk(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 30,
              height: 1,
            ),
          ),
          const Gap(10),
          Text(
            subtitle,
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const Gap(16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _infoChip(
                colors: colors,
                label: 'Method',
                value: widget.preview.methodName,
              ),
              _infoChip(
                colors: colors,
                label: widget.preview.recipientLabel,
                value: AddressUtils.shorten(
                  widget.preview.recipientAddress,
                  prefixLength: 7,
                  suffixLength: 5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepsCard(ReefThemeColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction progress',
            style: GoogleFonts.spaceGrotesk(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 30,
              height: 1,
            ),
          ),
          const Gap(8),
          Text(
            'We will keep updating each step as the transaction moves through the chain.',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const Gap(20),
          _buildProgressStep(
            colors: colors,
            title: 'Approval complete',
            subtitle: 'Password and biometric checks passed.',
            state: _stepState(0),
            detail: widget.preview.networkName,
          ),
          _buildConnector(colors, active: _activeStepIndex > 1),
          _buildProgressStep(
            colors: colors,
            title: 'Broadcasted to network',
            subtitle: _txHash == null
                ? 'Signing and submitting the transaction.'
                : 'Transaction accepted by Reef.',
            state: _stepState(1),
            detail: _txHash == null ? null : _shortHash(_txHash!),
          ),
          _buildConnector(colors, active: _activeStepIndex > 2),
          _buildProgressStep(
            colors: colors,
            title: 'Included in block',
            subtitle: _blockNumber == null
                ? 'Waiting for on-chain inclusion.'
                : 'Transaction included on chain.',
            state: _stepState(2),
            detail: _blockNumber == null ? null : 'Block #$_blockNumber',
          ),
          _buildConnector(colors, active: _activeStepIndex > 3),
          _buildProgressStep(
            colors: colors,
            title: _completionTitle(),
            subtitle: _txHash == null
                ? 'Finalizing transaction state.'
                : 'The transaction lifecycle completed successfully.',
            state: _stepState(3),
            detail: _txHash == null ? null : 'Hash ${_shortHash(_txHash!)}',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep({
    required ReefThemeColors colors,
    required String title,
    required String subtitle,
    required _TransactionStepState state,
    String? detail,
  }) {
    final accentColor = state == _TransactionStepState.error
        ? colors.danger
        : state == _TransactionStepState.complete
        ? colors.success
        : colors.accentStrong;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackgroundSecondary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: state == _TransactionStepState.loading
              ? accentColor.withOpacity(0.7)
              : colors.borderColor.withOpacity(0.7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressStepIndicator(state: state, colors: colors),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    height: 1,
                  ),
                ),
                const Gap(6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                if (detail != null) ...[
                  const Gap(10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.topBarChipBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      detail,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
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

  Widget _buildConnector(ReefThemeColors colors, {required bool active}) {
    final connectorColor = active ? colors.accentStrong : colors.inputBorder;
    return Padding(
      padding: const EdgeInsets.only(left: 18, top: 4, bottom: 4),
      child: Container(
        width: 3,
        height: 18,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors.accent, colors.accentStrong],
                )
              : LinearGradient(
                  colors: [
                    connectorColor.withOpacity(0.5),
                    connectorColor.withOpacity(0.2),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(ReefThemeColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.danger.withOpacity(0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.danger, size: 24),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _errorTitle ?? 'Unable to process transaction',
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    height: 1,
                  ),
                ),
                const Gap(8),
                Text(
                  _errorMessage ??
                      'Something went wrong while processing the transaction.',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(ReefThemeColors colors) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            if (_isRunning)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: colors.cardBackgroundSecondary,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: colors.accentStrong,
                        ),
                      ),
                      const Gap(12),
                      Text(
                        'Working on it…',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.inputBorder),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    _errorMessage == null ? 'Back' : 'Back to review',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.accent, colors.accentStrong],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ElevatedButton(
                    onPressed: _errorMessage != null
                        ? _runFlow
                        : () => Navigator.of(context).pop(
                            TransactionProgressOutcome(
                              completed: true,
                              txHash: _txHash,
                              blockNumber: _blockNumber,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      _errorMessage != null ? 'Retry' : 'Continue',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip({
    required ReefThemeColors colors,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.topBarChipBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: colors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortHash(String value) {
    if (value.length <= 14) return value;
    return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
  }
}

class _ProgressStepIndicator extends StatelessWidget {
  const _ProgressStepIndicator({required this.state, required this.colors});

  final _TransactionStepState state;
  final ReefThemeColors colors;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _TransactionStepState.complete:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.success,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
        );
      case _TransactionStepState.loading:
        return SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accentStrong,
                ),
              ),
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.8,
                  color: colors.accent,
                  backgroundColor: colors.accentStrong.withOpacity(0.18),
                ),
              ),
            ],
          ),
        );
      case _TransactionStepState.error:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.danger.withOpacity(0.12),
            border: Border.all(color: colors.danger),
          ),
          child: Icon(Icons.close_rounded, color: colors.danger, size: 22),
        );
      case _TransactionStepState.pending:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.cardBackground,
            border: Border.all(color: colors.inputBorder, width: 2),
          ),
        );
    }
  }
}
