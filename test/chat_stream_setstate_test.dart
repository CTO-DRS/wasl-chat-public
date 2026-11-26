// إصلاح شاشة الخطأ الحمراء عند فتح أي محادثة:
// «setState() or markNeedsBuild() called during build ... ChatScreen ...
// StreamBuilder<List<Map<String, dynamic>>>». كان builder الستريم يستدعي
// _refreshSmartReplies/_scanPromises اللتين تستدعيان setState على الشاشة.
// الاشتقاق صار يمر عبر PostBuildCoalescer فيُطبق بعد الإطار.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasl_chat/services/post_build_coalescer.dart';

/// نسخة مصغّرة من تدفق ChatScreen: هيكل ← رسائل، والحالة المشتقة
/// (ردود ذكية) تُكتب على الشاشة الأب
class _ChatLike extends StatefulWidget {
  const _ChatLike({required this.stream, required this.deferred});
  final Stream<List<Map<String, dynamic>>> stream;
  final bool deferred;
  @override
  State<_ChatLike> createState() => _ChatLikeState();
}

class _ChatLikeState extends State<_ChatLike> {
  List<String> replies = const [];
  String? repliesFor;
  int derivations = 0;

  late final PostBuildCoalescer<List<Map<String, dynamic>>> _derived =
      PostBuildCoalescer((all) {
    if (mounted) _refresh(all);
  });

  void _refresh(List<Map<String, dynamic>> all) {
    derivations++;
    if (all.isEmpty) return;
    final id = all.first['id'] as String;
    if (repliesFor == id) return;
    repliesFor = id;
    setState(() => replies = ['تمام', 'شكراً']);
  }

  @override
  void dispose() {
    _derived.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(children: [
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.stream,
            builder: (context, snap) {
              if (!snap.hasData) return const Text('skeleton');
              final all = snap.data!;
              if (widget.deferred) {
                _derived.schedule(all);
              } else {
                _refresh(all); // السلوك القديم المعطوب
              }
              return ListView(children: [
                for (final m in all) Text(m['content'] as String),
              ]);
            },
          ),
        ),
        Text('replies:${replies.length}'),
      ]),
    );
  }
}

void main() {
  testWidgets('الاشتقاق المؤجل: لا FlutterError عند الانتقال من الهيكل للرسائل',
      (tester) async {
    final ctrl = StreamController<List<Map<String, dynamic>>>();
    addTearDown(ctrl.close);
    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = old);

    await tester.pumpWidget(_ChatLike(stream: ctrl.stream, deferred: true));
    expect(find.text('skeleton'), findsOneWidget);

    ctrl.add([
      {'id': 'm2', 'content': 'كيفك؟'},
      {'id': 'm1', 'content': 'مرحبا'},
    ]);
    await tester.pump(); // بناء الرسائل + جدولة الاشتقاق
    await tester.pump(); // تطبيق setState بعد الإطار
    // تحديث ثانٍ ثم ثالث سريعان — يُدمجان ولا يرميان
    ctrl.add([
      {'id': 'm3', 'content': 'وينك'},
      {'id': 'm2', 'content': 'كيفك؟'},
    ]);
    await tester.pump();
    await tester.pump();

    FlutterError.onError = old;
    expect(errors, isEmpty, reason: errors.map((e) => e.exceptionAsString()).join('\n'));
    expect(tester.takeException(), isNull);
    expect(find.text('replies:2'), findsOneWidget);
    expect(find.text('وينك'), findsOneWidget);
  });

  testWidgets('شاهد ضبط: setState داخل builder الستريم يرمي (السبب الجذري)',
      (tester) async {
    final ctrl = StreamController<List<Map<String, dynamic>>>();
    addTearDown(ctrl.close);
    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = errors.add;

    await tester.pumpWidget(_ChatLike(stream: ctrl.stream, deferred: false));
    ctrl.add([
      {'id': 'm1', 'content': 'مرحبا'},
    ]);
    await tester.pump();
    await tester.pump();
    FlutterError.onError = old;
    expect(
        errors.any((e) => e.exceptionAsString().contains('during build')), isTrue);
  });

  testWidgets('PostBuildCoalescer يدمج طلبات الإطار ويتوقف بعد dispose',
      (tester) async {
    final seen = <int>[];
    final c = PostBuildCoalescer<int>(seen.add);
    await tester.pumpWidget(const SizedBox());
    c.schedule(1);
    c.schedule(2);
    c.schedule(3);
    expect(c.isScheduled, isTrue);
    await tester.pump();
    expect(seen, [3]);
    c.schedule(4);
    c.dispose();
    await tester.pump();
    expect(seen, [3]);
  });
}
