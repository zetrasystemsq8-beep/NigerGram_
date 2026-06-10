import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nigergram/core/utils/constants/enums/router_enum.dart';
import 'package:nigergram/features/auth/presentation/bloc/auth_cubit.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register(BuildContext context) async {
    if (_usernameController.text.trim().isEmpty) {
      _showError(context, 'Please enter a username');
      return;
    }
    if (_usernameController.text.trim().length < 3) {
      _showError(context, 'Username must be at least 3 characters');
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      _showError(context, 'Please enter your email');
      return;
    }
    if (_passwordController.text.length < 6) {
      _showError(context, 'Password must be at least 6 characters');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError(context, 'Passwords do not match');
      return;
    }
    if (!_agreedToTerms) {
      _showError(context, 'Please agree to the terms to continue');
      return;
    }
    context.read<AuthCubit>().register(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) async {
          if (state is AuthSuccess) {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .set({
                'uid': user.uid,
                'username': _usernameController.text.trim(),
                'email': user.email,
                'followers': 0,
                'following': 0,
                'bio': 'Naija Creator 🇳🇬',
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
            if (context.mounted) {
              context.go(RouterEnum.dashboardView.routeName);
            }
          }
          if (state is AuthError) {
            _showError(context, state.message);
          }
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            return SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28.0, vertical: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),

                            // Back button
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.arrow_back,
                                    color: Colors.white, size: 20),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Header
                            const Text(
                              'Create Account',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Join millions of Naija creators 🇳🇬',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 15,
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Username field
                            _buildLabel('Username'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _usernameController,
                              hint: 'naija_creator',
                              prefix: const Text('@',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              prefixIcon: null,
                            ),

                            const SizedBox(height: 20),

                            // Email field
                            _buildLabel('Email'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _emailController,
                              hint: 'your@email.com',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: const Icon(Icons.mail_outline,
                                  color: Colors.grey, size: 20),
                            ),

                            const SizedBox(height: 20),

                            // Password field
                            _buildLabel('Password'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _passwordController,
                              hint: 'Min 6 characters',
                              obscure: !_isPasswordVisible,
                              prefixIcon: const Icon(Icons.lock_outline,
                                  color: Colors.grey, size: 20),
                              suffix: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                    () => _isPasswordVisible =
                                        !_isPasswordVisible),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Confirm Password field
                            _buildLabel('Confirm Password'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _confirmPasswordController,
                              hint: 'Repeat password',
                              obscure: !_isConfirmPasswordVisible,
                              prefixIcon: const Icon(Icons.lock_outline,
                                  color: Colors.grey, size: 20),
                              suffix: IconButton(
                                icon: Icon(
                                  _isConfirmPasswordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                    () => _isConfirmPasswordVisible =
                                        !_isConfirmPasswordVisible),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Terms checkbox
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(
                                      () => _agreedToTerms = !_agreedToTerms),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: _agreedToTerms
                                          ? Colors.red
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _agreedToTerms
                                            ? Colors.red
                                            : Colors.grey,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: _agreedToTerms
                                        ? const Icon(Icons.check,
                                            color: Colors.white, size: 14)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'I agree to NigerGram Terms of Service and Privacy Policy',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Create Account button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: state is AuthLoading
                                    ? null
                                    : () => _register(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  disabledBackgroundColor:
                                      Colors.grey.shade800,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: state is AuthLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Join NigerGram 🇳🇬',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Login link
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Already have an account?',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14),
                                  ),
                                  TextButton(
                                    onPressed: () => context.pop(),
                                    child: const Text(
                                      'Log In',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? prefixIcon,
    Widget? prefix,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade800, width: 1),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        keyboardType: keyboardType,
        obscureText: obscure,
        cursorColor: Colors.white,
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
          border: InputBorder.none,
          prefixIcon: prefixIcon,
          prefix: prefix,
          suffixIcon: suffix,
        ),
      ),
    );
  }
}
