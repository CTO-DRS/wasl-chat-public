// حزام عرض لقطة شاشة «إعدادات الذكاء» — يولّد PNG حقيقيًا بالخطوط العربية
// بلا أي اتصال شبكي (بيانات معاينة). يولَّد بـ:
//   flutter test --update-goldens test/ai_settings_render_test.dart
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasl_chat/screens/ai_settings_screen.dart';
import 'package:wasl_chat/theme.dart';

Future<void> _loadFonts() async {
  final cache = Platform.environment['FLUTTER_CACHE'] ??
      '/home/sandbox/flutter-sdk/flutter/bin/cache';
  final fonts = <String, String>{
    'Roboto': '$cache/artifacts/material_fonts/Roboto-Regular.ttf',
    'Roboto-Medium': '$cache/artifacts/material_fonts/Roboto-Medium.ttf',
    'Roboto-Bold': '$cache/artifacts/material_fonts/Roboto-Bold.ttf',
    'NotoSansArabic': '/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf',
    'NotoSansArabic-Bold': '/usr/share/fonts/truetype/noto/NotoSansArabic-Bold.ttf',
  };
  Future<void> load(String path, String family, {FontWeight? weight}) async {
    final f = File(path);
    if (!f.existsSync()) return;
    final loader = FontLoader(family);
    loader.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    await loader.load();
  }

  // عائلتان مكتملتان الأوزان: Roboto للّاتينية وNoto Sans Arabic للعربية،
  // وتُربطان بقائمة fallback على كل أنماط النص في الحزام (نمط M3 المُختبر).
  await load(fonts['Roboto']!, 'Roboto');
  await load(fonts['Roboto-Medium']!, 'Roboto');
  await load(fonts['Roboto-Bold']!, 'Roboto');
  const noto = '/usr/share/fonts/truetype/noto';
  await load(fonts['NotoSansArabic']!, 'Noto Sans Arabic');
  await load('$noto/NotoSansArabic-Medium.ttf', 'Noto Sans Arabic');
  await load(fonts['NotoSansArabic-Bold']!, 'Noto Sans Arabic');
  await load('$noto/NotoSansArabic-ExtraBold.ttf', 'Noto Sans Arabic');
  await load('$noto/NotoSansArabic-Black.ttf', 'Noto Sans Arabic');
  await load('$cache/artifacts/material_fonts/MaterialIcons-Regular.otf', 'MaterialIcons');
}

Widget _harness(Widget child, ThemeData base) {
  const fb = ['Noto Sans Arabic'];
  final themed = base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: fb),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamilyFallback: fb),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle:
          base.appBarTheme.titleTextStyle?.copyWith(fontFamilyFallback: fb),
    ),
    // material_ui يعيد تركيب textTheme داخليًا فيسقط fontFamilyFallback عن
    // أنماط البلاطات؛ نمرّر الخط صراحةً عبر listTileTheme الذي يتقدّم عليها.
    listTileTheme: base.listTileTheme.copyWith(
      titleTextStyle: base.textTheme.titleMedium
          ?.copyWith(fontFamily: 'Roboto', fontFamilyFallback: fb),
      subtitleTextStyle: base.textTheme.bodyMedium?.copyWith(
          fontFamily: 'Roboto',
          fontFamilyFallback: fb,
          color: base.textTheme.bodySmall?.color),
    ),
  );
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    theme: themed,
    home: Directionality(textDirection: TextDirection.rtl, child: child),
  );
}

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
    await _loadFonts();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(
      const AiSettingsScreen(previewData: preview),
      WaslTheme.dark,
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(AiSettingsScreen),
        matchesGoldenFile('goldens/ai_settings_dark_ar.png'));
  });

  testWidgets('لقطة إعدادات الذكاء - فاتح', (tester) async {
    ignoreGlassTileAsserts();
    await _loadFonts();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(
      const AiSettingsScreen(previewData: preview),
      WaslTheme.light,
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(AiSettingsScreen),
        matchesGoldenFile('goldens/ai_settings_light_ar.png'));
  });
}
