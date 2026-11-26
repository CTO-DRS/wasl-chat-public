// وصل شات: طبقة تجريد مزود الذكاء (0.2.0).
// الإعدادات تُدار من داخل التطبيق: جدول public.ai_settings (هجرة 047) يحدد
// المزود والنموذج والميزات والحدود، ويقرأه هذا الملف عبر دور الخدمة. الأولوية
// للمفتاح المدخل من لوحة الأدمن ثم سر البيئة (GROQ_API_KEY / GEMINI_API_KEY).
// يعود Gemini للعمل فوراً باختيار المسؤول له من لوحة الإعدادات.
export type Turn = { role: "user" | "model"; text: string };

export type AiSettings = {
  provider: "groq" | "gemini";
  chat_model: string;
  stt_model: string;
  feature_chat: boolean;
  feature_translate: boolean;
  feature_summarize: boolean;
  feature_transcribe: boolean;
  feature_moderation: boolean;
  max_input_chars: number;
  groq_api_key: string | null;
  gemini_api_key: string | null;
};

const DEFAULTS: AiSettings = {
  provider: "groq",
  chat_model: "qwen/qwen3.8-27b",
  stt_model: "whisper-large-v3",
  feature_chat: true,
  feature_translate: true,
  feature_summarize: true,
  feature_transcribe: true,
  feature_moderation: true,
  max_input_chars: 8000,
  groq_api_key: null,
  gemini_api_key: null,
};

// ذاكرة مؤقتة قصيرة داخل نسخة الدالة حتى لا نقرأ الجدول مع كل طلب.
let cached: { at: number; value: AiSettings } | null = null;
const CACHE_MS = 30_000;

export async function getAiSettings(): Promise<AiSettings> {
  if (cached && Date.now() - cached.at < CACHE_MS) return cached.value;
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return DEFAULTS;
  try {
    const res = await fetch(`${url}/rest/v1/ai_settings?id=eq.true&select=*`, {
      headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` },
    });
    if (!res.ok) return DEFAULTS;
    const rows = await res.json();
    const row = Array.isArray(rows) ? rows[0] : null;
    const value: AiSettings = row ? { ...DEFAULTS, ...row } : DEFAULTS;
    cached = { at: Date.now(), value };
    return value;
  } catch {
    return DEFAULTS;
  }
}

export async function llmFeatureEnabled(
  feature: "chat" | "translate" | "summarize" | "transcribe" | "moderation",
): Promise<boolean> {
  const s = await getAiSettings();
  return s[`feature_${feature}`] ?? true;
}

export async function llmMaxInputChars(): Promise<number> {
  return (await getAiSettings()).max_input_chars;
}

function groqKey(s: AiSettings): string {
  return s.groq_api_key ?? Deno.env.get("GROQ_API_KEY") ?? "";
}

function geminiKey(s: AiSettings): string {
  return s.gemini_api_key ?? Deno.env.get("GEMINI_API_KEY") ?? "";
}

export async function llmReady(): Promise<boolean> {
  const s = await getAiSettings();
  return s.provider === "gemini" ? !!geminiKey(s) : !!(groqKey(s) || geminiKey(s));
}

async function groqChat(s: AiSettings, system: string, turns: Turn[]): Promise<string> {
  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${groqKey(s)}`,
    },
    body: JSON.stringify({
      model: s.chat_model,
      messages: [
        { role: "system", content: system },
        ...turns.map((t) => ({
          role: t.role === "model" ? "assistant" : "user",
          content: t.text,
        })),
      ],
      temperature: 0.3,
    }),
  });
  if (!res.ok) throw new Error(`groq ${res.status}: ${await res.text()}`);
  const j = await res.json();
  return String(j.choices?.[0]?.message?.content ?? "").trim();
}

async function geminiChat(s: AiSettings, system: string, turns: Turn[]): Promise<string> {
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${s.chat_model}:generateContent`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": geminiKey(s) },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents: turns.map((t) => ({ role: t.role, parts: [{ text: t.text }] })),
      }),
    },
  );
  if (!res.ok) throw new Error(`gemini ${res.status}: ${await res.text()}`);
  const j = await res.json();
  return (j.candidates?.[0]?.content?.parts ?? [])
    .map((p: { text?: string }) => p.text ?? "")
    .join("")
    .trim();
}

export async function llmChat(system: string, turns: Turn[]): Promise<string> {
  const s = await getAiSettings();
  if (s.provider === "gemini" && geminiKey(s)) return await geminiChat(s, system, turns);
  if (groqKey(s)) return await groqChat(s, system, turns);
  if (geminiKey(s)) return await geminiChat(s, system, turns);
  throw new Error("no llm provider configured");
}

function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function groqTranscribe(s: AiSettings, hint: string, audioB64: string, mime: string): Promise<string> {
  const bytes = b64ToBytes(audioB64);
  const ext = mime === "audio/webm" ? "webm" : "m4a";
  const form = new FormData();
  form.append("file", new Blob([bytes], { type: mime }), `voice.${ext}`);
  form.append("model", s.stt_model);
  // Whisper لا يأخذ تعليمات نظام؛ نمرر التلميح كسياق لغوي فقط.
  form.append("prompt", hint.slice(0, 800));
  const res = await fetch("https://api.groq.com/openai/v1/audio/transcriptions", {
    method: "POST",
    headers: { Authorization: `Bearer ${groqKey(s)}` },
    body: form,
  });
  if (!res.ok) throw new Error(`groq-stt ${res.status}: ${await res.text()}`);
  const j = await res.json();
  return String(j.text ?? "").trim();
}

async function geminiTranscribe(s: AiSettings, system: string, audioB64: string, mime: string): Promise<string> {
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${s.chat_model}:generateContent`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": geminiKey(s) },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents: [
          { role: "user", parts: [{ inlineData: { mimeType: mime, data: audioB64 } }] },
        ],
      }),
    },
  );
  if (!res.ok) throw new Error(`gemini ${res.status}: ${await res.text()}`);
  const j = await res.json();
  return (j.candidates?.[0]?.content?.parts ?? [])
    .map((p: { text?: string }) => p.text ?? "")
    .join("")
    .trim();
}

export async function llmTranscribe(system: string, audioB64: string, mime: string): Promise<string> {
  const s = await getAiSettings();
  if (s.provider === "gemini" && geminiKey(s)) return await geminiTranscribe(s, system, audioB64, mime);
  if (groqKey(s)) return await groqTranscribe(s, system, audioB64, mime);
  if (geminiKey(s)) return await geminiTranscribe(s, system, audioB64, mime);
  throw new Error("no stt provider configured");
}
