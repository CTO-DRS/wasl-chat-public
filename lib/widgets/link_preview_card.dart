import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/link_preview_service.dart';
import '../theme.dart';

/// بطاقة معاينة الرابط داخل فقاعة النص (المرحلة 8 ب — 0.21.0).
///
/// تظهر تحت النص فقط: العنوان + الوصف + الصورة المصغرة + النطاق —
/// والنقر يفتح الرابط في المتصفح. تختفي بلا بطاقة عند: تعطيل الميزة،
/// فشل الجلب، أو صفحة بلا وسوم — لا عرض مشوّش أبداً.
class LinkPreviewCard extends StatefulWidget {
  const LinkPreviewCard({super.key, required this.text, required this.mine, this.ink});

  /// النص المفكوك للرسالة — نستخرج منه أول رابط
  final String text;
  final bool mine;

  /// حبر فقاعتي المحسوب من تباين لونها (2.5.0) — null = أبيض كالسابق
  final Color? ink;

  @override
  State<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<LinkPreviewCard> {
  LinkPreviewData? _data;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = LinkPreviewService.extractFirstUrl(widget.text);
    if (url == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    final d = await LinkPreviewService.get(url);
    if (!mounted) return;
    setState(() {
      _data = d;
      _failed = d == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // بلا بطاقة: لا رابط، أو الميزة معطلة، أو فشل الجلب، أو ما زالت تجري
    // ولم تصل بعد (تظهر عند جهوزها بلا أي مساحة فارغة تنتظر)
    if (_failed || _data == null) return const SizedBox.shrink();
    final d = _data!;
    final mineInk = widget.ink ?? Colors.white;
    final onColor = widget.mine ? mineInk : context.textPrimary;
    final subColor =
        widget.mine ? mineInk.withValues(alpha: 0.78) : context.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: WaslSpace.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(WaslRadius.md),
        onTap: () => launchUrl(Uri.parse(d.url), mode: LaunchMode.externalApplication),
        child: Container(
          padding: const EdgeInsets.all(WaslSpace.md),
          decoration: BoxDecoration(
            color: widget.mine
                ? Colors.black.withValues(alpha: 0.18)
                : Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(WaslRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (d.image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LayoutBuilder(
                    builder: (context, c) => Image.network(
                      d.image!,
                      width: c.maxWidth,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              if (d.title != null) ...[
                const SizedBox(height: WaslSpace.sm),
                Row(children: [
                  Flexible(
                    child: Text(
                      d.title!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onColor,
                        fontWeight: FontWeight.w700,
                        fontSize: WaslFont.body,
                        height: 1.3,
                      ),
                    ),
                  ),
                ]),
              ],
              if ((d.description ?? '').isNotEmpty) ...[
                const SizedBox(height: WaslSpace.xs),
                Text(
                  d.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subColor, fontSize: WaslFont.small, height: 1.3),
                ),
              ],
              const SizedBox(height: WaslSpace.xs),
              Row(children: [
                Icon(Icons.link_rounded, size: 12, color: subColor),
                const SizedBox(width: WaslSpace.xs),
                Flexible(
                  child: Text(
                    d.host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: subColor, fontSize: WaslFont.caption),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
