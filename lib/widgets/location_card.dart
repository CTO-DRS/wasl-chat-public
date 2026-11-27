import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../services/live_location_service.dart';
import '../theme.dart';
import 'live_status_row.dart';

/// بطاقة الموقع داخل الفقاعة: بلاطة OSM محسوبة من الإحداثيات + دبوس + الوصف،
/// وسطر حالة عند المشاركة المباشرة. عند فشل البلاطة تظهر بطاقة بديلة.
class LocationCard extends StatelessWidget {
  const LocationCard({
    super.key,
    required this.lat,
    required this.lng,
    required this.label,
    required this.fill,
    required this.titleColor,
    required this.subColor,
    required this.onTap,
    this.liveState,
  });
  final double lat, lng;
  final String label;
  final LiveState? liveState;
  final Color fill, titleColor, subColor;
  final VoidCallback onTap;

  static String tileUrl(double lat, double lng, {int z = 14}) {
    final n = 1 << z;
    final xt = (((lng + 180) / 360) * n).floor().clamp(0, n - 1);
    final rad = lat * pi / 180;
    final yt = ((1 - (log(tan(rad) + 1 / cos(rad)) / pi)) / 2 * n)
        .floor()
        .clamp(0, n - 1);
    return 'https://tile.openstreetmap.org/$z/$xt/$yt.png';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(WaslRadius.md),
      onTap: onTap,
      child: Container(
        width: 240,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(WaslRadius.md),
          color: fill,
          border: Border.all(color: context.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(alignment: Alignment.center, children: [
              Image.network(tileUrl(lat, lng),
                  width: 240,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                        width: 240,
                        height: 140,
                        color: WaslColors.indigo.withValues(alpha: 0.25),
                        alignment: Alignment.center,
                        child: const Icon(Icons.map_rounded,
                            size: 42, color: WaslColors.teal),
                      )),
              const Icon(Icons.location_on_rounded,
                  size: 34,
                  color: WaslColors.danger,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black45)]),
            ]),
            Padding(
              padding: const EdgeInsets.all(WaslSpace.sm),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (liveState != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: LiveStatusRow(liveState!)),
                    Text(label.isEmpty ? 'موقع' : label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: WaslFont.meta,
                            fontWeight: FontWeight.w800,
                            color: titleColor)),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                          '\u2066${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}\u2069',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                              fontSize: WaslFont.caption, color: subColor)),
                    ),
                  ]),
            ),
          ],
        ),
      ),
    );
  }
}
