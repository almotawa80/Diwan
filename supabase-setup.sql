-- ديواني: إعداد قاعدة البيانات في Supabase
-- الصق هذا الملف كاملًا في SQL Editor ثم اضغط Run.

-- 1) الجداول
create table if not exists public.poems (
  id         text primary key,
  title      text    not null default '',
  poet       text    not null default '',
  section    text    not null default 'diwan' check (section in ('diwan','fav')),
  star       boolean not null default false,
  bahr       text    not null default '',
  qafiya     text    not null default '',
  era        text    not null default '',
  source     text    not null default '',
  tags       text[]  not null default '{}',
  occasion   text    not null default '',
  gloss      text    not null default '',
  verses     jsonb   not null default '[]',
  sample     boolean not null default false,
  created    bigint  not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.settings (
  id     int primary key default 1 check (id = 1),
  site   text not null default 'ديواني',
  author text not null default ''
);
insert into public.settings (id) values (1) on conflict (id) do nothing;

-- المالك والمديرون
create table if not exists public.staff (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role    text not null check (role in ('owner','manager'))
);

-- 2) دوال الصلاحيات
create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.staff where user_id = auth.uid());
$$;

create or replace function public.is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.staff where user_id = auth.uid() and role = 'owner');
$$;

-- 3) قواعد الأمان (RLS): القراءة للجميع، الكتابة للمالك والمديرين، الحذف للمالك
alter table public.poems    enable row level security;
alter table public.settings enable row level security;
alter table public.staff    enable row level security;

drop policy if exists poems_read   on public.poems;
drop policy if exists poems_insert on public.poems;
drop policy if exists poems_update on public.poems;
drop policy if exists poems_delete on public.poems;
create policy poems_read   on public.poems for select to anon, authenticated using (true);
create policy poems_insert on public.poems for insert to authenticated with check (public.is_staff());
create policy poems_update on public.poems for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy poems_delete on public.poems for delete to authenticated using (public.is_owner());

drop policy if exists settings_read   on public.settings;
drop policy if exists settings_insert on public.settings;
drop policy if exists settings_update on public.settings;
create policy settings_read   on public.settings for select to anon, authenticated using (true);
create policy settings_insert on public.settings for insert to authenticated with check (public.is_owner());
create policy settings_update on public.settings for update to authenticated using (public.is_owner()) with check (public.is_owner());

drop policy if exists staff_read_self on public.staff;
create policy staff_read_self on public.staff for select to authenticated using (user_id = auth.uid());

grant select on public.poems, public.settings to anon, authenticated;
grant insert, update, delete on public.poems to authenticated;
grant insert, update on public.settings to authenticated;
grant select on public.staff to authenticated;

-- 4) تحديث الصفحة تلقائيًا عند تغيّر القصائد (اختياري)
do $$
begin
  begin alter publication supabase_realtime add table public.poems;    exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.settings; exception when duplicate_object then null; end;
end $$;

-- 5) بعد إنشاء المستخدمين من Authentication > Users، شغّل الأسطر التالية
--    (غيّر البريد إلى بريد كل حساب، وأزل علامة -- من أول السطر):
-- insert into public.staff (user_id, role) select id, 'owner'   from auth.users where email = 'owner@example.com';
-- insert into public.staff (user_id, role) select id, 'manager' from auth.users where email = 'manager@example.com';
