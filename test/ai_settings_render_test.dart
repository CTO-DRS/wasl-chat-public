// حزام عرض لقطة شاشة «إعدادات الذكاء» — يولّد PNG حقيقيًا بالخطوط العربية
// بلا أي اتصال شبكي (بيانات معاينة). يولَّد بـ:
//   flutter test --update-goldens test/ai_settings_render_test.dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasl_chat/screens/ai_settings_screen.dart';
import 'package:wasl_chat/theme.dart';

import 'support/render_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // GlassGroup يلف البلاطات بـ DecoratedBox خلفية زجاجية — تحذير تصحيحي من
  // material_ui لا يؤثر على الرسم؛ نتجاوزه هنا فقط ونبقي بقية الأخطاء قاتلة.
  void ignoreGlassTileAsserts() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.toString().contains('ListTile background color')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  const preview = {
    'provider': 'groq',
    'chat_model': 'qwen/qwen3.8-27b',
    'stt_model': 'whisper-large-v3',
    'max_input_chars': 8000,
    'has_groq_key_override': false,
    'has_gemini_key_override': false,
    'feature_chat': true,
    'feature_translate': true,
    'feature_summarize': true,
    'feature_transcribe': true,
    'feature_moderation': true,
  };

  testWidgets('لقطة إعدادات الذكاء - داكن', (tester) async {
    ignoreGlassTileAsserts();
    await loadRenderFonts();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(renderHarness(
      const AiSettingsScreen(previewData: preview),
      WaslTheme.dark,
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(AiSettingsScreen),
        matchesGoldenFile('goldens/ai_settings_dark_ar.png'));
  });

  testWidgets('لقطة إعدادات الذكاء - فاتح', (tester) async {
    ignoreGlassTileAsserts();
    await loadRenderFonts();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(renderHarness(
      const AiSettingsScreen(previewData: preview),
      WaslTheme.light,
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(AiSettingsScreen),
        matchesGoldenFile('goldens/ai_settings_light_ar.png'));
  });
}
