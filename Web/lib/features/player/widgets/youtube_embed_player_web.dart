// Web-only YouTube embed using an <iframe>.

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'youtube_embed_player.dart';

class YoutubeEmbedPlayerImpl extends StatefulWidget {
  final String url;
  final bool autoplay;
  final bool allowFullScreen;

  const YoutubeEmbedPlayerImpl({
    super.key,
    required this.url,
    required this.autoplay,
    required this.allowFullScreen,
  });

  @override
  State<YoutubeEmbedPlayerImpl> createState() => _YoutubeEmbedPlayerImplState();
}

class _YoutubeEmbedPlayerImplState extends State<YoutubeEmbedPlayerImpl> {
  static int _nextId = 0;
  static final Set<String> _registered = <String>{};

  String? _embedUrl;
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _embedUrl = toYoutubeEmbedUrl(widget.url);
    _viewType = 'youtube-iframe-${_nextId++}-${_embedUrl.hashCode}';
    _registerFactoryIfNeeded();
  }

  @override
  void didUpdateWidget(covariant YoutubeEmbedPlayerImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.autoplay != widget.autoplay ||
        oldWidget.allowFullScreen != widget.allowFullScreen) {
      // We keep the same viewType to avoid refresh loops. If the URL changes,
      // the common case is a different player instance anyway.
      _embedUrl = toYoutubeEmbedUrl(widget.url);
      _registerFactoryIfNeeded();
    }
  }

  void _registerFactoryIfNeeded() {
    if (_registered.contains(_viewType)) return;
    final embedUrl = _embedUrl;
    if (embedUrl == null) return;
    _registered.add(_viewType);

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final uri = Uri.parse(embedUrl);
      final withParams = uri.replace(queryParameters: {
        ...uri.queryParameters,
        if (widget.autoplay) 'autoplay': '1',
        'playsinline': '1',
        'rel': '0',
        'modestbranding': '1',
      });

      final iframe = html.IFrameElement()
        ..src = withParams.toString()
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
        ..referrerPolicy = 'origin-when-cross-origin'
        ..allowFullscreen = widget.allowFullScreen;

      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    final embedUrl = _embedUrl;
    if (embedUrl == null) {
      return Center(
        child: Text(
          'Invalid YouTube URL',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return HtmlElementView(viewType: _viewType);
  }
}
