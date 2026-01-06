import 'package:flutter/widgets.dart';

import 'youtube_embed_player_impl.dart'
    if (dart.library.html) 'youtube_embed_player_web.dart' as impl;

bool isYoutubeUrl(String url) {
  final u = url.toLowerCase();
  return u.contains('youtube.com') || u.contains('youtu.be');
}

String? extractYoutubeVideoId(String url) {
  Uri? uri;
  try {
    uri = Uri.parse(url);
  } catch (_) {
    return null;
  }

  final host = uri.host.toLowerCase();

  // https://youtu.be/VIDEO_ID
  if (host == 'youtu.be') {
    final seg = uri.pathSegments;
    if (seg.isNotEmpty && seg.first.trim().isNotEmpty) return seg.first.trim();
  }

  // https://www.youtube.com/watch?v=VIDEO_ID
  if (host.contains('youtube.com')) {
    final v = uri.queryParameters['v'];
    if (v != null && v.trim().isNotEmpty) return v.trim();

    // https://www.youtube.com/embed/VIDEO_ID
    final seg = uri.pathSegments;
    final embedIndex = seg.indexOf('embed');
    if (embedIndex >= 0 && seg.length > embedIndex + 1) {
      final id = seg[embedIndex + 1].trim();
      if (id.isNotEmpty) return id;
    }

    // https://www.youtube.com/shorts/VIDEO_ID
    final shortsIndex = seg.indexOf('shorts');
    if (shortsIndex >= 0 && seg.length > shortsIndex + 1) {
      final id = seg[shortsIndex + 1].trim();
      if (id.isNotEmpty) return id;
    }
  }

  return null;
}

String? toYoutubeEmbedUrl(String url) {
  final id = extractYoutubeVideoId(url);
  if (id == null) return null;
  return 'https://www.youtube.com/embed/$id';
}

class YoutubeEmbedPlayer extends StatelessWidget {
  final String url;
  final bool autoplay;
  final bool allowFullScreen;

  const YoutubeEmbedPlayer({
    super.key,
    required this.url,
    this.autoplay = true,
    this.allowFullScreen = true,
  });

  @override
  Widget build(BuildContext context) {
    return impl.YoutubeEmbedPlayerImpl(
      url: url,
      autoplay: autoplay,
      allowFullScreen: allowFullScreen,
    );
  }
}
