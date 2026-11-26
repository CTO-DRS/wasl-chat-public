import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../services/block_service.dart';
import '../services/presence_service.dart';
import '../services/profile_image_service.dart';
import '../services/qr_scanner.dart';
import '../services/username_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/profile_header.dart';
import 'chat_screen.dart';

/// ملفي الشخصي (2.5.0 — ج6): رأس قابل للطي بالخلفية، أفاتار متداخل بشارة
/// تعديل، عرض/تغيير/إزالة الصورتين، إجراءات سريعة (مشاركة، QR، تعديل،
/// نسخ الرابط)، وورقة تعديل الاسم والنبذة بعدّاد حي.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String _me = supabase.auth.currentUser!.id;
  String _username = '';
  String _displayName = '';
  String _bio = '';
  String? _avatar;
  String? _cover;
  bool _verified = false;
  bool _official = false;
  DateTime? _joinedAt;
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _uploadingCover = false;

  /// عمود cover_url (ترحيل 044) غير موجود على الخادم → الخلفية معطّلة بوضوح
  bool _coverSupported = true;

  /// تغيّر شيء يُعاد للشاشة السابقة (الإعدادات تحدّث بطاقتها)
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<Map<String, dynamic>> _fetch(String cols) =>
      supabase.from('profiles').select(cols).eq('id', _me).single();

  Future<void> _load({bool retry = false}) async {
    if (retry) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    const base = 'username, display_name, bio, avatar_url, verified, is_official, created_at';
    Map<String, dynamic>? p;
    try {
      p = await _fetch('$base, cover_url');
      _coverSupported = true;
    } catch (e) {
      // ترحيل 044 لم يُطبَّق: الاستعلام كله كان يفشل فيبقى الملف فارغاً —
      // نعيد الجلب بلا cover_url ونعطّل الخلفية بوضوح
      if (ProfileImageService.isMissingColumn(e)) {
        debugPrint('[profile] cover_url غير موجود (ترحيل 044): $e');
        _coverSupported = false;
        try {
          p = await _fetch(base);
        } catch (e2) {
          debugPrint('[profile] تحميل الملف فشل: $e2');
        }
      } else {
        debugPrint('[profile] تحميل الملف فشل: $e');
      }
    }
    if (!mounted) return;
    if (p == null) {
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
      return;
    }
    final row = p;
    setState(() {
      _username = (row['username'] ?? '') as String;
      _displayName = (row['display_name'] ?? '') as String;
      _bio = (row['bio'] ?? '') as String;
      _avatar = row['avatar_url'] as String?;
      _cover = _coverSupported ? row['cover_url'] as String? : null;
      _verified = row['verified'] == true;
      _official = row['is_official'] == true;
      _joinedAt = DateTime.tryParse((row['created_at'] ?? '') as String);
      _loading = false;
    });
  }

  // ---------- الصورة والخلفية ----------

  /// اختيار → تحضير (فك/قص/ضغط JPEG) → رفع → حفظ الرابط → حذف القديم.
  /// إن فشل حفظ الرابط بعد الرفع يُحذف الكائن اليتيم.
  Future<void> _pickImage(ProfileImageKind kind) async {
    final cover = kind == ProfileImageKind.cover;
    if (cover && !_coverSupported) {
      _snack('خلفية الملف تحتاج تحديث قاعدة البيانات (ترحيل 044) — راسل الإدارة');
      return;
    }
    final XFile? x;
    try {
      // بلا maxWidth/imageQuality: التصغير والضغط نحن نجريهما بدقة
      x = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (e) {
      _snack(ProfileImageService.describeError(e, kind: kind));
      return;
    }
    if (x == null || !mounted) return;
    setState(() => cover ? _uploadingCover = true : _uploadingAvatar = true);
    final store = supabase.storage.from(ProfileImageService.bucket);
    String? uploaded;
    try {
      final prepared = await ProfileImageService.prepare(await x.readAsBytes(), kind);
      final path = ProfileImageService.pathFor(_me, kind, DateTime.now());
      await store.uploadBinary(path, prepared.bytes,
          fileOptions: ProfileImageService.fileOptions());
      uploaded = path;
      final url = store.getPublicUrl(path);
      final column = cover ? 'cover_url' : 'avatar_url';
      final old = cover ? _cover : _avatar;
      await supabase.from('profiles').update({column: url}).eq('id', _me);
      uploaded = null; // صار مرجعاً في الملف — لا يُحذف
      final oldPath = ProfileImageService.ownedPathFromUrl(old, _me, kind);
      if (oldPath != null) store.remove([oldPath]).ignore();
      _changed = true;
      if (mounted) setState(() => cover ? _cover = url : _avatar = url);
      _snack(cover ? 'تم تحديث الخلفية' : 'تم تحديث الصورة');
    } catch (e, st) {
      if (uploaded != null) store.remove([uploaded]).ignore();
      if (cover && ProfileImageService.isMissingColumn(e) && mounted) {
        setState(() => _coverSupported = false);
      }
      _snack(ProfileImageService.describeError(e, kind: kind, st: st));
    } finally {
      if (mounted) {
        setState(() => cover ? _uploadingCover = false : _uploadingAvatar = false);
      }
    }
  }

  Future<void> _removeImage(ProfileImageKind kind) async {
    final cover = kind == ProfileImageKind.cover;
    final old = cover ? _cover : _avatar;
    if (old == null) return;
    try {
      await supabase
          .from('profiles')
          .update({cover ? 'cover_url' : 'avatar_url': null}).eq('id', _me);
      final oldPath = ProfileImageService.ownedPathFromUrl(old, _me, kind);
      if (oldPath != null) {
        supabase.storage.from(ProfileImageService.bucket).remove([oldPath]).ignore();
      }
      _changed = true;
      if (mounted) setState(() => cover ? _cover = null : _avatar = null);
    } catch (e) {
      debugPrint('[profile] حذف ${cover ? 'الخلفية' : 'الصورة'} فشل: $e');
      _snack(cover ? 'تعذّر حذف الخلفية' : 'تعذّر حذف الصورة');
    }
  }

  Future<void> _imageMenu(ProfileImageKind kind) async {
    final cover = kind == ProfileImageKind.cover;
    final url = cover ? _cover : _avatar;
    final choice = await showProfileImageSheet(context,
        title: cover ? 'خلفية الملف' : 'الصورة الشخصية',
        hasImage: url != null && url.isNotEmpty);
    if (!mounted || choice == null) return;
    switch (choice) {
      case ProfileImageChoice.view:
        if (url != null) {
          await showProfileImageViewer(context,
              url: url, title: cover ? 'خلفية الملف' : _displayName);
        }
      case ProfileImageChoice.change:
        await _pickImage(kind);
      case ProfileImageChoice.remove:
        await _removeImage(kind);
    }
  }

  // ---------- الاسم والنبذة ----------

  Future<void> _openEditSheet() async {
    final r = await showModalBottomSheet<ProfileEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceAlt,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(WaslRadius.xl))),
      builder: (_) => ProfileEditSheet(
        initialName: _displayName,
        initialBio: _bio,
        onSave: _saveProfile,
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      _displayName = r.name;
      _bio = r.bio;
    });
    _snack('حُفظ ملفك');
  }

  /// يعيد رسالة خطأ أو null عند النجاح (تعرضها الورقة نفسها)
  Future<String?> _saveProfile(ProfileEditResult r) async {
    try {
      await supabase.from('profiles').update({
        'display_name': r.name,
        'bio': r.bio.isEmpty ? null : r.bio,
      }).eq('id', _me);
      _changed = true;
      return null;
    } catch (e) {
      debugPrint('[profile] حفظ الاسم/النبذة فشل: $e');
      return 'تعذّر الحفظ — تحقق من الاتصال وحاول مجدداً';
    }
  }

  Future<void> _shareProfile() async {
    if (_username.isEmpty) return;
    final link = UsernameService.profileLink(_username);
    try {
      await SharePlus.instance.share(ShareParams(
          text: 'تواصل معي على وصل شات: $link', subject: 'ملفي على وصل شات'));
    } catch (_) {
      await _copyProfileLink();
    }
  }

  Future<void> _copyUsername() async {
    await Clipboard.setData(ClipboardData(text: '@$_username'));
    _snack('نُسخ @$_username');
  }

  /// تغيير اسم المستخدم: فحص توفر حي + حفظ عبر الخادم (مرة كل 24 ساعة)
  Future<void> _editUsername() async {
    final ctrl = TextEditingController(text: _username);
    final formKey = GlobalKey<FormState>();
    bool? available;
    bool checking = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => AlertDialog(
          backgroundColor: context.surfaceAlt,
          title: const Text('اسم المستخدم'),
          content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: ctrl,
                // توافق 3.47.9: TextFormField لم يُعرِّف prefixText بعد — عبر InputDecoration المتاحة في الإصدارين
                decoration: const InputDecoration(prefixText: '@'),
                autovalidateMode: AutovalidateMode.disabled,
                validator: (v) => UsernameService.validationError(v ?? ''),
                onChanged: (v) {
                  setSheet(() {
                    available = null;
                    checking = false;
                  });
                },
              ),
              const SizedBox(height: WaslSpace.sm),
              Text('رابطك العام: ${UsernameService.profileLink(ctrl.text.trim().isEmpty ? _username : UsernameService.normalize(ctrl.text))}',
                  style: TextStyle(fontSize: WaslFont.small, color: context.textTertiary)),
              if (checking)
                const Padding(
                  padding: EdgeInsets.only(top: WaslSpace.sm),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final err = UsernameService.validationError(ctrl.text);
                if (err != null) {
                  formKey.currentState?.validate();
                  return;
                }
                setSheet(() => checking = true);
                final okAv = await UsernameService.available(ctrl.text);
                setSheet(() {
                  checking = false;
                  available = okAv;
                });
              },
              child: const Text('فحص التوفر'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: available == true
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    final newName = UsernameService.normalize(ctrl.text);
    // لا نتخلص من المتحكم فوراً: حركة إغلاق الحوار ما زالت تبني الحقل
    // (كان يرمي «TextEditingController used after being disposed»)
    Future.delayed(const Duration(milliseconds: 600), ctrl.dispose);
    if (ok != true) return;
    if (mounted) setState(() => _saving = true);
    try {
      final u = await UsernameService.set(newName);
      if (!mounted) return;
      setState(() => _username = u);
      _changed = true;
      _snack('صار اسمك @$u');
    } catch (e) {
      _snack(UsernameService.errorLabel(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copyProfileLink() async {
    final link = UsernameService.profileLink(_username);
    await Clipboard.setData(ClipboardData(text: link));
    _snack('نُسخ رابط ملفك: $link');
  }

  /// رمز QR الخاص بي: يظهر رابطك العام — من يمسحه يجدك ويتحدث معك مباشرة،
  /// ومن نفس الورقة يمكن مسح رمز الطرف الآخر لفتح محادثته.
  void _showMyQr() {
    final link = UsernameService.profileLink(_username);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WaslSpace.xxl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(WaslSpace.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(WaslRadius.lg),
              ),
              child: QrImageView(data: link, size: 220),
            ),
            const SizedBox(height: WaslSpace.md),
            Text(link,
                style: TextStyle(fontSize: WaslFont.small, color: context.textTertiary)),
            const SizedBox(height: WaslSpace.xs),
            const Text('امسح الرمز بكاميرا أي مستخدم وصل لفتح محادثتك معه.',
                style: TextStyle(fontSize: WaslFont.small)),
            const SizedBox(height: WaslSpace.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _scanUserQr();
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('مسح رمز الطرف الآخر'),
              ),
            ),
            const SizedBox(height: WaslSpace.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (ctx.mounted) Navigator.pop(ctx);
                  _snack('نُسخ رابط ملفك');
                },
                icon: const Icon(Icons.link_rounded, size: 16),
                label: const Text('نسخ الرابط'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// مسح رمز الطرف الآخر → فتح محادثة مباشرة (نفس تدفق البحث في new_chat_screen)
  Future<void> _scanUserQr() async {
    final raw = await scanQrCode(context);
    if (!mounted || raw == null || raw.isEmpty) return;
    final name = UsernameService.parseFromInput(raw);
    if (name == null) {
      _snack('الرمز لا يحتوي رابط وصل شات');
      return;
    }
    try {
      final user = await UsernameService.lookup(name);
      if (!mounted) return;
      if (user == null) {
        _snack('لا يوجد مستخدم بهذا الرمز');
        return;
      }
      if (user['id'] == _me) {
        _snack('هذا رمزك أنت');
        return;
      }
      if (BlockService.isBlocked(user['id'] as String)) {
        _snack('لا يمكن فتح محادثة مع مستخدم محظور');
        return;
      }
      final isBot = user['is_bot'] == true;
      final convId = await supabase
          .rpc('create_direct_chat', params: {'other_id': user['id']});
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: convId as String,
            title: (user['display_name'] ?? user['username']) as String,
            otherId: user['id'] as String,
            // محادثات البوتات غير مشفرة — البوت يقرأها عبر واجهته (بصدق)
            isBot: isBot,
            encrypted: !isBot,
          ),
        ),
      );
    } catch (_) {
      if (mounted) _snack('تعذّر فتح المحادثة من الرمز');
    }
  }

  Widget _body() {
    final name = _displayName.isEmpty ? _username : _displayName;
    final hasLink = _username.isNotEmpty;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        ProfileCoverAppBar(
          title: name,
          coverUrl: _cover,
          coverSemantics: _coverSupported
              ? (_cover == null ? 'إضافة خلفية للملف' : 'خلفية الملف — عرض أو تغيير')
              : 'خلفية الملف غير متاحة',
          onCoverTap: _uploadingCover ? null : () => _imageMenu(ProfileImageKind.cover),
          actions: [
            if (hasLink)
              IconButton(
                tooltip: 'رمز QR الخاص بي',
                onPressed: _showMyQr,
                icon: const Icon(Icons.qr_code_2_rounded),
              ),
          ],
        ),
        SliverToBoxAdapter(
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
            Padding(
              padding: const EdgeInsets.only(
                  top: kProfileAvatarRadius * 2 + 8 - kProfileAvatarOverlap + WaslSpace.sm),
              child: Column(children: [
                if (_uploadingCover)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: WaslSpace.xxl),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: WaslSpace.xl),
                  child: ProfileIdentity(
                    name: name.isEmpty ? 'بلا اسم' : name,
                    username: _username,
                    verified: _verified,
                    official: _official,
                    onEditUsername: _saving ? null : _editUsername,
                    onCopyUsername: hasLink ? _copyUsername : null,
                  ),
                ),
                ProfileStatusLine(
                    online: PresenceService.isOnline(_me), joinedAt: _joinedAt),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      WaslSpace.xxl, WaslSpace.md, WaslSpace.xxl, 0),
                  child: _bio.isEmpty
                      ? TextButton.icon(
                          style: TextButton.styleFrom(
                              minimumSize: const Size(WaslSize.minTap, WaslSize.minTap)),
                          onPressed: _openEditSheet,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('أضف نبذة قصيرة عنك'),
                        )
                      : ExpandableBio(text: _bio),
                ),
                const SizedBox(height: WaslSpace.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: WaslSpace.md),
                  child: ProfileQuickActions(actions: [
                    ProfileAction(
                        icon: Icons.ios_share_rounded,
                        label: 'مشاركة',
                        semanticsLabel: 'مشاركة رابط ملفي',
                        onTap: hasLink ? _shareProfile : null),
                    ProfileAction(
                        icon: Icons.qr_code_2_rounded,
                        label: 'رمز QR',
                        semanticsLabel: 'رمز QR الخاص بي ومسح رموز الآخرين',
                        onTap: hasLink ? _showMyQr : null),
                    ProfileAction(
                        icon: Icons.edit_rounded,
                        label: 'تعديل',
                        semanticsLabel: 'تعديل الاسم والنبذة',
                        onTap: _openEditSheet),
                    ProfileAction(
                        icon: Icons.link_rounded,
                        label: 'نسخ الرابط',
                        semanticsLabel: 'نسخ رابط ملفي العام',
                        onTap: hasLink ? _copyProfileLink : null),
                  ]),
                ),
              ]),
            ),
            Positioned(
              top: -kProfileAvatarOverlap,
              child: ProfileAvatarBadge(
                name: name,
                url: _avatar,
                busy: _uploadingAvatar,
                online: false,
                onTap: () => _imageMenu(ProfileImageKind.avatar),
                onEdit: () => _pickImage(ProfileImageKind.avatar),
              ),
            ),
          ]),
        ),
        SliverToBoxAdapter(
          child: ProfileSection(title: 'الحساب', children: [
            ProfileTile(
              icon: Icons.badge_outlined,
              title: 'الاسم الظاهر',
              subtitle: _displayName.isEmpty ? 'لم يُضبط بعد' : _displayName,
              onTap: _openEditSheet,
            ),
            ProfileTile(
              icon: Icons.alternate_email_rounded,
              title: 'اسم المستخدم',
              subtitle: _username.isEmpty ? 'اختر اسماً فريداً' : '@$_username',
              onTap: _saving ? null : _editUsername,
            ),
            if (hasLink)
              ProfileTile(
                icon: Icons.public_rounded,
                title: 'رابطك العام',
                subtitle: UsernameService.profileLink(_username),
                onTap: _copyProfileLink,
                trailing: Icon(Icons.copy_rounded, size: 18, color: context.textFaint),
              ),
          ]),
        ),
        SliverToBoxAdapter(
          child: ProfileSection(title: 'المظهر', children: [
            ProfileTile(
              icon: Icons.account_circle_outlined,
              title: 'الصورة الشخصية',
              subtitle: _avatar == null ? 'أضف صورة يعرفك بها أصدقاؤك' : 'عرض أو تغيير أو إزالة',
              onTap: _uploadingAvatar ? null : () => _imageMenu(ProfileImageKind.avatar),
            ),
            ProfileTile(
              icon: Icons.panorama_outlined,
              title: 'خلفية الملف',
              subtitle: !_coverSupported
                  ? 'غير متاحة حتى تُحدَّث قاعدة البيانات'
                  : (_cover == null
                      ? 'تظهر أعلى ملفك وفي رابطك العام'
                      : 'عرض أو تغيير أو إزالة'),
              onTap: _uploadingCover ? null : () => _imageMenu(ProfileImageKind.cover),
            ),
          ]),
        ),
        SliverToBoxAdapter(
          child: ProfileSection(children: [
            ProfileTile(
              icon: Icons.qr_code_scanner_rounded,
              title: 'مسح رمز مستخدم',
              subtitle: 'افتح محادثة مباشرة من رمز QR',
              onTap: _scanUserQr,
            ),
          ]),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              WaslSpace.xxl, WaslSpace.lg, WaslSpace.xxl, WaslSpace.xxxl),
          sliver: SliverToBoxAdapter(
            child: Text('صورتك واسمك ونبذتك يراها أي مستخدم في وصل.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textFaint, fontSize: WaslFont.small)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        body: _loading
            ? SafeArea(
                child: Column(children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: BackButton(onPressed: () => Navigator.maybePop(context)),
                  ),
                  const Expanded(
                      child: WaslSkeletonHeader(cover: true, actions: 4, rows: 3)),
                ]),
              )
            : _loadFailed
                ? Scaffold(
                    appBar: AppBar(title: const Text('الملف الشخصي')),
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(WaslSpace.xxl),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const GlassEmptyState(
                            icon: Icons.cloud_off_rounded,
                            title: 'تعذّر تحميل الملف الشخصي',
                            subtitle: 'تحقق من الاتصال ثم أعد المحاولة',
                          ),
                          const SizedBox(height: WaslSpace.lg),
                          FilledButton.icon(
                            onPressed: () => _load(retry: true),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ]),
                      ),
                    ),
                  )
                : _body(),
      ),
    );
  }
}
