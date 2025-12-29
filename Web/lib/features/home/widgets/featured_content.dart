import 'package:flutter/material.dart';
import 'content_section.dart';

class FeaturedContent extends StatelessWidget {
  const FeaturedContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentSection(
      title: 'Featured',
      children: List.generate(5, (index) {
        return Container(
          width: 150,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('Featured ${index + 1}'),
          ),
        );
      }),
    );
  }
}