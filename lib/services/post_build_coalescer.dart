import 'package:flutter/scheduler.dart';

/// يجمع طلبات «اشتقاق حالة» الصادرة أثناء البناء ويؤجلها لما بعد الإطار.
///
/// استدعاء setState على شاشة أب من داخل builder ابن (مثل StreamBuilder)
/// يرمي «setState() called during build». هذا الصنف يحفظ آخر قيمة طُلبت
/// ويشغّل المعالج مرة واحدة بعد اكتمال الإطار الحالي، فيصبح setState آمناً.
class PostBuildCoalescer<T> {
  PostBuildCoalescer(this._run);

  final void Function(T value) _run;
  T? _pending;
  bool _hasPending = false;
  bool _scheduled = false;
  bool _disposed = false;

  /// هل هناك تشغيل مجدول لم يُنفذ بعد؟ (للاختبارات)
  bool get isScheduled => _scheduled;

  /// يطلب التشغيل بآخر قيمة — طلبات الإطار الواحد تُدمج في تشغيل واحد
  void schedule(T value) {
    if (_disposed) return;
    _pending = value;
    _hasPending = true;
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed || !_hasPending) return;
      final v = _pending as T;
      _pending = null;
      _hasPending = false;
      _run(v);
    });
    // يضمن وجود إطار يُنفذ فيه الاستدعاء حتى لو طُلب خارج البناء
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void dispose() {
    _disposed = true;
    _pending = null;
    _hasPending = false;
  }
}
