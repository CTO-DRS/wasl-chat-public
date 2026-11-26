import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// نوع صورة الملف الشخصي
enum ProfileImageKind { avatar, cover }

/// خطأ تحضير/رفع برسالة عربية جاهزة للعرض
class ProfileImageException implements Exception {
  const ProfileImageException(this.message);
  final String message;
  @override
  String toString() => 'ProfileImageException: $message';
}

/// صورة جاهزة للرفع: بايتات JPEG ضمن حد السلّة
class PreparedProfileImage {
  const PreparedProfileImage(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
  String get contentType => ProfileImageService.contentType;
  String get extension => 'jpg';
}

/// رفع الصورة الشخصية وخلفية الملف (2.5.0 — إصلاح «تعذّر رفع الصورة»).
///
/// سلّة `avatars` (ترحيل 011): عامة القراءة، حد 2 م.ب، وأنواع
/// jpeg/png/webp فقط، والكتابة داخل مجلد `<uid>/` حصراً. كان التطبيق يرفع
/// بايتات image_picker كما هي ويُعلن نوعها من امتداد الاسم فقط — فصور HEIC/GIF
/// أو PNG الكبيرة (لقطات الشاشة) تُرفض، والنوع المعلن قد لا يطابق المحتوى.
/// هنا: فك الصورة فعلياً، تدوير EXIF، قص مربع للصورة الشخصية، تصغير،
/// وترميز JPEG بجودة تنخفض حتى تدخل تحت الحد — والخطأ الحقيقي يُطبع ويُترجم.
abstract final class ProfileImageService {
  static const bucket = 'avatars';
  static const contentType = 'image/jpeg';

  /// حد السلّة 2 م.ب (011) — نترك هامشاً صغيراً
  static const maxBytes = 2 * 1024 * 1024 - 64 * 1024;

  static const avatarSize = 512;
  static const coverMaxWidth = 1280;
  static const coverMaxHeight = 720;

  /// مسار الكائن داخل السلّة — المجلد الأول هو uid (شرط سياسة الإدراج)
  static String pathFor(String uid, ProfileImageKind kind, DateTime now) {
    final ms = now.millisecondsSinceEpoch;
    return kind == ProfileImageKind.cover ? '$uid/cover_$ms.jpg' : '$uid/$ms.jpg';
  }

  /// خيارات الرفع: نوع صريح مطابق للمحتوى، بلا استبدال (مسار جديد كل مرة)
  static FileOptions fileOptions() =>
      const FileOptions(contentType: contentType, upsert: false, cacheControl: '3600');

  /// مسار الكائن القديم من رابطه العام — فقط إن كان داخل مجلدي ومن النوع نفسه
  static String? ownedPathFromUrl(String? url, String uid, ProfileImageKind kind) {
    if (url == null || url.isEmpty) return null;
    const marker = '/$bucket/';
    final i = url.indexOf('$marker$uid/');
    if (i < 0) return null;
    var path = url.substring(i + marker.length);
    final q = path.indexOf('?');
    if (q >= 0) path = path.substring(0, q);
    final file = path.substring(uid.length + 1);
    final isCover = file.startsWith('cover_');
    if ((kind == ProfileImageKind.cover) != isCover) return null;
    if (file.isEmpty || file.contains('/')) return null;
    return path;
  }

  /// تحضير في عزلة منفصلة (فك وترميز الصور ثقيل على خيط الواجهة)
  static Future<PreparedProfileImage> prepare(Uint8List bytes, ProfileImageKind kind) async {
    final r = await compute(_prepareSync, (bytes, kind));
    return r;
  }

  /// النسخة المتزامنة (للاختبارات وللعزلة)
  static PreparedProfileImage prepareSync(Uint8List bytes, ProfileImageKind kind) =>
      _prepareSync((bytes, kind));

  static PreparedProfileImage _prepareSync((Uint8List, ProfileImageKind) args) {
    final (bytes, kind) = args;
    if (bytes.isEmpty) {
      throw const ProfileImageException('الصورة فارغة — اختر صورة أخرى');
    }
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) {
      throw const ProfileImageException(
          'صيغة الصورة غير مدعومة (مثل HEIC) — اختر صورة JPG أو PNG');
    }
    var im = img.bakeOrientation(decoded);
    if (kind == ProfileImageKind.avatar) {
      final side = im.width < im.height ? im.width : im.height;
      im = img.copyCrop(im,
          x: (im.width - side) ~/ 2, y: (im.height - side) ~/ 2, width: side, height: side);
      if (side > avatarSize) {
        im = img.copyResize(im,
            width: avatarSize, height: avatarSize, interpolation: img.Interpolation.average);
      }
    } else {
      final sw = coverMaxWidth / im.width;
      final sh = coverMaxHeight / im.height;
      final s = sw < sh ? sw : sh;
      if (s < 1) {
        im = img.copyResize(im,
            width: (im.width * s).round(),
            height: (im.height * s).round(),
            interpolation: img.Interpolation.average);
      }
    }
    // الشفافية (PNG) تُسطَّح على أبيض بدل الأسود الافتراضي في JPEG
    if (im.hasAlpha) {
      final bg = img.Image(width: im.width, height: im.height);
      img.fill(bg, color: img.ColorRgb8(255, 255, 255));
      im = img.compositeImage(bg, im);
    }
    for (final q in const [85, 75, 65, 55, 45]) {
      final out = Uint8List.fromList(img.encodeJpg(im, quality: q));
      if (out.length <= maxBytes) return PreparedProfileImage(out, im.width, im.height);
    }
    throw const ProfileImageException('الصورة أكبر من الحد المسموح (2 م.ب) حتى بعد الضغط');
  }

  /// رسالة عربية واضحة من الخطأ الحقيقي — ويُطبع كاملاً في سجل التصحيح
  static String describeError(Object e, {required ProfileImageKind kind, StackTrace? st}) {
    final what = kind == ProfileImageKind.cover ? 'الخلفية' : 'الصورة';
    debugPrint('[profile-image] رفع $what فشل: ${e.runtimeType}: $e');
    if (st != null) debugPrint('$st');
    if (e is ProfileImageException) return e.message;
    if (e is StorageException) {
      final m = '${e.message} ${e.error ?? ''}'.toLowerCase();
      final code = e.statusCode ?? '';
      if (m.contains('row-level security') || m.contains('unauthorized') || code == '403') {
        return 'تعذّر رفع $what: الخادم رفض الإذن (سياسات تخزين avatars) — [$code] ${e.message}';
      }
      if (m.contains('exceeded') || m.contains('too large') || code == '413') {
        return 'تعذّر رفع $what: الحجم أكبر من حد الخادم';
      }
      if (m.contains('mime') || m.contains('invalid_mime') || code == '415') {
        return 'تعذّر رفع $what: نوع الملف غير مسموح في سلّة الصور';
      }
      if (m.contains('bucket not found')) {
        return 'تعذّر رفع $what: سلّة avatars غير موجودة على الخادم';
      }
      if (m.contains('jwt') || code == '401') {
        return 'تعذّر رفع $what: انتهت الجلسة — سجّل الدخول من جديد';
      }
      return 'تعذّر رفع $what: ${e.message}';
    }
    if (e is PostgrestException) {
      if (e.code == '42703' || e.message.contains('cover_url')) {
        return 'تعذّر حفظ $what: قاعدة البيانات تحتاج ترحيل 044 (عمود cover_url غير موجود)';
      }
      return 'تعذّر حفظ $what في الملف: ${e.message}';
    }
    if (e is SocketException || e is TimeoutException || e.toString().contains('ClientException')) {
      return 'تعذّر رفع $what: لا اتصال بالشبكة';
    }
    return 'تعذّر رفع $what — حاول مرة أخرى';
  }

  /// هل الخطأ «عمود غير موجود» (ترحيل لم يُطبَّق)؟
  static bool isMissingColumn(Object e) =>
      e is PostgrestException && (e.code == '42703' || e.code == 'PGRST204');
}
