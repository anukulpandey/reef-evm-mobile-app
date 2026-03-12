import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../providers/settings_provider.dart';
import '../widgets/official_top_bar.dart';
import '../providers/wallet_provider.dart';
import '../core/theme/styles.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  "Settings",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Styles.primaryColor),
                ),
                const Gap(16),
                _buildSectionTitle("Security"),
                SwitchListTile(
                  title: const Text("Biometric Authentication", style: TextStyle(color: Styles.textColor)),
                  subtitle: const Text("Require FaceID/TouchID to open", style: TextStyle(color: Styles.textLightColor)),
                  activeColor: Styles.purpleColor,
                  value: settings.useBiometrics,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).setBiometrics(val);
                  },
                ),
                const Divider(color: Colors.black12),
                _buildSectionTitle("General"),
                ListTile(
                  title: const Text("WalletConnect", style: TextStyle(color: Styles.textColor)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Styles.textLightColor),
                  onTap: () {},
                ),
                const Divider(color: Colors.black12),
                _buildSectionTitle("Developer"),
                ListTile(
                  title: const Text("RPC Endpoint", style: TextStyle(color: Styles.textColor)),
                  subtitle: Text(settings.rpcUrl, style: const TextStyle(color: Styles.textLightColor)),
                  trailing: const Icon(Icons.edit, size: 16, color: Styles.purpleColor),
                  onTap: () => _showRpcEditDialog(context, ref, settings.rpcUrl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(color: Styles.purpleColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
      ),
    );
  }

  void _showRpcEditDialog(BuildContext context, WidgetRef ref, String currentRpc) {
    final controller = TextEditingController(text: currentRpc);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Styles.whiteColor,
          title: const Text("Edit RPC Endpoint", style: TextStyle(color: Styles.primaryColor)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Styles.textColor),
            decoration: const InputDecoration(
              hintText: "http://localhost:8545",
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Styles.purpleColor)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () {
                ref.read(settingsProvider.notifier).setRpcUrl(controller.text);
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }
}
