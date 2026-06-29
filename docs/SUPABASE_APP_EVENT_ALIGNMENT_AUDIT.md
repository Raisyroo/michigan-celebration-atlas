# Supabase ↔ Celebration Atlas App Event Alignment Audit

Date: 2026-06-29

## Scope and safety confirmation

This audit was performed as a read-only compatibility review before any media/storage work. No database writes, migrations, Storage buckets, uploads, visual-app UI changes, map changes, marker changes, flyer changes, search changes, or local visual-app event-data edits were made.

Read-only validation attempted:

- `GET /rest/v1/events?select=*&limit=100` using the configured Supabase URL and service role header.
- `HEAD /rest/v1/events?select=*&limit=1` using the configured Supabase URL and service role header.
- Read-only clone/inspection of `Raisyroo/celebration-atlas-app`.

The Supabase REST requests were read-only `select` requests only. They failed in this environment with `503 Service Unavailable` and body `DNS resolution failure`, so this report does **not** claim a live confirmed row inventory or live confirmed table DDL. The app-side audit is confirmed from the cloned visual-app repository.

## Confirmed database schema summary

Live schema confirmation is blocked by the current environment's Supabase DNS/proxy failure. The attempted read-only PostgREST requests did not return table metadata or records.

| Field area requested | Confirmed from live DB? | Notes |
| --- | ---: | --- |
| Primary key | No | Could not query table metadata or rows. Do not assume the primary key name/type until a successful read-only schema query is run. |
| `slug` | No | Expected by the audit goal, but not confirmed from live DB in this run. |
| `name` | No | Expected by the audit goal, but not confirmed from live DB in this run. |
| City/location fields | No | Could not confirm whether location is split into city/state/venue or stored as a display string. |
| Coordinates | No | Could not confirm coordinate column names or numeric types. |
| Date | No | Could not confirm date/range fields. |
| Status | No | Could not confirm status field or enum values. |
| Category | No | Could not confirm category field or enum values. |
| Media-related fields | No | Could not confirm whether any flyer/image/media columns already exist. |
| Stable IDs for cross-app matching | No live DB confirmation | The safest likely candidates are a Supabase UUID primary key plus a unique, human-readable `slug`, but both must be confirmed with a successful schema query. |

### Required follow-up read-only schema query

Before implementation, run a read-only schema check from an environment that can resolve the Supabase project. The minimum output needed is:

- `information_schema.columns` for `public.events`.
- primary-key constraint for `public.events`.
- unique constraints/indexes involving `slug`.
- a row sample containing only non-secret event fields.

## Visual-app local event data sources

The current visual app stores its canonical local event list in `data/events.ts` as `ATLAS_EVENTS`. Each record has an `id`, `name`, display `location`, `latitude`, `longitude`, visual map coordinates `x`/`y`, category, optional `dateRange`, and optional card/detail media metadata.

Additional local event-derived sources inspected:

- `data/eventFlyers.ts` maps flyer assets by visual-app `event.id`.
- `data/eventThumbnail.ts` derives generated thumbnail paths from visual-app `event.id` and falls back by category.
- `data/eventThumbnailManifest.ts` embeds preview thumbnail records keyed by visual-app event ID and includes separate `requestedSlug` values.
- `components/AtlasMap.tsx` uses `ATLAS_EVENTS` directly for markers, selected IDs, callouts, and the thumbnail rail.
- `data/eventMedia.ts` resolves approved Supabase media records by visual-app event ID for future media support, but it is still keyed to the local `event.id` contract in the inspected app.

## Visual-app IDs/slugs used by map, flyer resolver, and thumbnail rail

The app's effective event identifier is `AtlasEvent.id`, not a separate `slug` field. The event type has no `slug` property in `data/events.ts`.

| App subsystem | Identifier used | Evidence |
| --- | --- | --- |
| Map markers and selected state | `event.id` | `AtlasMap` builds layouts and selection from `ATLAS_EVENTS` and `layout.event.id`. |
| Flyer resolver | `event.id` | `getEventFlyer(event.id)` in `data/eventFlyers.ts`. |
| Generated thumbnail resolver | `event.id` | `getGeneratedEventThumbnailPath()` returns `/event-media/generated/${event.id}-thumb.webp`. |
| Embedded thumbnail manifest | manifest key / `eventId`; also has `requestedSlug` | `MANIFEST_EVENT_THUMBNAILS` is keyed by IDs such as `romeo-peach`, while `requestedSlug` can differ, e.g. `romeo-peach-festival`. |
| Internal profile/search-derived records | `event.id` | `EVENT_PROFILES` are adapted from `ATLAS_EVENTS`. |

## Visual-app event inventory

| Visual-app ID | Visual-app name | Location | Notes |
| --- | --- | --- | --- |
| `romeo-peach` | Romeo Peach Festival | Romeo, MI | Has local flyer and generated thumbnail. |
| `detroit-jazz` | Detroit Jazz Festival | Detroit, MI | Generated thumbnail; detailed card briefing. |
| `armada-fair` | Armada Fair | Armada, MI | Local map event. |
| `mackinac-lilac` | Mackinac Island Lilac Festival | Mackinac Island, MI | Has local flyer and generated thumbnail. |
| `electric-forest` | Electric Forest | Rothbury, MI | Has local event media videos/poster. |
| `traverse-city-cherry` | National Cherry Festival | Traverse City, MI | Generated thumbnail; app ID is location-based rather than event-name slug. |
| `west-michigan-coast-guard` | Coast Guard Festival | Grand Haven, MI | Local map event. |
| `holland-tulip-time` | Tulip Time Festival | Holland, MI | Generated thumbnail. |
| `alpena-brown-trout` | Brown Trout Festival | Alpena, MI | Has local flyer; app ID includes city alias. |
| `charlevoix-venetian` | Charlevoix Venetian Festival | Charlevoix, MI | Local map event. |
| `cheboygan-4th-fireworks` | Cheboygan Independence Day Festival | Cheboygan, MI | Local map event. |
| `muskegon-summer-celebration` | Muskegon Summer Celebration | Muskegon, MI | Local map event. |
| `faster-horses` | Faster Horses Festival | Brooklyn, MI | Local map event. |
| `common-ground-lansing` | Common Ground Music Festival | Lansing, MI | Local map event. |
| `allendale-balloon-fest` | Allendale Balloon Festival | Allendale, MI | Local map event. |
| `black-river-tattoo` | Black River Tattoo Convention | Port Huron, MI | Has local flyer. |
| `goodells-fair` | St. Clair County 4-H & Youth Fair | Goodells, Michigan | Has local flyer; app ID is an alias, not the formal event name. |
| `shiawassee-fair` | Shiawassee County Fair | Corunna, MI | Local map event. |
| `upper-peninsula-state-fair` | Upper Peninsula State Fair | Escanaba, MI | Has local flyer. |

## Event alignment table

Because the live Supabase row query failed, the Supabase columns below are limited to the target canonical matches named in the audit request and are marked as unconfirmed pending a successful read-only DB query.

| Supabase name | Supabase slug | Visual-app ID/slug | Match status | Notes |
| --- | --- | --- | --- | --- |
| Romeo Peach Festival | Unconfirmed | `romeo-peach` | App confirmed; DB unconfirmed in this run | Strong expected match by exact name and city. App thumbnail manifest requested slug is `romeo-peach-festival`, while app ID is `romeo-peach`. |
| Black River Tattoo Convention | Unconfirmed | `black-river-tattoo` | App confirmed; DB unconfirmed in this run | Strong expected match by exact name. App has a local flyer. |
| Upper Peninsula State Fair | Unconfirmed | `upper-peninsula-state-fair` | App confirmed; DB unconfirmed in this run | Strong expected match by exact name and app ID likely matching a canonical slug. App has a local flyer. |
| Mackinac Island Lilac Festival | Unconfirmed | `mackinac-lilac` | App confirmed; DB unconfirmed in this run | Strong expected match by exact name, but app ID is shortened. App thumbnail manifest requested slug is `mackinac-lilac`; a DB slug could plausibly be longer. |
| National Cherry Festival | Unconfirmed | `traverse-city-cherry` | App confirmed; DB unconfirmed in this run | Strong expected name match if present, but app ID is location-based. App thumbnail manifest requested slug is `traverse-city-cherry`, which may not equal a canonical DB slug such as `national-cherry-festival`. |
| St. Clair County 4-H & Youth Fair / Goodells Fair | Unconfirmed | `goodells-fair` | App confirmed; DB unconfirmed in this run | Needs alias handling. App name is formal, while app ID/flyer path use `goodells-fair`. |
| Brown Trout Festival | Unconfirmed | `alpena-brown-trout` | App confirmed; DB unconfirmed in this run | Needs alias handling. App ID includes city. Do not choose as pilot unless DB row is confirmed. |

## Events in the visual app that do not yet exist in Supabase

This cannot be confirmed from live DB records in this environment. Treat the full app inventory above as candidates to check against Supabase once read-only access works. Based on only the specifically requested known Supabase candidates, these app events remain unverified and should be checked:

- Detroit Jazz Festival (`detroit-jazz`)
- Armada Fair (`armada-fair`)
- Electric Forest (`electric-forest`)
- Coast Guard Festival (`west-michigan-coast-guard`)
- Tulip Time Festival (`holland-tulip-time`)
- Charlevoix Venetian Festival (`charlevoix-venetian`)
- Cheboygan Independence Day Festival (`cheboygan-4th-fireworks`)
- Muskegon Summer Celebration (`muskegon-summer-celebration`)
- Faster Horses Festival (`faster-horses`)
- Common Ground Music Festival (`common-ground-lansing`)
- Allendale Balloon Festival (`allendale-balloon-fest`)
- Shiawassee County Fair (`shiawassee-fair`)

## Supabase events that do not yet have a visual-app equivalent

Not determined. The read-only Supabase events query failed before returning any canonical rows. This list must be generated after a successful `select id, slug, name, city/location fields` read.

## Mismatches, aliases, duplicates, and normalization issues

Confirmed app-side issues to account for before linking:

1. The app has `id` but no distinct `slug` field. Any first-phase mapping to Supabase `slug` will require either a deterministic ID-to-slug alias map or adding a non-invasive mapping layer later.
2. Several app IDs are not guaranteed to equal likely canonical Supabase slugs:
   - `romeo-peach` vs likely `romeo-peach-festival`.
   - `traverse-city-cherry` vs likely `national-cherry-festival`.
   - `alpena-brown-trout` vs likely `brown-trout-festival` or similar.
   - `goodells-fair` vs formal event name `St. Clair County 4-H & Youth Fair`.
   - `mackinac-lilac` vs likely `mackinac-island-lilac-festival`.
3. Names are more stable for human review but less reliable as foreign keys because punctuation, location prefixes, and formal/common names differ.
4. Flyer and thumbnail assets are keyed by app ID today, so changing app IDs would be risky. A mapping layer is safer than renaming local events.
5. Goodells/St. Clair County and Brown Trout/Alpena are alias cases and should not become duplicate Supabase event records.

## Recommended canonical linking rule

Use a two-part contract:

1. **Canonical database identity:** Supabase event UUID primary key, once confirmed.
2. **Public stable lookup identity:** unique Supabase `slug`, once confirmed as unique/non-null.

For the first phase, `slug` is sufficient only if the read-only schema audit confirms that `public.events.slug` is unique, non-null, stable, and already populated for all pilot events. The visual app should not rename its local `id` values just to match Supabase. Instead, add a future explicit mapping such as:

```ts
const SUPABASE_EVENT_LINKS_BY_APP_ID = {
  'romeo-peach': { slug: 'romeo-peach-festival', supabaseId: '<uuid-after-read-only-confirmation>' },
};
```

Recommended evolution:

- Phase 1: app ID → Supabase slug mapping for read-only media lookup.
- Phase 2: store both Supabase UUID and slug in app-side link metadata after UUIDs are confirmed.
- Phase 3: use UUID internally for database joins/media records and keep slug for URLs, debugging, and manual review.

Aliases should be first-class link metadata, not duplicate events. A single Supabase event should own the canonical slug/UUID, while alternate app IDs, historic names, city-prefixed names, and common names should live in an alias/link table or static app mapping until a database alias model exists.

## Recommended first media pilot event

Recommended pilot: **Romeo Peach Festival**, pending final live DB row confirmation.

Rationale:

- It is confirmed in the visual app as `romeo-peach`.
- It already has a known local flyer asset: `/event-media/flyers/romeo-peach-festival.webp`.
- It has the cleanest human-readable match among the requested events.
- The app already uses related media for Romeo (`/event-media/romeo-peach-loop.mp4`) and a generated thumbnail, making it an ideal end-to-end media pilot.
- It avoids the Brown Trout uncertainty until the Supabase row is confirmed and alias mapping is decided.

Do not start media implementation until the Supabase row is confirmed read-only and its UUID/slug are captured in a non-secret mapping plan.

## Exact next implementation step, with no implementation in this task

Run a read-only Supabase alignment script from an environment that can resolve the project and produce a small JSON/Markdown artifact containing:

1. `public.events` columns and primary/unique constraints.
2. All canonical event rows with only non-secret fields: primary key, slug, name, city/location, coordinates, date/date range, status, category, and media-related columns.
3. A deterministic app-ID-to-Supabase-slug match proposal for the 19 visual-app events.
4. A confirmed pilot row for Romeo Peach Festival including Supabase UUID and slug.

After that artifact is reviewed, the first implementation PR should add only a static mapping layer and read-only media lookup contract. It should still avoid Storage bucket creation, file upload, and production data mutation until the linking contract is accepted.
