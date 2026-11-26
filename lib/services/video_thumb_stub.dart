import 'dart:typed_data';

/// بديل المنصات بلا dart:io (الويب): لا استخراج إطارات — هبوط صامت.
bool get videoThumbSupported => false;

/// دائماً null: يُرسل الفيديو بلا ملصق كما كان قبل ج5.
Future<Uint8List?> extractVideoPoster(
  String path, {
  int atMs = 800,
  int maxWidth = 320,
  int maxHeight = 640,
  int quality = 70,
}) async =>
    null;

/// دائماً null: المدة غير مقاسة هنا (لا تُخمَّن).
Future<int?> probeVideoDurationMs(String path) async => null;
