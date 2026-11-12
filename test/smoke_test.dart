import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('GivenMaterialApp_WhenPumped_ThenRendersWithoutError', (
    tester,
  ) async {
    // Given
    const app = MaterialApp(home: Scaffold(body: Text('Heimdall')));

    // When
    await tester.pumpWidget(app);

    // Then
    expect(find.text('Heimdall'), findsOneWidget);
  });
}
