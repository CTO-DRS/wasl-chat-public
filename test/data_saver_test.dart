import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wasl_chat/services/privacy_service.dart';
import 'package:wasl_chat/theme.dart';
import 'package:wasl_chat/widgets/media_bubbles.dart';

import 'support/render_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    PrivacyService.dataSaver.value = false;
    PrivacyService.manuallyLoaded.clear();
  });

  Widget host(Widget child, {bool dark = true}) => renderHarness(
      Scaffold(body: Center(child: child)), dark ? WaslTheme.dark : WaslTheme.light);

  test('توفير البيانات مطفأ افتراضياً', () {
    expect(PrivacyService.dataSaver.value, isFalse);
  });

  testWidgets('مطفأ: الصورة تُحمَّل كالمعتاد بلا بطاقة', (tester) async {
    await tester.pumpWidget(host(const DataSaverGate(
        id: 'm1', width: 220, height: 140, child: Text('IMAGE'))));
    expect(find.text('IMAGE'), findsOneWidget);
    expect(find.byKey(const ValueKey('data-saver-load')), findsNothing);
  });

  testWidgets('مفعّل: بطاقة تحميل ثم الصورة بنقرة وتبقى للجلسة', (tester) async {
    PrivacyService.dataSaver.value = true;
    await tester.pumpWidget(host(const DataSaverGate(
        id: 'm2', width: 220, height: 140, child: Text('IMAGE'))));
    expect(find.text('IMAGE'), findsNothing);
    expect(find.text('اضغط لتحميل الصورة'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('data-saver-load')));
    await tester.pump();
    expect(find.text('IMAGE'), findsOneWidget);
    // إعادة بناء الفقاعة نفسها لا تسأل مرة ثانية
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host(const DataSaverGate(
        id: 'm2', width: 220, height: 140, child: Text('IMAGE'))));
    expect(find.text('IMAGE'), findsOneWidget);
  });

  testWidgets('إطفاء الوضع يعيد الصورة فوراً', (tester) async {
    PrivacyService.dataSaver.value = true;
    await tester.pumpWidget(host(const DataSaverGate(
        id: 'm3', width: 220, height: 140, child: Text('IMAGE'))));
    expect(find.text('IMAGE'), findsNothing);
    PrivacyService.dataSaver.value = false;
    await tester.pump();
    expect(find.text('IMAGE'), findsOneWidget);
  });

  for (final dark in [true, false]) {
    testWidgets('لقطة بطاقة توفير البيانات - ${dark ? 'داكن' : 'فاتح'}', (tester) async {
      await loadRenderFonts();
      tester.view.physicalSize = const Size(390 * 3, 300 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      PrivacyService.dataSaver.value = true;
      await tester.pumpWidget(host(
          const DataSaverGate(id: 'g', width: 240, height: 150, child: SizedBox()),
          dark: dark));
      await tester.pump();
      await expectLater(find.byType(Scaffold),
          matchesGoldenFile('goldens/data_saver_${dark ? 'dark' : 'light'}_ar.png'));
    });
  }
}
