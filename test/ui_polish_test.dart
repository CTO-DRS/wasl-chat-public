/// اختبارات صقل الواجهة (2.5.0): رموز التصميم، أوقات القائمة، فواصل الأيام،
/// تجميع الفقاعات، وشارة غير المقروء.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wasl_chat/services/app_studio_service.dart';
import 'package:wasl_chat/services/contrast_service.dart';
import 'package:wasl_chat/theme.dart';
import 'package:wasl_chat/widgets/common.dart';

void main() {
  // الأربعاء 18 نوفمبر 2026 ظهراً (توقيت محلي)
  final now = DateTime(2026, 11, 18, 12, 0);

  group('shortTime — وقت صف المحادثة', () {
    test('اليوم يعرض الساعة', () {
      expect(
        shortTime(DateTime(2026, 11, 18, 9, 5).toIso8601String(), now: now),
        '09:05',
      );
    });
    test('أمس', () {
      expect(
        shortTime(DateTime(2026, 11, 17, 23, 59).toIso8601String(), now: now),
        'أمس',
      );
    });
    test('خلال الأسبوع اسم اليوم', () {
      // 15 نوفمبر 2026 = الأحد
      expect(
        shortTime(DateTime(2026, 11, 15, 8).toIso8601String(), now: now),
        'الأحد',
      );
    });
    test('هذه السنة يوم/شهر، وما قبلها مع السنة', () {
      expect(
        shortTime(DateTime(2026, 3, 2).toIso8601String(), now: now),
        '2/3',
      );
      expect(
        shortTime(DateTime(2025, 3, 2).toIso8601String(), now: now),
        '2/3/25',
      );
    });
    test('قيمة فارغة أو تالفة لا ترمي', () {
      expect(shortTime(null), '');
      expect(shortTime('bad'), '');
    });
  });

  group('dayLabel — فاصل اليوم', () {
    test('اليوم وأمس واسم اليوم', () {
      expect(dayLabel(DateTime(2026, 11, 18, 1), now: now), 'اليوم');
      expect(dayLabel(DateTime(2026, 11, 17, 22), now: now), 'أمس');
      expect(dayLabel(DateTime(2026, 11, 13), now: now), 'الجمعة');
    });
    test('أقدم من أسبوع: يوم + شهر عربي، والسنة عند اختلافها', () {
      expect(dayLabel(DateTime(2026, 3, 12), now: now), '12 مارس');
      expect(dayLabel(DateTime(2025, 3, 12), now: now), '12 مارس 2025');
    });
    test('الأيام التقويمية تتجاهل الساعة', () {
      expect(
        calendarDaysBetween(
          DateTime(2026, 1, 1, 23, 59),
          DateTime(2026, 1, 2, 0, 1),
        ),
        1,
      );
      expect(
        calendarDaysBetween(
          DateTime(2026, 1, 2, 0, 1),
          DateTime(2026, 1, 2, 23),
        ),
        0,
      );
    });
  });

  group('BubbleLook — تجميع المتتاليات', () {
    final look = BubbleLook.resolve(
      StudioStyle.defaults.copyWith(bubbleTail: true),
      null,
    );

    test('بلا التصاق = الشكل السابق حرفياً', () {
      final r = look.borderRadius(mine: true) as BorderRadiusDirectional;
      expect(r.bottomEnd.x, 4);
      expect(r.topEnd.x, look.radius);
    });

    test('الالتصاق يضيّق زوايا جهة المرسل فقط والذيل على الأخيرة', () {
      final mid =
          look.borderRadius(mine: true, joinAbove: true, joinBelow: true)
              as BorderRadiusDirectional;
      expect(mid.topEnd.x, 6);
      expect(mid.bottomEnd.x, 6);
      expect(mid.topStart.x, look.radius);
      expect(mid.bottomStart.x, look.radius);

      final other =
          look.borderRadius(mine: false, joinAbove: true)
              as BorderRadiusDirectional;
      expect(other.topStart.x, 6);
      expect(other.bottomStart.x, 4); // آخر السلسلة: الذيل
      expect(other.topEnd.x, look.radius);
    });

    test('بلا ذيل وبلا التصاق = زوايا متساوية', () {
      final plain = BubbleLook.resolve(
        StudioStyle.defaults.copyWith(bubbleTail: false),
        null,
      );
      expect(plain.borderRadius(mine: false), isA<BorderRadius>());
    });
  });

  group('الثيم — رموز التصميم', () {
    test('لا تباعد أحرف في أي نمط (الحروف العربية تتصل)', () {
      for (final b in Brightness.values) {
        final t = WaslTheme.build(b, StudioStyle.defaults).textTheme;
        for (final st in [
          t.displayLarge,
          t.headlineMedium,
          t.titleLarge,
          t.titleMedium,
          t.bodyLarge,
          t.bodyMedium,
          t.labelLarge,
          t.labelSmall,
        ]) {
          expect(st?.letterSpacing, 0);
        }
      }
    });

    test('الأزرار بهدف لمس ≥48 واللقطات عائمة', () {
      final t = WaslTheme.dark;
      final min = t.filledButtonTheme.style!.minimumSize!.resolve({})!;
      expect(min.height, greaterThanOrEqualTo(48));
      expect(t.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(t.dialogTheme.shape, isA<RoundedRectangleBorder>());
    });

    test('أسطح الحوارات تطابق بطاقات وصل في الوضعين', () {
      expect(
        WaslTheme.dark.dialogTheme.backgroundColor,
        WaslColors.darkSurface,
      );
      expect(
        WaslTheme.light.dialogTheme.backgroundColor,
        WaslColors.lightSurface,
      );
    });

    test('ألوان أسماء المرسلين تجتاز AA على فقاعة الطرف الآخر', () {
      for (final c in WaslColors.senderOnDark) {
        expect(
          ContrastService.ratio(c, WaslColors.darkSurface),
          greaterThanOrEqualTo(4.5),
        );
      }
      for (final c in WaslColors.senderOnLight) {
        expect(
          ContrastService.ratio(c, WaslColors.lightBubble),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(
        ContrastService.ratio(WaslColors.tealInk, Colors.white),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('UnreadBadge', () {
    testWidgets('يخفى عند الصفر ويقصّ فوق 99 ويعلن العدد', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WaslTheme.dark,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Column(children: [UnreadBadge(0), UnreadBadge(150)]),
            ),
          ),
        ),
      );
      expect(find.text('0'), findsNothing);
      expect(find.text('99+'), findsOneWidget);
      expect(find.bySemanticsLabel('150 غير مقروءة'), findsOneWidget);
    });

    testWidgets('فاصل اليوم يُعرض عنواناً', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WaslTheme.light,
          home: const Scaffold(body: WaslDayChip('اليوم')),
        ),
      );
      expect(find.text('اليوم'), findsOneWidget);
    });
  });
}
