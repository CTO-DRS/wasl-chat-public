import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wasl_chat/screens/about_developer_screen.dart';
import 'package:wasl_chat/theme.dart';

import 'support/render_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('الروابط الثمانية الرسمية حرفياً', () {
    expect(developerLinks.map((l) => l.url).toList(), [
      'https://wa.me/message/MVTVWPOPFOVFF1',
      'https://t.me/CTO_DRS',
      'https://www.tiktok.com/@cto.drs',
      'https://www.instagram.com/cto.drs',
      'https://x.com/cto_drs',
      'https://youtube.com/@cto-drs',
      'https://github.com/CTO-DRS',
      'https://cto-drs.com',
    ]);
    expect(developerName, 'CTO.DRS');
  });

  test('صورة المطوّر مضمّنة كأصل', () async {
    final d = await rootBundle.load('assets/developer/dev-avatar.jpg');
    expect(d.lengthInBytes, greaterThan(1000));
  });

  for (final dark in [true, false]) {
    final n = dark ? 'dark' : 'light';
    testWidgets('لقطة عن المطوّر - $n', (tester) async {
      await loadRenderFonts();
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(renderHarness(
          const AboutDeveloperScreen(), dark ? WaslTheme.dark : WaslTheme.light));
      await tester.runAsync(() async {
        await precacheImage(
            const AssetImage('assets/developer/dev-avatar.jpg'),
            tester.element(find.byType(AboutDeveloperScreen)));
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('CTO.DRS'), findsOneWidget);
      for (final l in developerLinks) {
        expect(find.byKey(ValueKey('dev-link-${l.id}')), findsOneWidget);
      }
      await expectLater(find.byType(AboutDeveloperScreen),
          matchesGoldenFile('goldens/about_developer_${n}_ar.png'));
    });
  }

  testWidgets('النقر على حساب يفتح ورقة QR وعلى الصورة يفتح العارض', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(renderHarness(const AboutDeveloperScreen(), WaslTheme.dark));
    await tester.tap(find.byKey(const ValueKey('dev-link-github')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dev-qr')), findsOneWidget);
    expect(find.text('https://github.com/CTO-DRS'), findsOneWidget);
    expect(find.byKey(const ValueKey('dev-open')), findsOneWidget);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    await tester.tap(find.byKey(const ValueKey('dev-copy')));
    await tester.pump();
    expect(copied, 'https://github.com/CTO-DRS');
    expect(find.text('تم النسخ'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/about_developer_qr_ar.png'));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dev-avatar')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
