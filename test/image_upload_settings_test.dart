import 'package:flutter_test/flutter_test.dart';
import 'package:wasl_chat/services/privacy_service.dart';

void main() {
  tearDown(() => PrivacyService.dataSaver.value = false);

  test('default image upload settings', () {
    PrivacyService.dataSaver.value = false;
    expect(PrivacyService.imageUploadSettings.maxWidth, 1600);
    expect(PrivacyService.imageUploadSettings.quality, 80);
  });

  test('data saver compresses harder', () {
    PrivacyService.dataSaver.value = true;
    final s = PrivacyService.imageUploadSettings;
    expect(s.maxWidth, lessThan(1600));
    expect(s.quality, lessThan(80));
  });
}
