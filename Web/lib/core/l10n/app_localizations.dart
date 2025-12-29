import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class AppLocalizations {
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('vi', 'VN'),
  ];

  static const List<LocalizationsDelegate> localizationsDelegates = [
    AppLocalizationsDelegate(),
    DefaultMaterialLocalizations.delegate,
    DefaultWidgetsLocalizations.delegate,
  ];

  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  // Common
  String get appName => _localizedValues[locale.languageCode]!['appName']!;
  String get loading => _localizedValues[locale.languageCode]!['loading']!;
  String get error => _localizedValues[locale.languageCode]!['error']!;
  String get success => _localizedValues[locale.languageCode]!['success']!;
  String get cancel => _localizedValues[locale.languageCode]!['cancel']!;
  String get confirm => _localizedValues[locale.languageCode]!['confirm']!;
  String get ok => _localizedValues[locale.languageCode]!['ok']!;
  String get retry => _localizedValues[locale.languageCode]!['retry']!;
  String get save => _localizedValues[locale.languageCode]!['save']!;
  String get edit => _localizedValues[locale.languageCode]!['edit']!;
  String get delete => _localizedValues[locale.languageCode]!['delete']!;
  String get search => _localizedValues[locale.languageCode]!['search']!;
  String get filter => _localizedValues[locale.languageCode]!['filter']!;
  String get sort => _localizedValues[locale.languageCode]!['sort']!;

  // Authentication
  String get signIn => _localizedValues[locale.languageCode]!['signIn']!;
  String get signUp => _localizedValues[locale.languageCode]!['signUp']!;
  String get signOut => _localizedValues[locale.languageCode]!['signOut']!;
  String get email => _localizedValues[locale.languageCode]!['email']!;
  String get password => _localizedValues[locale.languageCode]!['password']!;
  String get confirmPassword => _localizedValues[locale.languageCode]!['confirmPassword']!;
  String get forgotPassword => _localizedValues[locale.languageCode]!['forgotPassword']!;
  String get rememberMe => _localizedValues[locale.languageCode]!['rememberMe']!;
  String get createAccount => _localizedValues[locale.languageCode]!['createAccount']!;
  String get alreadyHaveAccount => _localizedValues[locale.languageCode]!['alreadyHaveAccount']!;
  String get dontHaveAccount => _localizedValues[locale.languageCode]!['dontHaveAccount']!;

  // Navigation
  String get home => _localizedValues[locale.languageCode]!['home']!;
  String get movies => _localizedValues[locale.languageCode]!['movies']!;
  String get series => _localizedValues[locale.languageCode]!['series']!;
  String get profile => _localizedValues[locale.languageCode]!['profile']!;
  String get favorites => _localizedValues[locale.languageCode]!['favorites']!;
  String get recentViews => _localizedValues[locale.languageCode]!['recentViews']!;
  String get settings => _localizedValues[locale.languageCode]!['settings']!;

  // Content
  String get watchNow => _localizedValues[locale.languageCode]!['watchNow']!;
  String get playTrailer => _localizedValues[locale.languageCode]!['playTrailer']!;
  String get addToFavorites => _localizedValues[locale.languageCode]!['addToFavorites']!;
  String get removeFromFavorites => _localizedValues[locale.languageCode]!['removeFromFavorites']!;
  String get rating => _localizedValues[locale.languageCode]!['rating']!;
  String get duration => _localizedValues[locale.languageCode]!['duration']!;
  String get releaseDate => _localizedValues[locale.languageCode]!['releaseDate']!;
  String get genre => _localizedValues[locale.languageCode]!['genre']!;
  String get cast => _localizedValues[locale.languageCode]!['cast']!;
  String get overview => _localizedValues[locale.languageCode]!['overview']!;
  String get episodes => _localizedValues[locale.languageCode]!['episodes']!;
  String get seasons => _localizedValues[locale.languageCode]!['seasons']!;

  // Subscription
  String get subscription => _localizedValues[locale.languageCode]!['subscription']!;
  String get subscribe => _localizedValues[locale.languageCode]!['subscribe']!;
  String get upgradeSubscription => _localizedValues[locale.languageCode]!['upgradeSubscription']!;
  String get cancelSubscription => _localizedValues[locale.languageCode]!['cancelSubscription']!;
  String get renewSubscription => _localizedValues[locale.languageCode]!['renewSubscription']!;
  String get subscriptionExpired => _localizedValues[locale.languageCode]!['subscriptionExpired']!;

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Common
      'appName': 'FlixGo',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'ok': 'OK',
      'retry': 'Retry',
      'save': 'Save',
      'edit': 'Edit',
      'delete': 'Delete',
      'search': 'Search',
      'filter': 'Filter',
      'sort': 'Sort',
      
      // Authentication
      'signIn': 'Sign In',
      'signUp': 'Sign Up',
      'signOut': 'Sign Out',
      'email': 'Email',
      'password': 'Password',
      'confirmPassword': 'Confirm Password',
      'forgotPassword': 'Forgot Password?',
      'rememberMe': 'Remember me',
      'createAccount': 'Create Account',
      'alreadyHaveAccount': 'Already have an account?',
      'dontHaveAccount': "Don't have an account?",
      
      // Navigation
      'home': 'Home',
      'movies': 'Movies',
      'series': 'TV Series',
      'profile': 'Profile',
      'favorites': 'Favorites',
      'recentViews': 'Recent Views',
      'settings': 'Settings',
      
      // Content
      'watchNow': 'Watch Now',
      'playTrailer': 'Play Trailer',
      'addToFavorites': 'Add to Favorites',
      'removeFromFavorites': 'Remove from Favorites',
      'rating': 'Rating',
      'duration': 'Duration',
      'releaseDate': 'Release Date',
      'genre': 'Genre',
      'cast': 'Cast',
      'overview': 'Overview',
      'episodes': 'Episodes',
      'seasons': 'Seasons',
      
      // Subscription
      'subscription': 'Subscription',
      'subscribe': 'Subscribe',
      'upgradeSubscription': 'Upgrade Subscription',
      'cancelSubscription': 'Cancel Subscription',
      'renewSubscription': 'Renew Subscription',
      'subscriptionExpired': 'Your subscription has expired',
    },
    'vi': {
      // Common
      'appName': 'FlixGo',
      'loading': 'Đang tải...',
      'error': 'Lỗi',
      'success': 'Thành công',
      'cancel': 'Hủy',
      'confirm': 'Xác nhận',
      'ok': 'Đồng ý',
      'retry': 'Thử lại',
      'save': 'Lưu',
      'edit': 'Chỉnh sửa',
      'delete': 'Xóa',
      'search': 'Tìm kiếm',
      'filter': 'Lọc',
      'sort': 'Sắp xếp',
      
      // Authentication
      'signIn': 'Đăng nhập',
      'signUp': 'Đăng ký',
      'signOut': 'Đăng xuất',
      'email': 'Email',
      'password': 'Mật khẩu',
      'confirmPassword': 'Xác nhận mật khẩu',
      'forgotPassword': 'Quên mật khẩu?',
      'rememberMe': 'Ghi nhớ đăng nhập',
      'createAccount': 'Tạo tài khoản',
      'alreadyHaveAccount': 'Đã có tài khoản?',
      'dontHaveAccount': 'Chưa có tài khoản?',
      
      // Navigation
      'home': 'Trang chủ',
      'movies': 'Phim lẻ',
      'series': 'Phim bộ',
      'profile': 'Hồ sơ',
      'favorites': 'Yêu thích',
      'recentViews': 'Xem gần đây',
      'settings': 'Cài đặt',
      
      // Content
      'watchNow': 'Xem ngay',
      'playTrailer': 'Xem trailer',
      'addToFavorites': 'Thêm vào yêu thích',
      'removeFromFavorites': 'Bỏ khỏi yêu thích',
      'rating': 'Đánh giá',
      'duration': 'Thời lượng',
      'releaseDate': 'Ngày phát hành',
      'genre': 'Thể loại',
      'cast': 'Diễn viên',
      'overview': 'Tóm tắt',
      'episodes': 'Tập phim',
      'seasons': 'Mùa phim',
      
      // Subscription
      'subscription': 'Gói đăng ký',
      'subscribe': 'Đăng ký',
      'upgradeSubscription': 'Nâng cấp gói',
      'cancelSubscription': 'Hủy đăng ký',
      'renewSubscription': 'Gia hạn đăng ký',
      'subscriptionExpired': 'Gói đăng ký đã hết hạn',
    },
  };
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'vi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}