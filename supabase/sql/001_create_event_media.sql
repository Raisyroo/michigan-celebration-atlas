-- Celebration Atlas event-owned media schema.
--
-- Purpose:
--   Creates public.event_media as an additive companion table for media that is
--   owned by canonical public.events rows. This prepares Supabase-hosted media
--   records for the Romeo Peach Festival flyer pilot without changing existing
--   event records, flyer data, local assets, application code, RLS policies, or
--   Storage objects.
--
-- Manual Storage convention documented in docs/EVENT_MEDIA_SETUP.md:
--   Bucket: celebration-atlas-media
--   Romeo flyer path: events/romeo-peach-festival/flyer/romeo-peach-festival.webp
--
-- Safe to run more than once in Supabase SQL Editor.

create table if not exists public.event_media (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  media_role text not null check (
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
  source text not null check (source in ('supabase', 'local', 'external')),
  storage_bucket text,
  storage_path text,
  public_url text,
  title text,
  alt_text text,
  sort_order integer not null default 0,
  status text not null default 'draft' check (status in ('draft', 'approved', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.event_media is
  'Additive event-owned media records linked to public.events. Approved Supabase records can be resolved ahead of local fallback media by application code later.';
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

-- General lookup by owning event, role, status, and ordering.
create index if not exists event_media_event_role_status_sort_idx
  on public.event_media (event_id, media_role, status, sort_order, created_at desc);

-- Active media resolution index. This supports future application logic that
-- asks for the approved media for an event/role and can rank Supabase-hosted
-- records before local fallback records without deleting local data.
create index if not exists event_media_approved_resolution_idx
  on public.event_media (event_id, media_role, source, sort_order, created_at desc)
  where status = 'approved';

-- Storage-path lookup for Supabase-backed media records. Multiple NULL values
-- are allowed, so this remains additive for local/external rows.
create unique index if not exists event_media_supabase_storage_path_uidx
  on public.event_media (storage_bucket, storage_path)
  where source = 'supabase'
    and storage_bucket is not null
    and storage_path is not null;
