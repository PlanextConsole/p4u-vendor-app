import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../../firebase_options.dart';
import '../data/auth_repository.dart';

class VendorLoginPage extends ConsumerStatefulWidget {
  const VendorLoginPage({super.key});

  @override
  ConsumerState<VendorLoginPage> createState() => _VendorLoginPageState();
}

class _VendorLoginPageState extends ConsumerState<VendorLoginPage> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;
  String? _verificationId;

  Future<void> _sendOtp() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      _snack('Please enter a valid 10-digit phone number');
      return;
    }
    setState(() => _loading = true);
    final firebaseReady = await _ensureFirebase();
    if (!firebaseReady) {
      if (mounted) setState(() => _loading = false);
      _snack(
        'Firebase is not ready. Check google-services.json and try again.',
      );
      return;
    }
    try {
      await firebase.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$digits',
        verificationCompleted: (credential) async {
          await _signInWithCredential(credential);
        },
        verificationFailed: (error) {
          if (mounted) {
            setState(() => _loading = false);
            _snack(_friendly(error));
          }
        },
        codeSent: (verificationId, _) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _otpSent = true;
              _loading = false;
            });
          }
        },
        codeAutoRetrievalTimeout: (verificationId) =>
            _verificationId = verificationId,
      );
    } catch (e) {
      _snack('$e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _ensureFirebase() async {
    if (Firebase.apps.isNotEmpty) return true;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 8));
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      debugPrint('Firebase init failed before OTP: $e');
      return false;
    }
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null || _otp.text.length != 6) {
      _snack('Enter the 6-digit OTP');
      return;
    }
    setState(() => _loading = true);
    try {
      final credential = firebase.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otp.text,
      );
      await _signInWithCredential(credential);
    } catch (e) {
      _snack(_friendly(e));
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithCredential(
      firebase.PhoneAuthCredential credential) async {
    final auth = firebase.FirebaseAuth.instance;
    try {
      final userCredential = await auth.signInWithCredential(credential);
      final token = await userCredential.user?.getIdToken(true);
      if (token == null) throw StateError('Missing Firebase ID token');
      await ref.read(authRepositoryProvider).signInWithFirebaseIdToken(token);
      ref.invalidate(authStateProvider);
      if (mounted) context.go('/');
    } catch (e) {
      _snack(_friendly(e));
    } finally {
      await auth.signOut().catchError((_) {});
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendly(Object e) {
    if (e is ApiException) return e.message;
    if (e is firebase.FirebaseAuthException) {
      if (e.code == 'invalid-verification-code') {
        return 'Incorrect OTP. Please try again.';
      }
      if (e.code == 'session-expired' || e.code == 'code-expired') {
        return 'OTP expired. Please request a new code.';
      }
      final message = e.message ?? '';
      if (e.code == 'app-not-authorized' ||
          message.toLowerCase().contains('missing a valid app identifier')) {
        return 'Firebase phone OTP is not authorized for this APK. Add this app package and SHA-1/SHA-256 fingerprints in Firebase Console, download google-services.json, then rebuild.';
      }
      return message.isNotEmpty ? message : 'OTP failed. Please try again.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      if (next.valueOrNull != null && mounted) context.go('/');
    });
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accent, Colors.white, AppColors.softGreen],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  elevation: 16,
                  shadowColor: AppColors.brandDark.withValues(alpha: .14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.primary,
                            AppColors.primaryDark
                          ]),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x331F1F1F),
                                    blurRadius: 18,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/p4u-logo.png',
                                fit: BoxFit.contain,
                                semanticLabel: 'Planext4u',
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.store_rounded,
                                    color: Colors.white70, size: 20),
                                SizedBox(width: 8),
                                Text('Vendor Portal',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                                'Manage your store, orders & settlements',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Phone OTP sign-in',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(height: 16),
                            if (!_otpSent) ...[
                              TextField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.phone_rounded),
                                    prefixText: '+91 ',
                                    hintText: 'Phone number',
                                    counterText: ''),
                              ),
                            ] else ...[
                              Text('Enter OTP sent to +91 ${_phone.text}',
                                  style:
                                      const TextStyle(color: Colors.black54)),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _otp,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 8),
                                decoration: const InputDecoration(
                                    hintText: '000000', counterText: ''),
                              ),
                            ],
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: _loading
                                  ? null
                                  : (_otpSent ? _verifyOtp : _sendOtp),
                              icon: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Icon(_otpSent
                                      ? Icons.verified_user_rounded
                                      : Icons.arrow_forward_rounded),
                              label: Text(_loading
                                  ? 'Please wait...'
                                  : (_otpSent
                                      ? 'Verify OTP'
                                      : 'Send OTP')),
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52)),
                            ),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: () => context.go('/register'),
                              child: const Text('New vendor? Register here'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
