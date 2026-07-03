import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nigergram/core/config/app_config.dart';

class MonnifyService {
  final String _base = AppConfig.monnifyBaseUrl;
  String? _token;
  DateTime? _tokenExpiry;

  Future<String> _auth() async {
    if (_token != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _token!;
    }

    final creds =
        '${AppConfig.monnifyApiKey}:${AppConfig.monnifySecretKey}';
    final encoded = base64Encode(utf8.encode(creds));

    final uri = Uri.parse('$_base/api/v1/auth/login');

    if (kDebugMode) {
      debugPrint('================ MONNIFY AUTH ================');
      debugPrint('POST $uri');
      debugPrint(
          'API Key: ${AppConfig.monnifyApiKey.substring(0, 6)}...');
      debugPrint(
          'Secret Key: ${AppConfig.monnifySecretKey.substring(0, 6)}...');
    }

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Basic $encoded',
        'Content-Type': 'application/json',
      },
    );

    if (kDebugMode) {
      debugPrint('Status Code: ${res.statusCode}');
      debugPrint('Response Body: ${res.body}');
      debugPrint('==============================================');
    }

    if (res.statusCode != 200) {
      throw Exception(
          'Monnify auth failed: ${res.statusCode}\n${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    final response = body['response'];

    if (response == null) {
      throw Exception(
          'Monnify auth response is null.\nFull response:\n${res.body}');
    }

    final token = response['accessToken'] as String?;
    final expiry = response['expiresIn'] as int? ?? 3600;

    if (token == null || token.isEmpty) {
      throw Exception(
          'Monnify auth token missing.\nFull response:\n${res.body}');
    }

    _token = token;
    _tokenExpiry = DateTime.now().add(
      Duration(seconds: expiry - 60),
    );

    return _token!;
  }

  Future<Map<String, dynamic>> initTransaction({
    required double amount,
    required String customerName,
    required String customerEmail,
  }) async {
    final token = await _auth();

    final uri = Uri.parse(
      '$_base/api/v1/merchant/transactions/init-transaction',
    );

    final body = {
      'amount': amount,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'currency': 'NGN',
      'contractCode': AppConfig.monnifyContractCode,
      'paymentDescription': 'NigerGram Wallet Funding',
      'merchantLogoUrl': '',
      'merchantName': 'NigerGram',
    };

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (kDebugMode) {
      debugPrint('========== INIT TRANSACTION ==========');
      debugPrint('Status Code: ${res.statusCode}');
      debugPrint('Response: ${res.body}');
      debugPrint('======================================');
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(
          'Monnify init transaction failed: ${res.statusCode}\n${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['response'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> queryTransaction(
      String paymentReference) async {
    final token = await _auth();

    final uri = Uri.parse(
      '$_base/api/v1/merchant/transactions/query?paymentReference=$paymentReference',
    );

    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (kDebugMode) {
      debugPrint('========== QUERY TRANSACTION ==========');
      debugPrint('Status Code: ${res.statusCode}');
      debugPrint('Response: ${res.body}');
      debugPrint('=======================================');
    }

    if (res.statusCode != 200) {
      throw Exception(
          'Monnify query failed: ${res.statusCode}\n${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['response'] as Map<String, dynamic>;
  }
}
