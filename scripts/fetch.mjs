import fs from 'node:fs/promises';

const API = 'https://api.amediateka.tech/gateway/v1/cms/content/series/';
const SITE = 'https://www.amediateka.ru';
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36';
const DATA_FILE = new URL('../data/series.json', import.meta.url);

const clean = s => String(s ?? '').replace(/\s+/g, ' ').trim();
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function getJSON(url, tries = 3) {
  let lastError;
  for (let i = 0; i < tries; i++) {
    try {
      const r = await fetch(url, {
        headers: { 'User-Agent': UA, Accept: 'application/json' },
        signal: AbortSignal.timeout(30000)
      });
      if (r.status === 429) {
        await sleep(2000 * (i + 1));
        continue;
      }
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return await r.json();
    } catch (e) {
      lastError = e;
      if (i < tries - 1) await sleep(500 * (i + 1));
    }
  }
  throw lastError;
}

async function headStatus(url) {
  for (let i = 0; i < 2; i++) {
    try {
      const r = await fetch(url, {
        method: 'HEAD',
        headers: { 'User-Agent': UA },
        signal: AbortSignal.timeout(20000)
      });
      if (r.status === 404 || r.status === 403) return 'missing';
      if (r.ok) return 'ok';
    } catch (e) { /* retry */ }
    await sleep(300);
  }
  return 'error';
}

async function pool(items, limit, fn) {
  const out = new Array(items.length);
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (true) {
      const i = next++;
      if (i >= items.length) return;
      out[i] = await fn(items[i], i);
    }
  });
  await Promise.all(workers);
  return out;
}

function posterCandidates(assets) {
  if (!assets) return [];
  return ['productPosterV2', 'v_poster', 'productPoster', 'partnersPoster', 'productItemCover']
    .map(k => [k, assets[k]])
    .filter(([, u]) => u)
    .map(([k, u]) => [k, String(u).replace('{SIZE}', '400x600')]);
}

async function resolvePoster(assets) {
  let optimistic = null;
  for (const [key, url] of posterCandidates(assets)) {
    const status = await headStatus(url);
    if (status === 'ok') return { url, asset: key };
    if (status === 'error') {
      optimistic = { url, asset: key + '-unverified' };
      break;
    }
  }
  return optimistic;
}

async function loadAll() {
  const first = await getJSON(API + '?limit=100');
  const count = first.count;
  const pages = Math.ceil(count / 100);
  const raw = [...first.results];
  for (let p = 1; p < pages; p++) {
    const page = await getJSON(API + `?limit=100&offset=${p * 100}`);
    raw.push(...page.results);
  }
  const seen = new Set();
  return raw.filter(s => (seen.has(s.id) ? false : (seen.add(s.id), true)));
}

const startedAt = new Date();
console.log('Fetching series list...');
const list = await loadAll();
console.log(`Series in catalog: ${list.length}`);

console.log('Fetching details (countries, ratings, descriptions)...');
let detailFailures = 0;
let ratingChanges = 0;
await pool(list, 8, async s => {
  try {
    const d = await getJSON(API + s.id + '/');
    const diff = [
      ['ratingAmediateka', s.ratingAmediateka, d.ratingAmediateka],
      ['ratingImdb', s.ratingImdb, d.ratingImdb],
      ['ratingKinopoisk', s.ratingKinopoisk, d.ratingKinopoisk]
    ].filter(([, a, b]) => String(a ?? '') !== String(b ?? ''));
    if (diff.length) ratingChanges++;
    s.detail = d;
  } catch (e) {
    detailFailures++;
    console.warn(`  detail failed: ${s.title} (${s.id}): ${e.message}`);
  }
});
console.log(`Details: ${list.length - detailFailures}/${list.length}, rating changes: ${ratingChanges}`);

console.log('Checking posters...');
const items = await pool(list, 24, async s => {
  const src = s.detail || s;
  const poster = await resolvePoster(src.assets || s.assets);
  const countries = ((s.detail && s.detail.countries) || []).map(c => clean(c.name)).filter(Boolean);
  const genres = ((s.detail && s.detail.genres) || s.genres || []).map(g => clean(g.name)).filter(Boolean);
  const detailSeasons = s.detail && s.detail.seasons;
  const seasons = typeof s.seasons === 'number'
    ? s.seasons
    : (Array.isArray(detailSeasons) ? detailSeasons.length : null);
  return {
    id: s.id,
    title: clean(src.title || s.title),
    slug: s.slug,
    url: SITE + (src.webUrl || s.webUrl || `/watch/series_${s.id}_${s.slug}`),
    year: src.premierYear ?? s.premierYear ?? null,
    seasons,
    genres,
    countries,
    am: src.ratingAmediateka ? String(src.ratingAmediateka) : null,
    imdb: src.ratingImdb ? String(src.ratingImdb) : null,
    kp: src.ratingKinopoisk ? String(src.ratingKinopoisk) : null,
    desc: clean(src.shortDescription || s.shortDescription),
    poster: poster ? poster.url : null,
    posterAsset: poster ? poster.asset : null
  };
});

items.sort((a, b) => a.id - b.id);

let previous = null;
try {
  previous = JSON.parse(await fs.readFile(DATA_FILE, 'utf8'));
} catch (e) { /* first run */ }

if (previous && Array.isArray(previous.items)) {
  const oldIds = new Set(previous.items.map(s => s.id));
  const newIds = new Set(items.map(s => s.id));
  const added = items.filter(s => !oldIds.has(s.id));
  const removed = previous.items.filter(s => !newIds.has(s.id));
  console.log(`Diff vs previous snapshot: +${added.length} / -${removed.length}`);
  for (const s of added) console.log(`  + ${s.title} (${s.year}) AM ${s.am ?? '—'}`);
  for (const s of removed) console.log(`  - ${s.title} (${s.year}) AM ${s.am ?? '—'}`);
}

const withCountries = items.filter(s => s.countries.length).length;
const withPoster = items.filter(s => s.poster).length;
const payload = {
  source: API,
  updatedAt: new Date().toISOString(),
  count: items.length,
  countries: [...new Set(items.flatMap(s => s.countries))].sort((a, b) => a.localeCompare(b, 'ru')),
  items
};

await fs.writeFile(DATA_FILE, JSON.stringify(payload, null, 2) + '\n', 'utf8');
console.log(`Saved ${DATA_FILE.pathname}: ${items.length} series, ${withCountries} with countries, ${withPoster} with poster`);
console.log(`Elapsed: ${Math.round((Date.now() - startedAt.getTime()) / 1000)}s`);
if (detailFailures) console.warn(`WARN: ${detailFailures} detail requests failed; countries may be missing for those series`);
