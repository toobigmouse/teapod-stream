import 'package:flutter_test/flutter_test.dart';
import 'package:teapodstream/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TeapodApp());
    // Advance past the 5s deferred update check timer so it doesn't
    // trigger "A Timer is still pending" on teardown.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(find.byType(TeapodApp), findsOneWidget);
  });
}
