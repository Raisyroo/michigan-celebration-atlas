-- Atlas Control Plane v1: protected operation ledger and typed write RPCs.
-- Additive and non-destructive. Creates no browser-facing policies.

create table if not exists public.atlas_operation_runs (
  id uuid primary key default gen_random_uuid(),
  operation_type text not null,
  actor_type text not null,
  actor_identity text not null,
  status text not null default 'planned',
  idempotency_key text not null,
  request jsonb not null default '{}'::jsonb,
  summary jsonb not null default '{}'::jsonb,
  error jsonb,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint atlas_operation_runs_operation_type_check check (nullif(btrim(operation_type), '') is not null),
  constraint atlas_operation_runs_actor_type_check check (actor_type in ('human', 'automation', 'system')),
  constraint atlas_operation_runs_actor_identity_check check (nullif(btrim(actor_identity), '') is not null),
  constraint atlas_operation_runs_status_check check (status in ('planned', 'running', 'succeeded', 'partial', 'failed', 'cancelled')),
  constraint atlas_operation_runs_idempotency_key_check check (nullif(btrim(idempotency_key), '') is not null),
  constraint atlas_operation_runs_started_completed_check check (completed_at is null or started_at is null or completed_at >= started_at)
);

create unique index if not exists atlas_operation_runs_operation_idempotency_uidx
  on public.atlas_operation_runs (operation_type, idempotency_key);
create index if not exists atlas_operation_runs_status_created_idx
  on public.atlas_operation_runs (status, created_at desc);

create table if not exists public.atlas_operation_actions (
  id uuid primary key default gen_random_uuid(),
  operation_run_id uuid not null references public.atlas_operation_runs(id) on delete cascade,
  action_type text not null,
  target_entity_type text,
  target_entity_id uuid,
  lifecycle_state text not null default 'proposed',
  source_references jsonb not null default '[]'::jsonb,
  requested_payload jsonb not null default '{}'::jsonb,
  before_snapshot jsonb,
  applied_payload jsonb,
  after_snapshot jsonb,
  reason text,
  warnings jsonb not null default '[]'::jsonb,
  failure jsonb,
  created_at timestamptz not null default now(),
  applied_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint atlas_operation_actions_action_type_check check (nullif(btrim(action_type), '') is not null),
  constraint atlas_operation_actions_lifecycle_state_check check (lifecycle_state in ('proposed', 'applied', 'skipped', 'blocked', 'failed')),
  constraint atlas_operation_actions_source_references_array_check check (jsonb_typeof(source_references) = 'array'),
  constraint atlas_operation_actions_warnings_array_check check (jsonb_typeof(warnings) = 'array')
);

create index if not exists atlas_operation_actions_run_idx on public.atlas_operation_actions (operation_run_id, created_at);
create index if not exists atlas_operation_actions_target_idx on public.atlas_operation_actions (target_entity_type, target_entity_id) where target_entity_id is not null;
create index if not exists atlas_operation_actions_state_idx on public.atlas_operation_actions (lifecycle_state, created_at desc);

create table if not exists public.atlas_review_items (
  id uuid primary key default gen_random_uuid(),
  operation_run_id uuid references public.atlas_operation_runs(id) on delete set null,
  operation_action_id uuid references public.atlas_operation_actions(id) on delete set null,
  review_type text not null,
  event_id uuid references public.events(id) on delete set null,
  candidate_id uuid references public.event_candidates(id) on delete set null,
  priority integer not null default 50,
  status text not null default 'open',
  evidence jsonb not null default '{}'::jsonb,
  recommended_action text not null,
  resolution_details jsonb,
  resolved_by text,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint atlas_review_items_type_check check (review_type in ('ambiguous_event_match', 'duplicate_risk', 'conflicting_source_data', 'missing_or_non_official_source', 'suspicious_date_location_change', 'media_collision', 'policy_or_validation_block', 'other')),
  constraint atlas_review_items_priority_check check (priority between 0 and 100),
  constraint atlas_review_items_status_check check (status in ('open', 'approved', 'rejected', 'resolved')),
  constraint atlas_review_items_recommended_action_check check (nullif(btrim(recommended_action), '') is not null),
  constraint atlas_review_items_resolution_check check ((status = 'open' and resolved_at is null) or (status <> 'open'))
);

create index if not exists atlas_review_items_open_priority_idx on public.atlas_review_items (priority desc, created_at) where status = 'open';
create index if not exists atlas_review_items_event_idx on public.atlas_review_items (event_id) where event_id is not null;
create index if not exists atlas_review_items_candidate_idx on public.atlas_review_items (candidate_id) where candidate_id is not null;

create or replace function public.set_atlas_control_plane_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_atlas_operation_runs_updated_at on public.atlas_operation_runs;
create trigger set_atlas_operation_runs_updated_at before update on public.atlas_operation_runs for each row execute function public.set_atlas_control_plane_updated_at();
drop trigger if exists set_atlas_operation_actions_updated_at on public.atlas_operation_actions;
create trigger set_atlas_operation_actions_updated_at before update on public.atlas_operation_actions for each row execute function public.set_atlas_control_plane_updated_at();
drop trigger if exists set_atlas_review_items_updated_at on public.atlas_review_items;
create trigger set_atlas_review_items_updated_at before update on public.atlas_review_items for each row execute function public.set_atlas_control_plane_updated_at();

alter table public.atlas_operation_runs enable row level security;
alter table public.atlas_operation_actions enable row level security;
alter table public.atlas_review_items enable row level security;

create or replace function public.atlas_assert_service_role()
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if session_user in ('postgres', 'service_role') or coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role' then
    return;
  end if;
  raise exception 'Atlas Control Plane mutations require server-side service role access' using errcode = '42501';
end;
$$;

create or replace function public.atlas_require_source_evidence(p_sources jsonb)
returns void language plpgsql immutable set search_path = public as $$
begin
  if jsonb_typeof(p_sources) <> 'array' or jsonb_array_length(p_sources) < 1 then
    raise exception 'At least one source evidence record is required';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_sources) s
    where nullif(btrim(coalesce(s->>'source_url', '')), '') is null
       or nullif(btrim(coalesce(s->>'source_name', '')), '') is null
       or coalesce((s->>'is_official')::boolean, false) is not true
  ) then
    raise exception 'Each intake source must include source_name, source_url, and is_official=true';
  end if;
end;
$$;

create or replace function public.atlas_start_operation(p_operation_type text, p_actor_type text, p_actor_identity text, p_idempotency_key text, p_request jsonb default '{}'::jsonb)
returns public.atlas_operation_runs language plpgsql security definer set search_path = public as $$
declare v_run public.atlas_operation_runs;
begin
  perform public.atlas_assert_service_role();
  insert into public.atlas_operation_runs (operation_type, actor_type, actor_identity, status, idempotency_key, request, started_at)
  values (p_operation_type, p_actor_type, p_actor_identity, 'running', p_idempotency_key, coalesce(p_request, '{}'::jsonb), now())
  on conflict (operation_type, idempotency_key) do update
    set request = excluded.request,
        status = case when public.atlas_operation_runs.status in ('failed', 'cancelled') then 'running' else public.atlas_operation_runs.status end,
        started_at = coalesce(public.atlas_operation_runs.started_at, now())
  returning * into v_run;
  return v_run;
end;
$$;

create or replace function public.atlas_intake_event_candidate(p_actor_type text, p_actor_identity text, p_idempotency_key text, p_candidate jsonb, p_sources jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_run public.atlas_operation_runs; v_action_id uuid; v_candidate_id uuid; v_source jsonb; v_status text;
begin
  perform public.atlas_assert_service_role();
  perform public.atlas_require_source_evidence(p_sources);
  v_run := public.atlas_start_operation('candidate_intake', p_actor_type, p_actor_identity, p_idempotency_key, jsonb_build_object('candidate', p_candidate, 'sources', p_sources));
  if v_run.completed_at is not null and v_run.status = 'succeeded' then
    return v_run.summary || jsonb_build_object('operation_run_id', v_run.id, 'idempotent_replay', true);
  end if;
  insert into public.atlas_operation_actions (operation_run_id, action_type, lifecycle_state, source_references, requested_payload, reason)
  values (v_run.id, 'candidate_intake', 'proposed', p_sources, p_candidate, 'Source-backed candidate intake requested.') returning id into v_action_id;

  select id into v_candidate_id from public.event_candidates where slug_candidate = p_candidate->>'slug_candidate' order by created_at desc limit 1;
  if v_candidate_id is null then
    insert into public.event_candidates (candidate_name, normalized_name, slug_candidate, city, county, state, start_date, end_date, typical_month, typical_season, description, source_urls, discovery_confidence, verification_status, duplicate_status, needs_review, semantic_notes, raw_payload)
    values (p_candidate->>'candidate_name', p_candidate->>'normalized_name', p_candidate->>'slug_candidate', p_candidate->>'city', p_candidate->>'county', coalesce(p_candidate->>'state','MI'), nullif(p_candidate->>'start_date','')::date, nullif(p_candidate->>'end_date','')::date, p_candidate->>'typical_month', p_candidate->>'typical_season', p_candidate->>'description', (select array_agg(s->>'source_url') from jsonb_array_elements(p_sources) s), coalesce((p_candidate->>'discovery_confidence')::numeric, 0.70), 'needs_review', 'unchecked', true, p_candidate->>'semantic_notes', p_candidate)
    returning id into v_candidate_id;
    v_status := 'created';
  else
    update public.event_candidates set raw_payload = coalesce(raw_payload, '{}'::jsonb) || p_candidate, needs_review = true, updated_at = now() where id = v_candidate_id;
    v_status := 'updated';
  end if;

  for v_source in select * from jsonb_array_elements(p_sources) loop
    insert into public.event_candidate_sources (candidate_id, source_name, source_url, source_type, source_excerpt, trust_score, last_accessed)
    select v_candidate_id, v_source->>'source_name', v_source->>'source_url', coalesce(v_source->>'source_type','official'), v_source->>'source_excerpt', coalesce((v_source->>'trust_score')::numeric, 0.90), now()
    where not exists (select 1 from public.event_candidate_sources where candidate_id = v_candidate_id and source_url = v_source->>'source_url');
  end loop;

  update public.atlas_operation_actions set lifecycle_state = 'applied', target_entity_type = 'event_candidate', target_entity_id = v_candidate_id, applied_payload = jsonb_build_object('candidate_id', v_candidate_id, 'status', v_status), after_snapshot = (select to_jsonb(c) from public.event_candidates c where c.id = v_candidate_id), applied_at = now() where id = v_action_id;
  update public.atlas_operation_runs set status = 'succeeded', summary = jsonb_build_object('candidate_id', v_candidate_id, 'status', v_status), completed_at = now() where id = v_run.id;
  return jsonb_build_object('operation_run_id', v_run.id, 'action_id', v_action_id, 'candidate_id', v_candidate_id, 'status', v_status);
exception when others then
  if v_run.id is not null then update public.atlas_operation_runs set status = 'failed', error = jsonb_build_object('message', sqlerrm, 'sqlstate', sqlstate), completed_at = now() where id = v_run.id; end if;
  raise;
end;
$$;

create or replace function public.atlas_record_event_verification(p_actor_type text, p_actor_identity text, p_idempotency_key text, p_event_id uuid, p_occurrence_id uuid, p_verification jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_run public.atlas_operation_runs; v_action_id uuid; v_verification_id uuid;
begin
  perform public.atlas_assert_service_role();
  if nullif(btrim(coalesce(p_verification->>'source_url','')), '') is null then raise exception 'Verification source_url is required'; end if;
  v_run := public.atlas_start_operation('event_verification_recording', p_actor_type, p_actor_identity, p_idempotency_key, p_verification);
  if v_run.completed_at is not null and v_run.status = 'succeeded' then
    return v_run.summary || jsonb_build_object('operation_run_id', v_run.id, 'idempotent_replay', true);
  end if;
  insert into public.atlas_operation_actions (operation_run_id, action_type, target_entity_type, target_entity_id, lifecycle_state, source_references, requested_payload)
  values (v_run.id, 'record_event_verification', 'event', p_event_id, 'proposed', jsonb_build_array(p_verification), p_verification) returning id into v_action_id;
  insert into public.event_verifications (event_id, occurrence_id, verification_source_type, verification_status, verified_by_name, verified_by_role, verification_method, notes, source_url, source_contact, expires_at, recheck_at, overrides_automated_uncertainty, override_reason)
  values (p_event_id, p_occurrence_id, coalesce(p_verification->>'verification_source_type','automated'), coalesce(p_verification->>'verification_status','needs_review'), p_actor_identity, p_actor_type, p_verification->>'verification_method', p_verification->>'notes', p_verification->>'source_url', p_verification->>'source_contact', nullif(p_verification->>'expires_at','')::timestamptz, nullif(p_verification->>'recheck_at','')::timestamptz, coalesce((p_verification->>'overrides_automated_uncertainty')::boolean, false), p_verification->>'override_reason')
  returning id into v_verification_id;
  update public.atlas_operation_actions set lifecycle_state = 'applied', applied_payload = jsonb_build_object('event_verification_id', v_verification_id), after_snapshot = (select to_jsonb(v) from public.event_verifications v where v.id = v_verification_id), applied_at = now() where id = v_action_id;
  update public.atlas_operation_runs set status = 'succeeded', summary = jsonb_build_object('event_verification_id', v_verification_id), completed_at = now() where id = v_run.id;
  return jsonb_build_object('operation_run_id', v_run.id, 'action_id', v_action_id, 'event_verification_id', v_verification_id);
exception when others then
  if v_run.id is not null then update public.atlas_operation_runs set status = 'failed', error = jsonb_build_object('message', sqlerrm, 'sqlstate', sqlstate), completed_at = now() where id = v_run.id; end if;
  raise;
end;
$$;

create or replace function public.atlas_create_review_item(p_actor_type text, p_actor_identity text, p_idempotency_key text, p_review jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_run public.atlas_operation_runs; v_action_id uuid; v_review_id uuid;
begin
  perform public.atlas_assert_service_role();
  v_run := public.atlas_start_operation('review_item_creation', p_actor_type, p_actor_identity, p_idempotency_key, p_review);
  if v_run.completed_at is not null and v_run.status = 'succeeded' then
    return v_run.summary || jsonb_build_object('operation_run_id', v_run.id, 'idempotent_replay', true);
  end if;
  insert into public.atlas_operation_actions (operation_run_id, action_type, target_entity_type, target_entity_id, lifecycle_state, source_references, requested_payload, reason)
  values (v_run.id, 'create_review_item', 'atlas_review_item', nullif(p_review->>'candidate_id','')::uuid, 'proposed', jsonb_build_array(coalesce(p_review->'evidence','{}'::jsonb)), p_review, p_review->>'recommended_action') returning id into v_action_id;
  insert into public.atlas_review_items (operation_run_id, operation_action_id, review_type, event_id, candidate_id, priority, evidence, recommended_action)
  values (v_run.id, v_action_id, p_review->>'review_type', nullif(p_review->>'event_id','')::uuid, nullif(p_review->>'candidate_id','')::uuid, coalesce((p_review->>'priority')::integer, 50), coalesce(p_review->'evidence','{}'::jsonb), p_review->>'recommended_action') returning id into v_review_id;
  update public.atlas_operation_actions set lifecycle_state = 'applied', target_entity_id = v_review_id, applied_payload = jsonb_build_object('review_item_id', v_review_id), after_snapshot = (select to_jsonb(r) from public.atlas_review_items r where r.id = v_review_id), applied_at = now() where id = v_action_id;
  update public.atlas_operation_runs set status = 'succeeded', summary = jsonb_build_object('review_item_id', v_review_id), completed_at = now() where id = v_run.id;
  return jsonb_build_object('operation_run_id', v_run.id, 'action_id', v_action_id, 'review_item_id', v_review_id);
end;
$$;

create or replace function public.atlas_disposition_candidate(p_actor_type text, p_actor_identity text, p_idempotency_key text, p_candidate_id uuid, p_disposition text, p_matched_event_id uuid default null, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_run public.atlas_operation_runs; v_action_id uuid; v_before jsonb;
begin
  perform public.atlas_assert_service_role();
  if p_disposition not in ('matched', 'duplicate', 'rejected', 'ready_for_promotion') then raise exception 'Unsupported candidate disposition'; end if;
  select to_jsonb(c) into v_before from public.event_candidates c where c.id = p_candidate_id for update;
  if v_before is null then raise exception 'Candidate not found'; end if;
  v_run := public.atlas_start_operation('candidate_disposition', p_actor_type, p_actor_identity, p_idempotency_key, jsonb_build_object('candidate_id', p_candidate_id, 'disposition', p_disposition, 'matched_event_id', p_matched_event_id, 'reason', p_reason));
  if v_run.completed_at is not null and v_run.status = 'succeeded' then
    return v_run.summary || jsonb_build_object('operation_run_id', v_run.id, 'idempotent_replay', true);
  end if;
  insert into public.atlas_operation_actions (operation_run_id, action_type, target_entity_type, target_entity_id, lifecycle_state, before_snapshot, requested_payload, reason)
  values (v_run.id, 'candidate_disposition', 'event_candidate', p_candidate_id, 'proposed', v_before, jsonb_build_object('disposition', p_disposition, 'matched_event_id', p_matched_event_id), p_reason) returning id into v_action_id;
  update public.event_candidates set
    verification_status = case p_disposition when 'rejected' then 'rejected' when 'ready_for_promotion' then 'verified' else verification_status end,
    duplicate_status = case p_disposition when 'matched' then 'possible_duplicate' when 'duplicate' then 'duplicate' else duplicate_status end,
    matched_event_id = case when p_disposition in ('matched','duplicate') then p_matched_event_id else matched_event_id end,
    needs_review = p_disposition <> 'ready_for_promotion',
    semantic_notes = concat_ws(E'\n', semantic_notes, p_reason),
    updated_at = now()
  where id = p_candidate_id;
  update public.atlas_operation_actions set lifecycle_state = 'applied', applied_payload = jsonb_build_object('disposition', p_disposition), after_snapshot = (select to_jsonb(c) from public.event_candidates c where c.id = p_candidate_id), applied_at = now() where id = v_action_id;
  update public.atlas_operation_runs set status = 'succeeded', summary = jsonb_build_object('candidate_id', p_candidate_id, 'disposition', p_disposition), completed_at = now() where id = v_run.id;
  return jsonb_build_object('operation_run_id', v_run.id, 'action_id', v_action_id, 'candidate_id', p_candidate_id, 'disposition', p_disposition);
end;
$$;

revoke all on table public.atlas_operation_runs from anon, authenticated;
revoke all on table public.atlas_operation_actions from anon, authenticated;
revoke all on table public.atlas_review_items from anon, authenticated;
revoke execute on function public.atlas_assert_service_role() from public, anon, authenticated;
revoke execute on function public.atlas_require_source_evidence(jsonb) from public, anon, authenticated;
revoke execute on function public.atlas_start_operation(text, text, text, text, jsonb) from public, anon, authenticated;
revoke execute on function public.atlas_intake_event_candidate(text, text, text, jsonb, jsonb) from public, anon, authenticated;
revoke execute on function public.atlas_record_event_verification(text, text, text, uuid, uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.atlas_create_review_item(text, text, text, jsonb) from public, anon, authenticated;
revoke execute on function public.atlas_disposition_candidate(text, text, text, uuid, text, uuid, text) from public, anon, authenticated;
grant execute on function public.atlas_start_operation(text, text, text, text, jsonb) to service_role;
grant execute on function public.atlas_intake_event_candidate(text, text, text, jsonb, jsonb) to service_role;
grant execute on function public.atlas_record_event_verification(text, text, text, uuid, uuid, jsonb) to service_role;
grant execute on function public.atlas_create_review_item(text, text, text, jsonb) to service_role;
grant execute on function public.atlas_disposition_candidate(text, text, text, uuid, text, uuid, text) to service_role;
