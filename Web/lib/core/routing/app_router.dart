import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../../features/auth/screens/signin_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/mfa_verification_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/movies/screens/movie_details_screen.dart';
import '../../features/movies/screens/series_details_screen.dart';
import '../../features/movies/screens/moviebox_screen.dart';
import '../../features/actors/screens/actor_details_screen.dart';
import '../../features/categories/screens/category_screen.dart';
import '../../features/player/screens/player_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/recent_views_screen.dart';
import '../../features/profile/screens/reviews_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../shared/screens/splash_screen.dart';
import '../../shared/screens/not_found_screen.dart';

// Route Names
class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String signin = '/signin';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String mfaVerification = '/mfa-verification';
  static const String movieDetails = '/movie';
  static const String seriesDetails = '/series';
  static const String actorDetails = '/actor';
  static const String category = '/category';
  static const String player = '/player';
  static const String search = '/search';
  static const String profile = '/profile';
  static const String recentViews = '/recent-views';
  static const String reviews = '/reviews';
  static const String moviebox = '/moviebox';
  static const String aboutUs = '/about-us';
  static const String helpCenter = '/help-center';
  static const String contacts = '/contacts';
  static const String privacyPolicy = '/privacy-policy';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final location = state.uri.path;

      // Define public routes that don't require authentication
      const publicRoutes = [
        AppRoutes.splash,
        AppRoutes.signin,
        AppRoutes.signup,
        AppRoutes.forgotPassword,
        AppRoutes.mfaVerification,
        AppRoutes.search,
        AppRoutes.aboutUs,
        AppRoutes.helpCenter,
        AppRoutes.contacts,
        AppRoutes.privacyPolicy,
      ];

      // If user is not authenticated and trying to access protected route
      if (!isAuthenticated &&
          !publicRoutes.contains(location) &&
          !location.startsWith('/movie') &&
          !location.startsWith('/series')) {
        return AppRoutes.signin;
      }

      // If user is authenticated and trying to access auth routes
      if (isAuthenticated &&
          [AppRoutes.signin, AppRoutes.signup].contains(location)) {
        return AppRoutes.home;
      }

      return null; // No redirect needed
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Authentication Routes
      GoRoute(
        path: AppRoutes.signin,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.mfaVerification,
        builder: (context, state) {
          final userIdStr = state.uri.queryParameters['userID'] ?? '0';
          final userId = int.tryParse(userIdStr) ?? 0;
          return MfaVerificationScreen(userId: userId);
        },
      ),

      // Main App Routes
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),

      // Movie Details
      GoRoute(
        path: '${AppRoutes.movieDetails}/:id',
        builder: (context, state) {
          final movieId = int.parse(state.pathParameters['id']!);
          return MovieDetailsScreen(movieId: movieId);
        },
      ),

      // Series Details
      GoRoute(
        path: '${AppRoutes.seriesDetails}/:id',
        builder: (context, state) {
          final seriesId = int.parse(state.pathParameters['id']!);
          return SeriesDetailsScreen(seriesId: seriesId);
        },
      ),

      // Actor Details
      GoRoute(
        path: '${AppRoutes.actorDetails}/:id',
        builder: (context, state) {
          final actorId = int.parse(state.pathParameters['id']!);
          return ActorDetailsScreen(actorId: actorId);
        },
      ),

      // Category/Genre
      GoRoute(
        path: '${AppRoutes.category}/:genre',
        builder: (context, state) {
          final genre = state.pathParameters['genre']!;
          return CategoryScreen(genre: genre);
        },
      ),

      // Video Player
      GoRoute(
        path: '${AppRoutes.player}/:id',
        builder: (context, state) {
          final contentId = int.parse(state.pathParameters['id']!);
          final contentType = state.uri.queryParameters['type'] ?? 'movie';
          final episodeId = state.uri.queryParameters['episode'];

          return PlayerScreen(
            contentId: contentId,
            contentType: contentType,
            episodeId: episodeId != null ? int.parse(episodeId) : null,
          );
        },
      ),

      // Search
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) {
          final query = state.uri.queryParameters['q'];
          return SearchScreen(initialQuery: query);
        },
      ),

      // Profile Routes
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.moviebox,
        builder: (context, state) => const MovieBoxScreen(),
      ),
      GoRoute(
        path: AppRoutes.recentViews,
        builder: (context, state) => const RecentViewsScreen(),
      ),
      GoRoute(
        path: AppRoutes.reviews,
        builder: (context, state) => const ReviewsScreen(),
      ),

      // (Subscription & Payment routes removed)

      // Static Pages
      GoRoute(
        path: AppRoutes.aboutUs,
        builder: (context, state) => const StaticPageScreen(
          title: 'About Us',
          content: 'Welcome to FlixGo - Your premium streaming destination...',
        ),
      ),
      GoRoute(
        path: AppRoutes.helpCenter,
        builder: (context, state) => const StaticPageScreen(
          title: 'Help Center',
          content: 'Frequently Asked Questions and Support Information...',
        ),
      ),
      GoRoute(
        path: AppRoutes.contacts,
        builder: (context, state) => const StaticPageScreen(
          title: 'Contact Us',
          content: 'Get in touch with our support team...',
        ),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        builder: (context, state) => const StaticPageScreen(
          title: 'Privacy Policy',
          content: 'Your privacy is important to us...',
        ),
      ),
    ],
    errorBuilder: (context, state) => NotFoundScreen(
      path: state.uri.path,
    ),
  );
});

// Helper extension for navigation (renamed to avoid conflicts)
extension FlixGoNavigation on BuildContext {
  void pushNamed(String name,
      {Map<String, String>? pathParameters,
      Map<String, dynamic>? queryParameters}) {
    GoRouter.of(this).pushNamed(name,
        pathParameters: pathParameters ?? {},
        queryParameters: queryParameters ?? {});
  }

  void goNamed(String name,
      {Map<String, String>? pathParameters,
      Map<String, dynamic>? queryParameters}) {
    GoRouter.of(this).goNamed(name,
        pathParameters: pathParameters ?? {},
        queryParameters: queryParameters ?? {});
  }

  void goBack() {
    GoRouter.of(this).pop();
  }
}

// Static Page Widget for simple content pages
class StaticPageScreen extends StatelessWidget {
  final String title;
  final String content;

  const StaticPageScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          content,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
