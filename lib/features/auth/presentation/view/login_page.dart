import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nigergram/core/design_system/colors.dart'; // Using the black constant defined here
import 'package:nigergram/core/utils/constants/enums/router_enum.dart';
import 'package:nigergram/features/auth/presentation/bloc/auth_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Immersive pure dark mode
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            // Instantly transition directly to the main video feed dashboard
            context.go(RouterEnum.dashboardView.routeName);
          }
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                content: Text(
                  state.message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            );
          }
        },
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
                      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          
                          // Brand Identity Section
                          Column(
                            children: [
                              Text(
                                'NigerGram',
                                style: TextStyle(
                                  fontFamily: 'PlatformFont', // Fallback to system font if custom font isn't configured
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 10.0,
                                      color: Colors.red.withOpacity(0.3),
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'The Heartbeat of Naija Content',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),

                          // Interactive Form Fields Section
                          Column(
                            children: [
                              // Email Container Field
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.shade800, width: 1),
                                ),
                                child: TextField(
                                  controller: _emailController,
                                  style: const TextStyle(color: Colors.white, fontSize: 15),
                                  keyboardType: TextInputType.emailAddress,
                                  cursorColor: Colors.white,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                    hintText: 'Email address',
                                    hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                                    border: InputBorder.none,
                                    prefixIcon: Icon(Icons.mail_outline, color: Colors.grey, size: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Password Container Field
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.shade800, width: 1),
                                ),
                                child: TextField(
                                  controller: _passwordController,
                                  style: const TextStyle(color: Colors.white, fontSize: 15),
                                  obscureText: !_isPasswordVisible,
                                  cursorColor: Colors.white,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                    hintText: 'Password',
                                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
                                    border: InputBorder.none,
                                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                        color: Colors.grey,
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
                              const SizedBox(height: 32),

                              // Premium High-Contrast Authentic Action Trigger
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: state is AuthLoading
                                      ? null
                                      : () {
                                          if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
                                            context.read<AuthCubit>().login(
                                                  _emailController.text.trim(),
                                                  _passwordController.text.trim(),
                                                );
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Please fill in all details')),
                                            );
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white, // High impact clean contrast matching TikTok design guide
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: state is AuthLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.black,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text(
                                          'Log In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),

                          // Clean System Gateway Toggle
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account?",
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // Removed old Navigator state mixin to maintain strict engineering architectural alignment.
                                    // This can switch to a state variable toggle in a unified layout, or a strict router branch call.
                                    context.push('/register'); 
                                  },
                                  child: const Text(
                                    "Sign Up",
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
    );
  }
}
