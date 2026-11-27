import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wasl_chat/services/message_buttons.dart';
import 'package:wasl_chat/theme.dart';
import 'package:wasl_chat/widgets/button_editor_sheet.dart';
import 'package:wasl_chat/widgets/message_buttons_row.dart';

import 'support/render_harness.dart';

void main() {
  group('MessageButton', () {
    test('رابط https وزر نسخ صالحان', () {
      final a = MessageButton.tryParse({'label': 'تسجيل', 'kind': 'url', 'value': 'https://waslchat.app'});
      final b = MessageButton.tryParse({'label': 'الكود', 'kind': 'copy', 'value': 'WASL10'});
      expect(a!.kind, ButtonKind.url);
      expect(b!.value, 'WASL10');
    });

    test('يرفض http وjavascript والأنواع المجهولة والتسمية الفارغة أو الطويلة', () {
      for (final v in [
        {'label': 'x', 'kind': 'url', 'value': 'http://a.com'},
        {'label': 'x', 'kind': 'url', 'value': 'javascript:alert(1)'},
        {'label': 'x', 'kind': 'url', 'value': 'https://nodot'},
        {'label': 'x', 'kind': 'call', 'value': '123'},
        {'label': '', 'kind': 'copy', 'value': 'a'},
        {'label': 'ا' * 25, 'kind': 'copy', 'value': 'a'},
        {'label': 'x', 'kind': 'copy', 'value': ''},
        'نص',
        null,
      ]) {
        expect(MessageButton.tryParse(v), isNull, reason: '$v');
      }
    });

    test('parseAll يسقط الفاسد ويقصّ عند 4', () {
      final raw = [
        for (var i = 0; i < 6; i++) {'label': 'b$i', 'kind': 'copy', 'value': 'v'},
      ];
      expect(MessageButton.parseAll(raw).length, 4);
      expect(MessageButton.parseAll(null), isEmpty);
      expect(MessageButton.parseAll('x'), isEmpty);
      expect(
          MessageButton.parseAll([
            {'label': 'ok', 'kind': 'copy', 'value': 'v'},
            {'label': 'bad', 'kind': 'url', 'value': 'http://x.com'},
          ]).length,
          1);
    });

    test('toJson يدور ذهاباً وإياباً', () {
      const b = MessageButton('اشترِ', ButtonKind.url, 'https://a.com/p');
      expect(MessageButton.tryParse(b.toJson())!.value, 'https://a.com/p');
    });
  });

  testWidgets('الصف: النقر يستدعي الزر الصحيح', (tester) async {
    MessageButton? got;
    await tester.pumpWidget(renderHarness(
        Scaffold(
            body: MessageButtonsRow(
                buttons: const [
                  MessageButton('الموقع', ButtonKind.url, 'https://a.com'),
                  MessageButton('الكود', ButtonKind.copy, 'X'),
                ],
                onTap: (b) => got = b)),
        WaslTheme.dark));
    await tester.tap(find.byKey(const ValueKey('msg-btn-الكود')));
    expect(got!.kind, ButtonKind.copy);
  });

  testWidgets('المحرر: إضافة زر رابط وزر نسخ وإرجاعهما، ويرفض http', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    List<MessageButton>? result;
    await tester.pumpWidget(renderHarness(
        Scaffold(
            body: Builder(
                builder: (c) => TextButton(
                    key: const ValueKey('open'),
                    onPressed: () async => result = await showButtonEditor(c, const []),
                    child: const Text('فتح')))),
        WaslTheme.dark));
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('btn-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('btn-label-0')), 'الموقع');
    await tester.enterText(find.byKey(const ValueKey('btn-value-0')), 'http://a.com');
    await tester.tap(find.byKey(const ValueKey('btn-done')));
    await tester.pumpAndSettle();
    expect(find.textContaining('https://'), findsWidgets);
    expect(result, isNull);
    await tester.enterText(find.byKey(const ValueKey('btn-value-0')), 'https://a.com');
    await tester.tap(find.byKey(const ValueKey('btn-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('btn-label-1')), 'الكود');
    await tester.tap(find.text('نسخ').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('btn-value-1')), 'WASL10');
    await tester.tap(find.byKey(const ValueKey('btn-done')));
    await tester.pumpAndSettle();
    expect(result!.map((b) => b.label), ['الموقع', 'الكود']);
    expect(result![1].kind, ButtonKind.copy);
  });

  testWidgets('لقطة المحرر والصف', (tester) async {
    await loadRenderFonts();
    tester.view.physicalSize = const Size(390 * 3, 760 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(renderHarness(
        Scaffold(
          body: Column(children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('عرض خاص لمتابعي القناة اليوم فقط'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MessageButtonsRow(buttons: const [
                MessageButton('افتح العرض', ButtonKind.url, 'https://waslchat.app'),
                MessageButton('انسخ كود الخصم', ButtonKind.copy, 'WASL10'),
              ], onTap: (_) {}),
            ),
            const Divider(height: 32),
            const Expanded(
                child: ButtonEditor(initial: [
              MessageButton('افتح العرض', ButtonKind.url, 'https://waslchat.app'),
              MessageButton('انسخ كود الخصم', ButtonKind.copy, 'WASL10'),
            ])),
          ]),
        ),
        WaslTheme.dark));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/message_buttons_dark_ar.png'));
  });
}
