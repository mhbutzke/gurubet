require('dotenv').config();

const [, , endpoint, perPageArg] = process.argv;

if (!endpoint) {
  console.error('Uso: node scripts/inspectEndpoint.js <endpoint> [perPage]');
  process.exit(1);
}

const token = process.env.SPORTMONKS_API_KEY;
if (!token) {
  console.error('SPORTMONKS_API_KEY não configurado.');
  process.exit(1);
}

async function inspectEndpoint(path, perPage) {
  const url = new URL(`https://api.sportmonks.com/v3/${path}`);
  url.searchParams.set('api_token', token);
  if (perPage) {
    url.searchParams.set('per_page', perPage);
  }

  const response = await fetch(url);
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Falha (${response.status}): ${body}`);
  }

  const payload = await response.json();
  const items = payload.data ?? [];
  const meta = payload.meta ?? null;
  const fieldSet = new Set();

  for (const item of items) {
    Object.keys(item).forEach((key) => fieldSet.add(key));
  }

  return {
    url: url.toString(),
    meta,
    sample: items[0] ?? null,
    fields: [...fieldSet].sort(),
    count: items.length,
  };
}

inspectEndpoint(endpoint, perPageArg)
  .then((result) => {
    console.log(JSON.stringify(result, null, 2));
  })
  .catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
