import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';

class VendorLoginPage extends ConsumerStatefulWidget {
  const VendorLoginPage({super.key});

  @override
  ConsumerState<VendorLoginPage> createState() => _VendorLoginPageState();
}

class _VendorLoginPageState extends ConsumerState<VendorLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;
  bool _otpSent = false;
  bool _passwordMode = false;
  String? _verificationId;

  bool get _useDemoPhoneLogin => false;

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      _snack('Please enter email and password');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithPassword(_email.text.trim(), _password.text);
      if (mounted) context.go('/');
    } catch (e) {
      _snack(e.toString().replaceFirst('AuthException(message: ', '').replaceFirst(', statusCode: null)', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _demoLogin() async {
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithDemo();
      ref.invalidate(authStateProvider);
      if (mounted) context.go('/');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendOtp() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      _snack('Please enter a valid 10-digit phone number');
      return;
    }
    if (_useDemoPhoneLogin) {
      await _demoLogin();
      return;
    }
    if (Firebase.apps.isEmpty) {
      _snack('Firebase is not configured for this native app yet.');
      return;
    }
    setState(() => _loading = true);
    try {
      await firebase.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$digits',
        verificationCompleted: (credential) async {
          await _signInWithCredential(credential);
        },
        verificationFailed: (error) {
          if (mounted) {
            setState(() => _loading = false);
            _snack(error.message ?? 'OTP failed. Please try again.');
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
        codeAutoRetrievalTimeout: (verificationId) => _verificationId = verificationId,
      );
    } catch (e) {
      _snack('$e');
      if (mounted) setState(() => _loading = false);
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
      _snack('Invalid OTP. Please try again.');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithCredential(firebase.PhoneAuthCredential credential) async {
    final userCredential = await firebase.FirebaseAuth.instance.signInWithCredential(credential);
    final token = await userCredential.user?.getIdToken();
    if (token == null) throw StateError('Missing Firebase ID token');
    await ref.read(authRepositoryProvider).signInWithFirebaseIdToken(token);
    if (mounted) context.go('/');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _modeSwitch() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(26),
        color: const Color(0xFFF7FAFA),
      ),
      child: Row(
        children: [
          _modeButton(label: 'Phone OTP', icon: Icons.phone_rounded, selected: !_passwordMode, onTap: () => _setMode(false)),
          _modeButton(label: 'Password', icon: Icons.mail_outline_rounded, selected: _passwordMode, onTap: () => _setMode(true)),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFD5F1F0) : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? Icons.check_rounded : icon, size: 18, color: AppColors.brandDark),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setMode(bool passwordMode) {
    setState(() {
      _passwordMode = passwordMode;
      _otpSent = false;
      _otp.clear();
    });
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
            colors: [Color(0xFFFFF7E8), Colors.white, Color(0xFFE8FFFF)],
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
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
                                    color: Color(0x33011D33),
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
                                Icon(Icons.store_rounded, color: Colors.white70, size: 20),
                                SizedBox(width: 8),
                                Text('Vendor Portal', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('Manage your store, orders & settlements', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            _modeSwitch(),
                            const SizedBox(height: 16),
                            if (_passwordMode) ...[
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded), hintText: 'Vendor Email'),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _password,
                                obscureText: !_showPassword,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  hintText: 'Password',
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _showPassword = !_showPassword),
                                    icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                                  ),
                                ),
                                onSubmitted: (_) => _submit(),
                              ),
                            ] else if (!_otpSent) ...[
                              TextField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_rounded), prefixText: '+91 ', hintText: 'Phone number', counterText: ''),
                              ),
                            ] else ...[
                              Text('Enter OTP sent to +91 ${_phone.text}', style: const TextStyle(color: Colors.black54)),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _otp,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 8),
                                decoration: const InputDecoration(hintText: '000000', counterText: ''),
                              ),
                            ],
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: _loading ? null : (_passwordMode ? _submit : (_otpSent ? _verifyOtp : _sendOtp)),
                              icon: _loading
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Icon(_passwordMode ? Icons.login_rounded : (_otpSent ? Icons.verified_user_rounded : Icons.arrow_forward_rounded)),
                              label: Text(_loading ? 'Please wait...' : (_passwordMode ? 'Sign In' : (_otpSent ? 'Verify OTP' : 'Send OTP'))),
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                            ),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: () => context.go('/register'),
                              child: const Text('New vendor? Register here'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _loading ? null : _demoLogin,
                              icon: const Icon(Icons.storefront_rounded),
                              label: const Text('Continue with dummy login'),
                              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
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
