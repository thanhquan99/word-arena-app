import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/main.dart';

void main() {
  testWidgets('App khởi động vào màn hình spike với nút PTT', (tester) async {
    await tester.pumpWidget(const WordArenaApp());

    expect(find.text('GIỮ ĐỂ NÓI'), findsOneWidget);
    expect(find.byType(GestureDetector), findsWidgets);
  });
}
