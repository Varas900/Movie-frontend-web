import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class ImageWithPlaceholder extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? errorText;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const ImageWithPlaceholder({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorText,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = this.borderRadius ?? BorderRadius.circular(8);
    
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildErrorWidget(context, borderRadius);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => placeholder ?? _buildPlaceholder(context),
        errorWidget: (context, url, error) => _buildErrorWidget(context, borderRadius),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.surface,
        highlightColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, BorderRadius borderRadius) {
    if (errorWidget != null) return errorWidget!;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: borderRadius,
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: (height != null && height! < 100) ? 24 : 48,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          if (errorText != null && (height == null || height! >= 100)) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                errorText!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Specialized variants for common use cases
class MoviePosterImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const MoviePosterImage({
    super.key,
    this.imageUrl,
    this.width = 150,
    this.height = 225,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ImageWithPlaceholder(
          imageUrl: imageUrl,
          width: width,
          height: height,
          errorText: 'No Image',
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class ActorAvatarImage extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? fallbackText;
  final VoidCallback? onTap;

  const ActorAvatarImage({
    super.key,
    this.imageUrl,
    this.radius = 30,
    this.fallbackText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => _buildFallback(context),
                ),
              )
            : _buildFallback(context),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          fallbackText?.isNotEmpty == true 
              ? fallbackText![0].toUpperCase() 
              : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.6,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class BannerImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double height;
  final Widget? overlay;
  final VoidCallback? onTap;

  const BannerImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height = 200,
    this.overlay,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageWithPlaceholder(
              imageUrl: imageUrl,
              width: width,
              height: height,
              errorText: 'No Banner Image',
              borderRadius: BorderRadius.circular(16),
            ),
            
            // Gradient overlay for better text readability
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            
            // Custom overlay
            if (overlay != null) overlay!,
          ],
        ),
      ),
    );
  }
}