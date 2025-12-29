import 'package:flutter/material.dart';

class ActorDetailsScreen extends StatelessWidget {
  final int actorId;

  const ActorDetailsScreen({
    super.key,
    required this.actorId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actor Details'),
      ),
      body: const Center(
        child: Text('Actor Details - Coming Soon'),
      ),
    );
  }
}