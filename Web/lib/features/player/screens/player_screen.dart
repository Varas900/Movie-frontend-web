import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../core/utils/app_constants.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/http_client_factory.dart';
import '../../../core/utils/authz_prompt.dart';
import '../widgets/youtube_embed_player.dart';
// Chewie exports Subtitle/Subtitles via its main import

class _PlayableSource {
  final int? id;
  final String url;
  final String? quality;
  final String? type; // e.g. mp4, m3u8
  final bool isVip;
  final List<Map<String, String>> subtitles; // [{lang, url}]

  _PlayableSource({
    this.id,
    required this.url,
    this.quality,
    this.type,
    this.isVip = false,
    this.subtitles = const [],
  });
}

class PlayerScreen extends StatefulWidget {
  final int contentId;
  final String? contentType;
  final int? episodeId;

  const PlayerScreen({
    super.key,
    required this.contentId,
    this.contentType,
    this.episodeId,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isLoading = true;
  String? _error;
  List<_PlayableSource> _sources = [];
  int _currentIndex = 0;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _useYoutubeEmbed = false;
  String? _youtubeUrl;
  bool _subtitlesEnabled = false;
  String? _selectedSubtitleLang;
  String? _selectedSubtitleUrl;
  List<Subtitle> _subtitleCues = const [];
  bool _isFetchingSubs = false;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  String _friendlyAuthError(Object e) {
    final msg = e.toString();
    final prompt = authzPromptFromError(e);
    if (prompt == AuthzPromptType.signIn) return 'Please sign in to continue.';
    if (prompt == AuthzPromptType.buyPlan) return 'Please buy a plan to continue.';
    return 'Failed to load sources: $e';
  }

  Future<void> _loadSources() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _sources = [];
    });

    try {
      // If episode provided (series), try episode source first
      if ((widget.contentType ?? 'movie') == 'series' &&
          widget.episodeId != null) {
        final episodeSources = await _fetchEpisodeSources(widget.episodeId!);
        if (episodeSources.isNotEmpty) {
          setState(() {
            _sources = episodeSources;
            _isLoading = false;
          });
          await _setupPlayerForSource(episodeSources[0]);
          return;
        }
      }

      // Primary: public movie sources by movieId
      final movieSources = await _fetchMovieSources(widget.contentId);
      if (movieSources.isNotEmpty) {
        setState(() {
          _sources = movieSources;
          _isLoading = false;
        });
        await _setupPlayerForSource(movieSources[0]);
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

  Future<void> _setupPlayerForSource(_PlayableSource s) async {
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

      final uri = Uri.parse(s.url);
      final controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize();
      // Optionally load subtitles for current source if enabled
      await _maybeLoadSubtitlesForSource(s);
      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowMuting: true,
        allowFullScreen: true,
        subtitle:
            _subtitlesEnabled ? Subtitles(_subtitleCues) : const Subtitles([]),
        subtitleBuilder: (context, subtitle) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.black54,
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      );
      setState(() {
        _videoController = controller;
        _chewieController = chewie;
        _useYoutubeEmbed = false;
        _youtubeUrl = null;
        _error = null;
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

  Future<List<_PlayableSource>> _fetchMovieSources(int movieId) async {
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
          res.body.length > 400 ? res.body.substring(0, 400) : res.body;
      throw Exception('MovieSources HTTP ${res.statusCode}: $bodyPreview');
    }
    final body = jsonDecode(res.body);
    final List<_PlayableSource> out = [];
    final data = body is Map ? (body['data'] ?? body['Data'] ?? body) : body;
    if (data is List) {
      for (final s in data) {
        if (s is Map) {
          final sourceUrl = s['sourceUrl'] ?? s['url'];
          if (sourceUrl is String && sourceUrl.isNotEmpty) {
            final id = s['movieSourceID'] ?? s['sourceID'] ?? s['id'];
            final quality = s['quality']?.toString();
            final type = s['sourceType']?.toString() ?? s['type']?.toString();
            final isVip = s['isVipOnly'] == true || s['isVip'] == true;
            out.add(_PlayableSource(
              id: id is int ? id : int.tryParse('$id'),
              url: sourceUrl,
              quality: quality,
              type: type,
              isVip: isVip,
            ));
          }
        }
      }
    }
    return await _attachSubtitles(out, isEpisode: false);
  }

  Future<List<_PlayableSource>> _fetchEpisodeSources(int episodeId) async {
    final url = Uri.parse(
        '${AppConstants.baseApiUrl}/movie/EpisodeSource/GetEpisodeSourcesByEpisodeId/$episodeId');
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
      return [];
    }
    final body = jsonDecode(res.body);
    final data = body is Map ? (body['data'] ?? body['Data'] ?? body) : body;
    final List<_PlayableSource> out = [];
    if (data is List) {
      for (final s in data) {
        if (s is Map) {
          final sourceUrl = s['sourceUrl'] ?? s['url'];
          if (sourceUrl is String && sourceUrl.isNotEmpty) {
            final id = s['episodeSourceID'] ?? s['sourceID'] ?? s['id'];
            final quality = s['quality']?.toString();
            final type = s['sourceType']?.toString() ?? s['type']?.toString();
            out.add(_PlayableSource(
              id: id is int ? id : int.tryParse('$id'),
              url: sourceUrl,
              quality: quality,
              type: type,
              isVip: false,
            ));
          }
        }
      }
    }
    return await _attachSubtitles(out, isEpisode: true);
  }

  Future<List<_PlayableSource>> _attachSubtitles(
    List<_PlayableSource> sources, {
    required bool isEpisode,
  }) async {
    final List<_PlayableSource> result = [];
    for (final s in sources) {
      if (s.id == null) {
        result.add(s);
        continue;
      }
      try {
        final url = Uri.parse(isEpisode
            ? '${AppConstants.baseApiUrl}/api/MovieSubTitle/GetAllSubTitlesByEpisodeId/episode/GetAllSubTitlesBySourceID/${s.id}'
            : '${AppConstants.baseApiUrl}/api/MovieSubTitle/GetAllSubTitlesByMovieId/movie/GetAllSubTitlesBySourceID/${s.id}');
        final headers = <String, String>{
          'Accept': 'application/json',
        };
        final token = StorageService.getUserToken();
        if (token != null && token.trim().isNotEmpty) {
          headers['Authorization'] = 'Bearer ${token.trim()}';
        }

        final res = await http.get(url, headers: headers);
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          final subs = <Map<String, String>>[];
          // Unwrap ResponseDto<Data> if present, else accept raw array fallback
          List<dynamic> list = [];
          if (body is Map && (body['data'] is List || body['Data'] is List)) {
            list = (body['data'] as List?) ?? (body['Data'] as List?) ?? [];
          } else if (body is List) {
            list = body;
          }
          for (final sub in list) {
            if (sub is Map) {
              final lang = sub['language']?.toString() ??
                  sub['lang']?.toString() ??
                  'Subtitle';
              final subUrl = sub['linkSubTitle']?.toString() ??
                  sub['subtitleUrl']?.toString() ??
                  sub['url']?.toString();
              if (subUrl != null && subUrl.isNotEmpty) {
                subs.add({'lang': lang, 'url': subUrl});
              }
            }
          }
          result.add(_PlayableSource(
            id: s.id,
            url: s.url,
            quality: s.quality,
            type: s.type,
            isVip: s.isVip,
            subtitles: subs,
          ));
        } else {
          result.add(s);
        }
      } catch (_) {
        result.add(s);
      }
    }
    return result;
  }

  Future<void> _maybeLoadSubtitlesForSource(_PlayableSource s) async {
    if (!_subtitlesEnabled) {
      _subtitleCues = const [];
      return;
    }
    // Pick selected language or default to first available
    final subs = s.subtitles;
    if (subs.isEmpty) {
      _subtitleCues = const [];
      return;
    }
    Map<String, String>? chosen;
    if (_selectedSubtitleUrl != null) {
      chosen = subs.firstWhere(
        (e) => e['url'] == _selectedSubtitleUrl,
        orElse: () => subs.first,
      );
    } else if (_selectedSubtitleLang != null) {
      chosen = subs.firstWhere(
        (e) =>
            (e['lang'] ?? '').toLowerCase() ==
            _selectedSubtitleLang!.toLowerCase(),
        orElse: () => subs.first,
      );
    } else {
      chosen = subs.first;
    }

    final url = chosen['url'];
    if (url == null || url.isEmpty) {
      _subtitleCues = const [];
      return;
    }
    _selectedSubtitleLang = chosen['lang'];
    _selectedSubtitleUrl = url;
    _isFetchingSubs = true;
    try {
      final subtitleUri = Uri.parse(url);
      final token = StorageService.getUserToken();
      final needsAuth = token != null &&
          token.trim().isNotEmpty &&
          url.startsWith(AppConstants.baseApiUrl);
      final res = await http.get(
        subtitleUri,
        headers:
            needsAuth ? {'Authorization': 'Bearer ${token!.trim()}'} : null,
      );
      if (res.statusCode == 200) {
        final text = res.body;
        _subtitleCues = _parseSrtOrVttToChewie(text);
      } else {
        _subtitleCues = const [];
      }
    } catch (_) {
      _subtitleCues = const [];
    } finally {
      _isFetchingSubs = false;
    }
  }

  List<Subtitle> _parseSrtOrVttToChewie(String content) {
    final lines = content.replaceAll('\r', '').split('\n');
    final cues = <Subtitle>[];
    int i = 0;
    while (i < lines.length) {
      // Skip sequence number if present
      if (RegExp(r'^\d+$').hasMatch(lines[i].trim())) {
        i++;
      }
      if (i >= lines.length) break;
      final timeLine = lines[i].trim();
      final timeMatch = RegExp(
              r'(?<start>\d{2}:\d{2}:\d{2}[\.,]\d{3})\s*-->\s*(?<end>\d{2}:\d{2}:\d{2}[\.,]\d{3})')
          .firstMatch(timeLine);
      if (timeMatch == null) {
        i++;
        continue;
      }
      final startStr = timeMatch.namedGroup('start')!;
      final endStr = timeMatch.namedGroup('end')!;
      i++;
      final textLines = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        textLines.add(lines[i]);
        i++;
      }
      // Skip blank line
      while (i < lines.length && lines[i].trim().isEmpty) {
        i++;
      }
      final start = _parseTimestamp(startStr);
      final end = _parseTimestamp(endStr);
      if (start != null && end != null) {
        cues.add(Subtitle(
            index: cues.length,
            start: start,
            end: end,
            text: textLines.join('\n')));
      }
    }
    return cues;
  }

  Duration? _parseTimestamp(String s) {
    final normalized = s.replaceAll(',', '.');
    final parts = normalized.split('.');
    final main = parts[0];
    final msStr = parts.length > 1 ? parts[1] : '000';
    final hms = main.split(':');
    if (hms.length != 3) return null;
    final h = int.tryParse(hms[0]) ?? 0;
    final m = int.tryParse(hms[1]) ?? 0;
    final sec = int.tryParse(hms[2]) ?? 0;
    final ms = int.tryParse(msStr.padRight(3, '0').substring(0, 3)) ?? 0;
    return Duration(hours: h, minutes: m, seconds: sec, milliseconds: ms);
  }

  Future<void> _toggleSubtitles() async {
    setState(() {
      _subtitlesEnabled = !_subtitlesEnabled;
    });
    await _reloadChewieForCurrentSource();
  }

  Future<void> _reloadChewieForCurrentSource() async {
    if (_videoController == null) return;
    final current = (_sources.isNotEmpty && _currentIndex < _sources.length)
        ? _sources[_currentIndex]
        : null;
    if (current == null) return;
    await _maybeLoadSubtitlesForSource(current);
    _chewieController?.dispose();
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      allowMuting: true,
      allowFullScreen: true,
      subtitle:
          _subtitlesEnabled ? Subtitles(_subtitleCues) : const Subtitles([]),
      subtitleBuilder: (context, subtitle) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.black54,
        child: Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _showSubtitleLanguagePicker(_PlayableSource s) async {
    if (s.subtitles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No subtitles available')));
      return;
    }
    final choice = await showModalBottomSheet<Map<String, String>>(
      context: context,
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Select Subtitle Language')),
            ...s.subtitles.map((sub) => ListTile(
                  title: Text(sub['lang'] ?? 'Subtitle'),
                  subtitle: Text(sub['url'] ?? ''),
                  onTap: () => Navigator.of(ctx).pop(sub),
                )),
          ],
        );
      },
    );
    if (choice != null) {
      setState(() {
        _selectedSubtitleLang = choice['lang'];
        _selectedSubtitleUrl = choice['url'];
      });
      if (_subtitlesEnabled) {
        await _reloadChewieForCurrentSource();
      }
    }
  }

  Future<void> _openSource(_PlayableSource s) async {
    final uri = Uri.parse(s.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open source URL')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch Now'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _sources.isEmpty
                    ? const Center(child: Text('No sources available'))
                    : ListView.separated(
                        itemCount:
                            _sources.length > 1 ? _sources.length + 1 : 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Card(
                              child: AspectRatio(
                                aspectRatio:
                                    _videoController?.value.aspectRatio ??
                                        16 / 9,
                                child: Stack(
                                  children: [
                                    if (_useYoutubeEmbed && _youtubeUrl != null)
                                      YoutubeEmbedPlayer(url: _youtubeUrl!)
                                    if (_useYoutubeEmbed && _youtubeUrl != null)
                                      Positioned.fill(
                                        child: YoutubeEmbedPlayer(
                                            url: _youtubeUrl!),
                                      )
                                          ? const Center(
                                              child: Text(
                                                  'Select a source to play'))
                                          : Chewie(
                                              controller: _chewieController!)),
                                    if (!(_useYoutubeEmbed &&
                                        _youtubeUrl != null))
                                      Positioned(
                                        right: 12,
                                        top: 12,
                                        child: Row(
                                          children: [
                                            // Subtitles toggle button
                                            IconButton(
                                              tooltip: _subtitlesEnabled
                                                  ? 'Subtitles: On (tap to turn off)'
                                                  : 'Subtitles: Off (tap to turn on)',
                                              icon: Icon(
                                                _subtitlesEnabled
                                                    ? Icons.closed_caption
                                                    : Icons
                                                        .closed_caption_disabled,
                                                color: Colors.white,
                                              ),
                                              onPressed: () =>
                                                  _toggleSubtitles(),
                                            ),
                                            // Language selection (dropdown via bottom sheet)
                                            IconButton(
                                              tooltip: 'Subtitle Language',
                                              icon: const Icon(Icons.settings,
                                                  color: Colors.white),
                                              onPressed: () {
                                                final s = (_sources
                                                            .isNotEmpty &&
                                                        _currentIndex <
                                                            _sources.length)
                                                    ? _sources[_currentIndex]
                                                    : null;
                                                if (s != null) {
                                                  _showSubtitleLanguagePicker(
                                                      s);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }
                          // Only render source cards if there are multiple sources
                          if (_sources.length <= 1) {
                            return const SizedBox.shrink();
                          }
                          final s = _sources[index - 1];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Source ${s.id ?? index} • ${s.quality ?? 'Auto'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      if (s.isVip)
                                        const Chip(label: Text('VIP')),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final idx = index - 1;
                                          setState(() {
                                            _currentIndex = idx;
                                          });
                                          await _setupPlayerForSource(s);
                                        },
                                        icon: const Icon(Icons.play_arrow),
                                        label: const Text('Play this source'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Clipboard.setData(
                                              ClipboardData(text: s.url));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text('Source URL copied')),
                                          );
                                        },
                                        icon: const Icon(Icons.link),
                                        label: const Text('Copy URL'),
                                      ),
                                    ],
                                  ),
                                  if (s.subtitles.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text('Subtitles',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: s.subtitles.map((sub) {
                                        return OutlinedButton(
                                          onPressed: () => _openSource(
                                              _PlayableSource(
                                                  url: sub['url']!,
                                                  quality: sub['lang'])),
                                          child:
                                              Text(sub['lang'] ?? 'Subtitle'),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }
}
