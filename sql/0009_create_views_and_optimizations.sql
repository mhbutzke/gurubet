-- Views e otimizações para o sistema GURUBET expandido
-- Facilita consultas e melhora performance

-- View agregada com participantes e nomes dos times
create or replace view public.v_fixtures_with_participants as
select
  f.id,
  f.name,
  f.starting_at,
  l.name as league_name,
  s.name as state_name,
  coalesce(
    json_agg(
      json_build_object(
        'participant_id', fp.participant_id,
        'team_name', t.name,
        'location', fp.location,
        'winner', fp.winner,
        'position', fp.position,
        'meta', fp.meta
      ) order by coalesce(
        fp.position,
        case
          when lower(coalesce(fp.location, '')) = 'home' then 1
          when lower(coalesce(fp.location, '')) = 'away' then 2
          else 99
        end
      )
    ) filter (where fp.participant_id is not null),
    '[]'::json
  ) as participants,
  coalesce(
    string_agg(
      coalesce(t.name, 'TBD'),
      ' x '
      order by coalesce(
        fp.position,
        case
          when lower(coalesce(fp.location, '')) = 'home' then 1
          when lower(coalesce(fp.location, '')) = 'away' then 2
          else 99
        end
      )
    ),
    ''
  ) as teams
from public.fixtures f
left join public.fixture_participants fp on fp.fixture_id = f.id
left join public.teams t on t.id = fp.participant_id
left join public.leagues l on l.id = f.league_id
left join public.states s on s.id = f.state_id
group by f.id, f.name, f.starting_at, l.name, s.name;

-- View para fixtures completas com participantes e contadores
create or replace view public.v_fixtures_complete as
select 
  f.id,
  f.name,
  f.starting_at,
  f.state_id,
  s.name as state_name,
  f.league_id,
  l.name as league_name,
  f.season_id,
  se.name as season_name,
  f.venue_id,
  v.name as venue_name,
  v.city_name as venue_city,
  coalesce(vfp.participants, '[]'::json) as participants,
  coalesce(vfp.teams, '') as teams,
  (select count(*) from public.fixture_events fe where fe.fixture_id = f.id) as events_count,
  (select count(*) from public.fixture_statistics fs where fs.fixture_id = f.id) as statistics_count,
  f.created_at,
  f.updated_at
from public.fixtures f
left join public.states s on f.state_id = s.id
left join public.leagues l on f.league_id = l.id  
left join public.seasons se on f.season_id = se.id
left join public.venues v on f.venue_id = v.id
left join public.v_fixtures_with_participants vfp on vfp.id = f.id;

-- View para fixtures de hoje
create or replace view public.v_fixtures_today as
select * from public.v_fixtures_complete
where starting_at::date = current_date
order by starting_at;

-- View para fixtures desta semana
create or replace view public.v_fixtures_this_week as
select * from public.v_fixtures_complete
where starting_at >= date_trunc('week', current_date)
  and starting_at < date_trunc('week', current_date) + interval '7 days'
order by starting_at;

-- View para estatísticas de eventos por fixture
create or replace view public.v_fixture_events_summary as
select 
  fe.fixture_id,
  f.name as fixture_name,
  f.starting_at,
  count(*) as total_events,
  count(*) filter (
    where upper(coalesce(ct.developer_name, '')) = 'GOAL'
  ) as goals,
  count(*) filter (
    where upper(coalesce(ct.developer_name, '')) in (
      'YELLOWCARD',
      'SECONDYELLOW',
      'SECOND_YELLOW'
    )
  ) as yellow_cards,
  count(*) filter (
    where upper(coalesce(ct.developer_name, '')) in (
      'REDCARD',
      'YELLOWREDCARD',
      'DIRECTRED'
    )
  ) as red_cards,
  count(*) filter (
    where upper(coalesce(ct.developer_name, '')) like 'SUBSTITUTION%'
  ) as substitutions,
  json_agg(
    json_build_object(
      'minute', fe.minute,
      'type', ct.name,
      'player_name', fe.player_name,
      'participant_id', fe.participant_id
    ) order by fe.minute
  ) as events_timeline
from public.fixture_events fe
join public.fixtures f on fe.fixture_id = f.id
left join public.core_types ct on fe.type_id = ct.id
group by fe.fixture_id, f.name, f.starting_at;

-- View para relatório de ingestão
create or replace view public.v_ingestion_summary as
select 
  entity,
  count(*) as total_runs,
  count(*) filter (where status = 'success') as successful_runs,
  count(*) filter (where status = 'error') as failed_runs,
  sum(processed_count) as total_processed,
  max(started_at) as last_run,
  avg(
    extract(epoch from (finished_at - started_at))
  )::int as avg_duration_seconds
from public.ingestion_runs
where started_at >= current_date - interval '30 days'
group by entity
order by last_run desc;

-- Índices adicionais para performance
create index if not exists fixtures_starting_at_state_idx on public.fixtures (starting_at, state_id);
create index if not exists fixtures_league_season_idx on public.fixtures (league_id, season_id);
create index if not exists fixture_events_minute_idx on public.fixture_events (fixture_id, minute);
create index if not exists fixture_events_type_participant_idx on public.fixture_events (type_id, participant_id);
create index if not exists fixture_statistics_type_participant_idx on public.fixture_statistics (type_id, participant_id);

-- Índices para as novas tabelas
create index if not exists fixture_participants_meta_idx on public.fixture_participants using gin (meta);

-- Função para estatísticas rápidas
create or replace function public.get_fixture_stats(fixture_id_param bigint)
returns json as $$
declare
  result json;
begin
  select json_build_object(
    'fixture_id', fixture_id_param,
    'participants', (
      select count(*) from public.fixture_participants 
      where fixture_id = fixture_id_param
    ),
    'events', (
      select count(*) from public.fixture_events 
      where fixture_id = fixture_id_param
    ),
    'statistics', (
      select count(*) from public.fixture_statistics 
      where fixture_id = fixture_id_param
    ),
    'goals', (
      select count(*) from public.fixture_events fe
      join public.core_types ct on fe.type_id = ct.id
      where fe.fixture_id = fixture_id_param 
        and ct.developer_name = 'GOAL'
    ),
    'cards', (
      select count(*) from public.fixture_events fe
      join public.core_types ct on fe.type_id = ct.id
      where fe.fixture_id = fixture_id_param 
        and ct.developer_name in ('YELLOW_CARD', 'RED_CARD')
    )
  ) into result;
  
  return result;
end;
$$ language plpgsql;

-- Função para buscar fixtures por time
create or replace function public.get_team_fixtures(
  team_id_param bigint,
  limit_param int default 10
)
returns table (
  fixture_id bigint,
  fixture_name text,
  starting_at timestamptz,
  location text,
  opponent_name text,
  state_name text
) as $$
begin
  return query
  select 
    f.id,
    f.name,
    f.starting_at,
    coalesce(fp.location, fp.meta->>'location') as location,
    coalesce(t_opponent.name, 'TBD') as opponent_name,
    s.name as state_name
  from public.fixtures f
  join public.fixture_participants fp on f.id = fp.fixture_id
  left join public.fixture_participants fp_opponent on f.id = fp_opponent.fixture_id 
    and fp_opponent.participant_id != team_id_param
  left join public.teams t_opponent on fp_opponent.participant_id = t_opponent.id
  left join public.states s on f.state_id = s.id
  where fp.participant_id = team_id_param
  order by f.starting_at desc
  limit limit_param;
end;
$$ language plpgsql;

-- Comentários para documentação
comment on view public.v_fixtures_with_participants is 'Fixtures com participantes agregados e string dos times.';
comment on view public.v_fixtures_complete is 'View completa de fixtures com participantes e contadores';
comment on view public.v_fixtures_today is 'Fixtures de hoje com informações completas';
comment on view public.v_fixtures_this_week is 'Fixtures desta semana com informações completas';
comment on view public.v_fixture_events_summary is 'Resumo de eventos por fixture com timeline';
comment on view public.v_ingestion_summary is 'Relatório de execuções de ingestão dos últimos 30 dias';
comment on function public.get_fixture_stats(bigint) is 'Retorna estatísticas rápidas de uma fixture';
comment on function public.get_team_fixtures(bigint, int) is 'Retorna fixtures de um time específico';
