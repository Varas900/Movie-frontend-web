import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../core/routing/app_router.dart';

class NotFoundScreen extends StatelessWidget {
  final String path;

  const NotFoundScreen({
    super.key,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 404 Animation or Icon
              Icon(
                Icons.error_outline,
                size: 120,
                color: Theme.of(context).colorScheme.error,
              ),
              
              const SizedBox(height: 24),
              
              // 404 Text
              Text(
                '404',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Not Found Message
              Text(
                'Page Not Found',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Description
              Text(
                'The page you are looking for does not exist.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              
              if (path.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Path: $path',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              const SizedBox(height: 48),
              
              // Action Buttons
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.go(AppRoutes.home),
                    icon: const Icon(Icons.home),
                    label: const Text('Go Home'),
                  ),
                  
                  OutlinedButton.icon(
                    onPressed: () {
                      if (context.canPop()) {
                        context.goBack();
                      } else {
                        context.go(AppRoutes.home);
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Additional Help
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.help_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Need Help?',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'If you think this is an error, please contact our support team.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.helpCenter),
                        child: const Text('Contact Support'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
