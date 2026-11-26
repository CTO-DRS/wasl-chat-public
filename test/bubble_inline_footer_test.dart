/// الوقت المضمّن في الفقاعة (2.5.0 — ج3) بأسلوب واتساب/تيليجرام: التذييل
/// يجلس على السطر الأخير إن اتسع، وإلا ينزل لسطر مستقل في الحافة الختامية.
/// خط الاختبار مربّع: عرض كل محرف = حجم الخط، فالقياسات حتمية.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wasl_chat/widgets/bubble_layout.dart';

const _fKey = Key('footer');
const _tKey = Key('text');

Widget _bubble(
  String text, {
  TextDirection dir = TextDirection.rtl,
  double maxWidth = 260,
  double fontSize = 20,
  double scale = 1.0,
  Widget? after,
  bool anchored = true,
}) {
  Widget t = Text(
    text,
    key: _tKey,
    style: TextStyle(fontSize: fontSize),
  );
  if (anchored) t = BubbleInlineAnchor(child: t);
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: dir,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: BubbleFooterLayout(
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [t, ?after],
              ),
              footer: const SizedBox(key: _fKey, width: 60, height: 14),
            ),
          ),
        ),
      ),
    ),
  );
}

RenderBubbleFooter _render(WidgetTester t) =>
    t.renderObject<RenderBubbleFooter>(find.byType(BubbleFooterLayout));

void main() {
  testWidgets('نص قصير RTL: الوقت على السطر نفسه يساراً بلا تداخل', (
    tester,
  ) async {
    await tester.pumpWidget(_bubble('hi')); // 2 × 20 = 40
    final layout = tester.getRect(find.byType(BubbleFooterLayout));
    final text = tester.getRect(find.byKey(_tKey));
    final f = tester.getRect(find.byKey(_fKey));
    expect(_render(tester).isInline, isTrue);
    expect(layout.height, text.height); // لا سطر إضافي
    expect(layout.width, 100); // 40 نص + 60 تذييل
    expect(text.right, layout.right); // النص في البداية (يمين)
    expect(f.left, layout.left); // الوقت في النهاية (يسار)
    expect(f.right, lessThanOrEqualTo(text.left));
    expect(f.bottom, layout.bottom);
  });

  testWidgets('نص قصير LTR: الوقت على السطر نفسه يميناً', (tester) async {
    await tester.pumpWidget(_bubble('hello', dir: TextDirection.ltr));
    final layout = tester.getRect(find.byType(BubbleFooterLayout));
    final text = tester.getRect(find.byKey(_tKey));
    final f = tester.getRect(find.byKey(_fKey));
    expect(_render(tester).isInline, isTrue);
    expect(layout.height, text.height);
    expect(text.left, layout.left);
    expect(f.right, layout.right);
    expect(f.left, greaterThanOrEqualTo(text.right));
  });

  testWidgets('سطر أخير ممتلئ: الوقت ينزل لسطر مستقل في الحافة الختامية', (
    tester,
  ) async {
    await tester.pumpWidget(_bubble('x' * 13)); // 260 = أقصى عرض
    final layout = tester.getRect(find.byType(BubbleFooterLayout));
    final text = tester.getRect(find.byKey(_tKey));
    final f = tester.getRect(find.byKey(_fKey));
    expect(_render(tester).isInline, isFalse);
    expect(layout.width, 260);
    expect(layout.height, text.height + 14);
    expect(f.top, text.bottom);
    expect(f.left, layout.left);
  });

  testWidgets('نص ملفوف بسطر أخير قصير: الوقت على السطر الأخير لا تحته', (
    tester,
  ) async {
    // السطر الأول 12 محرفاً (240)، والأخير «xx» (40) — في RTL يلتصق يميناً
    await tester.pumpWidget(_bubble('xxxxxxxxxxxx xx'));
    final layout = tester.getRect(find.byType(BubbleFooterLayout));
    final text = tester.getRect(find.byKey(_tKey));
    final f = tester.getRect(find.byKey(_fKey));
    expect(text.height, 40); // سطران
    expect(_render(tester).isInline, isTrue);
    expect(layout.height, 40);
    expect(f.bottom, layout.bottom);
    expect(f.left, layout.left);
    // لا تداخل مع السطر الأخير (يشغل يمين النص بعرض 40)
    expect(f.right, lessThanOrEqualTo(text.right - 40));
  });

  testWidgets('نص عربي مختلط بالإنجليزية وإيموجي في RTL: مضمّن بلا تداخل', (
    tester,
  ) async {
    await tester.pumpWidget(_bubble('مرحبا Flutter 👋', fontSize: 12));
    final layout = tester.getRect(find.byType(BubbleFooterLayout));
    final text = tester.getRect(find.byKey(_tKey));
    final f = tester.getRect(find.byKey(_fKey));
    expect(_render(tester).isInline, isTrue);
    expect(f.right, lessThanOrEqualTo(text.left + 0.01));
    // التذييل (14) أطول من السطر (12): الارتفاع للأطول لا للمجموع
    expect(layout.height, 14);
  });

  testWidgets('نص إنجليزي داخل واجهة عربية بسطر أخير طويل يلتف', (
    tester,
  ) async {
    await tester.pumpWidget(_bubble('aaaaaaaaaaaa aaaaaaaaaaa'));
    final layout = tester.getRect(find.byType(BubbleFooterLayout));
    final text = tester.getRect(find.byKey(_tKey));
    expect(_render(tester).isInline, isFalse);
    expect(layout.height, text.height + 14);
  });

  testWidgets('مقياس نص كبير: يُحترم في القرار', (tester) async {
    // 5 محارف × 14 × 2 = 140 + 60 = 200 ≤ 260 → مضمّن
    await tester.pumpWidget(_bubble('hello', fontSize: 14, scale: 2));
    expect(_render(tester).isInline, isTrue);
    final layout = tester.getRect(find.byType(BubbleFooterLayout));
    expect(layout.width, 200);
    // × 3 = 210 + 60 = 270 > 260 → سطر مستقل
    await tester.pumpWidget(_bubble('hello', fontSize: 14, scale: 3));
    expect(_render(tester).isInline, isFalse);
    final text = tester.getRect(find.byKey(_tKey));
    final layout3 = tester.getRect(find.byType(BubbleFooterLayout));
    expect(layout3.height, text.height + 14);
  });

  testWidgets('معاينة رابط/ترجمة بعد النص: الوقت تحت الكل كما كان', (
    tester,
  ) async {
    await tester.pumpWidget(
      _bubble(
        'hi',
        after: const SizedBox(key: Key('preview'), width: 200, height: 50),
      ),
    );
    final layout = tester.getRect(find.byType(BubbleFooterLayout));
    final p = tester.getRect(find.byKey(const Key('preview')));
    final f = tester.getRect(find.byKey(_fKey));
    expect(_render(tester).isInline, isFalse);
    expect(f.top, p.bottom);
    expect(f.bottom, layout.bottom);
  });

  testWidgets('بلا مرساة (صوت/وسائط): لا تغيير عن التخطيط المكدّس', (
    tester,
  ) async {
    await tester.pumpWidget(_bubble('hi', anchored: false));
    final layout = tester.getRect(find.byType(BubbleFooterLayout));
    final text = tester.getRect(find.byKey(_tKey));
    expect(_render(tester).isInline, isFalse);
    expect(layout.height, text.height + 14);
  });

  testWidgets('تغيّر النص يعيد القرار (طويل ← قصير)', (tester) async {
    await tester.pumpWidget(_bubble('x' * 13));
    expect(_render(tester).isInline, isFalse);
    await tester.pumpWidget(_bubble('ok'));
    expect(_render(tester).isInline, isTrue);
  });

  testWidgets('LTR بسطر أخير ممتلئ: الوقت تحته يميناً', (tester) async {
    await tester.pumpWidget(
      _bubble('xxxxxxxxxxxx xxxxxxxxxxxx', dir: TextDirection.ltr),
    );
    final layout = tester.getRect(find.byType(BubbleFooterLayout));
    final text = tester.getRect(find.byKey(_tKey));
    final f = tester.getRect(find.byKey(_fKey));
    expect(_render(tester).isInline, isFalse);
    expect(f.top, text.bottom);
    expect(f.right, layout.right);
  });

  testWidgets('LayoutBuilder داخل المحتوى (كمعاينة الروابط) لا ينهار', (
    tester,
  ) async {
    await tester.pumpWidget(
      _bubble(
        'hi',
        after: LayoutBuilder(
          builder: (context, c) =>
              SizedBox(width: c.maxWidth.clamp(0, 200).toDouble(), height: 40),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(_render(tester).isInline, isFalse);
  });
}
