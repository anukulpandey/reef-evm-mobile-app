import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../providers/wallet_provider.dart';
import '../core/theme/styles.dart';

class AddAccountModal extends ConsumerWidget {
  const AddAccountModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Styles.primaryBackgroundColor,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
          ),
          const Gap(30),
          const Text("Add Account", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Styles.primaryColor)),
          const Gap(30),
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
            title: "Import recovery phrase",
            onTap: () {
              Navigator.pop(context);
              _showImportPhraseDialog(context, ref);
            },
          ),
          const Gap(40),
        ],
      ),
    );
  }

  Widget _buildOption({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Styles.purpleColor),
      title: Text(title, style: const TextStyle(fontSize: 16, color: Styles.textColor, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black26),
      onTap: onTap,
    );
  }

  void _showImportPhraseDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Styles.whiteColor,
          title: const Text("Import from Phrase", style: TextStyle(color: Styles.primaryColor)),
          content: TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(color: Styles.textColor),
            decoration: const InputDecoration(
              hintText: "Enter mnemonic phrase...",
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Styles.purpleColor)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () async {
                final phrase = controller.text.trim();
                Navigator.pop(context);
                if (phrase.isNotEmpty) {
                  await ref.read(walletProvider.notifier).importMnemonic(phrase);
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
