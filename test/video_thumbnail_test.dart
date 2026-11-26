/// اختبارات مصغّرات الفيديو (2.5.0 — ج5): ميتا الملصق داخل content مع/بلا
/// المفاتيح الجديدة، فحص مسار الملصق، التحضير عند الإرسال وهبوطه، بديل
/// المنصات غير المدعومة، وفقاعة الفيديو (ملصق/ضبابية/بطاقة قديمة، المدة في
/// الزاوية الختامية بالاتجاهين، زر 48px ووصف قارئ الشاشة).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:wasl_chat/services/blurhash.dart';
import 'package:wasl_chat/services/l10n.dart';
import 'package:wasl_chat/services/media_gallery_service.dart';
import 'package:wasl_chat/services/media_preview_service.dart';
import 'package:wasl_chat/services/video_preview_service.dart';
import 'package:wasl_chat/services/video_thumb.dart' as conditional;
import 'package:wasl_chat/services/video_thumb_io.dart' as io_impl;
import 'package:wasl_chat/services/video_thumb_stub.dart' as stub;
import 'package:wasl_chat/theme.dart';
import 'package:wasl_chat/widgets/media_bubbles.dart';

const _conv = '3f2b6c1e-0a4d-4f7e-9b1a-2c3d4e5f6a7b';

Uint8List _rgba(int w, int h) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = (y * w + x) * 4;
      out[p] = (255 * (1 - x / (w - 1))).round();
      out[p + 1] = y < h / 2 ? 40 : 160;
      out[p + 2] = (255 * x / (w - 1)).round();
      out[p + 3] = 255;
    }
  }
  return out;
}

final _hash = MediaPreview.hashFromRgba(_rgba(32, 18), 32, 18);

Widget _host(Widget child, {TextDirection dir = TextDirection.rtl, Locale locale = const Locale('ar')}) =>
    MaterialApp(
      theme: WaslTheme.dark,
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaQuery(
        data: const MediaQueryData(size: Size(400, 800), disableAnimations: true),
        child: Directionality(
          textDirection: dir,
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );

void main() {
  group('VideoPoster — ميتا content مع/بلا مفاتيح الملصق', () {
    test('رسالة جديدة: bh/w/h/thumb/dur تُقرأ كاملة', () {
      final meta = jsonDecode(jsonEncode({
        'name': 'clip.mp4',
        'size': 1234567,
        'mk': 'AAAA',
        'bh': _hash,
        'w': 320,
        'h': 180,
        'thumb': '$_conv/1732240000000_ab12cd34.thumb.enc.bin',
        'dur': 65400,
      })) as Map<String, dynamic>;
      final p = VideoPoster.fromMeta(meta, conversationId: _conv);
      expect(p.preview.hasHash, isTrue);
      expect(p.preview.aspectRatio, closeTo(320 / 180, 1e-9));
      expect(p.thumbPath, endsWith('.thumb.enc.bin'));
      expect(p.durationMs, 65400);
      expect(p.hasPoster, isTrue);
      expect(p.hasPreview, isTrue);
    });

    test('رسالة قديمة {name,size}: فارغة ⇒ تبقى بطاقة الملف', () {
      final p = VideoPoster.fromMeta({'name': 'old.mp4', 'size': 10});
      expect(p.hasPreview, isFalse);
      expect(p.thumbPath, isNull);
      expect(p.durationMs, isNull);
      expect(VideoPoster.fromMeta(null).hasPreview, isFalse);
    });

    test('المدة من عمود duration_ms احتياطاً، و"dur" يتقدم عليه', () {
      expect(VideoPoster.fromMeta(null, durationMs: 4200).durationMs, 4200);
      expect(VideoPoster.fromMeta({'name': 'a'}, durationMs: 4200).durationMs, 4200);
      expect(VideoPoster.fromMeta({'dur': 9000}, durationMs: 4200).durationMs, 9000);
      expect(VideoPoster.fromMeta({'dur': -5}, durationMs: 0).durationMs, isNull);
      expect(VideoPoster.fromMeta({'dur': 'x'}).durationMs, isNull);
    });

    test('ضبابية بلا ملصق مرفوع (فشل رفع الملصق) ما زالت معاينة', () {
      final p = VideoPoster.fromMeta({'bh': _hash, 'w': 320, 'h': 568});
      expect(p.hasPoster, isFalse);
      expect(p.hasPreview, isTrue);
    });

    test('هاش تالف ومسار غير نصي يُتجاهلان بلا استثناء', () {
      final p = VideoPoster.fromMeta({'bh': '!!', 'thumb': 42, 'w': 'x'});
      expect(p.hasPreview, isFalse);
    });

    test('toMeta ذهاباً وإياباً عبر JSON', () {
      final a = VideoPoster(
          preview: MediaPreview(blurHash: _hash, width: 320, height: 180),
          thumbPath: '$_conv/1_x.thumb.jpg',
          durationMs: 7000);
      final b = VideoPoster.fromMeta(
          jsonDecode(jsonEncode(a.toMeta())) as Map<String, dynamic>,
          conversationId: _conv);
      expect(b.preview.blurHash, a.preview.blurHash);
      expect(b.thumbPath, a.thumbPath);
      expect(b.durationMs, 7000);
      expect(VideoPoster.empty.toMeta(), isEmpty);
    });

    test('مسار الملصق: داخل مجلد المحادثة نفسها فقط وبلا رجوع/مطلق', () {
      bool ok(String p) => VideoPoster.safeThumbPath(p, conversationId: _conv);
      expect(ok('$_conv/1_ab.thumb.enc.bin'), isTrue);
      expect(ok('other-conv/1_ab.thumb.enc.bin'), isFalse);
      expect(ok('$_conv/../other/1.bin'), isFalse);
      expect(ok('/$_conv/1.bin'), isFalse);
      expect(ok('$_conv\\1.bin'), isFalse);
      expect(ok('$_conv/a b.bin'), isFalse);
      expect(ok('$_conv/${'a' * 300}'), isFalse);
      expect(VideoPoster.fromMeta({'bh': _hash, 'thumb': 'evil/1.bin'}, conversationId: _conv).thumbPath,
          isNull);
    });

    test('تنسيق المدة', () {
      expect(VideoPoster.formatDuration(0), '0:00');
      expect(VideoPoster.formatDuration(7400), '0:07');
      expect(VideoPoster.formatDuration(65400), '1:05');
      expect(VideoPoster.formatDuration(3723000), '1:02:03');
    });

    test('معرض الوسائط يقرأ thumb/dur للفيديو فقط', () {
      final items = MediaGalleryService.collect(
        [
          {
            'id': 'v1',
            'type': 'video',
            'media_url': '$_conv/1.enc.bin',
            'created_at': '2026-11-22T01:00:00Z',
            'sender_id': 'me',
            'duration_ms': 1000,
            'content': 'x',
          },
          {
            'id': 'v0',
            'type': 'video',
            'media_url': '$_conv/0.mp4',
            'created_at': '2026-11-21T01:00:00Z',
            'sender_id': 'me',
            'content': '',
          },
        ],
        (m) => m['id'] == 'v1'
            ? jsonEncode({'name': 'a.mp4', 'bh': _hash, 'w': 320, 'h': 180, 'thumb': '$_conv/2.thumb.enc.bin', 'dur': 5000})
            : jsonEncode({'name': 'old.mp4', 'size': 3}),
        myId: 'me',
      );
      expect(items.first.thumbPath, '$_conv/2.thumb.enc.bin');
      expect(items.first.durationMs, 5000);
      expect(items.last.thumbPath, isNull);
      expect(items.last.blurHash, isNull);
    });
  });

  group('التحضير عند الإرسال والهبوط', () {
    test('بديل المنصات غير المدعومة (الويب): null دائماً بلا استثناء', () async {
      expect(stub.videoThumbSupported, isFalse);
      expect(await stub.extractVideoPoster('/tmp/a.mp4'), isNull);
      expect(await stub.probeVideoDurationMs('/tmp/a.mp4'), isNull);
    });

    test('تطبيق dart:io على سطح مكتب الاختبار: معطّل وهابط بصمت', () async {
      // مضيف الاختبار لينكس/ماك ⇒ ليس أندرويد/iOS
      expect(io_impl.videoThumbSupported, isFalse);
      expect(await io_impl.extractVideoPoster('/no/such/file.mp4'), isNull);
      expect(await io_impl.probeVideoDurationMs('/no/such/file.mp4'), isNull);
      expect(conditional.videoThumbSupported, isFalse);
      expect(VideoPreviewService.supported, isFalse);
    });

    test('prepare بلا مسار أو على منصة غير مدعومة ⇒ null (يُرسل كما كان)', () async {
      expect(await VideoPreviewService.prepare(null), isNull);
      expect(await VideoPreviewService.prepare(''), isNull);
      expect(await VideoPreviewService.prepare('/no/such/file.mp4'), isNull);
    });

    test('prepare ناجح: JPEG + معاينة + مدة', () async {
      final jpeg = Uint8List.fromList(List.filled(2048, 7));
      final d = await VideoPreviewService.prepare('/v.mp4',
          extractor: (_) async => jpeg,
          compute: (_) async => MediaPreview(blurHash: _hash, width: 320, height: 180),
          probe: (_) async => 12500);
      expect(d, isNotNull);
      expect(d!.jpeg, same(jpeg));
      final meta = d.toMeta();
      expect(meta['bh'], _hash);
      expect(meta['w'], 320);
      expect(meta['dur'], 12500);
      expect(meta.containsKey('thumb'), isFalse); // يُضاف بعد نجاح الرفع فقط
    });

    test('prepare: فشل الاستخراج/الهاش/حجم شاذ ⇒ null، وفشل المدة لا يُسقط الملصق', () async {
      final jpeg = Uint8List.fromList(List.filled(100, 1));
      Future<MediaPreview?> okPv(Uint8List _) async =>
          MediaPreview(blurHash: _hash, width: 10, height: 10);
      expect(await VideoPreviewService.prepare('/v', extractor: (_) async => null, compute: okPv), isNull);
      expect(await VideoPreviewService.prepare('/v', extractor: (_) async => throw Exception('x'), compute: okPv),
          isNull);
      expect(
          await VideoPreviewService.prepare('/v',
              extractor: (_) async => jpeg, compute: (_) async => null),
          isNull);
      expect(
          await VideoPreviewService.prepare('/v',
              extractor: (_) async => Uint8List(VideoPreviewService.maxPosterBytes + 1), compute: okPv),
          isNull);
      final d = await VideoPreviewService.prepare('/v',
          extractor: (_) async => jpeg, compute: okPv, probe: (_) async => throw Exception('no player'));
      expect(d, isNotNull);
      expect(d!.durationMs, isNull);
    });

    testWidgets('prepare مع حساب BlurHash الحقيقي من بايتات صورة', (t) async {
      final bmp = BlurHash.rgbaToBmp(_rgba(64, 36), 64, 36);
      final d = await t.runAsync(() => VideoPreviewService.prepare('/v.mp4',
          extractor: (_) async => bmp, probe: (_) async => null));
      expect(d, isNotNull);
      expect(d!.preview.width, 64);
      expect(d.preview.height, 36);
      expect(d.preview.hasHash, isTrue);
    });
  });

  group('VideoBubble — ملصق/ضبابية/هبوط', () {
    VideoPoster poster({int? dur = 65400, String? thumb}) => VideoPoster(
        preview: MediaPreview(blurHash: _hash, width: 320, height: 180),
        thumbPath: thumb,
        durationMs: dur);

    testWidgets('أثناء تحميل الملصق: ضبابية فورية بنسبة الأبعاد + زر 48 + المدة', (t) async {
      await t.pumpWidget(_host(VideoBubble(
        poster: poster(thumb: '$_conv/t.bin'),
        posterLoader: () => Completer<Uint8List?>().future,
        onTap: () {},
      )));
      expect(find.byKey(const ValueKey('progressive-blur')), findsOneWidget);
      expect(t.getSize(find.byKey(const ValueKey('video-play-button'))), const Size(48, 48));
      expect(find.text('1:05'), findsOneWidget);
      // صندوق محجوز 220 × 220/(320/180)
      final box = t.getSize(find.byType(ClipRRect).first);
      expect(box.width, 220);
      expect(box.height, closeTo(220 / (320 / 180), 0.01));
    });

    testWidgets('وصول الملصق ⇒ الصورة الكاملة', (t) async {
      final bytes = BlurHash.rgbaToBmp(_rgba(64, 36), 64, 36);
      await t.pumpWidget(_host(VideoBubble(
        poster: poster(thumb: '$_conv/t.bin'),
        posterLoader: () async => bytes,
        onTap: () {},
      )));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await t.pump();
      expect(find.byKey(const ValueKey('progressive-full')), findsOneWidget);
    });

    testWidgets('بلا ملصق مرفوع أو فشل الملصق ⇒ تبقى الضبابية (لا كسر)', (t) async {
      await t.pumpWidget(_host(VideoBubble(poster: poster(), onTap: () {})));
      await t.pump();
      expect(find.byKey(const ValueKey('video-poster-blur-only')), findsOneWidget);
      expect(find.byKey(const ValueKey('video-play-button')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('بلا مدة ⇒ لا شريحة مدة', (t) async {
      await t.pumpWidget(_host(VideoBubble(poster: poster(dur: null), onTap: () {})));
      expect(find.byKey(const ValueKey('video-duration-chip')), findsNothing);
    });

    testWidgets('المدة في الزاوية السفلية الختامية: يسار في RTL ويمين في LTR', (t) async {
      await t.pumpWidget(_host(VideoBubble(poster: poster(), onTap: () {})));
      final bubbleR = t.getRect(find.byType(VideoBubble));
      final chipR = t.getRect(find.byKey(const ValueKey('video-duration-chip')));
      expect(chipR.left - bubbleR.left, lessThan(20)); // RTL ⇒ النهاية يسار
      expect(bubbleR.bottom - chipR.bottom, lessThan(20));

      await t.pumpWidget(_host(VideoBubble(poster: poster(), onTap: () {}),
          dir: TextDirection.ltr, locale: const Locale('en')));
      final b2 = t.getRect(find.byType(VideoBubble));
      final c2 = t.getRect(find.byKey(const ValueKey('video-duration-chip')));
      expect(b2.right - c2.right, lessThan(20)); // LTR ⇒ النهاية يمين
    });

    testWidgets('قارئ الشاشة: زر بتسمية مترجمة والضغط يعمل', (t) async {
      final h = t.ensureSemantics();
      var taps = 0;
      await t.pumpWidget(_host(VideoBubble(poster: poster(), onTap: () => taps++)));
      expect(find.bySemanticsLabel(RegExp('^تشغيل الفيديو')), findsOneWidget);
      await t.tap(find.byType(VideoBubble));
      expect(taps, 1);

      await t.pumpWidget(_host(VideoBubble(poster: poster(), onTap: () {}),
          dir: TextDirection.ltr, locale: const Locale('en')));
      expect(find.bySemanticsLabel(RegExp('^Play video')), findsOneWidget);
      expect(l10nComplete('media_play_video'), isTrue);
      expect(l10nComplete('media_duration'), isTrue);
      h.dispose();
    });

    testWidgets('خلية المعرض: مقاس الخلية، أيقونة مصغرة، بلا هدف لمس خاص', (t) async {
      await t.pumpWidget(_host(SizedBox(
        width: 120,
        height: 120,
        child: VideoBubble(poster: poster(), width: 120, height: 120, compact: true, radius: 0),
      )));
      expect(t.getSize(find.byType(VideoBubble)), const Size(120, 120));
      expect(t.getSize(find.byKey(const ValueKey('video-play-button'))), const Size(32, 32));
      expect(find.byType(InkWell), findsNothing);
    });
  });
}
