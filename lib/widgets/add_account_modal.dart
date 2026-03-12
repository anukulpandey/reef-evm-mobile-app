import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/wallet_provider.dart';
import '../core/theme/app_colors.dart';

class AddAccountModal extends ConsumerWidget {
  const AddAccountModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            "Add Account",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          _buildOption(
            icon: Icons.add_circle_outline,
            title: "Create new",
            onTap: () async {
              Navigator.pop(context);
              await ref.read(walletProvider.notifier).createAccount();
            },
          ),
          _buildOption(
            icon: Icons.restore,
            title: "Import from recovery phrase",
            onTap: () {
              Navigator.pop(context);
              _showImportPhraseDialog(context, ref);
            },
          ),
          _buildOption(
            icon: Icons.file_upload_outlined,
            title: "Import from JSON file",
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not implemented yet')),
              );
            },
          ),
          _buildOption(
            icon: Icons.qr_code_scanner,
            title: "Import from QR code",
            onTap: () {
              Navigator.pop(context);
              // Navigate to QR scanner
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not implemented yet')),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.white54,
      ),
      onTap: onTap,
    );
  }

  void _showImportPhraseDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          title: const Text("Import from Phrase"),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Enter 12 or 24 word mnemonic phrase...",
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
              onPressed: () async {
                final phrase = controller.text.trim();
                Navigator.pop(context);
                if (phrase.isNotEmpty) {
                  await ref
                      .read(walletProvider.notifier)
                      .importMnemonic(phrase);
                }
              },
              child: const Text("Import"),
            ),
          ],
        );
      },
    );
  }
}
