import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots and shows Home', (tester) async {
    // Mock storage for shared_preferences
    SharedPreferences.setMockInitialValues({});

    // If your root widget is App:
    await tester.pumpWidget(MyApp(initialProfile: const UserProfile()));

    // If you renamed it back to MyApp, use the next line instead:
    // await tester.pumpWidget(MyApp(initialProfile: const UserProfile()));

    await tester.pumpAndSettle();
    expect(find.text('MealPrep+ Home'), findsOneWidget);
  });
}
