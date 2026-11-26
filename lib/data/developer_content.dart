import 'package:material_ui/material_ui.dart';

/// نص بثلاث لغات؛ العربية هي الأصل وتُستعمل عند غياب اللغة.
class L3 {
  final String ar;
  final String en;
  final String fr;
  const L3(this.ar, this.en, this.fr);
  String of(String lang) => switch (lang) {
        'en' => en,
        'fr' => fr,
        _ => ar,
      };
}

/// إعلان في شريط اللافتات أعلى بطاقة المطوّر.
///
/// **للتحديث:** عدّل القائمة [developerBanners] أدناه فقط (أضف عنصراً أو احذفه
/// أو بدّل النص)؛ الشريط يتكيّف تلقائياً (نقاط المؤشر، التمرير الآلي، النقر).
/// [url] اختياري: إن وُجد فالنقر على اللافتة يفتحه.
class DeveloperBanner {
  final String id;
  final L3 title;
  final L3 subtitle;
  final IconData icon;
  final List<Color> colors;
  final String? url;
  const DeveloperBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    this.url,
  });
}

const developerBanners = <DeveloperBanner>[
  DeveloperBanner(
    id: 'wasl-chat',
    title: L3('وصل شات', 'Wasl Chat', 'Wasl Chat'),
    subtitle: L3('مراسلة عربية أولاً، بخصوصية حقيقية وتشفير طرف لطرف',
        'Arabic-first messaging with real privacy and end-to-end encryption',
        'Messagerie arabe d\'abord, vraie confidentialité et chiffrement de bout en bout'),
    icon: Icons.chat_bubble_rounded,
    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
    url: 'https://cto-drs.com',
  ),
  DeveloperBanner(
    id: 'new-apps',
    title: L3('تطبيقات جديدة قادمة', 'New apps coming soon', 'De nouvelles apps arrivent'),
    subtitle: L3('تابع الحسابات الرسمية ليصلك كل إطلاق أولاً بأول',
        'Follow the official accounts to hear about every launch first',
        'Suivez les comptes officiels pour chaque lancement'),
    icon: Icons.rocket_launch_rounded,
    colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
  ),
  DeveloperBanner(
    id: 'consulting',
    title: L3('استشارات تقنية', 'Tech consulting', 'Conseil technique'),
    subtitle: L3('فكرة تطبيق أو منتج؟ راسلني على واتساب للأعمال',
        'Have an app or product idea? Message me on WhatsApp Business',
        'Une idée d\'app ou de produit ? Écrivez-moi sur WhatsApp Business'),
    icon: Icons.lightbulb_rounded,
    colors: [Color(0xFF0F766E), Color(0xFF22C55E)],
    url: 'https://wa.me/message/MVTVWPOPFOVFF1',
  ),
];

/// صفحة الإصدارات العامة: مصدر التحديث ورابط تحميل التطبيق.
const developerReleasesUrl = 'https://github.com/CTO-DRS/wasl-chat-public/releases';
const developerReleasesLatestApi =
    'https://api.github.com/repos/CTO-DRS/wasl-chat-public/releases/latest';

String appShareMessage(String lang) => switch (lang) {
      'en' => 'Try Wasl Chat, an Arabic-first private messenger. Download it here:\n$developerReleasesUrl',
      'fr' => 'Essayez Wasl Chat, une messagerie privée arabe d\'abord. Téléchargez-la ici :\n$developerReleasesUrl',
      _ => 'جرّب «وصل شات»، تطبيق مراسلة عربي بخصوصية حقيقية. حمّله من هنا:\n$developerReleasesUrl',
    };
