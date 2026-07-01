# Flyer Inventory Workflow

`npm run inventory:flyers` is a read-only dry run for finding possible flyer artwork and proposing canonical Celebration Atlas event matches. It does not upload files, create Supabase Storage objects, modify `event_media`, change schema, or edit media files.

## What the script scans

By default the script checks two inputs:

1. `../celebration-atlas-app`, the expected sibling checkout for `Raisyroo/celebration-atlas-app`, when that path is available.
2. This repository's `images/` directory, so the canonical repo's existing artwork can still be classified when the visual app checkout is unavailable.

The visual app source can be overridden with:

```bash
FLYER_INVENTORY_SOURCE=/path/to/celebration-atlas-app npm run inventory:flyers
```

A JSON manifest can also be supplied for future reviewed inputs:

```bash
FLYER_INVENTORY_MANIFEST=/path/to/flyer-manifest.json npm run inventory:flyers
```

The manifest may be either an array of file paths or an object with a `files` array. This lets a future upload phase consume an explicitly reviewed list instead of rescanning a whole app checkout.

## Classification categories

The script classifies assets conservatively:

- `flyer_candidate`: image files whose path or filename explicitly contains `flyer` or a `flyers` folder.
- `thumbnail_only`: image files whose path or filename indicates thumbnails or generated thumbnail output.
- `poster_or_artwork`: image files whose path or filename indicates posters or artwork.
- `video_only`: video formats such as MP4/WebM/MOV/M4V.
- `unknown`: image files without enough path evidence to call them a flyer, thumbnail, or poster.

This intentionally avoids calling every image a flyer.

## How canonical matching and confidence work

The script uses only repository-documented canonical identity information and hard-coded, reviewable aliases from existing audits. It does not scrape the network or query Supabase.

Match confidence is deterministic:

- Exact canonical slug or exact canonical name: high confidence and eligible for `matched`, unless approved flyer media already exists.
- Configured visual-app alias/app ID: medium confidence and `needs_manual_review` because filename-only guesses must not be auto-approved.
- Fuzzy filename/path similarity: low confidence and `needs_manual_review`.
- Multiple plausible matches: `ambiguous`.
- No canonical event: `no_canonical_event`.
- Non-flyer categories: `not_a_flyer`.

Romeo Peach Festival is special only because repository media documentation identifies an approved Supabase flyer path. The report marks Romeo as `already_has_approved_flyer` when a flyer candidate exactly matches `romeo-peach-festival`, and the recommended action is not to overwrite the authoritative approved Supabase media.

## Report review

The command writes stable, reviewable outputs:

- `reports/flyer-inventory.json`
- `reports/flyer-inventory.md`

Each entry includes source path, file type, file size, classification, proposed event name, proposed canonical slug, match status, confidence, approved-flyer status, next action, and reasoning.

Reviewers should focus on:

1. Whether `flyer_candidate` entries are truly flyers.
2. Whether `needs_manual_review` alias/fuzzy matches should be accepted into a future upload manifest.
3. Whether `ambiguous` and `no_canonical_event` entries need canonical data work before any media handling.
4. Whether any `already_has_approved_flyer` entry, especially Romeo, should be skipped to avoid overwriting approved media.

## What “ready for upload” means

An asset is ready for a future upload phase only after human review confirms all of the following:

- The asset is truly a flyer, not a thumbnail, poster, gallery image, or video.
- The canonical event already exists; no new event is invented to force a match.
- The target canonical slug/event ID is explicitly approved.
- There is no existing approved flyer that should remain authoritative.
- The reviewed asset appears in a future upload manifest with the exact source file path and desired Supabase Storage destination.

This workflow does not perform that upload. A separate future command must require a reviewed manifest containing exact source path, canonical event ID or slug, target bucket, target storage path, media role, title/alt text, and approval intent before any Supabase write is allowed.
