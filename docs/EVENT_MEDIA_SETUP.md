# Event Media Setup

This document describes the manual Supabase setup for the first event-owned media pilot: the Romeo Peach Festival flyer. It does **not** change the visual app, local flyers, map, UI, or existing event rows.

## What the schema adds

Run `supabase/sql/001_create_event_media.sql` manually in the Supabase SQL Editor to create an additive `public.event_media` table linked to `public.events.id`.

The table stores event-owned media records with roles such as `flyer`, `thumbnail`, `hero`, `event-card`, `gallery`, `map-art`, and `brand`. Future application code can resolve `status = 'approved'` Supabase media before local fallback media, so an approved Supabase flyer can override a local fallback later without moving, overwriting, or deleting existing files.

## Storage bucket convention

Use this Storage bucket name for Celebration Atlas media:

```text
celebration-atlas-media
```

Use this object path for the Romeo Peach Festival flyer pilot:

```text
events/romeo-peach-festival/flyer/romeo-peach-festival.webp
```

## 1. Create the Supabase Storage bucket

1. Open the Supabase project dashboard.
2. In the left navigation, open **Storage**.
3. Select **New bucket**.
4. Enter the bucket name exactly:

   ```text
   celebration-atlas-media
   ```

5. Set the bucket to **Public** initially.
   - The first pilot flyer is intended for public event display.
   - A public bucket lets later read-only app code use the object path or public URL without signing URLs.
   - Do not upload private, licensed, unreleased, or personally sensitive files to this public bucket.
6. Leave file-size and MIME restrictions at the project default unless the Supabase project owner has a stricter policy.
7. Select **Create bucket**.

## 2. Upload the Romeo flyer

This is a later manual Storage step. Do not run it from Codex.

1. In the Supabase dashboard, open **Storage**.
2. Open the `celebration-atlas-media` bucket.
3. Create folders to match this path:

   ```text
   events/romeo-peach-festival/flyer/
   ```

4. Upload the Romeo flyer as:

   ```text
   romeo-peach-festival.webp
   ```

5. Confirm the full object path is exactly:

   ```text
   events/romeo-peach-festival/flyer/romeo-peach-festival.webp
   ```

6. If the dashboard shows a public object URL, copy it for the later `public_url` field if desired. The schema also supports resolving the object by `storage_bucket` and `storage_path`, so `public_url` can remain null.

## 3. Run the SQL schema file

1. Open the Supabase project dashboard.
2. Open **SQL Editor**.
3. Create a new query.
4. Paste the full contents of:

   ```text
   supabase/sql/001_create_event_media.sql
   ```

5. Review that the script only creates `public.event_media`, comments, a timestamp trigger function/trigger, and indexes.
6. Run the query.
7. The SQL is idempotent and is safe to run again if needed.

## 4. Later manual Romeo media insert

Only run this after confirming the canonical Romeo row exists in `public.events` with the slug `romeo-peach-festival` and after uploading the flyer object. This insert uses the canonical event slug for lookup; it does not hardcode Romeo's UUID.

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
);
```

Expected result: one inserted row. If zero rows are inserted, confirm the `public.events.slug` value and whether the media row already exists.

## Rollback note

Because the schema is additive, rollback can be limited to the new objects if no production media rows need to be retained:

```sql
drop table if exists public.event_media;
drop function if exists public.set_event_media_updated_at();
```

Dropping the table deletes `event_media` metadata only. It does not delete existing `public.events` rows and does not delete files from Supabase Storage.
