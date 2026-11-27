import 'package:flutter_test/flutter_test.dart';
import 'package:wasl_chat/services/channel_stats_service.dart';
import 'package:wasl_chat/services/message_buttons.dart';

void main() {
  test('groupButtonStats groups by message and sorts by index', () {
    final g = ChannelStatsService.groupButtonStats([
      {'message_id': 'a', 'btn_idx': 1, 'label': 'ب', 'clicks': 3},
      {'message_id': 'a', 'btn_idx': 0, 'label': 'أ', 'clicks': 1},
      {'message_id': 'b', 'btn_idx': 0, 'label': 'ج', 'clicks': 0},
      {'btn_idx': 0},
    ]);
    expect(g.keys, ['a', 'b']);
    expect(g['a']!.map((e) => e.index), [0, 1]);
    expect(g['a']!.first.clicks, 1);
  });

  test('clicksLabel uses correct Arabic plurals', () {
    String l(int n) => ChannelStatsService.clicksLabel(ButtonClickStat(0, 'افتح', n));
    expect(l(0), 'افتح: لا نقرات');
    expect(l(1), 'افتح: نقرة واحدة');
    expect(l(2), 'افتح: نقرتان');
    expect(l(5).contains('نقرات'), isTrue);
    expect(l(20).endsWith('نقرة'), isTrue);
  });

  test('parseIndexed keeps original positions past invalid items', () {
    final r = MessageButton.parseIndexed([
      {'label': 'x', 'kind': 'bad', 'value': 'y'},
      {'label': 'ok', 'kind': 'copy', 'value': 'v'},
    ]);
    expect(r.length, 1);
    expect(r.first.$1, 1);
  });
}
