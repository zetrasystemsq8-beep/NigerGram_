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
      debugPrint('[Monnify] Using cached auth token');
      return _token!;
    }

    final creds =
        '${AppConfig.monnifyApiKey}:${AppConfig.monnifySecretKey}';
    final encoded = base64Encode(utf8.encode(creds));

    final uri = Uri.parse('$_base/api/v1/auth/login');

    debugPrint('[Monnify Auth] Authenticating with endpoint: $uri');

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Basic $encoded',
        'Content-Type': 'application/json',
      },
    );

    debugPrint('[Monnify Auth] Status Code: ${res.statusCode}');
    debugPrint('[Monnify Auth] Response: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception(
          'Monnify auth failed: ${res.statusCode} ${res.body}');
    }

    final responseJson = jsonDecode(res.body) as Map<String, dynamic>;

    if (responseJson['requestSuccessful'] != true) {
      throw Exception(
          'Monnify auth failed: ${responseJson['responseMessage'] ?? 'Unknown error'}');
    }

    final response =
        responseJson['responseBody'] as Map<String, dynamic>?;

    if (response == null) {
      throw Exception('Invalid auth response: ${res.body}');
    }

    final token = response['accessToken'] as String?;
    final expiry = response['expiresIn'] as int? ?? 3600;

    if (token == null) {
      throw Exception('Monnify auth token missing: ${res.body}');
    }

    _token = token;
    _tokenExpiry =
        DateTime.now().add(Duration(seconds: expiry - 60));

    debugPrint('[Monnify Auth] Token obtained, expires in: ${expiry}s');

    return _token!;
  }

  Future<Map<String, dynamic>> initTransaction({
    required double amount,
    required String customerName,
    required String customerEmail,
  }) async {
    final token = await _auth();

    final uri =
        Uri.parse('$_base/api/v1/merchant/transactions/init-transaction');

    // Generate unique payment reference (required by Monnify)
    final paymentReference =
        'NGR-${DateTime.now().millisecondsSinceEpoch}-${(DateTime.now().microsecond % 1000).toString().padLeft(3, '0')}';

    final body = {
      'amount': amount,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'currencyCode': 'NGN',
      'contractCode': AppConfig.monnifyContractCode,
      'paymentDescription': 'NigerGram Wallet Funding',
      'paymentReference': paymentReference,
      // Use a proper callback URL - update this to your actual domain
      'redirectUrl': 'https://nigergram.app/payment-callback',
      'incomeSplitConfig': [],
    };

    debugPrint('[Monnify Init] URL: $uri');
    debugPrint('[Monnify Init] Request body: ${jsonEncode(body)}');

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    debugPrint('[Monnify Init] Status Code: ${res.statusCode}');
    debugPrint('[Monnify Init] Response: ${res.body}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(
          'Monnify init transaction failed: ${res.statusCode} ${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;

    if (json['requestSuccessful'] != true) {
      throw Exception(
          'Transaction init failed: ${json['responseMessage'] ?? 'Unknown error'}');
    }

    final responseBody = json['responseBody'] as Map<String, dynamic>;

    debugPrint('[Monnify Init] Checkout URL: ${responseBody['checkoutUrl']}');
    debugPrint('[Monnify Init] Payment Reference: $paymentReference');

    // Return the payment reference along with checkout URL for tracking
    return {
      ...responseBody,
      'paymentReference': paymentReference, // Ensure this is in the response
    };
  }

  /// Query transaction status - uses transactionReference from the response body
  /// According to Monnify API v2 documentation, the correct endpoint is /api/v2/merchant/transactions/query
  Future<Map<String, dynamic>> queryTransaction(
      String transactionReference) async {
    final token = await _auth();

    // FIXED: Use v2 endpoint instead of v1
    // The Monnify API v1 query endpoint does NOT exist; v2 is the correct endpoint
    final uri = Uri.parse(
        '$_base/api/v2/merchant/transactions/query?transactionReference=$transactionReference');

    debugPrint('[Monnify Query] URL: $uri');

    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    debugPrint('[Monnify Query] Status Code: ${res.statusCode}');
    debugPrint('[Monnify Query] Full Response: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception(
          'Monnify query failed: ${res.statusCode} ${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;

    debugPrint('[Monnify Query] requestSuccessful: ${json['requestSuccessful']}');

    if (json['requestSuccessful'] != true) {
      throw Exception(
          'Query failed: ${json['responseMessage'] ?? 'Unknown error'}');
    }

    final responseBody = json['responseBody'] as Map<String, dynamic>;

    debugPrint('[Monnify Query] Response body keys: ${responseBody.keys}');
    debugPrint('[Monnify Query] Transaction status field: ${responseBody['status']}');
    debugPrint('[Monnify Query] Payment status field: ${responseBody['paymentStatus']}');
    debugPrint('[Monnify Query] Full response body: ${jsonEncode(responseBody)}');

    return responseBody;
  }
}
