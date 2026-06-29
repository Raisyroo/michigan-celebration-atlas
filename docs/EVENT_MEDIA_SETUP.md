# Event Media Setup

This document describes the manual Supabase setup for the first event-owned media pilot: one Romeo Peach Festival flyer. It does **not** change the visual app, local flyers, map, UI, or existing event rows.

## What `event_media` is for

`public.event_media` is an additive database table for approved media assets that belong to canonical rows in `public.events`. It lets Celebration Atlas associate multiple media assets with one event by role, including `flyer`, `thumbnail`, `hero`, `event-card`, `gallery`, `map-art`, and `brand`.

The table is intended to support a later safe connection from the visual website. Future application code can look for `status = 'approved'` media for an event before falling back to existing local media. This PR only adds the database-side foundation and documentation.

## Proposed Storage bucket and folder convention

Proposed Supabase Storage bucket name:

```text
celebration-atlas-media
```

Folder/object convention for the Romeo Peach Festival flyer pilot:

```text
events/romeo-peach-festival/flyer/romeo-peach-festival.webp
```

## Manual Supabase setup steps

### 1. Create the Storage bucket

1. Open the canonical Celebration Atlas Supabase project dashboard.
2. In the left navigation, open **Storage**.
3. Select **New bucket**.
4. Enter this bucket name exactly:

   ```text
   celebration-atlas-media
   ```

5. Choose the bucket visibility policy that matches the project owner's media policy. For public event display, a public bucket is the simplest first pilot option.
6. Leave file-size and MIME restrictions at the project default unless the project owner has a stricter Storage policy.
7. Select **Create bucket**.

### 2. Upload one Romeo flyer

1. In the Supabase dashboard, open **Storage**.
2. Open the `celebration-atlas-media` bucket.
3. Create folders to match this path:

   ```text
   events/romeo-peach-festival/flyer/
   ```

4. Upload the approved Romeo flyer as:

   ```text
   romeo-peach-festival.webp
   ```

5. Confirm the full object path is exactly:

   ```text
   events/romeo-peach-festival/flyer/romeo-peach-festival.webp
   ```

6. If the dashboard shows a public object URL, copy it for the optional `public_url` field. The record can also be resolved by `storage_bucket` and `storage_path`, so `public_url` may remain null.

### 3. Run the SQL file

1. Open the canonical Celebration Atlas Supabase project dashboard.
2. Open **SQL Editor**.
3. Create a new query.
4. Paste the full contents of:

   ```text
   supabase/sql/001_create_event_media.sql
   ```

5. Review that the script only creates `public.event_media`, comments, a timestamp trigger function/trigger, and indexes.
6. Run the query.
7. The SQL is idempotent and safe to run again if needed.

### 4. Insert one approved Romeo flyer record

Only run this after confirming the canonical Romeo row exists in `public.events` with `events.slug = 'romeo-peach-festival'` and after uploading the flyer object. This sample locates the event by slug and stores the canonical event UUID in `event_id`.

## Sample SQL insert for Romeo flyer — do not execute from Codex

```sql
insert into public.event_media (
  event_id,
  media_role,
  source,
  storage_bucket,
  storage_path,
  public_url,
  title,
  alt_text,
  sort_order,
  status
)
select
  e.id,
  'flyer',
  'supabase',
  'celebration-atlas-media',
  'events/romeo-peach-festival/flyer/romeo-peach-festival.webp',
  null,
  'Romeo Peach Festival flyer',
  'Flyer for the Romeo Peach Festival in Romeo, Michigan.',
  0,
  'approved'
from public.events e
where e.slug = 'romeo-peach-festival'
and not exists (
  select 1
  from public.event_media em
  where em.event_id = e.id
    and em.media_role = 'flyer'
    and em.source = 'supabase'
    and em.storage_bucket = 'celebration-atlas-media'
    and em.storage_path = 'events/romeo-peach-festival/flyer/romeo-peach-festival.webp'
    and em.status in ('draft', 'approved')
);
```

Expected result: one inserted row. If zero rows are inserted, confirm the `public.events.slug` value and whether an active media row already exists.

## Rollback

Because the schema is additive, rollback can be limited to the new objects if no production media rows need to be retained:

```sql
drop table if exists public.event_media;
drop function if exists public.set_event_media_updated_at();
```

Dropping the table deletes `event_media` metadata only. It does not delete existing `public.events` rows and does not delete files from Supabase Storage. Delete uploaded Storage objects manually only if the project owner decides they are no longer needed.

## Visual app status

The visual website in `Raisyroo/celebration-atlas-app` remains unchanged. A later separate PR should connect the visual app to approved `event_media` records safely.
