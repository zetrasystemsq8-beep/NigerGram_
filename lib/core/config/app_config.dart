import 'package:flutter/material.dart';

class AppConfig {
  /// Monnify Sandbox API Key (Revealed from your dashboard)
  static const String monnifyApiKey = String.fromEnvironment(
    'MONNIFY_API_KEY',
    defaultValue: 'YOUR_MONNIFY_API_KEY', // Swap this with your unhidden key for local device debugging
  );

  /// Monnify Sandbox Secret Key (Revealed from your dashboard)
  static const String monnifySecretKey = String.fromEnvironment(
    'MONNIFY_SECRET_KEY',
    defaultValue: 'YOUR_MONNIFY_SECRET_KEY', // Swap this with your unhidden key for local device debugging
  );

  /// Monnify Sandbox Contract Code from Screenshot_20260623-072959.png
  static const String monnifyContractCode = String.fromEnvironment(
    'MONNIFY_CONTRACT_CODE',
    defaultValue: '5081962263',
  );

  /// The official clean Base URL from your dashboard
  static const String monnifyBaseUrl = 'https://sandbox.monnify.com';
}
