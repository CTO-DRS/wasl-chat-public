import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wasl_chat/screens/about_developer_screen.dart';
import 'package:wasl_chat/theme.dart';

import 'package:wasl_chat/data/developer_content.dart';
import 'package:wasl_chat/services/developer_update_service.dart';
import 'package:http/http.dart' as http;

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
      tester.view.physicalSize = const Size(390 * 3, 1100 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(renderHarness(
          const AboutDeveloperScreen(bannerAutoPlay: false), dark ? WaslTheme.dark : WaslTheme.light));
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
    tester.view.physicalSize = const Size(390 * 3, 1100 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(renderHarness(const AboutDeveloperScreen(bannerAutoPlay: false), WaslTheme.dark));
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
    final shared = <ShareParams>[];
    developerShare = (p) async => shared.add(p);
    await tester.tap(find.byKey(const ValueKey('dev-share-link')));
    await tester.pump();
    expect(shared.single.text, contains('https://github.com/CTO-DRS'));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('dev-share-qr')));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    expect(shared.length, 2);
    expect(shared.last.files, isNotNull);
    expect(shared.last.files!.single.mimeType, 'image/png');
    final bytes = await tester.runAsync(() => shared.last.files!.single.readAsBytes());
    expect(bytes!.sublist(1, 4), [0x50, 0x4E, 0x47]);
    File('/tmp/qr_share.png').writeAsBytesSync(bytes);
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

  test('مقارنة الإصدارات الدلالية', () {
    expect(compareVersions('v0.2.1', '0.2.0'), greaterThan(0));
    expect(compareVersions('0.2.0+103', '0.2.0'), 0);
    expect(compareVersions('0.10.0', '0.9.9'), greaterThan(0));
    expect(compareVersions('0.1.9', '0.2.0'), lessThan(0));
  });

  test('فحص التحديث: كل الحالات من صفحة الإصدارات', () async {
    final orig = DeveloperUpdateService.fetch;
    addTearDown(() => DeveloperUpdateService.fetch = orig);
    DeveloperUpdateService.fetch = (_) async => http.Response('{"tag_name":"v0.3.0"}', 200);
    expect((await DeveloperUpdateService.check(current: '0.2.0')).outcome, UpdateOutcome.available);
    DeveloperUpdateService.fetch = (_) async => http.Response('{"tag_name":"v0.2.0"}', 200);
    expect((await DeveloperUpdateService.check(current: '0.2.0')).outcome, UpdateOutcome.upToDate);
    DeveloperUpdateService.fetch = (_) async => http.Response('{}', 404);
    expect((await DeveloperUpdateService.check()).outcome, UpdateOutcome.noReleases);
    DeveloperUpdateService.fetch = (_) async => throw Exception('offline');
    expect((await DeveloperUpdateService.check()).outcome, UpdateOutcome.failed);
  });

  test('رسائل المشاركة: التطبيق وكل الحسابات الثمانية', () {
    expect(appShareMessage('ar'), contains('$developerReleasesUrl'));
    final all = AboutDeveloperScreen.allAccountsMessage('en');
    for (final l in developerLinks) {
      expect(all, contains(l.url));
    }
    expect(all.split('\n').length, 9);
  });

  test('محتوى اللافتات: كل لافتة بالعربية والإنجليزية والفرنسية', () {
    expect(developerBanners, isNotEmpty);
    for (final b in developerBanners) {
      for (final l in ['ar', 'en', 'fr']) {
        expect(b.title.of(l).trim(), isNotEmpty);
        expect(b.subtitle.of(l).trim(), isNotEmpty);
      }
    }
  });

  testWidgets('أزرار مشاركة التطبيق وكل الحسابات وفحص التحديث', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1100 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final shared = <ShareParams>[];
    developerShare = (p) async => shared.add(p);
    final orig = DeveloperUpdateService.fetch;
    addTearDown(() => DeveloperUpdateService.fetch = orig);
    DeveloperUpdateService.fetch = (_) async => http.Response('{"tag_name":"v9.0.0"}', 200);
    await tester.pumpWidget(renderHarness(
        const AboutDeveloperScreen(bannerAutoPlay: false), WaslTheme.dark));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dev-share-app')));
    await tester.tap(find.byKey(const ValueKey('dev-share-all')));
    await tester.pump();
    expect(shared.length, 2);
    expect(shared[1].text, contains('https://t.me/CTO_DRS'));
    await tester.tap(find.byKey(const ValueKey('dev-check-update')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('dev-update-status')), findsOneWidget);
    expect(find.byKey(const ValueKey('dev-version')), findsOneWidget);
    // سحب اللافتات ينقل للتالية
    await tester.drag(find.byKey(const ValueKey('dev-banners')), const Offset(300, 0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
}
