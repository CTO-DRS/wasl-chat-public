import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/locale_service.dart';
import '../theme.dart';

/// حساب رسمي للمطوّر — مصدر واحد للشاشة والاختبارات.
class DeveloperLink {
  final String id;
  final String labelAr;
  final String labelEn;
  final FaIconData icon;
  final Color color;
  final String url;
  const DeveloperLink(this.id, this.labelAr, this.labelEn, this.icon, this.color, this.url);
  String label(bool ar) => ar ? labelAr : labelEn;
}

const developerName = 'CTO.DRS';
const developerSite = 'https://cto-drs.com';

/// الترتيب والألوان حسب مرجع NeoKey.
const developerLinks = <DeveloperLink>[
  DeveloperLink('whatsapp', 'واتساب', 'WhatsApp', FontAwesomeIcons.whatsapp,
      Color(0xFF25D366), 'https://wa.me/message/MVTVWPOPFOVFF1'),
  DeveloperLink('telegram', 'تيليجرام', 'Telegram', FontAwesomeIcons.telegram,
      Color(0xFF229ED9), 'https://t.me/CTO_DRS'),
  DeveloperLink('tiktok', 'تيك توك', 'TikTok', FontAwesomeIcons.tiktok,
      Color(0xFF111111), 'https://www.tiktok.com/@cto.drs'),
  DeveloperLink('instagram', 'إنستغرام', 'Instagram', FontAwesomeIcons.instagram,
      Color(0xFFE1306C), 'https://www.instagram.com/cto.drs'),
  DeveloperLink('x', 'إكس', 'X', FontAwesomeIcons.xTwitter, Color(0xFF000000),
      'https://x.com/cto_drs'),
  DeveloperLink('youtube', 'يوتيوب', 'YouTube', FontAwesomeIcons.youtube,
      Color(0xFFFF0000), 'https://youtube.com/@cto-drs'),
  DeveloperLink('github', 'GitHub', 'GitHub', FontAwesomeIcons.github,
      Color(0xFF24292F), 'https://github.com/CTO-DRS'),
  DeveloperLink('web', 'الموقع', 'Website', FontAwesomeIcons.globe, Color(0xFF4F46E5),
      developerSite),
];

const _avatarAsset = 'assets/developer/dev-avatar.jpg';

/// شاشة «عن المطوّر» — لوحة زجاجية داكنة بصورة دائرية وشبكة حسابات 4×2.
class AboutDeveloperScreen extends StatelessWidget {
  const AboutDeveloperScreen({super.key});

  static Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  static void _showQr(BuildContext context, DeveloperLink l, bool ar) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (c) => _QrSheet(link: l, ar: ar),
    );
  }

  static void _showPhoto(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (c) => GestureDetector(
        onTap: () => Navigator.of(c).pop(),
        child: Center(
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(_avatarAsset, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = LocaleService.lang.value == 'ar';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? const Color(0xFFDDE1EA) : WaslColors.ink;
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(title: Text(ar ? 'عن المطوّر' : 'About the developer')),
      body: Container(
        decoration: dark
            ? const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF05061A), Color(0xFF0D0A2E)]))
            : null,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(children: [
              Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                      color: const Color(0xFF6D3FC9),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Text(ar ? 'عن المطوّر' : 'About the developer',
                  style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              const Expanded(child: Divider(height: 1, color: Color(0x40A78BFA))),
            ]),
            const SizedBox(height: 16),
            _card(context, ar),
            const SizedBox(height: 28),
            Center(
              child: Text(
                  ar
                      ? 'وصل شات • الإصدار ${AppConfig.appVersion}'
                      : 'Wasl Chat • Version ${AppConfig.appVersion}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, bool ar) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: dark ? const Color(0xB80B0C24) : Colors.white,
        border: GradientBoxBorder.make(),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      child: Stack(clipBehavior: Clip.none, children: [
        // لمعة علوية داخل حدود البطاقة
        Positioned(
          left: -16,
          right: -16,
          top: -16,
          height: 60,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  dark ? const Color(0x1CFFFFFF) : const Color(0x146366F1),
                  Colors.transparent
                ],
              ),
            ),
          ),
        ),
        Column(children: [
          const SizedBox(height: 4),
          _avatar(context),
          const SizedBox(height: 14),
          Text(developerName,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  color: dark ? Colors.white : WaslColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(ar ? 'مطوّر تطبيقات • استشارات تقنية' : 'App developer • Tech consulting',
              style: TextStyle(
                  color: dark ? const Color(0xFFA5B4FC) : WaslColors.indigo, fontSize: 13)),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth / 4;
            return Wrap(runSpacing: 16, children: [
              for (final l in developerLinks)
                SizedBox(width: w, child: _cell(context, l, ar, dark)),
            ]);
          }),
        ]),
      ]),
    );
  }

  Widget _avatar(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('dev-avatar'),
      onTap: () => _showPhoto(context),
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6366F1), Color(0xFF06B6D4), Color(0xFFA855F7)],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF161437)),
              child: const CircleAvatar(radius: 45, backgroundImage: AssetImage(_avatarAsset)),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1D9BF0),
                  border: Border.all(color: const Color(0xFF161437), width: 2)),
              child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _cell(BuildContext context, DeveloperLink l, bool ar, bool dark) {
    return Semantics(
      button: true,
      label: l.label(ar),
      child: InkWell(
        key: ValueKey('dev-link-${l.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showQr(context, l, ar),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: l.color,
              border: Border.all(color: const Color(0x40FFFFFF)),
            ),
            child: Center(child: FaIcon(l.icon, size: 22, color: Colors.white)),
          ),
          const SizedBox(height: 6),
          Text(l.label(ar),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: dark ? const Color(0xFFCBD5E1) : WaslColors.ink2, fontSize: 11)),
        ]),
      ),
    );
  }
}

/// حد متدرّج قطري (~36% شفافية) لبطاقة المطوّر.
class GradientBoxBorder {
  static BoxBorder make() => Border.all(color: const Color(0x5C5558C2), width: 1);
}

/// ورقة QR زجاجية: رمز مولَّد على الجهاز + أزرار «فتح» و«نسخ» متسلسلة.
class _QrSheet extends StatefulWidget {
  final DeveloperLink link;
  final bool ar;
  const _QrSheet({required this.link, required this.ar});

  @override
  State<_QrSheet> createState() => _QrSheetState();
}

class _QrSheetState extends State<_QrSheet> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.link.url));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.link;
    final ar = widget.ar;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0x5C5558C2)),
          // زجاج داكن معتم مع لمعة علوية (الأطراف معتمة كي لا تظهر الشاشة خلفها)
          gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Color(0xFF1C1D3C), Color(0xFF0B0C24)]),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0x40FFFFFF), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: l.color,
                  border: Border.all(color: const Color(0x40FFFFFF))),
              child: Center(child: FaIcon(l.icon, size: 17, color: Colors.white)),
            ),
            const SizedBox(width: 10),
            Text(l.label(ar),
                style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: QrImageView(
                key: const ValueKey('dev-qr'),
                data: l.url,
                size: 200,
                backgroundColor: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(ar ? 'امسح الرمز بكاميرا هاتفك' : 'Scan with your phone camera',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
          const SizedBox(height: 4),
          Text(l.url,
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 12)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('dev-open'),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () async {
                  await AboutDeveloperScreen._open(l.url);
                  if (context.mounted) Navigator.of(context).maybePop();
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(ar ? 'فتح' : 'Open'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('dev-copy'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x40FFFFFF)),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _copy,
                icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 18),
                label: Text(_copied
                    ? (ar ? 'تم النسخ' : 'Copied')
                    : (ar ? 'نسخ' : 'Copy')),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
