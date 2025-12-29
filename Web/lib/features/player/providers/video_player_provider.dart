import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage_service.dart';

// Watch Progress Provider
class WatchProgressNotifier extends StateNotifier<double> {
  WatchProgressNotifier(this._movieId) : super(0.0) {
    _loadProgress();
  }

  final int _movieId;

  Future<void> _loadProgress() async {
    final progress = StorageService.getWatchProgress(_movieId);
    state = progress;
  }

  Future<void> updateProgress(double progress) async {
    state = progress;
    await StorageService.saveWatchProgress(_movieId, progress);
    
    // Mark as watched if progress > 90%
    if (progress > 0.9) {
      await StorageService.markAsWatched(_movieId);
    }
  }

  Future<void> markCompleted() async {
    state = 1.0;
    await StorageService.saveWatchProgress(_movieId, 1.0);
    await StorageService.markAsWatched(_movieId);
  }

  Future<void> resetProgress() async {
    state = 0.0;
    await StorageService.saveWatchProgress(_movieId, 0.0);
  }
}

final watchProgressProvider = StateNotifierProvider.family<WatchProgressNotifier, double, int>((ref, movieId) {
  return WatchProgressNotifier(movieId);
});

// Video Quality Provider
final videoQualityProvider = StateProvider<String>((ref) {
  return StorageService.getVideoQuality();
});

// Auto Play Provider
final autoPlayProvider = StateProvider<bool>((ref) {
  return StorageService.getAutoPlay();
});

// Subtitles Enabled Provider
final subtitlesEnabledProvider = StateProvider<bool>((ref) {
  return StorageService.getSubtitlesEnabled();
});

// Video Player Settings Provider
class VideoPlayerSettings {
  final String quality;
  final bool autoPlay;
  final bool subtitlesEnabled;
  final double playbackSpeed;
  final bool showControls;

  const VideoPlayerSettings({
    this.quality = 'auto',
    this.autoPlay = true,
    this.subtitlesEnabled = true,
    this.playbackSpeed = 1.0,
    this.showControls = true,
  });

  VideoPlayerSettings copyWith({
    String? quality,
    bool? autoPlay,
    bool? subtitlesEnabled,
    double? playbackSpeed,
    bool? showControls,
  }) {
    return VideoPlayerSettings(
      quality: quality ?? this.quality,
      autoPlay: autoPlay ?? this.autoPlay,
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      showControls: showControls ?? this.showControls,
    );
  }
}

class VideoPlayerSettingsNotifier extends StateNotifier<VideoPlayerSettings> {
  VideoPlayerSettingsNotifier() : super(const VideoPlayerSettings()) {
    _loadSettings();
  }

  void _loadSettings() {
    state = VideoPlayerSettings(
      quality: StorageService.getVideoQuality(),
      autoPlay: StorageService.getAutoPlay(),
      subtitlesEnabled: StorageService.getSubtitlesEnabled(),
    );
  }

  Future<void> updateQuality(String quality) async {
    state = state.copyWith(quality: quality);
    await StorageService.saveVideoQuality(quality);
  }

  Future<void> updateAutoPlay(bool autoPlay) async {
    state = state.copyWith(autoPlay: autoPlay);
    await StorageService.saveAutoPlay(autoPlay);
  }

  Future<void> updateSubtitlesEnabled(bool enabled) async {
    state = state.copyWith(subtitlesEnabled: enabled);
    await StorageService.saveSubtitlesEnabled(enabled);
  }

  void updatePlaybackSpeed(double speed) {
    state = state.copyWith(playbackSpeed: speed);
  }

  void updateShowControls(bool showControls) {
    state = state.copyWith(showControls: showControls);
  }
}

final videoPlayerSettingsProvider = StateNotifierProvider<VideoPlayerSettingsNotifier, VideoPlayerSettings>((ref) {
  return VideoPlayerSettingsNotifier();
});

// Currently Playing Provider
class CurrentlyPlaying {
  final int? movieId;
  final String? title;
  final String? thumbnailUrl;
  final double progress;
  final Duration position;
  final Duration duration;
  final bool isPlaying;

  const CurrentlyPlaying({
    this.movieId,
    this.title,
    this.thumbnailUrl,
    this.progress = 0.0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
  });

  CurrentlyPlaying copyWith({
    int? movieId,
    String? title,
    String? thumbnailUrl,
    double? progress,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
  }) {
    return CurrentlyPlaying(
      movieId: movieId ?? this.movieId,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      progress: progress ?? this.progress,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

class CurrentlyPlayingNotifier extends StateNotifier<CurrentlyPlaying> {
  CurrentlyPlayingNotifier() : super(const CurrentlyPlaying());

  void startPlaying({
    required int movieId,
    required String title,
    String? thumbnailUrl,
  }) {
    state = CurrentlyPlaying(
      movieId: movieId,
      title: title,
      thumbnailUrl: thumbnailUrl,
      isPlaying: true,
    );
  }

  void updateProgress({
    double? progress,
    Duration? position,
    Duration? duration,
  }) {
    state = state.copyWith(
      progress: progress,
      position: position,
      duration: duration,
    );
  }

  void updatePlayingState(bool isPlaying) {
    state = state.copyWith(isPlaying: isPlaying);
  }

  void stopPlaying() {
    state = const CurrentlyPlaying();
  }
}

final currentlyPlayingProvider = StateNotifierProvider<CurrentlyPlayingNotifier, CurrentlyPlaying>((ref) {
  return CurrentlyPlayingNotifier();
});

// Continue Watching Provider (Movies with progress > 0 and < 0.9)
final continueWatchingProvider = FutureProvider<List<ContinueWatchingItem>>((ref) async {
  // This would typically fetch from API or storage
  // For demo purposes, return empty list
  await Future.delayed(const Duration(milliseconds: 500));
  return <ContinueWatchingItem>[];
});

class ContinueWatchingItem {
  final int movieId;
  final String title;
  final String thumbnailUrl;
  final double progress;
  final DateTime lastWatched;

  const ContinueWatchingItem({
    required this.movieId,
    required this.title,
    required this.thumbnailUrl,
    required this.progress,
    required this.lastWatched,
  });
}

// Picture in Picture Provider (for web/mobile platforms that support it)
final pictureInPictureProvider = StateProvider<bool>((ref) => false);

// Fullscreen Provider
final fullscreenProvider = StateProvider<bool>((ref) => false);

// Video Player Error Provider
final videoPlayerErrorProvider = StateProvider<String?>((ref) => null);

// Buffering Provider
final bufferingProvider = StateProvider<bool>((ref) => false);