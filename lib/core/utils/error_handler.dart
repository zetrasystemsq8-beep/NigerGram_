// lib/core/utils/error_handler.dart
import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class NigerGramError {
  // ============ GET MESSAGE (WITH EXCEPTION TYPES) ============
  static String getMessage(dynamic error) {
    // Log the error for debugging
    log('Error occurred: $error');
    debugPrint('Error: $error');

    // ============ FIREBASE AUTH EXCEPTIONS ============
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return '👤 No account found with this email.';
        case 'wrong-password':
          return '🔒 Incorrect password. Please try again.';
        case 'email-already-in-use':
          return '📧 This email is already registered.';
        case 'invalid-email':
          return '📧 Please enter a valid email address.';
        case 'too-many-requests':
          return '⏳ Too many attempts. Please try again later.';
        case 'weak-password':
          return '🔐 Password must be at least 6 characters.';
        case 'requires-recent-login':
          return '⏰ Please login again to continue.';
        case 'user-disabled':
          return '🚫 This account has been disabled.';
        case 'invalid-credential':
          return '❌ Invalid email or password.';
        case 'operation-not-allowed':
          return '⚠️ This sign in method is not available.';
        case 'credential-already-in-use':
          return '⚠️ This account is already linked to another user.';
        case 'network-request-failed':
          return '📡 Network issue. Please check your connection.';
        case 'timeout':
          return '⏰ Request timed out. Please try again.';
        default:
          return '⚠️ ${error.message ?? 'Authentication error occurred.'}';
      }
    }

    // ============ FIRESTORE EXCEPTIONS ============
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return '🔒 You do not have permission to perform this action.';
        case 'unavailable':
          return '☁️ Server temporarily unavailable. Please try again.';
        case 'not-found':
          return '📄 The requested data was not found.';
        case 'already-exists':
          return '📁 This document already exists.';
        case 'aborted':
          return '⏹️ Operation aborted. Please try again.';
        case 'deadline-exceeded':
          return '⏰ Request timed out. Please try again.';
        case 'cancelled':
          return '⏹️ Operation cancelled.';
        case 'failed-precondition':
          return '⚠️ Operation failed. Please try again.';
        case 'out-of-range':
          return '📄 Requested data is out of range.';
        case 'resource-exhausted':
          return '📊 Resource limit exceeded. Please try again later.';
        case 'unauthenticated':
          return '🔒 Please login to continue.';
        default:
          return '⚠️ ${error.message ?? 'Database error occurred.'}';
      }
    }

    // ============ FIREBASE STORAGE EXCEPTIONS ============
    if (error is FirebaseException && error.plugin == 'storage') {
      switch (error.code) {
        case 'storage/object-not-found':
          return '📁 File not found in storage.';
        case 'storage/unauthorized':
          return '🔒 You don\'t have permission to upload files.';
        case 'storage/canceled':
          return '⏹️ Upload was cancelled.';
        case 'storage/retry-limit-exceeded':
          return '🔄 Upload failed after multiple attempts. Please try again.';
        case 'storage/invalid-checksum':
          return '📁 File integrity check failed. Please try again.';
        case 'storage/invalid-argument':
          return '📁 Invalid file. Please check the file format.';
        case 'storage/quota-exceeded':
          return '📊 Storage limit exceeded. Please free up space.';
        case 'storage/unauthenticated':
          return '🔒 Please login to upload files.';
        default:
          return '📤 Upload failed. Please try again.';
      }
    }

    // ============ FALLBACK: CHECK ERROR STRING ============
    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket')) {
      return '📡 Network issue. Please check your connection and try again.';
    }

    // Timeout
    if (errorString.contains('timeout')) {
      return '⏰ Request timed out. Please try again.';
    }

    // Supabase errors
    if (errorString.contains('supabase')) {
      return '☁️ Content service unavailable. Please try again.';
    }

    // User cancelled
    if (errorString.contains('cancel') ||
        errorString.contains('cancelled') ||
        errorString.contains('abort')) {
      return '⏹️ Operation cancelled.';
    }

    // ============ DEFAULT ============
    return '⚠️ Something went wrong. Please try again.';
  }

  // ============ SNACKBAR HELPERS ============
  static void showSnackBar(
    BuildContext context,
    dynamic error, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;
    
    final message = getMessage(error);
    final color = backgroundColor ?? 
        (error.toString().toLowerCase().contains('network') 
            ? NGColors.warning 
            : NGColors.error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: duration,
      ),
    );
  }

  static void showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    
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
        duration: duration,
      ),
    );
  }

  static void showInfoSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ℹ️ $message',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: NGColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: duration,
      ),
    );
  }

  static void showWarningSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⚠️ $message',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: NGColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: duration,
      ),
    );
  }

  // ============ SHORTCUT METHODS ============
  static void showSuccess(BuildContext context, String message) {
    showSuccessSnackBar(context, message);
  }

  static void showInfo(BuildContext context, String message) {
    showInfoSnackBar(context, message);
  }

  static void showWarning(BuildContext context, String message) {
    showWarningSnackBar(context, message);
  }

  // ============ LOADING DIALOG ============
  static void showLoading(
    BuildContext context, {
    String text = 'Please wait...',
  }) {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: NGColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            const CircularProgressIndicator(
              color: NGColors.accent,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: NGColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void hideLoading(BuildContext context) {
    if (!context.mounted) return;
    
    // Safely pop only dialog routes
    Navigator.of(context, rootNavigator: true).popUntil((route) {
      return route is! PopupRoute;
    });
  }

  // ============ ERROR DIALOG ============
  static void showErrorDialog(
    BuildContext context,
    dynamic error, {
    String title = 'Error',
    bool barrierDismissible = true,
  }) {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AlertDialog(
        backgroundColor: NGColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: NGColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          getMessage(error),
          style: const TextStyle(
            color: NGColors.textSecondary,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                color: NGColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ SUCCESS DIALOG ============
  static void showSuccessDialog(
    BuildContext context,
    String message, {
    String title = 'Success',
    bool barrierDismissible = true,
  }) {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AlertDialog(
        backgroundColor: NGColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: NGColors.success,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: NGColors.textSecondary,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                color: NGColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ CONFIRMATION DIALOG ============
  static Future<bool?> showConfirmDialog(
    BuildContext context,
    String title,
    String message, {
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color confirmColor = NGColors.error,
    bool barrierDismissible = false,
  }) {
    if (!context.mounted) return Future.value(false);
    
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AlertDialog(
        backgroundColor: NGColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: NGColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: NGColors.textSecondary,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              cancelText,
              style: const TextStyle(
                color: NGColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: confirmColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
