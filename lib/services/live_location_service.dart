import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:geolocator/geolocator.dart';

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

/// طلب صلاحية الموقع أثناء الاستخدام قبل أي قراءة GPS.
Future<bool> ensureLocationPermission() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  } catch (_) {
    return false;
  }
}

/// جلسة مشاركة واحدة نشطة؛ تعيش خارج شاشة المحادثة حتى لا تتوقف بمغادرتها.
class LiveSession {
  LiveSession(this.conversationId, this.sid, this.until, this.send);
  final String conversationId;
  final String sid;
  final DateTime until;
  /// يرسل تحديثاً مشفراً بوصف موسوم جاهز.
  final Future<bool> Function(double lat, double lng, String label) send;
  Timer? timer;
  StreamSubscription<Position>? sub;
  Position? last;
  Position? lastSent;
  DateTime? lastSentAt;
  int failures = 0;
}

/// خدمة الموقع المباشر: تدفق موقع بخدمة أمامية (إشعار دائم) يُبقي العملية
/// حيّة والتطبيق في الخلفية. موفّرة للبطارية: دقة متوسطة، فلتر مسافة 25م،
/// وإرسال فقط عند التحرك 15م أو كل دقيقتين كحد أقصى للصمت.
/// حدود أندرويد الصادقة: السحب من قائمة التطبيقات الأخيرة أو إيقاف النظام
/// للتطبيق قد يقطع التحديثات؛ يرى المستلم حينها «توقفت التحديثات».
class LiveShare {
  static const tickSeconds = 30;
  static const maxSilence = Duration(minutes: 2);
  static const minMoveMeters = 15.0;
  static const maxFailures = 6;

  /// المحادثة المشاركة حالياً (null = لا مشاركة).
  static final ValueNotifier<String?> activeConversation = ValueNotifier(null);
  static LiveSession? _s;

  static bool isActiveIn(String conversationId) =>
      _s?.conversationId == conversationId;

  /// يبدأ جلسة (يوقف أي جلسة سابقة). يعيد false إن تعذّر أول إرسال.
  static Future<bool> start(String conversationId, int minutes,
      Future<bool> Function(double, double, String) send) async {
    await stop();
    final s = LiveSession(
        conversationId,
        DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        DateTime.now().add(Duration(minutes: minutes)),
        send);
    s.sub = Geolocator.getPositionStream(
            locationSettings: AndroidSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 25,
      intervalDuration: const Duration(seconds: tickSeconds),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'وصل شات · موقعك مباشر',
        notificationText: 'تتم مشاركة موقعك الآن. افتح وصل شات لإيقاف المشاركة.',
        notificationChannelName: 'مشاركة الموقع',
        setOngoing: true,
      ),
    ))
        .listen((p) => s.last = p, onError: (_) {});
    _s = s;
    activeConversation.value = conversationId;
    final ok = await _tick(s, force: true);
    if (!ok) {
      await stop(sendEnd: false);
      return false;
    }
    s.timer = Timer.periodic(const Duration(seconds: tickSeconds), (_) async {
      if (_s != s) return;
      if (!DateTime.now().isBefore(s.until) || s.failures >= maxFailures) {
        await stop();
        return;
      }
      await _tick(s);
    });
    return true;
  }

  static Future<bool> _tick(LiveSession s, {bool force = false, bool ended = false}) async {
    try {
      final p = s.last ??
          await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.medium,
                  timeLimit: Duration(seconds: 12)));
      final moved = s.lastSent == null
          ? double.infinity
          : Geolocator.distanceBetween(s.lastSent!.latitude,
              s.lastSent!.longitude, p.latitude, p.longitude);
      final quiet = s.lastSentAt == null ||
          DateTime.now().difference(s.lastSentAt!) >= maxSilence;
      if (!force && !ended && moved < minMoveMeters && !quiet) return true;
      double r6(double v) => (v * 1e6).round() / 1e6;
      final ok = await s.send(r6(p.latitude), r6(p.longitude),
          LiveLocationService.wrap(s.sid, s.until, ended, 'موقعي المباشر'));
      if (ok) {
        s.failures = 0;
        s.lastSent = p;
        s.lastSentAt = DateTime.now();
      } else {
        s.failures++;
      }
      return ok;
    } catch (_) {
      s.failures++;
      return false;
    }
  }

  /// إيقاف يدوي أو تلقائي؛ يرسل تحديث «انتهت» ثم يُغلق الخدمة والإشعار.
  static Future<void> stop({bool sendEnd = true}) async {
    final s = _s;
    if (s == null) return;
    _s = null;
    s.timer?.cancel();
    if (sendEnd) await _tick(s, force: true, ended: true);
    await s.sub?.cancel();
    activeConversation.value = null;
  }
}

enum LiveState { live, stale, ended, expired }
