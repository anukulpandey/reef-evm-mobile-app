import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/reef_theme_colors.dart';
import '../models/account.dart';
import '../models/token_creation_result.dart';
import '../models/token_creator_request.dart';
import '../providers/pool_provider.dart';
import '../providers/service_providers.dart';
import '../providers/wallet_provider.dart';
import '../services/token_creator_service.dart';
import '../utils/address_utils.dart';
import '../utils/token_icon_resolver.dart';
import '../utils/transaction_error_mapper.dart';
import '../widgets/common/token_avatar.dart';

class TokenCreationProgressOutcome {
  const TokenCreationProgressOutcome({this.result});

  final TokenCreationResult? result;
}

class TokenCreationProgressScreen extends ConsumerStatefulWidget {
  const TokenCreationProgressScreen({
    super.key,
    required this.account,
    required this.request,
  });

  final Account account;
  final TokenCreatorRequest request;

  @override
  ConsumerState<TokenCreationProgressScreen> createState() =>
      _TokenCreationProgressScreenState();
}

enum _TokenCreationStepState { pending, loading, complete, error }

class _TokenCreationProgressScreenState
    extends ConsumerState<TokenCreationProgressScreen> {
  TokenCreationSubmission? _submission;
  TokenCreationResult? _result;
  String? _txHash;
  String? _contractAddress;
  String? _errorTitle;
  String? _errorMessage;
  int? _blockNumber;
  int _activeStepIndex = 1;
  bool _isRunning = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCreationFlow());
  }

  Future<void> _runCreationFlow() async {
    final creatorService = ref.read(tokenCreatorServiceProvider);
    final web3Service = ref.read(web3ServiceProvider);

    try {
      setState(() {
        _isRunning = true;
        _errorTitle = null;
        _errorMessage = null;
        _activeStepIndex = 1;
        _submission = null;
        _result = null;
        _txHash = null;
        _contractAddress = null;
        _blockNumber = null;
      });

      final submission = await creatorService.submitCreation(
        account: widget.account,
        request: widget.request,
        web3Service: web3Service,
      );
      if (!mounted) return;

      setState(() {
        _submission = submission;
        _txHash = submission.txHash;
        _activeStepIndex = 2;
      });

      final receipt = await web3Service.waitForReceiptAndGet(submission.txHash);
      if (!mounted) return;

      setState(() {
        _contractAddress = receipt.contractAddress?.hexEip55;
        _blockNumber = receipt.blockNumber.blockNum;
        _activeStepIndex = 3;
      });

      final result = await creatorService.completeCreation(
        submission: submission,
        web3Service: web3Service,
      );
      await ref.read(walletProvider.notifier).refreshPortfolio();
      ref.invalidate(poolsProvider);
      if (!mounted) return;

      setState(() {
        _result = result;
        _contractAddress = result.contractAddress;
        _isRunning = false;
        _activeStepIndex = 4;
      });
    } catch (error, stackTrace) {
      print('[token_create][progress_error] error=$error');
      print('[token_create][progress_error][stack]=$stackTrace');
      final userError = TransactionErrorMapper.fromThrowable(error);
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _errorTitle = userError.title;
        _errorMessage = userError.message;
      });
    }
  }

  _TokenCreationStepState _stepState(int stepIndex) {
    if (_errorMessage != null && stepIndex == _activeStepIndex) {
      return _TokenCreationStepState.error;
    }
    if (stepIndex < _activeStepIndex) return _TokenCreationStepState.complete;
    if (_isRunning && stepIndex == _activeStepIndex) {
      return _TokenCreationStepState.loading;
    }
    if (!_isRunning && _result != null && stepIndex <= _activeStepIndex) {
      return _TokenCreationStepState.complete;
    }
    return _TokenCreationStepState.pending;
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
    final foreground = Colors.white;

    return PopScope(
      canPop: !_isRunning,
      child: Scaffold(
        backgroundColor: screenBackground,
        appBar: AppBar(
          backgroundColor: headerBackground,
          elevation: 0,
          foregroundColor: foreground,
          automaticallyImplyLeading: !_isRunning,
          title: Text(
            'Creating Token',
            style: GoogleFonts.spaceGrotesk(
              color: foreground,
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
    final accentGlow = _result != null ? colors.success : colors.accentStrong;
    final symbol = widget.request.normalizedSymbol;
    final title = _result != null
        ? '${widget.request.normalizedName} is ready'
        : 'Deploying $symbol on Reef';
    final subtitle = _result != null
        ? 'Your token contract is live, indexed locally, and ready for the next step.'
        : 'We are broadcasting the contract, waiting for inclusion, and finalizing the token locally.';

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
                  _result != null
                      ? Icons.check_circle_outline_rounded
                      : Icons.auto_awesome_rounded,
                  size: 16,
                  color: colors.accentStrong,
                ),
                const Gap(8),
                Text(
                  _result != null ? 'Token created' : 'Creator workflow',
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
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [colors.accent, colors.accentStrong],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: TokenAvatar(
                    size: 60,
                    iconUrl: TokenIconResolver.resolveIpfsUrl(
                      widget.request.normalizedIconUrl,
                    ),
                    fallbackSeed:
                        '${widget.request.normalizedName}_${widget.request.normalizedSymbol}',
                    resolveFallbackIcon: true,
                    useDeterministicFallback: true,
                    avatarBackgroundColor: colors.appBackground,
                  ),
                ),
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.request.normalizedName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        height: 1,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      symbol,
                      style: TextStyle(
                        color: colors.accentStrong,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(18),
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 26,
              height: 1.05,
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
            'Deployment progress',
            style: GoogleFonts.spaceGrotesk(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 30,
              height: 1,
            ),
          ),
          const Gap(8),
          Text(
            'We will move through each chain step and keep this screen updated as the contract becomes live.',
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
            detail:
                'Authorized for ${AddressUtils.shorten(widget.account.address)}',
          ),
          _buildConnector(colors, active: _activeStepIndex > 1),
          _buildProgressStep(
            colors: colors,
            title: 'Broadcasted to network',
            subtitle: _txHash == null
                ? 'Signing and submitting the deploy transaction.'
                : 'Transaction accepted by Reef.',
            state: _stepState(1),
            detail: _txHash == null ? null : _shortHash(_txHash!),
          ),
          _buildConnector(colors, active: _activeStepIndex > 2),
          _buildProgressStep(
            colors: colors,
            title: 'Included in block',
            subtitle: _blockNumber == null
                ? 'Waiting for block inclusion and execution.'
                : 'Transaction included on chain.',
            state: _stepState(2),
            detail: _blockNumber == null ? null : 'Block #$_blockNumber',
          ),
          _buildConnector(colors, active: _activeStepIndex > 3),
          _buildProgressStep(
            colors: colors,
            title: 'Token created',
            subtitle: _contractAddress == null
                ? 'Finalizing contract details and wallet registry.'
                : 'Contract address assigned and saved locally.',
            state: _stepState(3),
            detail: _contractAddress == null
                ? null
                : AddressUtils.shorten(_contractAddress!),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep({
    required ReefThemeColors colors,
    required String title,
    required String subtitle,
    required _TokenCreationStepState state,
    String? detail,
  }) {
    final accentColor = state == _TokenCreationStepState.error
        ? colors.danger
        : state == _TokenCreationStepState.complete
        ? colors.success
        : colors.accentStrong;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackgroundSecondary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: state == _TokenCreationStepState.loading
              ? accentColor.withOpacity(0.7)
              : colors.borderColor.withOpacity(0.7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIndicator(state: state, colors: colors),
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
                  _errorTitle ?? 'Unable to create token',
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
                      'Something went wrong while deploying the token.',
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
                    _result != null ? 'Back to creator' : 'Back to edit',
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
                    onPressed: _result == null
                        ? null
                        : () => Navigator.of(
                            context,
                          ).pop(TokenCreationProgressOutcome(result: _result)),
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
                      _result == null ? 'Try again later' : 'Continue',
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

  String _shortHash(String value) {
    if (value.length <= 14) return value;
    return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.state, required this.colors});

  final _TokenCreationStepState state;
  final ReefThemeColors colors;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _TokenCreationStepState.complete:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.success,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
        );
      case _TokenCreationStepState.loading:
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
      case _TokenCreationStepState.error:
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
      case _TokenCreationStepState.pending:
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
