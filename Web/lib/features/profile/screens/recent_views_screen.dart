import 'package:flutter/material.dart';

class RecentViewsScreen extends StatelessWidget {
  const RecentViewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Views'),
      ),
      body: const Center(
        child: Text('Recent Views - Coming Soon'),
      ),
    );
  }
}