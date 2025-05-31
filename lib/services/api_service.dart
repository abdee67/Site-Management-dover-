import 'dart:async';
import 'dart:convert';
import 'package:dover/db/siteDetailDatabase.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'https://a70e-196-188-162-10.ngrok-free.app/dover/api';
  final Sitedetaildatabase db = Sitedetaildatabase.instance;
  
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // Authentication Method (returns userId and addresses)
  Future<Map<String, dynamic>> authenticateUser(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 600));

      debugPrint('Login Response Code: ${response.statusCode}');
      debugPrint('Login Response: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final message = jsonData['message'] as String?;
        final userId = jsonData['userId'] as String?;
        
        
        debugPrint('Message: $message, UserId: $userId');
        
        // Process addresses array
        final List<dynamic> addresses = jsonData['addresses'] ?? [];
        final parsedAddresses = <Map<String, dynamic>>[];
        
        for (final address in addresses) {
          parsedAddresses.add({
            'id': address['id'],
            'companyName': address['companyName'],
            'country': address['country'],
          });
          debugPrint('id: ${address['id']}, Company: ${address['companyName']}, Country: ${address['country']}');
        }
        // Store credentials securely for future logins
        await _storeCredentials(username, password,userId);
        
        return {
          'success': true,
          'userId': userId,
          'addresses': parsedAddresses,
        };
      }
      
      return {
        'success': false,
        'error': 'Login failed with status ${response.statusCode}'
      };
    } catch (e) {
      debugPrint('API authentication failed: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }
    // Store credentials securely
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> _storeCredentials(String username, String password, String? userId) async {
    await _secureStorage.write(key: 'api_username', value: username);
    await _secureStorage.write(key: 'api_password', value: password);
     if (userId != null) {
    await _secureStorage.write(key: 'api_user_id', value: userId);
  }
  }

    // Retrieve stored credentials
Future<Map<String, String>?> getStoredCredentials() async {
  final username = await _secureStorage.read(key: 'api_username');
  final password = await _secureStorage.read(key: 'api_password');
  final userId = await _secureStorage.read(key: 'api_user_id');
  
  if (username != null && password != null) {
    return {
      'username': username, 
      'password': password,
      'userId': userId ?? 'offline_user' // Return empty string if userId is null
    };
  }
  return null;
}

  Future<Map<String, dynamic>> getUserProfile() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/user/profile'),
      headers: _headers,
      
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw ApiException('Failed to fetch profile', response.statusCode);
  } catch (e) {
    debugPrint('Error fetching user profile: $e');
    rethrow;
  }
}

  Future<bool> checkSiteExists(String siteId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sitedetailtable/check?siteId=$siteId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['exists'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Site existence check failed: $e');
      return false;
    }
  }

  Future<http.Response> postSiteDetailsBatch(
    Map<String, dynamic> data, {
    int maxRetries = 3,
  }) async {
    final url = Uri.parse('$baseUrl/sitedetailtable/batch');
    http.Response? lastResponse;
    Exception? lastException;

    for (int i = 0; i < maxRetries; i++) {
      try {
        final response = await http.post(
          url,
          headers: _headers,
          body: jsonEncode([data]),
        ).timeout(const Duration(seconds: 50));

        lastResponse = response;
        
        if (response.statusCode == 200) {
          debugPrint('✅ Site detail submitted successfully!');
          return response;
        } else {
          debugPrint('❌ Failed to submit site detail');
          debugPrint('Status: ${response.statusCode}');
          debugPrint('Body: ${response.body}');
          lastException = ApiException('API returned ${response.statusCode}', response.statusCode);
        }

        // Exponential backoff
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(seconds: _calculateDelay(i)));
        }
      } on TimeoutException catch (e) {
        lastException = e;
        debugPrint('⏱️ Timeout occurred: ${e.message}');
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(seconds: _calculateDelay(i)));
        }
      } on http.ClientException catch (e) {
        lastException = e;
        debugPrint('🌐 Network error occurred: ${e.message}');
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(seconds: _calculateDelay(i)));
        }
      } catch (e) {
        lastException = Exception('Unknown error: $e');
        debugPrint('❌ Unexpected error: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(seconds: _calculateDelay(i)));
        }
      }
    }

    if (lastResponse != null) return lastResponse;
    throw lastException ?? ApiException('API request failed after $maxRetries attempts');
  }
  // Helper method to calculate exponential backoff delay
  static int _calculateDelay(int attempt) => 2 * (attempt + 1);
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => statusCode != null
      ? 'ApiException: $message (Status: $statusCode)'
      : 'ApiException: $message';
}