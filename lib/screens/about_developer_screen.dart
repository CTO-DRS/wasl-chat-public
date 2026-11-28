import 'dart:math' as math;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/developer_content.dart';
import '../services/developer_update_service.dart';
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
  String labelFor(String lang) =>
      lang == 'ar' ? labelAr : (lang == 'fr' && id == 'web' ? 'Site web' : labelEn);
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

/// نقطة حقن للاختبار: تنفيذ المشاركة الفعلي عبر ورقة النظام.
Future<void> Function(ShareParams) developerShare =
    (p) async => SharePlus.instance.share(p);

/// يرسم رمز QR صورة PNG على الجهاز (بلا شبكة): خلفية بيضاء وهامش هادئ.
Future<Uint8List> renderQrPng(String data, {double size = 1024}) async {
  final painter = QrPainter(
    data: data,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
    dataModuleStyle:
        const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
    gapless: true,
  );
  final inner = await painter.toImageData(size - 128, format: ui.ImageByteFormat.png);
  final codec = await ui.instantiateImageCodec(inner!.buffer.asUint8List());
  final img = (await codec.getNextFrame()).image;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(Rect.fromLTWH(0, 0, size, size), Paint()..color = Colors.white);
  canvas.drawImage(img, const Offset(64, 64), Paint());
  final out = await rec.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

const _avatarAsset = 'assets/developer/dev-avatar.jpg';

/// شاشة «عن المطوّر» — لوحة زجاجية داكنة بصورة دائرية وشبكة حسابات 4×2.
class AboutDeveloperScreen extends StatelessWidget {
  /// يُعطَّل في الاختبارات كي لا يبقى مؤقّت معلّقاً.
  final bool bannerAutoPlay;
  const AboutDeveloperScreen({super.key, this.bannerAutoPlay = true});

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
    final lang = LocaleService.lang.value;
    final ar = lang == 'ar';
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
            _BannerCarousel(autoPlay: bannerAutoPlay, lang: lang),
            const SizedBox(height: 16),
            _card(context, ar),
            const SizedBox(height: 16),
            _actions(context, lang),
            const SizedBox(height: 12),
            _UpdateCard(lang: lang),
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

  static String allAccountsMessage(String lang) {
    final head = L3('حسابات المطوّر CTO.DRS الرسمية:', 'Official accounts of CTO.DRS:',
            'Comptes officiels de CTO.DRS :')
        .of(lang);
    return '$head\n${developerLinks.map((l) => '${l.labelFor(lang)}: ${l.url}').join('\n')}';
  }

  Widget _actions(BuildContext context, String lang) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget btn(String key, IconData icon, L3 text, Future<void> Function() onTap) => Expanded(
          child: OutlinedButton.icon(
            key: ValueKey(key),
            style: OutlinedButton.styleFrom(
                foregroundColor: dark ? Colors.white : WaslColors.ink,
                backgroundColor: dark ? const Color(0xB80B0C24) : Colors.white,
                side: const BorderSide(color: Color(0x5C5558C2)),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: FittedBox(fit: BoxFit.scaleDown, child: Text(text.of(lang), maxLines: 1)),
          ),
        );
    return Row(children: [
      btn('dev-share-app', Icons.ios_share_rounded,
          const L3('شارك التطبيق', 'Share the app', 'Partager l\'app'),
          () => developerShare(ShareParams(
              text: appShareMessage(lang), subject: lang == 'ar' ? 'وصل شات' : 'Wasl Chat'))),
      const SizedBox(width: 10),
      btn('dev-share-all', Icons.share_rounded,
          const L3('شارك الحسابات', 'Share all accounts', 'Partager les comptes'),
          () => developerShare(ShareParams(text: allAccountsMessage(lang), subject: developerName))),
    ]);
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
    return Semantics(
      button: true,
      label: 'صورة المطوّر، اضغط للتكبير',
      excludeSemantics: true,
      child: GestureDetector(
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
    ));
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

  Future<void> _shareLink() async {
    final l = widget.link;
    await developerShare(ShareParams(
        text: '${l.label(widget.ar)}: ${l.url}', subject: developerName));
  }

  Future<void> _shareQr() async {
    final l = widget.link;
    final png = await renderQrPng(l.url);
    await developerShare(ShareParams(
      text: l.url,
      subject: developerName,
      files: [XFile.fromData(png, mimeType: 'image/png', name: 'cto-drs-${l.id}-qr.png')],
      fileNameOverrides: ['cto-drs-${l.id}-qr.png'],
    ));
  }

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
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('dev-share-link'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x40FFFFFF)),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _shareLink,
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(ar ? 'مشاركة الرابط' : 'Share link'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('dev-share-qr'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x40FFFFFF)),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _shareQr,
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: Text(ar ? 'مشاركة الرمز' : 'Share QR'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// شريط لافتات متحرك أعلى البطاقة: محتواه من [developerBanners].
class _BannerCarousel extends StatefulWidget {
  final bool autoPlay;
  final String lang;
  const _BannerCarousel({required this.autoPlay, required this.lang});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay && developerBanners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_controller.hasClients) return;
        _controller.animateToPage((_page + 1) % developerBanners.length,
            duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (developerBanners.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      SizedBox(
        // يكبر مع حجم الخط (خط النظام المكبّر كان يقص النص)
        height: math.max(112, 36 + MediaQuery.textScalerOf(context).scale(62)),
        child: PageView.builder(
          key: const ValueKey('dev-banners'),
          controller: _controller,
          itemCount: developerBanners.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (c, i) {
            final b = developerBanners[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: b.url == null ? null : () => AboutDeveloperScreen._open(b.url!),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                        begin: Alignment.topRight, end: Alignment.bottomLeft, colors: b.colors),
                    border: Border.all(color: const Color(0x40FFFFFF)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Color(0x33FFFFFF)),
                      child: Icon(b.icon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.title.of(widget.lang),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(b.subtitle.of(widget.lang),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Color(0xE6FFFFFF), fontSize: 12.5, height: 1.35)),
                          ]),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      if (developerBanners.length > 1) ...[
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < developerBanners.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _page ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i == _page
                      ? const Color(0xFF6366F1)
                      : (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0x40FFFFFF)
                          : const Color(0x336366F1))),
            ),
        ]),
      ],
    ]);
  }
}

/// الإصدار الحالي + زر «التحقق من التحديثات» (مصدر: صفحة الإصدارات العامة).
class _UpdateCard extends StatefulWidget {
  final String lang;
  const _UpdateCard({required this.lang});

  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
  bool _busy = false;
  UpdateResult? _result;

  Future<void> _check() async {
    setState(() => _busy = true);
    final r = await DeveloperUpdateService.check();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = r;
    });
  }

  String _status() {
    final r = _result;
    if (r == null) return '';
    final lang = widget.lang;
    return switch (r.outcome) {
      UpdateOutcome.upToDate => const L3('أنت على أحدث إصدار', 'You are up to date',
              'Vous êtes à jour')
          .of(lang),
      UpdateOutcome.available => L3('إصدار جديد ${r.latest} متاح', 'New version ${r.latest} available',
              'Nouvelle version ${r.latest} disponible')
          .of(lang),
      UpdateOutcome.noReleases => const L3('لا توجد إصدارات منشورة بعد',
              'No releases published yet', 'Aucune version publiée pour l\'instant')
          .of(lang),
      UpdateOutcome.failed => const L3('تعذّر الفحص، تحقق من الاتصال',
              'Could not check, check your connection', 'Vérification impossible, vérifiez la connexion')
          .of(lang),
    };
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final r = _result;
    final available = r?.outcome == UpdateOutcome.available;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : WaslColors.ink;
    final sub = dark ? const Color(0xFFCBD5E1) : WaslColors.ink2;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: dark ? const Color(0xB80B0C24) : Colors.white,
        border: Border.all(color: const Color(0x5C5558C2)),
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.system_update_alt_rounded, color: Color(0xFFA5B4FC), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  L3('الإصدار ${AppConfig.appVersion} (${AppConfig.appBuild})',
                          'Version ${AppConfig.appVersion} (${AppConfig.appBuild})',
                          'Version ${AppConfig.appVersion} (${AppConfig.appBuild})')
                      .of(lang),
                  key: const ValueKey('dev-version'),
                  style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w700)),
              if (r != null) ...[
                const SizedBox(height: 2),
                Text(_status(),
                    key: const ValueKey('dev-update-status'),
                    style: TextStyle(
                        color: available ? const Color(0xFF16A34A) : sub,
                        fontSize: 12)),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton(
              key: const ValueKey('dev-check-update'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: _busy ? null : _check,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(const L3('فحص التحديثات', 'Check for updates',
                          'Rechercher des mises à jour')
                      .of(lang)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('dev-open-releases'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: fg,
                  side: BorderSide(
                      color: available ? const Color(0xFF16A34A) : const Color(0x40A78BFA)),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () => AboutDeveloperScreen._open(
                  available ? '$developerReleasesUrl/latest' : developerReleasesUrl),
              child: Text(available
                  ? const L3('تحميل الآن', 'Download now', 'Télécharger').of(lang)
                  : const L3('صفحة الإصدارات', 'Releases page', 'Page des versions').of(lang)),
            ),
          ),
        ]),
      ]),
    );
  }
}
