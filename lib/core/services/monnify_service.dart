import 'dart:convert';

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

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Basic $encoded',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Monnify auth failed: ${res.statusCode}\n${res.body}',
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    final response =
        (body['responseBody'] ?? body['response']) as Map<String, dynamic>?;

    if (response == null) {
      throw Exception(
        'Monnify auth response is null.\nFull response:\n${res.body}',
      );
    }

    final token = response['accessToken'] as String?;
    final expiry = (response['expiresIn'] as num?)?.toInt() ?? 3600;

    if (token == null || token.isEmpty) {
      throw Exception(
        'Monnify access token missing.\nFull response:\n${res.body}',
      );
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

    final uri =
        Uri.parse('$_base/api/v1/merchant/transactions/init-transaction');

    final request = {
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
      body: jsonEncode(request),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(
        'Monnify init transaction failed: ${res.statusCode}\n${res.body}',
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    final response =
        (body['responseBody'] ?? body['response']) as Map<String, dynamic>?;

    if (response == null) {
      throw Exception(
        'Invalid Monnify initTransaction response.\n${res.body}',
      );
    }

    return response;
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

    if (res.statusCode != 200) {
      throw Exception(
        'Monnify query failed: ${res.statusCode}\n${res.body}',
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    final response =
        (body['responseBody'] ?? body['response']) as Map<String, dynamic>?;

    if (response == null) {
      throw Exception(
        'Invalid Monnify query response.\n${res.body}',
      );
    }

    return response;
  }
}
