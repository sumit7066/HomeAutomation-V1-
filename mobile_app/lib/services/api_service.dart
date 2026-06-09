import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String defaultServerUrl = 'http://192.168.29.254:3000';
  
  String _baseUrl = defaultServerUrl;
  String? _token;
  Map<String, dynamic>? _user;

  String get baseUrl => _baseUrl;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;

  // Initialize service, load persisted token, user, and server URL
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? defaultServerUrl;
    _token = prefs.getString('token');
    final userStr = prefs.getString('user');
    if (userStr != null) {
      try {
        _user = jsonDecode(userStr);
      } catch (e) {
        _user = null;
      }
    }
  }

  // Update server URL
  Future<void> updateServerUrl(String url) async {
    // Sanitize URL (remove trailing slash)
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    // Prepend http if not present
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
  }

  // Set auth session
  Future<void> setSession(String token, Map<String, dynamic> user) async {
    _token = token;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('user', jsonEncode(user));
  }

  // Clear auth session
  Future<void> clearSession() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  // Helper for headers
  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // Test Server Connection (health check / latency check)
  Future<bool> testConnection(String testUrl) async {
    try {
      if (testUrl.endsWith('/')) {
        testUrl = testUrl.substring(0, testUrl.length - 1);
      }
      if (!testUrl.startsWith('http://') && !testUrl.startsWith('https://')) {
        testUrl = 'http://$testUrl';
      }
      // Attempt to hit index or a static asset/route with a 5s timeout
      final response = await http.get(Uri.parse('$testUrl/index.html')).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200 || response.statusCode == 404; // 404 is fine as long as server responded
    } catch (e) {
      return false;
    }
  }

  // User Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/login'),
      headers: _getHeaders(),
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Login failed');
    }
    return data;
  }

  // User Registration
  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/register'),
      headers: _getHeaders(),
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(data['error'] ?? 'Registration failed');
    }
    return data;
  }

  // Fetch Devices
  Future<List<dynamic>> getDevices() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/devices'),
      headers: _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to fetch devices');
    }
    return data['devices'] ?? [];
  }

  // Control Relay
  Future<bool> controlRelay(String deviceId, int relayIndex, bool state) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/control'),
      headers: _getHeaders(),
      body: jsonEncode({
        'deviceId': deviceId,
        'relay': relayIndex,
        'state': state,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to update relay');
    }
    return data['success'] == true;
  }

  // Create Device Token (Add New Device)
  Future<Map<String, dynamic>> createDeviceToken({
    required String name,
    required String wifiSSID,
    required String wifiPassword,
    required int relayCount,
    required String remoteMac,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/create-token'),
      headers: _getHeaders(),
      body: jsonEncode({
        'name': name,
        'wifiSSID': wifiSSID,
        'wifiPassword': wifiPassword,
        'relayCount': relayCount,
        'remoteMAC': remoteMac,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(data['error'] ?? 'Failed to register device token');
    }
    return data;
  }

  // Update Device Config (e.g. rename)
  Future<Map<String, dynamic>> updateDeviceConfig(String deviceId, String name) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/device/update-config'),
      headers: _getHeaders(),
      body: jsonEncode({
        'deviceId': deviceId,
        'name': name,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to update device config');
    }
    return data;
  }
}
