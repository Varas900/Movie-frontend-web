import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/providers/auth_provider.dart';
import '../core/providers/theme_provider.dart';
import '../core/providers/language_provider.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/app_constants.dart';
import '../core/l10n/app_localizations.dart';

class FlixGoApp extends ConsumerWidget {
  const FlixGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(languageProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      
      // Theme Configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      
      // Localization
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      
      // Routing
      routerConfig: router,
      
      // Global Text Theme
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
    );
  }
}