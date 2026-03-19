import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _configPath = '.telegram-notify.json';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/telegram_notify.dart "<message>" [--silent]',
    );
    exitCode = 64;
    return;
  }

  final message = args.first.trim();
  if (message.isEmpty) {
    stderr.writeln('Message cannot be empty.');
    exitCode = 64;
    return;
  }

  final config = _loadConfig();
  final botToken = config['bot_token']?.toString().trim() ?? '';
  final chatId = config['chat_id']?.toString().trim() ?? '';

  if (botToken.isEmpty || chatId.isEmpty) {
    stderr.writeln(
      'Missing Telegram config. Expected bot_token and chat_id in $_configPath.',
    );
    exitCode = 64;
    return;
  }

  final response = await http
      .post(
        Uri.parse('https://api.telegram.org/bot$botToken/sendMessage'),
        headers: const <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'chat_id': chatId,
          'text': message,
          'disable_web_page_preview': true,
        }),
      )
      .timeout(const Duration(seconds: 15));

  if (response.statusCode < 200 || response.statusCode >= 300) {
    stderr.writeln(
      'Telegram request failed (${response.statusCode}): ${response.body}',
    );
    exitCode = 1;
    return;
  }

  final payload = jsonDecode(response.body);
  if (payload is! Map<String, dynamic> || payload['ok'] != true) {
    stderr.writeln('Telegram API error: ${response.body}');
    exitCode = 1;
    return;
  }

  stdout.writeln('Telegram notification sent.');
}

Map<String, dynamic> _loadConfig() {
  final file = File(_configPath);
  if (!file.existsSync()) {
    return const <String, dynamic>{};
  }

  final raw = file.readAsStringSync().trim();
  if (raw.isEmpty) {
    return const <String, dynamic>{};
  }

  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  return const <String, dynamic>{};
}
