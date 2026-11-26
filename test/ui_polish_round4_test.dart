/// اختبارات صقل الواجهة — الجولة الرابعة (2.5.0 — ج4): بريق الهياكل الموحّد
/// (تقليل الحركة، الثيم، الاتجاه)، وهياكل الشاشات بالعربية، والمعاينات
/// الضبابية التقدمية (BlurHash ترميز/فك، الميتا، والهبوط للرسائل القديمة).
import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wasl_chat/services/blurhash.dart';
import 'package:wasl_chat/services/media_gallery_service.dart';
import 'package:wasl_chat/services/media_preview_service.dart';
import 'package:wasl_chat/theme.dart';
import 'package:wasl_chat/widgets/progressive_image.dart';
import 'package:wasl_chat/widgets/shimmer.dart';

Widget _host(Widget child,
        {TextDirection dir = TextDirection.rtl, bool reduce = false, ThemeData? theme}) =>
    MaterialApp(
      theme: theme ?? WaslTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(size: const Size(400, 800), disableAnimations: reduce),
        child: Directionality(
          textDirection: dir,
          child: Scaffold(body: child),
        ),
      ),
    );

/// صورة اختبار: تدرج أفقي أحمر→أزرق مع نصف سفلي أفتح
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

void main() {
  group('WaslShimmer — بريق موحّد', () {
    testWidgets('تقليل الحركة ⇒ بريق ثابت بلا متحكم يعمل', (t) async {
      await t.pumpWidget(_host(const WaslSkeletonList(rows: 3), reduce: true));
      expect(find.byKey(const ValueKey('wasl-shimmer-static')), findsOneWidget);
      expect(find.byKey(const ValueKey('wasl-shimmer-anim')), findsNothing);
      // لا إطارات مجدولة: يستقر فوراً (المتحكم متوقف)
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('الحركة مسموحة ⇒ قناع متحرك واحد لكل الشجرة', (t) async {
      await t.pumpWidget(_host(const WaslSkeletonList(rows: 5)));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('wasl-shimmer-anim')), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget); // متحكم/تدرج واحد للقائمة كلها
      expect(t.binding.hasScheduledFrame, isTrue);
      await t.pumpWidget(const SizedBox()); // التخلص يوقف المتحكم بلا تسريب
    });

    testWidgets('ألوان الأساس تتبع الثيم (فاتح/داكن)', (t) async {
      late (Color, Color) dark, light;
      await t.pumpWidget(_host(Builder(builder: (c) {
        dark = WaslShimmer.colorsOf(c);
        return const SizedBox();
      })));
      await t.pumpWidget(_host(Builder(builder: (c) {
        light = WaslShimmer.colorsOf(c);
        return const SizedBox();
      }), theme: WaslTheme.light));
      await t.pumpAndSettle(); // انتهاء تلاشي الثيم المتحرك
      expect(dark.$1, isNot(light.$1));
      expect(dark.$1.computeLuminance(), greaterThan(light.$1.computeLuminance() - 1));
      // الفاتح: عظام داكنة شفافة؛ الداكن: عظام فاتحة شفافة
      expect((dark.$1.r), greaterThan(0.9));
      expect((light.$1.r), lessThan(0.1));
    });

    testWidgets('العظمة خارج بريق تُرسم بلون الأساس لا بالأبيض', (t) async {
      await t.pumpWidget(_host(const Center(child: WaslBone(width: 50, height: 10))));
      final box = t.widget<Container>(find.descendant(
          of: find.byType(WaslBone), matching: find.byType(Container)));
      final color = (box.decoration as BoxDecoration).color!;
      expect(color, isNot(Colors.white));
    });
  });

  group('هياكل الشاشات بالعربية (RTL)', () {
    testWidgets('صف القائمة: الصورة الرمزية في جهة البداية (اليمين) بالعربية', (t) async {
      await t.pumpWidget(_host(const WaslSkeletonList(rows: 2), reduce: true));
      final avatar = find.byWidgetPredicate((w) => w is WaslBone && w.circle).first;
      final line = find.byWidgetPredicate((w) => w is WaslBone && !w.circle).first;
      expect(t.getCenter(avatar).dx, greaterThan(t.getCenter(line).dx));
    });

    testWidgets('…وفي الإنجليزية تنعكس إلى اليسار', (t) async {
      await t.pumpWidget(_host(const WaslSkeletonList(rows: 2), reduce: true, dir: TextDirection.ltr));
      final avatar = find.byWidgetPredicate((w) => w is WaslBone && w.circle).first;
      final line = find.byWidgetPredicate((w) => w is WaslBone && !w.circle).first;
      expect(t.getCenter(avatar).dx, lessThan(t.getCenter(line).dx));
    });

    testWidgets('هيكل المحادثة: فقاعاتي في النهاية (اليسار) والأخرى في البداية', (t) async {
      await t.pumpWidget(_host(const WaslSkeletonChat(bubbles: 4), reduce: true));
      final mine = find.byWidgetPredicate((w) => w is WaslSkeletonBubble && w.mine).first;
      final other = find.byWidgetPredicate((w) => w is WaslSkeletonBubble && !w.mine).first;
      final mineBone = find.descendant(of: mine, matching: find.byType(WaslBone));
      final otherBone = find.descendant(of: other, matching: find.byType(WaslBone));
      expect(t.getCenter(mineBone).dx, lessThan(200));
      expect(t.getCenter(otherBone).dx, greaterThan(200));
    });

    testWidgets('كل الهياكل تُبنى بلا أخطاء تخطيط وبوصف لقارئ الشاشة', (t) async {
      for (final w in <Widget>[
        const WaslSkeletonList(header: WaslSkeletonStatusStrip()),
        const WaslSkeletonList(rows: 6, trailingIcon: true),
        const WaslSkeletonList(rows: 7, avatar: WaslBoneAvatar.rounded),
        const WaslSkeletonGrid(),
        const WaslSkeletonChat(),
        const WaslSkeletonHeader(cover: true, actions: 0),
        const WaslSkeletonHeader(avatarSize: 96, rows: 5),
      ]) {
        await t.pumpWidget(_host(w, reduce: true));
        expect(t.takeException(), isNull, reason: '$w');
        expect(find.bySemanticsLabel(RegExp('جارٍ')), findsWidgets, reason: '$w');
      }
    });
  });

  group('BlurHash — ترميز وفك نقي', () {
    test('ترميز/فك ذهاباً وإياباً يحفظ الألوان التقريبية', () {
      const w = 32, h = 24;
      final px = _rgba(w, h);
      final hash = BlurHash.encode(px, w, h);
      expect(BlurHash.isValid(hash), isTrue);
      expect(hash.length, 4 + 2 * 4 * 3); // 4×3 مكوّنات = 28 حرفاً
      final back = BlurHash.decode(hash, w, h);
      expect(back.length, w * h * 4);
      int at(Uint8List b, int x, int y, int c) => b[(y * w + x) * 4 + c];
      // البداية حمراء والنهاية زرقاء والنصف السفلي أكثر خضرة — بعد الضبابية
      expect(at(back, 2, 12, 0), greaterThan(at(back, 29, 12, 0)));
      expect(at(back, 29, 12, 2), greaterThan(at(back, 2, 12, 2)));
      expect(at(back, 16, 20, 1), greaterThan(at(back, 16, 3, 1)));
      // فرق متوسط معقول عن الأصل
      var err = 0;
      for (var i = 0; i < px.length; i += 4) {
        err += (px[i] - back[i]).abs() + (px[i + 2] - back[i + 2]).abs();
      }
      expect(err / (w * h * 2), lessThan(40));
    });

    test('متجه مرجعي: صورة لون واحد تُرمّز بثبات ومتوسطها اللون نفسه', () {
      final px = Uint8List(8 * 8 * 4);
      for (var i = 0; i < px.length; i += 4) {
        px[i] = 99;
        px[i + 1] = 150;
        px[i + 2] = 200;
        px[i + 3] = 255;
      }
      final a = BlurHash.encode(px, 8, 8);
      expect(BlurHash.encode(px, 8, 8), a); // حتمي
      final avg = BlurHash.averageColor(a)!;
      expect((avg.$1 - 99).abs(), lessThanOrEqualTo(1));
      expect((avg.$2 - 150).abs(), lessThanOrEqualTo(1));
      expect((avg.$3 - 200).abs(), lessThanOrEqualTo(1));
    });

    test('سلاسل غير صالحة تُرفض بلا استثناء في التحقق', () {
      expect(BlurHash.isValid(null), isFalse);
      expect(BlurHash.isValid(''), isFalse);
      expect(BlurHash.isValid('LEHV6nWB2yk8'), isFalse); // طول لا يطابق المكوّنات
      expect(BlurHash.isValid('LEHV6nWB2yk8pyo0adR*.7kCMdnj'), isTrue); // مثال blurha.sh
      expect(() => BlurHash.decode('bad', 4, 4), throwsArgumentError);
    });

    test('BMP صالح الرأس والحجم', () {
      final bmp = BlurHash.rgbaToBmp(_rgba(4, 3), 4, 3);
      expect(bmp[0], 0x42);
      expect(bmp[1], 0x4D);
      expect(bmp.length, 54 + 4 * 3 * 4);
    });
  });

  group('MediaPreview — الميتا والهبوط', () {
    test('قراءة/كتابة الميتا ونسبة مقصوصة', () {
      final hash = MediaPreview.hashFromRgba(_rgba(32, 24), 32, 24);
      final p = MediaPreview.fromMeta({'bh': hash, 'w': 1600, 'h': 1200, 'mk': 'x'});
      expect(p.hasHash, isTrue);
      expect(p.aspectRatio, closeTo(4 / 3, 1e-9));
      expect(p.toMeta(), {'bh': hash, 'w': 1600, 'h': 1200});
      // لقطة شاشة طويلة جداً تُقص لحد الفقاعة
      expect(MediaPreview.fromMeta({'w': 100, 'h': 2000}).aspectRatio, MediaPreview.minAspect);
    });

    test('الرسائل القديمة (بلا ميتا/ميتا ملف/هاش تالف) ⇒ معاينة فارغة', () {
      expect(MediaPreview.fromMeta(null).hasHash, isFalse);
      expect(MediaPreview.fromMeta(const {}).aspectRatio, isNull);
      expect(MediaPreview.fromMeta({'name': 'a.pdf', 'size': 3}).hasHash, isFalse);
      expect(MediaPreview.fromMeta({'bh': 'not-a-hash!'}).hasHash, isFalse);
      expect(MediaPreview.placeholderBytes(null), isNull);
    });

    test('المعاينة المفكوكة مخبأة حسب الهاش', () {
      final hash = MediaPreview.hashFromRgba(_rgba(24, 32), 24, 32);
      final a = MediaPreview.placeholderBytes(hash, aspect: 0.75)!;
      expect(identical(a, MediaPreview.placeholderBytes(hash, aspect: 0.75)), isTrue);
    });

    test('معرض الوسائط يقرأ مفاتيح المعاينة من الميتا المفكوكة، والقديمة بلاها', () {
      final hash = MediaPreview.hashFromRgba(_rgba(32, 24), 32, 24);
      final rows = [
        {'id': 'a', 'type': 'image', 'media_url': 'c/a.jpg', 'created_at': '2026-11-22T10:00:00Z',
         'sender_id': 'me', 'content': '{"mk":"k","bh":"$hash","w":1600,"h":1200}'},
        {'id': 'b', 'type': 'image', 'media_url': 'c/b.jpg', 'created_at': '2026-11-21T10:00:00Z',
         'sender_id': 'x', 'content': ''},
      ];
      final items = MediaGalleryService.collect(rows, (m) => m['content'] as String?, myId: 'me');
      expect(items.first.blurHash, hash);
      expect(items.first.width, 1600);
      expect(items.first.height, 1200);
      expect(items.first.caption, isNull); // الميتا ليست تعليقاً
      expect(items.last.blurHash, isNull);
      expect(MediaPreview(blurHash: items.last.blurHash).hasHash, isFalse);
    });

    testWidgets('الحساب عند الإرسال من بايتات صورة حقيقية (مفكك المنصة)', (t) async {
      final bmp = BlurHash.rgbaToBmp(_rgba(64, 48), 64, 48);
      final p = await t.runAsync(() => MediaPreview.compute(bmp));
      expect(p, isNotNull);
      expect(p!.width, 64);
      expect(p.height, 48);
      expect(p.hasHash, isTrue);
      // بيانات تالفة ⇒ null (يُرسل الوسيط كما كان)
      final bad = await t.runAsync(() => MediaPreview.compute(Uint8List.fromList([1, 2, 3])));
      expect(bad, isNull);
    });
  });

  group('ProgressiveImage — معاينة ضبابية ثم الصورة', () {
    testWidgets('بهاش: معاينة ضبابية فورية بصندوق بنسبة الأبعاد', (t) async {
      final hash = MediaPreview.hashFromRgba(_rgba(32, 16), 32, 16);
      await t.pumpWidget(_host(
        Center(
          child: ProgressiveImage(
            loader: () => Completer<Uint8List?>().future, // لا يكتمل: حالة التحميل
            preview: MediaPreview(blurHash: hash, width: 200, height: 100),
            width: 220,
          ),
        ),
        reduce: true,
      ));
      expect(find.byKey(const ValueKey('progressive-blur')), findsOneWidget);
      expect(find.byKey(const ValueKey('progressive-shimmer')), findsNothing);
      expect(t.getSize(find.byType(ProgressiveImage)), const Size(220, 110));
    });

    testWidgets('بلا هاش (رسالة قديمة): هيكل لامع بلون الثيم', (t) async {
      await t.pumpWidget(_host(
        Center(
          child: ProgressiveImage(
            loader: () => Completer<Uint8List?>().future, // لا يكتمل: حالة التحميل
            width: 220,
          ),
        ),
        reduce: true,
      ));
      expect(find.byKey(const ValueKey('progressive-shimmer')), findsOneWidget);
      expect(t.getSize(find.byType(ProgressiveImage)), const Size(220, 220));
    });

    testWidgets('فشل الفك ⇒ بديل الفشل', (t) async {
      await t.pumpWidget(_host(
        Center(
          child: ProgressiveImage(
            loader: () async => null,
            width: 220,
            failed: (_) => const Text('تعذّر'),
          ),
        ),
        reduce: true,
      ));
      await t.pump();
      expect(find.text('تعذّر'), findsOneWidget);
    });

    testWidgets('وصول البايتات ⇒ الصورة الكاملة فوق المعاينة ثم تُزال المعاينة', (t) async {
      final bytes = BlurHash.rgbaToBmp(_rgba(40, 20), 40, 20);
      final hash = MediaPreview.hashFromRgba(_rgba(32, 16), 32, 16);
      await t.pumpWidget(_host(
        Center(
          child: ProgressiveImage(
            loader: () async => bytes,
            preview: MediaPreview(blurHash: hash, width: 40, height: 20),
            width: 200,
          ),
        ),
        reduce: true,
      ));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await t.pump();
      expect(find.byKey(const ValueKey('progressive-full')), findsOneWidget);
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      await t.pump();
      expect(find.byKey(const ValueKey('progressive-blur')), findsNothing);
      expect(t.getSize(find.byType(ProgressiveImage)), const Size(200, 100)); // بلا قفز
    });
  });
}
