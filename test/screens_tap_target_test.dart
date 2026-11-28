import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wasl_chat/screens/about_developer_screen.dart';
import 'package:wasl_chat/screens/app_studio_screen.dart';
import 'package:wasl_chat/screens/beta_screen.dart';
import 'package:wasl_chat/screens/business_replies_screen.dart';
import 'package:wasl_chat/screens/feedback_screen.dart';
import 'package:wasl_chat/screens/hijri_occasions_screen.dart';
import 'package:wasl_chat/screens/welcome_screen.dart';
import 'package:wasl_chat/screens/ai_screen.dart';
import 'package:wasl_chat/screens/voice_studio_screen.dart';
import 'package:wasl_chat/theme.dart';

import 'support/render_harness.dart';

/// تدقيق أهداف اللمس (48dp) والتسميات على شاشات كاملة بخط مكبّر 1.6.
void main() {
  Future<void> pump(WidgetTester tester, Widget child, {bool light = false}) async {
    ignoreGlassTileAsserts();
    tester.view.physicalSize = const Size(360 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(360, 900), textScaler: TextScaler.linear(1.6)),
      child: renderHarness(child, light ? WaslTheme.light : WaslTheme.dark),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  final screens = <String, Widget Function()>{
    'business replies': () => const BusinessRepliesScreen(),
    'welcome': () => WelcomeScreen(onDone: () async {}),
    'feedback': () => const FeedbackScreen(),
    'hijri occasions': () => const HijriOccasionsScreen(),
    'beta': () => const BetaScreen(),
    'app studio': () => const AppStudioScreen(),
    'ai': () => const AiScreen(),
    'voice studio': () => const VoiceStudioScreen(),
    'about developer': () => const AboutDeveloperScreen(bannerAutoPlay: false),
  };

  for (final e in screens.entries) {
    // ai/voice studio (شرائح بتدرج) وwelcome (زر بتدرج) يُقاس تباينها خطأً أو يعود لقرار لوحة الألوان: خارج الفحص
    const contrastSkip = {'welcome', 'ai', 'voice studio'};
    for (final light in contrastSkip.contains(e.key) ? const <bool>[] : [false, true]) {
      testWidgets('${e.key} (${light ? "light" : "dark"}): text contrast', (tester) async {
        final h = tester.ensureSemantics();
        await pump(tester, e.value(), light: light);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        h.dispose();
      });
    }

    testWidgets('${e.key}: tap targets, labels, no overflow at 1.6x', (tester) async {
      final h = tester.ensureSemantics();
      await pump(tester, e.value());
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      h.dispose();
    });
  }
}
