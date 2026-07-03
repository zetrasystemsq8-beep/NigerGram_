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

    final res = await http.post(
      Uri.parse('$_base/api/v1/auth/login'),
      headers: {
        'Authorization': 'Basic $encoded',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Monnify auth failed (${res.statusCode}): ${res.body}',
      );
    }

    final body = jsonDecode(res.body);

    if (body['requestSuccessful'] != true) {
      throw Exception(body['responseMessage'] ?? 'Authentication failed');
    }

    final response = body['responseBody'];

    _token = response['accessToken'];
    _tokenExpiry = DateTime.now().add(
      Duration(seconds: response['expiresIn'] ?? 3600),
    );

    return _token!;
  }

  Future<Map<String, dynamic>> initTransaction({
    required double amount,
    required String customerName,
    required String customerEmail,
  }) async {
    final token = await _auth();

    final paymentReference =
        'NIGERGRAM-${DateTime.now().millisecondsSinceEpoch}';

    final payload = {
      "amount": amount,
      "customerName": customerName,
      "customerEmail": customerEmail,
      "paymentReference": paymentReference,
      "paymentDescription": "NigerGram Wallet Funding",
      "currencyCode": "NGN",
      "contractCode": AppConfig.monnifyContractCode,
      "redirectUrl": "https://example.com"
    };

    final res = await http.post(
      Uri.parse(
        '$_base/api/v1/merchant/transactions/init-transaction',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    print("Monnify Init Status: ${res.statusCode}");
    print("Monnify Init Body: ${res.body}");

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(
        'Monnify init failed (${res.statusCode}): ${res.body}',
      );
    }

    final body = jsonDecode(res.body);

    if (body['requestSuccessful'] != true) {
      throw Exception(body['responseMessage'] ?? 'Transaction failed');
    }

    return body['responseBody'];
  }

  Future<Map<String, dynamic>> queryTransaction(
      String paymentReference) async {
    final token = await _auth();

    final res = await http.get(
      Uri.parse(
        '$_base/api/v1/merchant/transactions/query?paymentReference=$paymentReference',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Query failed (${res.statusCode}): ${res.body}',
      );
    }

    final body = jsonDecode(res.body);

    if (body['requestSuccessful'] != true) {
      throw Exception(body['responseMessage'] ?? 'Query failed');
    }

    return body['responseBody'];
  }
}
