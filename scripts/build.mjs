import fs from 'node:fs/promises';

const DATA_FILE = new URL('../data/series.json', import.meta.url);
const TEMPLATE_FILE = new URL('../src/template.html', import.meta.url);
const OUT_DIR = new URL('../dist/', import.meta.url);

const PLACEHOLDER = 'data:image/svg+xml,' + encodeURIComponent(
  '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="300" viewBox="0 0 200 300">' +
  '<rect width="200" height="300" fill="#1b1b26"/>' +
  '<rect x="58" y="96" width="84" height="104" rx="10" fill="none" stroke="#41415c" stroke-width="3"/>' +
  '<path d="M89 130l26 18-26 18z" fill="#41415c"/>' +
  '<text x="100" y="234" fill="#66667f" font-family="Segoe UI,Arial,sans-serif" font-size="12" text-anchor="middle">нет постера</text>' +
  '</svg>'
);

const esc = s => String(s ?? '')
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&#39;');

const data = JSON.parse(await fs.readFile(DATA_FILE, 'utf8'));
const items = [...data.items];
const byTitle = (a, b) => a.title.localeCompare(b.title, 'ru', { sensitivity: 'base' });
const num = v => (v === null || v === undefined || v === '' ? null : parseFloat(v));
const underscore = value => (value === null || value === undefined ? '' : String(value));

items.sort((a, b) => {
  const ya = num(a.year), yb = num(b.year);
  if (ya !== yb) {
    if (ya === null) return 1;
    if (yb === null) return -1;
    return yb - ya;
  }
  const ra = num(a.am), rb = num(b.am);
  if (ra !== rb) {
    if (ra === null) return 1;
    if (rb === null) return -1;
    return rb - ra;
  }
  return byTitle(a, b);
});

const genreSet = new Set(items.flatMap(d => d.genres));
const countrySet = new Set(items.flatMap(d => d.countries || []));
const genresList = [...genreSet].sort((a, b) => a.localeCompare(b, 'ru'));
const countriesList = [...countrySet].sort((a, b) => a.localeCompare(b, 'ru'));
const yearsList = [...new Set(items.map(d => d.year).filter(Boolean))].sort((a, b) => Number(b) - Number(a));

const genreOptions = genresList
  .map(g => `<label><input type="checkbox" value="${esc(g)}"> ${esc(g)}</label>`)
  .join('\n        ');
const countryOptions = countriesList
  .map(c => `<label><input type="checkbox" value="${esc(c)}"> ${esc(c)}</label>`)
  .join('\n        ');
const yearOptions = yearsList
  .map(y => `<option value="${esc(y)}">${esc(y)}</option>`)
  .join('\n      ');

function ratingCell(value, cls) {
  if (value) return `<span class="rating rating-${cls}">${esc(value)}</span>`;
  const hint = cls === 'imdb' || cls === 'kp'
    ? ' title="Рейтинга нет — при сортировке используется Amediateka"'
    : '';
  return `<span class="rating-na"${hint}>\u2014</span>`;
}

function posterButton(d) {
  const alt = esc('Постер: ' + d.title);
  if (!d.poster) {
    return `<button type="button" class="poster loaded" aria-label="${esc('Постер отсутствует: ' + d.title)}"><img src="${esc(PLACEHOLDER)}" alt="${alt}" class="is-placeholder" loading="lazy" decoding="async"></button>`;
  }
  const thumb = d.poster.replace('/400x600/', '/200x300/');
  return `<button type="button" class="poster" aria-label="${esc('Увеличить постер: ' + d.title)}"><img src="${esc(thumb)}" alt="${alt}" loading="lazy" decoding="async" referrerpolicy="no-referrer"></button>`;
}

function rowHtml(d) {
  const descHtml = d.desc ? `<p class="desc-text">${esc(d.desc)}</p>` : '';
  const genresHtml = d.genres.map(g => `<span class="genre-tag">${esc(g)}</span>`).join('');
  return `<tr data-id="${d.id}" data-genres="${esc(d.genres.join('|'))}" data-countries="${esc((d.countries || []).join('|'))}" data-year="${esc(underscore(d.year))}" data-am="${esc(d.am || '')}" data-imdb="${esc(d.imdb || '')}" data-kp="${esc(d.kp || '')}" data-seasons="${esc(underscore(d.seasons))}" data-url="${esc(d.url)}">
  <td class="title-col"><div class="title-wrap">
    ${posterButton(d)}
    <div class="title-info"><a href="${esc(d.url)}" target="_blank" rel="noopener">${esc(d.title)}</a>${descHtml}</div>
  </div></td>
  <td class="genre-col">${genresHtml}</td>
  <td class="year-col">${esc(underscore(d.year))}</td>
  <td class="rating-col">${ratingCell(d.am, 'am')}</td>
  <td class="rating-col">${ratingCell(d.imdb, 'imdb')}</td>
  <td class="rating-col">${ratingCell(d.kp, 'kp')}</td>
  <td class="seasons-col">${esc(underscore(d.seasons))}</td>
</tr>`;
}

const rowsHtml = items.map(rowHtml).join('\n');
const date = new Intl.DateTimeFormat('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' })
  .format(new Date(data.updatedAt || Date.now())).replace(' \u0433.', '');

const jsonItems = items.map(d => ({
  id: d.id,
  title: d.title,
  url: d.url,
  year: d.year,
  seasons: d.seasons,
  genres: d.genres,
  countries: d.countries || [],
  am: d.am,
  imdb: d.imdb,
  kp: d.kp,
  desc: d.desc,
  poster: d.poster
}));
const jsonPayload = JSON.stringify({ count: jsonItems.length, updatedAt: data.updatedAt, items: jsonItems })
  .replaceAll('<', '\\u003c')
  .replaceAll('\u2028', '\\u2028')
  .replaceAll('\u2029', '\\u2029');
const dataScript = `<script type="application/json" id="catalog-data">${jsonPayload}</script>`;
const noScriptJson = '<p class="empty-msg">Эта версия собирает каталог из встроенного JSON через JavaScript. Откройте <a href="amediateka_catalog.html">статическую версию</a>.</p>';

const template = await fs.readFile(TEMPLATE_FILE, 'utf8');

function render({ rows, dataScriptHtml, noScript }) {
  return template
    .replaceAll('{{COUNT}}', String(items.length))
    .replaceAll('{{DATE}}', date)
    .replaceAll('{{GENRE_OPTIONS}}', genreOptions)
    .replaceAll('{{COUNTRY_OPTIONS}}', countryOptions)
    .replaceAll('{{YEAR_OPTIONS}}', yearOptions)
    .replaceAll('{{ROWS}}', rows)
    .replaceAll('{{DATA_SCRIPT}}', dataScriptHtml)
    .replaceAll('{{NOSCRIPT_MSG}}', noScript)
    .replaceAll('{{PLACEHOLDER}}', PLACEHOLDER);
}

const staticHtml = render({ rows: rowsHtml, dataScriptHtml: '', noScript: '' });
const jsonHtml = render({ rows: '', dataScriptHtml: dataScript, noScript: noScriptJson });

for (const [name, html] of [['amediateka_catalog.html', staticHtml], ['amediateka_catalog_json.html', jsonHtml]]) {
  const leftovers = html.match(/\{\{[A-Z_]+\}\}/g);
  if (leftovers) throw new Error(`${name}: unreplaced markers: ${leftovers.join(', ')}`);
  await fs.writeFile(new URL(name, OUT_DIR), html, 'utf8');
}

const size = h => (Buffer.byteLength(h, 'utf8') / 1024).toFixed(0) + ' KB';
console.log(`Static:       dist/amediateka_catalog.html (${size(staticHtml)})`);
console.log(`JSON-embedded: dist/amediateka_catalog_json.html (${size(jsonHtml)})`);
console.log(`Series: ${items.length}, genres: ${genresList.length}, countries: ${countriesList.length}, date: ${date}`);
