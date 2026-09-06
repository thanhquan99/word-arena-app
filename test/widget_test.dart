import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/main.dart';

void main() {
  testWidgets('the app opens on the home screen', (tester) async {
    await tester.pumpWidget(const WordArenaApp());

    expect(find.text('Word Arena'), findsOneWidget);
    expect(find.text('Chơi'), findsOneWidget);
    // The mic spike stays reachable as a debugging tool.
    expect(find.text('Mic spike (debug)'), findsOneWidget);
  });
}
