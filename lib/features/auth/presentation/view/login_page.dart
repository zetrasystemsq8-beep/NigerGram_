// lib/features/auth/presentation/view/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/constants/enums/router_enum.dart';
import 'package:nigergram/core/utils/error_handler.dart';
import 'package:nigergram/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:nigergram/features/auth/presentation/view/terms_view.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _showSplash = true;
  bool _termsAccepted = false;
  
  late TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTab = _tabController.index;
      });
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _showForgotPasswordSheet() {
    final TextEditingController emailController = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Container(
            height: 420,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: NGColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NGColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NGColors.accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    size: 32,
                    color: NGColors.accent,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reset Password',
                  style: TextStyle(
                    color: NGColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your email and we\'ll send you a link to reset your password.',
                  style: TextStyle(
                    color: NGColors.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: NGColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    hintStyle: TextStyle(color: NGColors.textMuted),
                    prefixIcon: const Icon(Icons.email_outlined, color: NGColors.textMuted),
                    filled: true,
                    fillColor: NGColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty) {
                        NigerGramError.showSnackBar(ctx, 'Please enter your email');
                        return;
                      }
                      setSheet(() => isLoading = true);
                      try {
                        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                        Navigator.pop(ctx);
                        NigerGramError.showSuccess(ctx, 'Password reset link sent to $email');
                      } catch (e) {
                        setSheet(() => isLoading = false);
                        NigerGramError.showSnackBar(ctx, e);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NGColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Send Reset Link',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      NigerGramError.showSnackBar(context, 'Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (mounted) {
        context.go(RouterEnum.dashboardView.routeName);
      }
    } catch (e) {
      NigerGramError.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSignUp() async {
    // 🔥 Check if terms are accepted
    if (!_termsAccepted) {
      NigerGramError.showSnackBar(context, 'Please agree to Terms & Conditions');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();

    if (email.isEmpty || password.isEmpty || username.isEmpty) {
      NigerGramError.showSnackBar(context, 'Please fill in all required fields');
      return;
    }

    if (password.length < 6) {
      NigerGramError.showSnackBar(context, 'Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'displayName': username,
        'username': username,
        'email': email,
        'bio': bio,
        'profilePicUrl': '',
        'coverUrl': '',
        'videoCount': 0,
        'followers': 0,
        'following': 0,
        'likes': 0,
        'profileViews': 0,
        'profileTheme': 'default',
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        context.go(RouterEnum.dashboardView.routeName);
      }
    } catch (e) {
      NigerGramError.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return Scaffold(
        backgroundColor: NGColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [NGColors.accent, Colors.white, NGColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Text(
                  '🇳🇬',
                  style: TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [NGColors.accent, Colors.white, NGColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Text(
                  'NIGERGRAM',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 60,
                height: 3,
                decoration: BoxDecoration(
                  color: NGColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'The Heartbeat of Naija Content',
                style: TextStyle(
                  color: NGColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 30),
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: NGColors.accent,
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // Logo
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [NGColors.accent, Colors.white, NGColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    '🇳🇬 NIGERGRAM',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'The Heartbeat of Naija Content',
                  style: TextStyle(
                    color: NGColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),

                // Tabs
                Container(
                  decoration: BoxDecoration(
                    color: NGColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: NGColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: NGColors.textMuted,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Log In'),
                      Tab(text: 'Sign Up'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Form
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Email
                        Container(
                          decoration: BoxDecoration(
                            color: NGColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _emailController,
                            style: const TextStyle(color: NGColors.textPrimary, fontSize: 15),
                            keyboardType: TextInputType.emailAddress,
                            cursorColor: NGColors.accent,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              hintText: 'Email',
                              hintStyle: TextStyle(color: NGColors.textMuted, fontSize: 14),
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.email_outlined, color: NGColors.textMuted, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Password
                        Container(
                          decoration: BoxDecoration(
                            color: NGColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _passwordController,
                            style: const TextStyle(color: NGColors.textPrimary, fontSize: 15),
                            obscureText: !_isPasswordVisible,
                            cursorColor: NGColors.accent,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              hintText: 'Password',
                              hintStyle: const TextStyle(color: NGColors.textMuted, fontSize: 14),
                              border: InputBorder.none,
                              prefixIcon: const Icon(Icons.lock_outline, color: NGColors.textMuted, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                  color: NGColors.textMuted,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),

                        // Sign Up only fields
                        if (_currentTab == 1) ...[
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: NGColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _usernameController,
                              style: const TextStyle(color: NGColors.textPrimary, fontSize: 15),
                              cursorColor: NGColors.accent,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                hintText: 'Username',
                                hintStyle: TextStyle(color: NGColors.textMuted, fontSize: 14),
                                border: InputBorder.none,
                                prefixIcon: Icon(Icons.person_outline, color: NGColors.textMuted, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: NGColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _bioController,
                              style: const TextStyle(color: NGColors.textPrimary, fontSize: 15),
                              cursorColor: NGColors.accent,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                hintText: 'Bio (optional)',
                                hintStyle: TextStyle(color: NGColors.textMuted, fontSize: 14),
                                border: InputBorder.none,
                                prefixIcon: Icon(Icons.edit_note, color: NGColors.textMuted, size: 20),
                              ),
                            ),
                          ),
                          
                          // 🔥 Terms Checkbox
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _termsAccepted,
                                  onChanged: (value) {
                                    setState(() {
                                      _termsAccepted = value ?? false;
                                    });
                                  },
                                  activeColor: NGColors.accent,
                                  checkColor: Colors.white,
                                  side: const BorderSide(color: NGColors.divider),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: NGColors.textSecondary,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                    children: [
                                      const TextSpan(text: 'I agree to the '),
                                      TextSpan(
                                        text: 'Terms & Conditions',
                                        style: const TextStyle(
                                          color: NGColors.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const TermsView(type: 'terms'),
                                              ),
                                            );
                                          },
                                      ),
                                      const TextSpan(text: ' and '),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        style: const TextStyle(
                                          color: NGColors.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const TermsView(type: 'privacy'),
                                              ),
                                            );
                                          },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Login / Sign Up Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () {
                              if (_currentTab == 0) {
                                _handleLogin();
                              } else {
                                _handleSignUp();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: NGColors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    _currentTab == 0 ? 'Log In' : 'Create Account',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Forgot Password (only in Login tab)
                        if (_currentTab == 0)
                          GestureDetector(
                            onTap: _showForgotPasswordSheet,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: NGColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
