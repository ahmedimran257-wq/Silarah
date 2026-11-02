import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String home;
  late String nav;
  late String filters;
  late String filterBar;
  late String discovery;
  late String discoveryCubit;
  late String filterOptions;
  late String sheets;

  setUpAll(() {
    home = File('lib/features/home/home_screen.dart').readAsStringSync();
    nav = File('lib/features/home/widgets/silarah_bottom_nav.dart')
        .readAsStringSync();
    filters = File('lib/features/home/widgets/discovery_filter_sheet.dart')
        .readAsStringSync();
    filterBar = File('lib/features/home/widgets/discovery_filter_bar.dart')
        .readAsStringSync();
    discovery = File('lib/features/home/screens/discovery_feed_screen.dart')
        .readAsStringSync();
    discoveryCubit = File('lib/core/cubits/discovery/discovery_feed_cubit.dart')
        .readAsStringSync();
    filterOptions =
        File('lib/core/services/discovery_filter_options_service.dart')
            .readAsStringSync();
    sheets = File('lib/core/widgets/overlays/silarah_bottom_sheet.dart')
        .readAsStringSync();
  });

  test('home caches tab trees and pauses every offscreen ticker', () {
    expect(home, contains('List<Widget?>.filled(_tabCount, null)'));
    expect(home, contains('_ensureTabBuilt(index)'));
    expect(home, contains('TickerMode('));
    expect(home, contains('enabled: index == _currentTab'));
    expect(home, contains('_tabCache[index] ?? const SizedBox.shrink()'));
    expect(home, contains('_profileRefreshToken'));
    expect(home, contains('MyProfileScreen(refreshToken:'));
    expect(home, isNot(contains('refreshToken++')));
  });

  test('bottom navigation avoids full-screen blur and broad bloc rebuilds', () {
    expect(nav, isNot(contains('BackdropFilter')));
    expect(nav, isNot(contains('ImageFilter.blur')));
    expect(nav, contains('BlocSelector<InterestsCubit'));
    expect(nav, contains('BlocSelector<ChatCubit'));
    expect(nav, isNot(contains('AnimatedPositioned')));
    expect(nav, isNot(contains('AnimatedScale')));
  });

  test('filter sheet draws one surface, not a route surface behind it', () {
    // The sheet's DraggableScrollableSheet fills the route and paints its own
    // rounded surface, so the route itself must stay transparent.
    final entry = filters.substring(
      filters.indexOf('Future<void> showDiscoveryFilterSheet('),
      filters.indexOf('class DiscoveryFilterSheet extends'),
    );
    expect(entry, contains('showSilarahBottomSheet<void>('));
    expect(entry, contains('backgroundColor: Colors.transparent'));
    expect(entry, isNot(contains('SilarahBottomSheetRoute')));
    expect(filters, contains('DraggableScrollableSheet('));
    expect(filters, contains('const Center(child: SilarahSheetHandle())'));
  });

  test('filter selection keeps chip geometry stable and builds lazily', () {
    expect(filters, contains('ListView.builder('));
    expect(
        filters, contains('itemBuilder: (context, index) => sections[index]'));
    expect(
      RegExp(r'width: 19,').allMatches(filters).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      RegExp(r'width: 1\.5,').allMatches(filters).length,
      greaterThanOrEqualTo(2),
    );
    expect(filters, contains('onChangeEnd: (values)'));
    expect(filterBar, contains('BlocSelector<DiscoveryFeedCubit'));
    // One border width for every state keeps chip geometry stable.
    expect(filterBar, contains('width: 1,'));
    expect(filterOptions, contains('_cacheLifetime'));
    expect(filterOptions, contains('_inFlight'));
    expect(filterOptions, contains('identical(_inFlight, request)'));
  });

  test('discovery swipe isolates transforms from the full screen', () {
    expect(discovery, isNot(contains('_pageOffset')));
    expect(discovery, isNot(contains('_pageCtrl.addListener')));
    expect(discovery, contains('AnimatedBuilder('));
    expect(discovery, contains('RepaintBoundary(child: child)'));
    expect(discoveryCubit, contains('FeedStatus.refreshing'));
    expect(
      discovery,
      contains('if (feedState.status == FeedStatus.refreshing)'),
    );
    expect(
      RegExp(r'_pageCtrl\.positions\.length == 1').allMatches(discovery).length,
      greaterThanOrEqualTo(2),
    );
  });

  test('modal sheets do not animate a live Gaussian blur or idle handle', () {
    expect(sheets, isNot(contains('BackdropFilter')));
    expect(sheets, isNot(contains('ImageFilter.blur')));
    expect(sheets, isNot(contains('repeat(reverse: true)')));
    expect(sheets, contains('extends ModalBottomSheetRoute'));
    expect(sheets, contains('AppDimensions.durationSheetEnter'));
    expect(sheets, contains('AnimationStyle.noAnimation'));
    expect(sheets, isNot(contains('FadeTransition(')));
    expect(sheets, isNot(contains('ScaleTransition(')));
  });
}
