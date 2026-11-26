import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ردود الأعمال: قوالب سريعة + ردّ تلقائي بقواعد (كلمات مفتاحية / رسالة غياب).
///
/// التصميم الصادق:
/// - كل شيء يعمل **على جهازك**: الرسائل مشفّرة طرف لطرف، فلا يملك الخادم النص
///   ليرد عنك. لذلك يعمل الرد التلقائي **أثناء فتح التطبيق** (محادثة مفتوحة)،
///   لا والتطبيق مغلق — الحد موثّق في شاشة الإعداد.
/// - الرد التلقائي للمحادثات الخاصة فقط، مرة واحدة لكل محادثة خلال فترة
///   تهدئة، ولا يرد على ردّ تلقائي آخر (علامة غير مرئية تمنع الحلقات).
/// - [BusinessDataProvider] نقطة ربط جاهزة لدفتر وسوبر بز لاحقاً: أي تطبيق
///   يسجّل مزوّداً يحلّ متغيرات مثل {invoice_total} بقيم حقيقية.
class ReplyTemplate {
  final String id;
  final String title;
  final String text;
  /// اختصار بعد «/» في المحرر، مثل «سعر» لـ «/سعر»
  final String shortcut;
  const ReplyTemplate(
      {required this.id, required this.title, required this.text, this.shortcut = ''});

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'text': text, 'shortcut': shortcut};
  factory ReplyTemplate.fromJson(Map<String, dynamic> j) => ReplyTemplate(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      text: j['text'] as String? ?? '',
      shortcut: j['shortcut'] as String? ?? '');
}

enum ReplyRuleKind { keyword, away }

class AutoReplyRule {
  final String id;
  final ReplyRuleKind kind;
  final List<String> keywords;
  final String templateId;
  final bool enabled;
  const AutoReplyRule({
    required this.id,
    required this.kind,
    required this.templateId,
    this.keywords = const [],
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'keywords': keywords,
        'templateId': templateId,
        'enabled': enabled,
      };
  factory AutoReplyRule.fromJson(Map<String, dynamic> j) => AutoReplyRule(
        id: j['id'] as String,
        kind: j['kind'] == 'away' ? ReplyRuleKind.away : ReplyRuleKind.keyword,
        keywords: [for (final k in (j['keywords'] as List? ?? const [])) '$k'],
        templateId: j['templateId'] as String? ?? '',
        enabled: j['enabled'] as bool? ?? true,
      );
}

/// مزوّد بيانات خارجي (دفتر/سوبر بز لاحقاً): يحلّ اسم متغير إلى نص.
typedef BusinessDataProvider = String? Function(String variable);

class BusinessReplyEngine {
  /// علامة غير مرئية تُلحق بكل رد تلقائي لمنع حلقات الرد بين تطبيقين.
  static const autoMark = '\u200B\u2063';

  static bool isAutoReply(String text) => text.endsWith(autoMark);

  static String normalize(String s) => s
      .replaceAll(RegExp('[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .toLowerCase()
      .trim();

  /// يملأ {name} و{shop} وأي متغير سجّله مزوّد؛ المجهول يبقى كما هو ظاهراً.
  static String render(String text,
      {Map<String, String> vars = const {}, List<BusinessDataProvider> providers = const []}) {
    return text.replaceAllMapped(RegExp(r'\{([a-z_]+)\}'), (m) {
      final k = m.group(1)!;
      if (vars.containsKey(k)) return vars[k]!;
      for (final p in providers) {
        final v = p(k);
        if (v != null) return v;
      }
      return m.group(0)!;
    });
  }

  /// قوالب تطابق ما بعد «/» (اختصاراً أو عنواناً)؛ «/» وحدها تعرض الكل.
  static List<ReplyTemplate> suggest(List<ReplyTemplate> all, String input) {
    if (!input.startsWith('/')) return const [];
    final q = normalize(input.substring(1));
    if (q.isEmpty) return all;
    return [
      for (final t in all)
        if (normalize(t.shortcut).startsWith(q) || normalize(t.title).contains(q)) t
    ];
  }

  /// القاعدة المطابقة لرسالة واردة (الكلمات أولاً ثم الغياب)، أو null.
  static AutoReplyRule? match(List<AutoReplyRule> rules, String incoming) {
    if (isAutoReply(incoming)) return null;
    final n = normalize(incoming);
    if (n.isEmpty) return null;
    for (final r in rules) {
      if (!r.enabled || r.kind != ReplyRuleKind.keyword) continue;
      for (final k in r.keywords) {
        final kk = normalize(k);
        if (kk.isNotEmpty && n.contains(kk)) return r;
      }
    }
    for (final r in rules) {
      if (r.enabled && r.kind == ReplyRuleKind.away) return r;
    }
    return null;
  }
}

class BusinessReplyService {
  BusinessReplyService._();
  static const _store = FlutterSecureStorage();
  static const _key = 'wasl_business_replies_v1';

  static final templates = ValueNotifier<List<ReplyTemplate>>(const []);
  static final rules = ValueNotifier<List<AutoReplyRule>>(const []);
  static final autoReplyEnabled = ValueNotifier<bool>(false);
  static final providers = <BusinessDataProvider>[];

  /// ملء {name}/{shop} من ملفك الشخصي (يضبطه التطبيق بعد الدخول)
  static final vars = <String, String>{};

  /// آخر رد تلقائي لكل محادثة (جلسة التطبيق) — فترة التهدئة
  static final Map<String, DateTime> _lastAuto = {};
  static const cooldown = Duration(hours: 1);

  static bool canAutoReply(String conversationId, {DateTime? now}) {
    final t = _lastAuto[conversationId];
    return t == null || (now ?? DateTime.now()).difference(t) >= cooldown;
  }

  static void markAutoReplied(String conversationId, {DateTime? now}) =>
      _lastAuto[conversationId] = now ?? DateTime.now();

  static void resetSession() => _lastAuto.clear();

  static Future<void> load() async {
    try {
      final raw = await _store.read(key: _key);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      templates.value = [
        for (final t in (j['templates'] as List? ?? const []))
          ReplyTemplate.fromJson(Map<String, dynamic>.from(t as Map))
      ];
      rules.value = [
        for (final r in (j['rules'] as List? ?? const []))
          AutoReplyRule.fromJson(Map<String, dynamic>.from(r as Map))
      ];
      autoReplyEnabled.value = j['enabled'] as bool? ?? false;
    } catch (_) {}
  }

  static Future<void> save() async {
    try {
      await _store.write(
          key: _key,
          value: jsonEncode({
            'templates': [for (final t in templates.value) t.toJson()],
            'rules': [for (final r in rules.value) r.toJson()],
            'enabled': autoReplyEnabled.value,
          }));
    } catch (_) {}
  }

  /// نص الرد التلقائي لرسالة واردة، أو null إن لم يجب الرد.
  static String? autoReplyFor(String conversationId, String incoming, {DateTime? now}) {
    if (!autoReplyEnabled.value || !canAutoReply(conversationId, now: now)) return null;
    final rule = BusinessReplyEngine.match(rules.value, incoming);
    if (rule == null) return null;
    final tpl = templates.value.where((t) => t.id == rule.templateId).firstOrNull;
    if (tpl == null || tpl.text.trim().isEmpty) return null;
    return BusinessReplyEngine.render(tpl.text, vars: vars, providers: providers) +
        BusinessReplyEngine.autoMark;
  }
}
