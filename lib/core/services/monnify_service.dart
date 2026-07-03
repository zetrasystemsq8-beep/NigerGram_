import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nigergram/core/config/app_config.dart';

class MonnifyService {
  final String _base = AppConfig.monnifyBaseUrl;
  String? _token;
  DateTime? _tokenExpiry;

  Future<String> _auth() async {
    if (_token != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _token!;
    }

    // Basic Auth: format is secretKey:apiKey (NOT apiKey:secretKey)
    final creds = '${AppConfig.monnifySecretKey}:${AppConfig.monnifyApiKey}';
    final encoded = base64Encode(utf8.encode(creds));

    // Added explicit api/v1 context path mapping
    final uri = Uri.parse('$_base/api/v1/auth/login');
    
    if (kDebugMode) {
      debugPrint('🔐 Monnify Auth Request:');
      debugPrint('   URI: $uri');
      debugPrint('   Credentials (encoded): Basic $encoded');
      debugPrint('   Raw secret key: ${AppConfig.monnifySecretKey}');
      debugPrint('   Raw API key: ${AppConfig.monnifyApiKey}');
    }

    final res = await http.post(uri, headers: {
      'Authorization': 'Basic $encoded',
      'Content-Type': 'application/json',
    });

    if (kDebugMode) {
      debugPrint('🔐 Monnify Auth Response:');
      debugPrint('   Status Code: ${res.statusCode}');
      debugPrint('   Response Body: ${res.body}');
    }

    if (res.statusCode != 200) {
      throw Exception('Monnify auth failed: ${res.statusCode} ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final token = body['response']?['accessToken'] as String?;
    final expiry = body['response']?['expiresIn'] as int? ?? 3600;
    
    if (token == null) {
      final responseStr = jsonEncode(body);
      if (kDebugMode) {
        debugPrint('❌ Monnify auth token missing. Full response: $responseStr');
      }
      throw Exception('Monnify auth token missing. Response: $responseStr. Verify that monnifySecretKey and monnifyApiKey are correct and in the right order (secretKey:apiKey).');
    }

    _token = token;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiry - 60));
    
    if (kDebugMode) {
      debugPrint('✅ Monnify auth successful. Token expires in ${expiry - 60} seconds.');
    }
    
    return _token!;
  }

  Future<Map<String, dynamic>> initTransaction({required double amount, required String customerName, required String customerEmail}) async {
    final token = await _auth();
    // Added explicit api/v1 context path mapping
    final uri = Uri.parse('$_base/api/v1/merchant/transactions/init-transaction');
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

    if (kDebugMode) {
      debugPrint('💳 Monnify Init Transaction Request:');
      debugPrint('   URI: $uri');
      debugPrint('   Body: ${jsonEncode(body)}');
    }

    final res = await http.post(uri, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    }, body: jsonEncode(body));

    if (kDebugMode) {
      debugPrint('💳 Monnify Init Transaction Response:');
      debugPrint('   Status Code: ${res.statusCode}');
      debugPrint('   Response Body: ${res.body}');
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Monnify init transaction failed: ${res.statusCode} ${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['response'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> queryTransaction(String paymentReference) async {
    final token = await _auth();
    // Added explicit api/v1 context path mapping
    final uri = Uri.parse('$_base/api/v1/merchant/transactions/query?paymentReference=$paymentReference');
    
    if (kDebugMode) {
      debugPrint('🔍 Monnify Query Transaction Request:');
      debugPrint('   URI: $uri');
    }

    final res = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });

    if (kDebugMode) {
      debugPrint('🔍 Monnify Query Transaction Response:');
      debugPrint('   Status Code: ${res.statusCode}');
      debugPrint('   Response Body: ${res.body}');
    }

    if (res.statusCode != 200) {
      throw Exception('Monnify query failed: ${res.statusCode} ${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['response'] as Map<String, dynamic>;
  }
}
