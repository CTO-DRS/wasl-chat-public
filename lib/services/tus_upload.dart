import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// فشل في بروتوكول TUS لا يُرجى منه استئناف (يُستعمل للرجوع للرفع العادي).
class TusUnsupported implements Exception {
  TusUnsupported(this.message);
  final String message;
  @override
  String toString() => 'TusUnsupported: $message';
}

/// رفع قابل للاستئناف بالبايت (بروتوكول TUS 1.0.0) إلى نقطة Supabase.
/// يرفع على أجزاء 6 م.ب (الحجم المطلوب في Supabase). عند انقطاع جزء يسأل
/// الخادم عن الإزاحة المستلمة (HEAD) ويكمل من هناك بدل البدء من الصفر.
class TusUploader {
  TusUploader({
    required this.endpoint,
    required this.headers,
    http.Client? client,
    this.chunkSize = 6 * 1024 * 1024,
    this.maxResumes = 5,
    this.onProgress,
  }) : _client = client ?? http.Client();

  final String endpoint;
  final Map<String, String> headers;
  final int chunkSize;
  final int maxResumes;
  final void Function(int sent, int total)? onProgress;
  final http.Client _client;

  static const _tus = {'Tus-Resumable': '1.0.0'};

  static String metadata(Map<String, String> m) => m.entries
      .map((e) => '${e.key} ${base64.encode(utf8.encode(e.value))}')
      .join(',');

  Future<void> upload({
    required String bucket,
    required String path,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final create = await _client.post(Uri.parse(endpoint), headers: {
      ...headers,
      ..._tus,
      'Upload-Length': '${bytes.length}',
      'Upload-Metadata': metadata({
        'bucketName': bucket,
        'objectName': path,
        'contentType': contentType,
        'cacheControl': '3600',
      }),
      'x-upsert': 'false',
    });
    if (create.statusCode == 404 || create.statusCode == 405 ||
        create.statusCode == 501) {
      throw TusUnsupported('create ${create.statusCode}');
    }
    if (create.statusCode != 201) {
      throw http.ClientException(
          'tus create failed ${create.statusCode}: ${create.body}');
    }
    final loc = create.headers['location'];
    if (loc == null) throw TusUnsupported('no location');
    final url = Uri.parse(endpoint).resolve(loc);

    var offset = 0;
    var resumes = 0;
    while (offset < bytes.length) {
      final end = (offset + chunkSize).clamp(0, bytes.length);
      try {
        final r = await _client.patch(url,
            headers: {
              ...headers,
              ..._tus,
              'Content-Type': 'application/offset+octet-stream',
              'Upload-Offset': '$offset',
            },
            body: Uint8List.sublistView(bytes, offset, end));
        if (r.statusCode != 204 && r.statusCode != 200) {
          throw http.ClientException('tus patch ${r.statusCode}');
        }
        offset = int.tryParse(r.headers['upload-offset'] ?? '') ?? end;
        onProgress?.call(offset, bytes.length);
      } catch (e) {
        if (++resumes > maxResumes) rethrow;
        offset = await _serverOffset(url, fallback: offset);
      }
    }
  }

  Future<int> _serverOffset(Uri url, {required int fallback}) async {
    try {
      final h = await _client.head(url, headers: {...headers, ..._tus});
      return int.tryParse(h.headers['upload-offset'] ?? '') ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
