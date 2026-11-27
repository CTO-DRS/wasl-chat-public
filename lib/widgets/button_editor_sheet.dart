import 'package:material_ui/material_ui.dart';

import '../services/message_buttons.dart';
import '../theme.dart';

/// محرر أزرار الرسالة لمشرفي القناة: حتى 4 أزرار (رابط https أو نسخ نص).
Future<List<MessageButton>?> showButtonEditor(
    BuildContext context, List<MessageButton> initial) {
  return showModalBottomSheet<List<MessageButton>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ButtonEditor(initial: initial),
  );
}

class ButtonEditor extends StatefulWidget {
  const ButtonEditor({super.key, required this.initial});
  final List<MessageButton> initial;

  @override
  State<ButtonEditor> createState() => _ButtonEditorState();
}

class _Row {
  _Row(MessageButton? b)
      : label = TextEditingController(text: b?.label ?? ''),
        value = TextEditingController(text: b?.value ?? ''),
        kind = b?.kind ?? ButtonKind.url;
  final TextEditingController label, value;
  ButtonKind kind;
}

class _ButtonEditorState extends State<ButtonEditor> {
  late final List<_Row> rows = [for (final b in widget.initial) _Row(b)];
  String? error;

  @override
  void dispose() {
    for (final r in rows) {
      r.label.dispose();
      r.value.dispose();
    }
    super.dispose();
  }

  void _done() {
    final out = <MessageButton>[];
    for (final r in rows) {
      final b = MessageButton.tryParse({
        'label': r.label.text,
        'kind': r.kind.name,
        'value': r.value.text,
      });
      if (b == null) {
        setState(() => error = r.kind == ButtonKind.url
            ? 'تأكد من اسم الزر (حتى 24 حرفاً) ومن أن الرابط يبدأ بـ https://'
            : 'تأكد من اسم الزر (حتى 24 حرفاً) ومن النص المراد نسخه');
        return;
      }
      out.add(b);
    }
    Navigator.pop(context, out);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: WaslSpace.lg,
          right: WaslSpace.lg,
          top: WaslSpace.lg),
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('أزرار الرسالة',
                  style: TextStyle(fontSize: WaslFont.titleLarge, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('تظهر تحت نص الرسالة التالية في القناة. رابط يفتح صفحة، أو نسخ نص مثل كود خصم.',
                  style: TextStyle(height: 1.6)),
              const SizedBox(height: WaslSpace.md),
              for (var i = 0; i < rows.length; i++)
                Padding(
                  key: ValueKey('btn-row-$i'),
                  padding: const EdgeInsets.only(bottom: WaslSpace.md),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                          child: TextField(
                              key: ValueKey('btn-label-$i'),
                              controller: rows[i].label,
                              maxLength: MessageButton.maxLabel,
                              decoration: const InputDecoration(labelText: 'اسم الزر'))),
                      IconButton(
                          key: ValueKey('btn-del-$i'),
                          onPressed: () => setState(() => rows.removeAt(i)),
                          icon: const Icon(Icons.delete_outline_rounded)),
                    ]),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ButtonKind>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: ButtonKind.url, label: Text('رابط')),
                          ButtonSegment(value: ButtonKind.copy, label: Text('نسخ')),
                        ],
                        selected: {rows[i].kind},
                        onSelectionChanged: (s) => setState(() => rows[i].kind = s.first),
                      ),
                    ),
                    const SizedBox(height: WaslSpace.sm),
                    TextField(
                        key: ValueKey('btn-value-$i'),
                        controller: rows[i].value,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                            labelText: rows[i].kind == ButtonKind.url
                                ? 'الرابط (يبدأ بـ https)'
                                : 'النص الذي يُنسخ')),
                  ]),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: WaslSpace.sm),
                  child: Text(error!, style: const TextStyle(color: WaslColors.danger)),
                ),
              Row(children: [
                if (rows.length < MessageButton.maxButtons)
                  Flexible(child: TextButton.icon(
                      key: const ValueKey('btn-add'),
                      onPressed: () => setState(() => rows.add(_Row(null))),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('زر جديد', overflow: TextOverflow.ellipsis))),
                const Spacer(),
                FilledButton(
                    key: const ValueKey('btn-done'),
                    onPressed: _done,
                    child: Text(rows.isEmpty ? 'إزالة الأزرار' : 'تم')),
              ]),
              const SizedBox(height: WaslSpace.lg),
            ]),
      ),
    );
  }
}
