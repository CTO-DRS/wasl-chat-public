import 'package:flutter/foundation.dart' show compute;

import 'daily_summary_service.dart';
import 'missed_summary_service.dart';
import 'weekly_summary_service.dart';

/// يشغّل عملاً ثقيلاً على isolate منفصل حين يكبر الدخل، وتبقى الصغيرة متزامنة
/// (إنشاء isolate يكلف أكثر من بناء ملخص لعشرات الرسائل). الدوال المرسلة نقية:
/// لا إضافات ولا حالة ساكنة، ودخلها وخرجها كائنات بسيطة قابلة للإرسال.
const heavyThreshold = 800;

Future<R> computeIfLarge<A, R>(int size, R Function(A) f, A arg,
    {int threshold = heavyThreshold}) {
  if (size > threshold) return compute<A, R>(f, arg);
  return Future<R>.value(f(arg));
}

String? _daily((List<DailyLine>, DateTime) a) => DailySummaryService.build(a.$1, a.$2);
String? _weekly((List<WeeklyLine>, DateTime) a) => WeeklySummaryService.build(a.$1, a.$2);
String? _missed(List<MissedLine> a) => MissedSummaryService.build(a);

Future<String?> buildDailyOffMain(List<DailyLine> lines, DateTime day) =>
    computeIfLarge(lines.length, _daily, (lines, day));
Future<String?> buildWeeklyOffMain(List<WeeklyLine> lines, DateTime end) =>
    computeIfLarge(lines.length, _weekly, (lines, end));
Future<String?> buildMissedOffMain(List<MissedLine> lines) =>
    computeIfLarge(lines.length, _missed, lines);
