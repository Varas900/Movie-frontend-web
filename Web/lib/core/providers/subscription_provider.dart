import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../utils/app_constants.dart';
import 'auth_provider.dart';

bool _isActiveSubscriptionRecord(Map<String, dynamic> sub) {
  final status = (sub['status'] ?? 'active').toString().toLowerCase().trim();
  if (status == 'active' || status == 'trialing') return true;

  final endRaw = sub['currentPeriodEnd'] ?? sub['current_period_end'];
  if (endRaw != null) {
    final end = DateTime.tryParse(endRaw.toString());
    if (end != null) {
      return end.isAfter(DateTime.now().toUtc());
    }
  }
  return false;
}

final hasActiveSubscriptionProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  final userId = user?.userId;
  if (userId == null || userId <= 0) return false;

  final uri = Uri.parse('${AppConstants.baseApiUrl}/api/payment/subscription/user/$userId');
  final res = await http.get(uri);
  if (res.statusCode < 200 || res.statusCode >= 300) return false;

  final body = jsonDecode(res.body);
  final data = (body is Map<String, dynamic>) ? (body['data'] ?? body['Data'] ?? body) : body;
  final list = (data is List) ? data : <dynamic>[];
  if (list.isEmpty) return false;

  // Pick the latest record if sortable by subscriptionID.
  final records = list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  records.sort((a, b) {
    final aId = (a['subscriptionID'] ?? a['subscriptionId'] ?? 0) as num;
    final bId = (b['subscriptionID'] ?? b['subscriptionId'] ?? 0) as num;
    return bId.compareTo(aId);
  });

  return _isActiveSubscriptionRecord(records.first);
});
