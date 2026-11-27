/// «ما فاتني»: ملخص محلي لما وصل منذ آخر قراءة لك، يُبنى على جهازك فقط.
/// استخلاصي صادق: عدّاد، أبرز المرسلين، أسئلة مطروحة، روابط وملفات، وأهم الأسطر.
import 'local_ai_service.dart';

class MissedLine {
  const MissedLine({required this.who, required this.text, this.isMedia = false});
  final String who;
  final String text;
  final bool isMedia;
}

class MissedSummaryService {
  MissedSummaryService._();

  static final _link = RegExp(r'https?://\S+');
  static const _ask = ['؟', '?'];

  /// يعيد null إن لم يفتك شيء.
  static String? build(List<MissedLine> lines, {int maxHighlights = 3, int maxQuestions = 3}) {
    if (lines.isEmpty) return null;
    final texts = lines.where((l) => !l.isMedia && l.text.trim().isNotEmpty).toList();
    final media = lines.where((l) => l.isMedia).length;
    if (texts.isEmpty && media == 0) return null;

    final parts = <String>[];
    final head = StringBuffer('فاتك ${lines.length} ${lines.length == 1 ? 'رسالة' : 'رسائل'}');
    final byWho = <String, int>{};
    for (final l in lines) {
      final w = l.who.trim();
      if (w.isNotEmpty) byWho[w] = (byWho[w] ?? 0) + 1;
    }
    if (byWho.length >= 2) {
      final top = byWho.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      head.write(' من ${byWho.length} أشخاص، أكثرهم ${top.first.key} (${top.first.value})');
    } else if (byWho.length == 1) {
      head.write(' من ${byWho.keys.first}');
    }
    parts.add(head.toString());

    final links = texts.where((l) => _link.hasMatch(l.text)).length;
    final extras = <String>[];
    if (media > 0) extras.add('وسائط ($media)');
    if (links > 0) extras.add('${links == 1 ? 'رابط' : 'روابط'} ($links)');
    if (extras.isNotEmpty) parts.add(extras.join(' · '));

    final questions = texts
        .where((l) => _ask.any(l.text.contains))
        .toList();
    if (questions.isNotEmpty) {
      final shown = questions.reversed.take(maxQuestions).toList().reversed;
      parts.add('أسئلة مطروحة:\n${shown.map((q) => '• ${q.who}: ${_clip(q.text)}').join('\n')}');
    }

    // الأسئلة عُرضت أعلاه: لا تتكرر في النقاط الأساسية
    final rest = texts.where((l) => !questions.contains(l)).toList();
    final pool = rest.isEmpty ? texts : rest;
    if (pool.isNotEmpty) {
      parts.add(LocalAiService.summarizeLines(
          pool.map((l) => '${l.who}: ${l.text}').toList(),
          maxLines: maxHighlights));
    }
    return parts.join('\n');
  }

  static String _clip(String s) {
    final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length <= 90 ? t : '${t.substring(0, 90)}…';
  }
}
