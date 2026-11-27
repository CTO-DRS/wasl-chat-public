import 'package:flutter_test/flutter_test.dart';
import 'package:wasl_chat/services/album_service.dart';
import 'package:wasl_chat/services/daily_summary_service.dart';
import 'package:wasl_chat/services/live_location_service.dart';
import 'package:wasl_chat/services/message_buttons.dart';
import 'package:wasl_chat/services/missed_summary_service.dart';
import 'package:wasl_chat/services/semantic_search_service.dart';

/// ميزانيات أداء على 5000 رسالة اصطناعية للمسارات التي تعمل على كل بناء
/// للقائمة. الأرقام هنا زمن CPU على بيئة البناء وليست زمن إطار على جهاز:
/// الميزانيات كريمة عمداً (تلتقط الانحدار الأسّي لا الاهتزاز) ولا تغني عن
/// قياس جهاز حقيقي.
void main() {
  const n = 5000;
  final base = DateTime(2026, 11, 27, 9).toUtc();
  final msgs = <Map<String, dynamic>>[
    for (var i = 0; i < n; i++)
      {
        'id': 'm$i',
        'sender_id': 'u${i % 7}',
        'type': i % 25 == 0 ? 'location' : (i % 9 == 0 ? 'image' : 'text'),
        'content': i % 25 == 0
            ? '24.4686,39.6142|${LiveLocationService.wrap('s${i % 3}', base.add(const Duration(hours: 8)), false, 'موقعي المباشر')}'
            : 'رسالة رقم $i عن الاجتماع غداً والمشروع الجديد؟ https://example.com/$i',
        'created_at': base.add(Duration(seconds: i * 30)).toIso8601String(),
        if (i % 9 == 0 && i % 25 != 0) 'media_group_id': 'g${i ~/ 45}',
        if (i % 40 == 0) 'buttons': [
          {'label': 'افتح', 'kind': 'url', 'value': 'https://a.com/$i'}
        ],
      }
  ];

  int time(void Function() f) {
    final w = Stopwatch()..start();
    f();
    return w.elapsedMilliseconds;
  }

  (double, double, String)? parts(String raw) {
    final p = raw.split('|');
    final c = p.first.split(',');
    return (double.parse(c[0]), double.parse(c[1]), p.sublist(1).join('|'));
  }

  test('تجميع الألبومات على 5000 رسالة', () {
    final ms = time(() => AlbumService.group(msgs));
    // ignore: avoid_print
    print('AlbumService.group: ${ms}ms');
    expect(ms, lessThan(500));
  });

  test('طي الموقع المباشر على 5000 رسالة', () {
    late List<Map<String, dynamic>> out;
    final ms = time(() =>
        out = LiveLocationService.collapse(msgs, (m) => m['content'] as String, parts));
    // ignore: avoid_print
    print('LiveLocationService.collapse: ${ms}ms (${msgs.length} -> ${out.length})');
    expect(ms, lessThan(500));
    expect(out.length, lessThan(msgs.length));
  });

  test('تفكيك الأزرار لكل الرسائل', () {
    final ms = time(() {
      for (final m in msgs) {
        MessageButton.parseAll(m['buttons']);
      }
    });
    // ignore: avoid_print
    print('MessageButton.parseAll x$n: ${ms}ms');
    expect(ms, lessThan(300));
  });

  test('ما فاتني والملخص اليومي على 5000 سطر', () {
    final missed = [
      for (final m in msgs.where((m) => m['type'] == 'text'))
        MissedLine(who: m['sender_id'] as String, text: m['content'] as String)
    ];
    final daily = [for (final l in missed) DailyLine(who: l.who, text: l.text)];
    final a = time(() => MissedSummaryService.build(missed));
    final b = time(() => DailySummaryService.build(daily, base));
    // ignore: avoid_print
    print('Missed: ${a}ms, Daily: ${b}ms');
    expect(a, lessThan(1500));
    expect(b, lessThan(1500));
  });

  test('تقطيع نصوص البحث الدلالي على 5000 رسالة', () {
    final ms = time(() {
      for (final m in msgs) {
        SemanticSearchService.tokens(m['content'] as String);
      }
    });
    // ignore: avoid_print
    print('SemanticSearch.tokens x$n: ${ms}ms');
    expect(ms, lessThan(1500));
  });
}
