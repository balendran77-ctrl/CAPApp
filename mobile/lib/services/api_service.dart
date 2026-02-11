import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://capapp-hzwm.onrender.com/api';
  static const String tokenKey = 'jwt_token';

  static String? _token;

  // Initialize token from storage
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(tokenKey);
  }

  // Set token when user logs in
  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  // Clear token on logout
  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
  }

  // Get auth headers
  static Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // USERS
  static Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/register'),
      headers: _getHeaders(),
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await setToken(data['token']);
      return data;
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Registration failed');
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/login'),
      headers: _getHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await setToken(data['token']);
      return data;
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Login failed');
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/profile'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch profile');
    }
  }

  static Future<void> updateProfile(Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/profile'),
      headers: _getHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update profile');
    }
  }

  // ITEMS
  static Future<Map<String, dynamic>> createItem(Map<String, dynamic> itemData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/items'),
      headers: _getHeaders(),
      body: jsonEncode(itemData),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to create item');
    }
  }

  static Future<List<dynamic>> getItems() async {
    final response = await http.get(
      Uri.parse('$baseUrl/items'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch items');
    }
  }

  static Future<Map<String, dynamic>> getItem(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/items/$id'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch item');
    }
  }

  static Future<void> updateItem(String id, Map<String, dynamic> itemData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/items/$id'),
        headers: _getHeaders(),
        body: jsonEncode(itemData),
      );

      if (response.statusCode == 200) {
        return;
      } else {
        // Parse error response
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['error'] ?? 'Failed to update item');
        } catch (e) {
          throw Exception('Failed to update item: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> deleteItem(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/items/$id'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete item');
    }
  }

  // Health check
  static Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
