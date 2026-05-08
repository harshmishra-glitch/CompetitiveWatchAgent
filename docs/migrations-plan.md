# Migrations Plan — Base Tables

> Status: **Proposal** for branch `feature/migration-for-base-tables`. Nothing in `db/migrate/` yet — this document describes the migrations we intend to add and the reasoning behind each column choice. Review and amend before generating the actual migration files.

## Goals

1. Persist Swiggy restaurant info, menu items, and Google reviews scraped daily into Postgres.
2. Retain **full daily history** so the Daily Digest, leaderboard trends, and menu tracker can compute day-over-day diffs.
3. Keep ingestion idempotent — re-running the importer for the same `Data_<DD>May/` snapshot must not duplicate rows.
4. Honour the spec rule: every ingested table carries `scrapped_at` (timestamp) and `scrapped_at_date` (date).

## Cross-cutting Conventions

- **One row per (entity, scrapped_at_date).** A new snapshot day = a new row, even when the underlying entity hasn't changed. This is what powers diffing.
- **`scrapped_at_date` is the partition / dedupe key.** Always indexed and always part of the uniqueness constraint.
- **Numeric vs raw text.** Where the scrape produces formatted strings (`"₹600 for two"`, `"3.5K+ ratings"`, `"₹200"`), we store **both** the raw string (for fidelity) and a parsed numeric form (for querying / sorting / health-score math).
- **Booleans.** CSVs use `True`/`False`/`Yes`/`No` strings — parse at ingestion, store as Postgres `boolean`.
- **Timestamps.** `timestamp without time zone` is fine for scraper-generated values; use `timestamptz` for Rails-managed ones.
- **Naming.** Migration files use the standard Rails timestamped prefix; table names are plural snake_case as Rails expects.

---

## Migration 1 — `CreateRestaurants`

Source: `Data_<DD>May/restaurantsAndMenus/<Name>_<id>_info.csv`
Spec note: should also carry `menu` and `google_reviews` `jsonb` columns for denormalized snapshot access.

| Column                | Type           | Null | Notes / Source CSV column                                                                 |
| --------------------- | -------------- | ---- | ----------------------------------------------------------------------------------------- |
| `id`                  | `bigserial PK` | no   | Rails primary key                                                                         |
| `swiggy_restaurant_id`| `bigint`       | no   | `restaurant_id` — Swiggy's own id (e.g. 186263). The natural key from upstream            |
| `input_name`          | `string`       | yes  | `input_name` — the search term that produced this scrape (e.g. `BANOFFEE`)                |
| `name`                | `string`       | no   | `name`                                                                                    |
| `city`                | `string`       | yes  | `city`                                                                                    |
| `locality`            | `string`       | yes  | `locality`                                                                                |
| `area`                | `string`       | yes  | `area`                                                                                    |
| `address`             | `text`         | yes  | `address`                                                                                 |
| `cost_for_two_raw`    | `string`       | yes  | `cost_for_two` — kept verbatim (e.g. `"₹600 for two"`)                                    |
| `cost_for_two`        | `integer`      | yes  | parsed numeric form (e.g. `600`)                                                          |
| `cuisines`            | `text[]`       | yes  | `cuisines` — split on `,` and trimmed                                                     |
| `avg_rating`          | `decimal(3,2)` | yes  | `avg_rating`                                                                              |
| `total_ratings_raw`   | `string`       | yes  | `total_ratings` — verbatim (e.g. `"3.5K+ ratings"`)                                       |
| `total_ratings`       | `integer`      | yes  | parsed (e.g. `3500`)                                                                      |
| `google_rating`       | `decimal(3,2)` | yes  | `google_rating` — frequently empty in the CSVs                                            |
| `google_rating_count` | `integer`      | yes  | `google_rating_count`                                                                     |
| `pure_veg`            | `boolean`      | yes  | `pure_veg`                                                                                |
| `is_open`             | `boolean`      | yes  | `is_open`                                                                                 |
| `next_close_time`     | `timestamp`    | yes  | `next_close_time` — looks like `"2026-05-07 23:00:00"`                                    |
| `delivery_time_min`   | `integer`      | yes  | `delivery_time_min` (minutes)                                                             |
| `delivery_time_max`   | `integer`      | yes  | `delivery_time_max` (minutes)                                                             |
| `distance_km`         | `decimal(6,2)` | yes  | `distance_km` — keep as decimal in case Swiggy returns fractional km later                |
| `parent_id`           | `bigint`       | yes  | `parent_id` — Swiggy's chain parent id                                                    |
| `is_chain`            | `boolean`      | yes  | `is_chain` — CSV uses `Yes`/`No`                                                          |
| `discount_header`     | `string`       | yes  | `discount_header`                                                                         |
| `offers`              | `text[]`       | yes  | `offers` — split on `\|`, trimmed                                                         |
| `image_url`           | `text`         | yes  | `image_url`                                                                               |
| `swiggy_url`          | `text`         | yes  | `swiggy_url`                                                                              |
| `swiggy_lat`          | `decimal(10,7)`| yes  | `swiggy_lat`                                                                              |
| `swiggy_lng`          | `decimal(10,7)`| yes  | `swiggy_lng`                                                                              |
| `menu`                | `jsonb`        | yes  | snapshot copy of the parsed menu CSV — convenience reads for the chatbot / digest        |
| `google_reviews`      | `jsonb`        | yes  | snapshot copy of the parsed reviews CSV — same reasoning                                  |
| `scrapped_at`         | `timestamp`    | no   | when the snapshot was taken                                                               |
| `scrapped_at_date`    | `date`         | no   | snapshot date, derived from the `Data_<DD>May/` folder                                    |
| `created_at`          | `timestamptz`  | no   | Rails                                                                                     |
| `updated_at`          | `timestamptz`  | no   | Rails                                                                                     |

**Indexes**
- `UNIQUE (swiggy_restaurant_id, scrapped_at_date)` — one row per restaurant per scrape day; enforces idempotent ingestion.
- `INDEX (scrapped_at_date)` — daily-digest queries scan by snapshot date.
- `INDEX (city, locality)` — competitor suggestion ranks by proximity / locality.
- `INDEX (avg_rating)` — leaderboard sort.

**Open questions**
- `text[]` vs `jsonb` for `cuisines` and `offers`: arrays are simpler for `ANY` filtering; `jsonb` preserves order + future structure. Default to `text[]` unless we see structured offer payloads.
- Do we want a separate `restaurants_current` view (latest row per `swiggy_restaurant_id`) for fast "as of now" reads, or is `ORDER BY scrapped_at_date DESC LIMIT 1` good enough? Likely the latter to start.

---

## Migration 2 — `CreateMenuItems`

Source: `Data_<DD>May/restaurantsAndMenus/<Name>_<id>.csv` — one row per dish.

| Column              | Type            | Null | Notes / Source CSV column                                  |
| ------------------- | --------------- | ---- | ---------------------------------------------------------- |
| `id`                | `bigserial PK`  | no   | Rails primary key                                          |
| `restaurant_id`     | `bigint FK`     | no   | FK → `restaurants.id` (matched by `swiggy_restaurant_id` + `scrapped_at_date` at ingest time) |
| `category`          | `string`        | yes  | `category`                                                 |
| `subcategory`       | `string`        | yes  | `subcategory`                                              |
| `name`              | `string`        | no   | `name`                                                     |
| `price_raw`         | `string`        | yes  | `price` — verbatim (e.g. `"₹200"`)                        |
| `price`             | `integer`       | yes  | parsed integer rupees                                      |
| `variants`          | `jsonb`         | yes  | `variants` — looks free-form; jsonb keeps options open     |
| `description`       | `text`          | yes  | `description`                                              |
| `veg`               | `boolean`       | yes  | `veg` — `Veg` → true, `Non-Veg` → false                    |
| `rating`            | `decimal(3,2)`  | yes  | `rating`                                                   |
| `rating_count`      | `integer`       | yes  | `rating_count`                                             |
| `bestseller`        | `boolean`       | yes  | `bestseller` — non-empty marker → true                     |
| `availability`      | `string`        | yes  | `availability` (e.g. `"In Stock"`)                         |
| `scrapped_at`       | `timestamp`     | no   | snapshot timestamp                                         |
| `scrapped_at_date`  | `date`          | no   | snapshot date                                              |
| `created_at`        | `timestamptz`   | no   | Rails                                                      |
| `updated_at`        | `timestamptz`   | no   | Rails                                                      |

**Indexes**
- `INDEX (restaurant_id, scrapped_at_date)` — primary access pattern (menu for restaurant X on date Y).
- `INDEX (restaurant_id, name, scrapped_at_date)` — supports the menu tracker (`item X added/removed/repriced`).
- Optional `UNIQUE (restaurant_id, name, scrapped_at_date)` — only if upstream guarantees one row per dish per snapshot. The CSVs sometimes repeat names across categories; **start without this constraint** and add later once we confirm.

**Decision needed**
- The menu tracker needs to detect "added", "removed", "repriced" between snapshots. That's a compute on top of this table, not a schema change. No extra columns required for now.

---

## Migration 3 — `CreateRestaurantGoogleReviews`

Source: `Data_<DD>May/googleReviews/<restaurant>.csv` — one row per review.

| Column              | Type            | Null | Notes / Source CSV column                                                                      |
| ------------------- | --------------- | ---- | ---------------------------------------------------------------------------------------------- |
| `id`                | `bigserial PK`  | no   | Rails primary key                                                                              |
| `restaurant_id`     | `bigint FK`     | no   | FK → `restaurants.id`. **Matched by name** (CSVs key on `restaurant_name`, not `restaurant_id`) — see below |
| `restaurant_name`   | `string`        | yes  | `restaurant_name` — kept for traceability of the name-match                                    |
| `phone`             | `string`        | yes  | `phone`                                                                                        |
| `address`           | `text`          | yes  | `address`                                                                                      |
| `latitude`          | `decimal(10,7)` | yes  | `latitude`                                                                                     |
| `longitude`         | `decimal(10,7)` | yes  | `longitude`                                                                                    |
| `place_type`        | `string`        | yes  | `place_type`                                                                                   |
| `website`           | `text`          | yes  | `website`                                                                                      |
| `review_id`         | `string`        | no   | `review_id` — Google's stable id; used as the dedupe key                                       |
| `place_name`        | `string`        | yes  | `place_name`                                                                                   |
| `reviewer_name`     | `string`        | yes  | `reviewer_name`                                                                                |
| `reviewer_id`       | `string`        | yes  | `reviewer_id`                                                                                  |
| `local_guide`       | `boolean`       | yes  | `local_guide`                                                                                  |
| `rating`            | `integer`       | yes  | `rating` (1–5)                                                                                 |
| `review_text`       | `text`          | yes  | `review_text`                                                                                  |
| `likes`             | `integer`       | yes  | `likes`                                                                                        |
| `date_raw`          | `string`        | yes  | `date` — relative string like `"25 minutes ago"`. Keep as text                                 |
| `review_posted_at`  | `timestamp`     | yes  | parsed approximate posting time (best-effort from `date_raw` + `scrapped_at`)                  |
| `review_attributes` | `jsonb`         | yes  | `attributes` (CSV) — renamed to avoid shadowing AR's `record.attributes`. Already JSON-shaped (e.g. `{"food":5,"service_rating":4,...}`) |
| `scrapped_at`       | `timestamp`     | no   |                                                                                                 |
| `scrapped_at_date`  | `date`          | no   |                                                                                                 |
| `created_at`        | `timestamptz`   | no   | Rails                                                                                          |
| `updated_at`        | `timestamptz`   | no   | Rails                                                                                          |

**Indexes**
- `INDEX (restaurant_id, scrapped_at_date)` — review-volume / sentiment-trend queries.
- `UNIQUE (review_id, scrapped_at_date)` — same review can appear in multiple daily snapshots, but only once per day.
- `INDEX (restaurant_id, review_posted_at)` — for "reviews in the last 7 days" filters once we parse `date_raw`.

**Joining quirk**
Google Reviews CSVs are keyed by `restaurant_name` (e.g. `BANOFFEE`), not `restaurant_id`. The Swiggy CSV's `input_name` field carries the same uppercase name, so the ingest task should:

1. Look up `restaurants` by `(input_name, scrapped_at_date)`.
2. Fall back to a fuzzy name match against `name` if `input_name` doesn't resolve.
3. Log unresolved reviews loudly; do not silently drop them.

---

## Ingestion Task (out of scope for these migrations, but tightly related)

Once these migrations land, a Rake task in `lib/tasks/` will:

1. Walk `Data_<DD>May/` folders.
2. Derive `scrapped_at_date` from the folder name (`7May` → `2026-05-07`, etc. — confirm year handling with the team).
3. Use `scrapped_at = File.mtime(csv)` (or `Time.zone.now` at ingest, depending on whether we trust the file mtime).
4. Upsert into `restaurants`, then `menu_items`, then `restaurant_google_reviews`, in that order.
5. Populate the `restaurants.menu` and `restaurants.google_reviews` jsonb snapshots from the same data after the child rows are written.

This task is **not** part of this migration plan — it just shapes some of the column choices above (raw + parsed pairs, the unique constraints, the FK-by-name resolution).

---

## Order of Operations

```
1. db/migrate/<ts>_create_restaurants.rb
2. db/migrate/<ts>_create_menu_items.rb            # depends on restaurants
3. db/migrate/<ts>_create_restaurant_google_reviews.rb   # depends on restaurants
```

All three are additive — no destructive changes — and can ship in a single PR on `feature/migration-for-base-tables`.

---

## Items to Confirm Before Generating the Migrations

1. **Year for `scrapped_at_date`** — folders are named `Data_7May` etc. without a year. Is 2026 correct? (matches the `next_close_time` values in the CSV).
2. **Storage for `cuisines` / `offers`** — `text[]` vs `jsonb`. Defaulting to `text[]`.
3. **Currency / locale for parsed prices** — assume INR rupees as integers; confirm we never need sub-rupee precision.
4. **Whether to keep the `restaurants.menu` / `restaurants.google_reviews` jsonb snapshots** even though we have child tables. The product spec calls for them; flagging because it's denormalization with a maintenance cost.
5. **Soft delete vs hard history** — current plan keeps every snapshot row forever. If volume becomes a problem, we partition `restaurants` / `menu_items` / `restaurant_google_reviews` by `scrapped_at_date` — but **not** in this PR.
