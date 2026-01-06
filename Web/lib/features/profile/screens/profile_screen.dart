import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/app_constants.dart';
import '../../../core/utils/url_utils.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/http_client_factory.dart';
import '../../../core/services/user_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final tab = GoRouterState.of(context).uri.queryParameters['tab'];
    final initialIndex = switch (tab) {
      'settings' => 1,
      'subscription' => 2,
      _ => 0,
    };

    return DefaultTabController(
      length: 3,
      initialIndex: initialIndex,
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

  String _formatDob(dynamic value) {
    if (value == null) return '—';
    final s = value.toString().trim();
    if (s.isEmpty) return '—';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String dashIfEmpty(String? v) {
      final s = (v ?? '').trim();
      return s.isEmpty ? '—' : s;
    }

    Widget field({required String label, required String value}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    field(label: 'Username', value: user.userName),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: field(
                            label: 'First name',
                            value: dashIfEmpty(user.firstName),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: field(
                            label: 'Last name',
                            value: dashIfEmpty(user.lastName),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    field(label: 'Gender', value: dashIfEmpty(user.gender)),
                    const SizedBox(height: 16),
                    field(label: 'Date of birth', value: _formatDob(user.dateOfBirth)),
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

class _ProfileSettings extends ConsumerStatefulWidget {
  final User user;
  const _ProfileSettings({required this.user});

  @override
  ConsumerState<_ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends ConsumerState<_ProfileSettings> {
  final _userService = UserService();

  late final TextEditingController _usernameCtrl;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;

  String _gender = 'other';
  DateTime? _dateOfBirth;
  XFile? _avatarFile;
  Uint8List? _avatarBytes;
  String? _avatarCacheKey;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.user.userName);
    _firstNameCtrl = TextEditingController(text: widget.user.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: widget.user.lastName ?? '');
    _gender = (widget.user.gender ?? 'other').toLowerCase();
    if (!['male', 'female', 'other'].contains(_gender)) _gender = 'other';
    _dateOfBirth = DateTime.tryParse(widget.user.dateOfBirth ?? '');
  }

  @override
  void didUpdateWidget(covariant _ProfileSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If user changes (or gets refreshed from /user/me), keep the inline form in sync
    // without clobbering unsaved local edits.
    final isSameUser = oldWidget.user.userId == widget.user.userId;
    final didRelevantChange =
        !isSameUser ||
        oldWidget.user.userName != widget.user.userName ||
        oldWidget.user.firstName != widget.user.firstName ||
        oldWidget.user.lastName != widget.user.lastName ||
        oldWidget.user.gender != widget.user.gender ||
        oldWidget.user.dateOfBirth != widget.user.dateOfBirth ||
        oldWidget.user.avatar != widget.user.avatar;

    if (!didRelevantChange) return;

    if (!isSameUser) {
      _avatarFile = null;
      _avatarBytes = null;
      _error = null;
      _saving = false;
    }

    if (_saving) return;

    if (_usernameCtrl.text == oldWidget.user.userName) {
      _usernameCtrl.text = widget.user.userName;
    }
    if (_firstNameCtrl.text == (oldWidget.user.firstName ?? '')) {
      _firstNameCtrl.text = widget.user.firstName ?? '';
    }
    if (_lastNameCtrl.text == (oldWidget.user.lastName ?? '')) {
      _lastNameCtrl.text = widget.user.lastName ?? '';
    }

    final oldGender = (oldWidget.user.gender ?? 'other').toLowerCase();
    if (_gender == oldGender) {
      _gender = (widget.user.gender ?? 'other').toLowerCase();
      if (!['male', 'female', 'other'].contains(_gender)) _gender = 'other';
    }

    final oldDob = DateTime.tryParse(oldWidget.user.dateOfBirth ?? '');
    if (_dateOfBirth?.toIso8601String() == oldDob?.toIso8601String()) {
      _dateOfBirth = DateTime.tryParse(widget.user.dateOfBirth ?? '');
    }

    // If backend updated avatar, prefer it unless user picked a new file locally.
    if (_avatarFile == null && _avatarBytes == null) {
      // nothing to do; build() reads widget.user.avatar directly.
    }

    setState(() {});
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _avatarFile = file;
      _avatarBytes = bytes;
    });
  }

  Future<void> _pickDob(BuildContext context) async {
    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    final user = widget.user;
    final newUsername = _usernameCtrl.text.trim();
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();

    if (newUsername.isEmpty) {
      setState(() => _error = 'Username is required');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (newUsername != user.userName) {
        await _userService.updateUsername(userId: user.userId, newUsername: newUsername);
      }

      final oldDob = DateTime.tryParse(user.dateOfBirth ?? '');
      final shouldUpdateProfile =
          _avatarFile != null ||
          firstName != (user.firstName ?? '') ||
          lastName != (user.lastName ?? '') ||
          _gender != (user.gender ?? 'other').toLowerCase() ||
          (_dateOfBirth?.toIso8601String() != oldDob?.toIso8601String());

      if (shouldUpdateProfile) {
        await _userService.updateProfileMultipart(
          userId: user.userId,
          newUserName: newUsername,
          firstName: firstName,
          lastName: lastName,
          gender: _gender,
          dateOfBirth: _dateOfBirth,
          avatar: _avatarFile,
        );

        if (_avatarFile != null) {
          _avatarCacheKey = DateTime.now().millisecondsSinceEpoch.toString();
        }
      }

      // Refresh canonical values from /user/me
      try {
        final me = await _userService.getMe();
        final profile = (me['profile'] is Map)
            ? Map<String, dynamic>.from(me['profile'] as Map)
            : <String, dynamic>{};

        final updated = user.copyWith(
          userName: (me['userName'] ?? user.userName).toString(),
          firstName: (me['firstName'] ?? profile['firstName'])?.toString(),
          lastName: (me['lastName'] ?? profile['lastName'])?.toString(),
          avatar: (me['avatar'] ?? profile['avatar'])?.toString(),
          gender: (me['gender'] ?? profile['gender'])?.toString(),
          dateOfBirth: (me['dateOfBirth'] ?? profile['dateOfBirth'])?.toString(),
        );
        ref.read(authProvider.notifier).updateUser(updated);
      } catch (_) {
        final updated = user.copyWith(
          userName: newUsername,
          firstName: firstName,
          lastName: lastName,
          gender: _gender,
          dateOfBirth: _dateOfBirth?.toIso8601String(),
        );
        ref.read(authProvider.notifier).updateUser(updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final avatarUrl = cacheBustUrl(
      resolveApiUrl(user.avatar),
      cacheKey: _avatarCacheKey,
    );
    final hasNetworkAvatar = _avatarBytes == null && avatarUrl.isNotEmpty;
    final dobLabel = _dateOfBirth == null ? 'Not set' : DateFormat('yyyy-MM-dd').format(_dateOfBirth!);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.red,
                          backgroundImage: _avatarBytes != null
                              ? MemoryImage(_avatarBytes!)
                              : (hasNetworkAvatar ? NetworkImage(avatarUrl) : null) as ImageProvider<Object>?,
                          child: (_avatarBytes == null && !hasNetworkAvatar)
                              ? Text(user.initials,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _pickAvatar,
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Change Photo'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(labelText: 'Username'),
                      enabled: !_saving,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstNameCtrl,
                            decoration: const InputDecoration(labelText: 'First name'),
                            enabled: !_saving,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lastNameCtrl,
                            decoration: const InputDecoration(labelText: 'Last name'),
                            enabled: !_saving,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: _saving ? null : (v) => setState(() => _gender = v ?? 'other'),
                      decoration: const InputDecoration(labelText: 'Gender'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text('Date of birth: $dobLabel')),
                        OutlinedButton(
                          onPressed: _saving ? null : () => _pickDob(context),
                          child: const Text('Pick'),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _saving ? null : () => _showChangePasswordDialog(context, ref),
                          icon: const Icon(Icons.lock_reset),
                          label: const Text('Change Password'),
                        ),
                      ],
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
  const _ProfileSubscription();

  @override
  ConsumerState<_ProfileSubscription> createState() => _ProfileSubscriptionState();
}

class _ProfileSubscriptionState extends ConsumerState<_ProfileSubscription> {
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? _currentPlan; // { planId, name, status, expiry }
  List<Map<String, dynamic>> _plans = [];
  Map<String, String> _planPriceLabel = {};
  final Map<String, int> _planFirstPriceId = {}; // planId -> priceID
  final Map<String, Map<String, dynamic>> _planPriceInfo = {}; // planId -> { priceID, amount, currency, intervalUnit, intervalCount }
  List<Map<String, dynamic>> _billingHistory = [];

  String? _selectedPlanId;
  bool _showBillingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
      final Map<String, String> priceLabel = <String, String>{};
      for (final p in _plans) {
        final pid = (p['id'] ?? '').toString();
        final matched = prices.cast<dynamic?>().firstWhere(
              (pr) => (pr is Map<String, dynamic>) &&
                  ((pr['planID']?.toString() ?? pr['planId']?.toString() ?? '') == pid),
              orElse: () => null,
            )
            as Map<String, dynamic>?;

        if (matched == null) continue;

        final amount = matched['amount'];
        final currency = (matched['currency'] ?? '').toString();
        final priceId = matched['priceID'] ?? matched['priceId'];

        if (amount != null) {
          final amountNum = double.tryParse(amount.toString());
          if (amountNum != null && amountNum == 0) {
            priceLabel[pid] = 'Free';
          } else {
            priceLabel[pid] = _formatAmount(amount, currency);
          }
        }

        final priceIdInt = int.tryParse(priceId?.toString() ?? '');
        if (priceIdInt != null) {
          _planFirstPriceId[pid] = priceIdInt;
        }

        _planPriceInfo[pid] = {
          'priceID': priceId,
          'amount': amount,
          'currency': currency,
          'intervalUnit': (matched['intervalUnit'] ?? 'month').toString(),
          'intervalCount': matched['intervalCount'] ?? 1,
        };
      }
      _planPriceLabel = priceLabel;

      // Current subscription
      final auth = ref.read(authProvider);
      final userId = auth.user?.userId;
      if (userId != null && userId > 0) {
        final subsRes = await http.get(Uri.parse('${AppConstants.baseApiUrl}/api/payment/subscription/user/$userId'));
        if (subsRes.statusCode >= 200 && subsRes.statusCode < 300) {
          final body = json.decode(subsRes.body);
          final arr = (body is Map<String, dynamic>)
              ? (body['data'] ?? body['Data'] ?? [])
              : (body as List? ?? []);

          final list = (arr as List).whereType<Map<String, dynamic>>().toList();
          if (list.isNotEmpty) {
            list.sort((a, b) {
              final ai = (a['subscriptionID'] ?? a['subscriptionId'] ?? 0) as num;
              final bi = (b['subscriptionID'] ?? b['subscriptionId'] ?? 0) as num;
              return bi.compareTo(ai);
            });

            final latest = list.first;
            final latestPlanId = (latest['planID'] ?? latest['planId'])?.toString();
            final latestPlanName = _resolvePlanName(latestPlanId);
            final expiry = _formatIsoDate(latest['currentPeriodEnd']);
            final status = (latest['status'] ?? 'active').toString();

            _currentPlan = {
              'planId': latestPlanId,
              'name': latestPlanName,
              'status': status,
              'expiry': expiry,
            };

            _billingHistory = list.map((it) {
              final planId = (it['planID'] ?? it['planId'])?.toString();
              final planName = _resolvePlanName(planId);
              final created = _formatIsoDate(it['createdAt'] ?? it['paidAt'] ?? it['created'] ?? it['paymentDate']);
              final st = (it['status'] ?? 'unknown').toString();
              final method = (it['paymentMethod'] ?? it['provider'] ?? it['gateway'] ?? 'VnPay').toString();
              final amount = it['amount'] ?? it['totalAmount'] ?? it['price'] ?? it['paidAmount'];
              final currency = (it['currency'] ?? 'VND').toString();
              final amountLabel = amount == null ? '' : _formatAmount(amount, currency);
              return {
                'planName': planName,
                'amount': amountLabel,
                'method': method,
                'status': st,
                'date': created,
              };
            }).toList(growable: false);

            _selectedPlanId ??= latestPlanId;
          }
        }
      }

      _selectedPlanId ??= _plans.isNotEmpty ? (_plans.first['id']?.toString()) : null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _formatAmount(dynamic amount, String currency) {
    final numVal = (amount is num) ? amount.toDouble() : double.tryParse(amount?.toString() ?? '') ?? 0.0;
    final nf = NumberFormat.decimalPattern();
    final amt = nf.format(numVal);
    return '$amt ${currency.toUpperCase()}';
  }

  String _formatIsoDate(dynamic value) {
    if (value == null) return '';
    final s = value.toString();
    if (s.isEmpty) return '';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _resolvePlanName(String? planId) {
    if (planId == null || planId.isEmpty) return 'Plan';
    final match = _plans.cast<Map<String, dynamic>?>().firstWhere(
          (p) => p != null && p['id']?.toString() == planId,
          orElse: () => null,
        );
    return match?['name']?.toString() ?? 'Plan';
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
      final client = createHttpClient(withCredentials: true);
      http.Response res;
      try {
        res = await client.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode({
            'PriceId': priceId,
            'AutoRenew': false,
          }),
        );
      } finally {
        client.close();
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Checkout failed (${res.statusCode})');
      }
      final body = json.decode(res.body);
      final data = body is Map<String, dynamic> ? (body['data'] ?? body['Data']) : null;
      final payUrl = (data is Map<String, dynamic>)
          ? (data['paymentUrl'] ?? data['payUrl'] ?? data['url'])
          : (body is Map<String, dynamic> ? (body['paymentUrl'] ?? body['payUrl'] ?? body['url']) : null);

      if (payUrl is String && payUrl.isNotEmpty) {
        await launchUrl(Uri.parse(payUrl), mode: LaunchMode.externalApplication);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment page opened in a new tab')));
      } else {
        throw Exception('Missing payment URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
      }
    }

  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = _plans.firstWhere(
      (p) => p['id']?.toString() == _selectedPlanId,
      orElse: () => const <String, dynamic>{},
    );
    final selectedName = (selected['name'] ?? '').toString();
    final selectedPriceId = _selectedPlanId == null ? null : _planFirstPriceId[_selectedPlanId!];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              _RedOutlinedCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Failed to load subscription info: $_error',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),

            _SectionHeader(title: 'Current Plan'),
            const SizedBox(height: 10),
            _buildCurrentPlanCard(context),

            const SizedBox(height: 18),
            _SectionHeader(title: 'Choose Plan'),
            const SizedBox(height: 10),

            if (_loading && _plans.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_plans.isEmpty)
              _RedOutlinedCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'No active plans available.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ..._plans.map((p) {
                final pid = p['id']?.toString() ?? '';
                final isSelected = pid.isNotEmpty && pid == _selectedPlanId;

                final priceInfo = _planPriceInfo[pid];
                final amountLabel = priceInfo == null
                    ? (_planPriceLabel[pid] ?? 'N/A')
                    : _formatAmount(priceInfo['amount'], (priceInfo['currency'] ?? 'VND').toString());
                final intervalUnit = (priceInfo?['intervalUnit'] ?? 'month').toString();
                final intervalCount = int.tryParse((priceInfo?['intervalCount'] ?? 1).toString()) ?? 1;
                final perLabel = intervalUnit.isEmpty
                    ? ''
                    : '/ ${intervalCount > 1 ? '$intervalCount ' : ''}$intervalUnit';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PlanCard(
                    title: (p['name'] ?? 'Plan').toString(),
                    price: amountLabel,
                    per: perLabel,
                    description: (p['description'] ?? '').toString(),
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedPlanId = pid;
                      });
                    },
                  ),
                );
              }),

            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: (selectedPriceId == null)
                    ? null
                    : () => _startCheckout(selectedPriceId),
                child: Text(
                  selectedName.isEmpty ? 'Continue' : 'Continue with plan *$selectedName',
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 14),
            _BillingHistoryCard(
              isExpanded: _showBillingHistory,
              onToggle: () {
                setState(() {
                  _showBillingHistory = !_showBillingHistory;
                });
              },
              items: _billingHistory,
            ),

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.primary,
                  side: BorderSide(color: cs.primary, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cancel subscription: coming soon')),
                  );
                },
                child: const Text('Cancel Subscription'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlanCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading && _currentPlan == null) {
      return _RedOutlinedCard(
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_currentPlan == null) {
      return _RedOutlinedCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No active subscription',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final name = (_currentPlan?['name'] ?? 'Plan').toString();
    final status = (_currentPlan?['status'] ?? '').toString();
    final expiry = (_currentPlan?['expiry'] ?? '').toString();

    return _RedOutlinedCard(
      fillColor: cs.primary.withOpacity(0.10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          children: [
            Text(
              name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              status.isEmpty ? '—' : status,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.70)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              expiry.isEmpty ? 'Expires: —' : 'Expires: $expiry',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.65)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _RedOutlinedCard extends StatelessWidget {
  final Widget child;
  final Color? fillColor;
  const _RedOutlinedCard({required this.child, this.fillColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: fillColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary, width: 1.2),
      ),
      child: child,
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String per;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.per,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = isSelected ? cs.primary : cs.outlineVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '$price ${per.trim()}'.trim(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.70)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BillingHistoryCard extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Map<String, dynamic>> items;

  const _BillingHistoryCard({
    required this.isExpanded,
    required this.onToggle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _RedOutlinedCard(
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Show Billing History (i)',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: cs.primary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  const Divider(height: 18),
                  if (items.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No billing history',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  else
                    ...items.map((it) {
                      final plan = (it['planName'] ?? '').toString();
                      final amount = (it['amount'] ?? '').toString();
                      final method = (it['method'] ?? '').toString();
                      final status = (it['status'] ?? '').toString();
                      final date = (it['date'] ?? '').toString();

                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.primary.withOpacity(0.9), width: 1.0),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      plan.toUpperCase(),
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: cs.primary,
                                          ),
                                    ),
                                  ),
                                  if (amount.isNotEmpty)
                                    Text(
                                      amount,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (method.isNotEmpty)
                                Text('Payment Method: $method', style: Theme.of(context).textTheme.bodySmall),
                              if (status.isNotEmpty)
                                Text('Status: $status', style: Theme.of(context).textTheme.bodySmall),
                              if (date.isNotEmpty)
                                Text(date, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
        ],
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

void _showEditProfileDialog(BuildContext context, WidgetRef ref, User user) {
  final userService = UserService();
  final usernameCtrl = TextEditingController(text: user.userName);
  final firstNameCtrl = TextEditingController(text: user.firstName ?? '');
  final lastNameCtrl = TextEditingController(text: user.lastName ?? '');

  String gender = (user.gender ?? 'other').toLowerCase();
  if (!['male', 'female', 'other'].contains(gender)) gender = 'other';

  DateTime? dateOfBirth = DateTime.tryParse(user.dateOfBirth ?? '');
  XFile? avatarFile;
  Uint8List? avatarBytes;

  bool saving = false;
  String? error;

  Future<void> pickAvatar(void Function(void Function()) setState) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      avatarFile = file;
      avatarBytes = bytes;
    });
  }

  Future<void> pickDob(void Function(void Function()) setState, BuildContext ctx) async {
    final now = DateTime.now();
    final initial = dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => dateOfBirth = picked);
  }

  showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setState) {
        final avatarUrl = (user.avatar ?? '').trim();
        final hasNetworkAvatar = avatarBytes == null && avatarUrl.isNotEmpty;
        final dobLabel = dateOfBirth == null
            ? 'Not set'
            : DateFormat('yyyy-MM-dd').format(dateOfBirth!);

        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.red,
                      backgroundImage: avatarBytes != null
                          ? MemoryImage(avatarBytes!)
                          : (hasNetworkAvatar ? NetworkImage(avatarUrl) : null) as ImageProvider<Object>?,
                      child: (avatarBytes == null && !hasNetworkAvatar)
                          ? Text(
                              user.initials,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: saving ? null : () => pickAvatar(setState),
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Change Photo'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: firstNameCtrl,
                        decoration: const InputDecoration(labelText: 'First name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: lastNameCtrl,
                        decoration: const InputDecoration(labelText: 'Last name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: gender,
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: saving ? null : (v) => setState(() => gender = v ?? 'other'),
                  decoration: const InputDecoration(labelText: 'Gender'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('Date of birth: $dobLabel')),
                    OutlinedButton(
                      onPressed: saving ? null : () => pickDob(setState, dialogCtx),
                      child: const Text('Pick'),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final newUsername = usernameCtrl.text.trim();
                      final firstName = firstNameCtrl.text.trim();
                      final lastName = lastNameCtrl.text.trim();

                      if (newUsername.isEmpty) {
                        setState(() => error = 'Username is required');
                        return;
                      }

                      setState(() {
                        saving = true;
                        error = null;
                      });

                      try {
                        if (newUsername != user.userName) {
                          await userService.updateUsername(
                            userId: user.userId,
                            newUsername: newUsername,
                          );
                        }

                        final shouldUpdateProfile =
                            avatarFile != null ||
                            firstName != (user.firstName ?? '') ||
                            lastName != (user.lastName ?? '') ||
                            gender != (user.gender ?? 'other').toLowerCase() ||
                            (dateOfBirth?.toIso8601String() != DateTime.tryParse(user.dateOfBirth ?? '')?.toIso8601String());

                        if (shouldUpdateProfile) {
                          await userService.updateProfileMultipart(
                            userId: user.userId,
                            newUserName: newUsername,
                            firstName: firstName,
                            lastName: lastName,
                            gender: gender,
                            dateOfBirth: dateOfBirth,
                            avatar: avatarFile,
                          );
                        }

                        // Refresh from /user/me (includes nested profile fields)
                        try {
                          final me = await userService.getMe();
                          final profile = (me['profile'] is Map)
                              ? Map<String, dynamic>.from(me['profile'] as Map)
                              : <String, dynamic>{};
                          final updated = user.copyWith(
                            userName: (me['userName'] ?? user.userName).toString(),
                            firstName: (me['firstName'] ?? profile['firstName'])?.toString(),
                            lastName: (me['lastName'] ?? profile['lastName'])?.toString(),
                            avatar: (me['avatar'] ?? profile['avatar'])?.toString(),
                            gender: (me['gender'] ?? profile['gender'])?.toString(),
                            dateOfBirth: (me['dateOfBirth'] ?? profile['dateOfBirth'])?.toString(),
                          );
                          ref.read(authProvider.notifier).updateUser(updated);
                        } catch (_) {
                          final updated = user.copyWith(
                            userName: newUsername,
                            firstName: firstName,
                            lastName: lastName,
                            gender: gender,
                            dateOfBirth: dateOfBirth?.toIso8601String(),
                          );
                          ref.read(authProvider.notifier).updateUser(updated);
                        }

                        if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Profile updated')));
                        }
                      } catch (e) {
                        setState(() => error = e.toString());
                      } finally {
                        setState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        );
      },
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
            if (context.mounted) Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password change requested')));
          },
          child: const Text('Update'),
        ),
      ],
    ),
  );
}