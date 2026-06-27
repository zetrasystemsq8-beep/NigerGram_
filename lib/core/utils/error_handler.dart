// lib/core/utils/error_handler.dart
import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';

class NigerGramError {
  static String getMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Network errors
    if (errorString.contains('network') || 
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket')) {
      return '📡 Network issue. Please check your connection and try again.';
    }
    
    // Firebase Auth errors - User friendly
    if (errorString.contains('user-not-found')) {
      return '👤 No account found with this email.';
    }
    if (errorString.contains('wrong-password')) {
      return '🔒 Incorrect password. Please try again.';
    }
    if (errorString.contains('email-already-in-use')) {
      return '📧 This email is already registered.';
    }
    if (errorString.contains('invalid-email')) {
      return '📧 Please enter a valid email address.';
    }
    if (errorString.contains('too-many-requests')) {
      return '⏳ Too many attempts. Please try again later.';
    }
    if (errorString.contains('weak-password')) {
      return '🔐 Password must be at least 6 characters.';
    }
    if (errorString.contains('requires-recent-login')) {
      return '⏰ Please login again to continue.';
    }
    
    // Supabase errors
    if (errorString.contains('supabase')) {
      return '☁️ Content service unavailable. Please try again.';
    }
    
    // Default
    return '⚠️ Something went wrong. Please try again.';
  }
  
  static void showSnackBar(BuildContext context, dynamic error) {
    final message = getMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: error.toString().toLowerCase().contains('network') 
            ? Colors.orange 
            : NGColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
  
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ $message',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: NGColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
