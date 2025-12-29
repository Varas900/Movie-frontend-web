import 'package:flutter/material.dart';

class SeriesDetailsScreen extends StatelessWidget {
  final int seriesId;

  const SeriesDetailsScreen({
    super.key,
    required this.seriesId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Series Details'),
      ),
      body: const Center(
        child: Text('Series Details - Coming Soon'),
      ),
    );
  }
}