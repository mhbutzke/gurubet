import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const supabase = createClient(supabaseUrl, supabaseServiceKey)

serve(async (req) => {
  const { fixtureId } = await req.json()
  if (!fixtureId) return new Response(JSON.stringify({ error: 'fixtureId required' }), { status: 400 })

  // Query features from views
  const { data: fixture } = await supabase.from('v_fixtures_upcoming_v2').select('*').eq('id', fixtureId).single()
  if (!fixture) return new Response(JSON.stringify({ error: 'Fixture not found' }), { status: 404 })

  const { data: weights } = await supabase.from('prediction_weights').select('*').eq('league_id', fixture.league_id).single()
  if (!weights) return new Response(JSON.stringify({ error: 'Weights not found' }), { status: 404 })

  // Linear regression: predicted = w_home * home_avg + w_away * away_avg + w_ref * ref_avg + w_h2h * h2h_avg + w_weather * weather_mod + intercept
  const intercept = 2.5  // Base from historical avg
  const weather_mod = (fixture.humidity > 80 || fixture.condition_code?.includes('rain')) ? weights.w_weather : 0
  const predicted_cards = (
    weights.w_home_all * fixture.home_cards_avg_all +
    weights.w_opp_all * fixture.away_cards_avg_all +
    weights.w_ref * fixture.referee_cards_avg +
    weights.w_h2h * COALESCE(fixture.h2h_cards_avg, 0) +
    weather_mod
  ) + intercept

  const over_4_5_prob = 1 / (1 + Math.exp(-(predicted_cards - 4.5)))  // Sigmoid for prob

  return new Response(JSON.stringify({
    fixture_id: fixtureId,
    predicted_cards,
    over_4_5_prob,
    under_4_5_prob: 1 - over_4_5_prob
  }), { headers: { 'Content-Type': 'application/json' } })
})
