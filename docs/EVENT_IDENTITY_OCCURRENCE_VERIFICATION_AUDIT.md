# Event Identity, Occurrence, and Manual Verification Audit

Date: 2026-06-30  
Repository: `Raisyroo/michigan-celebration-atlas`  
Base branch: `main`  
Scope: read-only schema and data-model audit for identity, occurrences, and Celebration Atlas manual verification.

## Audit method and read-only boundary

This audit used repository search plus read-only Supabase PostgREST `GET`/OpenAPI requests against the corrected canonical project URL documented by the prior audit, `https://hmytrcorqkqvoaedvgbf.supabase.co`. The shell environment still contains the older typo URL, but it was not changed.

Repository evidence reviewed:

- `supabase/sql/001_create_event_media.sql`
- `docs/VISUAL_APP_EVENT_CATALOG_AUDIT.md`
- `docs/SUPABASE_APP_EVENT_ALIGNMENT_AUDIT.md`
- `docs/EVENT_MEDIA_SETUP.md`
- root visual HTML files were searched for schema/discovery references only

Live read-only schema/data evidence reviewed:

- PostgREST OpenAPI table definitions for `events`, `event_sources`, `event_candidates`, `event_candidate_sources`, `event_candidate_matches`, `discovery_runs`, and `event_media`
- Read-only `select` samples for those tables
- Read-only filtered `select` rows for `Black River Tattoo Convention`

No SQL editor commands, RPC mutation calls, inserts, updates, deletes, migrations, Storage writes, environment changes, or app-code changes were performed.

## 1. What exists today

### Current tables and relevant fields

| Table | Relevant fields observed | Purpose observed |
|---|---|---|
| `public.events` | `id`, `name`, `slug`, `event_type`, `category`, `subcategory`, `city`, `county`, `state`, `country`, `venue_name`, `official_website`, social URLs, `typical_month`, `typical_season`, `recurrence_pattern`, descriptions, `status`, `verification_status`, `confidence_score`, `first_discovered_at`, `last_verified_at`, timestamps, location/geocoding fields | Canonical event records. This is the closest current layer to durable event identity, but it also carries current lifecycle/verification fields directly on the canonical row. |
| `event_sources` | `id`, `event_id`, `source_name`, `source_url`, `source_type`, `trust_score`, `source_notes`, `last_accessed`, `created_at` | Source/evidence rows attached to canonical `events`. |
| `event_candidates` | `id`, `discovery_run_id`, `candidate_name`, `normalized_name`, `slug_candidate`, event classification/location fields, `start_date`, `end_date`, `typical_month`, `typical_season`, `probable_recurrence`, `description`, candidate website/social/source fields, `discovery_confidence`, `verification_status`, `duplicate_status`, `matched_event_id`, `needs_review`, `semantic_notes`, `raw_payload`, timestamps | Discovery-stage candidates, including optional date fields and promotion link to canonical `events`. |
| `event_candidate_sources` | `id`, `candidate_id`, `source_name`, `source_url`, `source_type`, `source_excerpt`, `trust_score`, `last_accessed`, `created_at` | Source/evidence rows attached to discovery candidates. |
| `event_candidate_matches` | `id`, `candidate_id`, `possible_event_id`, `possible_candidate_id`, `match_score`, `match_reason`, `recommended_action`, `status`, `reviewed_by`, `created_at` | Candidate duplicate/alias review signals. This has a reviewer field, but no reviewed timestamp, note, method, or verification override semantics were found. |
| `discovery_runs` | `id`, `run_type`, `source_id`, `status`, `started_at`, `completed_at`, counts/costs, `approval_required`, `approval_status`, `error_message`, `notes`, `run_metadata`, `created_at` | Batch/import/discovery run tracking. |
| `event_media` | `id`, `event_id`, `media_role`, `source`, storage/public URL fields, text metadata, `sort_order`, `status`, timestamps | Additive media metadata linked to canonical events. It has media approval status, not event verification or occurrence status. |

### Direct answers

- **Is there a durable event-identity record separate from annual/specific occurrences?**  
  **Partially.** `public.events` is a canonical event record with stable `id` and `slug`, so it can act as a durable identity. However, no separate occurrence table was found, and `events` does not separate identity data from occurrence/date-specific lifecycle data.

- **Is there a table or model for an occurrence with start date, end date, status, and expiry?**  
  **Not found.** No `event_occurrences`, schedule, session, instance, edition, date, expiry, or occurrence-status table was found. `event_candidates` has nullable `start_date` and `end_date`, but those exist only on discovery candidates and do not provide canonical occurrence status or expiry.

- **Is there a way to distinguish recurring annual festivals from one-time or fragile events?**  
  **Partially.** `events` includes nullable `recurrence_pattern`, `typical_month`, and `typical_season`; `event_candidates` includes nullable `probable_recurrence`, `typical_month`, and `typical_season`. No explicit annual/recurring/one-time/fragile classification field or lifecycle policy was found.

- **Is there a manual verification field, reviewer identity, manual source, verification note, or override capability?**  
  **Mostly not found.** `events.verification_status` and `events.last_verified_at` exist, but no field distinguishes automated vs Celebration Atlas manual verification. `event_candidate_matches.reviewed_by` exists for match review, but not for event verification. No manual source URL/contact, verification note, verification method, reviewer role, recheck date, or override flag was found.

- **Is there a public-display eligibility field separate from basic event status?**  
  **Not found.** Public eligibility appears to be inferred from `events.status`, `events.verification_status`, and supporting source rows. `event_media.status` is only media lifecycle approval and should not be treated as event-display eligibility.

- **Is there any automatic expiration behavior after an event occurrence ends?**  
  **Not found.** No occurrence expiry field, scheduled job, archival trigger, migration, or script was found. Because canonical events do not store occurrence dates, the current model cannot automatically age out a specific ended occurrence without changing the whole event's status manually.

## 2. Current model diagram

Real current relationship diagram using discovered tables only:

```text
discovery_runs
  → event_candidates
      → event_candidate_sources
      → event_candidate_matches
      → matched_event_id → public.events
                            → event_sources
                            → event_media
```

Missing or incomplete layers:

```text
long-lived event identity: public.events partially fills this role
specific dated occurrence: MISSING as canonical layer
occurrence status/expiry: MISSING
manual Celebration Atlas verification: MISSING as first-class layer
public display eligibility separate from status: MISSING
source-backed manual override: MISSING
```

## 3. Black River Tattoo Convention walkthrough

Using only the current data and schema:

```text
Black River Tattoo Convention
→ event identity
→ 2026 occurrence/date representation
→ evidence/source support
→ verification status
→ what happens after the 2026 event ends
```

### Event identity

The canonical event row exists in `public.events`:

- `id`: `b9688159-c18f-4337-9e4f-fee2ceb80f09`
- `name`: `Black River Tattoo Convention`
- `slug`: `black-river-tattoo-convention`
- `event_type`: `convention`
- `category`: `arts_culture`
- `subcategory`: `tattoo`
- location: `Port Huron`, `St. Clair`, `Michigan`, `Blue Water Convention Center`
- `status`: `active`
- `verification_status`: `verified`
- `confidence_score`: `0.86`

What the system can represent: a canonical event identity for the convention.

What it cannot fully represent: a clean separation between the convention as a long-lived identity and each dated edition/occurrence.

### 2026 occurrence/date representation

The current canonical event row has no `start_date` or `end_date`. The associated candidate row also has `start_date = null` and `end_date = null`, and its semantic note says schedule dates were not yet captured.

What the system can represent: general identity, type, category, venue, source support, and a broad active/verified status.

What it cannot represent: `Black River Tattoo Convention — June 5–7, 2026` as a dated occurrence with its own status, expiry, source evidence, or post-event aging rule.

### Evidence/source support

The canonical event has two `event_sources` rows:

- `Black River Tattoo Convention Official Site` at `https://www.blackrivertattooconvention.com`
- `Blue Water Convention Center Events` at `https://www.bluewaterconventioncenter.com/events`

The discovery candidate has matching `event_candidate_sources`, plus `source_urls` in the candidate record and `raw_payload`.

What the system can represent: source-backed evidence at both candidate and canonical-event levels.

What it cannot represent: source evidence tied to a specific 2026 occurrence date range, because no occurrence table exists.

### Verification status

The canonical event is `status = active` and `verification_status = verified`. The candidate is `verification_status = promoted`, `duplicate_status = needs_review`, `needs_review = false`, and `matched_event_id` points to the canonical event.

One `event_candidate_matches` row remains `status = pending_review`, `recommended_action = review`, `reviewed_by = null`. That match row appears to be duplicate/alias review evidence, not manual event verification.

What the system can represent: a simple canonical verification flag and candidate promotion state.

What it cannot represent: Ray or Celebration Atlas manually verified this event, how it was verified, when it should be rechecked, whether manual verification overrides automated uncertainty, or who changed the canonical verification status.

### What happens after the 2026 event ends

Not found. The current model has no dated canonical occurrence for June 5–7, 2026 and no expiry/recheck field. After June 7, 2026, the database has no occurrence row to age out. The only apparent options are manual changes to broad fields such as `events.status` or `events.verification_status`, which would affect the entire event identity rather than one occurrence.

## 4. Manual verification audit

| Concept | Classification | Actual table/field if found | Notes |
|---|---|---|---|
| manually verified by Celebration Atlas | Not supported | None found | `events.verification_status` can say `verified`, but does not identify manual Celebration Atlas verification. |
| verified by name/role | Partially supported | `event_candidate_matches.reviewed_by` | Only found for candidate match review, not canonical event verification; no role field found. |
| verification date | Partially supported | `events.last_verified_at`; source/candidate timestamps | `last_verified_at` exists on `events`, but does not distinguish manual vs automated or identify verifier. Black River currently has `last_verified_at = null`. |
| verification method | Not supported | None found | No method enum/text field found. |
| verification notes | Partially supported | `event_sources.source_notes`; `event_candidates.semantic_notes`; `discovery_runs.notes` | Notes exist around sources, discovery, and candidates, but no first-class verification note tied to manual approval. |
| manual source URL or contact | Partially supported | `event_sources.source_url`; `event_sources.source_type`; `event_candidate_sources.source_url`; `event_candidates.source_urls` | Source URLs are supported, but no field marks a source as manual, contact-based, or Celebration Atlas supplied. No contact field found. |
| expiration/recheck date | Not supported | None found | No `recheck_at`, `expires_at`, verification expiry, or occurrence expiry field found. |
| override of automated uncertainty | Not supported | None found | No override flag/reason/actor field found. `verification_status` is too broad to prove an override. |
| audit trail of who changed status | Not supported | None found | `reviewed_by` exists only on candidate matches. No canonical event status audit table or updated-by field found. |

## 5. Recommended future model — design only

Do not implement this in this PR. The smallest future model should preserve existing `events` as the durable identity layer and add only the missing layers needed for occurrences and manual verification.

Recommended conceptual model:

```text
events
  durable identity:
    id, slug, name, event_type, category, stable location/home venue,
    recurrence/fragility classification, broad lifecycle status

event_occurrences
  specific dated editions:
    event_id, occurrence_label/year, start_date, end_date,
    occurrence_status, venue/location override if needed,
    expires_at or display_until, recheck_at

event_verifications
  automated or manual verification evidence:
    event_id and/or occurrence_id,
    verification_source_type = automated | celebration_atlas_manual | organizer | venue | tourism_directory,
    verified_by_name or verified_by_user_id,
    verified_by_role,
    verified_at,
    verification_method,
    verification_status,
    notes,
    source_url/contact reference,
    expires_at/recheck_at,
    overrides_automated_uncertainty boolean/reason

event_sources
  supporting sources:
    keep existing canonical event sources;
    optionally allow occurrence_id and verification_id links for date-specific support

public display rule
  active event identity
  + eligible current/upcoming occurrence when dates matter
  + current verification or allowed manual override
  + not explicitly hidden/suppressed from public display
```

Minimal additions, in priority order:

1. Add an `event_occurrences` table rather than overloading `events` with annual dates. This protects durable event identities when individual dates pass.
2. Add an `event_verifications` table rather than adding many manual columns to `events`. This preserves auditability and allows multiple verification events over time.
3. Add a small recurrence/fragility classification to `events` if the existing nullable `recurrence_pattern` is insufficient, for example annual/recurring, one-time, fragile/uncertain, discontinued, unknown.
4. Add a public-display eligibility concept that is separate from canonical identity status. This can be a field, view, or application rule in a future PR, but it should not be conflated with `events.status` alone.
5. Extend `event_sources` only as needed to link sources to occurrences or verifications. Avoid duplicating source rows if a join table is cleaner.

## 6. Suggested display logic

Plain-English future rules, not SQL:

- **Recurring annual festival with no confirmed next-year dates yet:** keep the event identity active; show it as a recurring/annual event only if the identity is verified and the prior occurrence is not misleadingly displayed as current. Use wording such as “typically held in [month/season]” and suppress exact-date claims until a current occurrence is verified.

- **Manually verified local event:** allow public display when a Celebration Atlas manual verification is current, identifies the verifier or reviewer role, includes a source/contact/method, and has a recheck date. Manual verification should be allowed to override automated uncertainty, but the override should have notes and expiry.

- **One-time event that has passed:** automatically age out the occurrence after its `end_date`/`display_until`. Keep or archive the event identity according to policy, but do not present the past occurrence as current.

- **Fragile event such as a tattoo convention:** require a dated occurrence for public current display. If only the identity exists, show it as an unconfirmed/needs-date-check event or suppress it from current listings. A manual verification can make it eligible until its recheck/expiry date.

- **Event with stale or conflicting evidence:** do not rely on `events.status = active` alone. Require current source evidence or a current manual verification. If sources conflict, route to review and suppress date-specific current claims until resolved.

## 7. No-change confirmation

- No database writes occurred.
- No migrations were created.
- No visual app files changed.
- This PR contains documentation only.
- The only repository change is this audit report: `docs/EVENT_IDENTITY_OCCURRENCE_VERIFICATION_AUDIT.md`.
- No SQL write commands were run. Database access for this audit used read-only PostgREST OpenAPI and `select` requests only.
