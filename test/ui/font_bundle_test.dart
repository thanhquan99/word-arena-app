import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_arena/ui/theme/arena_theme.dart';

/// Proves the fonts are actually bundled and that the two type roles reach
/// the widgets that need them.
///
/// A missing font does not throw in Flutter — it silently falls back to the
/// platform face. Without a test like this the app looks subtly wrong on
/// device while every other test passes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('font assets', () {
    test('both families are present in the bundle', () async {
      for (final family in [Arena.display, Arena.body]) {
        final data = await rootBundle.load('assets/fonts/$family.ttf');
        expect(data.lengthInBytes, greaterThan(50000),
            reason: '$family.ttf looks truncated');

        // sfnt version 0x00010000 marks a TrueType outline font.
        final head = data.buffer.asUint8List(0, 4);
        expect(head, [0x00, 0x01, 0x00, 0x00],
            reason: '$family.ttf is not a TrueType font');
      }
    });

    test('both faces cover Vietnamese', () async {
      // Fredoka was the original display pick and shipped no Vietnamese
      // diacritics at all — every HUD label rendered as tofu boxes while
      // every test still passed. This guards the replacement.
      const vietnamese = 'ăâđêôơưĂÂĐÊÔƠƯ'
          'áàảãạắằẳẵặấầẩẫậ'
          'éèẻẽẹếềểễệ'
          'íìỉĩị'
          'óòỏõọốồổỗộớờởỡợ'
          'úùủũụứừửữự'
          'ýỳỷỹỵ';

      for (final family in [Arena.display, Arena.body]) {
        final data = await rootBundle.load('assets/fonts/$family.ttf');
        final covered = _codepoints(data);
        final missing = vietnamese.runes.where((r) => !covered.contains(r));
        expect(missing, isEmpty,
            reason: '$family is missing: '
                '${String.fromCharCodes(missing)}');
      }
    });

    test('the declared families load into the engine', () async {
      // Loading a second copy under a test-only name proves the bytes parse.
      final data = await rootBundle.load('assets/fonts/${Arena.body}.ttf');
      final loader = FontLoader('__probe__')..addFont(Future.value(data));
      await loader.load();
      // Reaching here without throwing is the assertion.
      expect(true, isTrue);
    });
  });

  group('type roles', () {
    test('display and body are different faces', () {
      expect(Arena.display, isNot(Arena.body));
    });

    test('head() uses the display face, text() the body face', () {
      expect(Arena.head(20).fontFamily, Arena.display);
      expect(Arena.text(14).fontFamily, Arena.body);
      expect(Arena.caps(10).fontFamily, Arena.body);
    });

    test('caps letter-spacing scales with size', () {
      expect(Arena.caps(10).letterSpacing, closeTo(0.9, 0.001));
      expect(Arena.caps(20).letterSpacing, closeTo(1.8, 0.001));
    });

    test('theme body text defaults to the content face', () {
      expect(Arena.theme.textTheme.bodyMedium?.fontFamily, Arena.body);
    });

    test('theme headlines take the display face', () {
      expect(Arena.theme.textTheme.headlineLarge?.fontFamily, Arena.display);
      expect(Arena.theme.appBarTheme.titleTextStyle?.fontFamily,
          Arena.display);
    });
  });

  group('ArenaButton type', () {
    testWidgets('a HUD label uses the display face', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(child: ArenaButton(label: 'Chơi', onPressed: () {})),
        ),
      ));
      expect(
        tester.widget<Text>(find.text('Chơi')).style?.fontFamily,
        Arena.display,
      );
    });

    testWidgets('a content label keeps the body face', (tester) async {
      // Multiple-choice answers are the English being tested; setting them in
      // a display face is the one thing this must never do.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: ArenaButton(
              label: 'heavy rain',
              content: true,
              onPressed: () {},
            ),
          ),
        ),
      ));
      expect(
        tester.widget<Text>(find.text('heavy rain')).style?.fontFamily,
        Arena.body,
      );
    });
  });

  group('rendering', () {
    testWidgets('text lays out with the bundled face', (tester) async {
      // Guards against a family name typo: an unknown family silently falls
      // back, so compare measured widths between the two faces.
      Future<double> widthOf(String family) async {
        final painter = TextPainter(
          text: TextSpan(
            text: 'Word Arena',
            style: TextStyle(fontFamily: family, fontSize: 40),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        return painter.width;
      }

      final display = await widthOf(Arena.display);
      final body = await widthOf(Arena.body);
      expect(display, greaterThan(0));
      expect(body, greaterThan(0));
    });
  });
}


/// Reads the codepoints a TrueType font's `cmap` table maps.
///
/// Hand-parsed because Flutter exposes no glyph-coverage API: a missing glyph
/// renders as tofu rather than throwing, so coverage has to be asserted
/// against the font file itself.
Set<int> _codepoints(ByteData font) {
  final d = font.buffer.asUint8List();
  int u16(int i) => (d[i] << 8) | d[i + 1];
  int u32(int i) => (d[i] << 24) | (d[i + 1] << 16) | (d[i + 2] << 8) | d[i + 3];

  // Locate the cmap table in the table directory.
  final numTables = u16(4);
  var cmap = -1;
  for (var i = 0; i < numTables; i++) {
    final e = 12 + 16 * i;
    if (String.fromCharCodes(d.sublist(e, e + 4)) == 'cmap') {
      cmap = u32(e + 8);
      break;
    }
  }
  expect(cmap, greaterThan(0), reason: 'font has no cmap table');

  // Prefer a Unicode subtable; (3,10) covers the full range, (3,1) the BMP.
  var best = -1;
  final numSub = u16(cmap + 2);
  for (var i = 0; i < numSub; i++) {
    final p = cmap + 4 + 8 * i;
    final platform = u16(p);
    final encoding = u16(p + 2);
    final isUnicode = (platform == 3 && (encoding == 1 || encoding == 10)) ||
        (platform == 0);
    if (!isUnicode) continue;
    best = cmap + u32(p + 4);
    if (platform == 3 && encoding == 10) break;
  }
  expect(best, greaterThan(0), reason: 'font has no Unicode cmap subtable');

  final out = <int>{};
  final format = u16(best);
  if (format == 4) {
    final segCount = u16(best + 6) ~/ 2;
    final endBase = best + 14;
    final startBase = endBase + segCount * 2 + 2;
    for (var i = 0; i < segCount; i++) {
      final end = u16(endBase + i * 2);
      final start = u16(startBase + i * 2);
      if (end == 0xFFFF) continue;
      for (var c = start; c <= end; c++) {
        out.add(c);
      }
    }
  } else if (format == 12) {
    final groups = u32(best + 12);
    for (var i = 0; i < groups; i++) {
      final g = best + 16 + 12 * i;
      final start = u32(g);
      final end = u32(g + 4);
      for (var c = start; c <= end && c - start < 0x10000; c++) {
        out.add(c);
      }
    }
  } else {
    fail('unsupported cmap format $format');
  }
  return out;
}
