import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';

// Theme State
enum AppThemeMode { light, dark, system }

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(_getInitialTheme());

  static ThemeMode _getInitialTheme() {
    final savedTheme = StorageService.getThemeMode();
    switch (savedTheme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setThemeMode(ThemeMode themeMode) {
    state = themeMode;
    _saveThemeMode(themeMode);
  }

  void toggleTheme() {
    switch (state) {
      case ThemeMode.light:
        setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setThemeMode(ThemeMode.system);
        break;
      case ThemeMode.system:
        setThemeMode(ThemeMode.light);
        break;
    }
  }

  void _saveThemeMode(ThemeMode themeMode) {
    String themeString;
    switch (themeMode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.system:
        themeString = 'system';
        break;
    }
    StorageService.saveThemeMode(themeString);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

// Current brightness provider (helpful for conditional theming)
final currentBrightnessProvider = Provider<Brightness>((ref) {
  final themeMode = ref.watch(themeProvider);
  final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  
  switch (themeMode) {
    case ThemeMode.light:
      return Brightness.light;
    case ThemeMode.dark:
      return Brightness.dark;
    case ThemeMode.system:
      return platformBrightness;
  }
});

// Helper provider to check if dark theme is active
final isDarkThemeProvider = Provider<bool>((ref) {
  return ref.watch(currentBrightnessProvider) == Brightness.dark;
});