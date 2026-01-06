import 'package:flutter/material.dart';

enum AuthzPromptType {
  signIn,
  buyPlan,
}

AuthzPromptType? authzPromptFromStatusCode(int? statusCode) {
  if (statusCode == null) return null;
  if (statusCode == 401) return AuthzPromptType.signIn;
  if (statusCode == 403) return AuthzPromptType.buyPlan;
  return null;
}

AuthzPromptType? authzPromptFromError(Object? error) {
  if (error == null) return null;
  final msg = error.toString().toLowerCase();

  // Prefer explicit markers thrown by our code.
  if (msg.contains('http_401')) return AuthzPromptType.signIn;
  if (msg.contains('http_403')) return AuthzPromptType.buyPlan;

  // Fallbacks for common exception shapes.
  if (msg.contains(' http 401') || msg.contains('statuscode: 401')) {
    return AuthzPromptType.signIn;
  }
  if (msg.contains(' http 403') || msg.contains('statuscode: 403')) {
    return AuthzPromptType.buyPlan;
  }

  return null;
}

String authzPromptTitle(AuthzPromptType type) {
  switch (type) {
    case AuthzPromptType.signIn:
      return 'Sign in required';
    case AuthzPromptType.buyPlan:
      return 'Plan required';
  }
}

String authzPromptMessage(AuthzPromptType type) {
  switch (type) {
    case AuthzPromptType.signIn:
      return 'Please sign in to continue.';
    case AuthzPromptType.buyPlan:
      return 'Please buy a plan to continue.';
  }
}

String authzPromptPrimaryLabel(AuthzPromptType type) {
  switch (type) {
    case AuthzPromptType.signIn:
      return 'Sign in';
    case AuthzPromptType.buyPlan:
      return 'Buy a plan';
  }
}

Future<void> showAuthzPromptDialog(
  BuildContext context, {
  required AuthzPromptType type,
  required VoidCallback onPrimary,
  String? title,
  String? message,
  String? primaryLabel,
}) async {
  final t = title ?? authzPromptTitle(type);
  final m = message ?? authzPromptMessage(type);
  final primary = primaryLabel ?? authzPromptPrimaryLabel(type);

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        title: Text(t),
        content: Text(m),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onPrimary();
            },
            child: Text(primary),
          ),
        ],
      );
    },
  );
}
