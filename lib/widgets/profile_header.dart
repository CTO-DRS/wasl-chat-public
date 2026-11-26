import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'bubble_layout.dart' show WaslReducedMotion;
import 'common.dart';

/// مكوّنات رأس الملف الشخصي (2.5.0 — ج6): مشتركة بين ملفي (ProfileScreen)
/// وملف الطرف الآخر (ContactScreen). عرض فقط — المنطق في الشاشات.

const double kProfileCoverHeight = 200;
const double kProfileAvatarRadius = 52;

/// كم يتداخل الأفاتار مع الخلفية (أقل من نصف القطر حتى يبقى معظم الأفاتار
/// داخل حدود الصندوق القابل للمس)
const double kProfileAvatarOverlap = 40;

/// شريط علوي قابل للطي بصورة الخلفية: تمدد عند السحب، تزيح (parallax)،
/// وتغبيش يزداد مع الطي — كله يتوقف عند «تقليل الحركة».
class ProfileCoverAppBar extends StatelessWidget {
  const ProfileCoverAppBar({
    super.key,
    required this.title,
    this.coverUrl,
    this.onCoverTap,
    this.actions = const [],
    this.coverSemantics = 'صورة الخلفية',
  });

  final String title;
  final String? coverUrl;
  final VoidCallback? onCoverTap;
  final List<Widget> actions;
  final String coverSemantics;

  @override
  Widget build(BuildContext context) {
    final reduce = WaslReducedMotion.of(context);
    final topPad = MediaQuery.paddingOf(context).top;
    return SliverAppBar(
      pinned: true,
      stretch: !reduce,
      expandedHeight: kProfileCoverHeight,
      actions: actions,
      flexibleSpace: LayoutBuilder(builder: (context, c) {
        final minH = kToolbarHeight + topPad;
        final maxH = kProfileCoverHeight + topPad;
        final t = ((c.maxHeight - minH) / (maxH - minH)).clamp(0.0, 1.0);
        final collapsed = 1 - t;
        return FlexibleSpaceBar(
          collapseMode: reduce ? CollapseMode.pin : CollapseMode.parallax,
          stretchModes: reduce
              ? const <StretchMode>[]
              : const [StretchMode.zoomBackground, StretchMode.fadeTitle],
          centerTitle: true,
          title: Opacity(
            opacity: collapsed > 0.75 ? ((collapsed - 0.75) * 4).clamp(0.0, 1.0) : 0,
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: WaslFont.title,
                    fontWeight: FontWeight.w800,
                    color: context.appBarText)),
          ),
          background: Semantics(
            button: onCoverTap != null,
            label: coverSemantics,
            child: GestureDetector(
              onTap: onCoverTap,
              child: Stack(fit: StackFit.expand, children: [
                ProfileCoverImage(url: coverUrl),
                if (!reduce && collapsed > 0.05)
                  BackdropFilter(
                    filter: ui.ImageFilter.blur(
                        sigmaX: collapsed * 10, sigmaY: collapsed * 10),
                    child: const SizedBox.expand(),
                  ),
                // تظليل سفلي حتى تقرأ أزرار الشريط فوق أي صورة
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Color(0x00000000), Color(0x33000000)],
                      stops: [0, 0.45, 1],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

/// صورة الخلفية أو تدرج الهوية حين لا توجد/تفشل
class ProfileCoverImage extends StatelessWidget {
  const ProfileCoverImage({super.key, this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
        decoration: BoxDecoration(gradient: WaslColors.gradient));
    final u = url;
    if (u == null || u.isEmpty) return fallback;
    return Image.network(u,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, _, _) => fallback,
        frameBuilder: (context, child, frame, sync) {
          if (sync || frame != null) return child;
          return fallback;
        });
  }
}

/// الأفاتار المتداخل مع الخلفية + شارة تعديل اختيارية (هدف لمس 48)
class ProfileAvatarBadge extends StatelessWidget {
  const ProfileAvatarBadge({
    super.key,
    required this.name,
    this.url,
    this.onTap,
    this.onEdit,
    this.busy = false,
    this.online = false,
  });

  final String name;
  final String? url;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final bool busy;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      width: kProfileAvatarRadius * 2 + 8,
      height: kProfileAvatarRadius * 2 + 8,
      child: Stack(clipBehavior: Clip.none, children: [
        Semantics(
          button: onTap != null,
          label: 'الصورة الشخصية لـ $name',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: UserAvatar(name: name, url: url, radius: kProfileAvatarRadius),
            ),
          ),
        ),
        if (online)
          PositionedDirectional(
            bottom: 10,
            start: 10,
            child: Semantics(
              label: 'متصل الآن',
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: WaslColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: bg, width: 3),
                ),
              ),
            ),
          ),
        if (onEdit != null)
          PositionedDirectional(
            bottom: -4,
            end: -4,
            child: Material(
              color: WaslColors.teal,
              shape: CircleBorder(side: BorderSide(color: bg, width: 3)),
              child: IconButton(
                tooltip: 'تغيير الصورة الشخصية',
                constraints: const BoxConstraints(
                    minWidth: WaslSize.minTap, minHeight: WaslSize.minTap),
                style: IconButton.styleFrom(
                    minimumSize: const Size(WaslSize.minTap, WaslSize.minTap)),
                onPressed: busy ? null : onEdit,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
      ]),
    );
  }
}

/// الاسم + شارة التوثيق، و@الاسم مع زر نسخ
class ProfileIdentity extends StatelessWidget {
  const ProfileIdentity({
    super.key,
    required this.name,
    required this.username,
    this.verified = false,
    this.official = false,
    this.onCopyUsername,
    this.onEditUsername,
  });

  final String name;
  final String username;
  final bool verified;
  final bool official;
  final VoidCallback? onCopyUsername;
  final VoidCallback? onEditUsername;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Flexible(
          child: Text(name,
              key: const ValueKey('profile-name'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: WaslFont.display, fontWeight: FontWeight.w800)),
        ),
        if (official) ...[
          const SizedBox(width: WaslSpace.sm),
          const OfficialBadge(size: 24),
        ] else if (verified) ...[
          const SizedBox(width: WaslSpace.sm),
          const VerifiedBadge(size: 22),
        ],
      ]),
      if (username.isNotEmpty)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(
            child: Semantics(
              button: onEditUsername != null,
              label: 'اسم المستخدم @$username',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(WaslRadius.sm),
                onTap: onEditUsername,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: WaslSize.minTap),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: WaslSpace.sm),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                        child: Text('@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                                color: context.textTertiary, fontSize: WaslFont.body)),
                      ),
                      if (onEditUsername != null) ...[
                        const SizedBox(width: WaslSpace.xs),
                        Icon(Icons.edit_outlined, size: 14, color: context.textFaint),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ),
          if (onCopyUsername != null)
            IconButton(
              tooltip: 'نسخ اسم المستخدم',
              iconSize: 18,
              constraints: const BoxConstraints(
                  minWidth: WaslSize.minTap, minHeight: WaslSize.minTap),
              style: IconButton.styleFrom(
                  minimumSize: const Size(WaslSize.minTap, WaslSize.minTap)),
              color: context.textTertiary,
              onPressed: onCopyUsername,
              icon: const Icon(Icons.copy_rounded),
            ),
        ]),
    ]);
  }
}

/// سطر الحالة: متصل الآن (من الحضور الفعلي) وتاريخ الانضمام إن وُجد
class ProfileStatusLine extends StatelessWidget {
  const ProfileStatusLine({super.key, this.online = false, this.joinedAt});
  final bool online;
  final DateTime? joinedAt;

  static const _months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  static String joinedLabel(DateTime d) => 'انضم في ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    if (online) {
      parts.add(Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                const BoxDecoration(color: WaslColors.success, shape: BoxShape.circle)),
        const SizedBox(width: WaslSpace.xs),
        Text('متصل الآن',
            style: TextStyle(color: context.accentText, fontSize: WaslFont.meta)),
      ]));
    }
    final j = joinedAt;
    if (j != null) {
      parts.add(Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.calendar_month_outlined, size: 14, color: context.textFaint),
        const SizedBox(width: WaslSpace.xs),
        Text(joinedLabel(j.toLocal()),
            style: TextStyle(color: context.textTertiary, fontSize: WaslFont.meta)),
      ]));
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: WaslSpace.xs),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: WaslSpace.lg,
        runSpacing: WaslSpace.xs,
        children: parts,
      ),
    );
  }
}

/// نبذة بثلاثة أسطر وزر «المزيد/أقل» حين تفيض فقط
class ExpandableBio extends StatefulWidget {
  const ExpandableBio({super.key, required this.text, this.maxLines = 3});
  final String text;
  final int maxLines;

  @override
  State<ExpandableBio> createState() => _ExpandableBioState();
}

class _ExpandableBioState extends State<ExpandableBio> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        color: context.textSecondary, fontSize: WaslFont.bodyLarge, height: 1.5);
    return LayoutBuilder(builder: (context, c) {
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: widget.maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: c.maxWidth);
      final overflows = tp.didExceedMaxLines;
      tp.dispose();
      final duration =
          WaslReducedMotion.of(context) ? Duration.zero : WaslMotion.base;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AnimatedSize(
          duration: duration,
          curve: WaslMotion.emphasized,
          alignment: AlignmentDirectional.topStart,
          child: Text(widget.text,
              key: const ValueKey('profile-bio'),
              textAlign: TextAlign.center,
              maxLines: _expanded ? null : widget.maxLines,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: style),
        ),
        if (overflows)
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                  minimumSize: const Size(WaslSize.minTap, WaslSize.minTap)),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'أقل' : 'المزيد'),
            ),
          ),
      ]);
    });
  }
}

/// زر إجراء سريع: أيقونة في دائرة زجاجية وتسمية — هدف لمس ≥48
class ProfileAction {
  const ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.semanticsLabel,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? semanticsLabel;
}

/// صف الإجراءات السريعة — تتوزع بالتساوي وتلتف التسميات الطويلة بسطرين
class ProfileQuickActions extends StatelessWidget {
  const ProfileQuickActions({super.key, required this.actions});
  final List<ProfileAction> actions;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final a in actions)
        Expanded(
          child: Semantics(
            button: true,
            enabled: a.onTap != null,
            label: a.semanticsLabel ?? a.label,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(WaslRadius.lg),
              onTap: a.onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: WaslSpace.sm),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: WaslSize.minTap,
                      height: WaslSize.minTap,
                      decoration: BoxDecoration(
                        color: context.glass,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.hairline),
                      ),
                      child: Icon(a.icon, color: context.accentText, size: 22),
                    ),
                    const SizedBox(height: WaslSpace.xs),
                    Text(a.label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: WaslFont.small,
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary)),
                  ]),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// بطاقة قسم بعنوان صغير
class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(WaslSpace.lg, WaslSpace.md, WaslSpace.lg, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
                start: WaslSpace.sm, bottom: WaslSpace.sm),
            child: Text(title!,
                style: TextStyle(
                    fontSize: WaslFont.meta,
                    fontWeight: FontWeight.w700,
                    color: context.textTertiary)),
          ),
        Container(
          decoration: BoxDecoration(
            color: context.glass,
            borderRadius: BorderRadius.circular(WaslRadius.lg),
            border: Border.all(color: context.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ]),
    );
  }
}

/// عارض صورة ملء الشاشة بتكبير وتحريك (بلا Hero لتفادي تكرار الوسوم)
Future<void> showProfileImageViewer(BuildContext context,
    {required String url, required String title}) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black,
    transitionDuration:
        WaslReducedMotion.of(context) ? Duration.zero : WaslMotion.base,
    pageBuilder: (ctx, _, _) => ProfileImageViewer(url: url, title: title),
    transitionsBuilder: (ctx, a, _, child) => FadeTransition(opacity: a, child: child),
  ));
}

class ProfileImageViewer extends StatelessWidget {
  const ProfileImageViewer({super.key, required this.url, required this.title});
  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Semantics(
              image: true,
              label: title,
              child: Image.network(url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined,
                      color: Colors.white54, size: 64)),
            ),
          ),
        ),
      ),
    );
  }
}

/// ورقة «عرض / تغيير / إزالة» لصورة الملف أو الخلفية. تعيد الاختيار.
enum ProfileImageChoice { view, change, remove }

Future<ProfileImageChoice?> showProfileImageSheet(
  BuildContext context, {
  required String title,
  required bool hasImage,
  bool canEdit = true,
}) {
  return showModalBottomSheet<ProfileImageChoice>(
    context: context,
    backgroundColor: context.surfaceAlt,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(WaslRadius.xl))),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        if (hasImage)
          ListTile(
            leading: const Icon(Icons.fullscreen_rounded),
            title: const Text('عرض'),
            onTap: () => Navigator.pop(ctx, ProfileImageChoice.view),
          ),
        if (canEdit)
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(hasImage ? 'تغيير' : 'اختيار صورة'),
            onTap: () => Navigator.pop(ctx, ProfileImageChoice.change),
          ),
        if (canEdit && hasImage)
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: WaslColors.danger),
            title: const Text('إزالة', style: TextStyle(color: WaslColors.danger)),
            onTap: () => Navigator.pop(ctx, ProfileImageChoice.remove),
          ),
        const SizedBox(height: WaslSpace.sm),
      ]),
    ),
  );
}

/// نتيجة ورقة تعديل الاسم والنبذة
class ProfileEditResult {
  const ProfileEditResult(this.name, this.bio);
  final String name;
  final String bio;
}

/// ورقة تعديل الاسم والنبذة: تحقق فوري وعدّاد حي، وحفظ عبر [onSave]
/// (يعيد رسالة خطأ أو null عند النجاح). تملك متحكماتها وتتخلص منها بنفسها.
class ProfileEditSheet extends StatefulWidget {
  const ProfileEditSheet({
    super.key,
    required this.initialName,
    required this.initialBio,
    required this.onSave,
  });

  final String initialName;
  final String initialBio;
  final Future<String?> Function(ProfileEditResult r) onSave;

  static const nameMax = 40;
  static const bioMax = 140;

  /// قواعد قيود الجدول (011): الاسم 1..40 والنبذة ≤140
  static String? validateName(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'اكتب اسمك';
    if (t.characters.length > nameMax) return 'الاسم أطول من $nameMax حرفاً';
    return null;
  }

  static String? validateBio(String v) {
    if (v.trim().characters.length > bioMax) return 'النبذة أطول من $bioMax حرفاً';
    return null;
  }

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _bio = TextEditingController(text: widget.initialBio);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nameErr = ProfileEditSheet.validateName(_name.text);
    final bioErr = ProfileEditSheet.validateBio(_bio.text);
    if (nameErr != null || bioErr != null) {
      setState(() => _error = nameErr ?? bioErr);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final r = ProfileEditResult(_name.text.trim(), _bio.text.trim());
    final err = await widget.onSave(r);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, r);
    } else {
      setState(() {
        _saving = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameErr = ProfileEditSheet.validateName(_name.text);
    final bioErr = ProfileEditSheet.validateBio(_bio.text);
    final changed = _name.text.trim() != widget.initialName.trim() ||
        _bio.text.trim() != widget.initialBio.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              WaslSpace.xl, WaslSpace.lg, WaslSpace.xl, WaslSpace.lg),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('تعديل الملف',
                    style: TextStyle(
                        fontSize: WaslFont.titleLarge, fontWeight: FontWeight.w800)),
                const SizedBox(height: WaslSpace.lg),
                TextField(
                  key: const ValueKey('edit-name'),
                  controller: _name,
                  autofocus: true,
                  maxLength: ProfileEditSheet.nameMax,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'الاسم الظاهر',
                    errorText: _name.text.isEmpty ? null : nameErr,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: WaslSpace.sm),
                TextField(
                  key: const ValueKey('edit-bio'),
                  controller: _bio,
                  maxLength: ProfileEditSheet.bioMax,
                  maxLines: 4,
                  minLines: 2,
                  decoration: InputDecoration(
                    labelText: 'نبذة عنك',
                    hintText: 'جملة قصيرة يراها من يزور ملفك',
                    errorText: bioErr,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: WaslSpace.xs),
                Text('صورتك واسمك ونبذتك يراها أي مستخدم في وصل.',
                    style: TextStyle(color: context.textFaint, fontSize: WaslFont.small)),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: WaslSpace.sm),
                    child: Text(_error!,
                        key: const ValueKey('edit-error'),
                        style: const TextStyle(
                            color: WaslColors.danger, fontSize: WaslFont.meta)),
                  ),
                const SizedBox(height: WaslSpace.lg),
                SizedBox(
                  height: WaslSize.minTap,
                  child: FilledButton(
                    key: const ValueKey('edit-save'),
                    onPressed: _saving || !changed || nameErr != null || bioErr != null
                        ? null
                        : _submit,
                    child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
                  ),
                ),
              ]),
        ),
      ),
    );
  }
}

/// عنصر قائمة داخل [ProfileSection] بهدف لمس مريح
class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.color,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 56,
      leading: Icon(icon, color: color ?? context.accentText),
      title: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: trailing ??
          (onTap == null
              ? null
              : Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: context.textFaint)),
      onTap: onTap,
    );
  }
}
