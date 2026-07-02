# Atlas Control Plane v1 database contract

## Audit summary

This contract reuses the current canonical Supabase model instead of creating parallel event concepts:

- `public.events` remains the durable event identity table. This PR does not let automation overwrite or delete event identity rows.
- `event_sources` remains the source table attached to canonical events.
- `event_media` remains the event-owned media table and is not changed by this contract.
- `event_occurrences` remains the dated-edition table for canonical events.
- `event_verifications` remains the source-backed verification audit trail for events and optional occurrences.
- `discovery_runs`, `event_candidates`, `event_candidate_sources`, and `event_candidate_matches` remain the discovery/candidate/match layer. Candidate intake reuses `event_candidates` and `event_candidate_sources`.
- Existing docs did not identify a single protected review queue or permanent per-mutation automation ledger, so this migration adds those missing control-plane concepts.

## New durable ledger

`atlas_operation_runs` stores one row per human, automation, or system operation. The `(operation_type, idempotency_key)` uniqueness rule makes retries converge on the same run instead of silently creating duplicate work.

`atlas_operation_actions` stores one row per meaningful proposed or applied mutation. It records the operation, action type, target entity, source references, requested payload, before snapshot, applied payload, after snapshot, reason, warnings, failures, and timestamps.

`atlas_review_items` is the single exception queue for ambiguous matches, duplicate risk, conflicting source data, missing or non-official source evidence, suspicious date/location changes, media collisions, policy blocks, and other validation blocks.

## Safe automation tier

The first automation tier is intentionally limited:

1. Future Atlas AI or app code calls a protected server route.
2. The server route calls a typed Supabase RPC with server-only privileges.
3. The RPC creates or attaches to an `atlas_operation_run`.
4. Each attempted mutation is recorded as an `atlas_operation_action`.
5. Safe candidate and verification writes are applied to existing canonical tables.
6. Ambiguous, conflicting, or under-sourced records become `atlas_review_items` instead of being silently published.

Candidate intake can create/update draft discovery candidates and attach official source evidence. Verification recording writes to `event_verifications`. Candidate disposition can mark a candidate matched, duplicate, rejected, or ready for a later explicit promotion workflow, but it does not alter canonical `public.events` identity records.

## Evidence, idempotency, and blocking

Source-backed candidate intake requires at least one official source with `source_name`, `source_url`, and `is_official=true`. Review creation records structured evidence and recommended action. Verification recording requires a source URL and uses the existing verification model. Every typed RPC accepts an idempotency key so retries are auditable and bounded.

Conflicts are handled by queueing review items. The contract avoids generic raw SQL execution, direct canonical event publication, deletes, and silent overwrites.

## Next app PR contract

The next PR should add an authenticated Atlas Control Plane app console. Its server routes should call these typed RPCs using server-only Supabase privileges. Browser clients should never receive service keys and should never submit raw SQL. Canonical event publication should remain deferred to a later explicit workflow with its own review and action ledger rules.
