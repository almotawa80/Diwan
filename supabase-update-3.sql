-- ديواني: تحديث 3 (المسودات + الأبيات المفضلة)
-- شغّله مرة واحدة في SQL Editor ثم اضغط Run.

alter table public.poems add column if not exists draft boolean not null default false;
alter table public.poems add column if not exists kind  text    not null default 'poem' check (kind in ('poem','bayt'));

-- المسودات لا يقرؤها إلا المالك والمديرون (حتى عبر واجهة البرمجة)
drop policy if exists poems_read on public.poems;
create policy poems_read on public.poems for select to anon, authenticated
  using (draft = false or public.is_staff());
