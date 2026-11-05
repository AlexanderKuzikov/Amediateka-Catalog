# Amediateka Catalog — Instructions for AI Agents

## Commands

- install: не требуется, зависимостей нет
- fetch: `node scripts/fetch.mjs` — тянет список и детали с API, пишет `data/series.json`
- build: `node scripts/build.mjs` — собирает оба HTML из `data/series.json` и `src/template.html`
- monthly: `npm run monthly` — fetch + build
- verify: открыть `dist/amediateka_catalog.html` и `dist/amediateka_catalog_json.html`

## Conventions

- Zero-dependency Node (>=20), ESM, без npm-пакетов.
- Данные — снимок `data/series.json`; `dist/` всегда генерируется, руками не правится.
- Шаблон один: `src/template.html`, маркеры `{{...}}` подставляет `scripts/build.mjs`.
- Два варианта вывода: статические строки и встроенный JSON (`#catalog-data`).
- Сортировка IMDb/КП: при отсутствии рейтинга используется AM (Amediateka).
- Постеры: приоритет `productPosterV2` → `v_poster` → `productPoster` → `partnersPoster` → `productItemCover`.
- Капс не используем, обычный регистр. Коммиты на русском, повелительное наклонение.

## Structure

- `scripts/fetch.mjs` — сбор данных (list + detail, страны, рейтинги, постеры)
- `scripts/build.mjs` — генерация `dist/*.html`
- `src/template.html` — общий шаблон UI
- `data/series.json` — снимок данных
- `dist/amediateka_catalog.html` — статический каталог
- `dist/amediateka_catalog_json.html` — каталог с JSON внутри HTML
- `.github/workflows/monthly.yml` — ежемесячная сборка

## Do NOT touch

- `dist/` руками — только через сборку.
- Секреты не требуются; ключи и токены не добавлять.
- Рейтинги IMDb/Кинопоиска не выдумывать и не скрапить сомнительными источниками.

## Documentation rules

- После работы обновить `docs/CONTEXT.md`.
- Архитектурные решения — в `docs/DECISIONS.md`.
- Новые `.md` без разрешения не создавать.
- Переиспользуемые знания — в `D:\GitHub\knowledge/`, только если они переживают проект.
