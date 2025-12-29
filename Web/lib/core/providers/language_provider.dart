import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';

// Language State
class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier() : super(_getInitialLocale());

  static Locale _getInitialLocale() {
    final savedLanguage = StorageService.getLanguage();
    return Locale(savedLanguage);
  }

  void setLocale(Locale locale) {
    state = locale;
    StorageService.saveLanguage(locale.languageCode);
  }

  void toggleLanguage() {
    if (state.languageCode == 'en') {
      setLocale(const Locale('vi'));
    } else {
      setLocale(const Locale('en'));
    }
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, Locale>((ref) {
  return LanguageNotifier();
});

// Supported languages
final supportedLanguagesProvider = Provider<List<Locale>>((ref) {
  return const [
    Locale('en', 'US'),
    Locale('vi', 'VN'),
  ];
});

// Language display names
final languageDisplayNamesProvider = Provider<Map<String, String>>((ref) {
  return {
    'en': 'English',
    'vi': 'Tiếng Việt',
  };
});