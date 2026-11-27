import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wasl_chat/screens/business_replies_screen.dart';
import 'package:wasl_chat/services/business_reply_service.dart';
import 'package:wasl_chat/services/live_location_service.dart';
import 'package:wasl_chat/services/message_buttons.dart';
import 'package:wasl_chat/theme.dart';
import 'package:wasl_chat/widgets/button_editor_sheet.dart';
import 'package:wasl_chat/widgets/live_status_row.dart';
import 'package:wasl_chat/widgets/location_card.dart';
import 'package:wasl_chat/widgets/message_buttons_row.dart';

import 'support/render_harness.dart';

/// إمكانية الوصول للويدجتات الجديدة: خط مكبّر 2.0 على شاشة 360 بلا فيض،
/// وأهداف لمس لا تقل عن 48dp، وكل هدف بتسمية للقارئ الشاشي.
void main() {
  Future<void> pumpScaled(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(360, 800), textScaler: TextScaler.linear(2.0)),
      child: renderHarness(child, WaslTheme.dark),
    ));
    await tester.pumpAndSettle();
  }

  const buttons = [
    MessageButton('افتح العرض الخاص بمتابعي القناة', ButtonKind.url, 'https://waslchat.app'),
    MessageButton('انسخ كود الخصم', ButtonKind.copy, 'WASL10'),
  ];

  testWidgets('أزرار الرسالة: خط 2.0 بلا فيض وأهداف لمس كافية', (tester) async {
    final h = tester.ensureSemantics();
    await pumpScaled(tester, Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: MessageButtonsRow(buttons: buttons, onTap: (_) {}))));
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    h.dispose();
  });

  testWidgets('بطاقة الموقع وحالة المشاركة: خط 2.0 بلا فيض', (tester) async {
    await pumpScaled(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  for (final s in LiveState.values) LiveStatusRow(s),
                  LocationCard(
                      lat: 21.4225,
                      lng: 39.8262,
                      label: 'موقعي المباشر مع وصف طويل جداً لاختبار القص',
                      liveState: LiveState.stale,
                      fill: const Color(0xFF1B2030),
                      titleColor: Colors.white,
                      subColor: Colors.white70,
                      onTap: () {}),
                ]))));
    expect(tester.takeException(), isNull);
  });

  testWidgets('محرر الأزرار: خط 2.0 بلا فيض وأهداف لمس كافية', (tester) async {
    final h = tester.ensureSemantics();
    await pumpScaled(tester, const Scaffold(body: ButtonEditor(initial: buttons)));
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    h.dispose();
  });

  testWidgets('شاشة ردود الأعمال: خط 2.0 بلا فيض', (tester) async {
    ignoreGlassTileAsserts();
    BusinessReplyService.templates.value = [
      const ReplyTemplate(id: '1', title: 'ساعات العمل الرسمية للفرع الرئيسي', text: 'من 9 إلى 5 طوال أيام الأسبوع عدا الجمعة', shortcut: 'دوام'),
    ];
    await pumpScaled(tester, const BusinessRepliesScreen());
    expect(tester.takeException(), isNull);
    addTearDown(() => BusinessReplyService.templates.value = []);
  });
}
