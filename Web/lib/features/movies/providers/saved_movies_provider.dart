import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/saved_movie_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/saved_movie_service.dart';

class SavedMoviesState {
  final List<SavedMovie> items;
  final Set<int> movieIds;
  final Map<int, int> savedIdByMovieId;
  final Map<int, DateTime> createdAtByMovieId;

  const SavedMoviesState({
    required this.items,
    required this.movieIds,
    required this.savedIdByMovieId,
    required this.createdAtByMovieId,
  });

  factory SavedMoviesState.empty() => const SavedMoviesState(
        items: [],
        movieIds: <int>{},
        savedIdByMovieId: <int, int>{},
        createdAtByMovieId: <int, DateTime>{},
      );

  bool isSaved(int movieId) => movieIds.contains(movieId);
}

final savedMovieServiceProvider = Provider<SavedMovieService>((ref) {
  return SavedMovieService();
});

class SavedMoviesNotifier extends StateNotifier<AsyncValue<SavedMoviesState>> {
  SavedMoviesNotifier({
    required SavedMovieService service,
    required int? userId,
  })  : _service = service,
        _userId = userId,
        super(const AsyncValue.loading()) {
    _init();
  }

  final SavedMovieService _service;
  final int? _userId;

  Future<void> _init() async {
    if (_userId == null || _userId! <= 0) {
      state = AsyncValue.data(SavedMoviesState.empty());
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    final uid = _userId;
    if (uid == null || uid <= 0) {
      state = AsyncValue.data(SavedMoviesState.empty());
      return;
    }

    try {
      state = const AsyncValue.loading();
      final items = await _service.getSavedMoviesByUserId(uid);

      final ids = <int>{};
      final map = <int, int>{};
      final createdAt = <int, DateTime>{};

      for (final s in items) {
        if (s.movieId <= 0) continue;
        ids.add(s.movieId);
        if (s.savedMovieId > 0) map[s.movieId] = s.savedMovieId;
        if (s.createdAt != null) createdAt[s.movieId] = s.createdAt!;
      }

      state = AsyncValue.data(
        SavedMoviesState(
          items: items,
          movieIds: ids,
          savedIdByMovieId: map,
          createdAtByMovieId: createdAt,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(int movieId) async {
    final uid = _userId;
    if (uid == null || uid <= 0) throw Exception('HTTP_401');

    final prev = state;
    final current = state.value ?? SavedMoviesState.empty();
    if (current.movieIds.contains(movieId)) return;

    // optimistic
    state = AsyncValue.data(
      SavedMoviesState(
        items: current.items,
        movieIds: {...current.movieIds, movieId},
        savedIdByMovieId: current.savedIdByMovieId,
        createdAtByMovieId: current.createdAtByMovieId,
      ),
    );

    try {
      final created = await _service.createSavedMovie(userId: uid, movieId: movieId);
      if (created == null) {
        // already saved or response not provided
        await refresh();
        return;
      }

      final after = state.value ?? current;
      final newItems = [...after.items, created];
      final newMap = {...after.savedIdByMovieId, movieId: created.savedMovieId};
      final newCreatedAt = {...after.createdAtByMovieId};
      if (created.createdAt != null) newCreatedAt[movieId] = created.createdAt!;

      state = AsyncValue.data(
        SavedMoviesState(
          items: newItems,
          movieIds: {...after.movieIds, movieId},
          savedIdByMovieId: newMap,
          createdAtByMovieId: newCreatedAt,
        ),
      );
    } catch (_) {
      state = prev;
      rethrow;
    }
  }

  Future<void> remove(int movieId) async {
    final uid = _userId;
    if (uid == null || uid <= 0) throw Exception('HTTP_401');

    final prev = state;
    final current = state.value ?? SavedMoviesState.empty();

    // optimistic
    final newIds = {...current.movieIds}..remove(movieId);
    final newMap = {...current.savedIdByMovieId}..remove(movieId);
    final newCreatedAt = {...current.createdAtByMovieId}..remove(movieId);
    state = AsyncValue.data(
      SavedMoviesState(
        items: current.items.where((e) => e.movieId != movieId).toList(),
        movieIds: newIds,
        savedIdByMovieId: newMap,
        createdAtByMovieId: newCreatedAt,
      ),
    );

    try {
      var savedId = current.savedIdByMovieId[movieId];
      if (savedId == null || savedId <= 0) {
        await refresh();
        savedId = state.value?.savedIdByMovieId[movieId];
      }
      if (savedId == null || savedId <= 0) return;
      await _service.deleteSavedMovie(savedId);
    } catch (_) {
      state = prev;
      rethrow;
    }
  }
}

final savedMoviesProvider = StateNotifierProvider.autoDispose<SavedMoviesNotifier, AsyncValue<SavedMoviesState>>((ref) {
  final user = ref.watch(currentUserProvider);
  final userId = user?.userId;
  final service = ref.read(savedMovieServiceProvider);
  return SavedMoviesNotifier(service: service, userId: userId);
});

final isSavedMovieProvider = Provider.family<bool, int>((ref, movieId) {
  final state = ref.watch(savedMoviesProvider);
  return state.value?.isSaved(movieId) ?? false;
});
