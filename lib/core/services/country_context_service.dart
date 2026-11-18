// SILARAH — Country Context Service
//
// Two optional, free data providers:
//   1. Wikidata           → location-specific language enrichment
//   2. Photon             → region/city/area search with coordinates
//
// Two curated data sources (no API exists for these):
//   3. CountryCommunityData → Muslim communities by country
//   4. CountrySectData      → Sect options adapted by country
//
// Official country languages are bundled from Wikidata (CC0), so onboarding
// remains globally functional when external providers are unavailable.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/country_communities_data.dart';
import '../data/country_languages_data.dart';
import '../data/country_sects_data.dart';
import 'supabase_service.dart';
import 'operational_telemetry_service.dart';

// Models
class CityResult {
  const CityResult({
    required this.city,
    required this.state,
    required this.country,
    required this.countryCode,
    required this.postalCode,
    required this.fullAddress,
    required this.placeId,
    required this.lat,
    required this.lng,
    this.resolutionToken,
    this.catalogCityId,
    this.district = '',
  });

  final String city;
  final String state;
  final String country;
  final String countryCode;
  final String postalCode; // Pincode / ZIP / Postcode
  final String fullAddress; // "Andheri West, Mumbai, Maharashtra 400053, India"
  final String placeId;
  final double lat;
  final double lng;
  final String? resolutionToken;
  final String? catalogCityId;

  /// District, taluk or mandal from the provider. Shown so that villages with
  /// the same name in one state (there are dozens of each) can be told apart.
  final String district;

  @override
  String toString() => fullAddress;
}

class RegionResult {
  const RegionResult({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.country,
  });

  final String id;
  final String name;
  final String countryCode;
  final String country;

  @override
  String toString() => name;
}

class CountryContext {
  const CountryContext({
    required this.languages,
    required this.communities,
    required this.sects,
  });

  final List<String> languages;
  final List<String> communities;
  final List<String> sects;
}

// Service
class CountryContextService {
  CountryContextService._();
  static final CountryContextService instance = CountryContextService._();

  @visibleForTesting
  static Future<List<Map<String, dynamic>>> Function({
    required String query,
    required String countryCode,
    required int limit,
    required String mode,
  })? debugLocationFeatureLoader;

  // Simple in-memory cache for bundled and location-enriched language lists.
  final _languageCache = <String, List<String>>{};
  final _locationLanguageCache = <String, List<String>>{};

  static const _photonRegionOsmValues = {
    'state',
    'province',
    'region',
  };
  /// With this many cached matches the cache alone is a full answer.
  static const _enoughCachedCities = 5;

  static const _photonCityAreaOsmValues = {
    'city',
    'town',
    'village',
    'hamlet',
    'locality',
    'municipality',
    'suburb',
    'quarter',
    'neighbourhood',
    'district',
    'borough',
    'island',
    // Rural settlements and taluk/mandal-level places people live in.
    'isolated_dwelling',
    'county',
    'state',
    'province',
    'region',
  };

  // 1. GET LANGUAGES FOR COUNTRY
  //
  // Returns bundled official languages for every supported country. Cached in
  // SharedPreferences for consistent behavior with location enrichment.

  Future<List<String>> getLanguages(String iso2) async {
    final key = iso2.toUpperCase();

    // Ignore a stale fallback-only cache from an older failed lookup.
    final memoryCached = _languageCache[key];
    if (_hasUsableLanguages(memoryCached)) return memoryCached!;
    _languageCache.remove(key);

    // SharedPreferences offline cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('lang_cache_$key');
      if (_hasUsableLanguages(cached)) {
        _languageCache[key] = cached!;
        return cached;
      }
    } catch (_) {}

    final languages = _fallbackLanguages(key);
    _languageCache[key] = languages;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('lang_cache_$key', languages);
    } catch (_) {}
    return languages;
  }

  // 2. SEARCH CITIES (Supabase cache → authenticated proxy)
  Future<List<String>> getLanguagesForLocation({
    required String countryCode,
    String? stateName,
    String? cityName,
  }) async {
    final code = countryCode.toUpperCase();
    final state = stateName?.trim() ?? '';
    final city = cityName?.trim() ?? '';
    final cacheKey = [
      code,
      if (state.isNotEmpty) state.toLowerCase(),
      if (city.isNotEmpty) city.toLowerCase(),
    ].join('|');

    final memoryCached = _locationLanguageCache[cacheKey];
    if (_hasUsableLanguages(memoryCached)) return memoryCached!;
    _locationLanguageCache.remove(cacheKey);

    const cacheVersion = 'v2';
    final persistentCacheKey = 'loc_lang_${cacheVersion}_$cacheKey';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(persistentCacheKey);
      if (_hasUsableLanguages(cached)) {
        _locationLanguageCache[cacheKey] = cached!;
        return cached;
      }
    } catch (_) {}

    // India launch uses a server-owned Census/state catalogue. Residence only
    // ranks likely choices; the RPC also returns the complete India catalogue
    // so migrants and linguistic minorities are never excluded.
    if (code == 'IN' && SupabaseService.isInitialized) {
      try {
        final response = await SupabaseService.client.rpc(
          'get_mother_tongues_for_location',
          params: {
            'p_country_code': code,
            'p_state_name': state.isEmpty ? null : state,
            'p_city_name': city.isEmpty ? null : city,
          },
        );
        final rows = response as List<dynamic>? ?? const [];
        final serverLanguages = _uniqueLanguages(rows
            .whereType<Map>()
            .map((row) => row['language']?.toString() ?? '')
            .where((language) => language.trim().isNotEmpty)
            .toList());
        if (_hasUsableLanguages(serverLanguages)) {
          if (!serverLanguages.contains('Other')) {
            serverLanguages.add('Other');
          }
          _locationLanguageCache[cacheKey] = serverLanguages;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setStringList(persistentCacheKey, serverLanguages);
          } catch (_) {}
          return serverLanguages;
        }
      } catch (error) {
        debugPrint(
          '[CountryContextService] India mother-tongue catalogue failed: $error',
        );
        OperationalTelemetryService.record(
          'onboarding',
          'mother_tongue_catalogue_failed',
        );
      }
    }

    final merged = _uniqueLanguages([
      ...await getLanguages(code),
      ..._fallbackLanguages(code),
    ]);
    if (!merged.contains('Other')) merged.add('Other');

    _locationLanguageCache[cacheKey] = merged;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(persistentCacheKey, merged);
    } catch (_) {}

    return merged;
  }

  Future<List<RegionResult>> searchRegions(
    String query, {
    required String countryCode,
  }) async {
    final selectedCountry = countryCode.trim().toUpperCase();
    if (query.trim().length < 2 || selectedCountry.isEmpty) return [];

    try {
      if (SupabaseService.isInitialized) {
        final response = await SupabaseService.client.rpc(
          'search_regions',
          params: {
            'search_term': query.trim(),
            'country_filter': selectedCountry,
          },
        );
        final rows = response as List<dynamic>? ?? const [];
        final cached = rows
            .map((row) {
              final map = row as Map<String, dynamic>;
              final name = (map['name'] as String? ?? '').trim();
              final code =
                  (map['country_code'] as String? ?? selectedCountry).trim();
              if (name.isEmpty || code.isEmpty) return null;
              return RegionResult(
                id: map['id']?.toString() ?? '',
                name: name,
                countryCode: code.toUpperCase(),
                country: (map['country'] as String? ?? '').trim(),
              );
            })
            .whereType<RegionResult>()
            .toList();
        if (cached.isNotEmpty) return cached;
      }
    } catch (e) {
      debugPrint('[CountryContextService] search_regions failed: $e');
      OperationalTelemetryService.record(
        'location',
        'region_cache_query_failed',
      );
    }

    return _searchPhotonRegions(query.trim(), selectedCountry);
  }

  Future<List<CityResult>> searchCities(
    String query, {
    required String countryCode,
    String? regionName,
  }) async {
    debugPrint(
        '[CountryContextService] searchCities query: "$query", countryCode: "$countryCode"');
    final selectedCountry = countryCode.trim().toUpperCase();
    final selectedRegion = regionName?.trim();
    if (query.trim().length < 2 || selectedCountry.isEmpty) return [];

    // 1. Try the Supabase city cache first. The cache only holds cities members
    // have already chosen, so a single hit ("Hyd" -> Hyderabad) must not hide
    // every other city; a short cache list is merged with provider results.
    var cached = const <CityResult>[];
    if (SupabaseService.isInitialized) {
      try {
        debugPrint(
            '[CountryContextService] Querying Supabase rpc search_cities...');
        final response = await SupabaseService.client.rpc(
          'search_cities',
          params: {
            'search_term': query.trim(),
            'country_filter': selectedCountry,
            if (selectedRegion != null && selectedRegion.isNotEmpty)
              'region_filter': selectedRegion,
          },
        );
        debugPrint('[CountryContextService] Supabase response: $response');
        if (response != null) {
          final list = response as List<dynamic>;
          if (list.isNotEmpty) {
            debugPrint(
                '[CountryContextService] Found ${list.length} cities from Supabase');
            cached = list
                .map((row) => _cityResultFromSupabaseRow(
                      row as Map<String, dynamic>,
                      selectedCountry: selectedCountry,
                      selectedRegion: selectedRegion,
                    ))
                .whereType<CityResult>()
                .toList();
            if (cached.length >= _enoughCachedCities) return cached;
          }
        }
      } catch (e) {
        debugPrint('[CountryContextService] Supabase search_cities failed: $e');
        OperationalTelemetryService.record(
          'location',
          'city_cache_query_failed',
        );
      }
    }

    // 2. Photon is the global no-key fallback when the city cache misses. Query
    // broadly because users type real areas too: districts, islands, suburbs,
    // and provinces are valid onboarding locations when they have coordinates.
    try {
      debugPrint(
          '[CountryContextService] Querying Photon Geocoding API for "$query" (countryCode: $countryCode)...');
      // The provider has no region filter. Naming the chosen state in the
      // query ("Ramnagar Telangana") ranks that state's places first.
      final regionQuery = selectedRegion == null || selectedRegion.isEmpty
          ? query.trim()
          : '${query.trim()} $selectedRegion';
      final features = await _fetchPhotonFeatures(
        regionQuery.length <= 80 ? regionQuery : query.trim(),
        countryCode: selectedCountry,
        limit: 15,
      );
      final parsedResults = <CityResult>[];
      for (final feat in features) {
        final result = _cityResultFromPhotonFeature(
          feat,
          selectedCountry: selectedCountry,
          selectedRegion: selectedRegion,
        );
        if (result != null) parsedResults.add(result);
      }

      if (parsedResults.isNotEmpty) {
        debugPrint(
            '[CountryContextService] Found ${parsedResults.length} cities from Photon');
        return _mergeCityResults(
          cached,
          _rankPhotonCities(parsedResults, query.trim()),
        );
      }
    } catch (e) {
      debugPrint('[CountryContextService] Photon search failed: $e');
      OperationalTelemetryService.record(
        'location',
        'provider_city_search_failed',
      );
    }

    // 3. Do not accept unverified free text: matching needs real coordinates.
    if (cached.isEmpty) {
      debugPrint(
          '[CountryContextService] No matches found, returning empty list.');
    }
    return cached;
  }

  Future<List<RegionResult>> _searchPhotonRegions(
    String query,
    String selectedCountry,
  ) async {
    try {
      final features = await _fetchPhotonFeatures(
        query,
        countryCode: selectedCountry,
        limit: 12,
        osmTags: const ['place:state'],
      );
      final results = <RegionResult>[];
      final seen = <String>{};

      for (final feat in features) {
        final properties = feat['properties'] as Map<String, dynamic>? ?? {};
        final code = (properties['countrycode'] as String? ?? '').toUpperCase();
        final name = (properties['name'] as String? ?? '').trim();
        final country = (properties['country'] as String? ?? '').trim();
        final osmValue =
            (properties['osm_value'] as String? ?? '').trim().toLowerCase();
        if (code != selectedCountry ||
            name.isEmpty ||
            !_photonRegionOsmValues.contains(osmValue)) {
          continue;
        }

        final key = '$code|${name.toLowerCase()}';
        if (!seen.add(key)) continue;
        results.add(RegionResult(
          id: 'photon-${properties['osm_id'] ?? name.toLowerCase()}',
          name: name,
          countryCode: code,
          country: country,
        ));
      }
      return results;
    } catch (e) {
      debugPrint('[CountryContextService] Photon region search failed: $e');
      OperationalTelemetryService.record(
        'location',
        'provider_region_search_failed',
      );
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPhotonFeatures(
    String query, {
    required String countryCode,
    int limit = 10,
    List<String>? osmTags,
  }) async {
    final testLoader = debugLocationFeatureLoader;
    if (testLoader != null) {
      return testLoader(
        query: query,
        countryCode: countryCode,
        limit: limit.clamp(1, 15),
        mode: osmTags?.contains('place:state') == true ? 'region' : 'city',
      );
    }
    if (!SupabaseService.isInitialized) return const [];
    final response = await SupabaseService.client.functions.invoke(
      'location-search',
      region: SupabaseService.functionsRegion,
      body: {
        'query': query,
        'country_code': countryCode,
        'mode': osmTags?.contains('place:state') == true ? 'region' : 'city',
        'limit': limit.clamp(1, 15),
      },
    ).timeout(const Duration(seconds: 8));
    final payload = response.data;
    if (payload is! Map) return const [];
    final features = payload['features'] as List<dynamic>? ?? const [];
    return features.whereType<Map<String, dynamic>>().toList();
  }

  CityResult? _cityResultFromPhotonFeature(
    Map<String, dynamic> feature, {
    required String selectedCountry,
    String? selectedRegion,
  }) {
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
    final coords = geometry['coordinates'] as List<dynamic>? ?? const [];
    final cCode = (properties['countrycode'] as String? ?? '').toUpperCase();
    final osmKey = (properties['osm_key'] as String? ?? '').toLowerCase();
    final osmValue = (properties['osm_value'] as String? ?? '').toLowerCase();

    // Photon public search is global, so the app enforces both country and
    // acceptable location type before anything can be selected or saved.
    if (cCode != selectedCountry ||
        osmKey != 'place' ||
        !_photonCityAreaOsmValues.contains(osmValue)) {
      return null;
    }

    final cityName = (properties['name'] as String? ?? '').trim();
    final rawState = (properties['state'] as String? ?? '').trim();
    final countryName = (properties['country'] as String? ?? '').trim();
    if (cityName.isEmpty ||
        coords.length < 2 ||
        coords[0] is! num ||
        coords[1] is! num) {
      return null;
    }

    final rawDistrict = (properties['county'] as String? ??
            properties['district'] as String? ??
            '')
        .trim();
    final district =
        rawDistrict.toLowerCase() == cityName.toLowerCase() ? '' : rawDistrict;
    final isRegionLike = _photonRegionOsmValues.contains(osmValue);
    final stateName = rawState.isNotEmpty
        ? rawState
        : isRegionLike
            ? cityName
            : '';
    if (selectedRegion != null &&
        selectedRegion.isNotEmpty &&
        stateName.isNotEmpty &&
        !_sameLocationName(stateName, selectedRegion)) {
      return null;
    }

    return CityResult(
      city: cityName,
      state: stateName,
      country: countryName,
      countryCode: cCode,
      postalCode: properties['postcode'] as String? ?? '',
      fullAddress: _joinDistinctLocationParts([
        cityName,
        district,
        stateName,
        countryName,
      ]),
      placeId: 'photon-${properties['osm_id'] ?? cityName.toLowerCase()}',
      lat: (coords[1] as num).toDouble(),
      lng: (coords[0] as num).toDouble(),
      resolutionToken: feature['silarah_resolution_token'] as String?,
      district: district,
    );
  }

  /// Same name and state is not the same place: villages repeat across
  /// districts, so the district is part of the identity.
  static String _cityResultKey(CityResult result) =>
      '${result.countryCode}|${result.city.toLowerCase()}|'
      '${result.district.toLowerCase()}|${result.state.toLowerCase()}';

  static const _maxCityResults = 15;

  /// Cache rows already carry a city ID, so they come first; provider rows
  /// that name the same city and state are dropped.
  List<CityResult> _mergeCityResults(
    List<CityResult> cached,
    List<CityResult> provider,
  ) {
    final seen = <String>{};
    final cachedNames = {
      for (final result in cached)
        '${result.countryCode}|${result.city.toLowerCase()}|${result.state.toLowerCase()}',
    };
    return [
      ...cached,
      // A cached row has no district; drop the provider row it came from.
      ...provider.where((result) => !cachedNames.contains(
            '${result.countryCode}|${result.city.toLowerCase()}|${result.state.toLowerCase()}',
          )),
    ].where((result) => seen.add(_cityResultKey(result))).take(_maxCityResults).toList();
  }

  List<CityResult> _rankPhotonCities(List<CityResult> results, String query) {
    final q = query.trim().toLowerCase();
    // Provider order reflects importance (Kolkata before Kollam for "Kol"),
    // so it breaks ties instead of name length.
    final ranked = [
      for (var i = 0; i < results.length; i++) (index: i, result: results[i]),
    ];
    ranked.sort((x, y) {
      final a = x.result;
      final b = y.result;
      final aExact = a.city.toLowerCase() == q ? 0 : 1;
      final bExact = b.city.toLowerCase() == q ? 0 : 1;
      if (aExact != bExact) return aExact.compareTo(bExact);

      final aStarts = a.city.toLowerCase().startsWith(q) ? 0 : 1;
      final bStarts = b.city.toLowerCase().startsWith(q) ? 0 : 1;
      if (aStarts != bStarts) return aStarts.compareTo(bStarts);

      return x.index.compareTo(y.index);
    });

    final seen = <String>{};
    return ranked
        .map((entry) => entry.result)
        .where((result) => seen.add(_cityResultKey(result)))
        .take(_maxCityResults)
        .toList();
  }

  CityResult? _cityResultFromSupabaseRow(
    Map<String, dynamic> map, {
    required String selectedCountry,
    String? selectedRegion,
  }) {
    final cityName = (map['name'] as String? ?? '').trim();
    final stateName = (map['state'] as String? ?? '').trim();
    final countryName = (map['country'] as String? ?? '').trim();
    final code = (map['country_code'] as String? ?? selectedCountry)
        .trim()
        .toUpperCase();
    final lat = (map['lat'] as num?)?.toDouble();
    final lng = (map['lng'] as num?)?.toDouble();
    if (cityName.isEmpty ||
        code != selectedCountry ||
        lat == null ||
        lng == null) {
      return null;
    }
    if (selectedRegion != null &&
        selectedRegion.trim().isNotEmpty &&
        !_sameLocationName(stateName, selectedRegion)) {
      return null;
    }
    return CityResult(
      city: cityName,
      state: stateName,
      country: countryName,
      countryCode: code,
      postalCode: '',
      fullAddress: _joinDistinctLocationParts([
        cityName,
        stateName,
        countryName,
      ]),
      placeId: map['id']?.toString() ?? '',
      lat: lat,
      lng: lng,
      catalogCityId: map['id']?.toString(),
    );
  }

  static bool _sameLocationName(String a, String b) {
    final left = _normalizeLocationName(a);
    final right = _normalizeLocationName(b);
    if (left.isEmpty || right.isEmpty) return false;
    return left == right || left.contains(right) || right.contains(left);
  }

  static String _normalizeLocationName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _joinDistinctLocationParts(List<String> parts) {
    final seen = <String>{};
    final cleaned = <String>[];
    for (final part in parts.map((p) => p.trim()).where((p) => p.isNotEmpty)) {
      final key = part.toLowerCase();
      if (seen.add(key)) cleaned.add(part);
    }
    return cleaned.join(', ');
  }

  // Place detail fetch (postal code, lat/lng, components)
  // 3. GET COMMUNITIES FOR COUNTRY
  //
  // No API for this exists. Uses CountryCommunityData.
  // The data file is designed to be replaceable by a Supabase query.

  List<String> getCommunities(String iso2) {
    return CountryCommunityData.forCountry(iso2);
  }

  // 4. GET SECTS FOR COUNTRY
  //
  // Returns sect options adapted to the country's Muslim demographics.
  // Saudi Arabia: no main sect shown (sensitive), only deen level.
  // Iran: Shia first.
  // Mixed countries: full list.

  CountrySectConfig getSects(String iso2) {
    return CountrySectData.forCountry(iso2);
  }

  // 5. GET FULL CONTEXT (all four)
  Future<CountryContext> getContext(String iso2) async {
    final langs = await getLanguages(iso2);
    return CountryContext(
      languages: langs,
      communities: getCommunities(iso2),
      sects: getSects(iso2).displaySects,
    );
  }

  // Language fallback
  static List<String> _fallbackLanguages(String iso2) {
    return _uniqueLanguages([
      ...?kCountryLanguages[iso2.toUpperCase()],
      'Other',
    ]);
  }

  static bool _hasUsableLanguages(List<String>? languages) {
    return languages != null &&
        languages.any((language) => language.trim().toLowerCase() != 'other');
  }

  static List<String> _uniqueLanguages(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isEmpty) continue;
      final key = normalized.toLowerCase();
      if (seen.add(key)) result.add(normalized);
    }
    result.sort((a, b) {
      if (a == 'Other') return 1;
      if (b == 'Other') return -1;
      return a.compareTo(b);
    });
    return result;
  }
}
