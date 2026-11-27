import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wasl_chat/services/live_location_service.dart';
import 'package:wasl_chat/theme.dart';
import 'package:wasl_chat/widgets/live_status_row.dart';

import 'support/render_harness.dart';

(double, double, String)? _parts(String raw) {
  final p = raw.split('|');
  final c = p.first.split(',');
  return (double.parse(c[0]), double.parse(c[1]), p.sublist(1).join('|'));
}

void main() {
  final until = DateTime(2026, 11, 27, 5, 0);
  test('ترميز وفك الوسم يحفظ الوصف', () {
    final w = LiveLocationService.wrap('abc', until, false, 'موقعي المباشر');
    final t = LiveLocationService.parse(w)!;
    expect(t.sid, 'abc');
    expect(t.until, until);
    expect(t.ended, false);
    expect(t.label, 'موقعي المباشر');
    expect(LiveLocationService.parse('مكتب'), isNull);
  });

  test('حالات العرض: مباشر ثم توقف ثم انتهاء', () {
    final sent = DateTime(2026, 11, 27, 4, 0);
    final t = LiveTag('a', until, false, '');
    expect(LiveLocationService.stateOf(t, sent, sent.add(const Duration(seconds: 40))), LiveState.live);
    expect(LiveLocationService.stateOf(t, sent, sent.add(const Duration(minutes: 5))), LiveState.stale);
    expect(LiveLocationService.stateOf(t, sent, until), LiveState.expired);
    expect(LiveLocationService.stateOf(LiveTag('a', until, true, ''), sent, sent), LiveState.ended);
  });

  test('تُطوى تحديثات الجلسة إلى الأحدث فقط وتبقى بقية الرسائل', () {
    String l(String sid, bool e) => '1,2|${LiveLocationService.wrap(sid, until, e, 'x')}';
    final msgs = [
      {'id': '1', 'type': 'location', 'content': l('a', false)},
      {'id': '2', 'type': 'text', 'content': 'hi'},
      {'id': '3', 'type': 'location', 'content': l('a', false)},
      {'id': '4', 'type': 'location', 'content': '1,2|مكتب'},
      {'id': '5', 'type': 'location', 'content': l('b', false)},
      {'id': '6', 'type': 'location', 'content': l('a', true)},
    ];
    final out = LiveLocationService.collapse(msgs, (m) => m['content'] as String, _parts);
    expect(out.map((m) => m['id']), ['2', '4', '5', '6']);
  });

  testWidgets('لقطة حالات الموقع المباشر', (tester) async {
    await loadRenderFonts();
    tester.view.physicalSize = const Size(390 * 3, 260 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(renderHarness(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final s in LiveState.values) ...[
                LiveStatusRow(s),
                const SizedBox(height: 16),
              ]
            ]),
          ),
        ),
        WaslTheme.dark));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold),
        matchesGoldenFile('goldens/live_status_dark_ar.png'));
  });
}
