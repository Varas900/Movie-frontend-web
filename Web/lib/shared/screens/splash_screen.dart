import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_constants.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
    
    // Navigate after animation completes
    _navigateToNextScreen();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      // Try cookie-based sync for Google OAuth (web). This sends cookies with the request.
      try {
        final url = Uri.parse('${AppConstants.baseApiUrl}/user/me');
        final req = await html.HttpRequest.request(
          url.toString(),
          method: 'GET',
          withCredentials: true, // critical to include cross-site cookies
        );
        if (req.status == 200 && req.responseText != null) {
          final body = json.decode(req.responseText!);
          final data = (body is Map<String, dynamic>) ? (body['data'] ?? body['Data'] ?? body) : body;
          if (data is Map<String, dynamic>) {
            ref.read(authProvider.notifier).authenticateFromUserJson(data);
          }
        }
      } catch (_) {
        // ignore sync failure
      }

      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        context.go(AppRoutes.home);
      } else {
        context.go(AppRoutes.signin);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark 
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0d1117),
                  Color(0xFF161b22),
                  Color(0xFF21262d),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFf8f9fa),
                  Color(0xFFe9ecef),
                  Color(0xFFdee2e6),
                ],
              ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: AppTheme.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'FlixGo',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Tagline
                      Text(
                        'Premium Streaming Experience',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.w300,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 60),
                      
                      // Loading Animation
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? AppTheme.secondaryColor : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Loading Text
                      Text(
                        'Loading amazing content...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}