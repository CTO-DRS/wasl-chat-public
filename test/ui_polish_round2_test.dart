/// اختبارات صقل الواجهة — الجولة الثانية (2.5.0): سلّم الخط، حبر فقاعتي
/// المحسوب من التباين، تذييل الفقاعة في الحافة الختامية، السحب للرد،
/// وزر «إلى الأحدث».
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wasl_chat/services/app_studio_service.dart';
import 'package:wasl_chat/services/contrast_service.dart';
import 'package:wasl_chat/theme.dart';
import 'package:wasl_chat/widgets/bubble_layout.dart';

BubbleLook _look(int? own, {StudioBubbleFill fill = StudioBubbleFill.solid}) {
  return BubbleLook.resolve(
    StudioStyle.defaults,
    ChatStyle(ownBubble: own, bubbleFill: fill),
  );
}

Widget _host(Widget child, {TextDirection dir = TextDirection.rtl}) => MaterialApp(
      theme: WaslTheme.dark,
      home: Directionality(
        textDirection: dir,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('WaslFont — سلّم الخط', () {
    test('لا حجم أصغر من 11 والسلّم تصاعدي', () {
      const scale = [
        WaslFont.caption, WaslFont.small, WaslFont.meta, WaslFont.body,
        WaslFont.bodyLarge, WaslFont.title, WaslFont.titleLarge, WaslFont.headline,
        WaslFont.headlineLarge, WaslFont.display, WaslFont.displayLarge, WaslFont.hero,
      ];
      expect(scale.first, greaterThanOrEqualTo(11));
      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
    });

    test('TextTheme مبني من السلّم نفسه', () {
      final t = WaslTheme.dark.textTheme;
      expect(t.bodyMedium!.fontSize, WaslFont.body);
      expect(t.bodySmall!.fontSize, WaslFont.small);
      expect(t.labelSmall!.fontSize, WaslFont.caption);
      expect(t.titleMedium!.fontSize, WaslFont.title);
      expect(t.bodyMedium!.letterSpacing, 0);
    });
  });

  group('حبر فقاعتي من التباين', () {
    test('الافتراضي (تدرج الهوية) يبقى أبيض', () {
      expect(_look(null, fill: StudioBubbleFill.gradient).ownInk, Colors.white);
    });

    test('فقاعة فاتحة (أصفر) تأخذ حبراً داكناً مقروءاً', () {
      final look = _look(0xFFFDE047);
      expect(look.ownInk, WaslColors.ink);
      expect(ContrastService.ratio(look.ownInk, const Color(0xFFFDE047)),
          greaterThanOrEqualTo(ContrastService.aaNormal));
      // علامة القراءة لا تكون سماوياً باهتاً فوق الفاتح
      expect(look.ownReadTick, isNot(WaslColors.readTick));
    });

    test('فقاعة داكنة تبقى بيضاء بعلامة قراءة متوهجة', () {
      final look = _look(0xFF1E3A8A);
      expect(look.ownInk, Colors.white);
      expect(look.ownReadTick, WaslColors.readTick);
    });

    test('التدرج المخصص من لون فاتح يُقاس على متوسطه', () {
      final look = _look(0xFFA5F3FC, fill: StudioBubbleFill.gradient);
      expect(look.ownInk, WaslColors.ink);
    });
  });

  group('BubbleFooterLayout', () {
    testWidgets('التذييل في الحافة الختامية — RTL يسار', (tester) async {
      await tester.pumpWidget(_host(BubbleFooterLayout(
        content: const SizedBox(key: Key('c'), width: 200, height: 40),
        footer: const SizedBox(key: Key('f'), width: 60, height: 14),
      )));
      final layout = tester.getRect(find.byType(BubbleFooterLayout));
      final c = tester.getRect(find.byKey(const Key('c')));
      final f = tester.getRect(find.byKey(const Key('f')));
      expect(layout.width, 200); // لا تمدد لأقصى عرض
      expect(c.right, layout.right); // المحتوى في البداية (يمين)
      expect(f.left, layout.left); // التذييل في النهاية (يسار)
      expect(f.bottom, layout.bottom);
    });

    testWidgets('LTR: التذييل يمين، والعرض يتبع التذييل إن كان أعرض',
        (tester) async {
      await tester.pumpWidget(_host(
        BubbleFooterLayout(
          content: const SizedBox(key: Key('c'), width: 30, height: 20),
          footer: const SizedBox(key: Key('f'), width: 80, height: 14),
        ),
        dir: TextDirection.ltr,
      ));
      final layout = tester.getRect(find.byType(BubbleFooterLayout));
      final c = tester.getRect(find.byKey(const Key('c')));
      final f = tester.getRect(find.byKey(const Key('f')));
      expect(layout.width, 80);
      expect(c.left, layout.left);
      expect(f.right, layout.right);
    });
  });

  group('SwipeToReply', () {
    testWidgets('السحب نحو الداخل يتجاوز العتبة فيرد (RTL = نحو اليسار)',
        (tester) async {
      var replies = 0;
      await tester.pumpWidget(_host(SwipeToReply(
        onReply: () => replies++,
        child: const SizedBox(width: 200, height: 50, child: Text('رسالة')),
      )));
      await tester.drag(find.text('رسالة'), const Offset(-90, 0));
      await tester.pumpAndSettle();
      expect(replies, 1);
    });

    testWidgets('السحب القصير أو المعاكس لا يرد', (tester) async {
      var replies = 0;
      await tester.pumpWidget(_host(SwipeToReply(
        onReply: () => replies++,
        child: const SizedBox(width: 200, height: 50, child: Text('رسالة')),
      )));
      await tester.drag(find.text('رسالة'), const Offset(-30, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.text('رسالة'), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(replies, 0);
    });

    testWidgets('معطّل = بلا إيماءة', (tester) async {
      var replies = 0;
      await tester.pumpWidget(_host(SwipeToReply(
        enabled: false,
        onReply: () => replies++,
        child: const SizedBox(width: 200, height: 50, child: Text('رسالة')),
      )));
      await tester.drag(find.text('رسالة'), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(replies, 0);
    });
  });

  group('JumpToBottomButton', () {
    testWidgets('يعرض عدد الجديد ووصفاً لقارئ الشاشة', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(JumpToBottomButton(
        visible: true,
        unread: 3,
        onPressed: () => taps++,
      )));
      expect(find.text('3'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('أحدث الرسائل — 3')), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      expect(taps, 1);
      expect(tester.getSize(find.byType(InkWell)).width,
          greaterThanOrEqualTo(WaslSize.minTap));
    });

    testWidgets('مخفي = لا يستقبل اللمس', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(JumpToBottomButton(
        visible: false,
        unread: 0,
        onPressed: () => taps++,
      )));
      await tester.tap(find.byType(InkWell), warnIfMissed: false);
      expect(taps, 0);
    });
  });
}
