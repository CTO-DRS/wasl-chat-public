-- 050: إحصاءات نقرات أزرار القنوات
-- صف لكل (رسالة، زر، مستخدم): النقر المتكرر لا يضخم الأرقام. لا سياسات على
-- الجدول، فلا قراءة مباشرة لأحد: التسجيل عبر دالة للأعضاء، والعدّادات عبر
-- دالة للمشرفين تعيد أرقاماً مجمّعة فقط (لا هوية من نقر).

create table if not exists public.message_button_clicks (
  message_id uuid not null references public.messages(id) on delete cascade,
  btn_idx    smallint not null check (btn_idx between 0 and 3),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  clicked_at timestamptz not null default now(),
  primary key (message_id, btn_idx, user_id)
);
alter table public.message_button_clicks enable row level security;

create or replace function public.track_button_click(p_msg uuid, p_idx int)
returns void language sql security definer set search_path = public as $$
  insert into message_button_clicks (message_id, btn_idx, user_id)
  select m.id, p_idx, auth.uid()
  from messages m
  join conversations c on c.id = m.conversation_id
  where m.id = p_msg
    and c.kind = 'channel' and public.is_member(c.id)
    and m.buttons is not null
    and p_idx >= 0 and p_idx < jsonb_array_length(m.buttons)
  on conflict do nothing;
$$;

create or replace function public.channel_button_stats(p_conv uuid)
returns table (message_id uuid, btn_idx int, label text, kind text, clicks bigint)
language plpgsql security definer stable set search_path = public as $$
begin
  if not exists (
    select 1 from conversation_participants p
    join conversations c on c.id = p.conversation_id
    where p.conversation_id = p_conv and p.user_id = auth.uid()
      and c.kind = 'channel' and p.role in ('owner', 'admin')) then
    raise exception 'admins only';
  end if;
  return query
  select m.id, (b.ord - 1)::int, b.item->>'label', b.item->>'kind',
         (select count(*) from message_button_clicks k
           where k.message_id = m.id and k.btn_idx = (b.ord - 1))
  from (select id, buttons from messages
         where conversation_id = p_conv and deleted_at is null and buttons is not null
         order by created_at desc limit 30) m,
       jsonb_array_elements(m.buttons) with ordinality as b(item, ord)
  order by m.id, b.ord;
end; $$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.track_button_click(uuid, int)',
    'public.channel_button_stats(uuid)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
