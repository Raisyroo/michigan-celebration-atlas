-- Celebration Atlas event occurrences and verification audit trail schema.
--
-- Purpose:
--   Adds the smallest canonical foundation for dated event editions and
--   source-backed automated or manual Celebration Atlas verification without
--   changing public.events, discovery tables, media tables, Storage, or the
--   visual application.
--
-- Access/RLS convention:
--   These are operational foundation tables, not an app-facing display surface
--   yet. Row level security is enabled and no anon/authenticated policies are
--   created in this migration, so ordinary client roles do not receive new
--   read or write access. Supabase service_role/admin execution can manage the
--   records while a later PR defines any public-display view or policies.
--
-- Safe to run more than once in Supabase SQL Editor.

create table if not exists public.event_occurrences (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  occurrence_label text,
  start_date date,
  end_date date,
  occurrence_status text not null default 'draft',
  venue_name text,
  city text,
  state text,
  display_until timestamptz,
  recheck_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint event_occurrences_status_check check (
    occurrence_status in ('draft', 'confirmed', 'cancelled', 'completed', 'expired')
  ),
  constraint event_occurrences_date_order_check check (
    start_date is null
    or end_date is null
    or end_date >= start_date
  ),
  constraint event_occurrences_id_event_id_key unique (id, event_id)
);

comment on table public.event_occurrences is
  'Specific dated or expected editions of durable public.events identities. Occurrences can be completed or expired without deleting or disabling the parent event.';
comment on column public.event_occurrences.event_id is
  'Durable canonical event identity. The parent public.events row remains the long-lived event record.';
comment on column public.event_occurrences.occurrence_label is
  'Human label for this edition, such as 2026, 2026 Summer Edition, or Labor Day Weekend 2026.';
comment on column public.event_occurrences.occurrence_status is
  'Occurrence lifecycle: draft, confirmed, cancelled, completed, or expired.';
comment on column public.event_occurrences.display_until is
  'Optional timestamp after which this occurrence should no longer be considered current by future display logic. No automatic job is created here.';
comment on column public.event_occurrences.recheck_at is
  'Optional timestamp for humans or automation to recheck this occurrence. No automatic job is created here.';

create table if not exists public.event_verifications (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  occurrence_id uuid,
  verification_source_type text not null,
  verification_status text not null default 'needs_review',
  verified_by_name text,
  verified_by_role text,
  verified_at timestamptz not null default now(),
  verification_method text,
  notes text,
  source_url text,
  source_contact text,
  expires_at timestamptz,
  recheck_at timestamptz,
  overrides_automated_uncertainty boolean not null default false,
  override_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint event_verifications_source_type_check check (
    verification_source_type in (
      'automated',
      'celebration_atlas_manual',
      'organizer',
      'venue',
      'tourism_directory',
      'other'
    )
  ),
  constraint event_verifications_status_check check (
    verification_status in ('verified', 'needs_review', 'rejected', 'expired')
  ),
  constraint event_verifications_override_reason_check check (
    overrides_automated_uncertainty = false
    or nullif(btrim(coalesce(override_reason, '')), '') is not null
  ),
  constraint event_verifications_occurrence_event_fk foreign key (occurrence_id, event_id)
    references public.event_occurrences(id, event_id) on delete cascade
);

comment on table public.event_verifications is
  'Audit trail for automated, source-backed, organizer, venue, tourism-directory, or Celebration Atlas manual verification of an event identity and optionally one occurrence.';
comment on column public.event_verifications.event_id is
  'Durable canonical event identity being verified.';
comment on column public.event_verifications.occurrence_id is
  'Optional occurrence verified by this row. Null means the verification applies to the durable event identity rather than a specific edition.';
comment on column public.event_verifications.verification_source_type is
  'Verification source type: automated, celebration_atlas_manual, organizer, venue, tourism_directory, or other.';
comment on column public.event_verifications.source_url is
  'Optional URL evidence. Manual Celebration Atlas verification may instead rely on source_contact, verification_method, or notes.';
comment on column public.event_verifications.expires_at is
  'Optional timestamp when this verification should no longer be treated as current by future logic. No automatic job is created here.';
comment on column public.event_verifications.recheck_at is
  'Optional timestamp for humans or automation to recheck verification evidence. No automatic job is created here.';
comment on column public.event_verifications.overrides_automated_uncertainty is
  'True when a manual or trusted verification is intended to temporarily override incomplete or uncertain automated discovery.';
comment on column public.event_verifications.override_reason is
  'Required reason when overrides_automated_uncertainty is true.';

create or replace function public.set_event_occurrences_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_event_occurrences_updated_at on public.event_occurrences;
create trigger set_event_occurrences_updated_at
before update on public.event_occurrences
for each row
execute function public.set_event_occurrences_updated_at();

create or replace function public.set_event_verifications_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_event_verifications_updated_at on public.event_verifications;
create trigger set_event_verifications_updated_at
before update on public.event_verifications
for each row
execute function public.set_event_verifications_updated_at();

create index if not exists event_occurrences_event_idx
  on public.event_occurrences (event_id);

create index if not exists event_occurrences_status_start_date_idx
  on public.event_occurrences (occurrence_status, start_date);

create index if not exists event_occurrences_display_until_idx
  on public.event_occurrences (display_until)
  where display_until is not null;

create index if not exists event_occurrences_recheck_at_idx
  on public.event_occurrences (recheck_at)
  where recheck_at is not null;

create index if not exists event_verifications_event_verified_at_idx
  on public.event_verifications (event_id, verified_at desc);

create index if not exists event_verifications_occurrence_verified_at_idx
  on public.event_verifications (occurrence_id, verified_at desc)
  where occurrence_id is not null;

create index if not exists event_verifications_current_expiry_idx
  on public.event_verifications (verification_status, expires_at);

create index if not exists event_verifications_recheck_at_idx
  on public.event_verifications (recheck_at)
  where recheck_at is not null;

alter table public.event_occurrences enable row level security;
alter table public.event_verifications enable row level security;

comment on table public.event_occurrences is
  'Specific dated or expected editions of durable public.events identities. RLS is enabled with no client policies in this foundation migration; service_role/admin access manages rows until a future app-facing policy or view is added.';
comment on table public.event_verifications is
  'Audit trail for event and occurrence verification. RLS is enabled with no client policies in this foundation migration; service_role/admin access manages rows until a future app-facing policy or view is added.';
