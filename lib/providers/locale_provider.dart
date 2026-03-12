import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleState {
  const LocaleState({required this.languageCode});

  final String languageCode;

  Locale get locale => Locale(languageCode);

  LocaleState copyWith({String? languageCode}) {
    return LocaleState(languageCode: languageCode ?? this.languageCode);
  }
}

class LocaleNotifier extends Notifier<LocaleState> {
  static const String _languageCodeKey = 'languageCode';

  @override
  LocaleState build() {
    Future.microtask(_loadLanguage);
    return const LocaleState(languageCode: 'en');
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_languageCodeKey) ?? 'en';
    state = state.copyWith(languageCode: code);
  }

  Future<void> setLanguageCode(String code) async {
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, normalized);
    state = state.copyWith(languageCode: normalized);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, LocaleState>(() {
  return LocaleNotifier();
});
