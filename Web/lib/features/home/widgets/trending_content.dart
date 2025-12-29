import 'package:flutter/material.dart';
import 'content_section.dart';

class TrendingContent extends StatelessWidget {
  const TrendingContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentSection(
      title: 'Trending',
      children: List.generate(5, (index) {
        return Container(
          width: 150,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.orange[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('Trending ${index + 1}'),
          ),
        );
      }),
    );
  }
}