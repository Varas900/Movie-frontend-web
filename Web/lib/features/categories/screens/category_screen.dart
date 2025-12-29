import 'package:flutter/material.dart';

class CategoryScreen extends StatelessWidget {
  final String genre;

  const CategoryScreen({
    super.key,
    required this.genre,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Category: $genre'),
      ),
      body: const Center(
        child: Text('Category Screen - Coming Soon'),
      ),
    );
  }
}