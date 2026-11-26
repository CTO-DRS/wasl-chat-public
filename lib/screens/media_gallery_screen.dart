import 'dart:convert';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../services/e2e_service.dart';
import '../services/media_gallery_service.dart';
import '../services/media_search_service.dart';
import '../services/media_preview_service.dart';
import '../services/media_service.dart';
import '../services/video_preview_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/media_bubbles.dart';
import '../widgets/motion.dart';
import '../widgets/progressive_image.dart';
import 'chat_screen.dart';

/// صورة خلية شبكة (ج4): معاينة ضبابية فورية من الميتا (أو هيكل لامع
/// للرسائل القديمة) ثم تلاشٍ للصورة مفكوكة بدقة الخلية (cacheWidth) —
/// بلا تبعية لفقاعة المحادثة (مقاسات شبكة لا مقاسات رسالة)
class _GridImage extends StatelessWidget {
  const _GridImage({required this.loader, required this.item});
  final Future<Uint8List?> Function() loader;
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => ProgressiveImage(
        loader: loader,
        preview: MediaPreview(blurHash: item.blurHash, width: item.width, height: item.height),
        width: c.maxWidth,
        height: c.maxHeight,
        memoryKey: item.messageId,
        semanticLabel: 'صورة',
        failed: (context) => Container(
          color: context.glass,
          child: Icon(Icons.broken_image_rounded, size: 24, color: context.textFaint),
        ),
      ),
    );
  }
}

/// معرض وسائط المحادثة (المرحلة 8 ب — 0.21.0)
///
/// شبكة كل وسائط المحادثة (صور/فيديو/ملفات/صوتيات) بفلترة حسب النوع،
/// والنقر على أي وسيط يفتح المحادثة **مقفلاً على رسالته** (قفز دقيق
/// بالفهرس عبر scrollable_positioned_list).
///
/// الرسائل الوسائطية تُجلب من الخادم كما هي (مشفرة في المحادثات المشفرة)
/// وتُفك محلياً — لا يغادر أي شيء جهازك.
class MediaGalleryScreen extends StatefulWidget {
  const MediaGalleryScreen({
    super.key,
    required this.conversationId,
    required this.title,
    required this.isGroup,
    required this.isChannel,
    required this.encrypted,
    this.otherId,
    this.isSaved = false,
    this.isBot = false,
  });

  final String conversationId;
  final String title;
  final bool isGroup;
  final bool isChannel;
  final bool encrypted;
  final String? otherId;
  final bool isSaved;
  final bool isBot;

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  static const _limit = 500;

  final String _me = supabase.auth.currentUser!.id;
  List<MediaItem> _items = const [];
  String _tab = MediaGalleryService.tabs.first;
  bool _loading = true;
  String? _error;

  // فك النص (ميتا/تعليق) — نفس منطق شاشة المحادثة
  final Map<String, String> _plain = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _e2e => widget.encrypted && !widget.isChannel;

  String? _textOf(Map<String, dynamic> m) {
    final raw = m['content'] as String? ?? '';
    if (raw.isEmpty) return null;
    return E2eService.isEncrypted(raw) ? _plain[raw] : raw;
  }

  Future<String?> _decrypt(String content) async {
    if (!widget.isGroup) {
      if (widget.otherId == null) return null;
      return E2eService.decryptDmText(widget.conversationId, widget.otherId!, content);
    }
    var plain = await E2eService.decryptGroupText(widget.conversationId, content);
    if (plain == null) {
      E2eService.invalidateGroupKey(widget.conversationId);
      plain = await E2eService.decryptGroupText(widget.conversationId, content);
    }
    return plain;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await supabase
          .from('messages')
          .select('id, sender_id, type, content, media_url, created_at, deleted_at, view_once')
          .eq('conversation_id', widget.conversationId)
          .inFilter('type', ['image', 'video', 'file', 'voice'])
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(_limit);
      final list = List<Map<String, dynamic>>.from(rows);
      // فك ميتا/تعليقات الوسائط المشفرة (نقطة واحدة لكل نص مشفر)
      if (_e2e) {
        final futures = <Future<void>>[];
        for (final m in list) {
          final c = m['content'] as String? ?? '';
          if (c.isNotEmpty &&
              E2eService.isEncrypted(c) &&
              !_plain.containsKey(c)) {
            futures.add(_decrypt(c).then((p) {
              _plain[c] = p ?? '🔒';
              // mk الوسيط من الميتا المتدرجة يُخزّن برسالة عند الفك الأول
              if (p != null && p.startsWith('{')) {
                E2eService.rememberMediaKey(
                    widget.conversationId, m['id'] as String?, p);
              }
            }));
          }
        }
        await Future.wait(futures);
      }
      if (!mounted) return;
      setState(() {
        _items = MediaGalleryService.collect(list, _textOf, myId: _me);
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذّر جلب الوسائط — تحقق من الاتصال';
        });
      }
    }
  }

  List<MediaItem> get _filtered => MediaGalleryService.filter(_items, _tab);

  // ---- البحث الصادق (المرحلة 14 ب — 1.4.0): ميتاداتا محلية حصراً ----
  String _query = '';
  int _datePreset = 0; // 0 الكل، 1 24 ساعة، 2 أسبوع، 3 شهر
  int _sizePreset = 0; // 0 الكل، 1 <1 م.ب، 2 1–10 م.ب، 3 >10 م.ب
  static const _datePresets = ['الكل', '24 ساعة', 'أسبوع', 'شهر'];
  static const _sizePresets = ['الحجم: الكل', 'أقل من 1 م.ب', '1–10 م.ب', 'أكبر من 10 م.ب'];
  static const _sizeBounds = [(null, null), (null, 1024 * 1024), (1024 * 1024, 10 * 1024 * 1024), (10 * 1024 * 1024, null)];

  List<MediaSearchHit> get _searchHits {
    final now = DateTime.now();
    DateTime? from;
    switch (_datePreset) {
      case 1:
        from = now.subtract(const Duration(hours: 24));
        break;
      case 2:
        from = now.subtract(const Duration(days: 7));
        break;
      case 3:
        from = now.subtract(const Duration(days: 30));
        break;
    }
    final (minS, maxS) = _sizeBounds[_sizePreset];
    return MediaSearchService.search(
      sources: [(widget.title, _filtered)],
      query: MediaSearchQuery(
        text: _query.trim().isEmpty ? null : _query,
        from: from,
        minSizeBytes: minS,
        maxSizeBytes: maxS,
      ),
    );
  }

  bool get _searching =>
      _query.trim().isNotEmpty || _datePreset != 0 || _sizePreset != 0;
  Map<String, int> get _counts => MediaGalleryService.counts(_items);

  void _openInChat(MediaItem item) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: widget.conversationId,
          title: widget.title,
          isGroup: widget.isGroup,
          otherId: widget.otherId,
          isChannel: widget.isChannel,
          encrypted: widget.encrypted,
          isSaved: widget.isSaved,
          isBot: widget.isBot,
          focusMessageId: item.messageId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hits = _searchHits;
    return Scaffold(
      appBar: AppBar(
        title: Text('وسائط ${widget.title}',
            style: const TextStyle(fontSize: WaslFont.headline, fontWeight: FontWeight.w800)),
      ),
      body: Column(children: [
        // البحث الصادق — في ميتاداتا نملكها محلياً حصراً (1.4.0)
        Padding(
          padding: const EdgeInsets.fromLTRB(WaslSpace.md, WaslSpace.sm, WaslSpace.md, 0),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searching
                  ? IconButton(
                      tooltip: 'إغلاق',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() {
                        _query = '';
                        _datePreset = 0;
                        _sizePreset = 0;
                      }),
                    )
                  : null,
              hintText: 'بحث بالاسم أو التعليق — ميتاداتا محلية حصراً',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(WaslRadius.md)),
            ),
          ),
        ),
        // فلاتر التاريخ والحجم
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: WaslSpace.md, vertical: WaslSpace.xs),
            children: [
              for (var i = 0; i < _datePresets.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: WaslSpace.xs),
                  child: ChoiceChip(
                    label: Text(_datePresets[i], style: const TextStyle(fontSize: WaslFont.small)),
                    selected: _datePreset == i,
                    onSelected: (_) => setState(() => _datePreset = i),
                    selectedColor: WaslColors.teal,
                    labelStyle: TextStyle(
                        color: _datePreset == i ? Colors.white : context.textSecondary),
                  ),
                ),
              const VerticalDivider(width: 8),
              for (var i = 0; i < _sizePresets.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: WaslSpace.xs),
                  child: ChoiceChip(
                    label: Text(_sizePresets[i], style: const TextStyle(fontSize: WaslFont.small)),
                    selected: _sizePreset == i,
                    onSelected: (_) => setState(() => _sizePreset = i),
                    selectedColor: WaslColors.indigo,
                    labelStyle: TextStyle(
                        color: _sizePreset == i ? Colors.white : context.textSecondary),
                  ),
                ),
            ],
          ),
        ),
        // شريط الفلترة بأعداد كل نوع
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: WaslSpace.md, vertical: WaslSpace.sm),
            children: [
              for (final t in MediaGalleryService.tabs)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: WaslSpace.xs),
                  child: ChoiceChip(
                    label: Text('${t} ${_counts[t] == 0 ? '' : _counts[t]}'),
                    selected: _tab == t,
                    onSelected: (_) => setState(() => _tab = t),
                    selectedColor: WaslColors.teal,
                    labelStyle: TextStyle(
                        color: _tab == t ? Colors.white : context.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const WaslSkeletonGrid()
              : _error != null
                  ? ListView(padding: const EdgeInsets.all(WaslSpace.xxl), children: [
                      GlassEmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: _error!,
                        subtitle: 'اضغط للمحاولة مجدداً',
                      ),
                    ])
                  : hits.isEmpty && !_searching
                      ? ListView(padding: const EdgeInsets.all(WaslSpace.xxl), children: [
                          const GlassEmptyState(
                            icon: Icons.photo_library_outlined,
                            title: 'لا وسائط بعد',
                            subtitle:
                                'الصور والفيديو والملفات والصوتيات المتبادلة هنا ستظهر في شبكة واحدة',
                          ),
                        ])
                      : Column(children: [
                          if (_searching)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(WaslSpace.lg, WaslSpace.xxs, WaslSpace.lg, 0),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  hits.isEmpty
                                      ? 'لا نتائج — البحث في ميتاداتا نملكها: الاسم والتعليق والنوع والحجم والتاريخ حصراً'
                                      : '${hits.length} نتيجة — بحث في ميتاداتا محلية: الاسم والتعليق والنوع والحجم والتاريخ — لا رؤية لمحتوى الصورة',
                                  style: const TextStyle(
                                      fontSize: WaslFont.small, height: 1.4),
                                ),
                              ),
                            ),
                          Expanded(
                            child: hits.isEmpty && _searching
                                ? ListView(padding: const EdgeInsets.all(WaslSpace.xxl), children: [
                                    const GlassEmptyState(
                                      icon: Icons.search_off_rounded,
                                      title: 'لا نتائج مطابقة',
                                      subtitle:
                                          'جرّب كلمة أقصر أو وسّع نطاق التاريخ والحجم — البحث لا يرى محتوى الصور إطلاقاً',
                                    ),
                                  ])
                                : RefreshIndicator(
                                    onRefresh: _load,
                                    child: GridView.builder(
                                      padding:
                                          const EdgeInsets.fromLTRB(WaslSpace.md, WaslSpace.xs, WaslSpace.md, 120),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        mainAxisSpacing: WaslSpace.xs,
                                        crossAxisSpacing: WaslSpace.xs,
                                      ),
                                      itemCount: hits.length,
                                      itemBuilder: (context, i) {
                                        final item = hits[i].item;
                                        return MotionStagger(
                                          index: i.clamp(0, 12),
                                          child: _tile(item),
                                        );
                                      },
                                    ),
                                  ),
                          ),
                        ]),
        ),
      ]),
    );
  }

  Widget _tile(MediaItem item) {
    Widget child;
    final vp = item.isVideo ? _posterOf(item) : VideoPoster.empty;
    if (item.isImage) {
      child = _GridImage(loader: () => _mediaBytes(item), item: item);
    } else if (vp.hasPreview) {
      // ج5: خلية فيديو بملصقه (ضبابية ثم صورة) وزر تشغيل ومدة — الضغط للخلية
      final thumb = vp.thumbPath;
      child = LayoutBuilder(
        builder: (context, c) => VideoBubble(
          poster: vp,
          posterLoader: thumb == null ? null : () => _mediaBytes(item, path: thumb),
          width: c.maxWidth,
          height: c.maxHeight,
          messageId: item.messageId,
          compact: true,
          radius: 0,
        ),
      );
    } else {
      final icon = item.isVideo
          ? Icons.play_circle_fill
          : item.isVoice
              ? Icons.graphic_eq_rounded
              : Icons.insert_drive_file_rounded;
      final color = item.isVideo
          ? WaslColors.indigo
          : item.isVoice
              ? WaslColors.teal
              : WaslColors.violet;
      child = Container(
        color: context.glass,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 30, color: color),
          if (item.name != null) ...[
            const SizedBox(height: WaslSpace.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: WaslSpace.sm),
              child: Text(item.name!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: WaslFont.caption, height: 1.2)),
            ),
          ],
        ]),
      );
    }
    return InkWell(
      onTap: () => _openInChat(item),
      child: Stack(fit: StackFit.expand, children: [
        child,
        PositionedDirectional(
          top: 4,
          end: 4,
          child: Icon(
            item.mine ? Icons.north_west_rounded : Icons.south_east_rounded,
            size: 14,
            color: Colors.white.withValues(alpha: 0.9),
            shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
          ),
        ),
      ]),
    );
  }

  /// ج5: ملصق الفيديو من بنود المعرض (المسار مفحوص داخل مجلد المحادثة)
  VideoPoster _posterOf(MediaItem item) => VideoPoster.fromMeta({
        'bh': ?item.blurHash,
        'w': ?item.width,
        'h': ?item.height,
        'thumb': ?item.thumbPath,
      }, durationMs: item.durationMs, conversationId: widget.conversationId);

  /// [path]: ملف آخر بمفتاح وسيط البند نفسه (ملصق الفيديو) — وإلا الوسيط
  Future<Uint8List?> _mediaBytes(MediaItem item, {String? path}) async {
    try {
      path ??= item.mediaUrl;
      final raw = await MediaService.download(path);
      if (!E2eService.isEncryptedPath(path) || !_e2e) return raw;
      if (!widget.isGroup) {
        if (widget.otherId == null) return null;
        // مفتاح الوسيط: mk من الميتا المفكوكة (أو المخزّن عند الوصول) —
        // والقديمة بلا mk تهبط لمفتاح v1 الثابت تلقائياً (dmMediaKey)
        Map<String, dynamic>? meta;
        final t = item.rawContent == null ? null : _plain[item.rawContent!];
        if (t != null && t.startsWith('{')) {
          try {
            meta = Map<String, dynamic>.from(jsonDecode(t) as Map);
          } catch (_) {}
        }
        final key = await E2eService.dmMediaKey(
          conversationId: widget.conversationId,
          otherUserId: widget.otherId!,
          messageId: item.messageId,
          meta: meta,
        );
        if (key == null) return null;
        return await E2eService.decryptBytes(key, widget.conversationId, raw);
      }
      var out = await E2eService.decryptGroupBytes(widget.conversationId, raw);
      if (out == null) {
        E2eService.invalidateGroupKey(widget.conversationId);
        out = await E2eService.decryptGroupBytes(widget.conversationId, raw);
      }
      return out;
    } catch (_) {
      return null;
    }
  }
}
