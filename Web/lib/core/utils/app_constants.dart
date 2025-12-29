class AppConstants {
  static const String appName = 'FlixGo';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Premium Movie & TV Streaming Platform';
  
  // API Configuration
  static const String baseApiUrl = 'https://filmzone-api.koyeb.app';
  static const String defaultImageUrl = 'https://via.placeholder.com/300x400?text=No+Image';
  
  // Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userDataKey = 'user_data';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String recentViewsKey = 'recent_views';
  static const String favoritesKey = 'favorites';
  static const String watchlistKey = 'watchlist';
  static const String downloadQueueKey = 'download_queue';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String firstLaunchKey = 'first_launch';
  static const String videoQualityKey = 'video_quality';
  static const String autoPlayKey = 'auto_play';
  static const String subtitlesEnabledKey = 'subtitles_enabled';
  static const String recentlyViewedKey = 'recently_viewed';
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Video Player
  static const Duration seekInterval = Duration(seconds: 10);
  static const Duration skipIntroInterval = Duration(seconds: 90);
  
  // Subscription plans removed
  
  // Image Sizes
  static const String thumbnailSize = '300x400';
  static const String bannerSize = '1280x720';
  static const String profileSize = '200x200';
  
  // Responsive Breakpoints
  static const double mobileBreakpoint = 768;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1440;
  
  // Animation Durations
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  
  // Grid Configurations
  static const int mobileGridColumns = 2;
  static const int tabletGridColumns = 4;
  static const int desktopGridColumns = 6;
  
  // Social Media Links
  static const Map<String, String> socialLinks = {
    'facebook': 'https://facebook.com/flixgo',
    'twitter': 'https://twitter.com/flixgo',
    'instagram': 'https://instagram.com/flixgo',
    'youtube': 'https://youtube.com/flixgo',
  };
  
  // Contact Information
  static const Map<String, String> contactInfo = {
    'email': 'support@flixgo.com',
    'phone': '+84-123-456-789',
    'address': 'Ho Chi Minh City, Vietnam',
  };
  
  // Legal Links
  static const Map<String, String> legalLinks = {
    'privacy': '/privacy-policy',
    'terms': '/terms-of-service',
    'cookies': '/cookie-policy',
  };
}