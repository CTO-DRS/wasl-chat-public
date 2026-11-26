/// استخراج إطار من فيديو محلي (2.5.0 — ج5) بتطبيق شرطي:
/// النسخ الأصلية (dart:io) تستخدم واجهات المنصة عبر fc_native_video_thumbnail
/// على أندرويد وiOS حصراً، والويب يأخذ البديل الذي يعيد null دائماً —
/// فيُرسل الفيديو كما كان تماماً بلا أي عطل.
export 'video_thumb_stub.dart' if (dart.library.io) 'video_thumb_io.dart';
