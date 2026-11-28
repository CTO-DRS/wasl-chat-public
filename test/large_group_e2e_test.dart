import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasl_chat/services/e2e_service.dart';

/// حالات حدّية لمجموعة كبيرة (300 عضو): لف مفتاح المجموعة لكل عضو وفكه.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final x = X25519();
  final aes = AesGcm.with256bits();
  const conv = 'large-group-1';
  const n = 300;

  late SecretKey gkey;
  late SimpleKeyPair admin;
  late List<SimpleKeyPair> members;
  late List<String> wrapped;

  setUpAll(() async {
    gkey = await aes.newSecretKey();
    admin = await x.newKeyPair();
    members = [for (var i = 0; i < n; i++) await x.newKeyPair()];
    wrapped = [
      for (final m in members)
        await E2eService.wrapGroupKey(
          groupKey: gkey,
          conversationId: conv,
          wrapperPair: admin,
          memberPub: await m.extractPublicKey(),
        ),
    ];
  });

  test('كل الأعضاء الـ300 يفكون الظرف ويحصلون على نفس المفتاح', () async {
    final want = await gkey.extractBytes();
    final adminPub = await admin.extractPublicKey();
    for (var i = 0; i < n; i++) {
      final k = await E2eService.unwrapGroupKey(
          wrapped: wrapped[i], conversationId: conv, myPair: members[i], wrapperPub: adminPub);
      expect(k, isNotNull, reason: 'عضو $i');
      expect(await k!.extractBytes(), want);
    }
  });

  test('الأظرفة فريدة لكل عضو (لا إعادة استخدام nonce أو مفتاح)', () {
    expect(wrapped.toSet().length, n);
    final nonces = wrapped.map((w) => w.split('.')[1]).toSet();
    expect(nonces.length, n);
  });

  test('ظرف عضو لا يفتحه عضو آخر ولا غريب', () async {
    final adminPub = await admin.extractPublicKey();
    for (final i in [0, 1, 149, 299]) {
      final other = members[(i + 1) % n];
      expect(
          await E2eService.unwrapGroupKey(
              wrapped: wrapped[i], conversationId: conv, myPair: other, wrapperPub: adminPub),
          isNull);
    }
    final outsider = await x.newKeyPair();
    expect(
        await E2eService.unwrapGroupKey(
            wrapped: wrapped[0], conversationId: conv, myPair: outsider, wrapperPub: adminPub),
        isNull);
  });

  test('إعادة تشغيل الظرف في مجموعة أخرى تفشل (ربط معرّف المحادثة)', () async {
    final adminPub = await admin.extractPublicKey();
    expect(
        await E2eService.unwrapGroupKey(
            wrapped: wrapped[5], conversationId: 'other-group', myPair: members[5], wrapperPub: adminPub),
        isNull);
  });

  test('ظرف تالف أو مقصوص أو بصيغة خاطئة يعيد null بدون استثناء', () async {
    final adminPub = await admin.extractPublicKey();
    final w = wrapped[7];
    final parts = w.split('.');
    final bad = <String>[
      '',
      'v1.',
      'v1.a.b',
      '${parts[0]}.${parts[1]}.${parts[2]}',
      '${parts[0]}.${parts[1]}.${parts[2]}.AAAA',
      w.substring(0, w.length - 4),
      'plain text, not an envelope',
    ];
    for (final b in bad) {
      expect(
          await E2eService.unwrapGroupKey(
              wrapped: b, conversationId: conv, myPair: members[7], wrapperPub: adminPub),
          isNull,
          reason: b);
    }
  });

  test('مفتاح مدوَّر: الأعضاء المتبقون يفكون الجديد والمُزال لا يفكه', () async {
    final newKey = await aes.newSecretKey();
    final adminPub = await admin.extractPublicKey();
    final removed = members[10];
    // الجديد يُغلَّف لكل الأعضاء ما عدا العضو 10
    final fresh = <int, String>{};
    for (var i = 0; i < n; i++) {
      if (i == 10) continue;
      fresh[i] = await E2eService.wrapGroupKey(
          groupKey: newKey,
          conversationId: conv,
          wrapperPair: admin,
          memberPub: await members[i].extractPublicKey());
    }
    final want = await newKey.extractBytes();
    for (final i in [0, 9, 11, 299]) {
      final k = await E2eService.unwrapGroupKey(
          wrapped: fresh[i]!, conversationId: conv, myPair: members[i], wrapperPub: adminPub);
      expect(await k!.extractBytes(), want);
    }
    // العضو المُزال يحاول فك ظرف عضو آخر بالجديد: يفشل
    expect(
        await E2eService.unwrapGroupKey(
            wrapped: fresh[11]!, conversationId: conv, myPair: removed, wrapperPub: adminPub),
        isNull);
  });
}
