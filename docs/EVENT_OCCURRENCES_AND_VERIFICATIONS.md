# Event Occurrences and Verifications

Date: 2026-06-30
Repository: `Raisyroo/michigan-celebration-atlas`

This document describes the small schema foundation added for dated event editions and source-backed verification records. It intentionally does not connect the visual application yet.

## Tables added

### `public.event_occurrences`

`event_occurrences` stores a specific edition, run, or expected dated period for a durable row in `public.events`.

Examples:

- `Black River Tattoo Convention — 2026`
- `Romeo Peach Festival — Labor Day Weekend 2026`
- `A local summer market — 2026 Summer Edition`

An occurrence can have exact dates when known, but dates are nullable so a manually confirmed local event can start as an expected season or labeled edition while details are still being checked. Occurrences have their own lifecycle (`draft`, `confirmed`, `cancelled`, `completed`, `expired`) so a past edition can age out without deleting or disabling the parent event identity.

Important fields include:

- `event_id`: parent durable event identity in `public.events`
- `occurrence_label`: readable edition label, such as `2026` or `Labor Day Weekend 2026`
- `start_date` / `end_date`: optional date range, with a check preventing `end_date` before `start_date`
- `occurrence_status`: occurrence lifecycle
- `venue_name`, `city`, `state`: optional location override for this edition
- `display_until`: optional future display cutoff for app logic that will be built later
- `recheck_at`: optional review timestamp for humans or automation

### `public.event_verifications`

`event_verifications` stores an audit trail of source-backed verification. A row may verify the durable event identity only, or it may verify a specific occurrence.

Verification source types include:

- `automated`
- `celebration_atlas_manual`
- `organizer`
- `venue`
- `tourism_directory`
- `other`

Verification statuses include:

- `verified`
- `needs_review`
- `rejected`
- `expired`

Manual Celebration Atlas verification does not require a URL. Evidence can be a contact, field observation, method, or note. When a verification explicitly overrides automated uncertainty, `overrides_automated_uncertainty` must be true and `override_reason` is required.

Important fields include:

- `event_id`: parent durable event identity being verified
- `occurrence_id`: optional occurrence being verified
- `verification_source_type`: where the verification came from
- `verification_status`: current verification result
- `verified_by_name` / `verified_by_role`: who performed or supplied the verification
- `verified_at`: when the verification happened
- `verification_method`, `notes`, `source_url`, `source_contact`: evidence details
- `expires_at`: optional time limit for relying on this verification
- `recheck_at`: optional timestamp to review the evidence again
- `overrides_automated_uncertainty` / `override_reason`: traceable manual override support

## Identity, occurrence, source, and verification

These concepts are intentionally separate:

| Concept | Meaning | Example |
|---|---|---|
| Event identity | The long-lived canonical event record in `public.events`. | `Black River Tattoo Convention` as a recurring convention identity. |
| Occurrence | A specific dated or expected edition of an event identity. | `Black River Tattoo Convention — June 5–7, 2026`. |
| Source | Supporting evidence such as official sites, venue pages, tourism directories, contacts, or observations. Existing `event_sources` still support canonical event sources. | Official convention website or Blue Water Convention Center event listing. |
| Verification | An audit row saying who or what verified an event or occurrence, when, how, and for how long. | Ray manually confirms the 2026 convention and sets a recheck date. |

A recurring festival differs from a single dated occurrence because the parent `events` row can stay active as the durable identity while each year or edition gets its own occurrence row. When the 2026 occurrence ends, future logic can stop displaying that occurrence without changing the identity of the festival itself.

## Black River Tattoo Convention example

Black River Tattoo Convention already exists as a durable event identity in `public.events`. A future 2026 occurrence could represent the specific dated edition:

```text
public.events
  Black River Tattoo Convention
    durable identity for the convention

public.event_occurrences
  occurrence_label: 2026
  start_date: 2026-06-05
  end_date: 2026-06-07
  occurrence_status: confirmed
  venue_name: Blue Water Convention Center
  city: Port Huron
  state: Michigan
  display_until: 2026-06-08
  recheck_at: 2026-05-15
```

A matching verification row could show how Celebration Atlas confirmed it:

```text
public.event_verifications
  verification_source_type: celebration_atlas_manual
  verification_status: verified
  verified_by_name: Ray
  verified_by_role: Celebration Atlas reviewer
  verified_at: 2026-06-30
  verification_method: official site and venue listing reviewed manually
  source_url: https://www.blackrivertattooconvention.com
  source_contact: optional organizer or venue contact
  expires_at: 2026-06-08
  recheck_at: 2026-05-15
  overrides_automated_uncertainty: true
  override_reason: manual review confirmed the current dated occurrence while automated discovery was incomplete
```

## Optional example SQL only

The block below is documentation-only. Do not run it as a production migration without replacing the lookup assumptions and reviewing the dates/evidence.

```sql
-- Optional example only: Black River Tattoo Convention 2026 occurrence.
-- This is intentionally not included as a live migration insert.
with black_river_event as (
  select id
  from public.events
  where slug = 'black-river-tattoo-convention'
  limit 1
), inserted_occurrence as (
  insert into public.event_occurrences (
    event_id,
    occurrence_label,
    start_date,
    end_date,
    occurrence_status,
    venue_name,
    city,
    state,
    display_until,
    recheck_at,
    notes
  )
  select
    id,
    '2026',
    date '2026-06-05',
    date '2026-06-07',
    'confirmed',
    'Blue Water Convention Center',
    'Port Huron',
    'Michigan',
    timestamptz '2026-06-08 00:00:00+00',
    timestamptz '2026-05-15 00:00:00+00',
    'Documentation example only; verify current dates before use.'
  from black_river_event
  returning id, event_id
)
insert into public.event_verifications (
  event_id,
  occurrence_id,
  verification_source_type,
  verification_status,
  verified_by_name,
  verified_by_role,
  verification_method,
  source_url,
  expires_at,
  recheck_at,
  overrides_automated_uncertainty,
  override_reason,
  notes
)
select
  event_id,
  id,
  'celebration_atlas_manual',
  'verified',
  'Ray',
  'Celebration Atlas reviewer',
  'Manual review of official and venue event pages.',
  'https://www.blackrivertattooconvention.com',
  timestamptz '2026-06-08 00:00:00+00',
  timestamptz '2026-05-15 00:00:00+00',
  true,
  'Manual review confirmed a current dated occurrence while automated discovery was incomplete.',
  'Documentation example only; do not run without current verification.'
from inserted_occurrence;
```

## RLS and access behavior

The migration enables row level security on both new tables and intentionally creates no `anon` or `authenticated` policies. This keeps the tables as operational/admin-managed foundation data for now. Supabase `service_role` or admin SQL can manage records, and a later PR can add a public view or specific read policies after display rules are designed.

This migration does not weaken existing RLS or add unrestricted anonymous writes.

## What this PR intentionally does not do

- No visual app integration
- No automatic expiration jobs
- No public-display view
- No backfill of all old events
- No new event discovery workflow
- No changes to existing `public.events` columns
- No changes to existing candidate, source, media, discovery, or matching tables
- No live seed or production data inserts
