import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../widgets/gradient_header.dart';
import '../core/theme/app_colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: Text(
              'Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionTitle("Security"),
                SwitchListTile(
                  title: const Text("Biometric Authentication"),
                  subtitle: const Text("Require FaceID/TouchID to open"),
                  activeColor: AppColors.accent,
                  value: settings.useBiometrics,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).setBiometrics(val);
                  },
                ),
                ListTile(
                  title: const Text("Change Password"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),

                const Divider(height: 40, color: Colors.white24),

                _buildSectionTitle("General"),
                ListTile(
                  title: const Text("WalletConnect"),
                  subtitle: const Text("Manage connected dApps"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),
                ListTile(
                  title: const Text("Select Language"),
                  trailing: const Text(
                    "English >",
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {},
                ),

                const Divider(height: 40, color: Colors.white24),

                _buildSectionTitle("Developer Settings"),
                ListTile(
                  title: const Text("RPC Endpoint"),
                  subtitle: Text(settings.rpcUrl),
                  trailing: const Icon(Icons.edit, size: 16),
                  onTap: () {
                    _showRpcEditDialog(context, ref, settings.rpcUrl);
                  },
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
      padding: const EdgeInsets.only(bottom: 10, top: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showRpcEditDialog(
    BuildContext context,
    WidgetRef ref,
    String currentRpc,
  ) {
    final controller = TextEditingController(text: currentRpc);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          title: const Text("Edit RPC Endpoint"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "http://localhost:8545",
              filled: true,
              fillColor: Colors.black26,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
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
