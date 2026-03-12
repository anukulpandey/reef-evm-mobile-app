import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../providers/wallet_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/official_top_bar.dart';
import '../widgets/official_account_box.dart';
import '../widgets/add_account_modal.dart';
import '../core/theme/styles.dart';
import 'wallet_connect_screen.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF2B0052),
      body: Column(
        children: [
          Material(
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/reef-header.png"),
                  fit: BoxFit.cover,
                  alignment: Alignment(-0.82, 1.0),
                ),
              ),
              child: topBar(
                context,
                walletState.activeAccount?.address,
                walletState.displayAccountName,
                onWalletConnectTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WalletConnectScreen(),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: walletState.activeAccount == null
                ? _buildNoAccountState(context, l10n)
                : _buildAccountList(context, ref, walletState, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAccountState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.noAccountAvailable,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFCFC3E6), fontSize: 16),
          ),
          const Gap(20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: Styles.buttonGradient,
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(40),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const AddAccountModal(),
                );
              },
              child: Text(
                l10n.addAccount,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountList(
    BuildContext context,
    WidgetRef ref,
    WalletState state,
    AppLocalizations l10n,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.myAccount,
              style: TextStyle(
                fontSize: Styles.fsPageTitle,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(
                Icons.add_circle,
                color: Color(0xFFB9359A),
                size: 24,
              ),
              label: Text(
                l10n.add,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: Styles.fsBodyStrong,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFB9359A), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const AddAccountModal(),
                );
              },
            ),
          ],
        ),
        const Gap(16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFBF37A7), Color(0xFF7B39C8)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: Text(
              l10n.buyReef,
              style: TextStyle(
                color: Colors.white,
                fontSize: Styles.fsBodyStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const Gap(16),
        AccountBox(
          address: state.activeAccount!.address,
          name: state.displayAccountName,
          balance: _formatReefBalance(state.balance),
          selected: true,
          onSelected: () {},
          onMenuAction: (action) => _handleAccountMenuAction(
            context: context,
            ref: ref,
            state: state,
            action: action,
          ),
          selectedText: l10n.selected,
          addressPrefix: l10n.addressLabel,
          selectAccountText: l10n.selectAccount,
          copyEvmAddressText: l10n.copyEvmAddress,
          deleteText: l10n.deleteLabel,
          exportAccountText: l10n.exportAccount,
        ),
      ],
    );
  }

  Future<void> _handleAccountMenuAction({
    required BuildContext context,
    required WidgetRef ref,
    required WalletState state,
    required AccountMenuAction action,
  }) async {
    final l10n = AppLocalizations.of(context);
    final account = state.activeAccount;
    if (account == null) return;

    switch (action) {
      case AccountMenuAction.selectAccount:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.accountSelected),
            duration: Duration(seconds: 1),
          ),
        );
        break;
      case AccountMenuAction.copyEvmAddress:
        await Clipboard.setData(ClipboardData(text: account.address));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.evmAddressCopied),
            duration: Duration(seconds: 1),
          ),
        );
        break;
      case AccountMenuAction.delete:
        final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.deleteAccount),
            content: Text(l10n.deleteAccountConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.deleteLabel),
              ),
            ],
          ),
        );
        if (shouldDelete == true) {
          ref.read(walletProvider.notifier).logout();
        }
        break;
      case AccountMenuAction.exportAccount:
        final exportValue = account.mnemonic.isNotEmpty
            ? account.mnemonic
            : account.privateKey;
        await Clipboard.setData(ClipboardData(text: exportValue));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              account.mnemonic.isNotEmpty
                  ? l10n.mnemonicCopiedForExport
                  : l10n.privateKeyCopiedForExport,
            ),
            duration: const Duration(seconds: 1),
          ),
        );
        break;
    }
  }

  static String _formatReefBalance(String raw) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '')) ?? 0;
    if (parsed <= 0) return '0.0';
    if (parsed >= 1000) return parsed.toStringAsFixed(2);
    if (parsed >= 1)
      return parsed
          .toStringAsFixed(3)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    return parsed
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
