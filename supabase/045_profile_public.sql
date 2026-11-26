-- 044: الملف العام للويب + خلفية الملف الشخصي (2.0.2)
-- 1) حقل الخلفية: صورة عريضة تظهر أعلى بطاقة الرابط العام waslchat.app/@user
alter table public.profiles add column if not exists cover_url text;

-- 2) نسخة عامة آمنة من جلب الملف بالاسم — تستدعيها بطاقة الويب كزائر مجهول.
--    تعيد فقط ما يظهر للعالم (الاسم والصورة والخلفية والنبذة) — بلا id ولا
--    أي حقول أخرى. إن حُرّكت بيانات الدالة لاحقاً فالحد هنا هو الضمانة.
create or replace function public.profile_public_by_username(p_username text)
returns table (username text, display_name text, avatar_url text, cover_url text, bio text)
language sql security definer stable set search_path = public as $$
  select p.username, p.display_name, p.avatar_url, p.cover_url, p.bio
  from profiles p
  where p.username = lower(coalesce(trim(p_username), ''))
  limit 1;
$$;

revoke all on function public.profile_public_by_username(text) from public;
grant execute on function public.profile_public_by_username(text) to anon, authenticated;
