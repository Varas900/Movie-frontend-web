import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/app_constants.dart';
import '../../../core/services/storage_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Settings'),
              Tab(text: 'Subscription'),
            ],
          ),
          actions: [
          if (authState.isAuthenticated)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) context.go(AppRoutes.signin);
              },
            ),
          ],
        ),
        body: authState.isAuthenticated && user != null
            ? TabBarView(
                children: [
                  _ProfileOverview(user: user),
                  _ProfileSettings(user: user),
                  const _ProfileSubscription(),
                ],
              )
            : _SignedOutBody(onSignIn: () => context.go(AppRoutes.signin)),
      ),
    );
  }
}

class _SignedOutBody extends StatelessWidget {
  final VoidCallback onSignIn;
  const _SignedOutBody({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_off, size: 64),
          const SizedBox(height: 12),
          const Text('You are not signed in'),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: onSignIn, child: const Text('Sign in')),
        ],
      ),
    );
  }
}

class _ProfileOverview extends ConsumerWidget {
  final User user;
  const _ProfileOverview({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user.fullDisplayName.isNotEmpty ? user.fullDisplayName : user.userName;
    final email = user.email;
    final role = user.role;
    final status = user.status;
    final createdAt = user.createdAt;
    final lastLogin = user.lastLogin;
    final verified = user.isEmailVerified == true;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Header Card
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      child: Text(user.initials, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              _Chip(label: _roleToString(role), color: Colors.blue),
                              const SizedBox(width: 8),
                              _Chip(label: _statusToString(status), color: status == UserStatus.active ? Colors.green : Colors.grey),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('@${user.userName}', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(verified ? Icons.verified : Icons.mark_email_unread, size: 16, color: verified ? Colors.green : Colors.orange),
                              const SizedBox(width: 6),
                              Text(verified ? 'Email verified' : 'Email not verified', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _showEditProfileDialog(context, ref, user),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Profile'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Latest Comments', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text('Coming soon'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, User user) {
    final nameCtrl = TextEditingController(text: user.fullDisplayName);
    final bioCtrl = TextEditingController(text: user.bio ?? '');
    String gender = user.gender ?? 'other';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Display Name'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: gender.isNotEmpty ? gender : 'other',
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => gender = v ?? 'other',
                decoration: const InputDecoration(labelText: 'Gender'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bioCtrl,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final updated = user.copyWith(
                name: nameCtrl.text.trim(),
                gender: gender,
                bio: bioCtrl.text.trim(),
              );
              // Persist locally for now; backend update can be integrated if needed
              ref.read(authProvider.notifier).updateUser(updated);
              if (context.mounted) Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Password'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                decoration: const InputDecoration(labelText: 'Current Password'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newCtrl,
                decoration: const InputDecoration(labelText: 'New Password'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmCtrl,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                return;
              }
              // Call service (optional; backend may be stubbed)
              // await ref.read(authServiceProvider).changePassword(currentCtrl.text, newCtrl.text);
              if (context.mounted) Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password change requested')));
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.tryParse(iso);
      if (dt == null) return '—';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _ProfileSettings extends ConsumerWidget {
  final User user;
  const _ProfileSettings({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _showEditProfileDialog(context, ref, user),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Profile'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showChangePasswordDialog(context, ref),
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('Change Password'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Preferences', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text('Notification and theme preferences will be added later.'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Danger Zone', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text('Delete Account'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSubscription extends ConsumerStatefulWidget {
  const _ProfileSubscription({super.key});

  @override
  ConsumerState<_ProfileSubscription> createState() => _ProfileSubscriptionState();
}

class _ProfileSubscriptionState extends ConsumerState<_ProfileSubscription> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _currentPlan; // { name, status, expiry }
  List<Map<String, dynamic>> _plans = [];
  Map<String, String> _planPriceLabel = {};
  final Map<String, int> _planFirstPriceId = {}; // planId -> priceID
  final Map<String, Map<String, dynamic>> _planPriceInfo = {}; // planId -> { priceID, amount, currency, intervalUnit, intervalCount }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Prices
      final pricesRes = await http.get(Uri.parse('${AppConstants.baseApiUrl}/api/price/all'));
      List<dynamic> prices = [];
      if (pricesRes.statusCode >= 200 && pricesRes.statusCode < 300) {
        final body = json.decode(pricesRes.body);
        prices = body is Map<String, dynamic> ? (body['data'] ?? body['Data'] ?? []) : (body as List? ?? []);
      }

      // Plans
      final plansRes = await http.get(Uri.parse('${AppConstants.baseApiUrl}/api/plans/all'));
      List<dynamic> plansRaw = [];
      if (plansRes.statusCode >= 200 && plansRes.statusCode < 300) {
        final body = json.decode(plansRes.body);
        plansRaw = body is Map<String, dynamic> ? (body['data'] ?? body['Data'] ?? []) : (body as List? ?? []);
      }
      final activePlans = plansRaw.where((p) => (p['isActive'] ?? true) != false).toList();
      _plans = activePlans.map<Map<String, dynamic>>((p) => {
        'id': p['planID'] ?? p['planId'] ?? p['id'],
        'name': p['name'] ?? p['code'] ?? 'Plan',
        'code': p['code'],
        'isActive': p['isActive'] ?? true,
        'description': p['description'],
      }).toList();

      // Map price
      final Map<String, String> priceLabel = {};
      for (final p in _plans) {
        final pid = (p['id'] ?? '').toString();
        final matched = prices.firstWhere(
          (pr) => (pr['planID']?.toString() ?? pr['planId']?.toString() ?? '') == pid,
          orElse: () => null,
        );
        if (matched != null) {
          final amount = matched['amount'];
          final currency = matched['currency'] ?? '';
          final priceId = matched['priceID'] ?? matched['priceId'];
          if (amount != null) {
            final amountNum = double.tryParse(amount.toString());
            priceLabel[pid] = (amountNum != null && amountNum == 0)
                ? 'Free'
                : '${amount ?? 'N/A'} ${currency}'.trim();
          }
          if (priceId != null) {
            final pidInt = int.tryParse(priceId.toString());
            if (pidInt != null) _planFirstPriceId[pid] = pidInt;
          }
          _planPriceInfo[pid] = {
            'priceID': priceId,
            'amount': amount,
            'currency': currency,
            'intervalUnit': matched['intervalUnit'] ?? 'month',
            'intervalCount': matched['intervalCount'] ?? 1,
          };
        }
      }
      _planPriceLabel = priceLabel;

      // Current subscription
      final auth = ref.read(authProvider);
      final userId = auth.user?.userId;
      if (userId != null && userId > 0) {
        final subsRes = await http.get(Uri.parse('${AppConstants.baseApiUrl}/api/payment/subscription/user/$userId'));
        if (subsRes.statusCode >= 200 && subsRes.statusCode < 300) {
          final body = json.decode(subsRes.body);
          final arr = body is Map<String, dynamic> ? (body['data'] ?? body['Data'] ?? []) : (body as List? ?? []);
          if (arr.isNotEmpty) {
            arr.sort((a,b) => ((b['subscriptionID'] ?? b['subscriptionId'] ?? 0) as num).compareTo((a['subscriptionID'] ?? a['subscriptionId'] ?? 0) as num));
            final latest = arr.first;
            var planId = latest['planID'] ?? latest['planId'];
            if (planId == null && latest['priceID'] != null) {
              try {
                final priceRes = await http.get(Uri.parse('${AppConstants.baseApiUrl}/api/price/${latest['priceID']}'));
                if (priceRes.statusCode >= 200 && priceRes.statusCode < 300) {
                  final pb = json.decode(priceRes.body);
                  final pdata = pb is Map<String, dynamic> ? (pb['data'] ?? pb['Data']) : null;
                  planId = pdata != null ? (pdata['planID'] ?? pdata['planId']) : planId;
                }
              } catch (_) {}
            }
            String planName = 'Current Plan';
            if (planId != null) {
              try {
                final planRes = await http.get(Uri.parse('${AppConstants.baseApiUrl}/api/plans/${planId}'));
                if (planRes.statusCode >= 200 && planRes.statusCode < 300) {
                  final pb = json.decode(planRes.body);
                  final pdata = pb is Map<String, dynamic> ? (pb['data'] ?? pb['Data']) : null;
                  if (pdata != null) planName = pdata['name'] ?? pdata['code'] ?? planName;
                }
              } catch (_) {}
            }
            String? expiry;
            if (latest['currentPeriodEnd'] != null) {
              try {
                final d = DateTime.tryParse(latest['currentPeriodEnd'].toString());
                if (d != null) expiry = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
              } catch (_) {}
            }
            final status = (latest['status'] ?? 'active').toString();
            _currentPlan = {
              'name': planName,
              'status': status,
              'expiry': expiry,
            };
          }
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  String _formatAmount(dynamic amount, String currency) {
    final numVal = (amount is num) ? amount.toDouble() : double.tryParse(amount?.toString() ?? '') ?? 0.0;
    final nf = NumberFormat.decimalPattern();
    final amt = nf.format(numVal);
    return '$amt ${currency.toUpperCase()}';
  }

  Future<void> _startCheckout(int priceId) async {
    try {
      final token = StorageService.getUserToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to subscribe')));
          context.go(AppRoutes.signin);
        }
        return;
      }
      final uri = Uri.parse('${AppConstants.baseApiUrl}/api/payment/vnpay/checkout');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
                    const Text('Unlock VIP perks like ad-free viewing and HD streaming.', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 12),
        body: json.encode({
          'PriceId': priceId,
          'AutoRenew': false,
        }),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Checkout failed (${res.statusCode})');
      }
      final body = json.decode(res.body);
                        final priceInfo = _planPriceInfo[pid];
                        final price = priceInfo == null
                            ? (_planPriceLabel[pid] ?? 'N/A')
                            : _formatAmount(priceInfo['amount'], priceInfo['currency']);
                        final intervalUnit = (priceInfo?['intervalUnit'] ?? 'month').toString();
                        final intervalCount = int.tryParse((priceInfo?['intervalCount'] ?? 1).toString()) ?? 1;
      if (payUrl is String && payUrl.isNotEmpty) {
        await launchUrl(Uri.parse(payUrl), mode: LaunchMode.externalApplication);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment page opened in a new tab')));
      } else {
        throw Exception('Missing payment URL');
      }
    } catch (e) {
      if (mounted) {
                                  Text(p['name'] ?? 'Plan', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                  const SizedBox(height: 6),
                                  Text('$price / ${intervalCount > 1 ? '$intervalCount ' : ''}$intervalUnit'),
  }

  @override
  Widget build(BuildContext context) {
                                  const SizedBox(height: 8),
                                  const Text('• Ad-free viewing\n• HD streaming\n• Early access'),
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
                                          : () => _startCheckout(_planFirstPriceId[pid]!),
                                      child: const Text('Upgrade'),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Failed to load subscription info: $_error'),
                ),
              ),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Plan', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (_loading && _currentPlan == null)
                      const Text('Loading...')
                    else if (_currentPlan == null)
                      const Text('No active subscription')
                    else ...[
                      Text(_currentPlan!['name'] ?? 'Current Plan'),
                      const SizedBox(height: 4),
                      Text('Status: ${_currentPlan!['status'] ?? 'N/A'}'),
                      if (_currentPlan!['expiry'] != null) Text('Expires: ${_currentPlan!['expiry']}'),
                      const SizedBox(height: 8),
                      const Text('Payment coming soon'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available Plans', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (_loading && _plans.isEmpty)
                      const Text('Loading...')
                    else if (_plans.isEmpty)
                      const Text('No active plans available.')
                    else Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _plans.map((p) {
                        final pid = (p['id'] ?? '').toString();
                        final price = _planPriceLabel[pid] ?? 'N/A';
                        return SizedBox(
                          width: 260,
                          child: Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['name'] ?? 'Plan', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  Text(price),
                                  if (p['description'] != null) ...[
                                    const SizedBox(height: 6),
                                    Text(p['description'], maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ],
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FilledButton(
                                      onPressed: _planFirstPriceId[pid] == null
                                          ? null
                                          : () => _startCheckout(_planFirstPriceId[pid]!),
                                      child: const Text('Subscribe'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Billing History', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text('Coming soon'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel Subscription'),
                    ),
                    const SizedBox(width: 12),
                    const Text('Coming soon'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanPlaceholderCard extends StatelessWidget {
  final String title;
  const _PlanPlaceholderCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('Coming soon', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoCard({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

String _roleToString(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Admin';
    case UserRole.manager:
      return 'Manager';
    case UserRole.moderator:
      return 'Moderator';
    case UserRole.user:
      return 'User';
  }
}

String _statusToString(UserStatus status) {
  switch (status) {
    case UserStatus.active:
      return 'Active';
    case UserStatus.inactive:
      return 'Inactive';
  }
}