# CLINK — Competitive Watch Agent

Backend for the **Competitive Watch Agent**, a product that gives restaurant owners a single place to understand how they stack up against their competition: what changed yesterday, what the market looks like today, and what to do about it. It works continuously in the background so the owner gets intelligence without doing any research themselves.

This repository hosts the Rails API and the data pipeline that ingests Swiggy + Google Reviews scrapes into Postgres for downstream use by the agent.

---

## Product Overview

### Onboarding

1. **Pilot restaurant selection** — the owner searches their own restaurant in a single search bar (results pulled from backend in real time, showing name + locality) and taps to set it as the pilot.
2. **Competitor selection** — the agent immediately suggests 8–12 competitors ranked by proximity, cuisine overlap, price band similarity, and review volume. The owner picks 3–10. A secondary search bar lets them add anything not suggested. Hitting "Set up my dashboard" triggers the first data pull.

### Main Dashboard

Three sections behind a persistent tab bar.

1. **Daily Digest** — what changed in the last 24 hours across competitors and the market.
   - A 2–3 sentence overall briefing card at the top.
   - Per-competitor change cards: what changed, why it matters to this restaurant specifically, and a suggested response (Defend / Watch / Ignore) with a one-line rationale.
   - Quiet days render a clean "No significant changes" state, not a blank screen.

2. **AI Chatbot** — natural-language Q&A with full context of the pilot restaurant, all competitors, recent changes, and market trends. Example questions it handles well:
   - "How is Bawarchi doing this month?"
   - "Should I be worried about the new Paradise outlet in Kondapur?"
   - "Who is growing fastest in my segment right now?"
   - "What should I do to defend my lunch covers this week?"
   - "How does my pricing compare to my competitors?"

   Responses are structured (key numbers called out, recommendations separated from analysis) — not walls of text.

3. **Competitor Analysis** — always-on deeper view of the landscape.
   - **Leaderboard** — pilot + competitors ranked by a Competitive Health Score (rating trajectory, review velocity, menu activity, social mentions, estimated demand). Updates daily. Pilot is always highlighted. Each row shows rank, score, week-over-week delta, and a single headline signal.
   - **Restaurant drill-down** — menu tracker (additions / removals / repricing over the last 30 days), rating & review trend, pricing analysis vs pilot, chronological activity feed, and a threat assessment (overlap with the pilot's segment, price band, and neighbourhood).

### Design Principles

- **Actionable over informative.** Every piece of data shown connects to a decision the owner can make.
- **Fast to the point.** Daily digest readable in under 90s. Chatbot answers in 3–5 sentences before offering depth. Leaderboard communicates the picture at a glance.

---

## Schema Design (current focus)

> Branch `feature/migration-for-base-tables` is where these base tables are being introduced.

### `restaurants`
- All restaurant-level fields scraped from Swiggy (as found in the `*_info.csv` files: `restaurant_id`, `name`, `city`, `locality`, `area`, `address`, `cost_for_two`, `cuisines`, `avg_rating`, `total_ratings`, `google_rating`, `google_rating_count`, `pure_veg`, `is_open`, `next_close_time`, delivery time, `distance_km`, `parent_id`, `is_chain`, `discount_header`, `offers`, `image_url`, `swiggy_url`, `swiggy_lat`, `swiggy_lng`, …).
- Two `jsonb` columns to store the full **menu** snapshot and the **Google reviews** snapshot for that restaurant.

### `menu_items`
- One row per menu item. Columns mirror the per-restaurant menu CSVs: `category`, `subcategory`, `name`, `price`, `variants`, `description`, `veg`, `rating`, `rating_count`, `bestseller`, `availability`, plus a foreign key to `restaurants`.

### `restaurant_google_reviews`
- One row per review. Columns mirror the Google Reviews CSVs: `phone`, `address`, `latitude`, `longitude`, `place_type`, `website`, `review_id`, `place_name`, `reviewer_name`, `reviewer_id`, `local_guide`, `rating`, `review_text`, `likes`, `date`, `attributes`, plus a foreign key to `restaurants`.

### Ingestion convention (applies to **every** scraped table)

Every table that ingests scraped data **must** include:

- `scrapped_at` — timestamp of when the data was scraped.
- `scrapped_at_date` — the date on which that data was scraped (used for daily diffs and the digest).

This is what powers the day-over-day change detection that the Daily Digest and Competitor Analysis are built on.

---

## Repository Layout

```
.
├── app/                  # Rails app (controllers, models, jobs, …) — currently scaffold only
├── config/               # Rails configuration (database.yml, routes.rb, environments/)
├── db/                   # Migrations + seeds (base-table migrations land on feature/migration-for-base-tables)
├── lib/tasks/            # Rake tasks (ingestion tasks live here)
├── Data_7May/            # Scraped data snapshot — 7 May
│   ├── restaurantsAndMenus/   #   <Name>_<id>_info.csv  (restaurant info)
│   │                          #   <Name>_<id>.csv       (menu items)
│   └── googleReviews/         #   <restaurant>.csv      (per-restaurant reviews)
├── Data_8May/            # Scraped data snapshot — 8 May
├── Data_9May/            # Scraped data snapshot — 9 May
└── Data_10May/           # Scraped data snapshot — 10 May
```

Each `Data_<DD>May/` folder is one daily snapshot. Re-ingesting the same restaurant on a new date should produce a new row keyed on `scrapped_at_date`, not overwrite the previous day.

---

## Tech Stack

- **Ruby** 3.2.3 (pinned in `.ruby-version`, `Gemfile`, and `Gemfile.lock`)
- **Rails** ~> 7.0.8
- **PostgreSQL** (via `pg` gem) — `jsonb` columns for menu and Google reviews snapshots
- **Puma** as the web server
- **dotenv-rails** for local env config (the `.env` file is gitignored)

---

## Local Setup

```bash
# 1. Install Ruby 3.2.x (rbenv / asdf / rvm)
# 2. Install dependencies
bundle install

# 3. Configure the database
#    Set DATABASE_URL in .env  (database.yml reads it)
#    Example: DATABASE_URL=postgres://USER:PASS@localhost:5432/competitive_watch_dev

# 4. Create + migrate
bin/rails db:create
bin/rails db:migrate

# 5. Boot the server
bin/rails server
```

Configuration is via `.env` (see `.gitignore`). `config/database.yml` reads `DATABASE_URL` for all environments.

---

## Current Status

- Rails skeleton is in place; `app/models`, `app/controllers`, `db/migrate` are still empty scaffolds.
- Four daily scrape snapshots are committed under `Data_7May/`…`Data_10May/`.
- Active work: introduce the base tables (`restaurants`, `menu_items`, `restaurant_google_reviews`) on `feature/migration-for-base-tables`, then wire up an ingestion Rake task that reads each `Data_<DD>May/` folder and populates the tables with `scrapped_at` / `scrapped_at_date` set from the snapshot date.

---

## For Future Contributors / LLM Agents Picking This Up

If you're new to this repo (human or model), the fastest way to orient yourself:

1. Read this file end-to-end — it captures the product intent, not just the code.
2. Open one file from each scrape folder to see the real column shapes:
   - `Data_7May/restaurantsAndMenus/<Name>_<id>_info.csv` — restaurant fields.
   - `Data_7May/restaurantsAndMenus/<Name>_<id>.csv` — menu fields.
   - `Data_7May/googleReviews/<name>.csv` — review fields.
3. Check the active branch (`feature/migration-for-base-tables`) for in-progress migrations before designing new ones.
4. Honour the **`scrapped_at` + `scrapped_at_date` on every scraped table** rule — the daily-digest and trend features depend on it.
