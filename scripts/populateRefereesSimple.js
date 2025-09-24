require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const SPORTMONKS_API_KEY = process.env.SPORTMONKS_API_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !SPORTMONKS_API_KEY) {
  throw new Error('Missing SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, or SPORTMONKS_API_KEY in .env');
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const BASE_URL = 'https://api.sportmonks.com/v3';
const PER_PAGE = 50;
const DELAY_MS = 1000;  // Rate limit delay

async function fetchPage(page) {
  const url = new URL(`${BASE_URL}/football/referees`);
  url.searchParams.append('api_token', SPORTMONKS_API_KEY);
  url.searchParams.append('per_page', PER_PAGE);
  url.searchParams.append('page', page);

  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`API Error ${response.status}: ${await response.text()}`);
  }
  const data = await response.json();
  return data.data || [];
}

async function upsertReferee(referee) {
  const { error } = await supabase
    .from('referees')
    .upsert({
      id: referee.id,
      sport_id: 1,
      country_id: referee.country_id || null,
      city_id: referee.city_id || null,
      common_name: referee.common_name || null,
      firstname: referee.firstname || null,
      lastname: referee.lastname || null,
      name: referee.name || null,
      display_name: referee.display_name || null,
      image_path: referee.image_path || null,
      date_of_birth: referee.date_of_birth ? new Date(referee.date_of_birth).toISOString() : null,
      gender: referee.gender || null,
      updated_at: new Date().toISOString()
    }, { onConflict: 'id' });

  if (error) {
    console.error(`Upsert error for referee ${referee.id}: ${error.message}`);
  }
}

async function populateReferees() {
  let page = 1;
  let totalFetched = 0;
  let totalUpserts = 0;
  let totalErrors = 0;

  while (true) {
    console.log(`Fetching page ${page}...`);
    const referees = await fetchPage(page);

    if (referees.length === 0) {
      console.log('No more referees to fetch.');
      break;
    }

    for (const referee of referees) {
      try {
        await upsertReferee(referee);
        totalUpserts++;
      } catch (error) {
        console.error(`Error upserting referee ${referee.id}: ${error.message}`);
        totalErrors++;
      }
    }

    totalFetched += referees.length;
    console.log(`Page ${page}: Fetched ${referees.length}, total ${totalFetched}, upserts ${totalUpserts}, errors ${totalErrors}`);

    // Delay for rate limit
    await new Promise(resolve => setTimeout(resolve, DELAY_MS));

    if (referees.length < PER_PAGE) break;
    page++;
  }

  console.log(`Populate complete: Fetched ${totalFetched}, upserts ${totalUpserts}, errors ${totalErrors}`);
}

populateReferees().catch(console.error);
