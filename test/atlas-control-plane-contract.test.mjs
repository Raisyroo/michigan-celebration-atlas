import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const migration = readFileSync(new URL('../supabase/sql/004_create_atlas_control_plane_v1.sql', import.meta.url), 'utf8');
const docs = readFileSync(new URL('../docs/atlas-control-plane-v1.md', import.meta.url), 'utf8');

test('control-plane migration creates the canonical ledger tables', () => {
  for (const table of ['atlas_operation_runs', 'atlas_operation_actions', 'atlas_review_items']) {
    assert.match(migration, new RegExp(`create table if not exists public\\.${table}`));
    assert.match(migration, new RegExp(`alter table public\\.${table} enable row level security`));
  }
});

test('operation runs enforce idempotent retries by operation type and key', () => {
  assert.match(migration, /create unique index if not exists atlas_operation_runs_operation_idempotency_uidx\s+on public\.atlas_operation_runs \(operation_type, idempotency_key\)/);
});

test('protected mutation RPCs are typed and not raw SQL escape hatches', () => {
  const expectedFunctions = [
    'atlas_intake_event_candidate',
    'atlas_record_event_verification',
    'atlas_create_review_item',
    'atlas_disposition_candidate',
  ];

  for (const fn of expectedFunctions) {
    assert.match(migration, new RegExp(`create or replace function public\\.${fn}\\(`));
    assert.match(migration, new RegExp(`revoke execute on function public\\.${fn}`));
    assert.match(migration, new RegExp(`grant execute on function public\\.${fn}.*to service_role`, 's'));
  }

  assert.doesNotMatch(migration, /execute\s+p_/i, 'migration must not execute caller-provided SQL');
  assert.doesNotMatch(migration, /raw_sql/i, 'migration must not expose a raw SQL function');
});

test('candidate intake requires official source evidence', () => {
  assert.match(migration, /atlas_require_source_evidence/);
  assert.match(migration, /is_official/);
  assert.match(migration, /Each intake source must include source_name, source_url, and is_official=true/);
});

test('documentation states canonical publication is deferred', () => {
  assert.match(docs, /`public\.events` remains the durable event identity table/);
  assert.match(docs, /does not alter canonical `public\.events` identity records/);
  assert.match(docs, /Canonical event publication should remain deferred/);
});
