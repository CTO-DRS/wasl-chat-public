import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../services/block_service.dart';
import '../services/e2e_service.dart';
import '../services/presence_service.dart';
import '../services/username_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/profile_header.dart';
import '../widgets/report_dialog.dart';
import 'chat_studio_screen.dart';

String disappearLabel(int? s) {
  switch (s) {
    case 86400:
      return '24 ساعة';
    case 604800:
      return '7 أيام';
    case 7776000:
      return '90 يوماً';
    default:
      return 'متوقفة';
  }
}

/// يختار مؤقت الرسائل المختفية ويحفظه. يعيد القيمة الجديدة (0 = متوقفة) أو null عند الإلغاء/الفشل.
Future<int?> pickDisappearing(BuildContext context, String convId, int? current) async {
  final picked = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: context.surfaceAlt,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(WaslRadius.xl))),
    builder: (ctx) => SafeArea(
      child: Wrap(children: [
        const ListTile(
          title: Text('الرسائل المختفية', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
              'الرسائل الجديدة تُحذف من الخادم بعد المدة المختارة. الرسائل السابقة لا تتأثر، ويمكن لأي طرف تصوير الشاشة.'),
        ),
        for (final s in const [0, 86400, 604800, 7776000])
          ListTile(
            leading: Icon(
                (current ?? 0) == s ? Icons.radio_button_checked : Icons.radio_button_off,
                color: WaslColors.teal),
            title: Text(disappearLabel(s == 0 ? null : s)),
            onTap: () => Navigator.pop(ctx, s),
          ),
      ]),
    ),
  );
  if (picked == null) return null;
  try {
    await supabase.rpc('set_disappearing', params: {'p_conv': convId, 'p_seconds': picked});
    return picked;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().contains('admins only')
              ? 'المالك أو المشرفون فقط يغيّرون هذا الإعداد'
              : 'تعذّر الحفظ')));
    }
    return null;
  }
}

/// ملف الطرف الآخر في المحادثة الفردية
class ContactScreen extends StatefulWidget {
  const ContactScreen({
    super.key,
    required this.otherId,
    required this.conversationId,
    required this.title,
    this.disappearSeconds,
    this.onSafetyNumber,
    this.onShowStarred,
    this.onOpenMedia,
    this.onVoiceCall,
    this.onVideoCall,
  });
  final String otherId;
  final String conversationId;
  final String title;
  final int? disappearSeconds;
  final VoidCallback? onSafetyNumber;
  final VoidCallback? onShowStarred;

  /// معرض وسائط المحادثة (صور/فيديو/ملفات/صوت) — من شاشة المحادثة
  final VoidCallback? onOpenMedia;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  Map<String, dynamic>? _p;
  bool _muted = false;
  int? _disappear;
  bool _blocked = false;
  bool _loaded = false;

  /// المجموعات المشتركة: ما أراه أنا من عضوياته (RLS: محادثاتي فقط)
  List<({String id, String title})>? _common;

  /// 0 = الوسائط، 1 = المجموعات المشتركة
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _disappear = widget.disappearSeconds;
    _load();
    _loadBlocked();
    _loadCommonGroups();
    PresenceService.online.addListener(_onPresence);
  }

  @override
  void dispose() {
    PresenceService.online.removeListener(_onPresence);
    super.dispose();
  }

  void _onPresence() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCommonGroups() async {
    try {
      final rows = await supabase
          .from('conversation_participants')
          .select('conversation_id, conversations!inner(id, title, is_group, kind)')
          .eq('user_id', widget.otherId)
          .eq('conversations.is_group', true)
          .limit(50);
      final out = <({String id, String title})>[];
      for (final r in rows) {
        final c = r['conversations'];
        if (c is! Map) continue;
        if (c['kind'] == 'channel') continue;
        final id = c['id'] as String?;
        if (id == null || id == widget.conversationId) continue;
        final raw = (c['title'] ?? '') as String;
        String title;
        try {
          title = await E2eService.groupTitle(id, raw);
        } catch (_) {
          title = E2eService.isEncrypted(raw) ? 'مجموعة مشفرة' : raw;
        }
        out.add((id: id, title: title.isEmpty ? 'مجموعة' : title));
      }
      if (mounted) setState(() => _common = out);
    } catch (e) {
      debugPrint('[contact] المجموعات المشتركة: $e');
      if (mounted) setState(() => _common = const []);
    }
  }

  Future<void> _loadBlocked() async {
    await BlockService.ensureLoaded();
    if (mounted) {
      setState(() => _blocked = BlockService.isBlocked(widget.otherId));
    }
  }

  Future<void> _toggleBlock() async {
    if (_blocked) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('إلغاء الحظر؟'),
          content: const Text('سيستطيع إرسال الرسائل إليك مجدداً.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('إلغاء الحظر')),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await BlockService.unblock(widget.otherId);
        if (mounted) setState(() => _blocked = false);
        if (mounted) Navigator.pop(context, true);
      } catch (_) {
        _snack('تعذّر إلغاء الحظر');
      }
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حظر المستخدم؟'),
        content: const Text(
            'لن يصلك منه رسائل جديدة، ولن يستطيع إرسال رسائل إليك. لن يُبلَّغ بالحظر.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: WaslColors.danger),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حظر')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await BlockService.block(widget.otherId);
      if (mounted) setState(() => _blocked = true);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      _snack('تعذّر الحظر');
    }
  }

  Future<void> _report() async {
    final name = (_p?['display_name'] ?? _p?['username'] ?? widget.title) as String?;
    final blocked = await showReportDialog(context,
        targetUser: widget.otherId, targetName: name);
    if (blocked && mounted) {
      setState(() => _blocked = true);
      Navigator.pop(context, true);
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        supabase
            .from('profiles')
            .select('username, display_name, bio, avatar_url, verified, is_official, created_at')
            .eq('id', widget.otherId)
            .single(),
        supabase
            .from('conversation_participants')
            .select('muted_until')
            .eq('conversation_id', widget.conversationId)
            .eq('user_id', supabase.auth.currentUser!.id)
            .single(),
      ]);
      final mu = results[1]['muted_until'] as String?;
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _p = results[0];
        _muted = mu != null &&
            (mu == 'infinity' || (DateTime.tryParse(mu)?.isAfter(DateTime.now()) ?? false));
      });
    } catch (e) {
      debugPrint('[contact] تحميل الملف: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _toggleMute() async {
    try {
      await supabase.rpc('set_chat_prefs', params: {
        'p_conv': widget.conversationId,
        'p_mute_hours': _muted ? 0 : -1,
      });
      if (mounted) setState(() => _muted = !_muted);
    } catch (_) {}
  }

  String get _username => (_p?['username'] ?? '') as String;

  Future<void> _copyUsername() async {
    await Clipboard.setData(ClipboardData(text: '@$_username'));
    _snack('نُسخ @$_username');
  }

  Future<void> _share() async {
    final link = UsernameService.profileLink(_username);
    try {
      await SharePlus.instance.share(ShareParams(text: link));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: link));
      _snack('نُسخ رابط الملف');
    }
  }

  Future<void> _avatarTap(String name) async {
    final url = _p?['avatar_url'] as String?;
    if (url == null || url.isEmpty) return;
    await showProfileImageViewer(context, url: url, title: name);
  }

  Widget _tabs() {
    final groups = _common;
    final segments = <(String, IconData)>[
      ('الوسائط والملفات', Icons.perm_media_outlined),
      (groups == null || groups.isEmpty
          ? 'مجموعات مشتركة'
          : 'مجموعات مشتركة (${groups.length})',
       Icons.groups_2_outlined),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(WaslSpace.lg, WaslSpace.lg, WaslSpace.lg, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (var i = 0; i < segments.length; i++)
              ButtonSegment<int>(
                value: i,
                icon: Icon(segments[i].$2, size: 18),
                label: Text(segments[i].$1,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
          selected: {_tab},
          onSelectionChanged: (v) => setState(() => _tab = v.first),
        ),
        const SizedBox(height: WaslSpace.sm),
        AnimatedSwitcher(
          duration: MediaQuery.maybeDisableAnimationsOf(context) == true
              ? Duration.zero
              : WaslMotion.base,
          child: _tab == 0 ? _mediaPane() : _groupsPane(),
        ),
      ]),
    );
  }

  Widget _mediaPane() {
    return ProfileSection(key: const ValueKey('media'), children: [
      if (widget.onOpenMedia != null)
        ProfileTile(
          icon: Icons.photo_library_outlined,
          title: 'الصور والفيديو والملفات',
          subtitle: 'كل ما تبادلتماه في هذه المحادثة',
          onTap: widget.onOpenMedia,
        )
      else
        Padding(
          padding: const EdgeInsets.all(WaslSpace.lg),
          child: Text('افتح الوسائط من شاشة المحادثة',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textTertiary)),
        ),
      if (widget.onShowStarred != null)
        ProfileTile(
          icon: Icons.star_outline_rounded,
          color: WaslColors.warning,
          title: 'الرسائل المميزة بنجمة',
          onTap: () {
            Navigator.pop(context);
            widget.onShowStarred!();
          },
        ),
    ]);
  }

  Widget _groupsPane() {
    final groups = _common;
    if (groups == null) {
      return const Padding(
        key: ValueKey('groups-loading'),
        padding: EdgeInsets.all(WaslSpace.xl),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (groups.isEmpty) {
      return Padding(
        key: const ValueKey('groups-empty'),
        padding: const EdgeInsets.symmetric(vertical: WaslSpace.lg),
        child: GlassEmptyState(
          icon: Icons.groups_2_outlined,
          title: 'لا مجموعات مشتركة',
          subtitle: 'المجموعات التي تجمعكما تظهر هنا',
        ),
      );
    }
    return ProfileSection(key: const ValueKey('groups'), children: [
      for (final g in groups)
        ListTile(
          minTileHeight: 56,
          leading: UserAvatar(name: g.title, radius: 18, icon: Icons.groups_rounded),
          title: Text(g.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final name = (_p?['display_name'] ?? _p?['username'] ?? widget.title) as String;
    final bio = _p?['bio'] as String?;
    final online = PresenceService.isOnline(widget.otherId);
    final joined = DateTime.tryParse((_p?['created_at'] ?? '') as String);
    final actions = <ProfileAction>[
      ProfileAction(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'مراسلة',
          semanticsLabel: 'العودة إلى المحادثة',
          onTap: () => Navigator.pop(context)),
      if (widget.onVoiceCall != null && !_blocked)
        ProfileAction(
            icon: Icons.call_outlined, label: 'اتصال', onTap: widget.onVoiceCall),
      if (widget.onVideoCall != null && !_blocked)
        ProfileAction(
            icon: Icons.videocam_outlined, label: 'فيديو', onTap: widget.onVideoCall),
      if (_username.isNotEmpty)
        ProfileAction(
            icon: Icons.ios_share_rounded,
            label: 'مشاركة',
            semanticsLabel: 'مشاركة رابط ملفه',
            onTap: _share),
      ProfileAction(
          icon: _muted ? Icons.notifications_off_rounded : Icons.notifications_none_rounded,
          label: _muted ? 'مكتوم' : 'كتم',
          semanticsLabel: _muted ? 'إلغاء كتم الإشعارات' : 'كتم الإشعارات',
          onTap: _toggleMute),
    ];
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          ProfileCoverAppBar(
            title: name,
            coverUrl: _p?['cover_url'] as String?,
          ),
          SliverToBoxAdapter(
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
              Padding(
                padding: const EdgeInsets.only(
                    top: kProfileAvatarRadius * 2 + 8 - kProfileAvatarOverlap + WaslSpace.sm),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: WaslSpace.xl),
                    child: ProfileIdentity(
                      name: name,
                      username: _username,
                      verified: _p?['verified'] == true,
                      official: _p?['is_official'] == true,
                      onCopyUsername: _username.isEmpty ? null : _copyUsername,
                    ),
                  ),
                  if (_p?['is_official'] == true)
                    Container(
                      margin: const EdgeInsets.only(top: WaslSpace.xs, bottom: WaslSpace.xxs),
                      padding: const EdgeInsets.symmetric(
                          horizontal: WaslSpace.md, vertical: WaslSpace.xs),
                      decoration: BoxDecoration(
                        color: VerifiedBadge.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(WaslRadius.xl),
                      ),
                      child: const Text('حساب رسمي من وصل شات',
                          style: TextStyle(
                              fontSize: WaslFont.small,
                              fontWeight: FontWeight.w700,
                              color: VerifiedBadge.color)),
                    ),
                  ProfileStatusLine(online: online && !_blocked, joinedAt: joined),
                  if (!_loaded)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: WaslSpace.xxxl, vertical: WaslSpace.md),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (bio != null && bio.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          WaslSpace.xxl, WaslSpace.md, WaslSpace.xxl, 0),
                      child: ExpandableBio(text: bio),
                    ),
                  const SizedBox(height: WaslSpace.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: WaslSpace.md),
                    child: ProfileQuickActions(actions: actions),
                  ),
                ]),
              ),
              Positioned(
                top: -kProfileAvatarOverlap,
                child: ProfileAvatarBadge(
                  name: name,
                  url: _p?['avatar_url'] as String?,
                  online: online && !_blocked,
                  onTap: () => _avatarTap(name),
                ),
              ),
            ]),
          ),
          SliverToBoxAdapter(child: _tabs()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(WaslSpace.lg, WaslSpace.lg, WaslSpace.lg, 0),
              child: ChatStudioEntry(conversationId: widget.conversationId, title: widget.title),
            ),
          ),
          SliverToBoxAdapter(
            child: ProfileSection(title: 'الخصوصية والأمان', children: [
              if (widget.onSafetyNumber != null)
                ProfileTile(
                  icon: Icons.verified_user_outlined,
                  title: 'رمز الأمان',
                  subtitle: 'قارنه مع صديقك للتأكد أن لا أحد في المنتصف',
                  onTap: widget.onSafetyNumber,
                ),
              ProfileTile(
                icon: Icons.timer_outlined,
                color: WaslColors.violet,
                title: 'الرسائل المختفية',
                subtitle: disappearLabel(_disappear),
                onTap: () async {
                  final v = await pickDisappearing(context, widget.conversationId, _disappear);
                  if (v != null && mounted) setState(() => _disappear = v == 0 ? null : v);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_off_outlined, color: WaslColors.indigo),
                title: const Text('كتم الإشعارات'),
                value: _muted,
                onChanged: (_) => _toggleMute(),
              ),
            ]),
          ),
          SliverToBoxAdapter(
            child: ProfileSection(children: [
              ListTile(
                minTileHeight: 56,
                leading: Icon(_blocked ? Icons.block_rounded : Icons.block_outlined,
                    color: _blocked ? WaslColors.danger : context.iconStd),
                title: Text(_blocked ? 'إلغاء حظر هذا الاتصال' : 'حظر هذا الاتصال',
                    style: TextStyle(color: _blocked ? WaslColors.danger : null)),
                subtitle: Text(_blocked
                    ? 'محدود الآن: لا رسائل جديدة بينكما من أي اتجاه'
                    : 'لن يصلك منه رسائل جديدة ولن يُبلَّغ بالحظر'),
                onTap: _toggleBlock,
              ),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.flag_outlined, color: WaslColors.danger),
                title: const Text('الإبلاغ عن المستخدم',
                    style: TextStyle(color: WaslColors.danger)),
                subtitle: const Text('تصل الشكوى إلى إدارة التطبيق فقط'),
                onTap: _report,
              ),
            ]),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
