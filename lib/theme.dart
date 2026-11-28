import 'package:material_ui/material_ui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'services/app_studio_service.dart';
import 'services/contrast_service.dart';
import 'widgets/studio_backdrop.dart';

class WaslColors {
  static const indigo = Color(0xFF6366F1);
  static const teal = Color(0xFF14B8A6);

  /// طرف تدرج الهوية الثاني (أغمق من [teal] ليبلغ 3:1 مع النص الأبيض، بموافقة المالك)
  static const tealDeep = Color(0xFF0D9488);
  static const violet = Color(0xFFA855F7);
  static const darkBg = Color(0xFF0B0F1A);
  static const darkSurface = Color(0xFF151B2B);
  static const glass = Color(0x14FFFFFF);

  // لوحة الوضع الفاتح (0.7.1): ألوان محايدة باردة تحافظ على هوية النيلة/التركواز
  static const lightBg = Color(0xFFF2F4FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightGlass = Color(0x146366F1); // نيلة خفيفة تعمل على الفاتح
  static const ink = Color(0xFF1A2033); // نص أساسي على الفاتح
  static const ink2 = Color(0xFF5A6478); // نص ثانوي على الفاتح
  static const ink3 = Color(0xFF6B7590); // نص خافت على الفاتح — WCAG AA نص كبير ≥3:1 (صُدّل 1.2.0)
  static const ink4 = Color(0xFF7D87A0); // نص شبه معطل على الفاتح — WCAG AA كبير ≥3:1 (صُدّل 1.2.0)
  static const lightBubble = Color(0xFFE7EBF5); // فقاعة الطرف الآخر على الفاتح

  /// تدرج الهوية الأصلي الثابت (نيلة ← تركواز)
  static const brandGradient = LinearGradient(
    colors: [indigo, tealDeep],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  /// تدرج الهوية الحالي — يتبع ألوان «استوديو التطبيق» (1.13.0)،
  /// ويساوي [brandGradient] حرفياً في الافتراضي.
  static LinearGradient get gradient => AppStudioService.style.value.gradient;

  /// اللون الأساسي الحالي من الاستوديو (نيلة افتراضياً)
  static Color get accent => AppStudioService.style.value.accentColor;

  // ---- ألوان دلالية (2.5.0) — مصدر واحد بدل تكرار القيم في الشاشات ----
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const online = Color(0xFF22C55E);

  /// علامة «قُرئت» على فقاعتي (سماوي فاتح يقرأ فوق التدرج)
  static const readTick = Color(0xFF7DF9FF);

  // 2.5.0 (ج2): ألوان دلالية إضافية كانت مكررة صلبة في الشاشات
  static const info = Color(0xFF0EA5E9); // معلومة/تعديل/مؤشرات زرقاء سماوية
  static const pink = Color(0xFFEC4899); // ألبومات وإحصاءات التواصل
  static const verified = Color(0xFF2FBE63); // هوية متحقق منها (مفاتيح/QR)
  static const orange = Color(0xFFF97316); // خطورة عالية (أدنى من danger)
  static const immersiveBg = Color(0xFF121319); // خلفية العارض/المحرر الغامر
  static const shieldMint = Color(0xFF2DD4BF); // شارة درع الحماية على الوسائط

  /// تركواز داكن للنص على الفاتح: التركواز الأصلي 2.49:1 على الأبيض
  /// (زخرفي حصراً) — هذا ≈5.5:1 يجتاز AA للنص العادي
  static const tealInk = Color(0xFF0F766E);

  /// لوحة ألوان أسماء المرسلين في المجموعات (كتيليجرام): لكل عضو لون ثابت
  /// من معرّفه — نسختان: فاتحة للداكن، وداكنة للفاتح (كلتاهما ≥4.5:1)
  static const senderOnDark = <Color>[
    Color(0xFF5EEAD4), Color(0xFFA5B4FC), Color(0xFFF0ABFC), Color(0xFFFCD34D),
    Color(0xFF86EFAC), Color(0xFFFDA4AF), Color(0xFF7DD3FC), Color(0xFFFDBA74),
  ];
  static const senderOnLight = <Color>[
    Color(0xFF0F766E), Color(0xFF4338CA), Color(0xFF9D174D), Color(0xFF92400E),
    Color(0xFF166534), Color(0xFFBE123C), Color(0xFF0369A1), Color(0xFF9A3412),
  ];
}

/// مسافات وصل (2.5.0): سلّم 4 نقاط ثابت — استخدمه بدل الأرقام المتفرقة.
abstract final class WaslSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// الحشوة الأفقية القياسية لحواف الشاشة
  static const double screen = 16;
}

/// زوايا وصل (2.5.0) — القيم الأساسية قبل معامل «الاستدارة» في الاستوديو
/// (مرّرها عبر `style.r(...)` حين يجب أن تتبع اختيار المستخدم).
abstract final class WaslRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
  static const double xxl = 28;
  static const double pill = 999;

  /// زاوية الفقاعات المتجاورة من المرسل نفسه (جهة المرسل)
  static const double bubbleJoin = 6;
}

/// أحجام ثابتة: هدف اللمس الأدنى وأنصاف أقطار الصور الشخصية.
abstract final class WaslSize {
  /// أدنى هدف لمس (Material/WCAG 2.5.5)
  static const double minTap = 48;
  static const double avatarList = 26;
  static const double avatarAppBar = 20;
}

/// إيقاع الحركة (2.5.0): مدد ومنحنيات موحّدة للانتقالات الصغيرة.
/// سلّم الخط (2.5.0 — الجولة الثانية): أحجام النص الوحيدة المسموح بها في
/// الشاشات، وهي نفسها التي يبني منها [TextTheme] في الثيم — فلا حجم سحري
/// خارج السلّم. الحد الأدنى 11 للمقروئية (لا نص أصغر من [caption]).
abstract final class WaslFont {
  static const double caption = 11; // labelSmall — شارات ووسوم صغيرة
  static const double small = 12; // bodySmall / labelMedium — بيانات ثانوية
  static const double meta = 13; // سطر شرح وتواريخ
  static const double body = 14; // bodyMedium / labelLarge / titleSmall
  static const double bodyLarge = 15; // نص مريح للقراءة
  static const double title = 16; // bodyLarge / titleMedium — عناوين القوائم
  static const double titleLarge = 18; // عناوين الأقسام والحالات الفارغة
  static const double headline = 20; // عنوان الشريط العلوي
  static const double headlineLarge = 22; // titleLarge
  static const double display = 24; // headlineSmall
  static const double displayLarge = 28; // headlineMedium — رموز تعبيرية كبيرة
  static const double hero = 32; // headlineLarge — أرقام وواجهات ترحيب
}

/// لون النص الأنسب فوق خلفية معينة (WCAG): أبيض أو حبر داكن.
///
/// القاعدة: يُقاس التباين على متوسط ألوان الخلفية (للتدرج: متوسط محطاته).
/// الأبيض يبقى ما دام تباينه ≥ 3:1 (حد AA للنص الكبير/العريض وعناصر الواجهة)
/// حفاظاً على هوية العلامة على الدرجات المتوسطة كتدرج وصل الافتراضي؛ وإلا
/// يُختار الأعلى تبايناً — فالفقاعات والأزرار الفاتحة (أصفر، سماوي، وردي
/// فاتح) تأخذ حبراً داكناً مقروءاً بدل أبيض باهت.
abstract final class WaslContrast {
  /// حد AA للنص الكبير وعناصر الواجهة (من [ContrastService])
  static const double minWhite = ContrastService.aaLarge;

  static double ratio(Color a, Color b) => ContrastService.ratio(a, b);

  /// متوسط محطات التدرج (لون واحد = نفسه)
  static Color mean(List<Color> stops) {
    if (stops.length == 1) return stops.first;
    double a = 0, r = 0, g = 0, b = 0;
    for (final c in stops) {
      a += c.a;
      r += c.r;
      g += c.g;
      b += c.b;
    }
    final n = stops.length.toDouble();
    return Color.from(alpha: a / n, red: r / n, green: g / n, blue: b / n);
  }

  static Color onColor(Color bg) => onColors([bg]);

  static Color onColors(List<Color> stops) {
    final bg = mean(stops);
    final w = ratio(Colors.white, bg);
    if (w >= minWhite) return Colors.white;
    return ratio(WaslColors.ink, bg) > w ? WaslColors.ink : Colors.white;
  }

  /// هل الحبر المختار داكن؟ (لاشتقاق الألوان الثانوية والعلامات)
  static bool isDarkInk(Color ink) => ink.computeLuminance() < 0.5;
}

abstract final class WaslMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 320);
  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve pop = Curves.easeOutBack;
}

/// ألوان دلالية تتبع سطوع الثيم الحالي — استخدمها بدل Colors.white* و
/// WaslColors.dark* الصلبة حتى تعمل كل الشاشات على الوضعين معاً.
extension WaslCtx on BuildContext {
  bool get _dark => Theme.of(this).brightness == Brightness.dark;

  /// خلفية بطاقة/ورقة سفلية بديلة عن الخلفية
  Color get surfaceAlt => _dark ? WaslColors.darkSurface : WaslColors.lightSurface;

  /// زجاج العناصر البينية (شرائط إدخال، بطاقات شفافة)
  Color get glass => _dark ? WaslColors.glass : WaslColors.lightGlass;

  /// لون النص/الأيقونة فوق تدرج الهوية أو لون التمييز الذي يختاره المستخدم
  /// في الاستوديو (2.5.0): أبيض أو حبر داكن حسب التباين — لا أبيض دائماً.
  Color get onAccent => WaslContrast.onColors(WaslColors.gradient.colors);

  /// نص أساسي
  Color get textPrimary => _dark ? Colors.white : WaslColors.ink;

  /// نص ثانوي (white70 في الداكن)
  Color get textSecondary => _dark ? Colors.white70 : WaslColors.ink2;

  /// نص خافت (white60/white54 في الداكن)
  Color get textTertiary => _dark ? Colors.white60 : WaslColors.ink3;

  /// نص شبه معطل (white38/white54 في الداكن)
  Color get textFaint => _dark ? Colors.white54 : WaslColors.ink4;

  /// حدود وفواصل
  Color get hairline => _dark ? Colors.white24 : Colors.black.withValues(alpha: 0.10);

  /// فقاعة رسالة الطرف الآخر
  Color get bubbleOther => _dark ? WaslColors.darkSurface : WaslColors.lightBubble;

  /// لون الأيقونة القياسي غير الملوّن
  Color get iconStd => _dark ? Colors.white : WaslColors.ink2;

  /// خلفية شريط التطبيق (شفاف يعتمد الخلفية + لون نصه)
  Color get appBarText => _dark ? Colors.white : WaslColors.ink;

  /// لون نص مميّز مقروء (أسماء، روابط صغيرة، «يكتب…») — التركواز على الداكن
  /// والتركواز الداكن على الفاتح حتى يجتاز AA في الوضعين (2.5.0)
  Color get accentText => _dark ? WaslColors.teal : WaslColors.tealInk;

  /// لون اسم مرسل ثابت لكل عضو في المجموعات (2.5.0)
  Color senderColor(String? id) {
    final pal = _dark ? WaslColors.senderOnDark : WaslColors.senderOnLight;
    if (id == null || id.isEmpty) return pal.first;
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return pal[h % pal.length];
  }
}

class WaslTheme {
  static ThemeData get dark => build(Brightness.dark, StudioStyle.defaults);

  static ThemeData get light => build(Brightness.light, StudioStyle.defaults);

  /// يبني الثيم من اختيارات «استوديو التطبيق» (1.13.0). القيم الافتراضية
  /// تنتج الثيم السابق نفسه حرفياً — كل إضافة تُضاف فقط عند تغييرها.
  static ThemeData build(Brightness b, StudioStyle s) {
    final dark = b == Brightness.dark;
    final d = StudioStyle.defaults;
    final scheme = dark
        ? ColorScheme.fromSeed(seedColor: s.accentColor, brightness: Brightness.dark)
        : ColorScheme.fromSeed(seedColor: s.accentColor);
    final baseBg = dark ? WaslColors.darkBg : const Color(0xFFF2F4FA);
    final surface = dark ? WaslColors.darkSurface : WaslColors.lightSurface;
    final glass = dark ? WaslColors.glass : WaslColors.lightGlass;
    final hair = dark ? Colors.white24 : Colors.black.withValues(alpha: 0.10);
    final fg = dark ? Colors.white : WaslColors.ink;

    final Color scaffold = switch (s.backdrop) {
      StudioBackdrop.plain => baseBg,
      StudioBackdrop.pure => dark ? Colors.black : Colors.white,
      _ => Colors.transparent, // الخلفية تُرسم خلف كل صفحة
    };

    final appBar = switch (s.appBar) {
      StudioAppBar.transparent => const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
      StudioAppBar.glass => AppBarTheme(
          backgroundColor: glass,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
      StudioAppBar.solid => AppBarTheme(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          foregroundColor: fg,
          elevation: 0,
          centerTitle: false,
        ),
      StudioAppBar.gradient => AppBarTheme(
          backgroundColor: s.accentColor,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
    };

    final cardDefault = s.surface == d.surface && s.roundness == d.roundness;
    final card = cardDefault
        ? null
        : CardThemeData(
            color: switch (s.surface) {
              StudioSurface.glass => glass,
              StudioSurface.solid || StudioSurface.elevated => surface,
              StudioSurface.outlined => Colors.transparent,
            },
            elevation: s.surface == StudioSurface.elevated ? 4 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(s.r(16)),
              side: s.surface == StudioSurface.outlined
                  ? BorderSide(color: hair)
                  : BorderSide.none,
            ),
          );

    final density = switch (s.density) {
      StudioDensity.compact => VisualDensity.compact,
      StudioDensity.comfortable => null,
      StudioDensity.spacious => const VisualDensity(horizontal: 1, vertical: 1),
    };

    final needsWrap = s.backdrop != StudioBackdrop.plain &&
        s.backdrop != StudioBackdrop.pure;
    // 1.13.1: انتقال موحّد للتطبيق كله (تلاشٍ + انزلاق وتكبير خفيف ~260ms)
    // يحترم «مستوى الحركة»: خفيفة = تلاشٍ قصير، متوقفة = فوري
    final transitions = StudioPageTransitions(wrap: needsWrap, motion: s.motion);

    // 2.5.0: أسطح محايدة بهوية وصل بدل الأسطح البنفسجية المولّدة من البذرة —
    // الحوارات والأوراق والقوائم المنبثقة تتطابق مع بطاقات التطبيق في الوضعين
    final scheme2 = scheme.copyWith(
      surface: dark ? WaslColors.darkBg : WaslColors.lightSurface,
      onSurface: fg,
      onSurfaceVariant: dark ? const Color(0xFFB4BCD0) : WaslColors.ink2,
      surfaceContainerLowest: dark ? const Color(0xFF070A12) : Colors.white,
      surfaceContainerLow: dark ? const Color(0xFF111626) : const Color(0xFFF7F8FC),
      surfaceContainer: dark ? WaslColors.darkSurface : const Color(0xFFF0F2F8),
      surfaceContainerHigh: dark ? const Color(0xFF1B2236) : Colors.white,
      surfaceContainerHighest: dark ? const Color(0xFF232B42) : const Color(0xFFE6E9F2),
      outline: dark ? const Color(0xFF4A5470) : const Color(0xFF8A93A8),
      outlineVariant: dark ? const Color(0xFF262E42) : const Color(0xFFDDE1EB),
      error: WaslColors.danger,
      surfaceTint: Colors.transparent,
    );

    // الخط: العربية تتصل حروفها — أي تباعد أحرف (M3 يضع 0.1–0.5) يقطع
    // الوصل بصرياً؛ نصفّره في كل الأنماط مع أوزان وارتفاعات أسطر مريحة
    const z = 0.0;
    const textTheme = TextTheme(
      displayLarge: TextStyle(letterSpacing: z, fontWeight: FontWeight.w800),
      displayMedium: TextStyle(letterSpacing: z, fontWeight: FontWeight.w800),
      displaySmall: TextStyle(letterSpacing: z, fontWeight: FontWeight.w800),
      headlineLarge: TextStyle(fontSize: WaslFont.hero, letterSpacing: z, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(fontSize: WaslFont.displayLarge, letterSpacing: z, fontWeight: FontWeight.w800),
      headlineSmall: TextStyle(fontSize: WaslFont.display, letterSpacing: z, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: WaslFont.headlineLarge, letterSpacing: z, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: WaslFont.title, letterSpacing: z, fontWeight: FontWeight.w700),
      titleSmall: TextStyle(fontSize: WaslFont.body, letterSpacing: z, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: WaslFont.title, letterSpacing: z, height: 1.45),
      bodyMedium: TextStyle(fontSize: WaslFont.body, letterSpacing: z, height: 1.45),
      bodySmall: TextStyle(fontSize: WaslFont.small, letterSpacing: z, height: 1.4),
      labelLarge: TextStyle(fontSize: WaslFont.body, letterSpacing: z, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(fontSize: WaslFont.small, letterSpacing: z, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(fontSize: WaslFont.caption, letterSpacing: z, fontWeight: FontWeight.w600),
    );

    final rMd = BorderRadius.circular(s.r(WaslRadius.md));
    final rLg = BorderRadius.circular(s.r(WaslRadius.lg));
    final rXl = BorderRadius.circular(s.r(WaslRadius.xl));
    const minTap = Size(64, WaslSize.minTap);
    final btnShape = RoundedRectangleBorder(borderRadius: rMd);
    const btnText = TextStyle(fontWeight: FontWeight.w700, letterSpacing: z);

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme2,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: appBar.copyWith(
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: z,
            color: appBar.foregroundColor ?? fg),
        scrolledUnderElevation: 0,
      ),
      cardTheme: card,
      visualDensity: density,
      pageTransitionsTheme: transitions,
      dividerTheme: DividerThemeData(color: hair, thickness: 1, space: 1),
      dividerColor: hair,
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: s.navLabels
            ? NavigationDestinationLabelBehavior.alwaysShow
            : NavigationDestinationLabelBehavior.alwaysHide,
        labelTextStyle: WidgetStateProperty.resolveWith((st) => TextStyle(
              fontSize: 11.5,
              letterSpacing: z,
              fontWeight: st.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            )),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: WaslSpace.lg),
        minVerticalPadding: 10,
        horizontalTitleGap: 14,
        titleTextStyle: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: z, color: fg),
        subtitleTextStyle: TextStyle(
            fontSize: 13.5,
            height: 1.35,
            letterSpacing: z,
            color: dark ? Colors.white70 : WaslColors.ink2),
        iconColor: dark ? Colors.white70 : WaslColors.ink2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? WaslColors.glass : const Color(0x0F6366F1), // نيلة خفيفة تعمل على الفاتح
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 18, vertical: 14),
        hintStyle: TextStyle(color: dark ? Colors.white54 : WaslColors.ink4, letterSpacing: z),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(s.r(18)),
          borderSide: BorderSide.none,
        ),
        // تركيز مرئي (إمكانية الوصول): حدّ بلون الهوية بدل لا شيء
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(s.r(18)),
          borderSide: BorderSide(color: s.accentColor.withValues(alpha: 0.7), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(s.r(18)),
          borderSide: const BorderSide(color: WaslColors.danger, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: minTap, shape: btnShape, textStyle: btnText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
            minimumSize: minTap, shape: btnShape, textStyle: btnText, elevation: 0),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: minTap,
            shape: btnShape,
            textStyle: btnText,
            side: BorderSide(color: hair)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            minimumSize: const Size(48, WaslSize.minTap), shape: btnShape, textStyle: btnText),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s.r(12))),
        side: BorderSide(color: hair),
        labelStyle: const TextStyle(letterSpacing: z, fontWeight: FontWeight.w600),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s.r(WaslRadius.xxl))),
        titleTextStyle: TextStyle(
            fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: z, color: fg),
        contentTextStyle: TextStyle(
            fontSize: 14.5, height: 1.55, letterSpacing: z,
            color: dark ? Colors.white70 : WaslColors.ink2),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(s.r(WaslRadius.xxl)))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
            borderRadius: rLg, side: BorderSide(color: hair.withValues(alpha: 0.6))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF232B42) : WaslColors.ink,
        contentTextStyle: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: z),
        actionTextColor: WaslColors.teal,
        shape: RoundedRectangleBorder(borderRadius: rMd),
        elevation: 4,
        insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF232B42) : WaslColors.ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12.5, letterSpacing: z),
        waitDuration: const Duration(milliseconds: 400),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: s.accentColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: rLg),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: s.accentColor,
        linearTrackColor: hair,
        circularTrackColor: Colors.transparent,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
            minimumSize: const Size(48, 44),
            shape: RoundedRectangleBorder(borderRadius: rXl)),
      ),
    );
  }
}

/// انتقال صفحات وصل الموحّد (1.13.1): تلاشٍ مع انزلاق قصير وتكبير خفيف
/// للصفحة الداخلة، وتراجع خفيف للصفحة السابقة. المدة حسب «مستوى الحركة»:
/// كاملة 260ms، خفيفة 180ms (تلاشٍ فقط)، متوقفة = فوري بلا حركة.
class WaslPageTransitionsBuilder extends PageTransitionsBuilder {
  const WaslPageTransitionsBuilder(this.motion);
  final StudioMotion motion;

  static Duration durationFor(StudioMotion m) => switch (m) {
        StudioMotion.full => const Duration(milliseconds: 260),
        StudioMotion.reduced => const Duration(milliseconds: 180),
        StudioMotion.off => Duration.zero,
      };

  @override
  Duration get transitionDuration => durationFor(motion);

  @override
  Duration get reverseTransitionDuration => durationFor(motion);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    switch (motion) {
      case StudioMotion.off:
        return child;
      case StudioMotion.reduced:
        return FadeTransition(opacity: animation, child: child);
      case StudioMotion.full:
        final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
        final inC = CurvedAnimation(
            parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        final outC = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.85).animate(outC),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1, end: 0.97).animate(outC),
            child: FadeTransition(
              opacity: inC,
              child: SlideTransition(
                position: Tween<Offset>(begin: Offset(rtl ? -0.06 : 0.06, 0), end: Offset.zero)
                    .animate(inC),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.98, end: 1).animate(inC),
                  child: child,
                ),
              ),
            ),
          ),
        );
    }
  }
}

/// انتقالات الصفحات حسب الاستوديو: ترسم خلفية التطبيق خلف كل صفحة،
/// وتطبّق انتقال وصل الموحّد حسب «مستوى الحركة» على كل المنصات.
class StudioPageTransitions extends PageTransitionsTheme {
  StudioPageTransitions({required this.wrap, required this.motion})
      : super(builders: {
          for (final p in TargetPlatform.values) p: WaslPageTransitionsBuilder(motion),
        });
  final bool wrap;
  final StudioMotion motion;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final c = wrap ? StudioBackdropView(child: child) : child;
    return WaslPageTransitionsBuilder(motion)
        .buildTransitions(route, context, animation, secondaryAnimation, c);
  }

  @override
  bool operator ==(Object other) =>
      other is StudioPageTransitions && other.wrap == wrap && other.motion == motion;

  @override
  int get hashCode => Object.hash(wrap, motion);
}

/// وضع المظهر (داكن/فاتح/النظام) مع حفظه محلياً — الوضع الفاتح مكتمَل منذ 0.7.1.
class ThemeService {
  static const _key = 'theme_mode';
  static const _storage = FlutterSecureStorage();
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.dark);

  static Future<void> load() async {
    try {
      final v = await _storage.read(key: _key);
      mode.value = switch (v) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
    } catch (_) {}
  }

  static Future<void> set(ThemeMode m) async {
    mode.value = m;
    try {
      final v = switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        _ => 'dark',
      };
      await _storage.write(key: _key, value: v);
    } catch (_) {}
  }
}

/// حجم خط التطبيق كنسبة تكبير تُطبَّق على كل النصوص عبر TextScaler.
/// الخيارات: 0.85 صغير، 1.0 عادي، 1.15 كبير، 1.3 أكبر.
class FontScaleService {
  static const _key = 'font_scale';
  static const _storage = FlutterSecureStorage();
  static final ValueNotifier<double> scale = ValueNotifier(1.0);

  /// الخيارات المعروضة في الإعدادات (القيمة، التسمية العربية)
  static const options = <(double, String)>[
    (0.85, 'صغير'),
    (1.0, 'عادي'),
    (1.15, 'كبير'),
    (1.3, 'أكبر'),
  ];

  static Future<void> load() async {
    try {
      final v = double.tryParse(await _storage.read(key: _key) ?? '') ?? 1.0;
      scale.value = v.clamp(0.8, 1.5);
    } catch (_) {}
  }

  static Future<void> set(double v) async {
    scale.value = v;
    try {
      await _storage.write(key: _key, value: v.toString());
    } catch (_) {}
  }
}

/// خلفية شاشة المحادثة: مضمنة داخل التطبيق (لا تنزيلات ولا وسائط خارجية — الخصوصية).
/// 0 = افتراضي (لون الخلفية فقط بلا نمط).
class WallpaperService {
  static const _key = 'chat_wallpaper';
  static const _storage = FlutterSecureStorage();
  static final ValueNotifier<int> index = ValueNotifier(0);

  static final wallpapers = const <WaslWallpaper>[
    WaslWallpaper('افتراضي'),
    WaslWallpaper('ليل وصل', colors: [Color(0xFF0B0F1A), Color(0xFF171F38)], dot: Color(0x14FFFFFF)),
    WaslWallpaper('نيلة', colors: [Color(0xFF10142A), Color(0xFF2A2450)], dot: Color(0x1AFFFFFF)),
    WaslWallpaper('تركواز', colors: [Color(0xFF0A1A1E), Color(0xFF123B3A)], dot: Color(0x18FFFFFF)),
    WaslWallpaper('بنفسج', colors: [Color(0xFF140F1E), Color(0xFF34204A)], dot: Color(0x16FFFFFF)),
    WaslWallpaper('رملي فاتح', colors: [Color(0xFFEFF2F9), Color(0xFFE4E9F4)], dot: Color(0x336366F1)),
    WaslWallpaper('نيلي فاتح', colors: [Color(0xFFEEF1FB), Color(0xFFE3E9FA)], dot: Color(0x2E14B8A6)),
  ];

  static WaslWallpaper get current =>
      (index.value >= 0 && index.value < wallpapers.length) ? wallpapers[index.value] : wallpapers.first;

  static Future<void> load() async {
    try {
      final v = int.tryParse(await _storage.read(key: _key) ?? '') ?? 0;
      index.value = v.clamp(0, wallpapers.length - 1);
    } catch (_) {}
  }

  static Future<void> set(int i) async {
    index.value = i;
    try {
      await _storage.write(key: _key, value: '$i');
    } catch (_) {}
  }
}

class WaslWallpaper {
  final String name;
  final List<Color>? colors; // تدرج الخلفية؛ null = لون الثيم الافتراضي
  final Color? dot; // لون نمط النقاط؛ null = بلا نمط
  const WaslWallpaper(this.name, {this.colors, this.dot});
}

/// يرسم خلفية المحادثة: تدرج ناعم + شبكة نقاط خافتة (نمط مجاني ومضمن).
class WallpaperPainter extends CustomPainter {
  final WaslWallpaper wallpaper;
  final bool dark;
  WallpaperPainter(this.wallpaper, {required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    if (wallpaper.colors != null && wallpaper.colors!.length >= 2) {
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: wallpaper.colors!,
          ).createShader(rect),
      );
    }
    final dot = wallpaper.dot;
    if (dot != null) {
      const gap = 26.0;
      final r = 1.4;
      final p = Paint()..color = dot;
      for (double y = gap / 2; y < size.height; y += gap) {
        for (double x = gap / 2; x < size.width; x += gap) {
          canvas.drawCircle(Offset(x, y), r, p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant WallpaperPainter old) =>
      old.wallpaper != wallpaper || old.dark != dark;
}

/// حبر فقاعتي (2.5.0): لون النص والوقت والعلامات يُشتق من تباين لون
/// الفقاعة الذي اختاره المستخدم (لون واحد أو تدرج) — لا أبيض دائماً.
extension BubbleInk on BubbleLook {
  List<Color> get _stops => gradient?.colors ?? [ownColor];

  /// النص الأساسي فوق فقاعتي
  Color get ownInk => WaslContrast.onColors(_stops);

  /// نص ثانوي (الوقت، الاقتباس، الترجمة)
  Color get ownInkSecondary => ownInk.withValues(alpha: 0.78);

  /// نص خافت (معدّلة، المؤقت، المحذوف)
  Color get ownInkTertiary => ownInk.withValues(alpha: 0.64);

  /// علامة «قُرئت»: سماوي متوهج فوق الداكن، وتركواز حبري فوق الفاتح
  Color get ownReadTick =>
      WaslContrast.isDarkInk(ownInk) ? WaslColors.tealInk : WaslColors.readTick;

  /// خلفية الاقتباس داخل فقاعتي: تظليل يعاكس الحبر ليبقى ظاهراً
  Color get ownQuoteFill => WaslContrast.isDarkInk(ownInk)
      ? Colors.white.withValues(alpha: 0.35)
      : Colors.black.withValues(alpha: 0.18);
}
