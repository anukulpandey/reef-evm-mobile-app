import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../core/theme/styles.dart';
import '../models/transaction_preview.dart';
import '../providers/service_providers.dart';
import '../utils/address_utils.dart';

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
  String? _errorText;

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

  Future<void> _approveTransaction() async {
    if (_isSubmitting) return;

    final auth = ref.read(authServiceProvider);
    final password = _passwordController.text.trim();

    if (!_hasPassword) {
      setState(() {
        _errorText = 'Set an app password in Settings before signing.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() => _errorText = 'Enter wallet password to continue.');
      return;
    }

    final passwordOk = await auth.verifyAppPassword(password);
    if (!mounted) return;
    if (!passwordOk) {
      setState(() => _errorText = 'Invalid wallet password.');
      return;
    }

    final biometricOk = await auth.authenticateForTransaction(
      localizedReason: 'Authenticate to sign this transaction',
    );
    if (!mounted) return;
    if (!biometricOk) {
      setState(() => _errorText = 'Biometric authentication failed.');
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    try {
      final txHash = await widget.onApprove();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(TransactionApprovalResult(approved: true, txHash: txHash));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final gasPriceGwei = preview.gasPriceWei == null
        ? '--'
        : NumberFormat(
            '0.######',
          ).format(preview.gasPriceWei!.toDouble() / 1000000000).trim();

    return Scaffold(
      backgroundColor: Styles.primaryBackgroundColor,
      appBar: AppBar(
        backgroundColor: Styles.primaryBackgroundColor,
        elevation: 0,
        foregroundColor: Styles.textColor,
        title: Text(
          'Confirm Transaction',
          style: GoogleFonts.poppins(
            color: Styles.textColor,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titleValue('Method', preview.methodName),
                  const Gap(12),
                  _titleValue(
                    'Recipient',
                    AddressUtils.shorten(preview.recipientAddress),
                  ),
                  const Gap(12),
                  _titleValue('Amount', preview.amountDisplay),
                  const Gap(12),
                  _titleValue(
                    'Network',
                    '${preview.networkName} (Chain ID: ${preview.chainId})',
                  ),
                  if ((preview.contractAddress ?? '').trim().isNotEmpty) ...[
                    const Gap(12),
                    _titleValue(
                      'Contract',
                      AddressUtils.shorten(preview.contractAddress!),
                    ),
                  ],
                ],
              ),
            ),
            const Gap(12),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Decoded Data',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Styles.textColor,
                    ),
                  ),
                  const Gap(10),
                  if (preview.fields.isEmpty)
                    const Text(
                      'No additional parameters',
                      style: TextStyle(color: Styles.textLightColor),
                    ),
                  for (final field in preview.fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _titleValue(field.label, field.value),
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
                    ),
                  ],
                ],
              ),
            ),
            const Gap(12),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titleValue(
                    'Estimated Network Fee',
                    preview.estimatedFeeDisplay ?? '--',
                  ),
                  const Gap(12),
                  _titleValue(
                    'Gas Limit',
                    preview.gasLimit?.toString() ?? '--',
                  ),
                  const Gap(12),
                  _titleValue('Gas Price', '$gasPriceGwei Gwei'),
                ],
              ),
            ),
            const Gap(12),
            _sectionCard(
              child: TextField(
                controller: _passwordController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                style: const TextStyle(color: Styles.textColor),
                decoration: const InputDecoration(
                  labelText: 'Wallet Password',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Styles.secondaryAccentColorDark,
                    ),
                  ),
                ),
              ),
            ),
            const Gap(8),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: Text(
                  _errorText!,
                  style: const TextStyle(
                    color: Styles.errorColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
                      side: const BorderSide(color: Color(0xFF9D92B6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      widget.rejectButtonText,
                      style: GoogleFonts.poppins(
                        color: Styles.textColor,
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
                      backgroundColor: Styles.primaryAccentColor,
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

  static Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  static Widget _titleValue(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Styles.textLightColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(3),
        SelectableText(
          value,
          style: const TextStyle(
            color: Styles.textColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
