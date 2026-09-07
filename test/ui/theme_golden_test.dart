import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/ui/theme/arena_theme.dart';

/// Renders the type scale and the button states with the real bundled fonts.
///
/// Run with: flutter test --update-goldens test/ui/theme_golden_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Widget tests use a placeholder font unless the real ones are loaded.
    for (final family in [Arena.display, Arena.body]) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await loader.load();
    }
  });

  testWidgets('type and buttons', (tester) async {
    await tester.binding.setSurfaceSize(const Size(620, 640));

    Widget row(String tag, Widget child) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(width: 108, child: Text(tag, style: Arena.caps(9))),
              Expanded(child: child),
            ],
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Arena.theme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Baloo 2 · display', style: Arena.caps(10)),
                const SizedBox(height: 6),
                row('Kết trận', Text('THẮNG', style: Arena.head(36))),
                row('Tên pet', Text('Phượng Hoàng Lửa', style: Arena.head(22))),
                row('Nhãn nút', Text('Cướp lượt', style: Arena.head(15))),
                const SizedBox(height: 18),
                Text('Nunito · nội dung', style: Arena.caps(10)),
                const SizedBox(height: 6),
                row('Đề mission', Text('He goes to school', style: Arena.text(17))),
                row('Objective',
                    Text('Đổi sang quá khứ đơn', style: Arena.text(14))),
                row('Phụ',
                    Text('3 objective · ~20s',
                        style: Arena.text(12, color: Arena.inkSoft))),
                const SizedBox(height: 22),
                Text('ArenaButton', style: Arena.caps(10)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 11,
                  runSpacing: 11,
                  children: [
                    ArenaButton(
                      label: 'Chơi',
                      icon: Icons.sports_esports,
                      onPressed: () {},
                    ),
                    ArenaButton(
                      label: 'Về trang chính',
                      color: Arena.surface,
                      compact: true,
                      onPressed: () {},
                    ),
                    ArenaButton(
                      label: 'Cướp',
                      color: Arena.enemy,
                      compact: true,
                      onPressed: () {},
                    ),
                    // Learning content keeps the body face.
                    ArenaButton(
                      label: 'heavy rain',
                      color: Arena.surface,
                      content: true,
                      onPressed: () {},
                    ),
                    const ArenaButton(label: 'Chờ', onPressed: null),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/theme_type_buttons.png'),
    );
  });
}
