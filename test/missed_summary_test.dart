import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wasl_chat/theme.dart';

import 'support/render_harness.dart';
import 'package:wasl_chat/services/missed_summary_service.dart';

void main() {
  test('لا رسائل = null', () {
    expect(MissedSummaryService.build(const []), isNull);
  });

  test('رسالة واحدة من شخص واحد', () {
    final s = MissedSummaryService.build(
        const [MissedLine(who: 'سارة', text: 'وصلت بالسلامة')])!;
    expect(s, startsWith('فاتك 1 رسالة من سارة'));
  });

  test('عدّاد وأكثر مرسل وأسئلة وروابط ووسائط', () {
    final s = MissedSummaryService.build(const [
      MissedLine(who: 'أحمد', text: 'متى الاجتماع؟'),
      MissedLine(who: 'أحمد', text: 'https://example.com/doc'),
      MissedLine(who: 'سارة', text: 'غداً الساعة العاشرة'),
      MissedLine(who: 'سارة', text: '[وسائط]', isMedia: true),
    ])!;
    expect(s, contains('فاتك 4 رسائل من 2 أشخاص، أكثرهم أحمد (2)'));
    expect(s, contains('وسائط (1) · رابط (1)'));
    expect(s, contains('أسئلة مطروحة:'));
    expect(s, contains('• أحمد: متى الاجتماع؟'));
    expect('متى الاجتماع؟'.allMatches(s).length, 1);
  });

  test('وسائط فقط تعطي عدّاداً بلا أسطر مبتورة', () {
    final s = MissedSummaryService.build(const [
      MissedLine(who: 'سارة', text: '[وسائط]', isMedia: true),
    ])!;
    expect(s, contains('وسائط (1)'));
    expect(s, isNot(contains('أسئلة')));
  });

  test('سؤال طويل يُقصّ', () {
    final s = MissedSummaryService.build([
      MissedLine(who: 'أ', text: '${'كلمة ' * 60}؟'),
    ])!;
    expect(s, contains('…'));
  });

  testWidgets('لقطة ما فاتني', (tester) async {
    await loadRenderFonts();
    tester.view.physicalSize = const Size(390 * 3, 420 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final text = MissedSummaryService.build(const [
      MissedLine(who: 'أحمد', text: 'متى الاجتماع غداً؟'),
      MissedLine(who: 'أحمد', text: 'هذا الملف https://example.com/plan'),
      MissedLine(who: 'سارة', text: 'الاجتماع الساعة العاشرة صباحاً في المكتب'),
      MissedLine(who: 'سارة', text: '[وسائط]', isMedia: true),
      MissedLine(who: 'خالد', text: 'تمام، سأحضر المستندات'),
    ])!;
    await tester.pumpWidget(renderHarness(
        Scaffold(
          appBar: AppBar(title: const Text('ما فاتني — على جهازك')),
          body: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(text, style: const TextStyle(height: 1.8, fontSize: 15))),
        ),
        WaslTheme.dark));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/missed_summary_dark_ar.png'));
  });
}
