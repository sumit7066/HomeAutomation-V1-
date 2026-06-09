import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('SmartHomeApp smoke test', (WidgetTester tester) async {
    // Mock SharedPreferences values for the test
    SharedPreferences.setMockInitialValues({});
    
    final apiService = ApiService();
    await apiService.init();

    // Build our app and trigger a frame.
    await tester.pumpWidget(SmartHomeApp(apiService: apiService));

    // Verify that the SmartHomeApp widget is present in the tree.
    expect(find.byType(SmartHomeApp), findsOneWidget);
  });
}
