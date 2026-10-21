// My Root — App smoke test.
// Tests that the root MyRootApp widget renders without errors.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/app/app.dart';

void main() {
  testWidgets('MyRootApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyRootApp());
    await tester.pump();
    // App renders without throwing
    expect(find.byType(MyRootApp), findsOneWidget);
  });
}
