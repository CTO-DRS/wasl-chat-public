import 'package:material_ui/material_ui.dart';

import '../services/message_buttons.dart';
import '../theme.dart';

/// صف أزرار تحت نص الرسالة: كل زر بعرض كامل كما في تيليجرام.
class MessageButtonsRow extends StatelessWidget {
  const MessageButtonsRow({super.key, required this.buttons, required this.onTap});
  final List<MessageButton> buttons;
  final void Function(MessageButton) onTap;

  @override
  Widget build(BuildContext context) {
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: WaslSpace.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final b in buttons)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: OutlinedButton.icon(
              key: ValueKey('msg-btn-${b.label}'),
              onPressed: () => onTap(b),
              icon: Icon(
                  b.kind == ButtonKind.url
                      ? Icons.open_in_new_rounded
                      : Icons.content_copy_rounded,
                  size: 16),
              label: Text(b.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
      ]),
    );
  }
}
