/// الموقع المباشر: ترميز الوسم داخل وصف رسالة الموقع (يُشفَّر مع الرسالة كلها)،
/// فلا يحتاج الخادم أي تغيير ولا يرى الإحداثيات.
/// الحد الصادق: التحديث يعمل والمحادثة مفتوحة على جهاز المرسل فقط (بلا خدمة
/// خلفية)، لذا يظهر للمستلم «آخر تحديث قبل …» إذا توقفت التحديثات.
class LiveTag {
  final String sid;
  final DateTime until;
  final bool ended;
  final String label;
  const LiveTag(this.sid, this.until, this.ended, this.label);
}

class LiveLocationService {
  static const _mark = '\u2063';
  static const intervalSeconds = 30;
  static const durationsMinutes = [15, 60, 480];

  /// لفّ وصف الموقع بوسم المشاركة المباشرة.
  static String wrap(String sid, DateTime until, bool ended, String label) =>
      '$_mark' 'live:$sid:${until.millisecondsSinceEpoch}:${ended ? 1 : 0}$_mark$label';

  /// يعيد null إن لم يكن الوصف مباشراً.
  static LiveTag? parse(String label) {
    if (!label.startsWith(_mark)) return null;
    final end = label.indexOf(_mark, 1);
    if (end < 0) return null;
    final p = label.substring(1, end).split(':');
    if (p.length != 4 || p[0] != 'live') return null;
    final ms = int.tryParse(p[2]);
    if (ms == null) return null;
    return LiveTag(p[1], DateTime.fromMillisecondsSinceEpoch(ms), p[3] == '1',
        label.substring(end + 1));
  }

  /// حالة العرض للمستلم/المرسل.
  static LiveState stateOf(LiveTag t, DateTime sentAt, DateTime now) {
    if (t.ended) return LiveState.ended;
    if (!now.isBefore(t.until)) return LiveState.expired;
    if (now.difference(sentAt) > const Duration(minutes: 3)) return LiveState.stale;
    return LiveState.live;
  }

  /// يُبقي أحدث تحديث فقط لكل جلسة مباشرة؛ بقية الرسائل كما هي.
  static List<Map<String, dynamic>> collapse(
      List<Map<String, dynamic>> msgs, String? Function(Map<String, dynamic>) textOf,
      (double, double, String)? Function(String) locParts) {
    final lastIdx = <String, int>{};
    final sids = <int, String>{};
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      if (m['type'] != 'location') continue;
      final loc = locParts(textOf(m) ?? '');
      if (loc == null) continue;
      final t = parse(loc.$3);
      if (t == null) continue;
      sids[i] = t.sid;
      lastIdx[t.sid] = i;
    }
    return [
      for (var i = 0; i < msgs.length; i++)
        if (!sids.containsKey(i) || lastIdx[sids[i]] == i) msgs[i]
    ];
  }
}

enum LiveState { live, stale, ended, expired }
