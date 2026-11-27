import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wasl_chat/services/app_studio_service.dart';
import 'package:wasl_chat/services/contrast_service.dart';
import 'package:wasl_chat/theme.dart';

void main() {
  gradientAudit();
  test('AUDIT: filled/outlined/text button contrast over all accents', () {
    final accents = <int>{...StudioStyle.defaults.accent == 0 ? {} : {StudioStyle.defaults.accent}};
    for (final p in StudioCatalog.palettes) { accents.add(p.accent); }
    for (final a in StudioCatalog.swatches) { accents.add(a); }
    final fails = <String>[];
    for (final a in accents) {
      for (final b in Brightness.values) {
        final t = WaslTheme.build(b, StudioStyle(accent: a));
        final cs = t.colorScheme;
        final bg = cs.surface;
        double r(Color f, Color g) => ContrastService.ratio(f, g);
        void chk(String n, Color f, Color g) {
          final v = r(f, g);
          if (v < 4.5) fails.add('${a.toRadixString(16)} $b $n ${v.toStringAsFixed(2)}');
        }
        chk('filled', cs.onPrimary, cs.primary);
        chk('outlined/text', cs.primary, bg);
      }
    }
    expect(fails, isEmpty);
  });
}

void gradientAudit() {
  test('AUDIT: text on the identity gradient is readable at BOTH ends', () {
    final fails = <String>[];
    for (final p in StudioCatalog.palettes) {
      final stops = [Color(p.accent), Color(p.accent2)];
      final on = WaslContrast.onColors(stops);
      for (final s in stops) {
        final v = ContrastService.ratio(on, s);
        if (v < 3.0) fails.add('${p.name} ${s.toARGB32().toRadixString(16)} ${v.toStringAsFixed(2)}');
      }
    }
    // فجوات معروفة (قرار هوية معلّق عند المالك، موثقة في ROADMAP.md): الطرف
    // الفاتح من التدرج تحت 3:1 مع النص الأبيض. الاختبار حارس انحدار: لا فشل
    // جديد خارج هذه القائمة، ولا يزداد أي منها سوءاً.
    const known = {'وصل', 'سماء', 'زمرد', 'ورد', 'ذهب', 'ياقوت', 'محيط', 'رمادي'};
    final fresh = fails.where((f) => !known.contains(f.split(' ').first)).toList();
    expect(fresh, isEmpty);
    expect(fails.every((f) => double.parse(f.split(' ').last) >= 2.1), isTrue,
        reason: 'worse than the recorded floor: $fails');
  });
}
