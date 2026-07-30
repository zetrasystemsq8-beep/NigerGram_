// lib/features/auth/presentation/view/verification_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/app_auth.dart';
import 'package:nigergram/core/utils/constants/enums/router_enum.dart';
import 'package:nigergram/core/utils/error_handler.dart';
import 'package:nigergram/features/auth/presentation/bloc/auth_cubit.dart';

/// Premium email verification screen shown after a successful login when
/// the user's ZetraID account has not yet been verified.
class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  bool _isResending = false;
  bool _isRefreshing = false;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_isResending || _resendCooldown > 0) return;
    setState(() => _isResending = true);
    try {
      await context.read<AuthCubit>().resendVerificationEmail();
      if (mounted) {
        NigerGramError.showSuccess(context, 'Verification email sent');
        _startCooldown();
      }
    } catch (e) {
      if (mounted) NigerGramError.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 30);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown -= 1);
      return _resendCooldown > 0;
    });
  }

  Future<void> _refreshStatus() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await context.read<AuthCubit>().refreshVerificationStatus();
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            context.go(RouterEnum.dashboardView.routeName);
          }
          if (state is AuthError) {
            NigerGramError.showSnackBar(context, state.message);
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A0A0F),
                Color(0xFF1A1A2E),
                Color(0xFF0D0D1A),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                children: [
                  const Spacer(),

                  // Animated glowing envelope
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            NGColors.accent.withOpacity(0.35),
                            NGColors.accent.withOpacity(0.0),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: NGColors.surface,
                            border: Border.all(
                              color: NGColors.accent.withOpacity(0.6),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_rounded,
                            color: NGColors.accent,
                            size: 38,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [NGColors.accent, Colors.white, NGColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      'Verify Your Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    "We've sent a verification link to your ZetraMail. "
                    'Confirm it to unlock full access to NigerGram.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: NGColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (AppAuth.email.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Text(
                        '${AppAuth.displayHandle}@zetramail.ng',
                        style: const TextStyle(
                          color: NGColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Continue / Refresh button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isRefreshing ? null : _refreshStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NGColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        shadowColor: NGColors.accent.withOpacity(0.5),
                      ),
                      child: _isRefreshing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              "I've Verified — Continue",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Resend button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: (_isResending || _resendCooldown > 0) ? null : _resend,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isResending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: NGColors.textSecondary,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _resendCooldown > 0
                                  ? 'Resend in ${_resendCooldown}s'
                                  : 'Resend Verification Email',
                              style: const TextStyle(
                                color: NGColors.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: () async {
                      await context.read<AuthCubit>().logout();
                      if (context.mounted) context.go('/login');
                    },
                    child: const Text(
                      'Use a different account',
                      style: TextStyle(color: NGColors.textMuted, fontSize: 13),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: NGColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 12),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Secured by ZetraID',
                        style: TextStyle(
                          color: NGColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Zetra Production',
                    style: TextStyle(
                      color: NGColors.textMuted,
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
