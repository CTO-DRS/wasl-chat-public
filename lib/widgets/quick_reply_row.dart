import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'motion.dart';

/// صف الردود السريعة فوق المحرر (2.5.0 — إصلاح القص): كان بارتفاع 44
/// بينما الشريحة بهدف لمس 48 فتُقص من الأعلى والأسفل، وأول شريحة ملتصقة
/// بالحافة. الآن: صف أفقي قابل للتمرير بارتفاع يتسع للهدف، وحشوة اتجاهية
/// عند البداية والنهاية، وتباعد موحّد، ونص طويل يُختصر بنقاط.
class QuickReplyRow extends StatelessWidget {
  const QuickReplyRow({
    super.key,
    required this.replies,
    required this.onReply,
    this.onStyle,
  });

  final List<String> replies;
  final ValueChanged<String> onReply;

  /// شريحة «صياغة بأسلوبك» في البداية (اختيارية)
  final VoidCallback? onStyle;

  static const double height = 56;
  static const double maxChipLabelWidth = 220;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (onStyle != null)
        ActionChip(
          key: const ValueKey('quick-style'),
          avatar: const Icon(Icons.edit_note_rounded, size: 16, color: WaslColors.violet),
          label: const Text('صياغة بأسلوبك',
              style: TextStyle(fontSize: WaslFont.meta, fontWeight: FontWeight.w700)),
          backgroundColor: context.glass,
          side: BorderSide(color: WaslColors.violet.withValues(alpha: 0.4)),
          onPressed: onStyle,
        ),
      for (final r in replies)
        MotionScaleIn(
          child: ActionChip(
            avatar: const Icon(Icons.bolt_rounded, size: 15, color: WaslColors.teal),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxChipLabelWidth),
              child: Text(r,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: WaslFont.meta, fontWeight: FontWeight.w600)),
            ),
            tooltip: r,
            backgroundColor: context.glass,
            side: BorderSide(color: context.hairline),
            onPressed: () => onReply(r),
          ),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // حشوة اتجاهية: البداية والنهاية تتبعان اتجاه النص (RTL/LTR)
        padding: const EdgeInsetsDirectional.symmetric(horizontal: WaslSpace.md),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: WaslSpace.sm),
        itemBuilder: (_, i) => Center(child: chips[i]),
      ),
    );
  }
}
