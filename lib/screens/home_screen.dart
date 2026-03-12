import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/wallet_provider.dart';
import '../widgets/gradient_header.dart';
import '../widgets/add_account_modal.dart';
import '../core/theme/app_colors.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            leading: const Icon(
              Icons.waves,
              color: Colors.white,
              size: 30,
            ), // Placeholder Reef logo
            title: const Text(
              'Reef',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                onPressed: () {
                  // Navigate to QR scanner
                },
              ),
            ],
          ),
          Expanded(
            child: walletState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : walletState.activeAccount == null
                ? _buildNoAccountState(context)
                : _buildDashboard(context, ref, walletState),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAccountState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 80,
              color: Colors.white54,
            ),
            const SizedBox(height: 24),
            const Text(
              "No account currently available, create or import an account to view your assets.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
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
              child: const Text(
                'Add Account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    WalletState state,
  ) {
    return RefreshIndicator(
      onRefresh: () async => ref.read(walletProvider.notifier).refreshBalance(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Balance Section
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state.showBalance ? '\$ \${state.balance}' : '******',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        state.showBalance
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.white70,
                      ),
                      onPressed: () => ref
                          .read(walletProvider.notifier)
                          .toggleBalanceVisibility(),
                    ),
                  ],
                ),
                Text(
                  "\${state.activeAccount!.address.substring(0, 6)}...\${state.activeAccount!.address.substring(state.activeAccount!.address.length - 4)}",
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(Icons.send, "Send"),
              _buildActionButton(Icons.qr_code, "Receive"),
              _buildActionButton(Icons.swap_calls, "Swap"),
            ],
          ),

          const SizedBox(height: 40),

          // Tabs (Reload, Tokens, NFTs)
          DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  indicatorColor: AppColors.accent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  tabs: [
                    Tab(text: "Tokens"),
                    Tab(text: "NFTs"),
                    Tab(text: "Activity"),
                  ],
                ),
                SizedBox(
                  height: 300,
                  child: TabBarView(
                    children: [
                      _buildTokenList(),
                      const Center(
                        child: Text(
                          "No NFTs found",
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      const Center(
                        child: Text(
                          "No recent activity",
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: AppColors.accent.withOpacity(0.2),
          child: Icon(icon, color: AppColors.accent),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _buildTokenList() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      children: [
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.purple,
            child: Icon(Icons.waves),
          ),
          title: const Text("Ethereum"),
          subtitle: const Text("Native"),
          trailing: const Text(
            "0.0",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
