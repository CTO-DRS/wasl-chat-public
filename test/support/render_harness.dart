// أدوات حزام اللقطات المشتركة: خطوط حقيقية (Roboto + Noto Sans Arabic) وثيم قابل للمقارنة.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

Future<void> loadRenderFonts() async {
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

Widget renderHarness(Widget child, ThemeData base) {
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

