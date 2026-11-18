import 'package:flutter_test/flutter_test.dart';

import 'package:ai_language_app/app/app.dart';
import 'package:ai_language_app/features/home/home_screen.dart';

void main() {
  testWidgets('O app abre na tela Home', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
