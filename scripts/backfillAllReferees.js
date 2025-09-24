require('dotenv').config();
const { Pool } = require('pg');
const { fetchEntities } = require('../src/sportmonks.js');

const pool = new Pool({
  connectionString: process.env.SUPABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function insertReferee(referee) {
  const dateOfBirth = referee.date_of_birth ? new Date(referee.date_of_birth).toISOString() : null;
  const query = `
    INSERT INTO public.referees (id, sport_id, country_id, city_id, common_name, firstname, lastname, name, display_name, image_path, date_of_birth, gender)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
    ON CONFLICT (id) DO UPDATE SET
      country_id = EXCLUDED.country_id,
      city_id = EXCLUDED.city_id,
      common_name = EXCLUDED.common_name,
      firstname = EXCLUDED.firstname,
      lastname = EXCLUDED.lastname,
      name = EXCLUDED.name,
      display_name = EXCLUDED.display_name,
      image_path = EXCLUDED.image_path,
      date_of_birth = EXCLUDED.date_of_birth,
      gender = EXCLUDED.gender,
      updated_at = NOW()
  `;
  const values = [
    referee.id,
    1,
    referee.country_id || null,
    referee.city_id || null,
    referee.common_name || null,
    referee.firstname || null,
    referee.lastname || null,
    referee.name || null,
    referee.display_name || null,
    referee.image_path || null,
    dateOfBirth,
    referee.gender || null
  ];
  await pool.query(query, values);
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
      try {
        await insertReferee(referee);
        totalInserted++;
      } catch (error) {
        console.error(`Error inserting referee ${referee.id}: ${error.message} - Full: ${JSON.stringify(error)}`);
      }
    }

    totalFetched += referees.length;
    console.log(`Page ${page}: Fetched ${referees.length}, total ${totalFetched}, inserted ${totalInserted}`);

    await new Promise(resolve => setTimeout(resolve, 1000));

    if (referees.length < 50) break;
    page++;
  }

  console.log(`Backfill complete: Fetched ${totalFetched}, inserted/updated ${totalInserted}`);
  await pool.end();
}

backfillAllReferees().catch(console.error);
