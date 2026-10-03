-- ديواني: تحديث 2 (صورة الشاعر)
-- شغّله مرة واحدة في SQL Editor ثم اضغط Run.
alter table public.settings add column if not exists photo text not null default '';
