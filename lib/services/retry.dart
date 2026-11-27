/// إعادة محاولة بتراجع تصاعدي للعمليات العابرة (انقطاع شبكة أثناء رفع).
/// [shouldRetry] يفرّق الفشل العابر عن الدائم (مثل رفض السياسة أو تجاوز الحجم).
Future<T> retryWithBackoff<T>(
  Future<T> Function(int attempt) run, {
  int attempts = 3,
  List<Duration> delays = const [Duration(seconds: 1), Duration(seconds: 3)],
  bool Function(Object error)? shouldRetry,
  Future<void> Function(Duration)? sleep,
}) async {
  final wait = sleep ?? (d) => Future<void>.delayed(d);
  Object? last;
  for (var i = 0; i < attempts; i++) {
    try {
      return await run(i);
    } catch (e) {
      last = e;
      final more = i < attempts - 1;
      if (!more || (shouldRetry != null && !shouldRetry(e))) rethrow;
      await wait(delays[i < delays.length ? i : delays.length - 1]);
    }
  }
  throw last!;
}

/// فشل دائم لا تفيد فيه الإعادة: حجم أكبر من الحد، أو رفض صلاحية/سياسة.
bool isTransientUploadError(Object e) {
  final s = e.toString().toLowerCase();
  const permanent = [
    'exceeded the maximum allowed size',
    'payload too large',
    '413',
    'row-level security',
    'unauthorized',
    '401',
    '403',
    'mime type',
    'invalid',
  ];
  return !permanent.any(s.contains);
}
