import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wasl_chat/theme.dart';
import 'package:wasl_chat/widgets/report_dialog.dart';
import 'package:wasl_chat/widgets/tone_picker_sheet.dart';

import 'support/render_harness.dart';

/// تدقيق وصول للحوارات والصفائح بخط 1.6x: هدف اللمس 48dp وتسمية الأهداف ولا فيضان.
void main() {
  final opens = <String, Future<void> Function(BuildContext)>{
    'report dialog': (c) => showReportDialog(c, targetName: 'مستخدم تجريبي', targetUser: 'u1'),
    'tone picker': (c) => showTonePicker(c),
  };
  for (final e in opens.entries) {
    for (final light in [false, true]) {
      testWidgets('${e.key} (${light ? "light" : "dark"}) at 1.6x', (tester) async {
        ignoreGlassTileAsserts();
        final h = tester.ensureSemantics();
        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        late BuildContext ctx;
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(size: Size(360, 800), textScaler: TextScaler.linear(1.6)),
          child: renderHarness(
              Builder(builder: (c) {
                ctx = c;
                return const Scaffold(body: SizedBox());
              }),
              light ? WaslTheme.light : WaslTheme.dark),
        ));
        e.value(ctx);
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(tester.takeException(), isNull);
        expect(find.byType(ModalBarrier), findsAtLeastNWidgets(2), reason: 'الحوار/الصفيحة لم تُفتح');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        h.dispose();
      });
    }
  }
}
