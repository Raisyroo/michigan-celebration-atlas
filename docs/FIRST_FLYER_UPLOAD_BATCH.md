# First reviewed flyer upload batch

This batch is manifest-driven and defaults to dry-run mode. It prepares exactly three reviewed flyer candidates from the sibling `celebration-atlas-app` checkout for Supabase Storage and `public.event_media` metadata.

Run this command from the `michigan-celebration-atlas` repository with `celebration-atlas-app` checked out beside it:

```text
../celebration-atlas-app
../michigan-celebration-atlas
```

If the app checkout lives somewhere else, set `FLYER_UPLOAD_SOURCE_ROOT` to that local path before running the uploader.

## Included reviewed flyer matches

| Event | Canonical slug | Source repository | Source path within source repository | Target Storage object |
| --- | --- | --- | --- | --- |
| Black River Tattoo Convention | `black-river-tattoo-convention` | `celebration-atlas-app` | `public/event-media/flyers/black-river-tattoo-convention.webp` | `celebration-atlas-media/events/black-river-tattoo-convention/flyer/black-river-tattoo-convention.webp` |
| Mackinac Island Lilac Festival | `mackinac-island-lilac-festival` | `celebration-atlas-app` | `public/event-media/flyers/mackinac-island-lilac-festival.webp` | `celebration-atlas-media/events/mackinac-island-lilac-festival/flyer/mackinac-island-lilac-festival.webp` |
| Upper Peninsula State Fair | `upper-peninsula-state-fair` | `celebration-atlas-app` | `public/event-media/flyers/upper-peninsula-state-fair.webp` | `celebration-atlas-media/events/upper-peninsula-state-fair/flyer/upper-peninsula-state-fair.webp` |

The reviewed manifest is `manifests/first-flyer-upload.json`. Each entry records the source repository, source path inside that repository, canonical slug, media role `flyer`, target bucket `celebration-atlas-media`, Romeo-style target object path, title, alt text, and intended `approved` status.

## Explicit exclusions

The first batch intentionally excludes:

- Romeo Peach Festival, because approved Supabase flyer media already exists.
- Brown Trout Festival, because it does not yet have a canonical event record.
- Goodells Fair, because it does not yet have a canonical event record.
- Any thumbnail, poster, artwork, unknown image, or video.

## Dry run: default and safe

```sh
npm run upload:flyers
```

Dry run reads the reviewed manifest, resolves flyer files from `FLYER_UPLOAD_SOURCE_ROOT` or the default `../celebration-atlas-app` source root, verifies local image files, validates target storage paths, confirms excluded events remain out of the upload manifest, prints the exact object path and intended `event_media` record, and performs zero Storage or database writes. Without Supabase credentials, database-dependent canonical event and existing approved-flyer verification is explicitly skipped so the default dry run remains local-only and safe. When `SUPABASE_URL` and a service key are available, dry run additionally performs those read-only Supabase checks.

The uploader fails clearly if the source checkout or any reviewed source file is unavailable.

## Apply: explicit write command

```sh
npm run upload:flyers -- --apply
```

Apply mode requires the canonical Supabase environment variables already used by project tooling:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` or `SUPABASE_SERVICE_KEY`

Do not commit keys or paste them into logs, manifests, or documentation.

Apply mode uploads missing flyer objects to `celebration-atlas-media` and creates or reconciles matching approved `event_media` rows. It never overwrites an existing approved flyer for an event when that flyer points at a different Storage object; that case is reported as blocked and requires a separate future replacement workflow.

## Idempotency and recovery

- Re-running dry run is read-only.
- Re-running apply after success reports already-present matching media and avoids duplicate rows.
- If Storage upload succeeds but metadata insertion is interrupted, re-running apply detects the existing object and creates/reconciles the matching `event_media` row.
- If approved flyer media already exists at a different object path, the batch stops before writing anything for that conflicting event.

## Scope boundaries

This batch does not add flyer binaries to the canonical repo, add a schema migration, modify `public.events`, or change the visual application. It reuses the existing `event_media` schema and the approved Supabase flyer conventions documented for the Romeo pilot.
