import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/routing/app_router.dart';
import '../../core/l10n/app_localizations.dart';

class AppHeader extends ConsumerWidget {
  final bool showSearchBar;
  final VoidCallback? onSearchTap;

  const AppHeader({
    super.key,
    this.showSearchBar = true,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo
          InkWell(
            onTap: () => context.go(AppRoutes.home),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'F',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'FlixGo',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 32),
          
          // Navigation Menu (Desktop)
          if (MediaQuery.of(context).size.width > 768) ...[
            _NavItem(
              label: l10n.home,
              onTap: () => context.go(AppRoutes.home),
              isActive: GoRouterState.of(context).uri.path == AppRoutes.home,
            ),
            const SizedBox(width: 24),
            _NavItem(
              label: l10n.movies,
              onTap: () => context.go('/category/movie'),
            ),
            const SizedBox(width: 24),
            _NavItem(
              label: l10n.series,
              onTap: () => context.go('/category/series'),
            ),
            const SizedBox(width: 24),
            _NavItem(
              label: 'Actors',
              onTap: () => context.go('/actors'),
            ),
          ],
          
          const Spacer(),
          
          // Search Bar (Desktop)
          if (showSearchBar && MediaQuery.of(context).size.width > 768) ...[
            SizedBox(
              width: 300,
              height: 40,
              child: TextFormField(
                decoration: InputDecoration(
                  hintText: 'Search movies, series, actors...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onTap: onSearchTap ?? () => context.push(AppRoutes.search),
                readOnly: onSearchTap != null,
              ),
            ),
            const SizedBox(width: 16),
          ],
          
          // Action Icons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Icon (Mobile)
              if (MediaQuery.of(context).size.width <= 768)
                IconButton(
                  onPressed: onSearchTap ?? () => context.push(AppRoutes.search),
                  icon: const Icon(Icons.search),
                ),
              
              // Theme Toggle
              IconButton(
                onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
                icon: Icon(
                  ref.watch(isDarkThemeProvider) 
                    ? Icons.light_mode 
                    : Icons.dark_mode,
                ),
              ),
              
              // Language Toggle
              IconButton(
                onPressed: () => ref.read(languageProvider.notifier).toggleLanguage(),
                icon: const Icon(Icons.language),
                tooltip: 'Language',
              ),
              
              // Notifications
              IconButton(
                onPressed: () {
                  // Show notifications
                },
                icon: const Icon(Icons.notifications_outlined),
              ),
              
              const SizedBox(width: 8),
              
              // User Profile
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'profile':
                      context.push(AppRoutes.profile);
                      break;
                    case 'favorites':
                      // Navigate to favorites
                      break;
                    case 'recent':
                      context.push(AppRoutes.recentViews);
                      break;
                    case 'settings':
                      // Navigate to settings
                      break;
                    case 'logout':
                      ref.read(authProvider.notifier).signOut();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(l10n.profile),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'favorites',
                    child: ListTile(
                      leading: const Icon(Icons.favorite),
                      title: Text(l10n.favorites),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'recent',
                    child: ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(l10n.recentViews),
                      dense: true,
                    ),
                  ),
                  
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: const Icon(Icons.settings),
                      title: Text(l10n.settings),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: const Icon(Icons.logout),
                      title: Text(l10n.signOut),
                      dense: true,
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: user?.avatar != null
                            ? ClipOval(
                                child: Image.network(
                                  user!.avatar!,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text(
                                      user.initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Text(
                                user?.initials ?? 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                      if (MediaQuery.of(context).size.width > 768) ...[
                        const SizedBox(width: 8),
                        Text(
                          user?.displayName ?? 'User',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _NavItem({
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}