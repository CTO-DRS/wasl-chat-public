/// تخطيط الفقاعة وإيماءاتها (2.5.0 — الجولة الثانية):
///
/// - [BubbleFooterLayout]: الوقت وعلامات القراءة في الحافة السفلية «الختامية»
///   للفقاعة (يسار في العربية، يمين في الإنجليزية) أياً كان عرض النص فوقها —
///   بلا IntrinsicWidth (التي تنهار مع LayoutBuilder داخل معاينة الروابط).
/// - [SwipeToReply]: سحب الفقاعة أفقياً نحو داخل الشاشة يرد عليها، بلمسة
///   اهتزاز عند تجاوز العتبة وأيقونة رد تظهر تدريجياً — بلا حزم إضافية.
/// - [JumpToBottomButton]: زر «إلى الأحدث» مع عدد الرسائل الجديدة.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';

// ---------------------------------------------------------------------------
// BubbleFooterLayout + BubbleInlineAnchor
// ---------------------------------------------------------------------------

/// يضع [content] في البداية و[footer] (الوقت + «معدّلة» + علامات القراءة)
/// في الحافة الختامية — بأسلوب واتساب/تيليجرام:
///
/// - إن كان آخر عنصر في [content] نصاً ملفوفاً بـ[BubbleInlineAnchor]، وفي
///   سطره الأخير متسع للتذييل (ضمن أقصى عرض للفقاعة)، يجلس التذييل على السطر
///   نفسه في طرفه الختامي، وقد تتسع الفقاعة قليلاً لتستوعبه.
/// - وإلا (سطر أخير طويل، معاينة رابط، ترجمة، تفاعلات، وسائط، صوت…) ينزل
///   التذييل إلى سطر مستقل عند الحافة السفلية الختامية.
///
/// القياس من [RenderParagraph] الفعلي بعد تخطيطه (صناديق السطر الأخير عبر
/// getBoxesForSelection)، فيحترم مقياس النص والخطوط والاتجاه ثنائي اللغة
/// والإيموجي — بلا IntrinsicWidth (التي تنهار مع LayoutBuilder داخل معاينة
/// الروابط). عرض الكل = الأعرض المطلوب، فلا تتمدد الفقاعة لأقصى عرض.
class BubbleFooterLayout extends MultiChildRenderObjectWidget {
  BubbleFooterLayout({
    super.key,
    required Widget content,
    required Widget footer,
  }) : super(children: [content, footer]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderBubbleFooter(textDirection: Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    RenderBubbleFooter renderObject,
  ) {
    renderObject.textDirection = Directionality.of(context);
  }
}

/// يعلّم نص الرسالة الذي يُسمح للتذييل بمشاركة سطره الأخير. يلفّ [Text]
/// (أو أي ودجت ينتهي بـ[RenderParagraph] واحد). بلا [BubbleFooterLayout]
/// سلف: لا أثر له إطلاقاً.
class BubbleInlineAnchor extends SingleChildRenderObjectWidget {
  const BubbleInlineAnchor({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderBubbleInlineAnchor();
}

class RenderBubbleInlineAnchor extends RenderProxyBox {
  RenderBubbleFooter? _host;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    // أقرب تخطيط فقاعة سلف هو المضيف
    RenderObject? p = parent;
    while (p != null && p is! RenderBubbleFooter) {
      p = p.parent;
    }
    _host = p as RenderBubbleFooter?;
    // الإدراج نفسه يعيد تخطيط السلسلة حتى المضيف (adoptChild)
    _host?._anchor = this;
  }

  @override
  void detach() {
    if (_host?._anchor == this) {
      _host!._anchor = null;
    }
    _host = null;
    super.detach();
  }

  /// أول [RenderParagraph] عبر سلسلة الأبناء المفردة (Text قد يلفّ
  /// RichText بـSemantics أو حاوية تحديد)
  RenderParagraph? get paragraph {
    RenderObject? r = child;
    while (r != null) {
      if (r is RenderParagraph) return r;
      if (r is RenderObjectWithChildMixin<RenderObject>) {
        r = r.child;
      } else {
        return null;
      }
    }
    return null;
  }

  /// امتداد السطر الأخير وارتفاع هذا العنصر — يُحسبان في تخطيطه هو (حيث
  /// يحق له قراءة حجم ابنه)، ويقرؤهما المضيف بعد تخطيط المحتوى
  ({double left, double right, double top})? _lastLine;
  double _height = 0;

  @override
  void performLayout() {
    super.performLayout();
    _height = size.height;
    _lastLine = _measureLastLine();
  }

  ({double left, double right, double top})? _measureLastLine() {
    final para = paragraph;
    if (para == null) return null;
    final len = para.text.toPlainText(includeSemanticsLabels: false).length;
    if (len == 0) return null;
    final boxes = para.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: len),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );
    if (boxes.isEmpty) return null;
    // السطر الأخير = الصناديق ذات أكبر قمة (BoxHeightStyle.max يوحّد
    // قمم صناديق السطر الواحد مهما اختلطت الاتجاهات والإيموجي)
    var lastTop = boxes.first.top;
    for (final b in boxes) {
      if (b.top > lastTop) lastTop = b.top;
    }
    var l = double.infinity, r = double.negativeInfinity;
    for (final b in boxes) {
      if (b.bottom > lastTop + 0.5) {
        l = math.min(l, b.left);
        r = math.max(r, b.right);
      }
    }
    if (!l.isFinite || !r.isFinite) return null;
    // مسافة ختامية «معلّقة» قد تتجاوز عرض الفقرة — تُقصّ إلى حدودها
    final w = para.textSize.width;
    l = l.clamp(0.0, w);
    r = r.clamp(0.0, w);
    // من إحداثيات الفقرة إلى إحداثيات هذا العنصر
    final o = MatrixUtils.transformPoint(
      para.getTransformTo(this),
      Offset.zero,
    );
    return (left: l + o.dx, right: r + o.dx, top: lastTop + o.dy);
  }
}

class _FooterParentData extends ContainerBoxParentData<RenderBox> {}

class RenderBubbleFooter extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FooterParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FooterParentData> {
  RenderBubbleFooter({required TextDirection textDirection})
    : _textDirection = textDirection;

  TextDirection _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsLayout();
  }

  RenderBubbleInlineAnchor? _anchor;

  /// هل جلس التذييل على السطر الأخير في آخر تخطيط (للاختبارات والتشخيص)
  bool get isInline => _inline;
  bool _inline = false;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FooterParentData) {
      child.parentData = _FooterParentData();
    }
  }

  RenderBox get _content => firstChild!;
  RenderBox get _footer => lastChild!;

  // القيم الجوهرية والتخطيط الجاف محافِظة (التذييل في سطر مستقل): لا يمكن
  // قياس السطر الأخير قبل تخطيط النص فعلاً. الحجم الفعلي ≤ هذا دائماً.
  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _content.getMinIntrinsicWidth(double.infinity),
    _footer.getMinIntrinsicWidth(double.infinity),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => math.max(
    _content.getMaxIntrinsicWidth(double.infinity),
    _footer.getMaxIntrinsicWidth(double.infinity),
  );

  @override
  double computeMinIntrinsicHeight(double width) =>
      _content.getMinIntrinsicHeight(width) +
      _footer.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _content.getMaxIntrinsicHeight(width) +
      _footer.getMaxIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final loose = constraints.loosen();
    final c = _content.getDryLayout(loose);
    final f = _footer.getDryLayout(loose);
    return constraints.constrain(
      Size(math.max(c.width, f.width), c.height + f.height),
    );
  }

  /// المرساة صالحة إن كانت داخل محتوى هذا التخطيط، وحافتها السفلية هي
  /// حافة المحتوى السفلية (أي النص آخر ما في الفقاعة)
  ({double left, double right, double top})? _lastLineInContent() {
    final a = _anchor;
    if (a == null || !a.attached) return null;
    RenderObject? p = a.parent;
    while (p != null && p != _content) {
      if (p is RenderBubbleFooter) return null; // مرساة فقاعة متداخلة
      p = p.parent;
    }
    if (p == null) return null;
    final o = MatrixUtils.transformPoint(
      a.getTransformTo(_content),
      Offset.zero,
    );
    if ((o.dy + a._height - _content.size.height).abs() > 1.0) return null;
    final line = a._lastLine;
    if (line == null) return null;
    return (
      left: line.left + o.dx,
      right: line.right + o.dx,
      top: line.top + o.dy,
    );
  }

  @override
  void performLayout() {
    final loose = constraints.loosen();
    _content.layout(loose, parentUsesSize: true);
    _footer.layout(loose, parentUsesSize: true);
    final cs = _content.size, fs = _footer.size;
    final rtl = _textDirection == TextDirection.rtl;
    final maxW = constraints.maxWidth;

    // عرض الفقاعة المطلوب كي يجلس التذييل على السطر الأخير
    double? inlineW;
    final line = _lastLineInContent();
    if (line != null) {
      // المحتوى ملاصق لحافة البداية؛ ما يشغله السطر الأخير من جهة النهاية
      final occupied = rtl ? cs.width - line.left : line.right;
      final need = occupied + fs.width;
      final w = math.max(cs.width, need);
      if (w <= maxW + 0.01) inlineW = w;
    }
    _inline = inlineW != null;

    final w = math.max(inlineW ?? math.max(cs.width, fs.width), 0.0);
    final h = _inline ? math.max(cs.height, fs.height) : cs.height + fs.height;
    size = constraints.constrain(Size(w, h));
    // المحتوى في البداية، والتذييل في النهاية وعلى الحافة السفلية
    (_content.parentData! as _FooterParentData).offset = Offset(
      rtl ? size.width - cs.width : 0,
      0,
    );
    (_footer.parentData! as _FooterParentData).offset = Offset(
      rtl ? 0 : size.width - fs.width,
      size.height - fs.height,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

// ---------------------------------------------------------------------------
// SwipeToReply
// ---------------------------------------------------------------------------

/// سحب أفقي نحو داخل الشاشة (من حافة البداية) يطلق [onReply].
/// الاتجاه يتبع لغة الواجهة: في العربية السحب نحو اليسار، وفي الإنجليزية
/// نحو اليمين — كواتساب وتيليجرام. السحب العمودي يبقى للقائمة.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
    this.iconColor,
  });

  final Widget child;
  final VoidCallback onReply;
  final bool enabled;
  final Color? iconColor;

  /// المسافة التي تُطلق الرد
  static const double threshold = 64;

  /// أقصى إزاحة مرئية (مقاومة مطاطية بعدها)
  static const double maxDrag = 96;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  double _dx = 0; // دائماً ≥ 0: المسافة نحو داخل الشاشة
  bool _armed = false;
  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: WaslMotion.base,
  )..addListener(() => setState(() => _dx = _from * (1 - _back.value)));
  double _from = 0;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  void _update(DragUpdateDetails d) {
    if (_back.isAnimating) _back.stop();
    // في RTL «نحو الداخل» = سالب على المحور الأفقي
    final delta = _rtl ? -d.delta.dx : d.delta.dx;
    final next = (_dx + delta).clamp(0.0, SwipeToReply.maxDrag);
    final armed = next >= SwipeToReply.threshold;
    if (armed && !_armed) HapticFeedback.selectionClick();
    setState(() {
      _dx = next;
      _armed = armed;
    });
  }

  void _end([DragEndDetails? _]) {
    if (_armed) widget.onReply();
    _armed = false;
    _from = _dx;
    if (_from == 0) return;
    if (WaslReducedMotion.of(context)) {
      setState(() => _dx = 0);
      return;
    }
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final progress = (_dx / SwipeToReply.threshold).clamp(0.0, 1.0);
    final sign = _rtl ? -1.0 : 1.0;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: _end,
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        clipBehavior: Clip.none,
        children: [
          if (_dx > 0)
            PositionedDirectional(
              start: math.max(0, _dx - 40),
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.6 + 0.4 * progress,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.glass,
                    ),
                    child: Icon(Icons.reply_rounded,
                        size: 18,
                        color: widget.iconColor ?? context.accentText),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(sign * _dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// احترام «تقليل الحركة» في النظام
abstract final class WaslReducedMotion {
  static bool of(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

// ---------------------------------------------------------------------------
// JumpToBottomButton
// ---------------------------------------------------------------------------

/// زر دائري صغير «إلى أحدث الرسائل» يظهر حين يبتعد المستخدم عن الأسفل،
/// مع شارة بعدد الرسائل التي وصلت أثناء ذلك.
class JumpToBottomButton extends StatelessWidget {
  const JumpToBottomButton({
    super.key,
    required this.visible,
    required this.unread,
    required this.onPressed,
  });

  final bool visible;
  final int unread;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final reduce = WaslReducedMotion.of(context);
    final label = unread > 0
        ? 'الانتقال إلى أحدث الرسائل — $unread جديدة'
        : 'الانتقال إلى أحدث الرسائل';
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedScale(
        scale: visible ? 1 : 0.6,
        duration: reduce ? Duration.zero : WaslMotion.fast,
        curve: WaslMotion.emphasized,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: reduce ? Duration.zero : WaslMotion.fast,
          child: Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            child: Stack(clipBehavior: Clip.none, children: [
              Material(
                color: context.surfaceAlt,
                shape: CircleBorder(side: BorderSide(color: context.hairline)),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                  child: SizedBox(
                    width: WaslSize.minTap,
                    height: WaslSize.minTap,
                    child: Icon(Icons.keyboard_double_arrow_down_rounded,
                        color: context.iconStd),
                  ),
                ),
              ),
              if (unread > 0)
                PositionedDirectional(
                  top: -WaslSpace.xs,
                  end: -WaslSpace.xs,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    padding: const EdgeInsets.symmetric(horizontal: WaslSpace.xs),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: WaslColors.gradient,
                      borderRadius: BorderRadius.circular(WaslRadius.pill),
                    ),
                    child: Text(unread > 99 ? '99+' : '$unread',
                        style: TextStyle(
                            color: context.onAccent,
                            fontSize: WaslFont.caption,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
