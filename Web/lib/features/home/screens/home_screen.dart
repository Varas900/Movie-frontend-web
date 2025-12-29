import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:html' as html;

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/app_header.dart';
import '../widgets/hero_banner.dart';
import '../widgets/content_section.dart';
import '../widgets/featured_content.dart';
import '../widgets/trending_content.dart';
import '../widgets/recent_content.dart';
import '../widgets/genre_content.dart';
import '../widgets/continue_watching_content.dart';
import '../widgets/api_all_movies_content.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _didSync = false;

  @override
  void initState() {
    super.initState();
    _syncAuthFromCookiesIfNeeded();
  }

  Future<void> _syncAuthFromCookiesIfNeeded() async {
    if (_didSync) return;
    _didSync = true;
    // If already authenticated, skip
    final isAuth = ref.read(isAuthenticatedProvider);
    if (isAuth) return;
    try {
      final url = Uri.parse('${AppConstants.baseApiUrl}/user/me');
      final req = await html.HttpRequest.request(
        url.toString(),
        method: 'GET',
        withCredentials: true,
      );
      if (req.status == 200 && req.responseText != null) {
        final body = json.decode(req.responseText!);
        final data = (body is Map<String, dynamic>) ? (body['data'] ?? body['Data'] ?? body) : body;
        if (data is Map<String, dynamic>) {
          ref.read(authProvider.notifier).authenticateFromUserJson(data);
        }
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      body: Column(
        children: [
          // App Header
          const AppHeader(),
          
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Banner Section
                  const HeroBanner(),
                  
                  // Content Sections
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        
                        // Featured Content
                        ContentSection(
                          title: 'Featured Movies & Series',
                          subtitle: 'Hand-picked content just for you',
                          child: const FeaturedContent(),
                        ),
                        
                        const SizedBox(height: 32),

                        // All Movies from API
                        ContentSection(
                          title: 'All Movies',
                          subtitle: 'Fetched from the FilmZone API',
                          child: const ApiAllMoviesContent(),
                        ),
                        
                        // Trending Now
                        ContentSection(
                          title: 'Trending Now',
                          subtitle: 'What everyone is watching',
                          child: const TrendingContent(),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Recently Added
                        ContentSection(
                          title: 'Recently Added',
                          subtitle: 'New arrivals to our catalog',
                          child: const RecentContent(),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Genre-based sections
                        ContentSection(
                          title: 'Action & Adventure',
                          subtitle: 'Heart-pounding excitement',
                          child: const GenreContent(genre: 'Action'),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        ContentSection(
                          title: 'Comedy',
                          subtitle: 'Laugh out loud moments',
                          child: const GenreContent(genre: 'Comedy'),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        ContentSection(
                          title: 'Drama',
                          subtitle: 'Compelling stories',
                          child: const GenreContent(genre: 'Drama'),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Continue Watching (if user has recent views)
                        ContentSection(
                          title: 'Continue Watching',
                          subtitle: 'Pick up where you left off',
                          child: const ContinueWatchingContent(),
                        ),
                        
                        const SizedBox(height: 64), // Bottom padding
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      
      // Floating Action Button for Quick Access
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Show quick access menu
          _showQuickAccessMenu(context);
        },
        icon: const Icon(Icons.menu),
        label: const Text('Quick Menu'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  void _showQuickAccessMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QuickAccessMenu(),
    );
  }
}

// Quick Access Menu Widget
class QuickAccessMenu extends StatelessWidget {
  const QuickAccessMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Text(
              'Quick Access',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Quick Access Items
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _QuickAccessItem(
                  icon: Icons.search,
                  label: 'Search',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to search
                  },
                ),
                _QuickAccessItem(
                  icon: Icons.favorite,
                  label: 'Favorites',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to favorites
                  },
                ),
                _QuickAccessItem(
                  icon: Icons.download,
                  label: 'Downloads',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to downloads
                  },
                ),
                _QuickAccessItem(
                  icon: Icons.history,
                  label: 'History',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to history
                  },
                ),
                _QuickAccessItem(
                  icon: Icons.person,
                  label: 'Profile',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to profile
                  },
                ),
                _QuickAccessItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to settings
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAccessItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}