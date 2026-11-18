import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Closed-test testers abroad searched their own city on the India-only
// location step, saw "No matching city" and never continued. These contracts
// keep the launch-country guidance and the country-filtered search in place.
void main() {
  final quickLocation =
      File('lib/features/onboarding/screens/quick_location_screen.dart')
          .readAsStringSync();
  final citySearchField =
      File('lib/core/widgets/inputs/city_search_field.dart').readAsStringSync();
  final countryContext =
      File('lib/core/services/country_context_service.dart').readAsStringSync();
  final locationSearch =
      File('supabase/functions/location-search/index.ts').readAsStringSync();
  final emailScreen =
      File('lib/features/onboarding/screens/email_verification_screen.dart')
          .readAsStringSync();

  test('single-country onboarding names the launch country', () {
    expect(quickLocation, contains('_singleCountry = launch.isSingleCountry'));
    expect(
      quickLocation,
      contains('Silarah is open in {country} first.'),
    );
    expect(quickLocation, contains('noResultsMessage: _singleCountry'));
    expect(citySearchField, contains('widget.noResultsMessage ??'));
  });

  test('a short cache hit no longer hides provider cities', () {
    expect(countryContext, contains('_enoughCachedCities'));
    expect(countryContext, contains('_mergeCityResults('));
  });

  test('provider search keeps only the requested country', () {
    expect(locationSearch, contains('PROVIDER_WINDOW'));
    expect(
      locationSearch,
      contains('featureCountryCode(feature) === countryCode'),
    );
    expect(locationSearch, contains('mode === "region" ? "place:state" : "place"'));
  });

  test('city results show the district and keep same-name villages apart', () {
    expect(countryContext, contains("properties['county']"));
    expect(countryContext, contains('result.district.toLowerCase()'));
    expect(citySearchField, contains('if (result.district.isNotEmpty)'));
    expect(locationSearch, contains('catalogCityName(claim)'));
  });

  test('city and region results fit above the keyboard and scroll', () {
    final regionSearchField =
        File('lib/core/widgets/inputs/region_search_field.dart')
            .readAsStringSync();
    for (final source in [citySearchField, regionSearchField]) {
      expect(source, contains('media.viewInsets.bottom'));
      expect(source, contains('BoxConstraints(maxHeight: maxHeight)'));
      expect(source, isNot(contains('NeverScrollableScrollPhysics')));
    }
  });

  test('stuck-onboarding failures reach Crashlytics', () {
    expect(
      File('lib/core/services/photo_moderation_service.dart')
          .readAsStringSync(),
      contains("record('photo', 'moderation_scan_failed')"),
    );
    expect(
      File('lib/core/services/location_service.dart').readAsStringSync(),
      contains("record('location', 'city_resolution_failed')"),
    );
  });

  test('sign-in send failures point new members to Create profile', () {
    expect(
      emailScreen,
      contains('New to Silarah? Tap Create profile below.'),
    );
  });
}
