// فقاعة الصادر الافتراضية: نص أبيض بتباين AA 4.5:1 على طول التدرج، ولقطة للمقارنة.
//   flutter test --update-goldens test/bubble_contrast_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wasl_chat/services/app_studio_service.dart';
import 'package:wasl_chat/services/contrast_service.dart';
import 'package:wasl_chat/theme.dart';

import 'support/render_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('فقاعة الصادر الافتراضية: كل نقطة من التدرج ≥4.5 مع الأبيض', () {
    final look = BubbleLook.resolve(StudioStyle.defaults, null);
    final g = look.gradient!;
    for (var t = 0.0; t <= 1.0; t += 0.1) {
      final c = Color.lerp(g.colors.first, g.colors.last, t)!;
      expect(ContrastService.ratio(Colors.white, c), greaterThanOrEqualTo(4.5), reason: 't=$t');
    }
  });

  Color tone(int c) => Color.lerp(Color(c), Colors.black, 0.12)!;

  test('كل لوحات الألوان: طرفا التدرج ≥4.5:1 مع الأبيض بعد تغميق الفقاعة', () {
    for (final p in StudioCatalog.palettes) {
      for (final c in [p.accent, p.accent2]) {
        expect(ContrastService.ratio(Colors.white, tone(c)), greaterThanOrEqualTo(4.5),
            reason: '${p.name} 0x${c.toRadixString(16)}');
      }
    }
  });

  test('كل السمات الجاهزة: طرفا تدرج الفقاعة ≥4.5:1 مع الأبيض', () {
    for (final t in StudioCatalog.themes) {
      for (final c in [t.style.accent, t.style.accent2]) {
        expect(ContrastService.ratio(Colors.white, tone(c)), greaterThanOrEqualTo(4.5),
            reason: '${t.name} 0x${c.toRadixString(16)}');
      }
    }
  });

  test('كل ألوان الاختيار الحر (swatches) ≥4.5:1 مع الأبيض', () {
    // لونا الهوية الافتراضيان يبقيان (ليظهرا محدَّدين في المنتقي): #6366F1=4.47 و#0D9488 قرار المالك
    const identity = {0xFF6366F1, 0xFF0D9488};
    for (final c in StudioCatalog.swatches.where((c) => !identity.contains(c))) {
      expect(ContrastService.ratio(Colors.white, Color(c)), greaterThanOrEqualTo(4.5),
          reason: '0x${c.toRadixString(16)}');
    }
  });

  test('الفقاعة الصلبة الافتراضية وتدرج الهوية العام لم يتغيرا للزر', () {
    final solid = BubbleLook.resolve(StudioStyle.defaults.copyWith(bubbleFill: StudioBubbleFill.solid), null);
    expect(ContrastService.ratio(Colors.white, solid.ownColor), greaterThanOrEqualTo(4.5));
    // تدرج الهوية للأزرار كما هو (قرار المالك: طرف #0D9488)
    expect(WaslColors.gradient.colors.last, WaslColors.tealDeep);
  });

  test('لون مخصص يختاره المستخدم يُحترم كما هو', () {
    final look = BubbleLook.resolve(
        StudioStyle.defaults, const ChatStyle(ownBubble: 0xFFFF5722));
    expect(look.ownColor, const Color(0xFFFF5722));
  });

  for (final light in [false, true]) {
    testWidgets('لقطة الفقاعات - ${light ? "فاتح" : "داكن"}', (tester) async {
      await loadRenderFonts();
      tester.view.physicalSize = const Size(360 * 3, 220 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final theme = light ? WaslTheme.light : WaslTheme.dark;
      final look = BubbleLook.resolve(StudioStyle.defaults, null);
      Widget bubble(bool mine, String t) => Align(
            alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
            child: Builder(
                builder: (c) => Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(12),
                      decoration: look.decoration(mine: mine, otherBase: c.bubbleOther),
                      child: Text(t, style: TextStyle(fontSize: 14, color: mine ? Colors.white : null)),
                    )),
          );
      await tester.pumpWidget(renderHarness(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              bubble(false, 'مرحباً! كيف حالك؟'),
              bubble(true, 'بخير الحمد لله 🌿'),
              bubble(true, 'نص أطول قليلاً لعرض التدرج على طول الفقاعة كاملة'),
            ]),
          ),
        ),
        theme,
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(find.byType(Scaffold),
          matchesGoldenFile('goldens/bubble_${light ? "light" : "dark"}_ar.png'));
    });
  }
}
