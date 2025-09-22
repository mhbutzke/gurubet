-- Allow nullable stage_id and state_id to match API output
alter table public.fixtures
  alter column stage_id drop not null,
  alter column state_id drop not null;
