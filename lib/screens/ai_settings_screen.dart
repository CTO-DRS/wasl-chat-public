import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../theme.dart';
import '../widgets/wasl_sheet.dart';

/// إعدادات الذكاء الاصطناعي (0.2.0) — تُدار من داخل التطبيق للمسؤول فقط.
/// القراءة والكتابة عبر RPCs خادمية (admin_get/update_ai_settings)؛ مفاتيح
/// API البديلة كتابة فقط ولا تُعاد قيمتها أبداً للعميل. دوال Edge تقرأ
/// الجدول مباشرة بدور الخدمة مع ذاكرة مؤقتة قصيرة.
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String _provider = 'groq';
  final _chatModel = TextEditingController();
  final _sttModel = TextEditingController();
  final _maxChars = TextEditingController();
  final _groqKey = TextEditingController();
  final _geminiKey = TextEditingController();
  bool _hasGroqKey = false;
  bool _hasGeminiKey = false;
  final Map<String, bool> _features = {
    'chat': true,
    'translate': true,
    'summarize': true,
    'transcribe': true,
    'moderation': true,
  };

  static const _featureMeta = <String, (String, String, IconData)>{
    'chat': ('محادثة وصل AI', 'المساعد الذكي داخل المحادثات', Icons.smart_toy_rounded),
    'translate': ('الترجمة الفورية', 'ترجمة الرسائل بين اللغات', Icons.translate_rounded),
    'summarize': ('التلخيص', 'تلخيص المحادثات والأسطر', Icons.summarize_rounded),
    'transcribe': ('التفريغ الصوتي', 'تحويل الرسائل الصوتية إلى نص', Icons.mic_rounded),
    'moderation': ('المراقبة الذكية', 'فحص المجتمعات العامة آلياً', Icons.security_rounded),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _chatModel.dispose();
    _sttModel.dispose();
    _maxChars.dispose();
    _groqKey.dispose();
    _geminiKey.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await supabase.rpc('admin_get_ai_settings');
      final m = Map<String, dynamic>.from(r as Map);
      if (!mounted) return;
      setState(() {
        _provider = (m['provider'] ?? 'groq') as String;
        _chatModel.text = (m['chat_model'] ?? '') as String;
        _sttModel.text = (m['stt_model'] ?? '') as String;
        _maxChars.text = '${m['max_input_chars'] ?? 8000}';
        _hasGroqKey = m['has_groq_key_override'] == true;
        _hasGeminiKey = m['has_gemini_key_override'] == true;
        for (final k in _features.keys) {
          _features[k] = m['feature_$k'] != false;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('تعذّر تحميل الإعدادات');
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save({bool clearGroq = false, bool clearGemini = false}) async {
    setState(() => _saving = true);
    try {
      await supabase.rpc('admin_update_ai_settings', params: {
        'p_provider': _provider,
        'p_chat_model': _chatModel.text.trim(),
        'p_stt_model': _sttModel.text.trim(),
        'p_max_input_chars': int.tryParse(_maxChars.text.trim()) ?? 8000,
        for (final k in _features.keys) 'p_feature_$k': _features[k],
        if (_groqKey.text.trim().isNotEmpty) 'p_groq_api_key': _groqKey.text.trim(),
        if (_geminiKey.text.trim().isNotEmpty) 'p_gemini_api_key': _geminiKey.text.trim(),
        'p_clear_groq_key': clearGroq,
        'p_clear_gemini_key': clearGemini,
      });
      _groqKey.clear();
      _geminiKey.clear();
      _snack('حُفظت الإعدادات ✓');
      await _load();
    } catch (_) {
      _snack('تعذّر الحفظ');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label, String hint,
      {bool secret = false, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(WaslSpace.xxl, WaslSpace.sm, WaslSpace.xxl, WaslSpace.sm),
      child: TextField(
        controller: c,
        obscureText: secret,
        keyboardType: keyboard,
        textDirection: secret || keyboard != null ? TextDirection.ltr : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: context.glass,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(WaslRadius.lg), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          ShaderMask(
            shaderCallback: (r) => WaslColors.gradient.createShader(r),
            child: const Icon(Icons.psychology_rounded, color: Colors.white),
          ),
          const SizedBox(width: WaslSpace.sm),
          const Text('إعدادات الذكاء', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(WaslSpace.md, WaslSpace.xs, WaslSpace.md, 40),
              children: [
                const SheetSectionLabel('المزود والنماذج'),
                GlassGroup([
                  Padding(
                    padding: const EdgeInsets.all(WaslSpace.md),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'groq',
                            label: Text('Groq'),
                            icon: Icon(Icons.bolt_rounded)),
                        ButtonSegment(
                            value: 'gemini',
                            label: Text('Gemini'),
                            icon: Icon(Icons.auto_awesome_rounded)),
                      ],
                      selected: {_provider},
                      onSelectionChanged: (s) => setState(() => _provider = s.first),
                    ),
                  ),
                  _field(_chatModel, 'نموذج المحادثة', 'qwen/qwen3.8-27b'),
                  _field(_sttModel, 'نموذج التفريغ الصوتي', 'whisper-large-v3'),
                  _field(_maxChars, 'الحد الأقصى لطول الإدخال (حرف)', '8000',
                      keyboard: TextInputType.number),
                ]),
                const SheetSectionLabel('الميزات'),
                GlassGroup([
                  for (final e in _featureMeta.entries)
                    SwitchListTile(
                      secondary: Icon(e.value.$3, color: WaslColors.teal),
                      title: Text(e.value.$1,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(e.value.$2,
                          style: TextStyle(color: context.textFaint, fontSize: WaslFont.meta)),
                      value: _features[e.key] ?? true,
                      onChanged: (v) => setState(() => _features[e.key] = v),
                    ),
                ]),
                const SheetSectionLabel('مفاتيح API البديلة'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(WaslSpace.xxl, 0, WaslSpace.xxl, WaslSpace.sm),
                  child: Text(
                    'المفاتيح الأساسية محفوظة في أسرار الخادم. أدخل مفتاحاً هنا لتجاوزه، ولا تُعرض قيمته مرة أخرى.',
                    style: TextStyle(color: context.textFaint, fontSize: WaslFont.meta),
                  ),
                ),
                GlassGroup([
                  _field(_groqKey, 'مفتاح Groq بديل', _hasGroqKey ? 'مضبوط ✓ — أدخل قيمة للاستبدال' : 'غير مضبوط',
                      secret: true),
                  _field(_geminiKey, 'مفتاح Gemini بديل',
                      _hasGeminiKey ? 'مضبوط ✓ — أدخل قيمة للاستبدال' : 'غير مضبوط',
                      secret: true),
                  if (_hasGroqKey || _hasGeminiKey)
                    SheetTile(
                      icon: Icons.key_off_rounded,
                      danger: true,
                      color: WaslColors.danger,
                      title: 'مسح المفاتيح البديلة',
                      subtitle: 'العودة إلى أسرار الخادم فقط',
                      onTap: () => _save(clearGroq: true, clearGemini: true),
                    ),
                ]),
                const SizedBox(height: WaslSpace.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: WaslSpace.xxl),
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _save(),
                    icon: _saving
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ الإعدادات'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(WaslRadius.lg)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
