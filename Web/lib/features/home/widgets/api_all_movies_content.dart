import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/utils/app_constants.dart';
import '../../../shared/widgets/image_with_placeholder.dart';

class ApiAllMoviesContent extends StatefulWidget {
  const ApiAllMoviesContent({super.key});

  @override
  State<ApiAllMoviesContent> createState() => _ApiAllMoviesContentState();
}

class _ApiAllMoviesContentState extends State<ApiAllMoviesContent> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final url = Uri.parse('${AppConstants.baseApiUrl}/api/Movie/GetAllMoviesMainScreen/mainScreen');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final List<dynamic> items = body['data'] as List<dynamic>;
        setState(() {
          _items = items.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Failed to load movies';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Network error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ),
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final m = _items[index];
          final image = (m['image'] as String?) ?? AppConstants.defaultImageUrl;
          final title = (m['title'] as String?) ?? (m['originalTitle'] as String?) ?? 'Untitled';
          return SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: MoviePosterImage(url: image),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: _items.length,
      ),
    );
  }
}
