-- 049: أزرار تفاعلية داخل رسائل القنوات
-- الأزرار بيانات عامة (القنوات غير مشفّرة أصلاً)، فعموداً jsonb منفصلاً لا يلوّث
-- معاينات القوائم. نوعان آمنان بلا تنفيذ على الخادم: url (https فقط) وcopy (نسخ نص).
-- الفرض من الخادم: قنوات فقط، رسائل نصية فقط، حتى 4 أزرار.

alter table public.messages add column if not exists buttons jsonb;

create or replace function public.validate_message_buttons()
returns trigger language plpgsql as $$
declare
  b jsonb;
begin
  if new.buttons is null then
    return new;
  end if;
  if jsonb_typeof(new.buttons) <> 'array' or jsonb_array_length(new.buttons) not between 1 and 4 then
    raise exception 'buttons: 1-4 items required';
  end if;
  if new.type <> 'text' then
    raise exception 'buttons: text messages only';
  end if;
  if not exists (select 1 from public.conversations c where c.id = new.conversation_id and c.kind = 'channel') then
    raise exception 'buttons: channels only';
  end if;
  for b in select * from jsonb_array_elements(new.buttons) loop
    if jsonb_typeof(b) <> 'object'
       or coalesce(char_length(b->>'label'), 0) not between 1 and 24
       or (b->>'kind') not in ('url', 'copy')
       or coalesce(char_length(b->>'value'), 0) not between 1 and 500
       or ((b->>'kind') = 'url' and (b->>'value') !~* '^https://') then
      raise exception 'buttons: invalid item';
    end if;
  end loop;
  return new;
end $$;

drop trigger if exists messages_validate_buttons on public.messages;
create trigger messages_validate_buttons before insert or update of buttons on public.messages
  for each row execute function public.validate_message_buttons();
