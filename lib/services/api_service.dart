import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://demo.techequations.com/dover/api';
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  Future<http.Response> postSiteDetailsBatch(Map<String, dynamic> data, 
      {int maxRetries = 3}) async {
    final url = Uri.parse('$_baseUrl/sitedetailtable/batch');
    http.Response? lastResponse;
    Exception? lastException;

    for (int i = 0; i < maxRetries; i++) {
      try {
        final response = await http.post(
          url,
          headers: _headers,
          body: jsonEncode([data]),
        ).timeout(const Duration(seconds: 30));

        lastResponse = response;
        
          if (response == 200 ) {
    print('✅ Site detail submitted successfully!');
    print(response.body);
  } else {
    print('❌ Failed to submit site detail');
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
  }

        // Exponential backoff
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
        }
      } on TimeoutException catch (e) {
        lastException = e;
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
        }
      } on http.ClientException catch (e) {
        lastException = e;
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
        }
      } catch (e) {
        lastException = Exception('Unknown error: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
        }
      }
    }

    throw ApiException(
      lastException?.toString() ?? 'API request failed after $maxRetries attempts',
      lastResponse?.statusCode,
    );
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() {
    if (statusCode != null) {
      return 'ApiException: $message (Status: $statusCode)';
    }
    return 'ApiException: $message';
  }
}