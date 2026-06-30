-- Operational seed: Romeo Peach Festival 2026 occurrence and Celebration Atlas verification.
--
-- Purpose:
--   Creates or updates exactly one dated occurrence for the canonical Romeo
--   Peach Festival event and one source-backed Celebration Atlas manual
--   verification for that occurrence.
--
-- Evidence checked before authoring:
--   - Live canonical event row:
--       id   = 79fab78b-0a08-4439-8cc0-470281d69fb6
--       slug = romeo-peach-festival
--       name = Romeo Peach Festival
--       city = Romeo, state = Michigan
--   - Existing event_sources row for the official website:
--       https://www.romeopeachfestival.com
--   - Official website text reviewed on 2026-06-30 states the 95th Anniversary
--     Romeo Peach Festival is Thursday, Sept. 3 through Labor Day, Sept. 7, 2026.
--
-- Safe to run more than once in Supabase SQL Editor after
-- 002_create_event_occurrences_and_verifications.sql has been applied.

begin;

do $$
declare
  v_event_id constant uuid := '79fab78b-0a08-4439-8cc0-470281d69fb6'::uuid;
  v_slug constant text := 'romeo-peach-festival';
  v_name constant text := 'Romeo Peach Festival';
  v_official_url constant text := 'https://www.romeopeachfestival.com';
  v_occurrence_id uuid;
  v_conflicting_occurrences integer;
  v_matching_occurrences integer;
  v_matching_verifications integer;
begin
  if not exists (
    select 1
    from public.events e
    where e.id = v_event_id
      and e.slug = v_slug
      and e.name = v_name
      and e.city = 'Romeo'
      and e.state = 'Michigan'
  ) then
    raise exception 'Canonical Romeo Peach Festival event identity was not found with expected id %, slug %, name %, city/state Romeo, Michigan.', v_event_id, v_slug, v_name;
  end if;

  if not exists (
    select 1
    from public.event_sources s
    where s.event_id = v_event_id
      and s.source_url = v_official_url
  ) then
    raise exception 'Expected official Romeo Peach Festival source URL % was not found for event_id %.', v_official_url, v_event_id;
  end if;

  select count(*)
    into v_conflicting_occurrences
  from public.event_occurrences o
  where o.event_id = v_event_id
    and o.occurrence_label = '2026'
    and (
      o.start_date is distinct from date '2026-09-03'
      or o.end_date is distinct from date '2026-09-07'
    );

  if v_conflicting_occurrences > 0 then
    raise exception 'Refusing to seed Romeo Peach Festival 2026 because a conflicting 2026 occurrence already exists for event_id %.', v_event_id;
  end if;

  select count(*)
    into v_matching_occurrences
  from public.event_occurrences o
  where o.event_id = v_event_id
    and o.occurrence_label = '2026'
    and o.start_date = date '2026-09-03'
    and o.end_date = date '2026-09-07';

  if v_matching_occurrences > 1 then
    raise exception 'Refusing to continue because multiple matching Romeo 2026 occurrence rows already exist for event_id %.', v_event_id;
  end if;

  update public.event_occurrences
  set
    occurrence_status = 'confirmed',
    venue_name = null,
    city = 'Romeo',
    state = 'Michigan',
    display_until = timestamptz '2026-09-08 00:00:00+00',
    recheck_at = timestamptz '2026-08-17 00:00:00+00',
    notes = 'Seeded from manual Celebration Atlas review of the official Romeo Peach Festival website, which listed the 95th Anniversary festival as Thursday, Sept. 3 through Labor Day, Sept. 7, 2026.'
  where event_id = v_event_id
    and occurrence_label = '2026'
    and start_date = date '2026-09-03'
    and end_date = date '2026-09-07'
  returning id into v_occurrence_id;

  if v_occurrence_id is null then
    insert into public.event_occurrences (
      event_id,
      occurrence_label,
      start_date,
      end_date,
      occurrence_status,
      venue_name,
      city,
      state,
      display_until,
      recheck_at,
      notes
    ) values (
      v_event_id,
      '2026',
      date '2026-09-03',
      date '2026-09-07',
      'confirmed',
      null,
      'Romeo',
      'Michigan',
      timestamptz '2026-09-08 00:00:00+00',
      timestamptz '2026-08-17 00:00:00+00',
      'Seeded from manual Celebration Atlas review of the official Romeo Peach Festival website, which listed the 95th Anniversary festival as Thursday, Sept. 3 through Labor Day, Sept. 7, 2026.'
    )
    returning id into v_occurrence_id;
  end if;

  select count(*)
    into v_matching_verifications
  from public.event_verifications v
  where v.event_id = v_event_id
    and v.occurrence_id = v_occurrence_id
    and v.verification_source_type = 'celebration_atlas_manual'
    and v.verified_by_name = 'Ray'
    and v.verified_by_role = 'Celebration Atlas reviewer';

  if v_matching_verifications > 1 then
    raise exception 'Refusing to continue because multiple matching Romeo 2026 manual verification rows already exist for occurrence_id %.', v_occurrence_id;
  end if;

  update public.event_verifications
  set
    verification_status = 'verified',
    verification_method = 'Manual review of the official Romeo Peach Festival website for the published 2026 festival date range.',
    source_url = v_official_url,
    source_contact = null,
    expires_at = timestamptz '2026-09-08 00:00:00+00',
    recheck_at = timestamptz '2026-08-17 00:00:00+00',
    overrides_automated_uncertainty = true,
    override_reason = 'Manual official-source review confirmed the upcoming dated 2026 occurrence.',
    notes = 'Official website reviewed on 2026-06-30: 95th Anniversary Romeo Peach Festival listed for Thursday, Sept. 3 through Labor Day, Sept. 7, 2026.'
  where event_id = v_event_id
    and occurrence_id = v_occurrence_id
    and verification_source_type = 'celebration_atlas_manual'
    and verified_by_name = 'Ray'
    and verified_by_role = 'Celebration Atlas reviewer';

  if not found then
    insert into public.event_verifications (
      event_id,
      occurrence_id,
      verification_source_type,
      verification_status,
      verified_by_name,
      verified_by_role,
      verified_at,
      verification_method,
      notes,
      source_url,
      source_contact,
      expires_at,
      recheck_at,
      overrides_automated_uncertainty,
      override_reason
    ) values (
      v_event_id,
      v_occurrence_id,
      'celebration_atlas_manual',
      'verified',
      'Ray',
      'Celebration Atlas reviewer',
      timestamptz '2026-06-30 00:00:00+00',
      'Manual review of the official Romeo Peach Festival website for the published 2026 festival date range.',
      'Official website reviewed on 2026-06-30: 95th Anniversary Romeo Peach Festival listed for Thursday, Sept. 3 through Labor Day, Sept. 7, 2026.',
      v_official_url,
      null,
      timestamptz '2026-09-08 00:00:00+00',
      timestamptz '2026-08-17 00:00:00+00',
      true,
      'Manual official-source review confirmed the upcoming dated 2026 occurrence.'
    );
  end if;
end $$;

commit;
