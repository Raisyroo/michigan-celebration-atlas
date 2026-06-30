# Visual App Event Catalog Audit — Corrected Supabase Read

Date: 2026-06-30  
Repository audited: `Raisyroo/celebration-atlas-app` `main` cloned read-only from GitHub  
Canonical project used: `https://hmytrcorqkqvoaedvgbf.supabase.co`  
Read-only boundary: all database inspection used PostgREST `select` requests only; no SQL write statements or database mutation endpoints were used.

## Executive summary

The previous documentation-only audit used the incorrect Supabase URL `https://hmytrcorkqvoaedvgbf.supabase.co`. That project URL failed canonical reads, so its conclusions about demo/sample-only and unmatched events were provisional.

This revision explicitly overrode the environment's incorrect `SUPABASE_URL` value with the corrected canonical Supabase project URL `https://hmytrcorqkqvoaedvgbf.supabase.co` for read-only audit tooling. The current shell environment still contains the old URL, so the correction is documented here rather than changing environment variables.

| Metric | Count | Basis |
|---|---:|---|
| Visual app event count | 19 | `ATLAS_EVENTS` in `Raisyroo/celebration-atlas-app` `main` |
| Matched canonical events | 6 | Canonical slug, approved/promoted candidate mapping, or normalized exact name + location |
| Verified/current-source supported | 6 | Matched `public.events` rows are `status=active`, `verification_status=verified`, and have canonical source rows |
| Needs current-source check | 0 | No matched canonical rows lacked source support in the inspected tables |
| Likely demo/sample only | 0 | No visual-app event was classified as demo/sample solely from canonical reads |
| Potentially stale/discontinued | 0 | No inspected canonical status/source/review row supported this disposition |
| Ambiguous/manual review | 0 | No visual-app event had multiple plausible canonical matches under the allowed matching rules |
| No canonical match | 13 | No canonical `events` or `event_candidates` match by slug/name/location |

## Read-only inspection scope

Read-only PostgREST `select` requests were run against these canonical tables:

| Table | Rows read | Relevant fields observed |
|---|---:|---|
| `public.events` | 15 | `id`, `name`, `slug`, `city`, `county`, `state`, `status`, `verification_status`, `official_website`, `typical_month`, `created_at`, `last_verified_at`, geocoding fields |
| `event_sources` | 28 | `event_id`, `source_name`, `source_url`, `source_type`, `trust_score`, `last_accessed`, `created_at` |
| `event_candidates` | 18 | `candidate_name`, `normalized_name`, `slug_candidate`, `city`, `verification_status`, `duplicate_status`, `matched_event_id`, `needs_review`, `source_urls`, `created_at` |
| `event_candidate_sources` | 33 | `candidate_id`, `source_name`, `source_url`, `source_type`, `trust_score`, `last_accessed`, `created_at` |
| `event_candidate_matches` | 7 | `candidate_id`, `possible_event_id`, `match_score`, `match_reason`, `recommended_action`, `status`, `created_at` |
| `discovery_runs` | 5 | `run_type`, `status`, `started_at`, `completed_at`, `items_found`, `candidates_created`, `approval_status`, `notes` |

No additional verification, approval, lifecycle, visibility, status, data-health, or review tables were discovered in this repository's audit tooling or documentation. In the live schema exposed through the requested tables, lifecycle and public visibility are represented only by the `events.status`, `events.verification_status`, candidate duplicate/review fields, and candidate-match review statuses listed above.

## Per-event audit

| App ID | Displayed name | Location | Local app slug | Canonical match status | Canonical slug / UUID | Source/evidence summary | Qualification / approval / visibility / lifecycle status | Recommended disposition |
|---|---|---|---|---|---|---|---|---|
| `romeo-peach` | Romeo Peach Festival | Romeo, MI | `romeo-peach` | Matched by normalized exact name + city; candidate promoted to event | `romeo-peach-festival` / `79fab78b-0a08-4439-8cc0-470281d69fb6` | Event sources: official website and Visit Detroit Events, source rows created 2026-05-15; candidate created 2026-05-14 and promoted | `events.status=active`; `events.verification_status=verified`; candidate `verification_status=promoted`; candidate `duplicate_status=possible_duplicate`; candidate `needs_review=true` | Verified — eligible for current public display |
| `detroit-jazz` | Detroit Jazz Festival | Detroit, MI | `detroit-jazz` | No canonical event/candidate match | — | No matching canonical rows found by slug, normalized name, or city/name | — | No canonical match found |
| `armada-fair` | Armada Fair | Armada, MI | `armada-fair` | No canonical event/candidate match | — | No matching canonical rows found by slug, normalized name, or city/name | — | No canonical match found |
| `mackinac-lilac` | Mackinac Island Lilac Festival | Mackinac Island, MI | `mackinac-lilac` | Matched by normalized exact name + city; candidate promoted to event | `mackinac-island-lilac-festival` / `34f9482c-8a22-4861-a350-4c49749b74ef` | Event sources: official Mackinac Island Lilac Festival page and Pure Michigan Events Directory, source rows created 2026-05-15; candidate created 2026-05-14 and promoted | `events.status=active`; `events.verification_status=verified`; candidate `verification_status=promoted`; candidate `duplicate_status=possible_duplicate`; candidate `needs_review=false`; match status `reviewed_same_event_alias` | Verified — eligible for current public display |
| `electric-forest` | Electric Forest | Rothbury, MI | `electric-forest` | No canonical event/candidate match | — | No matching canonical rows found by slug, normalized name, or city/name | — | No canonical match found |
| `traverse-city-cherry` | National Cherry Festival | Traverse City, MI | `traverse-city-cherry` | Matched by normalized exact name + city; candidate promoted to event | `national-cherry-festival` / `129bf2a1-6e7b-4ae0-ab5f-2be21c676ccf` | Event sources: National Cherry Festival official site and Michigan.org Events Directory, source rows created 2026-05-15; candidate created 2026-05-14 and promoted | `events.status=active`; `events.verification_status=verified`; candidate `verification_status=promoted`; candidate `duplicate_status=possible_duplicate`; candidate `needs_review=false`; match status `reviewed_same_event_alias` | Verified — eligible for current public display |
| `west-michigan-coast-guard` | Coast Guard Festival | Grand Haven, MI | `west-michigan-coast-guard` | No canonical event/candidate match | — | No matching canonical rows found by slug, normalized name, or city/name | — | No canonical match found |
| `holland-tulip-time` | Tulip Time Festival | Holland, MI | `holland-tulip-time` | Matched by normalized exact name + city; candidate promoted to event | `tulip-time-festival` / `21db3825-fbe3-4869-ba44-cb17ebb8d245` | Event sources: Tulip Time official site and Pure Michigan Tulip Time page, source rows created 2026-05-15; candidate created 2026-05-14 and promoted | `events.status=active`; `events.verification_status=verified`; candidate `verification_status=promoted`; candidate `duplicate_status=possible_duplicate`; candidate `needs_review=false`; match status `reviewed_same_event_alias` | Verified — eligible for current public display |
| `alpena-brown-trout` | Brown Trout Festival | Alpena, MI | `alpena-brown-trout` | No canonical event/candidate match | — | No matching canonical rows found by slug, normalized name, or city/name | — | No canonical match found |
| `charlevoix-venetian` | Charlevoix Venetian Festival | Charlevoix, MI | `charlevoix-venetian` | No canonical event/candidate match | — | No matching canonical rows found by slug, normalized name, or city/name | — | No canonical match found |
| `cheboygan-4th-fireworks` | Cheboygan Independence Day Festival | Cheboygan, MI | `cheboygan-4th-fireworks` | No canonical match to this event | — | Canonical rows contain `Cheboygan County Fair` in Cheboygan, but that is a distinct name/event and was not treated as a match | — | No canonical match found |
| `muskegon-summer-celebration` | Muskegon Summer Celebration | Muskegon, MI | `muskegon-summer-celebration` | No canonical event/candidate match | — | No matching canonical rows found by slug, normalized name, or city/name | — | No canonical match found |
| `faster-horses` | Faster Horses Festival | Brooklyn, MI | `faster-horses` | No canonical event/candidate match | — | No matching canonical rows found by slug, normalized name, or city/name | — | No canonical match found |
| `common-ground-lansing` | Common Ground Music Festival | Lansing, MI | `common-ground-lansing` | No canonical event/candidate match | — | No matching canonical rows found by slug, normalized name, or city/name | — | No canonical match found |
| `allendale-balloon-fest` | Allendale Balloon Festival | Allendale, MI | `allendale-balloon-fest` | No canonical event/candidate match | — | No matching canonical rows found by slug, normalized name, or city/name | — | No canonical match found |
| `black-river-tattoo` | Black River Tattoo Convention | Port Huron, MI | `black-river-tattoo` | Matched by normalized exact name + city; candidate promoted to event | `black-river-tattoo-convention` / `b9688159-c18f-4337-9e4f-fee2ceb80f09` | Event sources: official site and Blue Water Convention Center Events, source rows created 2026-05-15; candidate created 2026-05-14 and promoted | `events.status=active`; `events.verification_status=verified`; candidate `verification_status=promoted`; candidate `duplicate_status=needs_review`; candidate `needs_review=false`; one candidate-match row remains `pending_review` | Verified — eligible for current public display |
| `goodells-fair` | St. Clair County 4-H & Youth Fair | Goodells, Michigan | `goodells-fair` | No canonical event/candidate match | — | No matching canonical rows found by slug, normalized name, or city/name | — | No canonical match found |
| `shiawassee-fair` | Shiawassee County Fair | Corunna, MI | `shiawassee-fair` | No canonical event/candidate match | — | No matching canonical rows found by slug, normalized name, or city/name | — | No canonical match found |
| `upper-peninsula-state-fair` | Upper Peninsula State Fair | Escanaba, MI | `upper-peninsula-state-fair` | Matched by canonical slug and normalized exact name + city; candidate promoted to event | `upper-peninsula-state-fair` / `32774aad-2f82-4094-98be-a65ff42a6564` | Event sources: Upper Peninsula State Fair official site and Pure Michigan Events Directory, source rows created 2026-05-15; candidate created 2026-05-14 and promoted | `events.status=active`; `events.verification_status=verified`; candidate `verification_status=promoted`; candidate `duplicate_status=unique_candidate`; candidate `needs_review=true` | Verified — eligible for current public display |

## Muskegon review

`muskegon-summer-celebration` was re-checked by local slug, normalized displayed name, city, and candidate slug patterns. The corrected canonical project returned no `public.events` row and no `event_candidates` row for `Muskegon Summer Celebration`, `muskegon-summer-celebration`, or a Muskegon city/name combination.

Result: canonical evidence is **insufficient evidence**. This audit does **not** classify the event as discontinued, inactive, duplicate, or active because no supporting source record, canonical status, or clear review status was found in the inspected canonical tables.

## Qualification pipeline discovered

The live canonical data shows this path from discovery candidate to eligible canonical event:

1. A `discovery_runs` row records a completed `statewide_discovery` batch with `approval_status=not_required`.
2. The run creates `event_candidates` rows containing normalized names, candidate slugs, locations, source URLs, confidence, duplicate status, `needs_review`, and `verification_status`.
3. `event_candidate_sources` attaches source evidence to each candidate.
4. `event_candidate_matches` records duplicate or alias review signals such as `pending_review`, `reviewed_same_event_alias`, and `reviewed_related_distinct` with match scores and recommended actions.
5. Promoted candidates set `event_candidates.verification_status=promoted` and `matched_event_id` to a canonical `public.events.id`.
6. Eligible canonical records are represented by `public.events.status=active` and `public.events.verification_status=verified`, with supporting `event_sources` rows.

No repository-local script or job was found in this repository for running discovery or promotion. The inspected evidence appears to be database-resident run/candidate/match/source records rather than checked-in application code.

## Audit honesty and safety confirmations

- The previous audit used the incorrect Supabase URL `https://hmytrcorkqvoaedvgbf.supabase.co` and could not read canonical data.
- This revision successfully used the corrected canonical project URL `https://hmytrcorqkqvoaedvgbf.supabase.co`.
- The actual source of the incorrect configuration in this environment was the `SUPABASE_URL` environment variable. It was not changed; the audit script used a local read-only override for the corrected URL.
- No Supabase writes occurred: no SQL write statements were executed, and all database calls were HTTP `GET` `select` requests.
- No visual app files were changed; `Raisyroo/celebration-atlas-app` was cloned outside this repository under `/tmp` for read-only catalog inspection.
- This PR changes documentation only.
