import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'youtube_embed_player.dart';

/// Non-web fallback implementation.
///
/// For platforms where we can't embed an iframe, we open the URL externally.
class YoutubeEmbedPlayerImpl extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final embed = toYoutubeEmbedUrl(url);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.ondemand_video, size: 40),
          const SizedBox(height: 8),
          Text(
            'This source is a YouTube link.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.tryParse(embed ?? url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Open in YouTube'),
          ),
        ],
      ),
    );
  }
}
