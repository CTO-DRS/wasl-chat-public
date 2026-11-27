import 'package:material_ui/material_ui.dart';

import '../services/business_reply_service.dart';
import '../theme.dart';
import '../widgets/wasl_sheet.dart';

/// ردود الأعمال: القوالب السريعة والرد التلقائي بالقواعد.
class BusinessRepliesScreen extends StatefulWidget {
  const BusinessRepliesScreen({super.key});

  @override
  State<BusinessRepliesScreen> createState() => _BusinessRepliesScreenState();
}

class _BusinessRepliesScreenState extends State<BusinessRepliesScreen> {
  @override
  void initState() {
    super.initState();
    BusinessReplyService.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _editTemplate([ReplyTemplate? t]) async {
    final title = TextEditingController(text: t?.title ?? '');
    final short = TextEditingController(text: t?.shortcut ?? '');
    final text = TextEditingController(text: t?.text ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t == null ? 'قالب جديد' : 'تعديل القالب'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                key: const ValueKey('tpl-title'),
                controller: title,
                decoration: const InputDecoration(labelText: 'العنوان')),
            TextField(
                key: const ValueKey('tpl-short'),
                controller: short,
                decoration: const InputDecoration(
                    labelText: 'الاختصار (اختياري)', hintText: 'سعر ← اكتب /سعر')),
            TextField(
                key: const ValueKey('tpl-text'),
                controller: text,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                    labelText: 'النص', helperText: 'متغيرات: {name} {shop}')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(
              key: const ValueKey('tpl-save'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty || text.text.trim().isEmpty) return;
    final n = ReplyTemplate(
        id: t?.id ?? _id(),
        title: title.text.trim(),
        text: text.text.trim(),
        shortcut: short.text.trim().replaceAll('/', ''));
    final list = [...BusinessReplyService.templates.value];
    final i = list.indexWhere((e) => e.id == n.id);
    i >= 0 ? list[i] = n : list.add(n);
    BusinessReplyService.templates.value = list;
    if (mounted) setState(() {});
    await BusinessReplyService.save();
  }

  void _undoBar(String text, Future<void> Function() undo) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        action: SnackBarAction(label: 'تراجع', onPressed: undo),
      ));
  }

  Future<void> _deleteRule(AutoReplyRule r) async {
    final before = [...BusinessReplyService.rules.value];
    BusinessReplyService.rules.value = [
      for (final e in before)
        if (e.id != r.id) e
    ];
    if (mounted) setState(() {});
    _undoBar('حُذفت القاعدة', () async {
      BusinessReplyService.rules.value = before;
      if (mounted) setState(() {});
      await BusinessReplyService.save();
    });
    await BusinessReplyService.save();
  }

  Future<void> _deleteTemplate(ReplyTemplate t) async {
    final beforeT = [...BusinessReplyService.templates.value];
    final beforeR = [...BusinessReplyService.rules.value];
    BusinessReplyService.templates.value = [
      for (final e in BusinessReplyService.templates.value)
        if (e.id != t.id) e
    ];
    BusinessReplyService.rules.value = [
      for (final r in BusinessReplyService.rules.value)
        if (r.templateId != t.id) r
    ];
    if (mounted) setState(() {});
    _undoBar('حُذف القالب', () async {
      BusinessReplyService.templates.value = beforeT;
      BusinessReplyService.rules.value = beforeR;
      if (mounted) setState(() {});
      await BusinessReplyService.save();
    });
    await BusinessReplyService.save();
  }

  Future<void> _addRule(ReplyRuleKind kind) async {
    final tpls = BusinessReplyService.templates.value;
    if (tpls.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('أضف قالباً أولاً')));
      return;
    }
    final kw = TextEditingController();
    var pick = tpls.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(kind == ReplyRuleKind.away ? 'رسالة غياب' : 'قاعدة كلمات'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (kind == ReplyRuleKind.keyword)
              TextField(
                  key: const ValueKey('rule-kw'),
                  controller: kw,
                  decoration: const InputDecoration(
                      labelText: 'الكلمات (افصل بفاصلة)', hintText: 'سعر، كم، التوصيل')),
            const SizedBox(height: WaslSpace.md),
            DropdownButtonFormField<String>(
              initialValue: pick,
              decoration: const InputDecoration(labelText: 'القالب'),
              items: [
                for (final t in tpls) DropdownMenuItem(value: t.id, child: Text(t.title))
              ],
              onChanged: (v) => setD(() => pick = v ?? pick),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(
                key: const ValueKey('rule-save'),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final words = kw.text
        .split(RegExp('[,،]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (kind == ReplyRuleKind.keyword && words.isEmpty) return;
    BusinessReplyService.rules.value = [
      ...BusinessReplyService.rules.value,
      AutoReplyRule(id: _id(), kind: kind, keywords: words, templateId: pick),
    ];
    if (mounted) setState(() {});
    await BusinessReplyService.save();
  }

  @override
  Widget build(BuildContext context) {
    final tpls = BusinessReplyService.templates.value;
    final rules = BusinessReplyService.rules.value;
    String tplName(String id) =>
        tpls.where((t) => t.id == id).firstOrNull?.title ?? '؟';
    return Scaffold(
      appBar: AppBar(title: const Text('ردود الأعمال')),
      body: ListView(
        padding: const EdgeInsets.all(WaslSpace.lg),
        children: [
          const SheetSectionLabel('الرد التلقائي'),
          GlassGroup([
            SwitchListTile(
              key: const ValueKey('auto-switch'),
              secondary: const Icon(Icons.smart_toy_rounded, color: WaslColors.violet),
              title: const Text('تفعيل الرد التلقائي',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  'للمحادثات الخاصة، مرة كل ساعة لكل محادثة. يعمل والتطبيق مفتوح فقط لأن الرسائل مشفرة طرف لطرف ولا يقرؤها الخادم.',
                  style: TextStyle(color: context.textFaint, fontSize: WaslFont.meta)),
              value: BusinessReplyService.autoReplyEnabled.value,
              onChanged: (v) async {
                BusinessReplyService.autoReplyEnabled.value = v;
                await BusinessReplyService.save();
                setState(() {});
              },
            ),
          ]),
          const SheetSectionLabel('القواعد'),
          GlassGroup([
            if (rules.isEmpty)
              ListTile(
                  leading: Icon(Icons.rule_rounded, color: context.textFaint),
                  title: Text('لا قواعد بعد. أضف قاعدة كلمات أو رسالة غياب.',
                      style: TextStyle(color: context.textFaint))),
            for (final r in rules)
              ListTile(
                leading: Icon(
                    r.kind == ReplyRuleKind.away
                        ? Icons.bedtime_rounded
                        : Icons.key_rounded,
                    color: WaslColors.teal),
                title: Text(
                    r.kind == ReplyRuleKind.away ? 'رسالة غياب' : r.keywords.join('، '),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('الرد: ${tplName(r.templateId)}',
                    style: TextStyle(color: context.textFaint)),
                trailing: IconButton(
                  tooltip: 'حذف القاعدة',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _deleteRule(r),
                ),
              ),
          ]),
          const SizedBox(height: WaslSpace.sm),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('add-kw-rule'),
                onPressed: () => _addRule(ReplyRuleKind.keyword),
                icon: const Icon(Icons.add_rounded),
                label: const Text('قاعدة كلمات'),
              ),
            ),
            const SizedBox(width: WaslSpace.sm),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('add-away-rule'),
                onPressed: () => _addRule(ReplyRuleKind.away),
                icon: const Icon(Icons.bedtime_rounded),
                label: const Text('رسالة غياب'),
              ),
            ),
          ]),
          const SheetSectionLabel('القوالب السريعة'),
          GlassGroup([
            if (tpls.isEmpty)
              ListTile(
                  title: Text('لا قوالب بعد. اكتب «/» في المحادثة لاستدعاء قوالبك.',
                      style: TextStyle(color: context.textFaint))),
            for (final t in tpls)
              ListTile(
                leading: const Icon(Icons.bolt_rounded, color: WaslColors.warning),
                title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${t.shortcut.isEmpty ? '' : '/${t.shortcut}  ·  '}${t.text}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                onTap: () => _editTemplate(t),
                trailing: IconButton(
                  tooltip: 'حذف القالب',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _deleteTemplate(t),
                ),
              ),
          ]),
          const SizedBox(height: WaslSpace.lg),
          FilledButton.icon(
            key: const ValueKey('add-template'),
            onPressed: () => _editTemplate(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('قالب جديد'),
          ),
        ],
      ),
    );
  }
}
