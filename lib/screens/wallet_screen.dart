import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../providers/wallet_provider.dart';
import '../widgets/gradient_header.dart';
import '../widgets/add_account_modal.dart';
import '../widgets/glass_card.dart';
import '../core/theme/app_colors.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Column(
        children: [
          GradientHeader(
            title: const Text(
              'My Account',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
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
          Expanded(
            child: walletState.activeAccount == null
                ? _buildNoAccountState(context)
                : _buildAccountDetails(context, ref, walletState),
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
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const AddAccountModal(),
              );
            },
            child: const Text("Add Account"),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDetails(
    BuildContext context,
    WidgetRef ref,
    WalletState state,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          GlassCard(
            height: 350,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Address",
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.activeAccount!.address,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        size: 20,
                        color: AppColors.accent,
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: state.activeAccount!.address),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Address copied')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (state.activeAccount!.mnemonic.isNotEmpty) ...[
                  const Text(
                    "Recovery Phrase (Save this!)",
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      state.activeAccount!.mnemonic,
                      style: const TextStyle(
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    onPressed: () {
                      ref.read(walletProvider.notifier).logout();
                    },
                    child: const Text("Log Out / Clear State"),
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
