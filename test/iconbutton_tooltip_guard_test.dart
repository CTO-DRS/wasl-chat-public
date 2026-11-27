import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// حارس وصول: كل IconButton في lib/ يحمل tooltip (هو اسمه لقارئ الشاشة).
void main() {
  test('every IconButton in lib/ has a tooltip', () {
    final bad = <String>[];
    final re = RegExp(r'IconButton(\.(filled|filledTonal|outlined))?\(');
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final s = f.readAsStringSync();
      for (final m in re.allMatches(s)) {
        var i = m.end, d = 1;
        while (d > 0 && i < s.length) {
          if (s[i] == '(') d++;
          if (s[i] == ')') d--;
          i++;
        }
        final body = s.substring(m.start, i);
        if (!body.contains('tooltip')) {
          bad.add('${f.path}:${'\n'.allMatches(s.substring(0, m.start)).length + 1}');
        }
      }
    }
    expect(bad, isEmpty, reason: 'IconButton بلا tooltip: $bad');
  });
}
