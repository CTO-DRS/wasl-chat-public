import 'package:material_ui/material_ui.dart';

import '../services/live_location_service.dart';
import '../theme.dart';

/// سطر حالة الموقع المباشر داخل فقاعة الموقع.
class LiveStatusRow extends StatelessWidget {
  const LiveStatusRow(this.state, {super.key});
  final LiveState state;

  @override
  Widget build(BuildContext context) {
    final live = state == LiveState.live;
    final color = live ? WaslColors.teal : WaslColors.warning;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(live ? Icons.podcasts_rounded : Icons.location_off_rounded,
          size: 14, color: color),
      const SizedBox(width: 4),
      Text(
          switch (state) {
            LiveState.live => 'موقع مباشر',
            LiveState.stale => 'موقع مباشر · توقفت التحديثات',
            LiveState.ended => 'انتهت المشاركة',
            LiveState.expired => 'انتهت مدة المشاركة',
          },
          style: TextStyle(
              fontSize: WaslFont.caption, fontWeight: FontWeight.w800, color: color)),
    ]);
  }
}
