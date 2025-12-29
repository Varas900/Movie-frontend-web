import 'package:flutter/material.dart';

class AuthBackground extends StatelessWidget {
  final Widget child;

  const AuthBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: isDark 
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0d1117),
                Color(0xFF161b22),
                Color(0xFF21262d),
                Color(0xFF30363d),
              ],
            )
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFf8f9fa),
                Color(0xFFe9ecef),
                Color(0xFFdee2e6),
                Color(0xFFced4da),
              ],
            ),
      ),
      child: Stack(
        children: [
          // Animated Background Elements
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDark ? Colors.blue : Colors.purple).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDark ? Colors.purple : Colors.blue).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // Main Content
          child,
        ],
      ),
    );
  }
}