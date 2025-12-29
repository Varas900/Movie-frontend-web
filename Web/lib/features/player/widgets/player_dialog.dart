import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import '../../../core/utils/app_constants.dart';

class PlayerDialog extends StatefulWidget {
  final int movieId;
  const PlayerDialog({super.key, required this.movieId});

  @override
  State<PlayerDialog> createState() => _PlayerDialogState();
}

class _PlayableSource {
  final int? id;
  final String url;
  final String? quality;
  final bool isVip;
  const _PlayableSource({this.id, required this.url, this.quality, this.isVip = false});
}

class _PlayerDialogState extends State<PlayerDialog> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  List<_PlayableSource> _sources = [];
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _loadAndPlay();
    _animController.forward();
  }

  Future<void> _loadAndPlay() async {
    setState(() { _isLoading = true; _error = null; _sources = []; });
    try {
      final primary = await _fetchPublicSources(widget.movieId);
      if (primary.isNotEmpty) {
        _sources = primary;
        await _setup(primary.first);
        setState(() { _isLoading = false; });
        return;
      }
      final fallback = await _fetchWatchNow(widget.movieId);
      if (fallback.isNotEmpty) {
        _sources = fallback;
        await _setup(fallback.first);
        setState(() { _isLoading = false; });
        return;
      }
      setState(() { _error = 'No playable sources available.'; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load source: $e'; _isLoading = false; });
    }
  }

  Future<List<_PlayableSource>> _fetchPublicSources(int movieId) async {
    final url = Uri.parse('${AppConstants.baseApiUrl}/movie/MovieSource/GetMovieSourcesByMovieIdPublic/getByMovieId/$movieId');
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body);
    final data = body is Map ? (body['data'] ?? body['Data'] ?? body) : body;
    final list = <_PlayableSource>[];
    if (data is List) {
      for (final it in data) {
        if (it is Map) {
          final src = (it['sourceUrl'] ?? it['url'])?.toString();
          if (src != null && src.isNotEmpty) {
            final id = it['movieSourceID'] ?? it['sourceID'] ?? it['id'];
            final q = it['quality']?.toString();
            final vip = it['isVipOnly'] == true || it['isVip'] == true;
            list.add(_PlayableSource(id: id is int ? id : int.tryParse('$id'), url: src, quality: q, isVip: vip));
          }
        }
      }
    }
    return list;
  }

  Future<List<_PlayableSource>> _fetchWatchNow(int movieId) async {
    final url = Uri.parse('${AppConstants.baseApiUrl}/api/Movie/GetWatchNowMovieByID/watchNow/$movieId');
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body);
    final list = <_PlayableSource>[];
    if (body is Map) {
      final src = body['sourceUrl'] ?? body['url'] ?? body['movieUrl'];
      if (src is String && src.isNotEmpty) {
        final id = body['sourceID'] ?? body['id'];
        final q = body['quality']?.toString();
        list.add(_PlayableSource(id: id is int ? id : int.tryParse('$id'), url: src, quality: q));
      }
      final many = body['data'] ?? body['sources'];
      if (many is List) {
        for (final m in many) {
          if (m is Map) {
            final s = m['sourceUrl'] ?? m['url'];
            if (s is String && s.isNotEmpty) {
              final id = m['sourceID'] ?? m['id'];
              final q = m['quality']?.toString();
              list.add(_PlayableSource(id: id is int ? id : int.tryParse('$id'), url: s, quality: q));
            }
          }
        }
      }
    }
    return list;
  }

  Future<void> _setup(_PlayableSource s) async {
    try {
      _disposePlayer();
      final controller = VideoPlayerController.networkUrl(Uri.parse(s.url));
      await controller.initialize();
      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
      );
      setState(() {
        _videoController = controller;
        _chewieController = chewie;
      });
    } catch (e) {
      setState(() { _error = 'Playback failed: $e'; });
    }
  }

  void _disposePlayer() {
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
  }

  @override
  void dispose() {
    _disposePlayer();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Now Playing', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: _videoController?.value.aspectRatio ?? 16/9,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
                          : _chewieController == null
                              ? const SizedBox.shrink()
                              : Chewie(controller: _chewieController!),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
