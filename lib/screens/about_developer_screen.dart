import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/locale_service.dart';
import '../theme.dart';

/// روابط المطوّر الرسمية — مصدر واحد للشاشة والاختبارات.
class DeveloperLink {
  final String id;
  final String label;
  final IconData icon;
  final String url;
  const DeveloperLink(this.id, this.label, this.icon, this.url);
}

const developerName = 'CTO: DRS';
const developerSite = 'https://cto-drs.com';

const developerLinks = <DeveloperLink>[
  DeveloperLink('web', 'cto-drs.com', Icons.language_rounded, developerSite),
  DeveloperLink('github', 'GitHub', Icons.code_rounded, 'https://github.com/CTO-DRS'),
  DeveloperLink('x', 'X', Icons.alternate_email_rounded, 'https://x.com/cto_drs'),
  DeveloperLink('instagram', 'Instagram', Icons.photo_camera_rounded,
      'https://www.instagram.com/cto.drs'),
  DeveloperLink('tiktok', 'TikTok', Icons.music_note_rounded, 'https://www.tiktok.com/@cto.drs'),
  DeveloperLink('youtube', 'YouTube', Icons.play_circle_rounded, 'https://youtube.com/@cto-drs'),
  DeveloperLink('telegram', 'Telegram', Icons.send_rounded, 'https://t.me/CTO_DRS'),
  DeveloperLink('whatsapp', 'WhatsApp Business', Icons.chat_rounded,
      'https://wa.me/message/MVTVWPOPFOVFF1'),
];

/// شاشة «عن المطوّر» — بطاقة أنيقة بصورة دائرية وصف أيقونات الروابط.
class AboutDeveloperScreen extends StatelessWidget {
  const AboutDeveloperScreen({super.key});

  static Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final ar = LocaleService.lang.value == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'عن المطوّر' : 'About the developer')),
      body: ListView(
        padding: const EdgeInsets.all(WaslSpace.xxl),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(WaslSpace.xxl, 28, WaslSpace.xxl, WaslSpace.xxl),
            decoration: BoxDecoration(
              color: context.glass,
              borderRadius: BorderRadius.circular(WaslRadius.xl),
              border: Border.all(color: context.hairline.withValues(alpha: 0.5)),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    shape: BoxShape.circle, gradient: WaslColors.gradient),
                child: Semantics(
                  label: developerName,
                  image: true,
                  child: const CircleAvatar(
                    radius: 54,
                    backgroundImage: AssetImage('assets/developer/dev-avatar.jpg'),
                  ),
                ),
              ),
              const SizedBox(height: WaslSpace.lg),
              Text(developerName,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                      fontSize: WaslFont.titleLarge,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary)),
              const SizedBox(height: WaslSpace.xs),
              Text(ar ? 'تطوير CTO: DRS' : 'Developed by CTO: DRS',
                  style: TextStyle(fontSize: WaslFont.body, color: context.textSecondary)),
              const SizedBox(height: WaslSpace.xl),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: WaslSpace.md,
                runSpacing: WaslSpace.md,
                children: [
                  for (final l in developerLinks)
                    Tooltip(
                      message: l.label,
                      child: Semantics(
                        button: true,
                        label: l.label,
                        child: InkResponse(
                          key: ValueKey('dev-link-${l.id}'),
                          onTap: () => _open(l.url),
                          radius: 28,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: WaslColors.indigo.withValues(alpha: 0.14),
                            ),
                            child: Icon(l.icon, size: 22, color: WaslColors.teal),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
