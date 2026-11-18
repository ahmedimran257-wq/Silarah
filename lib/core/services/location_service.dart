import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'country_context_service.dart';
import 'operational_telemetry_service.dart';
import 'supabase_service.dart';

class LocationResolution {
  const LocationResolution({this.cityId, this.errorMessage});

  final String? cityId;
  final String? errorMessage;
  bool get isSuccess => cityId != null && cityId!.isNotEmpty;
}

/// Resolves externally searched cities into reusable rows in the Silarah city
/// cache. The server remains authoritative for IDs and location validation.
abstract final class LocationService {
  static Future<LocationResolution> resolveCity(CityResult city) async {
    if (!SupabaseService.isInitialized) {
      return const LocationResolution(
        errorMessage: 'Location saving is not configured. Please try again.',
      );
    }

    try {
      final existingId = city.catalogCityId?.trim();
      if (existingId != null && existingId.isNotEmpty) {
        return LocationResolution(cityId: existingId);
      }
      final token = city.resolutionToken?.trim();
      if (token == null || token.isEmpty) {
        return const LocationResolution(
          errorMessage:
              'This location result expired. Search for the city again.',
        );
      }
      final response = await SupabaseService.client.functions.invoke(
        'location-search',
        region: SupabaseService.functionsRegion,
        body: {
          'mode': 'resolve',
          'resolution_token': token,
        },
      );
      final payload = response.data;
      final cityId = payload is Map ? payload['city_id']?.toString() : null;
      if (cityId != null && cityId.trim().isNotEmpty) {
        return LocationResolution(cityId: cityId);
      }
    } catch (error) {
      debugPrint('LocationService: city resolution failed: $error');
    }

    // Saving a chosen city is the only way past the location step, so a
    // failure here must be visible in Crashlytics, not just the debug log.
    OperationalTelemetryService.record('location', 'city_resolution_failed');
    return const LocationResolution(
      errorMessage: 'We could not save that city. Please try again.',
    );
  }

  /// Refreshes the viewer's radius-search origin from the device. The server
  /// rounds it before storage; denied/unavailable GPS keeps the city point.
  static Future<bool> refreshDiscoveryLocation() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return false;
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      await SupabaseService.client.rpc(
        'update_discovery_location',
        params: {
          'p_latitude': position.latitude,
          'p_longitude': position.longitude,
        },
      );
      return true;
    } catch (error) {
      debugPrint('LocationService: device location refresh failed: $error');
      return false;
    }
  }
}
