import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../services/webio/web_files.dart';
import '../services/adaptive_actions.dart';
import '../services/app_lock_service.dart';
import '../services/shield_service.dart';
import '../services/l10n.dart';
import '../services/media_preview_service.dart';
import '../services/video_preview_service.dart';
import '../theme.dart';
import 'progressive_image.dart';

/// تُحمّل بايتات الوسيط (بعد فك التشفير إن كان مشفّراً)
typedef MediaLoader = Future<Uint8List?> Function();

/// بطاقة وسيط «تُعرض مرة واحدة»: قبل الفتح (اضغط للعرض) وبعده (انتهى)،
/// وللمرسل (لم يُعرض بعد / تم العرض).
class ViewOnceCard extends StatelessWidget {
  const ViewOnceCard({
    super.key,
    required this.mine,
    required this.viewed,
    this.mediaType = 'image',
    this.onTap,
  });

  final bool mine;
  final bool viewed;

  /// 'image' أو 'video'
  final String mediaType;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = !viewed && onTap != null;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: Container(
        width: 220,
        height: 150,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: viewed
                ? [context.hairline, context.hairline.withValues(alpha: 0.4)]
                : const [Color(0xFF2A2D3A), Color(0xFF15161F)],
          ),
          borderRadius: BorderRadius.circular(WaslRadius.md),
          border: Border.all(
            color: viewed ? context.hairline : Colors.white24,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: viewed
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.10),
                border: viewed ? Border.all(color: context.textFaint) : null,
              ),
              child: Icon(
                viewed
                    ? Icons.visibility_off_rounded
                    : (mediaType == 'video'
                        ? Icons.play_circle_fill_rounded
                        : Icons.photo_rounded),
                size: 22,
                color: viewed ? context.textFaint : Colors.white,
              ),
            ),
            const SizedBox(height: WaslSpace.md),
            Text(
              viewed
                  ? (mine ? 'انتهى — يُعرض مرة واحدة' : 'انتهى هذا الوسيط')
                  : (mine ? 'وسيط للعرض مرة واحدة' : 'اضغط للعرض مرة واحدة'),
              style: TextStyle(
                color: viewed ? context.textSecondary : Colors.white,
                fontSize: WaslFont.meta,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!viewed) ...[
              const SizedBox(height: WaslSpace.xs),
              Text(
                mine ? (active ? 'اضغط لعرض نسختك' : 'لم يُعرض بعد') : 'لا يُحفظ ولا يُلتقط',
                style: const TextStyle(color: Colors.white60, fontSize: WaslFont.caption),
              ),
            ] else if (mine) ...[
              const SizedBox(height: WaslSpace.xs),
              Text('تم العرض', style: TextStyle(color: context.textFaint, fontSize: WaslFont.caption)),
            ],
          ],
        ),
      ),
    );
  }
}

/// عارض الصورة «مرة واحدة»: بلا حفظ أو مشاركة، وخلفية سوداء.
/// منع لقطات الشاشة يُطبَّق من الشاشة المستدعية (FLAG_SECURE) قبل فتحه.
class ViewOnceImageScreen extends StatelessWidget {
  const ViewOnceImageScreen({super.key, required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white54,
        title: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.looks_one_rounded, size: 18),
          SizedBox(width: WaslSpace.sm),
          Text('عرض مرة واحدة', style: TextStyle(fontSize: WaslFont.body)),
        ]),
      ),
      body: Center(
          child: InteractiveViewer(
              maxScale: 4, child: Image.memory(bytes, fit: BoxFit.contain))),
    );
  }
}

/// فقاعة صورة: تُحمّل مرة واحدة، والضغط يفتحها بملء الشاشة.
/// ج4: معاينة ضبابية فورية (BlurHash من ميتا الرسالة) أو هيكل لامع للرسائل
/// القديمة، ثم تلاشٍ للصورة المفكوكة بدقة العرض الفعلي — بصندوق محجوز
/// بنسبة الأبعاد فلا تقفز المحادثة.
class ImageBubble extends StatelessWidget {
  const ImageBubble({
    super.key,
    required this.loader,
    this.width = 220,
    this.height,
    this.protected = false,
    this.preview = MediaPreview.empty,
    this.messageId,
  });
  final MediaLoader loader;

  /// Wasl Shield: وسيط محمي — عرض داخل التطبيق فقط، بعلامة مائية باسم المشاهد ومنع الالتقاط
  final bool protected;

  /// العرض المطلوب (يتغير في شبكة الألبوم — 0.20.0)
  final double width;

  /// ارتفاع ثابت (مربع الألبوم) — وإلا من نسبة الأبعاد
  final double? height;

  /// المعاينة الضبابية والأبعاد من ميتا الرسالة (فارغة للرسائل القديمة)
  final MediaPreview preview;

  /// لتذكّر نسبة أبعاد الرسائل القديمة بعد أول فك
  final String? messageId;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(WaslRadius.md),
      child: Stack(children: [
        ProgressiveImage(
          loader: loader,
          preview: preview,
          width: width,
          height: height,
          memoryKey: messageId,
          semanticLabel: 'صورة',
          onTap: (bytes) => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _FullImage(bytes: bytes, protected: protected)),
          ),
          failed: (context) => Container(
            width: width,
            height: height ?? 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.hairline,
              borderRadius: BorderRadius.circular(WaslRadius.md),
            ),
            child: Text('🔒 تعذّر فك تشفير الصورة',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary, fontSize: WaslFont.meta)),
          ),
        ),
        if (protected)
          const PositionedDirectional(
            top: 6,
            start: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              child: Padding(
                padding: EdgeInsets.all(WaslSpace.xs),
                child: Icon(Icons.shield_rounded, size: 14, color: WaslColors.shieldMint),
              ),
            ),
          ),
      ]),
    );
  }
}

/// فقاعة فيديو بملصق (2.5.0 — ج5): ضبابية BlurHash فورية من الميتا ثم
/// تلاشٍ إلى الملصق المفكوك (ProgressiveImage نفسه)، بصندوق محجوز بنسبة
/// الأبعاد، وزر تشغيل 48px في الوسط وشريحة المدة في الزاوية السفلية
/// الختامية (يسار في RTL — PositionedDirectional).
///
/// [posterLoader] null ⇒ ضبابية فقط (ملصق غير مرفوع/مسار غير آمن)؛ فشل
/// الملصق ⇒ تبقى الضبابية أو سطح داكن — لا كسر. [onTap] null ⇒ زخرفي (خلية
/// معرض يتولى الضغط فيها أبوها).
class VideoBubble extends StatelessWidget {
  const VideoBubble({
    super.key,
    required this.poster,
    this.posterLoader,
    this.onTap,
    this.width = 220,
    this.height,
    this.protected = false,
    this.messageId,
    this.compact = false,
    this.radius = WaslRadius.md,
  });

  final VideoPoster poster;
  final MediaLoader? posterLoader;
  final VoidCallback? onTap;
  final double width;
  final double? height;
  final bool protected;
  final String? messageId;

  /// خلية شبكة صغيرة: أيقونة تشغيل أصغر (الخلية كلها هدف اللمس)
  final bool compact;

  /// زاوية القص (0 لخلايا شبكة المعرض المربعة)
  final double radius;

  static Future<Uint8List?> _none() async => null;

  Widget _blurOrDark(BuildContext context) {
    final bmp = MediaPreview.placeholderBytes(poster.preview.blurHash,
        aspect: poster.preview.aspectRatio);
    final box = bmp == null
        ? const ColoredBox(color: WaslColors.immersiveBg)
        : Image.memory(bmp,
            key: const ValueKey('video-poster-blur-only'),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            excludeFromSemantics: true);
    final a = poster.preview.aspectRatio;
    return SizedBox(
        width: width,
        height: height ?? (a == null ? width * 9 / 16 : width / a),
        child: box);
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar';
    final dur = poster.durationMs;
    final durText = dur == null ? null : VideoPoster.formatDuration(dur);
    final label = [
      l10nT('media_play_video', lang),
      if (durText != null) '${l10nT('media_duration', lang)} $durText',
    ].join('، ');
    final playSize = compact ? 32.0 : WaslSize.minTap;
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(children: [
        ProgressiveImage(
          key: ValueKey('video-poster-${messageId ?? poster.thumbPath ?? poster.preview.blurHash}'),
          loader: posterLoader ?? _none,
          preview: poster.preview,
          width: width,
          height: height,
          memoryKey: messageId,
          failed: _blurOrDark,
        ),
        Positioned.fill(
          child: Center(
            child: ExcludeSemantics(
              child: Container(
                key: const ValueKey('video-play-button'),
                width: playSize,
                height: playSize,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: playSize * 0.66),
              ),
            ),
          ),
        ),
        if (durText != null)
          PositionedDirectional(
            bottom: WaslSpace.xs + 2,
            end: WaslSpace.xs + 2,
            child: ExcludeSemantics(
              child: Container(
                key: const ValueKey('video-duration-chip'),
                padding: const EdgeInsets.symmetric(
                    horizontal: WaslSpace.sm - 2, vertical: WaslSpace.xxs),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(WaslRadius.pill),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.videocam_rounded, size: 12, color: Colors.white),
                  const SizedBox(width: WaslSpace.xxs),
                  // الأوقات لاتينية LTR دائماً حتى داخل RTL
                  Text(durText,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: WaslFont.caption,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ]),
              ),
            ),
          ),
        if (protected)
          const PositionedDirectional(
            top: 6,
            start: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              child: Padding(
                padding: EdgeInsets.all(WaslSpace.xs),
                child: Icon(Icons.shield_rounded, size: 14, color: WaslColors.shieldMint),
              ),
            ),
          ),
      ]),
    );
    final tap = onTap;
    return Semantics(
      button: tap != null,
      label: label,
      onTap: tap,
      excludeSemantics: true,
      child: tap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: tap,
                child: content,
              ),
            ),
    );
  }
}

class _FullImage extends StatefulWidget {
  const _FullImage({required this.bytes, this.protected = false});
  final Uint8List bytes;
  final bool protected;

  @override
  State<_FullImage> createState() => _FullImageState();
}

class _FullImageState extends State<_FullImage> {
  String? _tag;

  @override
  void initState() {
    super.initState();
    if (widget.protected) {
      ScreenshotService.setSecure(true);
      ShieldService.watermarkTag().then((t) {
        if (mounted) setState(() => _tag = t);
      });
    }
  }

  @override
  void dispose() {
    // العودة لحالة الشاشة السابقة: المحادثة تعيد تطبيق علمها عند الرجوع (routeObserver)
    if (widget.protected) ScreenshotService.setSecure(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = Image.memory(widget.bytes, fit: BoxFit.contain);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: widget.protected
            ? const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.shield_rounded, size: 18, color: WaslColors.shieldMint),
                SizedBox(width: WaslSpace.sm),
                Text('وسيط محمي', style: TextStyle(fontSize: WaslFont.bodyLarge)),
              ])
            : null,
      ),
      body: Center(
          child: InteractiveViewer(
              child: widget.protected && _tag != null ? ShieldWatermark(tag: _tag!, child: img) : img)),
    );
  }
}

/// فقاعة رسالة صوتية: تشغيل/إيقاف وشريط تقدم ومدة
/// (يُفكّ تشفير الملف ويُكتب مؤقتاً ثم يُشغّل محلياً)
class VoiceBubble extends StatefulWidget {
  const VoiceBubble({super.key, required this.loader, this.durationMs});
  final MediaLoader loader;
  final int? durationMs;

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  final _player = AudioPlayer();
  bool _ready = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_player.playing && _player.processingState != ProcessingState.completed) {
        await _player.pause();
        return;
      }
      if (!_ready) {
        final bytes = await widget.loader();
        if (bytes == null) throw Exception('no bytes');
        if (kIsWeb) {
          final webm = bytes.length > 4 &&
              bytes[0] == 0x1A && bytes[1] == 0x45 && bytes[2] == 0xDF && bytes[3] == 0xA3;
          await _player.setUrl(webBlobUrl(bytes, webm ? 'audio/webm' : 'audio/mp4'));
        } else {
          final dir = await getTemporaryDirectory();
          final f = File(
              '${dir.path}/voice_enc_${DateTime.now().millisecondsSinceEpoch}.m4a');
          await f.writeAsBytes(bytes, flush: true);
          await _player.setFilePath(f.path);
        }
        _ready = true;
        // السرعة المشتركة (2.2.0): يضبطها شريط الإجراءات التكيفي
        await _player.setSpeed(VoiceRateService.rate);
      }
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      _player.play(); // لا ننتظرها: تكتمل عند انتهاء التشغيل
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذّر تشغيل الرسالة الصوتية')));
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, s) {
        final playing = (s.data?.playing ?? false) &&
            s.data?.processingState != ProcessingState.completed;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'إيقاف مؤقت',
              onPressed: _toggle,
              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 30),
            ),
            SizedBox(
              width: 140,
              child: StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, p) {
                  final total =
                      _player.duration ?? Duration(milliseconds: widget.durationMs ?? 0);
                  final pos = p.data ?? Duration.zero;
                  final value = total.inMilliseconds == 0
                      ? 0.0
                      : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0).toDouble();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 4,
                          backgroundColor: Colors.white24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: WaslSpace.xs),
                      Text(_fmt(playing ? pos : total),
                          style: const TextStyle(color: Colors.white70, fontSize: WaslFont.caption)),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
