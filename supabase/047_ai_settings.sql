-- 047: AI provider settings — administrable from inside the app (admin panel).
-- The edge functions (ai, moderation-ai) read this table via the service role;
-- app admins read/update it through security definer RPCs. API key overrides
-- are write-only from the client: the RPCs never return their values.

create table if not exists public.ai_settings (
  id boolean primary key default true check (id),
  provider text not null default 'groq' check (provider in ('groq','gemini')),
  chat_model text not null default 'qwen/qwen3.8-27b',
  stt_model text not null default 'whisper-large-v3',
  feature_chat boolean not null default true,
  feature_translate boolean not null default true,
  feature_summarize boolean not null default true,
  feature_transcribe boolean not null default true,
  feature_moderation boolean not null default true,
  max_input_chars integer not null default 8000 check (max_input_chars between 100 and 100000),
  groq_api_key text,
  gemini_api_key text,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

alter table public.ai_settings enable row level security;
-- no client policies: service role (edge functions) bypasses RLS;
-- app admins go through the RPCs below.

insert into public.ai_settings (id) values (true) on conflict do nothing;

create or replace function public.admin_get_ai_settings()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r public.ai_settings%rowtype;
begin
  if not public.is_app_admin() then raise exception 'forbidden'; end if;
  select * into r from public.ai_settings where id limit 1;
  return jsonb_build_object(
    'provider', r.provider,
    'chat_model', r.chat_model,
    'stt_model', r.stt_model,
    'feature_chat', r.feature_chat,
    'feature_translate', r.feature_translate,
    'feature_summarize', r.feature_summarize,
    'feature_transcribe', r.feature_transcribe,
    'feature_moderation', r.feature_moderation,
    'max_input_chars', r.max_input_chars,
    'has_groq_key_override', r.groq_api_key is not null,
    'has_gemini_key_override', r.gemini_api_key is not null,
    'updated_at', r.updated_at
  );
end;
$$;

create or replace function public.admin_update_ai_settings(
  p_provider text default null,
  p_chat_model text default null,
  p_stt_model text default null,
  p_feature_chat boolean default null,
  p_feature_translate boolean default null,
  p_feature_summarize boolean default null,
  p_feature_transcribe boolean default null,
  p_feature_moderation boolean default null,
  p_max_input_chars integer default null,
  p_groq_api_key text default null,
  p_gemini_api_key text default null,
  p_clear_groq_key boolean default false,
  p_clear_gemini_key boolean default false
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_app_admin() then raise exception 'forbidden'; end if;
  update public.ai_settings set
    provider = coalesce(p_provider, provider),
    chat_model = coalesce(nullif(trim(p_chat_model), ''), chat_model),
    stt_model = coalesce(nullif(trim(p_stt_model), ''), stt_model),
    feature_chat = coalesce(p_feature_chat, feature_chat),
    feature_translate = coalesce(p_feature_translate, feature_translate),
    feature_summarize = coalesce(p_feature_summarize, feature_summarize),
    feature_transcribe = coalesce(p_feature_transcribe, feature_transcribe),
    feature_moderation = coalesce(p_feature_moderation, feature_moderation),
    max_input_chars = coalesce(p_max_input_chars, max_input_chars),
    groq_api_key = case when p_clear_groq_key then null
                        when p_groq_api_key is not null and trim(p_groq_api_key) <> '' then trim(p_groq_api_key)
                        else groq_api_key end,
    gemini_api_key = case when p_clear_gemini_key then null
                          when p_gemini_api_key is not null and trim(p_gemini_api_key) <> '' then trim(p_gemini_api_key)
                          else gemini_api_key end,
    updated_by = auth.uid(),
    updated_at = now()
  where id;
end;
$$;

grant execute on function public.admin_get_ai_settings() to authenticated;
grant execute on function public.admin_update_ai_settings(text,text,text,boolean,boolean,boolean,boolean,boolean,integer,text,text,boolean,boolean) to authenticated;
