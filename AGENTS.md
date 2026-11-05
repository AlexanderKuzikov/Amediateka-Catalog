# Amediateka Catalog — Instructions for AI Agents

## Commands

- install: не требуется, зависимостей нет
- fetch: `node scripts/fetch.mjs` — тянет список и детали с API, пишет `data/catalog.json`
- build: `node scripts/build.mjs` — собирает оба HTML из `data/catalog.json` и `src/template.html`
- monthly: `npm run monthly` — fetch + build
- force monthly: `powershell -ExecutionPolicy Bypass -File scripts/monthly.ps1 -Force`
- install task: `powershell -ExecutionPolicy Bypass -File scripts/install-task.ps1` — ежедневная проверка, обновление раз в месяц
- verify: открыть `dist/amediateka_catalog.html` и `dist/amediateka_catalog_json.html`

## Conventions

- Zero-dependency Node (>=20), ESM, без npm-пакетов.
- Данные — снимок `data/catalog.json`; `dist/` всегда генерируется, руками не правится.
- `addedAt` — дата публикации (`publicationDate`) или первого появления; build считает новинками последние 30 дней.
- Шаблон один: `src/template.html`, маркеры `{{...}}` подставляет `scripts/build.mjs`.
- Два варианта вывода: статические строки и встроенный JSON (`#catalog-data`).
- Сортировка IMDb/КП: при отсутствии рейтинга используется AM (Amediateka).
- Типы: `kind` = `series` | `movie`; фильтруются переключателем, длительность фильма — в минутах.
- Постеры: приоритет `productPosterV2` → `v_poster` → `productPoster` → `partnersPoster` → `productItemCover`.
- Капс не используем, обычный регистр. Коммиты на русском, повелительное наклонение.

## Structure

- `scripts/fetch.mjs` — сбор данных по сериалам и фильмам (list + detail, страны, рейтинги, длительность, постеры)
- `scripts/build.mjs` — генерация `dist/*.html`
- `src/template.html` — общий шаблон UI
- `data/catalog.json` — снимок данных: 382 сериала и 251 фильм, поле `kind`
- `dist/amediateka_catalog.html` — статический каталог
- `dist/amediateka_catalog_json.html` — каталог с JSON внутри HTML
- `scripts/monthly.ps1` — ежемесячное обновление с проверкой даты снимка
- `scripts/install-task.ps1` — регистрация задачи в Windows Task Scheduler
- `legacy/` — старый PowerShell-конвейер v1–v3, только история, не использовать

## Do NOT touch

- `dist/` руками — только через сборку.
- Секреты не требуются; ключи и токены не добавлять.
- Рейтинги IMDb/Кинопоиска не выдумывать и не скрапить сомнительными источниками.

## Documentation rules

- После работы обновить `docs/CONTEXT.md`.
- Архитектурные решения — в `docs/DECISIONS.md`.
- Новые `.md` без разрешения не создавать.
- Переиспользуемые знания — в `D:\GitHub\knowledge/`, только если они переживают проект.
