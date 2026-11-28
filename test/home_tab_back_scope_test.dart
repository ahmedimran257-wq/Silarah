import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/router/home_tab.dart';
import 'package:silarah/core/router/notification_navigation.dart';

void main() {
  testWidgets('Back from a secondary home tab returns to Discover first',
      (tester) async {
    var returnedToDiscover = false;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabBackScope(
          currentTab: HomeTab.chats,
          onReturnToPrimaryTab: () => returnedToDiscover = true,
          child: const Scaffold(body: Text('Messages')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(returnedToDiscover, isTrue);
    expect(find.text('Messages'), findsOneWidget);
  });

  testWidgets('Back from the Calls tab returns to Discover first', (tester) async {
    var returnedToDiscover = false;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabBackScope(
          currentTab: HomeTab.calls,
          onReturnToPrimaryTab: () => returnedToDiscover = true,
          child: const Scaffold(body: Text('Calls')),
        ),
      ),
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(returnedToDiscover, isTrue);
  });
}
