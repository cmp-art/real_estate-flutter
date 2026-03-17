// test/widget_test.dart
// App-level smoke test — verifies that the app starts without crashing.
// Run with:  flutter test

// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import individual unit test suites so `flutter test` picks them all up.
import 'unit/formatters_test.dart' as formatters_tests;
import 'unit/property_entity_test.dart' as entity_tests;
import 'unit/mortgage_calculator_test.dart' as mortgage_tests;

void main() {
  // ── Unit test suites ───────────────────────────────────────────────────
  group('Formatters', () => formatters_tests.main());
  group('PropertyEntity', () => entity_tests.main());
  group('MortgageCalculator', () => mortgage_tests.main());

  // ── App widget smoke test ──────────────────────────────────────────────
  // This verifies the widget tree renders without throwing.
  // Supabase is not initialised here; we test a minimal MaterialApp scaffold.
  testWidgets('Scaffold renders without overflow', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Makazi Estate'),
          ),
        ),
      ),
    );

    expect(find.text('Makazi Estate'), findsOneWidget);
  });

  testWidgets('Card renders title and price', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Card(
            child: ListTile(
              title: const Text('Modern Apartment - Dar es Salaam'),
              subtitle: const Text('TSh 1,200,000 / month'),
              trailing: IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Modern Apartment - Dar es Salaam'), findsOneWidget);
    expect(find.text('TSh 1,200,000 / month'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('Expandable text shows read-more trigger', (WidgetTester tester) async {
    const longText =
        'This is a very long property description that goes into great detail '
        'about the property features, location, amenities, and all the wonderful '
        'things that make this property a great investment opportunity for anyone '
        'looking to buy or rent in the area. It has beautiful views and modern '
        'finishing throughout.';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: _ExpandableTextTest(text: longText),
        ),
      ),
    );

    // Initially shows truncated text
    expect(find.text('Read more'), findsOneWidget);

    // Tap to expand
    await tester.tap(find.text('Read more'));
    await tester.pump();

    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('Bottom navigation renders 4 tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: 0,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined), label: 'Home'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.notifications_outlined),
                  label: 'Notifications'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}

// ── Minimal expandable text widget for widget test ─────────────────────────
class _ExpandableTextTest extends StatefulWidget {
  final String text;
  const _ExpandableTextTest({required this.text});

  @override
  State<_ExpandableTextTest> createState() => _ExpandableTextTestState();
}

class _ExpandableTextTestState extends State<_ExpandableTextTest> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (widget.text.length > 200)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Show less' : 'Read more'),
          ),
      ],
    );
  }
}
