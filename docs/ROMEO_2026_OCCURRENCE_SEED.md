# Romeo Peach Festival 2026 occurrence seed

Date prepared: 2026-06-30

This document accompanies `supabase/sql/003_seed_romeo_2026_occurrence_verification.sql`. The seed adds one operational data example for the new occurrence and verification model. It does not bulk backfill events and does not connect Romeo to public app display logic.

## Canonical event identity used

The live Supabase database was checked before writing the seed. The canonical event row used by the seed is:

| Field | Value |
|---|---|
| `events.id` | `79fab78b-0a08-4439-8cc0-470281d69fb6` |
| `events.slug` | `romeo-peach-festival` |
| `events.name` | `Romeo Peach Festival` |
| `events.city` | `Romeo` |
| `events.state` | `Michigan` |
| `events.status` | `active` |
| `events.verification_status` | `verified` |
| `events.official_website` | `https://www.romeopeachfestival.com` |

The seed refuses to insert data if that exact event identity is not present.

## Source evidence used

Existing `event_sources` rows for the canonical Romeo event were inspected. The seed requires the official website source row to exist before inserting the occurrence or verification:

| Source name | URL | Source type | Trust score |
|---|---|---|---|
| `Romeo Peach Festival Official Website` | `https://www.romeopeachfestival.com` | `multi_source` | `0.95` |
| `Visit Detroit Events` | `https://visitdetroit.com/events/romeo-peach-festival` | `multi_source` | `0.78` |

Current official evidence from the official Romeo Peach Festival website was reviewed on 2026-06-30. The site stated that the 95th Anniversary Romeo Peach Festival is Thursday, September 3 through Labor Day, September 7, 2026. The seed therefore uses September 3–7, 2026 as the confirmed occurrence date range.

No new `event_sources` row is created by this seed because the canonical official website source already exists for the event.

## Occurrence values

The seed creates or updates exactly one `public.event_occurrences` row with these values:

| Column | Value |
|---|---|
| `event_id` | `79fab78b-0a08-4439-8cc0-470281d69fb6` |
| `occurrence_label` | `2026` |
| `start_date` | `2026-09-03` |
| `end_date` | `2026-09-07` |
| `occurrence_status` | `confirmed` |
| `venue_name` | `null` |
| `city` | `Romeo` |
| `state` | `Michigan` |
| `display_until` | `2026-09-08 00:00:00+00` |
| `recheck_at` | `2026-08-17 00:00:00+00` |

`display_until` is after the occurrence ends. `recheck_at` is before the event and was intentionally chosen as a practical future review date after this seed date.

## Verification values

The seed creates or updates exactly one `public.event_verifications` row for the occurrence with these values:

| Column | Value |
|---|---|
| `verification_source_type` | `celebration_atlas_manual` |
| `verification_status` | `verified` |
| `verified_by_name` | `Ray` |
| `verified_by_role` | `Celebration Atlas reviewer` |
| `verified_at` | `2026-06-30 00:00:00+00` |
| `verification_method` | `Manual review of the official Romeo Peach Festival website for the published 2026 festival date range.` |
| `source_url` | `https://www.romeopeachfestival.com` |
| `expires_at` | `2026-09-08 00:00:00+00` |
| `recheck_at` | `2026-08-17 00:00:00+00` |
| `overrides_automated_uncertainty` | `true` |
| `override_reason` | `Manual official-source review confirmed the upcoming dated 2026 occurrence.` |

## Idempotency behavior

The SQL seed is safe to run twice:

1. It verifies the exact canonical event ID, slug, name, and Romeo, Michigan location before making changes.
2. It verifies that the official website source URL is already attached to that event.
3. It refuses to proceed if a conflicting Romeo `2026` occurrence exists with different dates.
4. It updates the matching Romeo 2026 occurrence when one already exists, or inserts it when absent.
5. It updates the matching Celebration Atlas manual verification by Ray for that occurrence when one already exists, or inserts it when absent.
6. It refuses to proceed if multiple matching manual verification rows already exist, rather than hiding a duplicate-data problem.

## How to run

Apply the occurrence and verification schema before applying the Romeo operational seed. The `\i` include syntax is a PostgreSQL `psql` meta-command; it is not supported in Supabase SQL Editor.

Use one of these supported options:

1. Apply both SQL files through the repository's normal Supabase migration or CLI workflow, in order:
   - `supabase/sql/002_create_event_occurrences_and_verifications.sql`
   - `supabase/sql/003_seed_romeo_2026_occurrence_verification.sql`
2. Or, in Supabase SQL Editor, paste and run the full contents of `supabase/sql/002_create_event_occurrences_and_verifications.sql` first. After that execution succeeds, paste and run the full contents of `supabase/sql/003_seed_romeo_2026_occurrence_verification.sql` as a separate SQL Editor execution.

## How to confirm the records exist after running

Use this read-only query after applying the seed:

```sql
select
  e.id as event_id,
  e.slug,
  e.name,
  o.id as occurrence_id,
  o.occurrence_label,
  o.start_date,
  o.end_date,
  o.occurrence_status,
  o.city,
  o.state,
  o.display_until,
  o.recheck_at as occurrence_recheck_at,
  v.id as verification_id,
  v.verification_source_type,
  v.verification_status,
  v.verified_by_name,
  v.verified_by_role,
  v.verified_at,
  v.verification_method,
  v.source_url,
  v.expires_at,
  v.recheck_at as verification_recheck_at
from public.events e
join public.event_occurrences o
  on o.event_id = e.id
join public.event_verifications v
  on v.event_id = e.id
 and v.occurrence_id = o.id
where e.id = '79fab78b-0a08-4439-8cc0-470281d69fb6'::uuid
  and e.slug = 'romeo-peach-festival'
  and o.occurrence_label = '2026'
  and o.start_date = date '2026-09-03'
  and o.end_date = date '2026-09-07'
  and v.verification_source_type = 'celebration_atlas_manual'
  and v.verified_by_name = 'Ray';
```

To confirm repeat execution did not create duplicates, run:

```sql
select
  count(distinct o.id) filter (
    where o.occurrence_label = '2026'
      and o.start_date = date '2026-09-03'
      and o.end_date = date '2026-09-07'
  ) as matching_occurrences,
  count(v.id) filter (
    where o.occurrence_label = '2026'
      and o.start_date = date '2026-09-03'
      and o.end_date = date '2026-09-07'
      and v.verification_source_type = 'celebration_atlas_manual'
      and v.verified_by_name = 'Ray'
      and v.verified_by_role = 'Celebration Atlas reviewer'
  ) as matching_manual_verifications
from public.event_occurrences o
left join public.event_verifications v
  on v.event_id = o.event_id
 and v.occurrence_id = o.id
where o.event_id = '79fab78b-0a08-4439-8cc0-470281d69fb6'::uuid;
```

Both counts should be `1` after the seed has been run once or repeatedly.

## Public app display status

This seed does not connect Romeo Peach Festival to public app display logic. It does not add a public-display view, change RLS, update Storage, alter environment variables, or modify any visual application files.
