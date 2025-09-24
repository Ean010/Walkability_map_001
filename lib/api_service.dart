import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'flexible_polyline.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'dart:math' as math;

class ApiService {
  final String bestTimeApiKeyPrivate;
  final String bestTimeApiKeyPublic;
  final String hereMapsApiKey;

  static const String _bestTimeBaseUrl = 'https://besttime.app/api/v1';
  static const String _hereMapsBaseUrl = 'https://router.hereapi.com/v8/routes';
  static const String _herePlacesUrl = 'https://discover.search.hereapi.com/v1/discover';

  ApiService({
    String? bestTimeApiKeyPrivate,
    String? bestTimeApiKeyPublic,
    String? hereMapsApiKey,
  }) : bestTimeApiKeyPrivate = bestTimeApiKeyPrivate ?? dotenv.env['BESTTIME_API_KEY_PRIVATE'] ?? '',
       bestTimeApiKeyPublic = bestTimeApiKeyPublic ?? dotenv.env['BESTTIME_API_KEY_PUBLIC'] ?? '',
       hereMapsApiKey = hereMapsApiKey ?? dotenv.env['HERE_MAPS_API_KEY'] ?? '' {
    if (kDebugMode) {
      print("ApiService Initialized.");
      print("  BESTTIME_API_KEY_PRIVATE: ${this.bestTimeApiKeyPrivate.isNotEmpty ? '***' : 'Not Set'}");
      print("  BESTTIME_API_KEY_PUBLIC: ${this.bestTimeApiKeyPublic.isNotEmpty ? '***' : 'Not Set'}");
      print("  HERE_MAPS_API_KEY: ${this.hereMapsApiKey.isNotEmpty ? '***' : 'Not Set'}");
    }
  }

  Future<Map<String, dynamic>> getPedestrianRoute(latlong.LatLng start, latlong.LatLng end) async {
    if (kDebugMode) print("[ApiService] getPedestrianRoute called for $start to $end");
    try {
      if (kDebugMode) print("[ApiService] Trying HERE Maps for route...");
      return await _getHereMapsRoute(start, end);
    } catch (e) {
      if (kDebugMode) print("[ApiService] HERE Maps failed: $e. Trying OpenRouteService (if configured)...");
      throw Exception('Failed to get route: $e');
    }
  }

  Future<Map<String, dynamic>> _getHereMapsRoute(latlong.LatLng start, latlong.LatLng end) async {
    if (kDebugMode) print("[ApiService] _getHereMapsRoute executing...");
    if (hereMapsApiKey.isEmpty) {
      if (kDebugMode) print("[ApiService] HERE Maps API key is MISSING. Cannot make request.");
      throw Exception('HERE Maps API key not configured');
    }

    final url = Uri.parse('$_hereMapsBaseUrl?transportMode=pedestrian&origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&return=polyline,summary&apikey=$hereMapsApiKey');
    if (kDebugMode) print("[ApiService] HERE Maps URL: $url");
    
    final response = await http.get(url);
    if (kDebugMode) {
      print("[ApiService] HERE Maps response status: ${response.statusCode}");
      print("[ApiService] HERE Maps response body: ${response.body}");
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to get pedestrian route from HERE Maps (Status: ${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    if (data['routes'] == null || (data['routes'] as List).isEmpty) {
      throw Exception('No routes found from HERE Maps. Response: ${response.body}');
    }

    final route = data['routes'][0];
    final section = route['sections'][0];
    final summary = section['summary'];
    final polyline = section['polyline'];

    if (kDebugMode) print("[ApiService] HERE Maps Encoded Polyline: $polyline");
    
    final List<latlong.LatLng> points = _decodeHerePolyline(polyline);
    if (kDebugMode) print("[ApiService] Decoded Points: $points");

    return {
      'points': points,
      'duration': summary['duration'],
      'distance': summary['length'] / 1000.0,
    };
  }

  List<latlong.LatLng> _decodeHerePolyline(String encoded) =>
      FlexiblePolyline.decode(encoded)
          .map((geo) => latlong.LatLng(geo.lat, geo.lng))
          .toList();

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * (math.pi / 180);

  Future<Map<String, dynamic>> getPopularTimes({
    required String venueName,
    required String address,
  }) async {
    if (bestTimeApiKeyPrivate.isEmpty) {
      if (kDebugMode) print("[BestTime API] API key is MISSING. Cannot make request.");
      throw Exception('BestTime API key not configured');
    }

    final queryParams = {
      "api_key_private": bestTimeApiKeyPrivate,
      "name": venueName,
      "address": address
    };

    final url = Uri.parse('$_bestTimeBaseUrl/venues/forecasts').replace(queryParameters: queryParams);

    try {
      if (kDebugMode) print("[BestTime API] Request URL: $url");
      
      final res = await http.get(url);

      if (kDebugMode) {
        print("[BestTime API] Response Status: ${res.statusCode}");
        print("[BestTime API] Response Body: ${res.body}");
      }

      if (res.statusCode == 200) {
        return json.decode(res.body);
      } else {
        final error = json.decode(res.body);
        throw Exception('BestTime API Error ${res.statusCode}: ${error['message'] ?? res.body}');
      }
    } catch (e) {
      if (kDebugMode) print('getPopularTimes exception: $e');
      rethrow;
    }
  }
  
  Future<List<Map<String, dynamic>>> fetchCrowdDataForMap({
  required double centerLat,
  required double centerLng,
  required int radiusMeters,
}) async {
  if (bestTimeApiKeyPrivate.isEmpty || bestTimeApiKeyPublic.isEmpty) { // Keep this check if public key is used elsewhere
    if (kDebugMode) print("[BestTime API] API keys not set. Cannot fetch crowd data.");
    return [];
  }

  final uri = Uri.parse('$_bestTimeBaseUrl/venues/filter').replace(queryParameters: {
    'api_key_private': bestTimeApiKeyPrivate,
    'lat': centerLat.toStringAsFixed(3),
    'lng': centerLng.toStringAsFixed(3),
    'radius': radiusMeters.toString(),
    'foot_traffic': 'day',
    'limit': '5',
  });

    if (kDebugMode) print("[BestTime API] Request URL: ${uri.toString()}");

    try {
      final response = await http.get(uri);
      if (kDebugMode) {
        print("[BestTime API] Response Status: ${response.statusCode}");
        print("[BestTime API] Response Body: ${response.body}");
      }

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse?['venues'] != null) {
          List<Map<String, dynamic>> crowdDataList = [];
          for (var venue in jsonResponse['venues']) {
            final String venueName = venue['venue_name'] ?? 'Unknown Venue';
            final String venueId = venue['venue_id'] ?? '';
            final double lat = venue['venue_lat'] ?? 0.0;
            final double lng = venue['venue_lng'] ?? 0.0;
            final List<dynamic>? dayRaw = venue['day_raw'] ?? [];

            int crowdLevel = 1;
            if (dayRaw != null && dayRaw.isNotEmpty) {
              final currentHour = DateTime.now().hour;
              if (currentHour < dayRaw.length && dayRaw[currentHour] is num) {
                crowdLevel = ((dayRaw[currentHour] as num) / 100 * 5).ceil().clamp(1,5).toInt();
              } else {
                final maxIntensity = dayRaw.map((e) => e is num ? e : 0).cast<num>().reduce(math.max);
                crowdLevel = ((maxIntensity / 100 * 5).ceil().clamp(1,5)).toInt();
              }
            }

            crowdDataList.add({
              'id': venueId,
              'name': venueName,
              'location': {'lat': lat, 'lon': lng},
              'crowd_level': crowdLevel,
              'foot_traffic_data': dayRaw,
            });
          }
          return crowdDataList;
        }
      } else {
        if (kDebugMode) print("[BestTime API] Error fetching crowd data: ${json.decode(response.body)['message']}");
      }
    } catch (e) {
      if (kDebugMode) print("[BestTime API] Exception fetching crowd data: $e");
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _getNearbyPlacesHere(
      double lat, double lon, {int radius = 1000}) async {
    if (kDebugMode) print("[ApiService] _getNearbyPlacesHere called for lat:$lat, lon:$lon, radius:$radius");
    
    if (hereMapsApiKey.isEmpty) {
      if (kDebugMode) print("[ApiService] HERE Maps API key is MISSING. Cannot make request.");
      throw Exception('HERE Maps API key not configured');
    }

    final url = Uri.parse("$_herePlacesUrl?at=$lat,$lon&q=place&limit=20&apikey=$hereMapsApiKey");
    if (kDebugMode) print("[ApiService] HERE Places URL: $url");

    final response = await http.get(url);
    if (kDebugMode) {
      print("[ApiService] HERE Places response status: ${response.statusCode}");
      print("[ApiService] HERE Places response body: ${response.body}");
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch places from HERE (Status: ${response.statusCode}): ${response.body}');
    }

    final data = json.decode(response.body);
    return List<Map<String, dynamic>>.from(data['items'] ?? []);
  }

  String _extractAddressFromHere(Map<String, dynamic> place) {
    try {
      final address = place['address'] as Map<String, dynamic>?;
      if (address != null) {
        final List<String> addressParts = [];
        ['houseNumber', 'street', 'city', 'county', 'state', 'postalCode', 'countryName']
            .forEach((key) {
          if (address[key] != null) addressParts.add(address[key] as String);
        });

        if (addressParts.isEmpty) {
          if (address['label'] != null) addressParts.add(address['label'] as String);
          else if (place['title'] != null) addressParts.add(place['title'] as String);
        }
        
        return addressParts.where((e) => e.trim().isNotEmpty).join(', ');
      }
      return place['title'] as String? ?? '';
    } catch (e) {
      if (kDebugMode) print("Error extracting address from HERE place: $e");
      return place['title'] as String? ?? '';
    }
  }

  int _extractCrowdLevel(Map<String, dynamic> popularTimes) {
    try {
      if (kDebugMode) print("[ApiService] Attempting to extract crowd level...");
      if (popularTimes.isEmpty) {
        if (kDebugMode) print("[ApiService] No popular times data available. Defaulting to 1.");
        return 1;
      }

      final analysis = popularTimes['analysis'];
      if (analysis == null) {
        if (kDebugMode) print("[ApiService] 'analysis' field is null. Defaulting to 1.");
        return 1;
      }

      // Try venue_forecast first
      if (analysis['venue_forecast'] != null && (analysis['venue_forecast'] is List) && (analysis['venue_forecast'] as List).isNotEmpty) {
        final currentDayOfWeekBestTime = DateTime.now().weekday % 7; 
        final forecastToday = (analysis['venue_forecast'] as List).firstWhere(
          (dayForecast) => dayForecast['day_int'] == currentDayOfWeekBestTime,
          orElse: () {
            if (kDebugMode) print("No forecast data for today ($currentDayOfWeekBestTime).");
            return null;
          },
        );

        if (forecastToday?['hour_analysis'] != null && (forecastToday['hour_analysis'] is List)) {
          final hourData = (forecastToday['hour_analysis'] as List);
          final currentHour = DateTime.now().hour;
          if (currentHour < hourData.length && hourData[currentHour]?['intensity_nr'] != null) {
            return ((hourData[currentHour]['intensity_nr'] as num) + 1).toInt();
          } else {
            if (kDebugMode) print("No hour data or intensity_nr for current hour ($currentHour).");
          }
        }
      }

      // Fallback to busy_hours
      if (analysis.containsKey('busy_hours') && (analysis['busy_hours'] is List) && (analysis['busy_hours'] as List).isNotEmpty) {
        final busyHours = analysis['busy_hours'] as List;
        final currentHour = DateTime.now().hour;
        if (currentHour < busyHours.length && busyHours[currentHour] is num) {
          return ((busyHours[currentHour] as num) / 100 * 5).ceil().clamp(1,5);
        } else {
          if (kDebugMode) print("No busy_hours data for current hour ($currentHour).");
        }
      }
      
      if (kDebugMode) print("[ApiService] No valid crowd data found in popularTimes. Defaulting to 1.");
      return 1;
    } catch (e) {
      if (kDebugMode) print("[ApiService] Error extracting crowd level: $e. Defaulting to 1.");
      return 1;
    }
  }
}