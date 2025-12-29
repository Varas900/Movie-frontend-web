import 'package:flutter/material.dart';
import 'content_section.dart';

class RecentContent extends StatelessWidget {
  const RecentContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentSection(
      title: 'Recently Added',
      children: List.generate(5, (index) {
        return Container(
          width: 150,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.blue[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('Recent ${index + 1}'),
          ),
        );
      }),
    );
  }
}