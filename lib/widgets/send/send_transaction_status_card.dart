import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/reef_theme_colors.dart';
import '../../core/theme/styles.dart';
import '../official_components.dart';

enum SendTransactionStepState { pending, loading, complete }

class SendTransactionStatusCard extends StatelessWidget {
  const SendTransactionStatusCard({
    super.key,
    required this.isSending,
    required this.isSentToNetwork,
    required this.txHash,
    required this.onContinue,
    required this.onCopyHash,
  });

  final bool isSending;
  final bool isSentToNetwork;
  final String? txHash;
  final VoidCallback onContinue;
  final VoidCallback onCopyHash;

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    final sendStepState = isSentToNetwork
        ? SendTransactionStepState.complete
        : (isSending
              ? SendTransactionStepState.loading
              : SendTransactionStepState.pending);
    final networkStepState = isSentToNetwork
        ? SendTransactionStepState.complete
        : SendTransactionStepState.pending;
    final showHash = (txHash ?? '').trim().isNotEmpty;
    final canContinue = isSentToNetwork;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: ViewBoxContainer(
        color: colors.cardBackground,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusTimelineStep(
                title: 'Sending transaction',
                subtitle: 'Sending transaction to network...',
                state: sendStepState,
              ),
              _buildConnector(context, active: isSentToNetwork),
              _StatusTimelineStep(
                title: 'Sent to network',
                subtitle: isSentToNetwork
                    ? 'Transaction accepted by network.'
                    : 'Waiting for network confirmation...',
                state: networkStepState,
              ),
              if (showHash) ...[
                const Gap(12),
                _HashBox(hash: txHash!.trim(), onCopy: onCopyHash),
              ],
              const Gap(20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    shadowColor: const Color(0x559d6cff),
                    elevation: canContinue ? 5 : 0,
                    backgroundColor: canContinue
                        ? Styles.primaryAccentColor
                        : colors.cardBackgroundSecondary,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 32,
                    ),
                  ),
                  onPressed: canContinue ? onContinue : null,
                  child: Text(
                    canContinue ? 'Continue' : 'Processing...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: canContinue
                          ? Styles.whiteColor
                          : colors.textMuted.withOpacity(0.8),
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

  Widget _buildConnector(BuildContext context, {required bool active}) {
    final colors = context.reefColors;
    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
      child: Container(
        width: 2,
        height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Styles.primaryAccentColor,
                    Styles.secondaryAccentColorDark,
                  ],
                )
              : LinearGradient(
                  colors: [
                    colors.inputBorder.withOpacity(0.7),
                    colors.inputBorder.withOpacity(0.7),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatusTimelineStep extends StatelessWidget {
  const _StatusTimelineStep({
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final String title;
  final String subtitle;
  final SendTransactionStepState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusStepIndicator(state: state),
        const Gap(12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const Gap(4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusStepIndicator extends StatelessWidget {
  const _StatusStepIndicator({required this.state});

  final SendTransactionStepState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    switch (state) {
      case SendTransactionStepState.complete:
        return Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: Styles.buttonGradient,
          ),
          child: const Icon(Icons.check_rounded, size: 20, color: Colors.white),
        );
      case SendTransactionStepState.loading:
        return SizedBox(
          width: 30,
          height: 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Styles.primaryAccentColor,
                ),
              ),
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Styles.secondaryAccentColorDark,
                  ),
                  backgroundColor: Color(0x33bf37a7),
                ),
              ),
            ],
          ),
        );
      case SendTransactionStepState.pending:
        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.cardBackgroundSecondary.withOpacity(0.85),
            border: Border.all(color: colors.inputBorder, width: 2),
          ),
        );
    }
  }
}

class _HashBox extends StatelessWidget {
  const _HashBox({required this.hash, required this.onCopy});

  final String hash;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colors.cardBackgroundSecondary,
        border: Border.all(color: colors.borderColor.withOpacity(0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              hash,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          const Gap(8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onCopy,
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, size: 18, color: colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
