import 'package:flutter/material.dart';

class AppConfig {
  /// Monnify Sandbox API Key (Injected via compilation flags)
  static const String monnifyApiKey = String.fromEnvironment(
    'MONNIFY_API_KEY',
    defaultValue: 'YOUR_MONNIFY_API_KEY', // Swap out for your raw unhidden key if building locally in Acode
  );

  /// Monnify Sandbox Secret Key (Injected via compilation flags)
  static const String monnifySecretKey = String.fromEnvironment(
    'MONNIFY_SECRET_KEY',
    defaultValue: 'YOUR_MONNIFY_SECRET_KEY', // Swap out for your raw unhidden key if building locally in Acode
  );

  /// Monnify Sandbox Contract Code from Developer Dashboard
  static const String monnifyContractCode = String.fromEnvironment(
    'MONNIFY_CONTRACT_CODE',
    defaultValue: '5081962263',
  );

  /// Correct Sandbox Base API URL endpoint path
  static const String monnifyBaseUrl = 'https://sandbox.monnify.com/api/v1';
}
