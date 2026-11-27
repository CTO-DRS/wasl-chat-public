/// أزرار الرسائل التفاعلية (القنوات): رابط https أو نسخ نص. بلا تنفيذ خادمي.
/// الحدود نفسها يفرضها الخادم (ترحيل 049)، والتحليل هنا دفاعي: العنصر الفاسد يُسقط.
enum ButtonKind { url, copy }

class MessageButton {
  const MessageButton(this.label, this.kind, this.value);
  final String label;
  final ButtonKind kind;
  final String value;

  static const maxButtons = 4;
  static const maxLabel = 24;
  static const maxValue = 500;

  Map<String, dynamic> toJson() => {'label': label, 'kind': kind.name, 'value': value};

  /// يعيد null إن كان العنصر غير صالح (تسمية فارغة/طويلة، نوع مجهول، رابط غير https).
  static MessageButton? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final label = (raw['label'] as String?)?.trim() ?? '';
    final value = (raw['value'] as String?)?.trim() ?? '';
    final kind = switch (raw['kind']) {
      'url' => ButtonKind.url,
      'copy' => ButtonKind.copy,
      _ => null,
    };
    if (kind == null) return null;
    if (label.isEmpty || label.length > maxLabel) return null;
    if (value.isEmpty || value.length > maxValue) return null;
    if (kind == ButtonKind.url && !validUrl(value)) return null;
    return MessageButton(label, kind, value);
  }

  static bool validUrl(String v) {
    final u = Uri.tryParse(v);
    return u != null && u.scheme == 'https' && u.host.contains('.');
  }

  /// يحلل عمود buttons كاملاً؛ يعيد قائمة فارغة عند null أو الفساد.
  static List<MessageButton> parseAll(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw.take(maxButtons))
        ?tryParse(e)
    ];
  }

  /// نفس parseAll لكن بموضع كل زر في المصفوفة الأصلية (أساس تسجيل النقرات:
  /// الخادم يعدّ بالموضع الأصلي حتى لو سقط عنصر فاسد قبله).
  static List<(int, MessageButton)> parseIndexed(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (var i = 0; i < raw.length && i < maxButtons; i++)
        if (tryParse(raw[i]) case final b?) (i, b)
    ];
  }

  static List<Map<String, dynamic>> toJsonList(List<MessageButton> l) =>
      [for (final b in l) b.toJson()];
}
