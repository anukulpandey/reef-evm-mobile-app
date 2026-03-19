import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../core/theme/reef_theme_colors.dart';
import '../core/theme/styles.dart';
import '../models/transaction_preview.dart';
import '../providers/service_providers.dart';
import '../utils/address_utils.dart';
import '../utils/transaction_error_mapper.dart';
import 'transaction_progress_screen.dart';

class TransactionConfirmationScreen extends ConsumerStatefulWidget {
  const TransactionConfirmationScreen({
    super.key,
    required this.preview,
    this.onApprove,
    this.approveButtonText = 'Approve',
    this.rejectButtonText = 'Reject',
    this.authenticateOnly = false,
  }) : assert(
         authenticateOnly || onApprove != null,
         'onApprove is required unless authenticateOnly is true.',
       );

  final TransactionPreview preview;
  final Future<String> Function()? onApprove;
  final String approveButtonText;
  final String rejectButtonText;
  final bool authenticateOnly;

  @override
  ConsumerState<TransactionConfirmationScreen> createState() =>
      _TransactionConfirmationScreenState();
}

class _TransactionConfirmationScreenState
    extends ConsumerState<TransactionConfirmationScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _hasPassword = true;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorTitle;
  String? _errorText;
  bool _showRecoveryActions = false;

  @override
  void initState() {
    super.initState();
    _loadPasswordState();
  }

  Future<void> _loadPasswordState() async {
    final hasPassword = await ref.read(authServiceProvider).hasAppPassword();
    if (!mounted) return;
    setState(() => _hasPassword = hasPassword);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setInlineError(
    String message, {
    String title = 'Action required',
    bool showRecoveryActions = false,
  }) {
    setState(() {
      _errorTitle = title;
      _errorText = message;
      _showRecoveryActions = showRecoveryActions;
    });
  }

  Future<void> _approveTransaction() async {
    if (_isSubmitting) return;

    final auth = ref.read(authServiceProvider);
    var password = _passwordController.text.trim();

    if (!_hasPassword) {
      final createdPassword = await _showSetPasswordDialog();
      if (!mounted) return;
      if (createdPassword == null || createdPassword.trim().isEmpty) {
        _setInlineError(
          'You must set an app password before signing transactions.',
          title: 'App password required',
        );
        return;
      }
      password = createdPassword.trim();
      _passwordController.text = password;
      setState(() {
        _hasPassword = true;
        _errorTitle = null;
        _errorText = null;
        _showRecoveryActions = false;
      });
    }

    if (password.isEmpty) {
      _scrollToPasswordSection();
      _setInlineError(
        'Enter wallet password to continue.',
        title: 'Wallet password required',
      );
      return;
    }

    final passwordOk = await auth.verifyAppPassword(password);
    if (!mounted) return;
    if (!passwordOk) {
      _setInlineError(
        'Invalid wallet password. Please try again.',
        title: 'Authentication failed',
      );
      return;
    }

    final biometricOk = await auth.authenticateForTransaction(
      localizedReason: 'Authenticate to sign this transaction',
    );
    if (!mounted) return;
    if (!biometricOk) {
      _setInlineError(
        'Biometric authentication failed. Please try again.',
        title: 'Authentication failed',
      );
      return;
    }

    setState(() {
      _errorTitle = null;
      _errorText = null;
      _showRecoveryActions = false;
      _isSubmitting = true;
    });

    try {
      if (widget.authenticateOnly) {
        if (!mounted) return;
        Navigator.of(
          context,
        ).pop(const TransactionApprovalResult(approved: true));
        return;
      }

      final progressOutcome = await Navigator.of(context)
          .push<TransactionProgressOutcome>(
            MaterialPageRoute(
              builder: (_) => TransactionProgressScreen(
                preview: widget.preview,
                runTransaction: widget.onApprove!,
              ),
            ),
          );
      if (!mounted) return;
      if (progressOutcome == null || !progressOutcome.completed) {
        setState(() {
          _isSubmitting = false;
        });
        return;
      }
      Navigator.of(context).pop(
        TransactionApprovalResult(
          approved: true,
          txHash: progressOutcome.txHash,
        ),
      );
    } catch (e, stackTrace) {
      print('[tx_confirm][approve_error] error=$e');
      print('[tx_confirm][approve_error][stack]=$stackTrace');
      final userError = TransactionErrorMapper.fromThrowable(e);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorTitle = userError.title;
        _errorText = userError.message;
        _showRecoveryActions = true;
      });
    }
  }

  void _scrollToPasswordSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _passwordFocusNode.requestFocus();
    });
  }

  void _handleModifyTransactionPressed() {
    Navigator.of(context).pop(const TransactionApprovalResult(approved: false));
  }

  Future<void> _handleSetPasswordPressed() async {
    if (_isSubmitting) return;
    final createdPassword = await _showSetPasswordDialog();
    if (!mounted || createdPassword == null || createdPassword.trim().isEmpty) {
      return;
    }
    setState(() {
      _hasPassword = true;
      _errorTitle = null;
      _errorText = null;
      _showRecoveryActions = false;
    });
    _passwordController.text = createdPassword.trim();
  }

  Future<String?> _showSetPasswordDialog() async {
    final auth = ref.read(authServiceProvider);
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          final colors = dialogContext.reefColors;
          String? dialogError;
          bool saving = false;

          return StatefulBuilder(
            builder: (context, setState) {
              Future<void> submit() async {
                final newPassword = newPasswordController.text.trim();
                final confirmPassword = confirmPasswordController.text.trim();

                if (newPassword.isEmpty || confirmPassword.isEmpty) {
                  setState(() {
                    dialogError = 'Enter and confirm your app password.';
                  });
                  return;
                }
                if (newPassword.length < 6) {
                  setState(() {
                    dialogError = 'Password must be at least 6 characters.';
                  });
                  return;
                }
                if (newPassword != confirmPassword) {
                  setState(() {
                    dialogError = 'Passwords do not match.';
                  });
                  return;
                }

                setState(() {
                  saving = true;
                  dialogError = null;
                });
                try {
                  await auth.setAppPassword(newPassword);
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(newPassword);
                } catch (_) {
                  if (!dialogContext.mounted) return;
                  setState(() {
                    saving = false;
                    dialogError = 'Unable to save password. Please try again.';
                  });
                }
              }

              InputDecoration passwordDecoration(String label, String hint) {
                return InputDecoration(
                  labelText: label,
                  hintText: hint,
                  hintStyle: TextStyle(color: colors.textMuted),
                  filled: true,
                  fillColor: colors.inputFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
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
                    borderSide: BorderSide(color: colors.accentStrong),
                  ),
                );
              }

              return AlertDialog(
                backgroundColor: colors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  'Set App Password',
                  style: GoogleFonts.poppins(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You must set an app password before signing transactions.',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      const Gap(12),
                      TextField(
                        controller: newPasswordController,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: passwordDecoration(
                          'New Password',
                          'Enter new password',
                        ),
                      ),
                      const Gap(10),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: passwordDecoration(
                          'Confirm Password',
                          'Re-enter new password',
                        ),
                      ),
                      if (dialogError != null) ...[
                        const Gap(10),
                        Text(
                          dialogError!,
                          style: TextStyle(
                            color: colors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: saving ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accentStrong,
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Set Password'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final colors = context.reefColors;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final gasPriceGwei = preview.gasPriceWei == null
        ? '--'
        : NumberFormat(
            '0.######',
          ).format(preview.gasPriceWei!.toDouble() / 1000000000).trim();
    final screenBackground = isDarkTheme
        ? const Color(0xFF1E0B3B)
        : Styles.greyColor;
    final appBarBackground = isDarkTheme
        ? const Color(0xFF5A23A5)
        : Colors.deepPurple.shade700;
    const appBarForeground = Colors.white;

    return Scaffold(
      backgroundColor: screenBackground,
      appBar: AppBar(
        backgroundColor: appBarBackground,
        elevation: 0,
        foregroundColor: appBarForeground,
        title: Text(
          'Confirm Transaction',
          style: GoogleFonts.spaceGrotesk(
            color: appBarForeground,
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
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCard(
                      preview: preview,
                      colors: colors,
                      isDarkTheme: isDarkTheme,
                    ),
                    const Gap(16),
                    _sectionCard(
                      colors: colors,
                      radius: 28,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeading(
                            'Transaction details',
                            'Review the decoded values before signing.',
                            colors: colors,
                          ),
                          const Gap(14),
                          if (preview.fields.isEmpty)
                            _detailValueTile(
                              label: 'Details',
                              value: 'No additional parameters',
                              colors: colors,
                            ),
                          for (final field in preview.fields) ...[
                            _detailValueTile(
                              label: field.label,
                              value: field.value,
                              colors: colors,
                            ),
                            const Gap(10),
                          ],
                          _detailValueTile(
                            label: 'Method',
                            value: _formatMethodName(preview.methodName),
                            colors: colors,
                          ),
                          if ((preview.calldataHex ?? '')
                              .trim()
                              .isNotEmpty) ...[
                            const Gap(10),
                            _detailValueTile(
                              label: 'Calldata',
                              value: preview.calldataHex!,
                              colors: colors,
                              monospace: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Gap(16),
                    _sectionCard(
                      colors: colors,
                      radius: 28,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeading(
                            'Network fee',
                            'The final gas usage may vary slightly on chain.',
                            colors: colors,
                          ),
                          const Gap(14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _metricCard(
                                label: 'Estimated fee',
                                value: preview.estimatedFeeDisplay ?? '--',
                                colors: colors,
                              ),
                              _metricCard(
                                label: 'Gas limit',
                                value: _formatLargeNumber(preview.gasLimit),
                                colors: colors,
                              ),
                              _metricCard(
                                label: 'Gas price',
                                value: '$gasPriceGwei Gwei',
                                colors: colors,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Gap(20),
                  ],
                ),
              ),
            ),
            _buildStickyActionArea(colors: colors),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyActionArea({required ReefThemeColors colors}) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        decoration: BoxDecoration(
          color: colors.appBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 22,
              offset: const Offset(0, -8),
              spreadRadius: -18,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPasswordPanel(colors: colors),
              if (_errorText != null) ...[
                const Gap(12),
                _buildErrorAlert(colors: colors),
              ],
              const Gap(12),
              _buildBottomActions(colors: colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordPanel({required ReefThemeColors colors}) {
    return _sectionCard(
      colors: colors,
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Wallet password',
            _hasPassword
                ? 'Password and biometric approval are required to sign.'
                : 'Set your app password before approving this transaction.',
            colors: colors,
          ),
          const Gap(14),
          Container(
            decoration: BoxDecoration(
              color: colors.cardBackgroundSecondary,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.inputBorder, width: 1.2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: _obscurePassword,
              enableSuggestions: false,
              autocorrect: false,
              style: GoogleFonts.spaceGrotesk(
                color: colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Enter wallet password',
                hintStyle: TextStyle(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                prefixIcon: Icon(
                  Icons.lock_outline_rounded,
                  color: colors.textMuted,
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ),
          ),
          if (!_hasPassword) ...[
            const Gap(12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.cardBackgroundSecondary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: colors.accentStrong,
                    size: 20,
                  ),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set an app password before signing transactions.',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Gap(10),
                        OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : _handleSetPasswordPressed,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colors.accentStrong),
                            foregroundColor: colors.accentStrong,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('Set Password'),
                        ),
                      ],
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

  Widget _buildErrorAlert({required ReefThemeColors colors}) {
    final title = _errorTitle ?? 'Transaction failed';
    final message = _errorText ?? 'Unable to process the transaction.';
    final backgroundColor = colors.danger.withOpacity(
      Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.1,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.danger.withOpacity(0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.danger, size: 20),
              const Gap(8),
              Expanded(
                child: Text(
                  title,
                  softWrap: true,
                  style: GoogleFonts.poppins(
                    color: colors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const Gap(6),
          Text(
            message,
            softWrap: true,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          if (_showRecoveryActions) ...[
            const Gap(10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _approveTransaction,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.borderColor),
                    foregroundColor: colors.textPrimary,
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -2,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : _handleModifyTransactionPressed,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modify'),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accentStrong,
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Widget _sectionCard({
    required Widget child,
    required ReefThemeColors colors,
    double radius = 14,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.cardBackground.withOpacity(0.85),
        border: Border.all(color: colors.borderColor),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }

  static Widget _titleValue(
    String title,
    String value, {
    required ReefThemeColors colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(3),
        SelectableText(
          value,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required TransactionPreview preview,
    required ReefThemeColors colors,
    required bool isDarkTheme,
  }) {
    final topLabel = preview.title.trim().isNotEmpty
        ? preview.title.trim()
        : _formatMethodName(preview.methodName);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.borderColor),
        boxShadow: [
          BoxShadow(
            color: (isDarkTheme ? Colors.black : colors.accentStrong)
                .withOpacity(isDarkTheme ? 0.18 : 0.08),
            blurRadius: 32,
            offset: const Offset(0, 14),
            spreadRadius: -18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [colors.accent, colors.accentStrong],
                  ),
                ),
                child: const Center(
                  child: Image(
                    image: AssetImage('assets/images/reef.png'),
                    width: 28,
                    height: 28,
                  ),
                ),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topLabel,
                      style: GoogleFonts.spaceGrotesk(
                        color: colors.textPrimary,
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      'Review all transaction details before signing.',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.cardBackgroundSecondary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are about to approve',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const Gap(8),
                Text(
                  preview.amountDisplay,
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.textPrimary,
                    fontSize: 31,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const Gap(14),
                _summaryRow(
                  label: preview.recipientLabel,
                  value: AddressUtils.shorten(
                    preview.recipientAddress,
                    prefixLength: 7,
                    suffixLength: 5,
                  ),
                  colors: colors,
                ),
                const Gap(10),
                _summaryRow(
                  label: 'Network',
                  value: '${preview.networkName} • ${preview.chainId}',
                  colors: colors,
                ),
                if ((preview.contractAddress ?? '').trim().isNotEmpty) ...[
                  const Gap(10),
                  _summaryRow(
                    label: 'Contract',
                    value: AddressUtils.shorten(
                      preview.contractAddress!,
                      prefixLength: 7,
                      suffixLength: 5,
                    ),
                    colors: colors,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions({required ReefThemeColors colors}) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSubmitting
                ? null
                : () => Navigator.of(
                    context,
                  ).pop(const TransactionApprovalResult(approved: false)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colors.inputBorder, width: 1.6),
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? colors.cardBackground.withOpacity(0.25)
                  : Colors.white.withOpacity(0.9),
              foregroundColor: colors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: Text(
              widget.rejectButtonText,
              style: GoogleFonts.spaceGrotesk(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const Gap(12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[colors.accent, colors.accentStrong],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colors.accentStrong.withOpacity(0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  spreadRadius: -10,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _approveTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.approveButtonText,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeading(
    String title,
    String subtitle, {
    required ReefThemeColors colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: colors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const Gap(6),
        Text(
          subtitle,
          style: TextStyle(
            color: colors.textMuted,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _summaryRow({
    required String label,
    required String value,
    required ReefThemeColors colors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: TextStyle(
              color: colors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Gap(10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailValueTile({
    required String label,
    required String value,
    required ReefThemeColors colors,
    bool monospace = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBackgroundSecondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(6),
          SelectableText(
            value,
            style:
                (monospace
                        ? GoogleFonts.robotoMono()
                        : GoogleFonts.spaceGrotesk())
                    .copyWith(
                      color: colors.textPrimary,
                      fontSize: monospace ? 13 : 16,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required ReefThemeColors colors,
  }) {
    return SizedBox(
      width: 160,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.cardBackgroundSecondary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(6),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLargeNumber(int? value) {
    if (value == null) return '--';
    return NumberFormat.decimalPattern().format(value);
  }

  String _formatMethodName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Transaction';
    final normalized = trimmed
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ');
    final words = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .toList();
    return words.join(' ');
  }
}
