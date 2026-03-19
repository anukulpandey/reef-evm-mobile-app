import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/reef_theme_colors.dart';
import '../../core/theme/styles.dart';
import '../../utils/address_utils.dart';
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
    final confirmStepState = isSentToNetwork
        ? SendTransactionStepState.complete
        : SendTransactionStepState.pending;
    final showHash = (txHash ?? '').trim().isNotEmpty;
    final canContinue = isSentToNetwork;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      child: ViewBoxContainer(
        color: colors.cardBackground,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroStatusHeader(
                colors: colors,
                isReady: canContinue,
                txHash: txHash,
              ),
              const Gap(18),
              _ProgressStepCard(
                colors: colors,
                title: 'Signed locally',
                subtitle:
                    'Your wallet approved the transaction and prepared it for sending.',
                detail: 'Signature complete',
                state: SendTransactionStepState.complete,
              ),
              _buildConnector(colors, active: isSending || isSentToNetwork),
              _ProgressStepCard(
                colors: colors,
                title: 'Broadcasted',
                subtitle: isSentToNetwork
                    ? 'Transaction has been accepted by the Reef network.'
                    : 'Submitting transaction to network…',
                detail: showHash ? 'Hash assigned' : 'Waiting for node',
                state: sendStepState,
              ),
              _buildConnector(colors, active: isSentToNetwork),
              _ProgressStepCard(
                colors: colors,
                title: 'Included in network flow',
                subtitle: isSentToNetwork
                    ? 'The network has received the transaction and it can be tracked now.'
                    : 'Waiting for the network to acknowledge the broadcast.',
                detail: isSentToNetwork
                    ? 'Network accepted'
                    : 'Pending acknowledgement',
                state: networkStepState,
              ),
              _buildConnector(colors, active: isSentToNetwork),
              _ProgressStepCard(
                colors: colors,
                title: 'Ready to continue',
                subtitle: isSentToNetwork
                    ? 'You can go back to the wallet and keep moving.'
                    : 'We will unlock the next step once the transaction is visible on network.',
                detail: isSentToNetwork ? 'Continue available' : 'Hold tight',
                state: confirmStepState,
              ),
              if (showHash) ...[
                const Gap(16),
                _HashBox(hash: txHash!.trim(), onCopy: onCopyHash),
              ],
              const Gap(18),
              _ContinueButton(
                colors: colors,
                canContinue: canContinue,
                onContinue: onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnector(ReefThemeColors colors, {required bool active}) {
    final connectorColor = active ? colors.accentStrong : colors.inputBorder;
    return Padding(
      padding: const EdgeInsets.only(left: 17, top: 4, bottom: 4),
      child: Container(
        width: 3,
        height: 18,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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
                    connectorColor.withOpacity(0.45),
                    connectorColor.withOpacity(0.18),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroStatusHeader extends StatelessWidget {
  const _HeroStatusHeader({
    required this.colors,
    required this.isReady,
    required this.txHash,
  });

  final ReefThemeColors colors;
  final bool isReady;
  final String? txHash;

  @override
  Widget build(BuildContext context) {
    final accentEnd = isReady ? colors.success : colors.accentStrong;
    final statusText = isReady
        ? 'Transaction submitted'
        : 'Sending transaction';
    final subtitle = isReady
        ? 'The network accepted your transfer. You can continue once you finish reviewing the details below.'
        : 'We are signing and broadcasting your transfer to the Reef network.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.cardBackgroundSecondary, colors.cardBackground],
        ),
        border: Border.all(color: colors.borderColor.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: accentEnd.withOpacity(0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [colors.accent, accentEnd]),
            ),
            child: Icon(
              isReady ? Icons.check_rounded : Icons.north_east_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    isReady ? 'Network accepted' : 'Processing',
                    style: TextStyle(
                      color: isReady ? colors.success : colors.accentStrong,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Gap(12),
                Text(
                  statusText,
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                    height: 1,
                  ),
                ),
                const Gap(8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if ((txHash ?? '').trim().isNotEmpty) ...[
                  const Gap(10),
                  Text(
                    AddressUtils.shorten(txHash!.trim(), prefixLength: 8),
                    style: TextStyle(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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
}

class _ProgressStepCard extends StatelessWidget {
  const _ProgressStepCard({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.state,
  });

  final ReefThemeColors colors;
  final String title;
  final String subtitle;
  final String detail;
  final SendTransactionStepState state;

  @override
  Widget build(BuildContext context) {
    final accentColor = state == SendTransactionStepState.complete
        ? colors.success
        : colors.accentStrong;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackgroundSecondary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: state == SendTransactionStepState.loading
              ? accentColor.withOpacity(0.6)
              : colors.borderColor.withOpacity(0.75),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusStepIndicator(state: state, colors: colors),
          const Gap(12),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStepIndicator extends StatelessWidget {
  const _StatusStepIndicator({required this.state, required this.colors});

  final SendTransactionStepState state;
  final ReefThemeColors colors;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case SendTransactionStepState.complete:
        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.success,
          ),
          child: const Icon(Icons.check_rounded, size: 20, color: Colors.white),
        );
      case SendTransactionStepState.loading:
        return SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accentStrong,
                ),
              ),
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 2.8,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Styles.secondaryAccentColorDark,
                  ),
                  backgroundColor: colors.accentStrong.withOpacity(0.16),
                ),
              ),
            ],
          ),
        );
      case SendTransactionStepState.pending:
        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.cardBackground,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackgroundSecondary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderColor.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 18,
                color: colors.accentStrong,
              ),
              const Gap(8),
              Text(
                'Transaction hash',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onCopy,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.topBarChipBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: colors.accentStrong,
                  ),
                ),
              ),
            ],
          ),
          const Gap(12),
          SelectableText(
            hash,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.colors,
    required this.canContinue,
    required this.onContinue,
  });

  final ReefThemeColors colors;
  final bool canContinue;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final child = canContinue
        ? const Text(
            'Continue',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: colors.textMuted,
                ),
              ),
              const Gap(12),
              Text(
                'Processing…',
                style: TextStyle(
                  color: colors.textMuted.withOpacity(0.9),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          );

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: canContinue
              ? const LinearGradient(
                  colors: [
                    Styles.primaryAccentColor,
                    Styles.secondaryAccentColorDark,
                  ],
                )
              : null,
          color: canContinue ? null : colors.cardBackgroundSecondary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: canContinue
              ? [
                  BoxShadow(
                    color: colors.accentStrong.withOpacity(0.24),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                    spreadRadius: -12,
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: canContinue ? onContinue : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
