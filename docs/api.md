# CLINK API Reference

All endpoints are prefixed with `/api`. Base URL in dev: `http://localhost:3000`.

- **Auth.** Single-tenant. `current_pilot_restaurant` is auto-resolved from the most-recently-set active pilot. To pin requests to a specific pilot, send `X-Pilot-Restaurant-Id: <id>` on every call.
- **Errors.** All non-2xx responses share the shape `{ "error": { "code": "...", "message": "...", "detail": "..." } }`.
- **Pagination.** `?per_page=` (default 25, max 200) + `?page=` on list endpoints.
- **Dates.** ISO `YYYY-MM-DD`. Some endpoints accept relative durations like `7d`, `30d`, `2w`, `1m`.

---

## Onboarding

### 1. Search restaurants

`GET /api/restaurants/search`

Typeahead used for picking the pilot and adding manual competitors.

**Query**

| Param | Type | Default |
|---|---|---|
| `q` | string (required) | — |
| `limit` | integer | 10 (max 50) |

**Request**

```bash
curl -G 'http://localhost:3000/api/restaurants/search' \
  --data-urlencode 'q=blue tokai' \
  --data-urlencode 'limit=5'
```

**Response 200**

```json
{
  "results": [
    {
      "id": 22,
      "name": "Blue Tokai Coffee Roasters | HSR Layout",
      "locality": "HSR Layout",
      "area": "Sector 6",
      "rating": "4.2",
      "review_count": 888,
      "image_url": "https://media-assets.swiggy.com/.../22.jpg"
    },
    {
      "id": 23,
      "name": "Blue Tokai Coffee Roasters | HSR Layout Sec 7",
      "locality": "HSR Layout",
      "area": "Sector 7",
      "rating": "4.9",
      "review_count": 92,
      "image_url": "https://media-assets.swiggy.com/.../23.jpg"
    }
  ]
}
```

---

### 2. Set the pilot restaurant

`POST /api/pilot_restaurants`

Sets one restaurant as the active pilot. Idempotent: calling twice for the same `restaurant_id` updates `set_at` instead of creating duplicates. Deactivates any previously active pilot.

**Body**

| Field | Type |
|---|---|
| `restaurant_id` | integer (required) |

**Request**

```bash
curl -X POST 'http://localhost:3000/api/pilot_restaurants' \
  -H 'Content-Type: application/json' \
  -d '{"restaurant_id": 22}'
```

**Response 201**

```json
{
  "pilot_restaurant": {
    "id": 2,
    "active": true,
    "set_at": "2026-05-10T12:00:00Z",
    "restaurant": {
      "id": 22,
      "name": "Blue Tokai Coffee Roasters | HSR Layout",
      "rating": "4.2",
      "review_count": 888
    },
    "active_competitor_set_id": null
  }
}
```

---

### 3. Get the active pilot

`GET /api/pilot_restaurants/current`

**Request**

```bash
curl 'http://localhost:3000/api/pilot_restaurants/current'
```

**Response 200**

```json
{
  "pilot_restaurant": {
    "id": 2,
    "active": true,
    "set_at": "2026-05-10T12:00:00Z",
    "restaurant": { "id": 22, "name": "Blue Tokai Coffee Roasters | HSR Layout", "rating": "4.2", "review_count": 888 },
    "active_competitor_set_id": 2
  }
}
```

**Response 404**

```json
{ "error": { "code": "no_pilot_restaurant", "message": "No active pilot restaurant." } }
```

---

### 4. List all pilots

`GET /api/pilot_restaurants`

**Request**

```bash
curl 'http://localhost:3000/api/pilot_restaurants'
```

**Response 200**

```json
{
  "pilot_restaurants": [
    { "id": 2, "active": true,  "set_at": "2026-05-10T...", "restaurant": {"id": 22, "name": "Blue Tokai..."}, "active_competitor_set_id": 2 },
    { "id": 1, "active": false, "set_at": "2026-05-09T...", "restaurant": {"id":  1, "name": "Casa Fresco..."}, "active_competitor_set_id": null }
  ]
}
```

---

### 5. Show one pilot

`GET /api/pilot_restaurants/:id`

**Request**

```bash
curl 'http://localhost:3000/api/pilot_restaurants/2'
```

Response same shape as endpoint #3.

---

### 6. Get suggested competitors

`GET /api/pilot_restaurants/:id/suggested_competitors`

Ranked candidates by proximity (haversine on lat/lng) + cuisine Jaccard + price-band similarity + log-volume of reviews. Use to populate the 8–12 onboarding cards.

**Query**

| Param | Type | Default |
|---|---|---|
| `limit` | integer | 12 (max 50) |

**Request**

```bash
curl 'http://localhost:3000/api/pilot_restaurants/2/suggested_competitors?limit=10'
```

**Response 200**

```json
{
  "suggestions": [
    {
      "restaurant_id": 11,
      "name": "BANOFFEE",
      "locality": "HSR Layout",
      "area": "Sector 6",
      "distance_km": 0.42,
      "primary_cuisines": ["Cafe", "Desserts"],
      "avg_rating": "4.1",
      "review_count": 1902,
      "cost_for_two": 600,
      "image_url": "https://...",
      "suggestion_score": 0.7321
    },
    { "restaurant_id": 50, "name": "Cafe 27", "distance_km": 0.71, "suggestion_score": 0.6912, "...": "..." }
  ]
}
```

---

### 7. Create a competitor set

`POST /api/competitor_sets`

Creates a fresh active competitor set with the chosen members, deactivating any previous active set for the pilot. This is the "Set up my dashboard" submit.

**Body**

| Field | Type |
|---|---|
| `pilot_restaurant_id` | integer (required) |
| `restaurant_ids` | integer[] (required, 3–10 recommended) |
| `name` | string (optional) |

**Request**

```bash
curl -X POST 'http://localhost:3000/api/competitor_sets' \
  -H 'Content-Type: application/json' \
  -d '{
    "pilot_restaurant_id": 2,
    "restaurant_ids": [2, 3, 8, 11, 50, 65],
    "name": "Initial set"
  }'
```

**Response 201**

```json
{
  "competitor_set": {
    "id": 2,
    "pilot_restaurant_id": 2,
    "name": "Initial set",
    "active": true,
    "created_at": "2026-05-10T...",
    "member_count": 6,
    "members": [
      { "id": 7,  "restaurant_id":  2, "name": "Cafe Here & Now",          "source": "suggested", "added_at": "2026-05-10T..." },
      { "id": 8,  "restaurant_id":  3, "name": "Café Coffee Day",          "source": "suggested", "added_at": "2026-05-10T..." },
      { "id": 9,  "restaurant_id":  8, "name": "Glen's Bakehouse (HSR Layout)", "source": "suggested", "added_at": "2026-05-10T..." },
      { "id": 10, "restaurant_id": 11, "name": "BANOFFEE",                 "source": "suggested", "added_at": "2026-05-10T..." },
      { "id": 11, "restaurant_id": 50, "name": "Cafe 27",                  "source": "suggested", "added_at": "2026-05-10T..." },
      { "id": 12, "restaurant_id": 65, "name": "The Hole In The Wall Cafe","source": "suggested", "added_at": "2026-05-10T..." }
    ]
  }
}
```

---

### 8. List competitor sets

`GET /api/competitor_sets?pilot_restaurant_id=`

**Request**

```bash
curl 'http://localhost:3000/api/competitor_sets?pilot_restaurant_id=2'
```

**Response 200**

```json
{
  "competitor_sets": [
    { "id": 2, "pilot_restaurant_id": 2, "name": "Initial set", "active": true,
      "created_at": "2026-05-10T...", "member_count": 6 }
  ]
}
```

---

### 9. Show one competitor set

`GET /api/competitor_sets/:id`

**Request**

```bash
curl 'http://localhost:3000/api/competitor_sets/2'
```

Response shape is the same `competitor_set` object as endpoint #7 (with `members` populated).

---

### 10. Add a competitor manually

`POST /api/competitor_sets/:id/members`

For the "add a restaurant that wasn't suggested" search bar. If the same restaurant existed but was soft-removed, this restores it.

**Body**

| Field | Type | Default |
|---|---|---|
| `restaurant_id` | integer (required) | — |
| `source` | `"manual"` \| `"suggested"` | `"manual"` |

**Request**

```bash
curl -X POST 'http://localhost:3000/api/competitor_sets/2/members' \
  -H 'Content-Type: application/json' \
  -d '{"restaurant_id": 99, "source": "manual"}'
```

**Response 201**

```json
{
  "member": {
    "id": 13,
    "competitor_set_id": 2,
    "restaurant_id": 99,
    "source": "manual",
    "added_at": "2026-05-10T...",
    "removed_at": null
  }
}
```

---

### 11. Remove a competitor

`DELETE /api/competitor_sets/:id/members/:member_id`

Soft-delete: writes `removed_at`, doesn't drop the row.

**Request**

```bash
curl -X DELETE 'http://localhost:3000/api/competitor_sets/2/members/13'
```

**Response 204** (empty body)

---

## Daily Digest

### 12. Daily digest for one date

`GET /api/pilot_restaurants/:id/daily_digest`

**Query**

| Param | Type | Default |
|---|---|---|
| `date` | ISO date | today |

**Request**

```bash
curl 'http://localhost:3000/api/pilot_restaurants/2/daily_digest?date=2026-05-08'
```

**Response 200**

```json
{
  "daily_digest": {
    "id": 4,
    "digest_date": "2026-05-08",
    "summary": "Cafe Here & Now posted about their English Kitchen offering, gaining minimal engagement. No immediate threat to Blue Tokai.",
    "quiet_day": false,
    "status": "published",
    "generated_at": "2026-05-08T22:30:14Z",
    "cards": [
      {
        "id": 2,
        "competitor_restaurant_id": 2,
        "change_summary": "Cafe Here & Now posted about English Kitchen.",
        "why_it_matters": "Minimal engagement suggests low impact on Blue Tokai's customer base.",
        "recommendation": "ignore",
        "rationale": "Low engagement and no direct overlap with Blue Tokai's offerings.",
        "priority": "0.1"
      }
    ]
  }
}
```

**Response 200 (quiet day)**

```json
{
  "daily_digest": {
    "id": 5,
    "digest_date": "2026-05-09",
    "summary": "No significant changes today across your pilot or your tracked competitors.",
    "quiet_day": true,
    "status": "published",
    "generated_at": "2026-05-09T22:30:11Z",
    "cards": []
  }
}
```

**Response 404**

```json
{ "error": { "code": "no_digest", "message": "No digest for 2026-05-10" } }
```

---

### 13. Daily digest list (date range)

`GET /api/pilot_restaurants/:id/daily_digests`

For sidebar/calendar of past digests. Returns summaries only — call #12 to load a specific day's cards.

**Query**

| Param | Default |
|---|---|
| `from` | 30 days ago |
| `to` | today |

**Request**

```bash
curl 'http://localhost:3000/api/pilot_restaurants/2/daily_digests?from=2026-05-06&to=2026-05-10'
```

**Response 200**

```json
{
  "from": "2026-05-06",
  "to":   "2026-05-10",
  "daily_digests": [
    { "id": 4, "digest_date": "2026-05-09", "summary": "No significant changes...", "quiet_day": true,  "status": "published" },
    { "id": 3, "digest_date": "2026-05-08", "summary": "Cafe Here & Now posted...",  "quiet_day": false, "status": "published" },
    { "id": 2, "digest_date": "2026-05-07", "summary": "No significant changes...", "quiet_day": true,  "status": "published" },
    { "id": 1, "digest_date": "2026-05-06", "summary": "Blue Tokai launched...",     "quiet_day": false, "status": "published" }
  ]
}
```

---

## Competitor Analysis

### 14. Leaderboard

`GET /api/competitor_sets/:id/leaderboard`

Ranked Competitive Health Score rows for one date.

**Query**

| Param | Default |
|---|---|
| `date` | today |

**Request**

```bash
curl 'http://localhost:3000/api/competitor_sets/2/leaderboard?date=2026-05-09'
```

**Response 200**

```json
{
  "date": "2026-05-09",
  "leaderboard": [
    { "rank": 1, "restaurant_id": 22, "name": "Blue Tokai Coffee Roasters | HSR Layout",
      "total_score": "43.5", "score_delta_7d": null,
      "headline_signal": "Trending on Instagram (486 engagement)", "is_pilot": true },
    { "rank": 2, "restaurant_id": 50, "name": "Cafe 27",
      "total_score": "25.28", "score_delta_7d": null, "headline_signal": "Steady", "is_pilot": false },
    { "rank": 3, "restaurant_id": 2,  "name": "Cafe Here & Now",
      "total_score": "24.28", "score_delta_7d": null, "headline_signal": "Steady", "is_pilot": false }
  ]
}
```

---

### 15. Leaderboard history (score series)

`GET /api/competitor_sets/:id/leaderboard/history`

Score-over-time per restaurant for charting.

**Query**

| Param | Default |
|---|---|
| `from` | 30 days ago |
| `to` | today |

**Request**

```bash
curl 'http://localhost:3000/api/competitor_sets/2/leaderboard/history?from=2026-05-06&to=2026-05-09'
```

**Response 200**

```json
{
  "from": "2026-05-06",
  "to":   "2026-05-09",
  "history": {
    "22": [
      { "date": "2026-05-06", "total_score": "33.5", "rank": 1 },
      { "date": "2026-05-07", "total_score": "33.5", "rank": 1 },
      { "date": "2026-05-08", "total_score": "33.5", "rank": 1 },
      { "date": "2026-05-09", "total_score": "43.5", "rank": 1 }
    ],
    "50": [
      { "date": "2026-05-06", "total_score": "16.5",  "rank": 2 },
      { "date": "2026-05-09", "total_score": "25.28", "rank": 2 }
    ]
  }
}
```

---

### 16. Threat assessments (per pilot)

`GET /api/pilot_restaurants/:id/threat_assessments`

Latest computed threats for each competitor in the active set, ordered by `total_threat` descending.

**Request**

```bash
curl 'http://localhost:3000/api/pilot_restaurants/2/threat_assessments'
```

**Response 200**

```json
{
  "threat_assessments": [
    {
      "id": 4,
      "competitor_restaurant_id": 11,
      "segment_overlap": "0.6667",
      "price_band_overlap": "1.0",
      "neighbourhood_overlap": "0.3039",
      "cuisine_overlap": "0.3333",
      "total_threat": "0.5193",
      "rationale": "BANOFFEE poses a moderate threat to Blue Tokai, primarily due to a 100% overlap in price band... 33% cuisine overlap and 30% neighbourhood overlap.",
      "computed_at": "2026-05-10T12:34:00Z"
    },
    { "competitor_restaurant_id": 65, "total_threat": "0.3742", "...": "..." }
  ]
}
```

---

## Restaurant Drill-down

### 17. Restaurant profile

`GET /api/restaurants/:id`

Identity + latest snapshot for the drill-down header card.

**Request**

```bash
curl 'http://localhost:3000/api/restaurants/22'
```

**Response 200**

```json
{
  "restaurant": {
    "id": 22,
    "name": "Blue Tokai Coffee Roasters | HSR Layout",
    "maps_url": "https://www.google.com/maps/place/...",
    "rating": "4.2",
    "review_count": 888,
    "primary_cuisines": ["Cafe", "Coffee"],
    "price_band": null,
    "cost_for_two": 600,
    "lat": "12.9128",
    "lng": "77.6448",
    "latest_snapshot": {
      "city": "Bangalore",
      "locality": "HSR Layout",
      "area": "Sector 6",
      "address": "1st Floor, 24th Main, HSR Layout...",
      "cuisines": ["Cafe", "Coffee"],
      "avg_rating": "4.2",
      "total_ratings": 888,
      "is_open": true,
      "image_url": "https://...",
      "swiggy_url": "https://www.swiggy.com/restaurant-info/91628",
      "scrapped_at_date": "2026-05-09"
    }
  }
}
```

---

### 18. Current menu

`GET /api/restaurants/:id/menu`

Items from the latest scrape (or a specific date).

**Query**

| Param | Default |
|---|---|
| `date` | latest |

**Request**

```bash
curl 'http://localhost:3000/api/restaurants/22/menu?date=2026-05-09'
```

**Response 200**

```json
{
  "scrapped_at_date": "2026-05-09",
  "items": [
    { "id": 4011, "category": "Coffee", "subcategory": "Espresso",
      "name": "Cappuccino", "price": 220, "price_raw": "₹220",
      "description": "House-blend espresso with steamed milk.",
      "veg": true, "rating": "4.4", "rating_count": 132,
      "bestseller": true, "availability": "Available" },
    { "id": 4012, "category": "Food", "subcategory": "Sandwiches",
      "name": "Veg Club Sandwich", "price": 320, "price_raw": "₹320",
      "veg": true, "bestseller": false, "availability": "Available" }
  ]
}
```

**Response 404**

```json
{ "error": { "code": "no_menu_snapshot", "message": "No menu snapshot for the requested date" } }
```

---

### 19. Menu changes (tracker)

`GET /api/restaurants/:id/menu_changes`

Added / removed / repriced / renamed events over a window.

**Query**

| Param | Default |
|---|---|
| `since` | `30d` (also accepts ISO date) |

**Request**

```bash
curl 'http://localhost:3000/api/restaurants/11/menu_changes?since=14d'
```

**Response 200**

```json
{
  "since": "2026-04-26",
  "events": [
    { "id": 88, "event_type": "price_increased",
      "menu_item_name": "Banoffee Cake Slice", "category": "Desserts",
      "prev_price": 240, "new_price": 280, "price_delta": 40,
      "prev_scrapped_at_date": "2026-05-07", "scrapped_at_date": "2026-05-08" },
    { "id": 87, "event_type": "added",
      "menu_item_name": "Cold Brew Float", "category": "Beverages",
      "prev_price": null, "new_price": 260, "price_delta": null,
      "scrapped_at_date": "2026-05-08" }
  ]
}
```

---

### 20. Rating trend

`GET /api/restaurants/:id/rating_trend`

Avg rating + review-count series.

**Query**

| Param | Default |
|---|---|
| `from` | 30 days ago |
| `to` | today |

**Request**

```bash
curl 'http://localhost:3000/api/restaurants/22/rating_trend?from=2026-05-06&to=2026-05-09'
```

**Response 200**

```json
{
  "from": "2026-05-06", "to": "2026-05-09",
  "series": [
    { "date": "2026-05-06", "avg_rating": "4.2", "total_ratings": 884, "google_rating": "4.3", "google_rating_count": 1240 },
    { "date": "2026-05-07", "avg_rating": "4.2", "total_ratings": 886, "google_rating": "4.3", "google_rating_count": 1242 },
    { "date": "2026-05-08", "avg_rating": "4.2", "total_ratings": 887, "google_rating": "4.3", "google_rating_count": 1245 },
    { "date": "2026-05-09", "avg_rating": "4.2", "total_ratings": 888, "google_rating": "4.3", "google_rating_count": 1247 }
  ]
}
```

---

### 21. Pricing analysis

`GET /api/restaurants/:id/pricing_analysis`

Per-category average prices, optionally compared to the pilot.

**Query**

| Param | Default |
|---|---|
| `compare_to` | active pilot's `restaurant_id` |

**Request**

```bash
curl 'http://localhost:3000/api/restaurants/11/pricing_analysis?compare_to=22'
```

**Response 200**

```json
{
  "target_id": 11,
  "pilot_id":  22,
  "categories": [
    { "name": "Coffee",   "target_avg": 195.0, "pilot_avg": 220.0, "delta": -25.0 },
    { "name": "Desserts", "target_avg": 280.0, "pilot_avg": null,  "delta": null  },
    { "name": "Food",     "target_avg": 340.0, "pilot_avg": 320.0, "delta":  20.0 }
  ]
}
```

---

### 22. Activity feed

`GET /api/restaurants/:id/activity_feed`

Chronological detected events (menu, rating, offer, social, SERP).

**Query**

| Param | Default |
|---|---|
| `since` | `14d` |
| `types` | all (comma-separated filter, e.g. `menu_added,rating_shift`) |

**Request**

```bash
curl 'http://localhost:3000/api/restaurants/11/activity_feed?since=14d&types=menu_added,offer_added'
```

**Response 200**

```json
{
  "since": "2026-04-26",
  "events": [
    { "id": 311, "event_type": "offer_added",
      "summary": "New offer: 20% off above ₹500",
      "occurred_on": "2026-05-08", "significance": "3.0",
      "before": null, "after": { "offer": "20% off above ₹500" } },
    { "id": 309, "event_type": "menu_added",
      "summary": "Added Cold Brew Float at ₹260",
      "occurred_on": "2026-05-08", "significance": "2.0",
      "before": null, "after": { "name": "Cold Brew Float", "category": "Beverages", "price": 260 } }
  ]
}
```

---

### 23. Social signals (Instagram)

`GET /api/restaurants/:id/social_signals`

Recent posts from the brand's own handle plus tagged hashtag posts.

**Query**

| Param | Default |
|---|---|
| `since` | `14d` |

**Request**

```bash
curl 'http://localhost:3000/api/restaurants/22/social_signals?since=7d'
```

**Response 200**

```json
{
  "since": "2026-05-03",
  "posts": [
    { "id": 401, "source": "profile",
      "ig_post_id": "3891351545984314324",
      "post_url": "https://www.instagram.com/p/DYA250ij-vU/",
      "post_type": "image", "owner_username": "thebluetokai",
      "caption": "Summer Specials are here...",
      "hashtags": ["summerspecials", "bluetokai"], "mentions": [],
      "likes_count": 486, "comments_count": 12,
      "engagement_score": 486, "posted_at": "2026-05-09T09:14:00Z",
      "is_promotional": true, "sentiment": "positive" },
    { "id": 402, "source": "hashtag",
      "ig_post_id": "3891091942406989010",
      "post_url": "https://www.instagram.com/p/DX_74F3jaTS/",
      "post_type": "image", "owner_username": "veluro_coffee",
      "caption": "Coffee is a language in itself...",
      "likes_count": 0, "comments_count": 0,
      "posted_at": "2026-05-06T13:32:00Z",
      "is_promotional": false, "sentiment": null }
  ]
}
```

---

### 24. SERP presence

`GET /api/restaurants/:id/serp_presence`

Latest Google search results scrape for that restaurant.

**Query**

| Param | Default |
|---|---|
| `date` | latest available |

**Request**

```bash
curl 'http://localhost:3000/api/restaurants/22/serp_presence'
```

**Response 200**

```json
{
  "scrapped_at_date": "2026-05-09",
  "search_term":     "Blue Tokai Coffee Roasters",
  "results_total":   null,
  "organic": [
    { "position": 1, "title": "Blue Tokai Coffee Roasters",
      "url": "https://bluetokaicoffee.com/",
      "displayed_url": "https://bluetokaicoffee.com",
      "description": "Specialty coffee roasted in India...",
      "result_type": "organic", "average_rating": null,
      "number_of_reviews": null, "followers_amount": null,
      "channel_name": null },
    { "position": 2, "title": "Blue Tokai (@bluetokaicoffee)",
      "url": "https://www.instagram.com/bluetokaicoffee/",
      "channel_name": "bluetokaicoffee",
      "followers_amount": "180K+ followers",
      "result_type": "organic" }
  ],
  "questions": [
    { "question": "Where is Blue Tokai HSR Layout?", "answer": "...", "url": "..." }
  ]
}
```

**Response 404**

```json
{ "error": { "code": "no_serp_scrape", "message": "No SERP scrape available" } }
```

---

## Chatbot

### 25. Create a chat session

`POST /api/chat_sessions`

**Body**

| Field | Type |
|---|---|
| `pilot_restaurant_id` | integer (required) |
| `title` | string (optional) |

**Request**

```bash
curl -X POST 'http://localhost:3000/api/chat_sessions' \
  -H 'Content-Type: application/json' \
  -d '{"pilot_restaurant_id": 2, "title": "Pricing check"}'
```

**Response 201**

```json
{
  "chat_session": {
    "id": 1,
    "pilot_restaurant_id": 2,
    "title": "Pricing check",
    "started_at": "2026-05-10T12:34:56Z",
    "last_message_at": null,
    "message_count": 0
  }
}
```

---

### 26. List chat sessions

`GET /api/chat_sessions?pilot_restaurant_id=`

**Request**

```bash
curl 'http://localhost:3000/api/chat_sessions?pilot_restaurant_id=2'
```

**Response 200**

```json
{
  "chat_sessions": [
    { "id": 2, "pilot_restaurant_id": 2, "title": null,
      "started_at": "2026-05-10T15:00:00Z", "last_message_at": "2026-05-10T15:02:30Z",
      "message_count": 4 },
    { "id": 1, "pilot_restaurant_id": 2, "title": "Pricing check",
      "started_at": "2026-05-10T12:34:56Z", "last_message_at": "2026-05-10T12:36:10Z",
      "message_count": 6 }
  ]
}
```

---

### 27. Show one chat session

`GET /api/chat_sessions/:id`

**Request**

```bash
curl 'http://localhost:3000/api/chat_sessions/1'
```

**Response 200**

```json
{
  "chat_session": {
    "id": 1,
    "pilot_restaurant_id": 2,
    "title": "Pricing check",
    "started_at": "2026-05-10T12:34:56Z",
    "last_message_at": "2026-05-10T12:36:10Z",
    "message_count": 6
  }
}
```

---

### 28. Get chat transcript

`GET /api/chat_sessions/:id/messages`

By default, omits `tool_calls` / `tool_results`. Add `?include=trace` to get them.

**Request**

```bash
curl 'http://localhost:3000/api/chat_sessions/1/messages'
```

**Response 200**

```json
{
  "messages": [
    { "id": 1, "role": "user",
      "content": "How does my pricing compare to my competitors?",
      "citations": null, "model_version": null,
      "created_at": "2026-05-10T12:35:00Z" },
    { "id": 2, "role": "assistant",
      "content": "Your average mains run ₹45 above the competitor median... Suggested next step: revisit weekday-lunch pricing on the Veg Club Sandwich.",
      "citations": { "restaurant_ids": [2, 3, 8, 11, 50, 65] },
      "model_version": "gpt-4o",
      "created_at": "2026-05-10T12:35:08Z" }
  ]
}
```

**Request (with trace)**

```bash
curl 'http://localhost:3000/api/chat_sessions/1/messages?include=trace'
```

Adds `tool_calls` and `tool_results` to each message.

---

### 29. Send a chat message

`POST /api/chat_sessions/:id/messages`

Records the user message, runs the OpenAI tool-use loop (max 6 iterations), persists and returns the assistant reply.

**Body**

| Field | Type |
|---|---|
| `content` | string (required) |

**Query**

| Param | Default |
|---|---|
| `include` | none — set to `trace` to include `tool_calls` + `tool_results` in the response |

**Request**

```bash
curl -X POST 'http://localhost:3000/api/chat_sessions/1/messages' \
  -H 'Content-Type: application/json' \
  -d '{"content": "How does my pricing compare to my competitors?"}'
```

**Response 201**

```json
{
  "user_message": {
    "id": 1, "role": "user",
    "content": "How does my pricing compare to my competitors?",
    "citations": null, "model_version": null,
    "created_at": "2026-05-10T12:35:00Z"
  },
  "assistant_message": {
    "id": 2, "role": "assistant",
    "content": "Your Coffee category averages ₹220, ₹25 above BANOFFEE's ₹195. Your Food prices sit ~₹20 below Glen's Bakehouse. Suggested next step: hold Coffee pricing, watch BANOFFEE for further moves.",
    "citations": { "restaurant_ids": [11, 8] },
    "model_version": "gpt-4o",
    "created_at": "2026-05-10T12:35:08Z"
  }
}
```

**Response 502 (LLM call failed)**

```json
{ "error": { "code": "llm_error", "message": "OpenAI call failed: ..." } }
```

---

## Common error responses

| Status | Code | When |
|---|---|---|
| 400 | `bad_request` | Required params missing or malformed |
| 400 | `missing_pilot` | `pilot_restaurant_id` required and not resolvable |
| 404 | `not_found` | Generic record-not-found |
| 404 | `no_pilot_restaurant` | No active pilot set |
| 404 | `no_digest` | Digest not yet generated for the requested date |
| 404 | `no_menu_snapshot` | No menu scrape on the requested date |
| 404 | `no_serp_scrape` | No SERP scrape for the restaurant |
| 422 | `validation_failed` | DB validation rejected the payload |
| 422 | `invalid_verdict` | (n/a — feedback endpoint removed) |
| 502 | `llm_error` | Underlying OpenAI call failed |

---

## Notes for the frontend

- **Numbers come back as strings** for `decimal` columns (Rails serializes `BigDecimal` as string). Cast to float in the client where you need to do math (`parseFloat`).
- **Dates** are ISO strings (`YYYY-MM-DD` for date, RFC3339 for datetime).
- **Pagination not in v1** for chat / activity feeds — assume reasonable defaults (`limit ≤ 50`).
- **Latency.** Chat (#29) runs a tool-use loop and can take 3–10s. Other endpoints are <500ms.
- **Caching.** Daily digest, leaderboard, threat assessments are date-keyed and update once per scoring run. Safe to cache client-side until the next scrape window.
