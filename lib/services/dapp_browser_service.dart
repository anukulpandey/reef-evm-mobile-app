import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';

class DappBrowserService {
  const DappBrowserService();

  Future<List<String>> getApprovedOrigins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(StorageKeys.dappApprovedOrigins) ?? <String>[];
  }

  Future<bool> isOriginApproved(String origin) async {
    final normalized = _normalizeOrigin(origin);
    final origins = await getApprovedOrigins();
    return origins.map(_normalizeOrigin).contains(normalized);
  }

  Future<void> approveOrigin(String origin) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeOrigin(origin);
    final next = <String>{
      ...(prefs.getStringList(StorageKeys.dappApprovedOrigins) ?? <String>[]),
      normalized,
    }.toList()..sort();
    await prefs.setStringList(StorageKeys.dappApprovedOrigins, next);
  }

  Future<void> revokeOrigin(String origin) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeOrigin(origin);
    final next =
        (prefs.getStringList(StorageKeys.dappApprovedOrigins) ?? <String>[])
            .where((entry) => _normalizeOrigin(entry) != normalized)
            .toList();
    await prefs.setStringList(StorageKeys.dappApprovedOrigins, next);
  }

  Future<List<String>> getRecentUrls() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(StorageKeys.dappRecentUrls) ?? <String>[];
  }

  Future<void> addRecentUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing =
        prefs.getStringList(StorageKeys.dappRecentUrls) ?? <String>[];
    final next = <String>[
      trimmed,
      ...existing.where((entry) => entry != trimmed),
    ].take(8).toList();
    await prefs.setStringList(StorageKeys.dappRecentUrls, next);
  }

  String normalizeUserUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('localhost') || trimmed.startsWith('127.0.0.1')) {
      return 'http://$trimmed';
    }
    return 'https://$trimmed';
  }

  String normalizeOriginFromUrl(String url) {
    final uri = Uri.tryParse(normalizeUserUrl(url));
    return uri == null
        ? url.trim()
        : '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  String _normalizeOrigin(String origin) {
    final trimmed = origin.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) return trimmed;
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }
}
