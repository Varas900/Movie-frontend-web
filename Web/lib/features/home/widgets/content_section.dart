import 'package:flutter/material.dart';

class ContentSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? child;

  const ContentSection({
    super.key,
    required this.title,
    this.subtitle,
    this.children = const [],
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (child != null)
          child!
        else
          SizedBox(
            height: 200,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: children,
            ),
          ),
      ],
    );
  }
}