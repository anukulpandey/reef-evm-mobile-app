import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../core/theme/reef_theme_colors.dart';
import '../models/transaction_preview.dart';
import '../providers/service_providers.dart';
import '../utils/address_utils.dart';
import '../utils/transaction_error_mapper.dart';

class TransactionConfirmationScreen extends ConsumerStatefulWidget {
  const TransactionConfirmationScreen({
    super.key,
    required this.preview,
    required this.onApprove,
    this.approveButtonText = 'Approve',
    this.rejectButtonText = 'Reject',
  });

  final TransactionPreview preview;
  final Future<String> Function() onApprove;
  final String approveButtonText;
  final String rejectButtonText;

  @override
  ConsumerState<TransactionConfirmationScreen> createState() =>
      _TransactionConfirmationScreenState();
}

class _TransactionConfirmationScreenState
    extends ConsumerState<TransactionConfirmationScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _hasPassword = true;
  bool _isSubmitting = false;
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
      final txHash = await widget.onApprove();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(TransactionApprovalResult(approved: true, txHash: txHash));
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
    final gasPriceGwei = preview.gasPriceWei == null
        ? '--'
        : NumberFormat(
            '0.######',
          ).format(preview.gasPriceWei!.toDouble() / 1000000000).trim();

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: Text(
          'Confirm Transaction',
          style: GoogleFonts.poppins(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard(
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titleValue('Method', preview.methodName, colors: colors),
                  const Gap(12),
                  _titleValue(
                    'Recipient',
                    AddressUtils.shorten(preview.recipientAddress),
                    colors: colors,
                  ),
                  const Gap(12),
                  _titleValue('Amount', preview.amountDisplay, colors: colors),
                  const Gap(12),
                  _titleValue(
                    'Network',
                    '${preview.networkName} (Chain ID: ${preview.chainId})',
                    colors: colors,
                  ),
                  if ((preview.contractAddress ?? '').trim().isNotEmpty) ...[
                    const Gap(12),
                    _titleValue(
                      'Contract',
                      AddressUtils.shorten(preview.contractAddress!),
                      colors: colors,
                    ),
                  ],
                ],
              ),
            ),
            const Gap(12),
            _sectionCard(
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Decoded Data',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Gap(10),
                  if (preview.fields.isEmpty)
                    Text(
                      'No additional parameters',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  for (final field in preview.fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _titleValue(
                        field.label,
                        field.value,
                        colors: colors,
                      ),
                    ),
                  if ((preview.calldataHex ?? '').trim().isNotEmpty) ...[
                    const Gap(6),
                    _titleValue(
                      'Calldata',
                      AddressUtils.shorten(
                        preview.calldataHex!,
                        prefixLength: 10,
                        suffixLength: 8,
                      ),
                      colors: colors,
                    ),
                  ],
                ],
              ),
            ),
            const Gap(12),
            _sectionCard(
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titleValue(
                    'Estimated Network Fee',
                    preview.estimatedFeeDisplay ?? '--',
                    colors: colors,
                  ),
                  const Gap(12),
                  _titleValue(
                    'Gas Limit',
                    preview.gasLimit?.toString() ?? '--',
                    colors: colors,
                  ),
                  const Gap(12),
                  _titleValue(
                    'Gas Price',
                    '$gasPriceGwei Gwei',
                    colors: colors,
                  ),
                ],
              ),
            ),
            const Gap(12),
            _sectionCard(
              colors: colors,
              child: TextField(
                controller: _passwordController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Wallet Password',
                  hintText: 'Enter wallet password',
                  hintStyle: TextStyle(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  floatingLabelStyle: TextStyle(
                    color: colors.accentStrong,
                    fontWeight: FontWeight.w700,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: colors.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colors.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colors.accentStrong),
                  ),
                ),
              ),
            ),
            if (!_hasPassword) ...[
              const Gap(8),
              _sectionCard(
                colors: colors,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You must set an app password before signing transactions.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : _handleSetPasswordPressed,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.accentStrong),
                          foregroundColor: colors.accentStrong,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Set Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Gap(8),
            if (_errorText != null) _buildErrorAlert(colors: colors),
            const Gap(14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(
                            const TransactionApprovalResult(approved: false),
                          ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      widget.rejectButtonText,
                      style: GoogleFonts.poppins(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _approveTransaction,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: colors.accentStrong,
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
                        : Text(
                            widget.approveButtonText,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBackground.withOpacity(0.85),
        border: Border.all(color: colors.borderColor),
        borderRadius: BorderRadius.circular(14),
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
}
