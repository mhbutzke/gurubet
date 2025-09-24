-- Create alias view v2_fast2 and update predictions to use it

create or replace view analytics.v_fixtures_upcoming_v2_fast2 as
select * from analytics.mv_fixtures_upcoming_v2_compact;

-- Pred ficará em migration posterior após a MV compact estar garantida


