import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'blurhash.dart';
import 'lru_cache.dart';

/// معاينة وسيط تقدمية (2.5.0 — ج4).
///
/// التخزين: بلا أي تغيير في المخطط — تُدمج ثلاثة مفاتيح قصيرة في ميتا
/// الرسالة الموجودة أصلاً (عمود content بصيغة JSON، وهو نفسه الذي يحمل
/// {name,size,mk}) فتُشفَّر معها تلقائياً في المحادثات المشفرة:
///   "bh": BlurHash (~20-30 حرفاً)، "w"/"h": أبعاد الصورة الأصلية بالبكسل.
/// وفي الحالات: داخل body المشفر بمفتاح الحالة (كان فارغاً لحالات الصور).
///
/// الرسائل القديمة بلا هذه المفاتيح تعمل كما كانت: هيكل لامع بلون الثيم
/// ثم تلاشٍ للصورة، وتُحفظ نسبة أبعادها في الذاكرة بعد أول فك.
class MediaPreview {
  const MediaPreview({this.blurHash, this.width, this.height});

  final String? blurHash;
  final int? width;
  final int? height;

  static const empty = MediaPreview();

  bool get hasHash => BlurHash.isValid(blurHash);

  /// نسبة العرض/الارتفاع إن عُرفت، مقصوصة لحدود فقاعة معقولة
  double? get aspectRatio {
    final w = width, h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return (w / h).clamp(minAspect, maxAspect);
  }

  /// أنحف/أعرض نسبة تُعرض بها صورة في فقاعة (بانوراما/لقطة طويلة تُقص)
  static const double minAspect = 0.5;
  static const double maxAspect = 2.0;

  /// قراءة المعاينة من ميتا رسالة/حالة مفكوكة (null/ناقص ⇒ فارغة)
  factory MediaPreview.fromMeta(Map<String, dynamic>? meta) {
    if (meta == null) return empty;
    final bh = meta['bh'];
    int? n(Object? v) => v is num ? v.toInt() : null;
    return MediaPreview(
      blurHash: bh is String && BlurHash.isValid(bh) ? bh : null,
      width: n(meta['w']),
      height: n(meta['h']),
    );
  }

  /// المفاتيح التي تُدمج في الميتا
  Map<String, dynamic> toMeta() => {
        if (hasHash) 'bh': blurHash,
        'w': ?width,
        'h': ?height,
      };

  // ---------- الحساب عند الإرسال ----------

  /// أقصى ضلع للصورة المصغرة التي يُحسب منها الهاش
  static const int sampleSide = 32;

  /// يحسب المعاينة من بايتات الصورة المرسلة. الفك المصغّر يتم بمفكك المنصة
  /// الأصلي (ImageDescriptor بحجم هدف 32px — سريع ولا يفك الصورة كاملة)،
  /// ثم BlurHash بدارت نقية على 32×32 بكسل فقط. أي فشل ⇒ null فيُرسل
  /// الوسيط كما كان تماماً.
  static Future<MediaPreview?> compute(Uint8List bytes) async {
    ui.ImmutableBuffer? buf;
    ui.ImageDescriptor? desc;
    ui.Codec? codec;
    ui.Image? img;
    try {
      buf = await ui.ImmutableBuffer.fromUint8List(bytes);
      desc = await ui.ImageDescriptor.encoded(buf);
      final w = desc.width, h = desc.height;
      if (w <= 0 || h <= 0) return null;
      final s = sampleSide / math.max(w, h);
      final tw = math.max(1, (w * s).round());
      final th = math.max(1, (h * s).round());
      codec = await desc.instantiateCodec(targetWidth: tw, targetHeight: th);
      img = (await codec.getNextFrame()).image;
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      final hash = hashFromRgba(data.buffer.asUint8List(), img.width, img.height);
      return MediaPreview(blurHash: hash, width: w, height: h);
    } catch (_) {
      return null;
    } finally {
      img?.dispose();
      codec?.dispose();
      desc?.dispose();
      buf?.dispose();
    }
  }

  /// الهاش من بكسلات مصغّرة: مكوّنات 4×3 للأفقي و3×4 للعمودي
  static String hashFromRgba(Uint8List rgba, int w, int h) => BlurHash.encode(
        rgba,
        w,
        h,
        componentsX: w >= h ? 4 : 3,
        componentsY: w >= h ? 3 : 4,
      );

  // ---------- العرض عند الاستقبال ----------

  static final LruCache<String, Uint8List> _decoded = LruCache(200);

  /// صورة BMP صغيرة (32px) جاهزة لـ Image.memory — مخبأة حسب الهاش
  static Uint8List? placeholderBytes(String? hash, {double? aspect}) {
    if (!BlurHash.isValid(hash)) return null;
    final hit = _decoded.get(hash!);
    if (hit != null) return hit;
    final a = (aspect ?? 1).clamp(minAspect, maxAspect);
    final w = a >= 1 ? sampleSide : math.max(4, (sampleSide * a).round());
    final h = a >= 1 ? math.max(4, (sampleSide / a).round()) : sampleSide;
    try {
      final bmp = BlurHash.rgbaToBmp(BlurHash.decode(hash, w, h), w, h);
      _decoded.put(hash, bmp);
      return bmp;
    } catch (_) {
      return null;
    }
  }

  /// نسب أبعاد الرسائل القديمة بعد أول فك (منعاً للقفز عند إعادة التمرير)
  static final LruCache<String, double> _aspects = LruCache(500);
  static double? rememberedAspect(String? id) => id == null ? null : _aspects.get(id);
  static void rememberAspect(String? id, double aspect) {
    if (id == null || !aspect.isFinite || aspect <= 0) return;
    _aspects.put(id, aspect.clamp(minAspect, maxAspect));
  }
}
