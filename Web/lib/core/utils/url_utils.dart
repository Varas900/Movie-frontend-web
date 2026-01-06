import 'app_constants.dart';

String resolveApiUrl(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return '';

  // Allow data URIs and absolute URLs as-is.
  final parsed = Uri.tryParse(value);
  if (parsed != null && parsed.hasScheme) return value;

  // Handle scheme-relative URLs (e.g. //cdn.com/x.png)
  if (value.startsWith('//')) {
    final base = Uri.parse(AppConstants.baseApiUrl);
    return '${base.scheme}:$value';
  }

  final base = Uri.parse(AppConstants.baseApiUrl);
  if (value.startsWith('/')) return base.resolve(value).toString();
  return base.resolve('/$value').toString();
}

String cacheBustUrl(String rawUrl, {String? cacheKey, String param = 'v'}) {
  final value = rawUrl.trim();
  if (value.isEmpty) return '';

  final uri = Uri.tryParse(value);
  if (uri == null) return value;
  if (uri.scheme == 'data') return value;

  if (cacheKey == null || cacheKey.isEmpty) return value;

  final qp = Map<String, String>.from(uri.queryParameters);
  qp[param] = cacheKey;
  return uri.replace(queryParameters: qp).toString();
}
