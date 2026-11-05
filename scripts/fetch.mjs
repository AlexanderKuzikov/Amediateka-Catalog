import fs from 'node:fs/promises';

const BASE = 'https://api.amediateka.tech/gateway/v1/cms/content/';
const SITE = 'https://www.amediateka.ru';
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36';
const DATA_FILE = new URL('../data/catalog.json', import.meta.url);
const SOURCES = [
  { kind: 'series', path: 'series' },
  { kind: 'movie', path: 'movies' }
];

const clean = s => String(s ?? '').replace(/\s+/g, ' ').trim();
const HEADERS = {
  'User-Agent': UA,
  Accept: 'application/json, text/plain, */*',
  'Accept-Language': 'ru-RU,ru;q=0.9,en;q=0.8',
  Origin: 'https://www.amediateka.ru',
  Referer: 'https://www.amediateka.ru/'
};
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function getJSON(url, tries = 3) {
  let lastError;
  for (let i = 0; i < tries; i++) {
    try {
      const r = await fetch(url, {
        headers: HEADERS,
        signal: AbortSignal.timeout(30000)
      });
      if (r.status === 429) {
        await sleep(2000 * (i + 1));
        continue;
      }
      if (!r.ok) {
        let body = '';
        try { body = (await r.text()).slice(0, 300); } catch (e) { /* ignore */ }
        throw new Error('HTTP ' + r.status + (body ? ' ' + body : ''));
      }
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

async function loadAll(source) {
  const endpoint = BASE + source.path + '/';
  const first = await getJSON(endpoint + '?limit=100');
  const count = first.count;
  const pages = Math.ceil(count / 100);
  const raw = [...first.results];
  for (let p = 1; p < pages; p++) {
    const page = await getJSON(endpoint + `?limit=100&offset=${p * 100}`);
    raw.push(...page.results);
  }
  const seen = new Set();
  const items = raw.filter(s => (seen.has(s.id) ? false : (seen.add(s.id), true)));
  return items.map(s => ({ ...s, kind: source.kind }));
}

const startedAt = new Date();
console.log('Fetching series and movies lists...');
const lists = {};
for (const source of SOURCES) {
  lists[source.kind] = await loadAll(source);
  console.log(`  ${source.kind}: ${lists[source.kind].length}`);
}
const list = SOURCES.flatMap(source => lists[source.kind]);

let previous = null;
try {
  previous = JSON.parse(await fs.readFile(DATA_FILE, 'utf8'));
} catch (e) { /* first run */ }
const itemKey = s => `${s.kind || 'series'}:${s.id}`;
const prevAdded = new Map(((previous && previous.items) || [])
  .map(s => [itemKey(s), s.addedAt])
  .filter(([, v]) => v));
const fetchedAt = new Date().toISOString();

console.log('Fetching details (countries, ratings, descriptions, duration)...');
let detailFailures = 0;
let ratingChanges = 0;
await pool(list, 8, async s => {
  try {
    const d = await getJSON(s.url || BASE + (s.kind === 'movie' ? 'movies' : 'series') + '/' + s.id + '/');
    const diff = [
      ['ratingAmediateka', s.ratingAmediateka, d.ratingAmediateka],
      ['ratingImdb', s.ratingImdb, d.ratingImdb],
      ['ratingKinopoisk', s.ratingKinopoisk, d.ratingKinopoisk]
    ].filter(([, a, b]) => String(a ?? '') !== String(b ?? ''));
    if (diff.length) ratingChanges++;
    s.detail = d;
  } catch (e) {
    detailFailures++;
    console.warn(`  detail failed: ${s.kind} ${s.title} (${s.id}): ${e.message}`);
  }
});
console.log(`Details: ${list.length - detailFailures}/${list.length}, rating changes: ${ratingChanges}`);

console.log('Checking posters and normalizing...');
const items = await pool(list, 24, async s => {
  const src = s.detail || s;
  const poster = await resolvePoster(src.assets || s.assets);
  const countries = ((s.detail && s.detail.countries) || []).map(c => clean(c.name)).filter(Boolean);
  const genres = ((s.detail && s.detail.genres) || s.genres || []).map(g => clean(g.name)).filter(Boolean);
  const detailSeasons = s.detail && s.detail.seasons;
  const seasons = s.kind === 'series'
    ? (typeof s.seasons === 'number' ? s.seasons : (Array.isArray(detailSeasons) ? detailSeasons.length : null))
    : null;
  const episode = s.detail && Array.isArray(s.detail.episodes) ? s.detail.episodes[0] : null;
  const durationSeconds = s.kind === 'movie' && episode ? Number(episode.duration) : null;
  const duration = Number.isFinite(durationSeconds) && durationSeconds > 0 ? Math.round(durationSeconds / 60) : null;
  const published = src.publicationDate ? new Date(src.publicationDate) : null;
  const addedAt = published && !Number.isNaN(published.getTime())
    ? published.toISOString()
    : (prevAdded.get(itemKey(s)) || fetchedAt);
  return {
    id: s.id,
    kind: s.kind,
    title: clean(src.title || s.title),
    slug: s.slug,
    url: SITE + (src.webUrl || s.webUrl || `/watch/${s.kind === 'movie' ? 'movies' : 'series'}_${s.id}_${s.slug}`),
    year: src.premierYear ?? s.premierYear ?? null,
    seasons,
    duration,
    genres,
    countries,
    am: src.ratingAmediateka ? String(src.ratingAmediateka) : null,
    imdb: src.ratingImdb ? String(src.ratingImdb) : null,
    kp: src.ratingKinopoisk ? String(src.ratingKinopoisk) : null,
    desc: clean(src.shortDescription || s.shortDescription),
    poster: poster ? poster.url : null,
    posterAsset: poster ? poster.asset : null,
    addedAt
  };
});

items.sort((a, b) => a.kind === b.kind ? a.id - b.id : a.kind.localeCompare(b.kind));

if (previous && Array.isArray(previous.items)) {
  const keyOf = s => itemKey(s);
  const oldKeys = new Set(previous.items.map(keyOf));
  const newKeys = new Set(items.map(keyOf));
  const added = items.filter(s => !oldKeys.has(keyOf(s)));
  const removed = previous.items.filter(s => !newKeys.has(keyOf(s)));
  console.log(`Diff vs previous snapshot: +${added.length} / -${removed.length}`);
  for (const s of added) console.log(`  + [${s.kind}] ${s.title} (${s.year}) AM ${s.am ?? '—'}`);
  for (const s of removed) console.log(`  - [${s.kind}] ${s.title} (${s.year}) AM ${s.am ?? '—'}`);
}

const newCount = items.filter(s => Date.now() - new Date(s.addedAt).getTime() <= 30 * 24 * 60 * 60 * 1000).length;
const withCountries = items.filter(s => s.countries.length).length;
const withPoster = items.filter(s => s.poster).length;
const payload = {
  source: BASE,
  updatedAt: new Date().toISOString(),
  count: items.length,
  countries: [...new Set(items.flatMap(s => s.countries))].sort((a, b) => a.localeCompare(b, 'ru')),
  items
};

await fs.writeFile(DATA_FILE, JSON.stringify(payload, null, 2) + '\n', 'utf8');
console.log(`Saved ${DATA_FILE.pathname}: ${items.length} titles (${lists.series.length} series, ${lists.movie.length} movies), ${withCountries} with countries, ${withPoster} with poster, ${newCount} new for 30 days`);
console.log(`Elapsed: ${Math.round((Date.now() - startedAt.getTime()) / 1000)}s`);
if (detailFailures) console.warn(`WARN: ${detailFailures} detail requests failed; data may be incomplete for those titles`);
