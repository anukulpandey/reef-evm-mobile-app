import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../providers/wallet_provider.dart';
import '../widgets/official_top_bar.dart';
import '../widgets/official_account_box.dart';
import '../widgets/add_account_modal.dart';
import '../core/theme/styles.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: Styles.primaryBackgroundColor,
      body: Column(
        children: [
          Material(
            elevation: 3,
            shadowColor: Colors.black45,
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
                'Account 1',
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: walletState.activeAccount == null
                  ? _buildNoAccountState(context)
                  : _buildAccountList(context, ref, walletState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAccountState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "No account currently available,\ncreate or import an account to view your assets.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Styles.textLightColor, fontSize: 16),
          ),
          const Gap(20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Styles.secondaryAccentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const AddAccountModal(),
              );
            },
            child: const Text("Add Account", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountList(BuildContext context, WidgetRef ref, WalletState state) {
    return ListView(
      children: [
        const Text(
          "My Accounts",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Styles.primaryColor,
          ),
        ),
        const Gap(16),
        AccountBox(
          address: state.activeAccount!.address,
          name: "Account 1",
          balance: state.balance,
          selected: true,
          onSelected: () {},
        ),
        const Gap(24),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Styles.purpleColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            ref.read(walletProvider.notifier).logout();
          },
          child: const Text("Logout / Clear Storage", style: TextStyle(color: Styles.purpleColor)),
        ),
      ],
    );
  }
}
