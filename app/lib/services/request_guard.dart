import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';
import 'api_service.dart';
import '../theme.dart';

class RequestGuard {
  static bool isAuthError(ApiException e) {
    return e.statusCode == 401 || e.statusCode == 403;
  }

  static Future<void> handleApiException(
    BuildContext context,
    ApiException e, {
    String? fallbackMessage,
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (isAuthError(e)) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Session expired. Please sign in again.'),
          duration: const Duration(seconds: 6),
          showCloseIcon: true,
          backgroundColor: ObrohColors.error,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Sign In',
            onPressed: () {
              context.read<AuthService>().logout();
            },
          ),
        ),
      );
      return;
    }

    final message = fallbackMessage ?? e.message;
    final hasRetry = onRetry != null;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        showCloseIcon: true,
        backgroundColor: ObrohColors.error,
        behavior: SnackBarBehavior.floating,
        action: hasRetry
            ? SnackBarAction(label: 'Retry', onPressed: onRetry)
            : SnackBarAction(
                label: 'Dismiss',
                onPressed: () {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  }
                },
              ),
      ),
    );
  }

  static void requireSessionOrReauth(BuildContext context, String? token) {
    if (token != null) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Session expired. Please sign in again.'),
        duration: const Duration(seconds: 6),
        showCloseIcon: true,
        backgroundColor: ObrohColors.error,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Sign In',
          onPressed: () {
            context.read<AuthService>().logout();
          },
        ),
      ),
    );
  }
}
