import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/models/movie_model.dart';
import '../../../core/routing/app_router.dart';
import '../../../features/movies/providers/movie_provider.dart';
import '../providers/video_player_provider.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final int movieId;
  final bool isFullscreen;

  const VideoPlayerScreen({
    super.key,
    required this.movieId,
    this.isFullscreen = false,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _isFullscreen = false;
  bool _showControls = true;
  
  @override
  void initState() {
    super.initState();
    _isFullscreen = widget.isFullscreen;
    _initializePlayer();
    
    // Keep screen awake during video playback
    WakelockPlus.enable();
    
    // Set fullscreen if needed
    if (_isFullscreen) {
      _setFullscreen(true);
    }
  }

  @override
  void dispose() {
    _disposePlayer();
    WakelockPlus.disable();
    
    // Exit fullscreen
    _setFullscreen(false);
    
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      final movieAsync = await ref.read(movieDetailsProvider(widget.movieId).future);
      
      // For demo purposes, use a sample video URL
      // In a real app, this would come from the movie data
      const videoUrl = 'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4';
      
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showOptions: false,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Colors.grey.withOpacity(0.5),
          bufferedColor: Colors.white.withOpacity(0.5),
        ),
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error playing video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Listen for fullscreen changes
      _chewieController!.addListener(_chewieListener);

      setState(() {
        _isInitialized = true;
      });

      // Track watch progress
      _videoController!.addListener(() {
        if (_videoController!.value.isInitialized) {
          final progress = _videoController!.value.position.inMilliseconds /
              _videoController!.value.duration.inMilliseconds;
          ref.read(watchProgressProvider(widget.movieId).notifier).updateProgress(progress);
        }
      });

    } catch (e) {
      print('Error initializing video player: $e');
    }
  }

  void _chewieListener() {
    if (_chewieController?.isFullScreen != _isFullscreen) {
      setState(() {
        _isFullscreen = _chewieController?.isFullScreen ?? false;
      });
    }
  }

  void _disposePlayer() {
    _chewieController?.removeListener(_chewieListener);
    _chewieController?.dispose();
    _videoController?.dispose();
  }

  void _setFullscreen(bool fullscreen) {
    if (fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    _setFullscreen(_isFullscreen);
    _chewieController?.toggleFullScreen();
  }

  @override
  Widget build(BuildContext context) {
    final movieAsync = ref.watch(movieDetailsProvider(widget.movieId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: movieAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load movie',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        data: (movie) => _buildVideoPlayer(movie),
      ),
    );
  }

  Widget _buildVideoPlayer(Movie movie) {
    if (!_isInitialized || _chewieController == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading ${movie.title}...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isFullscreen) {
      return Chewie(controller: _chewieController!);
    }

    return Column(
      children: [
        // App Bar (only in portrait mode)
        if (!_isFullscreen)
          Container(
            height: kToolbarHeight + MediaQuery.of(context).padding.top,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: Text(
                    movie.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: _toggleFullscreen,
                  icon: const Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        
        // Video Player
        Expanded(
          child: Container(
            width: double.infinity,
            child: Chewie(controller: _chewieController!),
          ),
        ),
        
        // Movie Info (only in portrait mode)
        if (!_isFullscreen)
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (movie.year != null) ...[
                      Text(
                        movie.year.toString(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (movie.formattedDuration.isNotEmpty) ...[
                      Text(
                        movie.formattedDuration,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (movie.imdbRating != null) ...[
                      Icon(
                        Icons.star,
                        color: Theme.of(context).colorScheme.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        movie.imdbRating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                if (movie.plot?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    movie.plot!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref.read(favoritesProvider.notifier).toggleFavorite(movie.movieId);
                        },
                        icon: Icon(
                          ref.watch(isFavoriteProvider(movie.movieId))
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                        label: const Text('Favorite'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Share functionality
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}