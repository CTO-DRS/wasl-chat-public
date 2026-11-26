import 'dart:typed_data';

import 'media_preview_service.dart';
import 'video_thumb.dart' as thumb;

/// ملصق فيديو (2.5.0 — ج5): معاينة الفيديو في الفقاعة والمعرض والحالات.
///
/// التخزين: بلا أي تغيير في المخطط — المفاتيح تُدمج في ميتا الرسالة
/// الموجودة أصلاً (عمود content بصيغة JSON مع {name,size,mk}) فتُشفَّر معها
/// في المحادثات المشفرة:
///   "bh"/"w"/"h": BlurHash وأبعاد الإطار (كالصور تماماً — MediaPreview)
///   "thumb": مسار ملصق JPEG صغير (~320px، جودة 70) في التخزين نفسه، مرفوع
///            بمسار رفع الوسائط ذاته ومشفّر بمفتاح الوسيط نفسه (mk في الخاص،
///            مفتاح المجموعة في المجموعات) فينتهي بـ .enc.bin في المشفرة
///   "dur": مدة الفيديو بالمللي ثانية (وتُكتب أيضاً في عمود duration_ms)
///
/// الرسائل القديمة بلا هذه المفاتيح ⇒ [VideoPoster.empty] فتبقى بطاقة الملف.
class VideoPoster {
  const VideoPoster({this.preview = MediaPreview.empty, this.thumbPath, this.durationMs});

  final MediaPreview preview;
  final String? thumbPath;
  final int? durationMs;

  static const empty = VideoPoster();

  /// يوجد ملصق مرفوع يمكن تنزيله
  bool get hasPoster => thumbPath != null;

  /// يكفي لعرض فقاعة الملصق (ضبابية أو ملصق) بدل بطاقة الملف
  bool get hasPreview => preview.hasHash || hasPoster;

  /// أطول مسار مقبول (مسارات الرفع ~70 حرفاً)
  static const int maxPathLength = 256;

  /// مسار تخزين نسبي آمن: لا مطلق ولا رجوع ولا محارف تحكم/شرطة عكسية.
  /// [conversationId] ⇒ يجب أن يكون داخل مجلد المحادثة نفسها، فلا يشير
  /// مرسل خبيث (الميتا منه) إلى ملف محادثة أخرى.
  static bool safeThumbPath(String? p, {String? conversationId}) {
    if (p == null || p.isEmpty || p.length > maxPathLength) return false;
    if (p.startsWith('/') || p.contains('\\') || p.contains('..')) return false;
    if (p.codeUnits.any((c) => c < 0x20 || c == 0x7F)) return false;
    if (!RegExp(r'^[A-Za-z0-9_\-./]+$').hasMatch(p)) return false;
    if (conversationId != null && !p.startsWith('$conversationId/')) return false;
    return true;
  }

  /// قراءة من ميتا مفكوكة. [durationMs]: عمود duration_ms احتياطاً.
  factory VideoPoster.fromMeta(Map<String, dynamic>? meta,
      {int? durationMs, String? conversationId}) {
    int? pos(Object? v) => v is num && v > 0 && v.isFinite ? v.toInt() : null;
    final col = durationMs != null && durationMs > 0 ? durationMs : null;
    if (meta == null) return col == null ? empty : VideoPoster(durationMs: col);
    final t = meta['thumb'];
    return VideoPoster(
      preview: MediaPreview.fromMeta(meta),
      thumbPath: t is String && safeThumbPath(t, conversationId: conversationId) ? t : null,
      durationMs: pos(meta['dur']) ?? col,
    );
  }

  Map<String, dynamic> toMeta() => {
        ...preview.toMeta(),
        'thumb': ?thumbPath,
        'dur': ?durationMs,
      };

  /// «0:07» / «12:05» / «1:02:03» — أرقام لاتينية كبقية أوقات الفقاعات
  static String formatDuration(int ms) {
    final total = (ms / 1000).round().clamp(0, 359999);
    final h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }
}

/// ما يُحسب على الجهاز قبل الرفع: بايتات الملصق ومعاينته ومدته.
class VideoPosterDraft {
  const VideoPosterDraft({required this.jpeg, required this.preview, this.durationMs});
  final Uint8List jpeg;
  final MediaPreview preview;
  final int? durationMs;

  /// المفاتيح المعروفة قبل الرفع (بلا thumb — يُضاف بعد نجاح رفع الملصق)
  Map<String, dynamic> toMeta() =>
      VideoPoster(preview: preview, durationMs: durationMs).toMeta();
}

typedef PosterExtractor = Future<Uint8List?> Function(String path);
typedef DurationProbe = Future<int?> Function(String path);
typedef PreviewComputer = Future<MediaPreview?> Function(Uint8List bytes);

class VideoPreviewService {
  VideoPreviewService._();

  /// زمن الإطار: بعد ثانية تقريباً (الإطار صفر غالباً أسود/انتقالي)
  static const int frameAtMs = 800;
  static const int posterWidth = 320;
  static const int posterQuality = 70;

  /// سقف ملصق معقول — أكبر منه يعني شيئاً غير متوقع فيُتخلى عنه
  static const int maxPosterBytes = 200 * 1024;

  static bool get supported => thumb.videoThumbSupported;

  /// يحضّر ملصق فيديو محلي: إطار JPEG ثم BlurHash/أبعاد منه، ومدة إن أمكن.
  /// أي فشل (منصة غير مدعومة، ملحق غائب، فيديو تالف) ⇒ null فيُرسل الفيديو
  /// كما كان تماماً. المحقونات للاختبار فقط.
  static Future<VideoPosterDraft?> prepare(
    String? path, {
    PosterExtractor? extractor,
    DurationProbe? probe,
    PreviewComputer? compute,
  }) async {
    if (path == null || path.isEmpty) return null;
    try {
      final jpeg = await (extractor ??
          (p) => thumb.extractVideoPoster(p,
              atMs: frameAtMs, maxWidth: posterWidth, quality: posterQuality))(path);
      if (jpeg == null || jpeg.isEmpty || jpeg.length > maxPosterBytes) return null;
      final pv = await (compute ?? MediaPreview.compute)(jpeg);
      if (pv == null || !pv.hasHash) return null;
      int? dur;
      try {
        dur = await (probe ?? thumb.probeVideoDurationMs)(path);
      } catch (_) {}
      return VideoPosterDraft(
          jpeg: jpeg, preview: pv, durationMs: dur != null && dur > 0 ? dur : null);
    } catch (_) {
      return null;
    }
  }
}
