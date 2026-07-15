import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';

/// Cold-start gate that resolves the persisted session before routing, so an
/// already-logged-in vendor goes straight to the dashboard without the brief
/// login-screen flash. Unauthenticated users are sent to `/login`.
///
/// [authStateProvider] reads the on-disk token (shared_preferences) and yields
/// the cached vendor immediately, so this gate typically shows for a single
/// frame when a session exists.
class VendorSplashGate extends ConsumerWidget {
  const VendorSplashGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    // Route once we know the outcome. Rebuilds run this again when the async
    // value transitions loading -> data/error; navigating away disposes the
    // gate, so the redirect fires at most once.
    if (!auth.isLoading) {
      final loggedIn = auth.valueOrNull != null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(loggedIn ? '/' : '/login');
      });
    }

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
