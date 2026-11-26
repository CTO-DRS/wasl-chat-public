import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../data/developer_content.dart';

enum UpdateOutcome { upToDate, available, noReleases, failed }

class UpdateResult {
  final UpdateOutcome outcome;
  final String? latest;
  const UpdateResult(this.outcome, [this.latest]);
}

/// يقارن إصدارين دلاليين «x.y.z» (يتجاهل بادئة v وأي لاحقة +build/-pre).
/// يعيد موجباً إن كان [a] أحدث من [b].
int compareVersions(String a, String b) {
  List<int> parse(String v) {
    final core = v.trim().replaceFirst(RegExp(r'^[vV]'), '').split(RegExp(r'[+\-]')).first;
    final p = core.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (p.length < 3) {
      p.add(0);
    }
    return p;
  }

  final x = parse(a), y = parse(b);
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return 0;
}

/// فحص التحديث من صفحة الإصدارات العامة (GitHub Releases) بلا حساب ولا مفاتيح.
class DeveloperUpdateService {
  /// يمكن حقنه في الاختبارات.
  static Future<http.Response> Function(Uri) fetch =
      (u) => http.get(u, headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 10));

  static Future<UpdateResult> check({String current = AppConfig.appVersion}) async {
    try {
      final r = await fetch(Uri.parse(developerReleasesLatestApi));
      if (r.statusCode == 404) return const UpdateResult(UpdateOutcome.noReleases);
      if (r.statusCode != 200) return const UpdateResult(UpdateOutcome.failed);
      final tag = (jsonDecode(r.body) as Map)['tag_name'] as String? ?? '';
      if (tag.isEmpty) return const UpdateResult(UpdateOutcome.failed);
      return compareVersions(tag, current) > 0
          ? UpdateResult(UpdateOutcome.available, tag.replaceFirst(RegExp(r'^[vV]'), ''))
          : UpdateResult(UpdateOutcome.upToDate, tag.replaceFirst(RegExp(r'^[vV]'), ''));
    } catch (_) {
      return const UpdateResult(UpdateOutcome.failed);
    }
  }
}
