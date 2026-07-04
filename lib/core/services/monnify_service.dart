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
      debugPrint('[Monnify Debug] Using cached auth token');
      return _token!;
    }

    final creds =
        '${AppConfig.monnifyApiKey}:${AppConfig.monnifySecretKey}';
    final encoded = base64Encode(utf8.encode(creds));

    final uri = Uri.parse('$_base/api/v1/auth/login');

    debugPrint('[Monnify Debug] ============ AUTHENTICATION START ============');
    debugPrint('[Monnify Debug] Auth Request URL: $uri');
    debugPrint('[Monnify Debug] Auth Request Headers: Authorization: Basic [REDACTED], Content-Type: application/json');

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Basic $encoded',
        'Content-Type': 'application/json',
      },
    );

    debugPrint('[Monnify Debug] Auth Status Code: ${res.statusCode}');
    debugPrint('[Monnify Debug] Auth Raw Response: ${res.body}');

    if (res.statusCode != 200) {
      debugPrint('[Monnify Debug] Auth FAILED - Status Code ${res.statusCode}');
      throw Exception(
          'Monnify auth failed: ${res.statusCode} ${res.body}');
    }

    final responseJson = jsonDecode(res.body) as Map<String, dynamic>;

    debugPrint('[Monnify Debug] Auth requestSuccessful: ${responseJson['requestSuccessful']}');
    debugPrint('[Monnify Debug] Auth responseMessage: ${responseJson['responseMessage']}');

    if (responseJson['requestSuccessful'] != true) {
      debugPrint('[Monnify Debug] Auth FAILED - requestSuccessful is false');
      throw Exception(
          'Monnify auth failed: ${responseJson['responseMessage'] ?? 'Unknown error'}');
    }

    final response =
        responseJson['responseBody'] as Map<String, dynamic>?;

    if (response == null) {
      debugPrint('[Monnify Debug] Auth FAILED - responseBody is null');
      throw Exception('Invalid auth response: ${res.body}');
    }

    final token = response['accessToken'] as String?;
    final expiry = response['expiresIn'] as int? ?? 3600;

    if (token == null) {
      debugPrint('[Monnify Debug] Auth FAILED - accessToken is null');
      throw Exception('Monnify auth token missing: ${res.body}');
    }

    _token = token;
    _tokenExpiry =
        DateTime.now().add(Duration(seconds: expiry - 60));

    debugPrint('[Monnify Debug] Auth SUCCESS - Token obtained, expires in: ${expiry}s');
    debugPrint('[Monnify Debug] ============ AUTHENTICATION END ============');

    return _token!;
  }

  Future<Map<String, dynamic>> initTransaction({
    required double amount,
    required String customerName,
    required String customerEmail,
  }) async {
    debugPrint('[Monnify Debug] ============ INIT TRANSACTION START ============');
    debugPrint('[Monnify Debug] Init Amount: $amount');
    debugPrint('[Monnify Debug] Init Customer: $customerName ($customerEmail)');

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

    debugPrint('[Monnify Debug] Init Request URL: $uri');
    debugPrint('[Monnify Debug] Init Request Body: ${jsonEncode(body)}');
    debugPrint('[Monnify Debug] Init ContractCode: ${AppConfig.monnifyContractCode}');
    debugPrint('[Monnify Debug] Init PaymentReference: $paymentReference');
    debugPrint('[Monnify Debug] Init Request Headers: Authorization: Bearer [REDACTED], Content-Type: application/json');

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    debugPrint('[Monnify Debug] Init Status Code: ${res.statusCode}');
    debugPrint('[Monnify Debug] Init Raw Response: ${res.body}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      debugPrint('[Monnify Debug] Init FAILED - Status Code ${res.statusCode}');
      throw Exception(
          'Monnify init transaction failed: ${res.statusCode} ${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;

    debugPrint('[Monnify Debug] Init requestSuccessful: ${json['requestSuccessful']}');
    debugPrint('[Monnify Debug] Init responseMessage: ${json['responseMessage']}');

    if (json['requestSuccessful'] != true) {
      debugPrint('[Monnify Debug] Init FAILED - requestSuccessful is false');
      throw Exception(
          'Transaction init failed: ${json['responseMessage'] ?? 'Unknown error'}');
    }

    final responseBody = json['responseBody'] as Map<String, dynamic>;

    debugPrint('[Monnify Debug] Init Response Body Keys: ${responseBody.keys.toList()}');
    debugPrint('[Monnify Debug] Init Full Response Body: ${jsonEncode(responseBody)}');
    debugPrint('[Monnify Debug] Init Checkout URL: ${responseBody['checkoutUrl']}');
    debugPrint('[Monnify Debug] Init TransactionReference: ${responseBody['transactionReference']}');

    // Return the payment reference along with checkout URL for tracking
    final result = {
      ...responseBody,
      'paymentReference': paymentReference, // Ensure this is in the response
    };

    debugPrint('[Monnify Debug] Init SUCCESS');
    debugPrint('[Monnify Debug] ============ INIT TRANSACTION END ============');

    return result;
  }

  /// Query transaction status - uses transactionReference from the response body
  /// According to Monnify API v2 documentation, the correct endpoint is /api/v2/merchant/transactions/query
  Future<Map<String, dynamic>> queryTransaction(
      String transactionReference) async {
    final token = await _auth();

    // Use v2 endpoint - this is the correct endpoint for querying transactions
    final uri = Uri.parse(
        '$_base/api/v2/merchant/transactions/query?transactionReference=$transactionReference');

    debugPrint('[Monnify Debug] ============ QUERY TRANSACTION START ============');
    debugPrint('[Monnify Debug] Query Request URL: $uri');
    debugPrint('[Monnify Debug] Query Request Headers: Authorization: Bearer [REDACTED], Content-Type: application/json');

    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    debugPrint('[Monnify Debug] Query Status Code: ${res.statusCode}');
    debugPrint('[Monnify Debug] Query Raw Response: ${res.body}');

    if (res.statusCode != 200) {
      debugPrint('[Monnify Debug] Query FAILED - Status Code ${res.statusCode}');
      throw Exception(
          'Monnify query failed: ${res.statusCode} ${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;

    debugPrint('[Monnify Debug] Query requestSuccessful: ${json['requestSuccessful']}');
    debugPrint('[Monnify Debug] Query responseMessage: ${json['responseMessage']}');

    if (json['requestSuccessful'] != true) {
      debugPrint('[Monnify Debug] Query FAILED - requestSuccessful is false');
      throw Exception(
          'Query failed: ${json['responseMessage'] ?? 'Unknown error'}');
    }

    final responseBody = json['responseBody'] as Map<String, dynamic>;

    debugPrint('[Monnify Debug] Query Response Body Keys: ${responseBody.keys.toList()}');
    debugPrint('[Monnify Debug] Query paymentStatus: ${responseBody['paymentStatus']}');
    debugPrint('[Monnify Debug] Query status: ${responseBody['status']}');
    debugPrint('[Monnify Debug] Query transactionReference: ${responseBody['transactionReference']}');
    debugPrint('[Monnify Debug] Query paymentReference: ${responseBody['paymentReference']}');
    debugPrint('[Monnify Debug] Query Full Response Body: ${jsonEncode(responseBody)}');
    debugPrint('[Monnify Debug] ============ QUERY TRANSACTION END ============');

    return responseBody;
  }
}
