// lib/features/auth/presentation/view/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/error_handler.dart';
import 'package:nigergram/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:nigergram/features/auth/presentation/view/terms_view.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
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

  late AnimationController _splashAnimController;
  late Animation<double> _splashFadeAnim;
  late Animation<double> _splashScaleAnim;

  late AnimationController _formAnimController;
  late Animation<double> _formFadeAnim;
  late Animation<Offset> _formSlideAnim;

  double _passwordStrength = 0;
  String _passwordStrengthLabel = '';
  Color _passwordStrengthColor = NGColors.divider;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _currentTab = _tabController.index);
    });

    _splashAnimController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _splashFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _splashAnimController, curve: Curves.easeOut),
    );
    _splashScaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _splashAnimController, curve: Curves.easeOutBack),
    );
    _splashAnimController.forward();

    _formAnimController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _formFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _formAnimController, curve: Curves.easeOut),
    );
    _formSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _formAnimController, curve: Curves.easeOut),
    );

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _showSplash = false);
        _formAnimController.forward();
      }
    });

    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _tabController.dispose();
    _splashAnimController.dispose();
    _formAnimController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final p = _passwordController.text;
    double strength = 0;
    if (p.length >= 6) strength += 0.25;
    if (p.length >= 10) strength += 0.25;
    if (p.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (p.contains(RegExp(r'[0-9!@#\$%^&*]'))) strength += 0.25;

    String label;
    Color color;
    if (p.isEmpty) {
      label = '';
      color = NGColors.divider;
    } else if (strength <= 0.25) {
      label = 'Weak';
      color = NGColors.error;
    } else if (strength <= 0.5) {
      label = 'Fair';
      color = NGColors.warning;
    } else if (strength <= 0.75) {
      label = 'Good';
      color = const Color(0xFF00BCD4);
    } else {
      label = 'Strong';
      color = NGColors.success;
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthLabel = label;
      _passwordStrengthColor = color;
    });
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
              color: NGColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: NGColors.accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    size: 30,
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
                const SizedBox(height: 6),
                const Text(
                  "Enter your email and we'll send a reset link.",
                  style: TextStyle(color: NGColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildField(
                  controller: emailController,
                  hint: 'Email address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final email = emailController.text.trim();
                            if (email.isEmpty) {
                              NigerGramError.showSnackBar(
                                  ctx, 'Please enter your email');
                              return;
                            }
                            setSheet(() => isLoading = true);
                            try {
                              await FirebaseAuth.instance
                                  .sendPasswordResetEmail(email: email);
                              Navigator.pop(ctx);
                              NigerGramError.showSuccess(
                                  ctx, 'Reset link sent to $email');
                            } catch (e) {
                              setSheet(() => isLoading = false);
                              NigerGramError.showSnackBar(ctx, e);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NGColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Send Reset Link',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
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
      if (mounted) context.go('/dashboard');
    } catch (e) {
      NigerGramError.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSignUp() async {
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
      NigerGramError.showSnackBar(
          context, 'Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
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

      if (mounted) context.go('/dashboard');
    } catch (e) {
      NigerGramError.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: NGColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NGColors.divider, width: 1),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          color: NGColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        keyboardType: keyboardType,
        obscureText: obscure,
        cursorColor: NGColors.accent,
        maxLines: maxLines,
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintText: hint,
          hintStyle: const TextStyle(color: NGColors.textMuted, fontSize: 14),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: NGColors.textMuted, size: 20),
          suffixIcon: suffix,
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthBar() {
    if (_passwordController.text.isEmpty || _currentTab == 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _passwordStrength,
              backgroundColor: NGColors.divider,
              valueColor:
                  AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _passwordStrengthLabel,
            style: TextStyle(
              color: _passwordStrengthColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplash() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _splashFadeAnim,
        child: ScaleTransition(
          scale: _splashScaleAnim,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🇳🇬', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      NGColors.accent,
                      Color(0xFFFF6B6B),
                      NGColors.accent
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(bounds),
                  child: const Text(
                    'NIGERGRAM',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The Heartbeat of Naija Content',
                  style: TextStyle(
                    color: NGColors.textMuted,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: NGColors.accent,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(height: 48),
                const Text(
                  'POWERED BY ZETRA',
                  style: TextStyle(
                    color: NGColors.textMuted,
                    fontSize: 10,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return _buildSplash();

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) context.go('/dashboard');
          if (state is AuthError) {
            NigerGramError.showSnackBar(context, state.message);
          }
        },
        child: FadeTransition(
          opacity: _formFadeAnim,
          child: SlideTransition(
            position: _formSlideAnim,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 28),
                        const Text('🇳🇬', style: TextStyle(fontSize: 44)),
                        const SizedBox(height: 10),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              NGColors.accent,
                              Color(0xFFFF6B6B),
                              NGColors.accent
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(bounds),
                          child: const Text(
                            'NIGERGRAM',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'The Heartbeat of Naija Content',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: NGColors.textMuted,
                            fontSize: 11,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: NGColors.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: NGColors.accent.withOpacity(0.25),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('⚡', style: TextStyle(fontSize: 10)),
                              SizedBox(width: 5),
                              Text(
                                'ZETRA · NIGERGRAM',
                                style: TextStyle(
                                  color: NGColors.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: NGColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: NGColors.divider, width: 1),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: NGColors.accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            dividerColor: Colors.transparent,
                            labelColor: Colors.white,
                            unselectedLabelColor: NGColors.textMuted,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.3,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            tabs: const [
                              Tab(text: 'Log In'),
                              Tab(text: 'Sign Up'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _currentTab == 0
                                ? 'Welcome back 👋'
                                : 'Join NigerGram 🚀',
                            style: const TextStyle(
                              color: NGColors.textPrimary,
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _currentTab == 0
                                ? 'Sign in to continue'
                                : 'Create your account in seconds',
                            style: const TextStyle(
                              color: NGColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildField(
                          controller: _emailController,
                          hint: 'Email address',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: _passwordController,
                          hint: 'Password',
                          icon: Icons.lock_outline,
                          obscure: !_isPasswordVisible,
                          suffix: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: NGColors.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(() =>
                                _isPasswordVisible = !_isPasswordVisible),
                          ),
                        ),
                        _buildPasswordStrengthBar(),
                        if (_currentTab == 1) ...[
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _usernameController,
                            hint: 'Username',
                            icon: Icons.alternate_email_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _bioController,
                            hint: 'Bio (optional)',
                            icon: Icons.edit_note_rounded,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() =>
                                    _termsAccepted = !_termsAccepted),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  width: 22,
                                  height: 22,
                                  margin: const EdgeInsets.only(top: 1),
                                  decoration: BoxDecoration(
                                    color: _termsAccepted
                                        ? NGColors.accent
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _termsAccepted
                                          ? NGColors.accent
                                          : NGColors.divider,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: _termsAccepted
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 14)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      color: NGColors.textSecondary,
                                      fontSize: 12.5,
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
                                                builder: (context) =>
                                                    const TermsView(
                                                        type: 'terms'),
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
                                                builder: (context) =>
                                                    const TermsView(
                                                        type: 'privacy'),
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
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    if (_currentTab == 0) {
                                      _handleLogin();
                                    } else {
                                      _handleSignUp();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: NGColors.accent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  NGColors.accent.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    _currentTab == 0
                                        ? 'Log In'
                                        : 'Create Account',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_currentTab == 0)
                          GestureDetector(
                            onTap: _showForgotPasswordSheet,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: NGColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                  decorationColor: NGColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 28),
                        const Text(
                          'ZETRA ⚡ NIGERGRAM',
                          style: TextStyle(
                            color: NGColors.textMuted,
                            fontSize: 10,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
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
