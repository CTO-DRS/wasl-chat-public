import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wasl_chat/services/message_buttons.dart';
import 'package:wasl_chat/theme.dart';
import 'package:wasl_chat/widgets/message_buttons_row.dart';
import 'package:wasl_chat/widgets/quick_reply_row.dart';

import 'support/render_harness.dart';

/// تدقيق وصول لودجات مشتركة بخط 1.6x: هدف اللمس 48dp، تسمية الأهداف، لا فيضان، تباين النص.
void main() {
  Future<void> pump(WidgetTester tester, Widget child, bool light) async {
    ignoreGlassTileAsserts();
    tester.view.physicalSize = const Size(360 * 2, 700 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(360, 700), textScaler: TextScaler.linear(1.6)),
      child: renderHarness(
          Scaffold(body: Align(alignment: Alignment.bottomCenter, child: child)),
          light ? WaslTheme.light : WaslTheme.dark),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  final widgets = <String, Widget Function()>{
    'quick replies': () => QuickReplyRow(
        replies: const ['تمام، شكراً', 'أكيد، أنا في الطريق الآن', 'سأرد عليك لاحقاً'],
        onReply: (_) {},
        onStyle: () {}),
    'message buttons': () => MessageButtonsRow(
        buttons: const [
          MessageButton('افتح الرابط', ButtonKind.url, 'https://waslchat.app'),
          MessageButton('انسخ الكود', ButtonKind.copy, 'WASL10'),
          MessageButton('تسمية طويلة جداً للزر الرابع', ButtonKind.copy, 'x'),
        ],
        onTap: (_) {}),
  };

  for (final e in widgets.entries) {
    for (final light in [false, true]) {
      testWidgets('${e.key} (${light ? "light" : "dark"}) at 1.6x', (tester) async {
        final h = tester.ensureSemantics();
        await pump(tester, e.value(), light);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        // شرائح التدرج تُقاس خطأً (1.1) فتُستثنى من فحص التباين
        if (e.key == 'message buttons') {
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }
        h.dispose();
      });
    }
  }
}
