/// الملف الشخصي (2.5.0 — ج6) + إصلاح رفع الصورة/الخلفية + صف الردود السريعة.
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wasl_chat/services/profile_image_service.dart';
import 'package:wasl_chat/theme.dart';
import 'package:wasl_chat/widgets/profile_header.dart';
import 'package:wasl_chat/widgets/quick_reply_row.dart';

Widget _host(Widget child,
        {TextDirection dir = TextDirection.rtl,
        bool reduce = false,
        ThemeData? theme,
        Size size = const Size(400, 800)}) =>
    MaterialApp(
      theme: theme ?? WaslTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: reduce),
        child: Directionality(textDirection: dir, child: Scaffold(body: child)),
      ),
    );

Uint8List _png(int w, int h, {bool alpha = false}) {
  final im = img.Image(width: w, height: h, numChannels: alpha ? 4 : 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgba(x, y, (x * 7) % 256, (y * 3) % 256, (x + y) % 256, alpha ? 0 : 255);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

const _uid = '0b6f8c3e-1111-4222-8333-944455556666';

void main() {
  group('ProfileImageService — مسار الرفع ومعاملاته', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1763790000000);

    test('المسار داخل مجلد uid (شرط سياسة avatars insert own) وامتداد jpg', () {
      expect(ProfileImageService.pathFor(_uid, ProfileImageKind.avatar, now),
          '$_uid/1763790000000.jpg');
      expect(ProfileImageService.pathFor(_uid, ProfileImageKind.cover, now),
          '$_uid/cover_1763790000000.jpg');
      expect(ProfileImageService.bucket, 'avatars');
    });

    test('خيارات الرفع: نوع JPEG صريح مطابق للمحتوى وبلا upsert', () {
      final o = ProfileImageService.fileOptions();
      expect(o.contentType, 'image/jpeg');
      expect(o.upsert, isFalse);
    });

    test('مسار القديم من الرابط العام: داخل مجلدي ومن النوع نفسه فقط', () {
      const base = 'https://x.supabase.co/storage/v1/object/public/avatars';
      expect(
          ProfileImageService.ownedPathFromUrl(
              '$base/$_uid/123.jpg', _uid, ProfileImageKind.avatar),
          '$_uid/123.jpg');
      expect(
          ProfileImageService.ownedPathFromUrl(
              '$base/$_uid/cover_9.png?t=1', _uid, ProfileImageKind.cover),
          '$_uid/cover_9.png');
      // الخلفية لا تحذف الصورة والعكس، ولا ملفات مستخدم آخر
      expect(
          ProfileImageService.ownedPathFromUrl(
              '$base/$_uid/cover_9.png', _uid, ProfileImageKind.avatar),
          isNull);
      expect(
          ProfileImageService.ownedPathFromUrl(
              '$base/$_uid/123.jpg', _uid, ProfileImageKind.cover),
          isNull);
      expect(
          ProfileImageService.ownedPathFromUrl(
              '$base/other-user/123.jpg', _uid, ProfileImageKind.avatar),
          isNull);
      expect(ProfileImageService.ownedPathFromUrl(null, _uid, ProfileImageKind.avatar), isNull);
    });

    test('تحضير الصورة الشخصية: قص مربع وتصغير إلى 512 وJPEG ضمن الحد', () {
      final out = ProfileImageService.prepareSync(_png(1200, 800), ProfileImageKind.avatar);
      expect(out.width, 512);
      expect(out.height, 512);
      expect(out.contentType, 'image/jpeg');
      expect(out.bytes.length, lessThanOrEqualTo(ProfileImageService.maxBytes));
      expect(out.bytes.sublist(0, 2), [0xFF, 0xD8]); // توقيع JPEG
    });

    test('تحضير الخلفية: يحافظ على النسبة ضمن 1280×720 ويسطّح الشفافية', () {
      final out = ProfileImageService.prepareSync(
          _png(2560, 1080, alpha: true), ProfileImageKind.cover);
      expect(out.width, lessThanOrEqualTo(1280));
      expect(out.height, lessThanOrEqualTo(720));
      expect((out.width / out.height - 2560 / 1080).abs(), lessThan(0.02));
      final decoded = img.decodeJpg(out.bytes)!;
      final p = decoded.getPixel(5, 5);
      expect(p.r, greaterThan(200)); // شفاف → أبيض لا أسود
    });

    test('صورة صغيرة لا تُكبَّر', () {
      final out = ProfileImageService.prepareSync(_png(300, 200), ProfileImageKind.cover);
      expect(out.width, 300);
      expect(out.height, 200);
    });

    test('بايتات غير صورة (مثل HEIC) → رسالة عربية واضحة', () {
      expect(
          () => ProfileImageService.prepareSync(
              Uint8List.fromList(List.filled(64, 7)), ProfileImageKind.avatar),
          throwsA(isA<ProfileImageException>()
              .having((e) => e.message, 'message', contains('غير مدعومة'))));
      expect(() => ProfileImageService.prepareSync(Uint8List(0), ProfileImageKind.avatar),
          throwsA(isA<ProfileImageException>()));
    });

    test('ترجمة الخطأ الحقيقي: RLS، الحجم، النوع، العمود المفقود، الشبكة', () {
      String d(Object e, [ProfileImageKind k = ProfileImageKind.avatar]) =>
          ProfileImageService.describeError(e, kind: k);
      expect(d(const StorageException('new row violates row-level security policy',
              statusCode: '403')),
          contains('الإذن'));
      expect(d(const StorageException('The object exceeded the maximum allowed size',
              statusCode: '413')),
          contains('الحجم'));
      expect(d(const StorageException('mime type image/heic is not supported',
              statusCode: '415')),
          contains('نوع'));
      expect(
          d(const PostgrestException(
                  message: 'column profiles.cover_url does not exist', code: '42703'),
              ProfileImageKind.cover),
          contains('044'));
      expect(ProfileImageService.isMissingColumn(
              const PostgrestException(message: 'x', code: '42703')),
          isTrue);
      expect(d(Exception('ClientException: Failed host lookup')), contains('الشبكة'));
      expect(d(const ProfileImageException('رسالة')), 'رسالة');
    });
  });

  group('رأس الملف الشخصي', () {
    Widget page({bool reduce = false, ThemeData? theme, TextDirection dir = TextDirection.rtl}) =>
        _host(
          CustomScrollView(slivers: [
            const ProfileCoverAppBar(title: 'رشيد'),
            SliverToBoxAdapter(
              child: Column(children: [
                ProfileAvatarBadge(name: 'رشيد', onTap: () {}, onEdit: () {}),
                ProfileIdentity(
                  name: 'اسم عربي طويل جداً جداً جداً يتجاوز عرض الشاشة بكثير بلا شك ' * 2,
                  username: 'rashid_dev_with_a_really_long_handle_name',
                  verified: true,
                  onCopyUsername: () {},
                  onEditUsername: () {},
                ),
                ProfileStatusLine(online: true, joinedAt: DateTime(2026, 11, 6)),
                const ExpandableBio(text: 'نبذة قصيرة'),
                ProfileQuickActions(actions: [
                  ProfileAction(icon: Icons.ios_share_rounded, label: 'مشاركة', onTap: () {}),
                  ProfileAction(icon: Icons.qr_code_2_rounded, label: 'رمز QR', onTap: () {}),
                  ProfileAction(icon: Icons.edit_rounded, label: 'تعديل', onTap: () {}),
                  ProfileAction(
                      icon: Icons.link_rounded, label: 'نسخ الرابط الطويل جداً', onTap: null),
                ]),
                const SizedBox(height: 1200),
              ]),
            ),
          ]),
          reduce: reduce,
          theme: theme,
          dir: dir,
          size: const Size(320, 700),
        );

    for (final (label, theme) in [('داكن', WaslTheme.dark), ('فاتح', WaslTheme.light)]) {
      testWidgets('بلا فيض في $label وRTL على شاشة 320', (tester) async {
        await tester.pumpWidget(page(theme: theme));
        expect(tester.takeException(), isNull);
        expect(find.text('متصل الآن'), findsOneWidget);
        expect(find.text('انضم في نوفمبر 2026'), findsOneWidget);
      });
    }

    testWidgets('LTR وتقليل الحركة: يُطوى بالتمرير بلا أخطاء', (tester) async {
      await tester.pumpWidget(page(reduce: true, dir: TextDirection.ltr));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();
      expect(tester.takeException(), isNull);
      // مطويّاً يظهر الاسم في الشريط
      expect(find.text('رشيد'), findsWidgets);
    });

    testWidgets('أهداف لمس ≥48 لشارة التعديل والنسخ والإجراءات', (tester) async {
      await tester.pumpWidget(page());
      final edit = find.byTooltip('تغيير الصورة الشخصية');
      final copy = find.byTooltip('نسخ اسم المستخدم');
      for (final f in [edit, copy]) {
        final s = tester.getSize(f);
        expect(s.width, greaterThanOrEqualTo(48));
        expect(s.height, greaterThanOrEqualTo(48));
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('Semantics: الإجراءات أزرار بتسميات عربية، والمعطّل معطّل', (tester) async {
      final h = tester.ensureSemantics();
      await tester.pumpWidget(page());
      expect(find.bySemanticsLabel('مشاركة'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('نسخ الرابط الطويل جداً'));
      expect(node.flagsCollection.isEnabled, isNot(true));
      h.dispose();
    });

    testWidgets('النبذة الطويلة تُختصر ثم تتوسع بـ«المزيد»', (tester) async {
      await tester.pumpWidget(_host(ExpandableBio(text: 'سطر طويل من النبذة ' * 40)));
      expect(find.text('المزيد'), findsOneWidget);
      Text bio() => tester.widget<Text>(find.byKey(const ValueKey('profile-bio')));
      expect(bio().maxLines, 3);
      await tester.tap(find.text('المزيد'));
      await tester.pumpAndSettle();
      expect(bio().maxLines, isNull);
      expect(find.text('أقل'), findsOneWidget);
    });

    testWidgets('النبذة القصيرة بلا زر توسيع', (tester) async {
      await tester.pumpWidget(_host(const ExpandableBio(text: 'مرحباً')));
      expect(find.text('المزيد'), findsNothing);
    });

    testWidgets('ورقة الصورة: عرض/تغيير/إزالة حسب وجود الصورة', (tester) async {
      ProfileImageChoice? got;
      await tester.pumpWidget(_host(Builder(
          builder: (c) => TextButton(
              onPressed: () async =>
                  got = await showProfileImageSheet(c, title: 'الصورة الشخصية', hasImage: true),
              child: const Text('فتح')))));
      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();
      expect(find.text('عرض'), findsOneWidget);
      expect(find.text('تغيير'), findsOneWidget);
      expect(find.text('إزالة'), findsOneWidget);
      await tester.tap(find.text('إزالة'));
      await tester.pumpAndSettle();
      expect(got, ProfileImageChoice.remove);
    });
  });

  group('ورقة تعديل الاسم والنبذة', () {
    test('قواعد التحقق تطابق قيود الجدول', () {
      expect(ProfileEditSheet.validateName('  '), isNotNull);
      expect(ProfileEditSheet.validateName('ر' * 40), isNull);
      expect(ProfileEditSheet.validateName('ر' * 41), isNotNull);
      expect(ProfileEditSheet.validateBio('ن' * 140), isNull);
      expect(ProfileEditSheet.validateBio('ن' * 141), isNotNull);
    });

    Future<void> open(WidgetTester tester, Future<String?> Function(ProfileEditResult) onSave,
        void Function(ProfileEditResult?) done) async {
      await tester.pumpWidget(_host(Builder(
          builder: (c) => TextButton(
              onPressed: () async {
                final r = await showModalBottomSheet<ProfileEditResult>(
                  context: c,
                  isScrollControlled: true,
                  builder: (_) => ProfileEditSheet(
                      initialName: 'رشيد', initialBio: '', onSave: onSave),
                );
                done(r);
              },
              child: const Text('تعديل')))));
      await tester.tap(find.text('تعديل'));
      await tester.pumpAndSettle();
    }

    testWidgets('الحفظ معطّل بلا تغيير، وعدّاد حي، ونجاح يعيد النتيجة', (tester) async {
      ProfileEditResult? result;
      ProfileEditResult? saved;
      await open(tester, (r) async {
        saved = r;
        return null;
      }, (r) => result = r);
      FilledButton save() => tester.widget(find.byKey(const ValueKey('edit-save')));
      expect(save().onPressed, isNull);
      expect(find.text('4/40'), findsOneWidget); // «رشيد» + عدّاد حي
      await tester.enterText(find.byKey(const ValueKey('edit-bio')), 'مطور');
      await tester.pump();
      expect(find.text('4/140'), findsOneWidget);
      expect(save().onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('edit-save')));
      await tester.pumpAndSettle();
      expect(saved?.bio, 'مطور');
      expect(result?.name, 'رشيد');
      // التخلص من المتحكمات بعد الإغلاق لا يرمي
      expect(tester.takeException(), isNull);
    });

    testWidgets('خطأ الحفظ يُعرض داخل الورقة ولا تُغلق', (tester) async {
      ProfileEditResult? result;
      await open(tester, (r) async => 'تعذّر الحفظ', (r) => result = r);
      await tester.enterText(find.byKey(const ValueKey('edit-name')), 'رشيد نجيب');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('edit-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('edit-error')), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('اسم فارغ يعطّل الحفظ', (tester) async {
      await open(tester, (r) async => null, (_) {});
      await tester.enterText(find.byKey(const ValueKey('edit-name')), '');
      await tester.pump();
      final save = tester.widget<FilledButton>(find.byKey(const ValueKey('edit-save')));
      expect(save.onPressed, isNull);
    });
  });

  group('صف الردود السريعة (إصلاح القص عند الحواف)', () {
    final replies = ['تمام', 'شكراً جزيلاً', 'إن شاء الله نلتقي قريباً', 'ممتاز', 'أكيد'];

    testWidgets('لا قص عمودي: ارتفاع الصف يتسع لهدف اللمس 48', (tester) async {
      await tester.pumpWidget(_host(Align(
          alignment: Alignment.bottomCenter,
          child: QuickReplyRow(replies: replies, onReply: (_) {}, onStyle: () {}))));
      expect(tester.takeException(), isNull);
      final row = tester.getRect(find.byType(QuickReplyRow));
      final chip = tester.getRect(find.byType(ActionChip).first);
      expect(chip.top, greaterThanOrEqualTo(row.top));
      expect(chip.bottom, lessThanOrEqualTo(row.bottom));
      expect(row.height, greaterThanOrEqualTo(48));
    });

    testWidgets('أول شريحة بحشوة من بداية الاتجاه (RTL يمين، LTR يسار)', (tester) async {
      for (final dir in [TextDirection.rtl, TextDirection.ltr]) {
        await tester.pumpWidget(_host(
            Align(
                alignment: Alignment.bottomCenter,
                child: QuickReplyRow(replies: replies, onReply: (_) {}, onStyle: () {})),
            dir: dir));
        final first = tester.getRect(find.byKey(const ValueKey('quick-style')));
        final row = tester.getRect(find.byType(QuickReplyRow));
        if (dir == TextDirection.rtl) {
          expect(row.right - first.right, greaterThanOrEqualTo(WaslSpace.md - 0.5));
        } else {
          expect(first.left - row.left, greaterThanOrEqualTo(WaslSpace.md - 0.5));
        }
      }
    });

    testWidgets('قابل للتمرير أفقياً ويصل لآخر رد، والنقر يعيد النص', (tester) async {
      String? tapped;
      await tester.pumpWidget(_host(Align(
          alignment: Alignment.bottomCenter,
          child: QuickReplyRow(replies: replies, onReply: (r) => tapped = r))));
      await tester.dragUntilVisible(
          find.text('أكيد'), find.byType(ListView), const Offset(300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'أكيد'));
      expect(tapped, 'أكيد');
    });

    testWidgets('رد طويل جداً يُختصر بلا فيض', (tester) async {
      await tester.pumpWidget(_host(QuickReplyRow(
          replies: ['رد طويل جداً ' * 20], onReply: (_) {})));
      expect(tester.takeException(), isNull);
      final t = tester.widget<Text>(find.textContaining('رد طويل'));
      expect(t.overflow, TextOverflow.ellipsis);
    });

    testWidgets('بلا ردود ولا صياغة: لا شيء', (tester) async {
      await tester.pumpWidget(_host(QuickReplyRow(replies: const [], onReply: (_) {})));
      expect(find.byType(ListView), findsNothing);
    });
  });
}
