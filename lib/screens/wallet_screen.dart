import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../models/account.dart';
import '../providers/service_providers.dart';
import '../providers/settings_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/navigation_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/amount_utils.dart';
import '../widgets/official_top_bar.dart';
import '../widgets/official_account_box.dart';
import '../widgets/add_account_modal.dart';
import '../widgets/common/reef_loading_widgets.dart';
import '../widgets/wallet/account_action_dialogs.dart';
import '../core/theme/styles.dart';

enum _AvailableAccountsSortMode {
  defaultOrder,
  balanceHighToLow,
  balanceLowToHigh,
}

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  _AvailableAccountsSortMode _availableSortMode =
      _AvailableAccountsSortMode.defaultOrder;

  @override
  Widget build(BuildContext context) {
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
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: walletState.activeAccount == null
                      ? _buildNoAccountState(context, l10n)
                      : _buildAccountList(context, ref, walletState, l10n),
                ),
                if (walletState.isLoading)
                  const Positioned(
                    top: 12,
                    right: 16,
                    child: ReefLoadingPill(label: 'Syncing accounts'),
                  ),
              ],
            ),
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
        FutureBuilder<List<_StoredAccountEntry>>(
          future: _loadStoredAccounts(ref, state),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: ReefLoadingCard(
                  title: 'Loading accounts',
                  subtitle: 'Syncing stored accounts and balances.',
                  compact: true,
                ),
              );
            }

            final entries = snapshot.data ?? const <_StoredAccountEntry>[];
            if (entries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.noAccountAvailable,
                  style: const TextStyle(
                    color: Color(0xFFCFC3E6),
                    fontSize: 14,
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildAccountCards(context, ref, state, l10n, entries),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildAccountCards(
    BuildContext context,
    WidgetRef ref,
    WalletState state,
    AppLocalizations l10n,
    List<_StoredAccountEntry> entries,
  ) {
    final selectedAddress = state.activeAccount?.address.toLowerCase();
    final selectedEntries = entries
        .where(
          (entry) => entry.account.address.toLowerCase() == selectedAddress,
        )
        .toList();
    final availableEntries = entries
        .where(
          (entry) => entry.account.address.toLowerCase() != selectedAddress,
        )
        .toList();
    final sortedAvailableEntries = _sortAvailableEntries(availableEntries);

    final widgets = <Widget>[];

    for (final entry in selectedEntries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildAccountCard(
            context: context,
            ref: ref,
            state: state,
            l10n: l10n,
            entry: entry,
            isSelected: true,
          ),
        ),
      );
    }

    if (sortedAvailableEntries.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.availableAccounts,
                  style: const TextStyle(
                    color: Color(0xFFCFC3E6),
                    fontSize: 20,
                  ),
                ),
              ),
              PopupMenuButton<_AvailableAccountsSortMode>(
                tooltip: l10n.sortByBalance,
                initialValue: _availableSortMode,
                color: Colors.white,
                icon: const Icon(
                  Icons.sort_rounded,
                  color: Color(0xFFCFC3E6),
                  size: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (mode) {
                  if (_availableSortMode == mode) return;
                  setState(() => _availableSortMode = mode);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _AvailableAccountsSortMode.defaultOrder,
                    child: Text(
                      l10n.defaultOrder,
                      style: const TextStyle(
                        color: Color(0xFF1F1F28),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: _AvailableAccountsSortMode.balanceHighToLow,
                    child: Text(
                      l10n.balanceHighToLow,
                      style: const TextStyle(
                        color: Color(0xFF1F1F28),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: _AvailableAccountsSortMode.balanceLowToHigh,
                    child: Text(
                      l10n.balanceLowToHigh,
                      style: const TextStyle(
                        color: Color(0xFF1F1F28),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      for (final entry in sortedAvailableEntries) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAccountCard(
              context: context,
              ref: ref,
              state: state,
              l10n: l10n,
              entry: entry,
              isSelected: false,
            ),
          ),
        );
      }
    }

    return widgets;
  }

  List<_StoredAccountEntry> _sortAvailableEntries(
    List<_StoredAccountEntry> entries,
  ) {
    if (_availableSortMode == _AvailableAccountsSortMode.defaultOrder) {
      return entries;
    }

    final sorted = List<_StoredAccountEntry>.from(entries);
    sorted.sort((a, b) {
      final aBalance = _tryParseBalanceValue(a.balance);
      final bBalance = _tryParseBalanceValue(b.balance);
      if (aBalance == null && bBalance == null) return 0;
      if (aBalance == null) return 1;
      if (bBalance == null) return -1;
      if (_availableSortMode == _AvailableAccountsSortMode.balanceLowToHigh) {
        return aBalance.compareTo(bBalance);
      }
      return bBalance.compareTo(aBalance);
    });
    return sorted;
  }

  static double? _tryParseBalanceValue(String raw) {
    final parsed = AmountUtils.parseNumeric(raw, fallback: double.nan);
    return parsed.isNaN ? null : parsed;
  }

  Widget _buildAccountCard({
    required BuildContext context,
    required WidgetRef ref,
    required WalletState state,
    required AppLocalizations l10n,
    required _StoredAccountEntry entry,
    required bool isSelected,
  }) {
    final displayName = entry.name.trim().isEmpty ? l10n.noName : entry.name;
    return AccountBox(
      address: entry.account.address,
      name: displayName,
      balance: AmountUtils.formatCompactBalance(entry.balance),
      selected: isSelected,
      showBalance: state.showBalance,
      onSelected: () => _selectAccountAndMaybeGoHome(
        context: context,
        ref: ref,
        address: entry.account.address,
      ),
      onMenuAction: (action) => _handleAccountMenuAction(
        context: context,
        ref: ref,
        account: entry.account,
        currentName: displayName,
        action: action,
      ),
      selectedText: l10n.selected,
      addressPrefix: l10n.addressLabel,
      selectAccountText: l10n.selectAccount,
      copyEvmAddressText: l10n.copyEvmAddress,
      renameAccountText: l10n.renameAccount,
      deleteText: l10n.deleteLabel,
      exportMnemonicText: l10n.exportMnemonic,
      exportPrivateKeyText: l10n.exportPrivateKey,
    );
  }

  Future<List<_StoredAccountEntry>> _loadStoredAccounts(
    WidgetRef ref,
    WalletState state,
  ) async {
    final walletService = ref.read(walletServiceProvider);
    final addresses = await walletService.getAccounts();

    // Deduplicate by lowercase while preserving insertion order.
    final uniqueAddresses = <String>[];
    final seen = <String>{};
    for (final address in addresses) {
      final normalized = address.trim().toLowerCase();
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      uniqueAddresses.add(address.trim());
    }

    final entries = <_StoredAccountEntry>[];
    final selectedAddress = state.activeAccount?.address.toLowerCase();
    for (final address in uniqueAddresses) {
      final account = await walletService.loadAccount(address);
      if (account == null) continue;
      final accountName = await walletService.getAccountName(account.address);
      final normalizedAddress = account.address.toLowerCase();
      final storedBalance = state.accountBalances[normalizedAddress];
      final fallbackSelectedBalance = normalizedAddress == selectedAddress
          ? state.balance
          : '';
      entries.add(
        _StoredAccountEntry(
          account: account,
          name: (accountName ?? '<No Name>').trim(),
          balance: storedBalance ?? fallbackSelectedBalance,
        ),
      );
    }

    if (entries.isEmpty && state.activeAccount != null) {
      entries.add(
        _StoredAccountEntry(
          account: state.activeAccount!,
          name: (state.accountName ?? '<No Name>').trim(),
          balance: state.balance,
        ),
      );
    }

    entries.sort((a, b) {
      final aSelected = a.account.address.toLowerCase() == selectedAddress;
      final bSelected = b.account.address.toLowerCase() == selectedAddress;
      if (aSelected == bSelected) return 0;
      return aSelected ? -1 : 1;
    });

    return entries;
  }

  Future<void> _handleAccountMenuAction({
    required BuildContext context,
    required WidgetRef ref,
    required Account account,
    required String currentName,
    required AccountMenuAction action,
  }) async {
    final l10n = AppLocalizations.of(context);

    switch (action) {
      case AccountMenuAction.selectAccount:
        await _selectAccountAndMaybeGoHome(
          context: context,
          ref: ref,
          address: account.address,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.accountSelected),
            duration: const Duration(seconds: 1),
          ),
        );
        break;
      case AccountMenuAction.copyEvmAddress:
        await Clipboard.setData(ClipboardData(text: account.address));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.evmAddressCopied),
            duration: const Duration(seconds: 1),
          ),
        );
        break;
      case AccountMenuAction.renameAccount:
        final updatedName = await showRenameAccountDialog(
          context: context,
          l10n: l10n,
          currentName: currentName,
        );
        if (updatedName == null) return;
        await ref
            .read(walletProvider.notifier)
            .renameAccount(address: account.address, name: updatedName);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.accountRenamed),
            duration: const Duration(seconds: 1),
          ),
        );
        break;
      case AccountMenuAction.delete:
        final shouldDelete = await showDeleteAccountConfirmation(
          context: context,
          l10n: l10n,
        );
        if (shouldDelete) {
          await ref
              .read(walletProvider.notifier)
              .deleteAccount(account.address);
        }
        break;
      case AccountMenuAction.exportMnemonic:
        final canExport = await confirmExportWithPassword(
          context: context,
          l10n: l10n,
          authService: ref.read(authServiceProvider),
        );
        if (!canExport) return;
        if (account.mnemonic.trim().isEmpty) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.noMnemonicAvailable),
              duration: const Duration(seconds: 1),
            ),
          );
          return;
        }
        final exportValue = account.mnemonic.trim();
        await Clipboard.setData(ClipboardData(text: exportValue));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.mnemonicCopiedForExport),
            duration: const Duration(seconds: 1),
          ),
        );
        break;
      case AccountMenuAction.exportPrivateKey:
        final canExport = await confirmExportWithPassword(
          context: context,
          l10n: l10n,
          authService: ref.read(authServiceProvider),
        );
        if (!canExport) return;
        await Clipboard.setData(ClipboardData(text: account.privateKey.trim()));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.privateKeyCopiedForExport),
            duration: const Duration(seconds: 1),
          ),
        );
        break;
    }
  }

  Future<void> _selectAccountAndMaybeGoHome({
    required BuildContext context,
    required WidgetRef ref,
    required String address,
  }) async {
    await ref.read(walletProvider.notifier).selectAccount(address);
    final goHomeOnSwitch = ref.read(settingsProvider).goHomeEnabled;
    if (!goHomeOnSwitch) return;
    ref.read(navigationTabProvider.notifier).goHome();
  }
}

class _StoredAccountEntry {
  final Account account;
  final String name;
  final String balance;

  const _StoredAccountEntry({
    required this.account,
    required this.name,
    required this.balance,
  });
}
