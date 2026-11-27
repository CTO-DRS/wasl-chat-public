import '../config.dart';

/// إحصاءات المشاهدة للقنوات الكبيرة (المرحلة 4).
///
/// كل عضو قناة يسجَّل مشاهدته لكل منشور مرة واحدة (صف في channel_post_views)،
/// والعدّاد يظهر لكل أعضاء القناة تحت كل منشور، وإحصاءات موسعة (المتوسط
/// والإجمالي وآخر 30 منشوراً) تقرؤها إدارة القناة فقط من الخادم.
class ChannelStatsService {
  ChannelStatsService._();

  /// تسجيل مشاهدتي لهذه المنشورات (يستدعى عند عرضها في شاشة القناة)
  static Future<void> trackViews(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    try {
      await supabase.rpc('channel_track_views', params: {'p_ids': messageIds});
    } catch (_) {
      // بلا ترحيل 025: تجاهل صامت — العدّاد ميزة إضافية لا تعطيل للعرض
    }
  }

  /// عدّادات المشاهدة لرسائل دفعة واحدة: message_id -> عدد المشاهدات
  static Future<Map<String, int>> counts(List<String> messageIds) async {
    if (messageIds.isEmpty) return {};
    try {
      final data = await supabase.rpc('channel_view_counts',
          params: {'p_ids': messageIds});
      final map = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(data as List)) {
        map[row['message_id'] as String] = (row['views'] as num?)?.toInt() ?? 0;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// إحصاءات القناة الكاملة (لمشرفيها): أول صف يحمل الإجماليات والبقية منشورات
  static Future<List<Map<String, dynamic>>> stats(String convId) async {
    final data =
        await supabase.rpc('channel_stats', params: {'p_conv': convId});
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// تسجيل نقرة زر (مرة لكل مستخدم/زر في الخادم) — صامتة عند الفشل
  static Future<void> trackButtonClick(String messageId, int index) async {
    try {
      await supabase.rpc('track_button_click',
          params: {'p_msg': messageId, 'p_idx': index});
    } catch (_) {}
  }

  /// نقرات أزرار آخر 30 منشوراً (للمشرفين): معرف الرسالة -> أزرارها بعدّاداتها
  static Future<Map<String, List<ButtonClickStat>>> buttonStats(String convId) async {
    try {
      final data = await supabase
          .rpc('channel_button_stats', params: {'p_conv': convId});
      return groupButtonStats(List<Map<String, dynamic>>.from(data as List));
    } catch (_) {
      return {};
    }
  }

  static Map<String, List<ButtonClickStat>> groupButtonStats(
      List<Map<String, dynamic>> rows) {
    final out = <String, List<ButtonClickStat>>{};
    for (final r in rows) {
      final id = r['message_id'] as String?;
      if (id == null) continue;
      (out[id] ??= []).add(ButtonClickStat(
          (r['btn_idx'] as num?)?.toInt() ?? 0,
          (r['label'] as String?) ?? '',
          (r['clicks'] as num?)?.toInt() ?? 0));
    }
    for (final l in out.values) {
      l.sort((a, b) => a.index.compareTo(b.index));
    }
    return out;
  }

  /// سطر نقرات الزر: «افتح: 12 نقرة» بجمع عربي سليم
  static String clicksLabel(ButtonClickStat s) {
    final n = s.clicks;
    final t = n == 0
        ? 'لا نقرات'
        : n == 1
            ? 'نقرة واحدة'
            : n == 2
                ? 'نقرتان'
                : n < 11
                    ? '${formatCount(n)} نقرات'
                    : '${formatCount(n)} نقرة';
    return '${s.label}: $t';
  }

  // ---------- مساعدات عرض نقية (مُختبَرة) ----------

  /// تنسيق الأعداد العربية: 999 / 1.2 ألف / 3.4 مليون
  static String formatCount(num n) {
    if (n < 0) return '0';
    if (n < 1000) return n.round().toString();
    if (n < 1000000) {
      final v = n / 1000;
      return '${_trim(v)} ألف';
    }
    final m = n / 1000000;
    return '${_trim(m)} مليون';
  }

  /// قصّ الصفر الزائد: 1.0 -> 1 ، 1.25 -> 1.3 (منزلة واحدة تكفي للعدّادات)
  static String _trim(num v) {
    var s = v.toStringAsFixed(1);
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
    return s;
  }

  /// سطر المشاهدات تحت المنشور: «1.2 ألف مشاهدة» بجمع عربي سليم
  static String viewsLabel(num views) {
    if (views <= 0) return 'لا مشاهدات';
    if (views == 1) return 'مشاهدة واحدة';
    if (views == 2) return 'مشاهدتان';
    if (views < 11) return '${formatCount(views)} مشاهدات';
    return '${formatCount(views)} مشاهدة';
  }

  /// سطر متوسط المشاهدات في ورقة الإحصاءات
  static String averageLabel(num avg) {
    if (avg <= 0) return 'لا مشاهدات بعد';
    return 'متوسط ${viewsLabel(avg)} للمنشور';
  }
}

/// عدّاد نقرات زر واحد في منشور قناة.
class ButtonClickStat {
  const ButtonClickStat(this.index, this.label, this.clicks);
  final int index;
  final String label;
  final int clicks;
}
