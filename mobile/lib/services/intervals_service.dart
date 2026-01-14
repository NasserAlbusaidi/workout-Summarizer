import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for interacting with Intervals.icu API
class IntervalsService {
  static const _baseUrl = 'https://intervals.icu/api/v1';
  static const _apiKeyStorageKey = 'intervals_api_key';
  static const _athleteIdStorageKey = 'intervals_athlete_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Check if API key is configured
  Future<bool> hasApiKey() async {
    final key = await _storage.read(key: _apiKeyStorageKey);
    return key != null && key.isNotEmpty;
  }

  /// Save API key
  Future<void> saveApiKey(String apiKey, String athleteId) async {
    await _storage.write(key: _apiKeyStorageKey, value: apiKey);
    await _storage.write(key: _athleteIdStorageKey, value: athleteId);
  }

  /// Get stored API key
  Future<String?> getApiKey() async {
    return await _storage.read(key: _apiKeyStorageKey);
  }

  /// Get stored athlete ID
  Future<String?> getAthleteId() async {
    return await _storage.read(key: _athleteIdStorageKey);
  }

  /// Clear API key
  Future<void> clearApiKey() async {
    await _storage.delete(key: _apiKeyStorageKey);
    await _storage.delete(key: _athleteIdStorageKey);
  }

  /// Get authorization headers
  Future<Map<String, String>> _getHeaders() async {
    final apiKey = await getApiKey();
    if (apiKey == null) throw Exception('API key not configured');

    // Intervals.icu uses Basic Auth with API_KEY as username
    final credentials = base64Encode(utf8.encode('API_KEY:$apiKey'));
    return {
      'Authorization': 'Basic $credentials',
      'Content-Type': 'application/json',
    };
  }

  /// Validate API key and get athlete info
  Future<Map<String, dynamic>?> validateAndGetAthlete() async {
    try {
      final headers = await _getHeaders();

      // First try to get current user's athlete info
      final response = await http.get(
        Uri.parse('$_baseUrl/athlete/i0'),
        headers: headers,
      );

      print(
        'Athlete response: ${response.statusCode} - ${response.body.substring(0, response.body.length.clamp(0, 500))}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Save the actual athlete ID for future requests
        if (data['id'] != null) {
          await _storage.write(
            key: _athleteIdStorageKey,
            value: data['id'].toString(),
          );
        }
        return data;
      }
      return null;
    } catch (e) {
      print('Error validating athlete: $e');
      return null;
    }
  }

  /// Fetch recent activities
  Future<List<Map<String, dynamic>>> getActivities({
    int? count,
    String? oldest,
    String? newest,
  }) async {
    try {
      final athleteId = await getAthleteId() ?? 'i0';
      final headers = await _getHeaders();

      // Intervals.icu requires date range - default to last 90 days
      final now = DateTime.now();
      final defaultNewest =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final thirtyDaysAgo = now.subtract(const Duration(days: 90));
      final defaultOldest =
          '${thirtyDaysAgo.year}-${thirtyDaysAgo.month.toString().padLeft(2, '0')}-${thirtyDaysAgo.day.toString().padLeft(2, '0')}';

      final queryParams = <String, String>{
        'oldest': oldest ?? defaultOldest,
        'newest': newest ?? defaultNewest,
      };

      final uri = Uri.parse(
        '$_baseUrl/athlete/$athleteId/activities',
      ).replace(queryParameters: queryParams);

      print('Activities URL: $uri');
      final response = await http.get(uri, headers: headers);
      print('Activities response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = response.body;
        print('Activities count chars: ${body.length}');

        final dynamic data = json.decode(body);

        // Handle both array and object with 'activities' key
        List<dynamic> activities;
        if (data is List) {
          activities = data;
        } else if (data is Map && data['activities'] != null) {
          activities = data['activities'] as List;
        } else {
          print('Unexpected data format: ${data.runtimeType}');
          return [];
        }

        print('Found ${activities.length} activities');
        return activities.cast<Map<String, dynamic>>();
      } else {
        print('Error body: ${response.body}');
      }

      return [];
    } catch (e) {
      print('Error fetching activities: $e');
      return [];
    }
  }

  /// Download FIT file for an activity
  Future<Uint8List?> downloadFitFile(String activityId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$_baseUrl/activity/$activityId/fit-file'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get single activity details
  Future<Map<String, dynamic>?> getActivity(String activityId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$_baseUrl/activity/$activityId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
