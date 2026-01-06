import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import '../../../core/utils/app_constants.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/http_client_factory.dart';
import '../../../core/utils/authz_prompt.dart';
import 'youtube_embed_player.dart';

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
  const _PlayableSource(
      {this.id, required this.url, this.quality, this.isVip = false});
}

class _PlayerDialogState extends State<PlayerDialog>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  List<_PlayableSource> _sources = [];
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _useYoutubeEmbed = false;
  String? _youtubeUrl;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _loadAndPlay();
    _animController.forward();
  }

  String _friendlyAuthError(Object e) {
    final msg = e.toString();
    final prompt = authzPromptFromError(e);
    if (prompt == AuthzPromptType.signIn) return 'Please sign in to continue.';
    if (prompt == AuthzPromptType.buyPlan) return 'Please buy a plan to continue.';
    return 'Failed to load source: $e';
  }

  Future<void> _loadAndPlay() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _sources = [];
    });
    try {
      final primary = await _fetchPublicSources(widget.movieId);
      if (primary.isNotEmpty) {
        _sources = primary;
        await _setup(primary.first);
        setState(() {
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _error = 'No playable sources available.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = _friendlyAuthError(e);
        _isLoading = false;
      });
    }
  }

  Future<List<_PlayableSource>> _fetchPublicSources(int movieId) async {
    final url = Uri.parse(
        '${AppConstants.baseApiUrl}/movie/MovieSource/GetMovieSourcesByMovieIdPublic/getByMovieId/$movieId');
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    final token = StorageService.getUserToken();
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    final client = HttpClientFactory.create();
    late final http.Response res;
    try {
      res = await client.get(url, headers: headers);
    } finally {
      client.close();
    }

    if (res.statusCode == 401) {
      throw Exception('HTTP_401');
    }
    if (res.statusCode == 403) {
      throw Exception('HTTP_403');
    }
    if (res.statusCode != 200) {
      final bodyPreview =
          res.body.length > 500 ? res.body.substring(0, 500) : res.body;
      throw Exception('MovieSources HTTP ${res.statusCode}: $bodyPreview');
    }
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
            list.add(_PlayableSource(
                id: id is int ? id : int.tryParse('$id'),
                url: src,
                quality: q,
                isVip: vip));
          }
        }
      }
    }
    return list;
  }

  Future<void> _setup(_PlayableSource s) async {
    try {
      _disposePlayer();

      if (isYoutubeUrl(s.url)) {
        setState(() {
          _useYoutubeEmbed = true;
          _youtubeUrl = s.url;
          _error = null;
        });
        return;
      }

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
        _useYoutubeEmbed = false;
        _youtubeUrl = null;
      });
    } catch (e) {
      if (isYoutubeUrl(s.url)) {
        setState(() {
          _useYoutubeEmbed = true;
          _youtubeUrl = s.url;
          _error = null;
        });
        return;
      }
      setState(() {
        _error = 'Playback failed: $e';
      });
    }
  }

  void _disposePlayer() {
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
    _useYoutubeEmbed = false;
    _youtubeUrl = null;
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
                    const Text('Now Playing',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: _videoController?.value.aspectRatio ?? 16 / 9,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Text(_error!,
                                  style:
                                      const TextStyle(color: Colors.white70)))
                          : (_useYoutubeEmbed && _youtubeUrl != null)
                              ? YoutubeEmbedPlayer(url: _youtubeUrl!)
                              : (_chewieController == null
                                  ? const SizedBox.shrink()
                                  : Chewie(controller: _chewieController!)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
