-- Celebration Atlas event-owned media schema.
--
-- Purpose:
--   Creates public.event_media as an additive companion table for approved media
--   that belongs to canonical public.events rows. This prepares the Supabase
--   database for a future Romeo Peach Festival flyer pilot without changing
--   existing event records, application code, RLS policies, or Storage objects.
--
-- Manual Storage convention documented in docs/EVENT_MEDIA_SETUP.md:
--   Bucket: celebration-atlas-media
--   Romeo flyer path: events/romeo-peach-festival/flyer/romeo-peach-festival.webp
--
-- Safe to run more than once in Supabase SQL Editor.

create table if not exists public.event_media (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  media_role text not null,
  source text not null,
  storage_bucket text,
  storage_path text,
  public_url text,
  title text,
  alt_text text,
  sort_order integer not null default 0,
  status text not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint event_media_media_role_check check (
    media_role in (
      'flyer',
      'thumbnail',
      'hero',
      'event-card',
      'gallery',
      'map-art',
      'brand'
    )
  ),
  constraint event_media_source_check check (
    source in ('supabase', 'local', 'external')
  ),
  constraint event_media_status_check check (
    status in ('draft', 'approved', 'archived')
  ),
  constraint event_media_storage_path_or_public_url_check check (
    nullif(btrim(coalesce(storage_path, '')), '') is not null
    or nullif(btrim(coalesce(public_url, '')), '') is not null
  )
);

comment on table public.event_media is
  'Additive event-owned media records linked to public.events. Approved records can be resolved by future application code without changing canonical event rows.';
comment on column public.event_media.event_id is
  'Canonical event owner. Use public.events.slug only for manual lookup/seed examples, then store the UUID here.';
comment on column public.event_media.media_role is
  'Media placement role: flyer, thumbnail, hero, event-card, gallery, map-art, or brand.';
comment on column public.event_media.source is
  'Media origin: supabase, local, or external. Supabase records may use storage_bucket/storage_path.';
comment on column public.event_media.status is
  'Lifecycle status. Application media resolution should prefer approved records and ignore draft/archived records unless explicitly requested.';

-- Keep updated_at current for row updates. The function is intentionally small
-- and idempotently replaceable so this standalone SQL file does not require a
-- migration framework.
create or replace function public.set_event_media_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_event_media_updated_at on public.event_media;
create trigger set_event_media_updated_at
before update on public.event_media
for each row
execute function public.set_event_media_updated_at();

-- Finding approved media by event while preserving role and display ordering.
create index if not exists event_media_approved_by_event_idx
  on public.event_media (event_id, media_role, sort_order, created_at desc)
  where status = 'approved';

-- Resolving one event's approved flyer efficiently.
create index if not exists event_media_approved_flyer_idx
  on public.event_media (event_id, sort_order, created_at desc)
  where status = 'approved'
    and media_role = 'flyer';

-- Sorting all media for an event/role, including draft review queues.
create index if not exists event_media_event_role_sort_idx
  on public.event_media (event_id, media_role, sort_order, created_at desc);

-- Prevent duplicate active media records for the same canonical event, role,
-- and Supabase Storage object path. Archived rows are excluded so old records
-- can be retained without blocking a replacement.
create unique index if not exists event_media_active_event_role_storage_path_uidx
  on public.event_media (event_id, media_role, storage_bucket, storage_path)
  where status in ('draft', 'approved')
    and storage_bucket is not null
    and storage_path is not null;

-- Prevent duplicate active media records for the same canonical event, role,
-- and public URL for local or external media where no Storage path exists.
create unique index if not exists event_media_active_event_role_public_url_uidx
  on public.event_media (event_id, media_role, public_url)
  where status in ('draft', 'approved')
    and public_url is not null;
