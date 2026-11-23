// A profile that cannot be opened shows the member a plain message, never
// an internal error (23 Nov 2026: "Supabase profile row is missing required
// field \"city_name\"" was shown on the screen).
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/features/home/screens/profile_route_screen.dart';

void main() {
  test('an internal failure is "could not be opened", never its own text', () {
    final message = ProfileRouteScreen.messageFor(
      StateError('Supabase profile row is missing required field "city_name".'),
    );
    expect(message, 'This profile could not be opened.');
  });

  test('a profile the member may not see is "unavailable"', () {
    expect(ProfileRouteScreen.messageFor(ProfileRouteScreen.unavailable), 'This profile is unavailable.');
  });
}
