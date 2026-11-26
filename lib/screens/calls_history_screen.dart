import 'dart:async';

/// شاشة سجل المكالمات (المرحلة 6 — 0.17.0) — تبويب «المكالمات» الرئيسي.
///
/// سجل صادق: صادرة/واردة/فائتة/مرفوضة/ملغاة/فشلت، والمدة للمكتملة منها،
/// والطرفان وحدهما يقرآن هذا السجل عبر RLS (028_calls.sql) ويُنظَّف
/// من الخادم بعد 90 يوماً. الضغط على أي سطر يعيد الاتصال بنفس الشخص
/// وبنوع المكالمة نفسه.
import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../services/call_logic.dart';
import '../services/realtime_hub_service.dart';
import '../services/call_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'call_screen.dart';

class CallsHistoryScreen extends StatefulWidget {
  const CallsHistoryScreen({super.key});

  @override
  State<CallsHistoryScreen> createState() => _CallsHistoryScreenState();
}

class _CallsHistoryScreenState extends State<CallsHistoryScreen> {
  bool _loading = true;
  List<CallRecord> _calls = [];
  final Map<String, (String, String?)> _peers = {}; // id → (الاسم، الصورة)
  StreamSubscription<Map<String, dynamic>>? _hubSub1;
  StreamSubscription<Map<String, dynamic>>? _hubSub2;

  @override
  void initState() {
    super.initState();
    _load();
    // 1.2.0: الإصغاء عبر مركز Realtime الواحد — بلا قناة لكل زيارة:
    // إدراج أو تحديث مكالمة يعيد تحميل السجل، والمفتاح مالك واحد
    if (RealtimeHubService.registry.attach('calls-history')) {
      _hubSub1 = RealtimeHubService.callInserted.listen((_) => _load());
      _hubSub2 = RealtimeHubService.callUpdated.listen((_) => _load());
    }
  }

  @override
  void dispose() {
    _hubSub1?.cancel();
    _hubSub2?.cancel();
    _hubSub1 = null;
    _hubSub2 = null;
    RealtimeHubService.registry.detach('calls-history');
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final calls = await CallService.history();
      final me = supabase.auth.currentUser?.id ?? '';
      final ids = calls.map((c) => c.peerId(me)).toSet().toList();
      final peers = <String, (String, String?)>{};
      if (ids.isNotEmpty) {
        final rows = await supabase
            .from('profiles')
            .select('id, display_name, username, avatar_url')
            .inFilter('id', ids);
        for (final r in (rows as List)) {
          final id = (r as Map)['id'] as String;
          final name = (r['display_name'] as String?)?.isNotEmpty == true
              ? r['display_name'] as String
              : ((r['username'] as String?) ?? 'وصل');
          final avatar = (r['avatar_url'] as String?);
          peers[id] = (name, (avatar?.isNotEmpty ?? false) ? avatar : null);
        }
      }
      if (!mounted) return;
      setState(() {
        _calls = calls;
        _peers.addAll(peers);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  (String, String?) _peerOf(CallRecord r) {
    final me = supabase.auth.currentUser?.id ?? '';
    return _peers[r.peerId(me)] ?? ('وصل', null);
  }

  Future<void> _callAgain(CallRecord r) async {
    final me = supabase.auth.currentUser?.id ?? '';
    final (name, avatar) = _peerOf(r);
    final s = await CallService.start(
      conversationId: r.conversationId,
      peerId: r.peerId(me),
      peerName: name,
      peerAvatar: avatar,
      kind: r.kind,
    );
    if (!mounted) return;
    if (s == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('لا يمكن بدء مكالمة الآن — أغلق المكالمة الجارية أو حاول لاحقاً')));
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(session: s)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('المكالمات',
              style: TextStyle(fontSize: WaslFont.displayLarge, fontWeight: FontWeight.w800))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const WaslSkeletonList(rows: 6, trailingIcon: true)
            : _calls.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(WaslSpace.lg, WaslSpace.sm, WaslSpace.lg, 130),
                    itemCount: _calls.length,
                    itemBuilder: (context, i) => MotionStagger(
                      index: i,
                      child: _row(_calls[i]),
                    ),
                  ),
      ),
    );
  }

  Widget _row(CallRecord r) {
    final me = supabase.auth.currentUser?.id ?? '';
    final (name, avatar) = _peerOf(r);
    final negative = CallHistoryView.negative(r);
    final tint = negative ? WaslColors.danger : WaslColors.teal;
    final answered = r.status == CallStatus.answered || r.status == CallStatus.ended;
    return Container(
      margin: const EdgeInsets.only(bottom: WaslSpace.md),
      decoration: BoxDecoration(
        color: context.glass,
        borderRadius: BorderRadius.circular(WaslRadius.lg),
        border: Border.all(color: context.hairline),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WaslRadius.lg)),
        onTap: () => _callAgain(r),
        leading: UserAvatar(name: name, url: avatar, radius: 23,
            color: WaslColors.indigo),
        title: Text(name,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: WaslFont.bodyLarge)),
        subtitle: Row(children: [
          Icon(CallHistoryView.statusIcon(r, me), size: 14, color: tint),
          const SizedBox(width: WaslSpace.xs),
          Flexible(child: Text(CallHistoryView.statusLabel(r, me),
              style: TextStyle(color: tint, fontSize: WaslFont.meta), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (answered) ...[
            const SizedBox(width: WaslSpace.xs),
            Text('· ${CallHistoryView.formatDuration(r.duration)}',
                style: TextStyle(color: context.textTertiary, fontSize: WaslFont.meta)),
          ],
          const SizedBox(width: WaslSpace.sm),
          Icon(callKindIcon(r.kind), size: 13, color: context.textTertiary),
        ]),
        trailing: Text(CallHistoryView.timeLabel(r.createdAt, DateTime.now()),
            style: TextStyle(color: context.textTertiary, fontSize: WaslFont.small)),
      ),
    );
  }

  /// فراغ صادق: المكالمات بدأت — أول مكالمة من شريط أي محادثة خاصة
  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(WaslSpace.xxl, 40, WaslSpace.xxl, 130),
      children: [
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: WaslColors.gradient,
              boxShadow: [
                BoxShadow(
                  color: WaslColors.indigo.withValues(alpha: 0.35),
                  blurRadius: 38,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Icon(Icons.call_outlined, size: 50, color: context.onAccent),
          ),
        ),
        const SizedBox(height: WaslSpace.xxl),
        const Center(
          child: Text('لا مكالمات بعد',
              style: TextStyle(fontSize: WaslFont.titleLarge, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: WaslSpace.sm),
        Center(
          child: Text(
            'ابدأ أول مكالمة صوتية أو مرئية من شريط\nأي محادثة خاصة — وسيظهر سجلها هنا',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.7, color: context.textTertiary, fontSize: WaslFont.body),
          ),
        ),
        const SizedBox(height: WaslSpace.xxl),
        // واجهة للمستخدم لا للمطوّر: سطر واحد واضح بدل المصطلحات التقنية
        _feature(Icons.lock_outline_rounded, WaslColors.violet, 'مكالمات مشفّرة',
            'الصوت والصورة مشفّران بين جهازيكما'),
      ],
    );
  }

  Widget _feature(IconData icon, Color color, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: WaslSpace.md),
      padding: const EdgeInsets.all(WaslSpace.lg),
      decoration: BoxDecoration(
        color: context.glass,
        borderRadius: BorderRadius.circular(WaslRadius.xl),
        border: Border.all(color: context.hairline),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(WaslRadius.md),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: WaslSpace.lg),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: WaslFont.body)),
            const SizedBox(height: WaslSpace.xs),
            Text(desc,
                style: TextStyle(height: 1.5, color: context.textTertiary, fontSize: WaslFont.meta)),
          ]),
        ),
      ]),
    );
  }
}
