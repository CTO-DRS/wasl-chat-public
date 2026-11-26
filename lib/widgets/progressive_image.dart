import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../services/media_preview_service.dart';
import '../theme.dart';
import 'shimmer.dart';

/// صورة تقدمية (2.5.0 — ج4): معاينة ضبابية فورية من BlurHash المخزّن في
/// ميتا الرسالة (أو هيكل لامع بلون الثيم للرسائل القديمة)، ثم تلاشٍ ناعم
/// إلى الصورة الكاملة بعد تنزيلها وفك تشفيرها.
///
/// - الصندوق يُحجز بنسبة الأبعاد المعروفة (w/h في الميتا أو المحفوظة بعد
///   أول فك) فلا تقفز الفقاعة عند وصول الصورة.
/// - الفك بدقة العرض الفعلي (cacheWidth = العرض × كثافة الشاشة) — لا تُفك
///   صورة 1600px كاملة لمربع شبكة بعرض 120.
/// - تقليل الحركة ⇒ استبدال فوري بلا تلاشٍ وبريق ثابت.
class ProgressiveImage extends StatefulWidget {
  const ProgressiveImage({
    super.key,
    required this.loader,
    this.preview = MediaPreview.empty,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.dark,
    this.memoryKey,
    this.onTap,
    this.failed,
    this.semanticLabel,
  });

  /// تنزيل/فك البايتات (يُستدعى مرة واحدة)
  final Future<Uint8List?> Function() loader;
  final MediaPreview preview;

  /// عرض ثابت (الفقاعة) — والارتفاع من النسبة إن لم يُعطَ
  final double? width;

  /// ارتفاع ثابت (مربع الشبكة/الألبوم مع width)
  final double? height;
  final BoxFit fit;

  /// فرض ألوان البريق الداكنة (العارض الغامر)
  final bool? dark;

  /// مفتاح تذكّر نسبة الأبعاد للرسائل القديمة (معرّف الرسالة)
  final String? memoryKey;
  final void Function(Uint8List bytes)? onTap;

  /// ما يُعرض عند فشل التنزيل/الفك (null من المحمّل)
  final WidgetBuilder? failed;
  final String? semanticLabel;

  @override
  State<ProgressiveImage> createState() => _ProgressiveImageState();
}

class _ProgressiveImageState extends State<ProgressiveImage> {
  late final Future<Uint8List?> _future = widget.loader();
  Uint8List? _bytes;
  bool _done = false;
  bool _settled = false; // اكتمل التلاشي ⇒ تُزال المعاينة من تحت الصورة
  double? _learned;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageProvider? _provider;

  @override
  void initState() {
    super.initState();
    _future.then((b) {
      if (!mounted) return;
      setState(() {
        _bytes = b;
        _done = true;
      });
    }, onError: (_) {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    super.dispose();
  }

  double? get _aspect =>
      widget.preview.aspectRatio ?? MediaPreview.rememberedAspect(widget.memoryKey) ?? _learned;

  bool get _motion => WaslShimmer.motionAllowed(context);

  ImageProvider _providerFor(Uint8List bytes, double logicalWidth) {
    if (_provider != null) return _provider!;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final cw = (logicalWidth * dpr).round();
    final p = ResizeImage.resizeIfNeeded(cw > 0 ? cw : null, null, MemoryImage(bytes));
    _provider = p;
    // تعلّم نسبة الأبعاد من الإطار المفكوك نفسه (بلا فك ثانٍ) إن كانت مجهولة
    if (widget.preview.aspectRatio == null) {
      final s = p.resolve(createLocalImageConfiguration(context));
      _stream = s;
      _listener = ImageStreamListener((info, _) {
        final a = info.image.width / info.image.height;
        MediaPreview.rememberAspect(widget.memoryKey, a);
        if (mounted && _learned == null) setState(() => _learned = a);
      }, onError: (_, _) {});
      s.addListener(_listener!);
    }
    return p;
  }

  Widget _placeholder() {
    final bmp = MediaPreview.placeholderBytes(widget.preview.blurHash,
        aspect: widget.preview.aspectRatio);
    if (bmp != null) {
      return Image.memory(
        bmp,
        key: const ValueKey('progressive-blur'),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      );
    }
    return WaslShimmer(
      key: const ValueKey('progressive-shimmer'),
      dark: widget.dark,
      child: const WaslBone(radius: 0),
    );
  }

  Widget _full(Uint8List bytes, double logicalWidth) {
    final dur = _motion ? WaslMotion.slow : Duration.zero;
    return Image(
      key: const ValueKey('progressive-full'),
      image: _providerFor(bytes, logicalWidth),
      fit: widget.fit,
      gaplessPlayback: true,
      semanticLabel: widget.semanticLabel,
      frameBuilder: (context, child, frame, sync) {
        if (sync) {
          if (!_settled) _settleSoon(Duration.zero);
          return child;
        }
        if (frame != null && !_settled) _settleSoon(dur);
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: dur,
          curve: WaslMotion.emphasized,
          child: child,
        );
      },
      errorBuilder: (context, _, _) => widget.failed?.call(context) ?? const SizedBox.shrink(),
    );
  }

  bool _settleScheduled = false;
  void _settleSoon(Duration d) {
    if (_settleScheduled) return;
    _settleScheduled = true;
    Timer(d + const Duration(milliseconds: 16), () {
      if (mounted) setState(() => _settled = true);
    });
  }

  Widget _layers(double logicalWidth) {
    final bytes = _bytes;
    return Stack(fit: StackFit.expand, children: [
      if (!_settled) _placeholder(),
      if (bytes != null) _full(bytes, logicalWidth),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_done && _bytes == null && widget.failed != null) {
      return widget.failed!(context);
    }
    final w = widget.width, h = widget.height;
    Widget box;
    if (w != null && h != null) {
      box = SizedBox(width: w, height: h, child: _layers(w));
    } else if (w != null) {
      final a = _aspect;
      box = SizedBox(width: w, height: a == null ? w : w / a, child: _layers(w));
    } else {
      box = LayoutBuilder(builder: (context, c) {
        final lw = c.maxWidth.isFinite ? c.maxWidth : MediaQuery.sizeOf(context).width;
        final a = _aspect;
        if (a == null) return SizedBox.expand(child: _layers(lw));
        return Center(child: AspectRatio(aspectRatio: a, child: _layers(lw)));
      });
    }
    final tap = widget.onTap;
    final bytes = _bytes;
    if (tap == null || bytes == null) return box;
    return GestureDetector(onTap: () => tap(bytes), child: box);
  }
}
