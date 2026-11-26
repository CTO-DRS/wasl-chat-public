import 'package:material_ui/material_ui.dart';

import '../services/app_studio_service.dart';
import '../theme.dart';

/// بريق الهياكل الموحّد (2.5.0 — ج4): متحكم حركة واحد وتدرج واحد لكل
/// شجرة فرعية. كل [WaslBone] داخلها يُرسم أبيض صلباً ثم يُلوَّن دفعة واحدة
/// بقناع [ShaderMask] — فلا متحكم لكل عظمة ولا إعادة بناء للأبناء في كل إطار
/// (AnimatedBuilder يعيد الرسم فقط، داخل RepaintBoundary).
///
/// - واعٍ للثيم: لون الأساس والبريق مشتقان من [WaslCtx.hairline] (فاتح/داكن)،
///   ويمكن فرض [dark] لخلفيات غامرة سوداء (عارض الحالات).
/// - صحيح الاتجاه: البريق يمشي باتجاه القراءة (يمين←يسار في العربية).
/// - يحترم تقليل الحركة: خيار الاستوديو أو disableAnimations في النظام ⇒
///   عظام ثابتة بلون الأساس بلا أي متحكم يعمل.
class WaslShimmer extends StatefulWidget {
  const WaslShimmer({super.key, required this.child, this.dark, this.period});

  final Widget child;

  /// فرض الألوان الداكنة (null = يتبع الثيم)
  final bool? dark;

  /// مدة دورة البريق (افتراضياً 1300ms)
  final Duration? period;

  /// هل الحركة مسموحة هنا؟ (الاستوديو + إعداد النظام)
  static bool motionAllowed(BuildContext context) =>
      AppStudioService.motionOn && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  /// لونا الأساس والبريق حسب السطوع
  static (Color base, Color highlight) colorsOf(BuildContext context, {bool? dark}) {
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? (Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.20))
        : (Colors.black.withValues(alpha: 0.06), Colors.black.withValues(alpha: 0.015));
  }

  @override
  State<WaslShimmer> createState() => _WaslShimmerState();
}

class _WaslShimmerState extends State<WaslShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: widget.period ?? const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    final on = WaslShimmer.motionAllowed(context);
    if (on && !_c.isAnimating) {
      _c.repeat();
    } else if (!on && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (base, hi) = WaslShimmer.colorsOf(context, dark: widget.dark);
    final animate = WaslShimmer.motionAllowed(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    Widget child = _ShimmerScope(animating: animate, child: widget.child);
    if (!animate) {
      // ثابت: لون الأساس فقط — بلا متحكم يعمل وبلا تدرج
      return ShaderMask(
        key: const ValueKey('wasl-shimmer-static'),
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => LinearGradient(colors: [base, base]).createShader(r),
        child: child,
      );
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          // الموضع من بداية السطر إلى نهايته: في RTL نعكس المحور
          final t = -1.6 + 3.2 * _c.value;
          final dx = rtl ? -t : t;
          final w = rtl ? -1.0 : 1.0;
          return ShaderMask(
            key: const ValueKey('wasl-shimmer-anim'),
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => LinearGradient(
              colors: [base, hi, base],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(dx, -0.3),
              end: Alignment(dx + w, 0.3),
            ).createShader(r),
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}

/// يعلن للعظام أنها داخل بريق (للاختبارات والتأكد من التصميم)
class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.animating, required super.child});
  final bool animating;

  @override
  bool updateShouldNotify(_ShimmerScope old) => old.animating != animating;
}

/// عظمة هيكل: مستطيل أو دائرة أو شريط نصي — تُرسم بيضاء ويلوّنها [WaslShimmer].
/// خارج بريق تُرسم بلون الأساس مباشرة (لا تختفي).
class WaslBone extends StatelessWidget {
  const WaslBone({super.key, this.width, this.height = 12, this.radius, this.circle = false});

  /// دائرة (صورة رمزية)
  const WaslBone.circle(double size, {super.key})
      : width = size,
        height = size,
        radius = null,
        circle = true;

  /// شريط نص بارتفاع سطر
  const WaslBone.line({super.key, this.width, this.height = 12})
      : radius = null,
        circle = false;

  final double? width;
  final double height;
  final double? radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final inShimmer = context.dependOnInheritedWidgetOfExactType<_ShimmerScope>() != null;
    final color = inShimmer ? Colors.white : WaslShimmer.colorsOf(context).$1;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius ?? height / 2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// هياكل جاهزة بحسب الشاشة — كلها تحت بريق واحد، وتستخدم EdgeInsetsDirectional
// فتنعكس تلقائياً في العربية.
// ---------------------------------------------------------------------------

/// شكل الصورة الرمزية في صف الهيكل
enum WaslBoneAvatar { circle, rounded, none }

/// صف قائمة: صورة رمزية + سطران + عنصر ختامي اختياري (وقت/أيقونة)
class WaslSkeletonRow extends StatelessWidget {
  const WaslSkeletonRow({
    super.key,
    this.index = 0,
    this.avatar = WaslBoneAvatar.circle,
    this.avatarSize = 52,
    this.lines = 2,
    this.trailing = true,
    this.trailingIcon = false,
  });

  final int index;
  final WaslBoneAvatar avatar;
  final double avatarSize;
  final int lines;
  final bool trailing;

  /// عنصر ختامي دائري (زر اتصال) بدل شريط الوقت
  final bool trailingIcon;

  @override
  Widget build(BuildContext context) {
    final i = index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WaslSpace.lg, vertical: WaslSpace.md),
      child: Row(children: [
        if (avatar == WaslBoneAvatar.circle) WaslBone.circle(avatarSize),
        if (avatar == WaslBoneAvatar.rounded)
          WaslBone(width: avatarSize, height: avatarSize, radius: WaslRadius.lg),
        if (avatar != WaslBoneAvatar.none) const SizedBox(width: WaslSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              WaslBone.line(width: 110.0 + (i % 3) * 30, height: 13),
              if (lines > 1) ...[
                const SizedBox(height: WaslSpace.sm),
                FractionallySizedBox(
                  widthFactor: 0.85 - (i % 4) * 0.12,
                  alignment: AlignmentDirectional.centerStart,
                  child: const WaslBone.line(height: 10),
                ),
              ],
            ],
          ),
        ),
        if (trailing) ...[
          const SizedBox(width: WaslSpace.md),
          trailingIcon ? const WaslBone.circle(28) : const WaslBone.line(width: 34, height: 9),
        ],
      ]),
    );
  }
}

/// هيكل قائمة لامع (1.13.0 → ج4): صفوف بشكل المحتوى الفعلي تحت بريق واحد
class WaslSkeletonList extends StatelessWidget {
  const WaslSkeletonList({
    super.key,
    this.rows = 8,
    this.avatar = WaslBoneAvatar.circle,
    this.avatarSize = 52,
    this.lines = 2,
    this.trailing = true,
    this.trailingIcon = false,
    this.header,
    this.padding,
  });

  final int rows;
  final WaslBoneAvatar avatar;
  final double avatarSize;
  final int lines;
  final bool trailing;
  final bool trailingIcon;

  /// عنصر فوق الصفوف (شريط حالات، عنوان قسم…) — تحت البريق نفسه
  final Widget? header;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'جارٍ التحميل',
      liveRegion: true,
      child: ExcludeSemantics(
        child: WaslShimmer(
          child: ListView.builder(
            padding: padding,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows + (header == null ? 0 : 1),
            itemBuilder: (_, i) {
              if (header != null && i == 0) return header!;
              final k = header == null ? i : i - 1;
              return WaslSkeletonRow(
                index: k,
                avatar: avatar,
                avatarSize: avatarSize,
                lines: lines,
                trailing: trailing,
                trailingIcon: trailingIcon,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// شريط حلقات الحالات (أعلى قائمة المحادثات) — بنفس قياس [StatusStrip]
class WaslSkeletonStatusStrip extends StatelessWidget {
  const WaslSkeletonStatusStrip({super.key, this.count = 5});
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: WaslSpace.md, vertical: WaslSpace.sm),
        itemCount: count,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsetsDirectional.only(end: WaslSpace.lg),
          child: SizedBox(
            width: 72,
            child: Column(children: [
              const WaslBone.circle(60),
              const SizedBox(height: WaslSpace.sm),
              WaslBone.line(width: 44.0 - (i % 2) * 8, height: 10),
            ]),
          ),
        ),
      ),
    );
  }
}

/// شبكة مربعات (معرض الوسائط)
class WaslSkeletonGrid extends StatelessWidget {
  const WaslSkeletonGrid({super.key, this.crossAxisCount = 3, this.count = 15, this.padding});
  final int crossAxisCount;
  final int count;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'جارٍ التحميل',
      child: ExcludeSemantics(
        child: WaslShimmer(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: padding ??
                const EdgeInsets.fromLTRB(WaslSpace.md, WaslSpace.xs, WaslSpace.md, WaslSpace.md),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: WaslSpace.xs,
              crossAxisSpacing: WaslSpace.xs,
            ),
            itemCount: count,
            itemBuilder: (_, _) => const WaslBone(radius: WaslRadius.xs),
          ),
        ),
      ),
    );
  }
}

/// فقاعات محادثة بالتناوب (بداية/نهاية) بأطوال مختلفة — تحميل المحادثة
class WaslSkeletonChat extends StatelessWidget {
  const WaslSkeletonChat({super.key, this.bubbles = 9, this.reverse = true});
  final int bubbles;

  /// الأحدث أسفل (كقائمة المحادثة المعكوسة)
  final bool reverse;

  /// نمط ثابت: نهاية = رسائلي
  static const _mine = [false, true, true, false, true, false, false, true, false, true];
  static const _widths = [0.55, 0.40, 0.62, 0.35, 0.50, 0.68, 0.30, 0.45, 0.58, 0.38];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'جارٍ تحميل الرسائل',
      child: ExcludeSemantics(
        child: WaslShimmer(
          child: LayoutBuilder(builder: (context, c) {
            final maxW = c.maxWidth.isFinite ? c.maxWidth : 360.0;
            return ListView.builder(
              reverse: reverse,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(WaslSpace.md),
              itemCount: bubbles,
              itemBuilder: (_, i) => WaslSkeletonBubble(
                mine: _mine[i % _mine.length],
                width: (maxW * _widths[i % _widths.length]).clamp(80.0, 420.0),
                tall: i % 4 == 2,
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// فقاعة هيكل واحدة (تُستخدم أيضاً لمؤشر «جلب الأقدم»)
class WaslSkeletonBubble extends StatelessWidget {
  const WaslSkeletonBubble({super.key, required this.mine, this.width = 180, this.tall = false});
  final bool mine;
  final double width;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: WaslSpace.xs),
        child: WaslBone(width: width, height: tall ? 64 : 40, radius: WaslRadius.lg),
      ),
    );
  }
}

/// رأس ملف شخصي/معلومات مجموعة: صورة كبيرة + اسم + سطر + أزرار + صفوف
class WaslSkeletonHeader extends StatelessWidget {
  const WaslSkeletonHeader({
    super.key,
    this.avatarSize = 112,
    this.actions = 3,
    this.rows = 4,
    this.cover = false,
  });
  final double avatarSize;
  final int actions;
  final int rows;

  /// شريط خلفية (الملف الشخصي)
  final bool cover;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'جارٍ التحميل',
      child: ExcludeSemantics(
        child: WaslShimmer(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(WaslSpace.xl),
            children: [
              Center(child: WaslBone.circle(avatarSize)),
              const SizedBox(height: WaslSpace.lg),
              if (cover) ...[
                const WaslBone(height: 110, radius: WaslRadius.md),
                const SizedBox(height: WaslSpace.lg),
              ],
              const Center(child: WaslBone.line(width: 160, height: 18)),
              const SizedBox(height: WaslSpace.sm),
              const Center(child: WaslBone.line(width: 110, height: 11)),
              if (actions > 0) ...[
                const SizedBox(height: WaslSpace.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < actions; i++)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: WaslSpace.md),
                        child: WaslBone(width: 64, height: 56, radius: WaslRadius.md),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: WaslSpace.xl),
              for (var i = 0; i < rows; i++)
                WaslSkeletonRow(
                  index: i,
                  avatarSize: 40,
                  trailing: false,
                  avatar: i == 0 ? WaslBoneAvatar.none : WaslBoneAvatar.circle,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
