import 'package:flutter_test/flutter_test.dart';
import 'package:wasl_chat/services/retry.dart';

void main() {
  Future<void> noSleep(Duration _) async {}

  test('ينجح من المحاولة الثانية بعد فشل عابر', () async {
    var calls = 0;
    final waited = <Duration>[];
    final r = await retryWithBackoff<String>((i) async {
      calls++;
      if (i == 0) throw Exception('SocketException: connection reset');
      return 'ok';
    }, sleep: (d) async => waited.add(d));
    expect(r, 'ok');
    expect(calls, 2);
    expect(waited, [const Duration(seconds: 1)]);
  });

  test('يتراجع تصاعدياً ثم يرمي آخر خطأ بعد استنفاد المحاولات', () async {
    var calls = 0;
    final waited = <Duration>[];
    await expectLater(
        retryWithBackoff<void>((_) async {
          calls++;
          throw Exception('timeout $calls');
        }, sleep: (d) async => waited.add(d)),
        throwsA(predicate((e) => e.toString().contains('timeout 3'))));
    expect(calls, 3);
    expect(waited, [const Duration(seconds: 1), const Duration(seconds: 3)]);
  });

  test('الفشل الدائم لا يعاد ويرمى فوراً', () async {
    var calls = 0;
    await expectLater(
        retryWithBackoff<void>((_) async {
          calls++;
          throw Exception('new row violates row-level security policy');
        }, shouldRetry: isTransientUploadError, sleep: noSleep),
        throwsException);
    expect(calls, 1);
  });

  test('تصنيف الأخطاء: الحجم والصلاحيات دائمة، الشبكة عابرة', () {
    expect(isTransientUploadError(Exception('The object exceeded the maximum allowed size')), isFalse);
    expect(isTransientUploadError(Exception('HTTP 413')), isFalse);
    expect(isTransientUploadError(Exception('403 forbidden')), isFalse);
    expect(isTransientUploadError(Exception('SocketException: Failed host lookup')), isTrue);
    expect(isTransientUploadError(Exception('Connection timed out')), isTrue);
  });
}
