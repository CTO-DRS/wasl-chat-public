import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wasl_chat/screens/business_replies_screen.dart';
import 'package:wasl_chat/services/business_reply_service.dart';
import 'package:wasl_chat/theme.dart';

import 'support/render_harness.dart';

const _price = ReplyTemplate(
    id: 't1', title: 'الأسعار', shortcut: 'سعر', text: 'أهلاً {name}، قائمة الأسعار عند {shop}.');
const _away = ReplyTemplate(
    id: 't2', title: 'غياب', shortcut: 'غياب', text: 'نرد عليك قريباً، شكراً لصبرك.');

void _seed() {
  BusinessReplyService.templates.value = const [_price, _away];
  BusinessReplyService.rules.value = const [
    AutoReplyRule(
        id: 'r1', kind: ReplyRuleKind.keyword, keywords: ['سعر', 'كم'], templateId: 't1'),
    AutoReplyRule(id: 'r2', kind: ReplyRuleKind.away, templateId: 't2'),
  ];
  BusinessReplyService.autoReplyEnabled.value = true;
  BusinessReplyService.vars
    ..['name'] = 'سامي'
    ..['shop'] = 'متجر الأمل';
  BusinessReplyService.resetSession();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    BusinessReplyService.templates.value = const [];
    BusinessReplyService.rules.value = const [];
    BusinessReplyService.autoReplyEnabled.value = false;
    BusinessReplyService.vars.clear();
    BusinessReplyService.providers.clear();
    BusinessReplyService.resetSession();
  });

  test('الاختصار بعد / يقترح القوالب، و/ وحدها تعرض الكل', () {
    _seed();
    final all = BusinessReplyService.templates.value;
    expect(BusinessReplyEngine.suggest(all, 'مرحبا'), isEmpty);
    expect(BusinessReplyEngine.suggest(all, '/').length, 2);
    expect(BusinessReplyEngine.suggest(all, '/سع').single.id, 't1');
    expect(BusinessReplyEngine.suggest(all, '/غيا').single.id, 't2');
    expect(BusinessReplyEngine.suggest(all, '/xyz'), isEmpty);
  });

  test('المطابقة تتجاهل التشكيل والهمزات وتفضّل الكلمات على الغياب', () {
    _seed();
    final r = BusinessReplyService.rules.value;
    expect(BusinessReplyEngine.match(r, 'كَمْ السِّعر؟')?.id, 'r1');
    expect(BusinessReplyEngine.match(r, 'هل أنتم موجودون')?.id, 'r2');
    expect(BusinessReplyEngine.match(const [], 'سعر'), isNull);
  });

  test('المتغيرات: ملفك ثم المزوّد الخارجي (نقطة ربط دفتر/سوبر بز)', () {
    _seed();
    BusinessReplyService.providers.add((v) => v == 'invoice_total' ? '1,250 ر.س' : null);
    expect(
        BusinessReplyEngine.render('{name} إجمالي فاتورتك {invoice_total} {unknown}',
            vars: BusinessReplyService.vars, providers: BusinessReplyService.providers),
        'سامي إجمالي فاتورتك 1,250 ر.س {unknown}');
  });

  test('الرد التلقائي: مرة لكل فترة تهدئة، لا يرد على ردّ تلقائي، ويحترم التعطيل', () {
    _seed();
    final t0 = DateTime(2026, 11, 26, 12);
    final r1 = BusinessReplyService.autoReplyFor('c1', 'كم السعر', now: t0);
    expect(r1, isNotNull);
    expect(r1, startsWith('أهلاً سامي، قائمة الأسعار عند متجر الأمل.'));
    expect(BusinessReplyEngine.isAutoReply(r1!), isTrue);
    BusinessReplyService.markAutoReplied('c1', now: t0);
    // داخل التهدئة: لا رد
    expect(BusinessReplyService.autoReplyFor('c1', 'كم السعر',
        now: t0.add(const Duration(minutes: 30))), isNull);
    // محادثة أخرى تردّ
    expect(BusinessReplyService.autoReplyFor('c2', 'سعر', now: t0), isNotNull);
    // بعد انتهاء التهدئة تردّ
    expect(BusinessReplyService.autoReplyFor('c1', 'سعر',
        now: t0.add(const Duration(hours: 2))), isNotNull);
    // رد تلقائي وارد لا يُرد عليه (منع الحلقات)
    expect(BusinessReplyService.autoReplyFor('c9', r1, now: t0), isNull);
    // معطّل
    BusinessReplyService.autoReplyEnabled.value = false;
    expect(BusinessReplyService.autoReplyFor('c3', 'سعر', now: t0), isNull);
  });

  test('الترميز JSON للقوالب والقواعد ذهاباً وإياباً', () {
    final j = _price.toJson();
    expect(ReplyTemplate.fromJson(j).text, _price.text);
    final r = AutoReplyRule(
        id: 'x', kind: ReplyRuleKind.keyword, keywords: ['أ'], templateId: 't1');
    expect(AutoReplyRule.fromJson(r.toJson()).keywords, ['أ']);
  });

  testWidgets('الشاشة: إضافة قالب من الحوار وحذفه', (tester) async {
    ignoreGlassTileAsserts();
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(renderHarness(const BusinessRepliesScreen(), WaslTheme.dark));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-template')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('tpl-title')), 'ساعات العمل');
    await tester.enterText(find.byKey(const ValueKey('tpl-short')), '/دوام');
    await tester.enterText(find.byKey(const ValueKey('tpl-text')), 'من 9 إلى 5');
    await tester.tap(find.byKey(const ValueKey('tpl-save')));
    await tester.pumpAndSettle();
    expect(BusinessReplyService.templates.value.single.shortcut, 'دوام');
    expect(find.text('ساعات العمل', skipOffstage: false), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(BusinessReplyService.templates.value, isEmpty);
  });

  for (final dark in [true, false]) {
    testWidgets('لقطة ردود الأعمال - ${dark ? 'داكن' : 'فاتح'}', (tester) async {
      ignoreGlassTileAsserts();
      await loadRenderFonts();
      tester.view.physicalSize = const Size(390 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      _seed();
      await tester.pumpWidget(renderHarness(
          const BusinessRepliesScreen(), dark ? WaslTheme.dark : WaslTheme.light));
      await tester.pumpAndSettle();
      await expectLater(find.byType(BusinessRepliesScreen),
          matchesGoldenFile('goldens/business_replies_${dark ? 'dark' : 'light'}_ar.png'));
    });
  }
}
