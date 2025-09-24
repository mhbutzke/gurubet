const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

async function insertReferee(referee) {
  const dateOfBirth = referee.date_of_birth ? new Date(referee.date_of_birth).toISOString() : null;
  const refData = {
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
    date_of_birth: dateOfBirth,
    gender: referee.gender || null
  };

  let retry = 3;
  while (retry > 0) {
    try {
      const { error } = await supabase.from('referees').upsert(refData);
      if (!error) {
        return;  // Success
      }
      console.error(`Upsert failed for referee ${referee.id}: ${error.message}`);
      retry--;
      if (retry > 0) await new Promise(r => setTimeout(r, 1000));
    } catch (error) {
      console.error(`Error inserting referee ${referee.id}: ${error.message} - Full: ${JSON.stringify(error)}`);
      retry--;
      if (retry > 0) await new Promise(r => setTimeout(r, 1000));
    }
  }
}

async function backfillAllReferees() {
  let page = 1;
  let totalFetched = 0;
  let totalInserted = 0;

  while (true) {
    console.log(`Fetching referees page ${page}...`);
    const referees = await fetchEntities('football/referees', { perPage: 50, page });
    
    if (referees.length === 0) break;

    for (const referee of referees) {
      await insertReferee(referee);
      totalInserted++;
    }

    totalFetched += referees.length;
    console.log(`Page ${page}: Fetched ${referees.length}, total ${totalFetched}, inserted ${totalInserted}`);

    await new Promise(resolve => setTimeout(resolve, 1000));

    if (referees.length < 50) break;
    page++;
  }

  console.log(`Backfill complete: Fetched ${totalFetched}, inserted/updated ${totalInserted}`);
  await supabase.auth.getUser();  // Close? Not needed for client
}

backfillAllReferees().catch(console.error);
