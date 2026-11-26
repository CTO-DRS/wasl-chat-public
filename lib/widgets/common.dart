import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'wasl_mascot.dart';
import '../services/app_studio_service.dart';

// هياكل التحميل اللامعة الموحّدة (ج4) — متاحة لكل من يستورد common
export 'shimmer.dart';

/// إجمالي الرسائل غير المقروءة عبر المحادثات — يشغّل شارة تبويب
/// «المحادثات» في الشريط السفلي (تتحدث مع كل تحميل للقائمة).
class UnreadHub {
  static final ValueNotifier<int> total = ValueNotifier<int>(0);
}

/// مؤقّت تهدئة لحقول البحث: لا نضرب الخادم بكل حرف،
/// بل ننفّذ البحث بعد توقّف الكتابة عن الحركة.
class Debouncer {
  Debouncer([this.delay = const Duration(milliseconds: 400)]);
  final Duration delay;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}

/// الزر العائم الموحّد للتطبيق: تدرج العلامة (نيلة -> تركواز) بزوايا ناعمة
/// وظل هادئ — يستخدم في المحادثات والقنوات والمجتمعات بدل الألوان المتضاربة.
class WaslFab extends StatelessWidget {
  const WaslFab({super.key, required this.onPressed, required this.icon, this.tooltip});
  final VoidCallback onPressed;
  final IconData icon;

  /// وصف للقارئ الصوتي وتلميح عند الضغط المطوّل (2.5.0)
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final fab = Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: WaslColors.gradient,
        borderRadius: BorderRadius.circular(WaslRadius.lg),
        boxShadow: [
          BoxShadow(
            color: WaslColors.indigo.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WaslRadius.lg)),
          onTap: onPressed,
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
    final t = tooltip;
    return Semantics(
      button: true,
      label: t,
      child: t == null ? fab : Tooltip(message: t, child: fab),
    );
  }
}

/// حالة فراغ موحّدة: أيقونة داخل حلقة زجاجية + عنوان + شرح —
/// تستخدم في المحادثات والقنوات والمجتمعات بدل النصوص العارية.
class GlassEmptyState extends StatelessWidget {
  const GlassEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String? subtitle;

  /// زر إجراء اختياري تحت الشرح (2.5.0) — الحالة الفارغة تقود لخطوة تالية
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WaslSpace.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // «وصول» يؤنس الحالة الفارغة (1.13.0) مع أيقونة القسم بجانبه
            SizedBox(
              width: 120,
              height: 112,
              child: Stack(clipBehavior: Clip.none, children: [
                const Center(child: WaslMascot(size: 104, mood: MascotMood.sleepy)),
                PositionedDirectional(
                  end: 0,
                  bottom: 4,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: context.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.hairline),
                    ),
                    child: Icon(icon, size: 19, color: context.iconStd),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: WaslSpace.xl),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: WaslFont.titleLarge, fontWeight: FontWeight.w800, color: context.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: WaslSpace.sm),
              ConstrainedBox(
                // سطر مريح القراءة على الشاشات العريضة
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        height: 1.7,
                        color: context.textTertiary,
                        fontSize: WaslFont.body)),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: WaslSpace.xl),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String previewText(Map<String, dynamic> row, {String empty = 'لا توجد رسائل بعد'}) {
  switch (row['last_type']) {
    case 'image':
      return '📷 صورة';
    case 'voice':
      return '🎤 رسالة صوتية';
    case 'video':
      return '🎬 فيديو';
    case 'file':
      return '📎 ملف';
    default:
      return (row['last_message'] as String?) ?? empty;
  }
}

/// وقت مختصر لصف المحادثة (2.5.0 — كواتساب/تيليجرام): اليوم = الساعة،
/// أمس = «أمس»، خلال الأسبوع = اسم اليوم، هذه السنة = يوم/شهر، وإلا يوم/شهر/سنة.
String shortTime(String? iso, {DateTime? now}) {
  if (iso == null) return '';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '';
  final d = parsed.toLocal();
  final n = now ?? DateTime.now();
  final days = calendarDaysBetween(d, n);
  if (days == 0) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  if (days == 1) return 'أمس';
  if (days > 1 && days < 7) return arabicWeekdays[d.weekday - 1];
  if (d.year == n.year) return '${d.day}/${d.month}';
  return '${d.day}/${d.month}/${d.year % 100}';
}

/// عدد الأيام التقويمية بين تاريخين (بتجاهل الساعة) — موجب إن كان [a] قبل [b]
int calendarDaysBetween(DateTime a, DateTime b) {
  final da = DateTime.utc(a.year, a.month, a.day);
  final db = DateTime.utc(b.year, b.month, b.day);
  return db.difference(da).inDays;
}

const arabicWeekdays = <String>[
  'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
];

const arabicMonths = <String>[
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// عنوان فاصل اليوم داخل المحادثة: اليوم / أمس / اسم اليوم / ١٢ مارس [٢٠٢٥]
String dayLabel(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final days = calendarDaysBetween(d, n);
  if (days == 0) return 'اليوم';
  if (days == 1) return 'أمس';
  if (days > 1 && days < 7) return arabicWeekdays[d.weekday - 1];
  final base = '${d.day} ${arabicMonths[d.month - 1]}';
  return d.year == n.year ? base : '$base ${d.year}';
}

/// رقاقة فاصل اليوم العائمة وسط المحادثة (2.5.0)
class WaslDayChip extends StatelessWidget {
  const WaslDayChip(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      header: true,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: WaslSpace.md),
          padding: const EdgeInsets.symmetric(horizontal: WaslSpace.md, vertical: WaslSpace.xs),
          decoration: BoxDecoration(
            color: dark
                ? const Color(0xCC1B2236)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(WaslRadius.pill),
            border: Border.all(color: context.hairline.withValues(alpha: 0.5)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: WaslFont.small, fontWeight: FontWeight.w700, color: context.textSecondary)),
        ),
      ),
    );
  }
}

class UnreadBadge extends StatelessWidget {
  const UnreadBadge(this.count, {super.key, this.muted = false});
  final int count;

  /// المحادثة المكتومة: شارة رمادية هادئة بدل تدرج الهوية
  final bool muted;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Semantics(
      label: '$count غير مقروءة',
      excludeSemantics: true,
      child: Container(
        // دائرة كاملة للرقم الواحد، وكبسولة لما فوقه
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: WaslSpace.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: muted ? null : WaslColors.gradient,
          color: muted ? context.hairline : null,
          borderRadius: BorderRadius.circular(WaslRadius.pill),
        ),
        child: Text(count > 99 ? '99+' : '$count',
            style: TextStyle(
                color: muted ? context.textPrimary : Colors.white,
                fontSize: WaslFont.small,
                height: 1.2,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// نافذة: اسم + وصف (لإنشاء مجتمع أو قناة)
Future<(String, String)?> askNameAndDescription(
  BuildContext context, {
  required String title,
  required String nameHint,
  bool withDescription = true,
}) {
  final name = TextEditingController();
  final desc = TextEditingController();
  return showDialog<(String, String)>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.surfaceAlt,
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: InputDecoration(hintText: nameHint)),
        if (withDescription) ...[
          const SizedBox(height: WaslSpace.md),
          TextField(
            controller: desc,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(hintText: 'وصف قصير (اختياري)'),
          ),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(ctx, (name.text.trim(), desc.text.trim()));
          },
          child: const Text('إنشاء'),
        ),
      ],
    ),
  );
}

/// شريط بحث + عنوان قسم
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
            WaslSpace.screen, WaslSpace.lg, WaslSpace.screen, WaslSpace.sm),
        child: Semantics(
          header: true,
          child: Text(text,
              style: TextStyle(
                  color: context.textTertiary, fontWeight: FontWeight.w700, fontSize: WaslFont.meta)),
        ),
      );
}

/// صورة شخصية دائرية: الصورة إن وُجدت، وإلا أول حرف من الاسم
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.url,
    this.radius = 26,
    this.color = WaslColors.indigo,
    this.icon,
  });
  final String name;
  final String? url;
  final double radius;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    // استوديو التطبيق (1.13.0): صورة بمربع ناعم بدل الدائرة عند اختيارها
    if (AppStudioService.style.value.avatarShape == StudioAvatarShape.squircle) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius * 0.62),
          image: hasUrl
              ? DecorationImage(
                  image: NetworkImage(url!), fit: BoxFit.cover, onError: (_, _) {})
              : null,
        ),
        child: hasUrl
            ? null
            : icon != null
                ? Icon(icon, color: Colors.white, size: radius)
                : Text(name.isNotEmpty ? name.characters.first : '?',
                    style: TextStyle(color: Colors.white, fontSize: radius * 0.75)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      foregroundImage: hasUrl ? NetworkImage(url!) : null,
      onForegroundImageError: hasUrl ? (_, _) {} : null,
      child: icon != null
          ? Icon(icon, color: Colors.white, size: radius)
          : Text(name.isNotEmpty ? name.characters.first : '?',
              style: TextStyle(color: Colors.white, fontSize: radius * 0.75)),
    );
  }
}

/// شارة التوثيق الرسمية (v0.13.0): علامة تحقق زرقاء بجانب اسم مجتمع أو قناة رسمية.
/// المنح والسحب من الخادم لمسؤولي التطبيق حصراً عبر دوال ترحيل 025 (verify_community /
/// verify_channel) — هنا العرض فقط بلا أي منطق كتابة.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({
    super.key,
    this.size = 16,
    this.tooltip = 'حساب رسمي موثّق من وصل شات',
  });
  final double size;
  final String tooltip;

  /// أزرق التوثيق القياسي — ثابت في الوضعين الفاتح والداكن على كل الخلفيات.
  static const color = Color(0xFF1D9BF0);

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Icon(Icons.verified, size: size, color: color),
      );
}


/// شارة الحساب الرسمي لوصل شات (1.11.0): درع بتدرّج ألوان التطبيق مع علامة
/// تحقق — تميّز حسابات التطبيق نفسه (@waslchat، الدعم، القناة والمجموعة
/// الرسمية) عن التوثيق الأزرق العادي. العرض فقط؛ المنح من الخادم.
class OfficialBadge extends StatelessWidget {
  const OfficialBadge({super.key, this.size = 16});
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'حساب رسمي من وصل شات',
        child: ShaderMask(
          shaderCallback: (r) => WaslColors.gradient.createShader(r),
          child: Icon(Icons.verified_user_rounded, size: size, color: Colors.white),
        ),
      );
}

/// وسم «ما زالت تحت التطوير» (1.11.0) للميزات غير المكتملة
class DevBadge extends StatelessWidget {
  const DevBadge({super.key, this.short = false});
  final bool short;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: WaslSpace.sm, vertical: WaslSpace.xxs),
        decoration: BoxDecoration(
          color: WaslColors.warning.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(WaslRadius.xl),
        ),
        child: Text(short ? 'تحت التطوير' : 'ما زالت تحت التطوير',
            style: const TextStyle(
                fontSize: WaslFont.caption, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
      );
}


/// عينة لون قابلة للنقر (2.5.0 — ج2): هدف لمس 48×48 مهما صغرت الدائرة
/// المرئية، مع وصف لقارئ الشاشة وحالة تحديد وعلامة ✓ بلون مقروء فوق العينة.
class WaslSwatch extends StatelessWidget {
  const WaslSwatch({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
    this.label = 'لون',
    this.size = 30,
    this.ringColor,
    this.idleRingColor = Colors.transparent,
    this.showCheck = false,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String label;

  /// قطر الدائرة المرئية (هدف اللمس ثابت 48)
  final double size;
  final Color? ringColor;
  final Color idleRingColor;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: WaslSize.minTap / 2,
        child: SizedBox.square(
          dimension: WaslSize.minTap,
          child: Center(
            child: AnimatedContainer(
              duration: WaslMotion.fast,
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? (ringColor ?? context.textPrimary) : idleRingColor,
                    width: selected ? 2.5 : 1),
              ),
              child: selected && showCheck
                  ? Icon(Icons.check_rounded,
                      size: size * 0.55, color: WaslContrast.onColor(color))
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// يتخلص من متحكم حقل نصي استُخدم داخل حوار/ورقة بعد انتهاء حركة إغلاقها.
/// التخلص فور عودة `await showDialog` يرمي «A TextEditingController was used
/// after being disposed» لأن الحوار ما زال يُبنى أثناء حركة الخروج (مثلاً حين
/// ينزل لوح المفاتيح فتتغير MediaQuery).
void disposeAfterRouteAnimation(ChangeNotifier c,
    {Duration delay = const Duration(milliseconds: 600)}) {
  Future<void>.delayed(delay, c.dispose);
}
