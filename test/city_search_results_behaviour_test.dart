import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/country_context_service.dart';
import 'package:silarah/core/widgets/inputs/city_search_field.dart';

Map<String, dynamic> _place({
  required int id,
  required String name,
  required String state,
  String county = '',
  String osmValue = 'village',
  double lat = 18.0,
  double lng = 79.0,
}) =>
    {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [lng, lat],
      },
      'properties': {
        'osm_id': id,
        'osm_key': 'place',
        'osm_value': osmValue,
        'name': name,
        'state': state,
        if (county.isNotEmpty) 'county': county,
        'country': 'India',
        'countrycode': 'IN',
      },
      'silarah_resolution_token': 'token-$id',
    };

Future<T> _withFeatures<T>(
  List<Map<String, dynamic>> features,
  Future<T> Function() body,
) async {
  final previous = CountryContextService.debugLocationFeatureLoader;
  CountryContextService.debugLocationFeatureLoader = ({
    required query,
    required countryCode,
    required limit,
    required mode,
  }) async =>
      features;
  try {
    return await body();
  } finally {
    CountryContextService.debugLocationFeatureLoader = previous;
  }
}

void main() {
  final service = CountryContextService.instance;

  test('same-name villages in one state stay separate with their district',
      () async {
    final results = await _withFeatures(
      [
        _place(id: 1, name: 'Ramnagar', state: 'Telangana', county: 'Husnabad mandal'),
        _place(id: 2, name: 'Ramnagar', state: 'Telangana', county: 'Mirdoddi mandal'),
        _place(id: 3, name: 'Ramnagar', state: 'Telangana', county: 'Husnabad mandal'),
      ],
      () => service.searchCities('Ramnagar', countryCode: 'IN'),
    );

    expect(results, hasLength(2));
    expect(
      results.map((r) => r.district),
      containsAll(['Husnabad mandal', 'Mirdoddi mandal']),
    );
  });

  test('rural settlements and mandal-level places are accepted', () async {
    final results = await _withFeatures(
      [
        _place(id: 1, name: 'Chinna Thanda', state: 'Telangana', osmValue: 'isolated_dwelling'),
        _place(id: 2, name: 'Orvakal', state: 'Andhra Pradesh', osmValue: 'county'),
      ],
      () => service.searchCities('Or', countryCode: 'IN'),
    );

    expect(results.map((r) => r.city), containsAll(['Chinna Thanda', 'Orvakal']));
  });

  test('up to fifteen results are offered, in provider order on ties',
      () async {
    final results = await _withFeatures(
      [
        for (var i = 0; i < 20; i++)
          _place(id: i, name: 'Shivajinagar', state: 'Maharashtra', county: 'District $i'),
      ],
      () => service.searchCities('Shivajinagar', countryCode: 'IN'),
    );

    expect(results, hasLength(15));
    expect(results.first.district, 'District 0');
  });

  testWidgets('shows the launch-country hint when nothing matches',
      (tester) async {
    await _withFeatures(const [], () async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitySearchField(
              countryCode: 'IN',
              noResultsMessage: 'No match in India. Search for a city there.',
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Lagos');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(
        find.text('No match in India. Search for a city there.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('results fit above the keyboard and the last one can be tapped',
      (tester) async {
    // A 360 x 640 phone with the keyboard covering the bottom 260 points,
    // set on the device view so the results overlay sees it as on a phone.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    tester.view.viewInsets = const FakeViewPadding(bottom: 780);
    addTearDown(tester.view.reset);

    CityResult? picked;
    await _withFeatures(
      [
        for (var i = 0; i < 15; i++)
          _place(id: i, name: 'Ramnagar', state: 'Uttar Pradesh', county: 'District $i'),
      ],
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: CitySearchField(
                    countryCode: 'IN',
                    onSelected: (result) => picked = result,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'Ramnagar');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        final list = find.byType(ListView);
        expect(list, findsOneWidget);
        final listBottom = tester.getBottomLeft(list).dy;
        expect(listBottom, lessThanOrEqualTo(640 - 260));

        await tester.drag(list, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(find.byType(ListView), findsOneWidget,
            reason: 'scrolling must not close the results');
        expect(find.text('District 14 · Uttar Pradesh'), findsOneWidget);
        await tester.tap(find.text('District 14 · Uttar Pradesh'));
        await tester.pumpAndSettle();
        expect(picked?.district, 'District 14');
      },
    );
  });
}
