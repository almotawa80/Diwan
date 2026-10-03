-- ديواني: تحديث 1 (عن الشاعر + الإعجاب + التعليقات)
-- شغّله مرة واحدة في SQL Editor بعد supabase-setup.sql ثم اضغط Run.

-- 1) عن الشاعر
alter table public.settings add column if not exists bio   text  not null default '';
alter table public.settings add column if not exists links jsonb not null default '[]';

-- 2) الإعجابات: لا وصول مباشر للجدول، فقط عبر الدوال
create table if not exists public.reactions (
  poem_id text not null,
  device  text not null,
  created timestamptz not null default now(),
  primary key (poem_id, device)
);
alter table public.reactions enable row level security;

create or replace function public.toggle_like(p_poem text, p_device text) returns int
language plpgsql security definer set search_path = public as $$
begin
  if length(coalesce(p_device,'')) < 8 or length(p_device) > 64 then raise exception 'bad device'; end if;
  if not exists (select 1 from public.poems where id = p_poem) then raise exception 'no poem'; end if;
  if exists (select 1 from public.reactions where poem_id = p_poem and device = p_device) then
    delete from public.reactions where poem_id = p_poem and device = p_device;
  else
    insert into public.reactions (poem_id, device) values (p_poem, p_device);
  end if;
  return (select count(*) from public.reactions where poem_id = p_poem)::int;
end $$;

create or replace function public.like_counts() returns table (poem_id text, n int)
language sql stable security definer set search_path = public as $$
  select poem_id, count(*)::int from public.reactions group by poem_id
$$;

create or replace function public.my_likes(p_device text) returns setof text
language sql stable security definer set search_path = public as $$
  select poem_id from public.reactions where device = p_device
$$;

-- 3) التعليقات: تُنشر بعد موافقة المدير
create table if not exists public.comments (
  id       bigint generated always as identity primary key,
  poem_id  text not null,
  name     text not null default '',
  body     text not null,
  device   text not null default '',
  approved boolean not null default false,
  created  timestamptz not null default now()
);
alter table public.comments enable row level security;

drop policy if exists comments_read_public on public.comments;
drop policy if exists comments_read_staff  on public.comments;
drop policy if exists comments_update_staff on public.comments;
drop policy if exists comments_delete_staff on public.comments;
create policy comments_read_public  on public.comments for select to anon, authenticated using (approved);
create policy comments_read_staff   on public.comments for select to authenticated using (public.is_staff());
create policy comments_update_staff on public.comments for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy comments_delete_staff on public.comments for delete to authenticated using (public.is_staff());

-- عمود device مخفي عن الجميع
grant select (id, poem_id, name, body, approved, created) on public.comments to anon, authenticated;
grant update (approved) on public.comments to authenticated;
grant delete on public.comments to authenticated;

create or replace function public.add_comment(p_poem text, p_name text, p_body text, p_device text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if length(coalesce(p_device,'')) < 8 or length(p_device) > 64 then raise exception 'bad device'; end if;
  if length(trim(coalesce(p_body,''))) < 2 or length(p_body) > 400 then raise exception 'bad body'; end if;
  if length(coalesce(p_name,'')) > 40 then raise exception 'bad name'; end if;
  if not exists (select 1 from public.poems where id = p_poem) then raise exception 'no poem'; end if;
  if (select count(*) from public.comments where device = p_device and created > now() - interval '1 hour') >= 3 then
    raise exception 'rate limit';
  end if;
  insert into public.comments (poem_id, name, body, device) values (p_poem, trim(coalesce(p_name,'')), trim(p_body), p_device);
end $$;

grant execute on function public.toggle_like(text, text)               to anon, authenticated;
grant execute on function public.like_counts()                          to anon, authenticated;
grant execute on function public.my_likes(text)                         to anon, authenticated;
grant execute on function public.add_comment(text, text, text, text)    to anon, authenticated;
