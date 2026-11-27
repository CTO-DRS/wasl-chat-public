import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wasl_chat/services/tus_upload.dart';

void main() {
  test('metadata is base64 encoded', () {
    expect(TusUploader.metadata({'a': 'x'}), 'a ${base64.encode(utf8.encode('x'))}');
  });

  test('uploads in chunks and resumes from server offset after a failure', () async {
    final bytes = Uint8List.fromList(List.generate(25, (i) => i));
    var stored = 0;
    var failed = false;
    var heads = 0;
    final client = MockClient((req) async {
      if (req.method == 'POST') {
        expect(req.headers['Upload-Length'], '25');
        return http.Response('', 201, headers: {'location': '/u/1'});
      }
      if (req.method == 'PATCH') {
        final off = int.parse(req.headers['Upload-Offset']!);
        expect(off, stored);
        if (off == 10 && !failed) {
          failed = true;
          stored = 15; // الخادم استلم جزءاً قبل الانقطاع
          throw http.ClientException('drop');
        }
        stored = off + req.bodyBytes.length;
        return http.Response('', 204, headers: {'upload-offset': '$stored'});
      }
      heads++;
      return http.Response('', 200, headers: {'upload-offset': '$stored'});
    });
    final progress = <int>[];
    await TusUploader(
      endpoint: 'https://x.test/storage/v1/upload/resumable',
      headers: {},
      client: client,
      chunkSize: 10,
      onProgress: (s, t) => progress.add(s),
    ).upload(bucket: 'b', path: 'p', contentType: 'image/png', bytes: bytes);
    expect(stored, 25);
    expect(heads, 1);
    expect(progress.last, 25);
  });

  test('404 on create means unsupported (caller falls back)', () async {
    final client = MockClient((_) async => http.Response('', 404));
    expect(
        TusUploader(endpoint: 'https://x.test/r', headers: {}, client: client)
            .upload(bucket: 'b', path: 'p', contentType: 'a', bytes: Uint8List(3)),
        throwsA(isA<TusUnsupported>()));
  });

  test('gives up after maxResumes', () async {
    final client = MockClient((req) async {
      if (req.method == 'POST') return http.Response('', 201, headers: {'location': '/u'});
      if (req.method == 'HEAD') return http.Response('', 200, headers: {'upload-offset': '0'});
      throw http.ClientException('down');
    });
    expect(
        TusUploader(endpoint: 'https://x.test/r', headers: {}, client: client, maxResumes: 2)
            .upload(bucket: 'b', path: 'p', contentType: 'a', bytes: Uint8List(3)),
        throwsA(isA<http.ClientException>()));
  });
}
