import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/movie_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';

// Movie Details Provider
final movieDetailsProvider = FutureProvider.family<Movie, int>((ref, movieId) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getMovieDetails(movieId);
});

// Movies by Category Provider
final moviesByCategoryProvider = FutureProvider.family<List<Movie>, String>((ref, category) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getMoviesByCategory(category);
});

// Search Movies Provider
final searchMoviesProvider = FutureProvider.family<List<Movie>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final apiService = ref.read(apiServiceProvider);
  return apiService.searchMovies(query);
});

// Popular Movies Provider
final popularMoviesProvider = FutureProvider<List<Movie>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getPopularMovies();
});

// Featured Movies Provider
final featuredMoviesProvider = FutureProvider<List<Movie>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getFeaturedMovies();
});

// Recently Added Movies Provider
final recentMoviesProvider = FutureProvider<List<Movie>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getRecentMovies();
});

// Trending Movies Provider
final trendingMoviesProvider = FutureProvider<List<Movie>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getTrendingMovies();
});

// Related Movies Provider
final relatedMoviesProvider = FutureProvider.family<List<Movie>, int>((ref, movieId) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getRelatedMovies(movieId);
});

// Favorites Provider
class FavoritesNotifier extends StateNotifier<Set<int>> {
  FavoritesNotifier(this._storageService) : super({}) {
    _loadFavorites();
  }

  final StorageService _storageService;

  Future<void> _loadFavorites() async {
    final favorites = await _storageService.getFavorites();
    state = favorites.toSet();
  }

  Future<void> toggleFavorite(int movieId) async {
    final newState = Set<int>.from(state);
    if (newState.contains(movieId)) {
      newState.remove(movieId);
    } else {
      newState.add(movieId);
    }
    state = newState;
    await _storageService.saveFavorites(newState.toList());
  }

  Future<void> addToFavorites(int movieId) async {
    if (!state.contains(movieId)) {
      final newState = Set<int>.from(state)..add(movieId);
      state = newState;
      await _storageService.saveFavorites(newState.toList());
    }
  }

  Future<void> removeFromFavorites(int movieId) async {
    if (state.contains(movieId)) {
      final newState = Set<int>.from(state)..remove(movieId);
      state = newState;
      await _storageService.saveFavorites(newState.toList());
    }
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<int>>((ref) {
  final storageService = ref.read(storageServiceProvider);
  return FavoritesNotifier(storageService);
});

// Is Favorite Provider
final isFavoriteProvider = Provider.family<bool, int>((ref, movieId) {
  final favorites = ref.watch(favoritesProvider);
  return favorites.contains(movieId);
});

// Recent Views Provider
class RecentViewsNotifier extends StateNotifier<List<int>> {
  RecentViewsNotifier(this._storageService) : super([]) {
    _loadRecentViews();
  }

  final StorageService _storageService;

  Future<void> _loadRecentViews() async {
    final recentViews = await _storageService.getRecentViews();
    state = recentViews;
  }

  Future<void> addRecentView(int movieId) async {
    final newState = List<int>.from(state);
    
    // Remove if already exists
    newState.remove(movieId);
    
    // Add to beginning
    newState.insert(0, movieId);
    
    // Keep only last 20 items
    if (newState.length > 20) {
      newState.removeRange(20, newState.length);
    }
    
    state = newState;
    await _storageService.saveRecentViews(newState);
  }

  Future<void> clearRecentViews() async {
    state = [];
    await _storageService.saveRecentViews([]);
  }
}

final recentViewsProvider = StateNotifierProvider<RecentViewsNotifier, List<int>>((ref) {
  final storageService = ref.read(storageServiceProvider);
  return RecentViewsNotifier(storageService);
});

// Recent Views Movies Provider
final recentViewsMoviesProvider = FutureProvider<List<Movie>>((ref) async {
  final recentViewIds = ref.watch(recentViewsProvider);
  if (recentViewIds.isEmpty) return [];
  
  final apiService = ref.read(apiServiceProvider);
  return apiService.getMoviesByIds(recentViewIds);
});

// Movie Categories Provider
final movieCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getMovieCategories();
});

// Current Category Provider
final currentCategoryProvider = StateProvider<String>((ref) => 'all');

// Movies by Current Category Provider
final moviesByCurrentCategoryProvider = FutureProvider<List<Movie>>((ref) async {
  final category = ref.watch(currentCategoryProvider);
  final apiService = ref.read(apiServiceProvider);
  return apiService.getMoviesByCategory(category);
});

// Filter Options Provider
class FilterOptions {
  final String genre;
  final String year;
  final String rating;
  final String sortBy;

  const FilterOptions({
    this.genre = '',
    this.year = '',
    this.rating = '',
    this.sortBy = 'popularity',
  });

  FilterOptions copyWith({
    String? genre,
    String? year,
    String? rating,
    String? sortBy,
  }) {
    return FilterOptions(
      genre: genre ?? this.genre,
      year: year ?? this.year,
      rating: rating ?? this.rating,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterOptions &&
          genre == other.genre &&
          year == other.year &&
          rating == other.rating &&
          sortBy == other.sortBy;

  @override
  int get hashCode => genre.hashCode ^ year.hashCode ^ rating.hashCode ^ sortBy.hashCode;
}

final filterOptionsProvider = StateProvider<FilterOptions>((ref) => const FilterOptions());

// Filtered Movies Provider
final filteredMoviesProvider = FutureProvider<List<Movie>>((ref) async {
  final filters = ref.watch(filterOptionsProvider);
  final apiService = ref.read(apiServiceProvider);
  return apiService.getFilteredMovies(
    genre: filters.genre,
    year: filters.year,
    rating: filters.rating,
    sortBy: filters.sortBy,
  );
});

// Watchlist Provider
class WatchlistNotifier extends StateNotifier<Set<int>> {
  WatchlistNotifier(this._storageService) : super({}) {
    _loadWatchlist();
  }

  final StorageService _storageService;

  Future<void> _loadWatchlist() async {
    final watchlist = await _storageService.getWatchlist();
    state = watchlist.toSet();
  }

  Future<void> toggleWatchlist(int movieId) async {
    final newState = Set<int>.from(state);
    if (newState.contains(movieId)) {
      newState.remove(movieId);
    } else {
      newState.add(movieId);
    }
    state = newState;
    await _storageService.saveWatchlist(newState.toList());
  }

  Future<void> addToWatchlist(int movieId) async {
    if (!state.contains(movieId)) {
      final newState = Set<int>.from(state)..add(movieId);
      state = newState;
      await _storageService.saveWatchlist(newState.toList());
    }
  }

  Future<void> removeFromWatchlist(int movieId) async {
    if (state.contains(movieId)) {
      final newState = Set<int>.from(state)..remove(movieId);
      state = newState;
      await _storageService.saveWatchlist(newState.toList());
    }
  }
}

final watchlistProvider = StateNotifierProvider<WatchlistNotifier, Set<int>>((ref) {
  final storageService = ref.read(storageServiceProvider);
  return WatchlistNotifier(storageService);
});

// Is in Watchlist Provider
final isInWatchlistProvider = Provider.family<bool, int>((ref, movieId) {
  final watchlist = ref.watch(watchlistProvider);
  return watchlist.contains(movieId);
});

// Watchlist Movies Provider
final watchlistMoviesProvider = FutureProvider<List<Movie>>((ref) async {
  final watchlistIds = ref.watch(watchlistProvider);
  if (watchlistIds.isEmpty) return [];
  
  final apiService = ref.read(apiServiceProvider);
  return apiService.getMoviesByIds(watchlistIds.toList());
});