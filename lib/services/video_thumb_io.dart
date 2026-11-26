import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
// أنواع الزمن غير مُصدَّرة من المكتبة الرئيسية في 3.0.1
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail_platform_interface.dart'
    show FcVideoThumbnailTime, FcVideoThumbnailTimeUnit;
import 'package:video_player/video_player.dart';

/// الاستخراج الأصلي مفعّل على أندرويد وiOS فقط. سطح المكتب يدعمه الملحق
/// جزئياً (ويندوز بلا تقديم زمني، ولينكس يتطلب FFmpeg على النظام) — فنهبط
/// هناك صامتين بدل سلوك غير متسق بين الأجهزة.
bool get videoThumbSupported => Platform.isAndroid || Platform.isIOS;

/// إطار JPEG مصغّر (≤ [maxWidth]×[maxHeight] مع حفظ النسبة) عند [atMs].
/// المصدر يُمرَّر كـ file:// URI: مسار ملف خام في 3.0.1 على أندرويد يمر عبر
/// toUri() بلا مخطط فيفشل، والـ URI يعمل على أندرويد وiOS معاً.
/// فيديو أقصر من [atMs] ⇒ محاولة ثانية بلا تقديم (الإطار الافتراضي).
/// أي فشل/غياب ملحق ⇒ null.
Future<Uint8List?> extractVideoPoster(
  String path, {
  int atMs = 800,
  int maxWidth = 320,
  int maxHeight = 640,
  int quality = 70,
}) async {
  if (!videoThumbSupported || path.isEmpty) return null;
  final plugin = FcNativeVideoThumbnail();
  final src = Uri.file(path).toString();
  Future<Uint8List?> grab(FcVideoThumbnailTime? at) async {
    try {
      return await plugin
          .saveThumbnailToBytes(
            srcFile: src,
            srcFileUri: true,
            width: maxWidth,
            height: maxHeight,
            quality: quality,
            at: at,
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      return null;
    }
  }

  final first = await grab(FcVideoThumbnailTime(atMs, FcVideoThumbnailTimeUnit.milliseconds));
  if (first != null && first.isNotEmpty) return first;
  final fallback = await grab(null);
  return fallback != null && fallback.isNotEmpty ? fallback : null;
}

/// مدة الفيديو بالمللي ثانية بتهيئة المشغّل الموجود أصلاً (video_player)
/// بلا تشغيل، بمهلة قصيرة — الفشل ⇒ null (لا تخمين).
Future<int?> probeVideoDurationMs(String path) async {
  if (!videoThumbSupported || path.isEmpty) return null;
  VideoPlayerController? c;
  try {
    c = VideoPlayerController.file(File(path));
    await c.initialize().timeout(const Duration(seconds: 4));
    final ms = c.value.duration.inMilliseconds;
    return ms > 0 ? ms : null;
  } catch (_) {
    return null;
  } finally {
    unawaited(c?.dispose());
  }
}
