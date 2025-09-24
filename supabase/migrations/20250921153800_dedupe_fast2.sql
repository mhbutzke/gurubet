-- Deduplicate fixtures in fast2 view (one row per fixture id)

create or replace view analytics.v_fixtures_upcoming_v2_fast2 as
select distinct on (id) *
from analytics.mv_fixtures_upcoming_v2_compact
order by id, referee_id nulls last;


