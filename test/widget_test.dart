import 'package:flutter_test/flutter_test.dart';
import 'package:life_inbox/main.dart';

void main() {
  testWidgets('Life Inbox app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const LifeInboxApp());
  });
}
