# SipBoard: Build Plan

**One line:** find cafés that fit what you need right now (study, work, chill), see what your friends think, and share your spots.
**Focus:** cafés only. Study/work attributes come first; more categories (date spot, view, specialty coffee, egg coffee…) come later.
**Markets:** Vietnam first (huge café culture), English + Vietnamese from day one, built so other countries and languages plug in.
**Stack:** Spring Boot (Java 21) API + Expo (React Native, TypeScript) app for iOS, Android and web.
**Why it's different from Beli/Google Maps:** they rate taste and general quality. This answers "can I sit here for 3 hours with my laptop, and are my friends here?" using fresh, crowdsourced, café-specific data.

---

## MVP features
1. **Map + list near me** with filters: open now, wifi, outlets, quiet, busy now
2. **Café page:** wifi speed, outlets, noise, seating and busyness, each shown with *how fresh* the data is; photos; friends who've been
3. **Check-in:** one tap for "how busy is it"; optionally add attributes, a photo or a note. **In-app wifi speed test** attaches a real measurement.
4. **Lists:** save cafés to lists ("Study spots in District 1"), share a link that opens on the web without an account
5. **Friends + feed:** follow friends, see their check-ins and saved cafés
6. **Add a missing café** with "is this the same as…?" duplicate suggestions
7. **Café board (personal memory board):** each check-in lets you pin **one photo** to your corkboard, grouped by city. It's your own memory, separate from the café's public photos.
   - **Front:** the photo shown as a polaroid with a film-like filter.
   - **Back (tap to flip):** a short journal note, character-limited (~200 characters, counted per character because Vietnamese words are short syllables), shown in a handwritten font that supports Vietnamese diacritics (test "Đường, ở, ữ").
   - **Private by default.** Each pin and board can be private, friends-only or public. Choosing the pinned photo never publishes it to the café page.
   - **Later:** a handwritten signature drawn once on screen, stored as vector strokes (SVG path) and shown at the end of every note; drag to arrange; stickers and themes; joint boards with friends; a share image for Instagram/TikTok stories; a yearly café recap.
   - **Backend:** `Pin` (one per check-in, enforced by a unique constraint) → photo, note, filter preset, layout (position, rotation, z-order). Photos have a visibility (public on the café page vs. private pin only). The note limit is validated on the server, not just in the app. The filter is applied at display time, so the original is kept and filters can change later; the server renders it only when generating a share image (async job → S3).
8. **Vietnamese / English**, with accent-insensitive search ("ca phe" finds "cà phê")

## Design and motion (the reason people will use it)
Design a few **signature moments** and make them excellent, rather than polishing everything:
1. **The polaroid develops** after you check in: it fades in from blank like real instant film.
2. **Flip the polaroid** to read the handwritten note on the back.
3. **Pin drop:** the photo lands on the corkboard with a slight random tilt and a haptic tap.
4. **The map comes alive:** gray pins turn to color as cafés get rated.

**Tools (Expo):** `react-native-reanimated` + `react-native-gesture-handler` (60 fps animations and gestures), `@shopify/react-native-skia` (film filters, paper texture, polaroid rendering), `expo-haptics`, Lottie for small accents.
**Process:** sketch the 3 core screens (map, check-in, board) in Figma before coding them. Pick one font pair, one color palette and one motion style (soft, paper-like), and reuse them everywhere.

**The backend makes the motion feel smooth (good resume material too):**
- Blurhash/tiny placeholders generated on the server at upload, so photos appear instantly and then sharpen
- Multiple image sizes (thumbnail / board / full) served from a CDN
- Fast APIs (p95 < 200 ms) and optimistic updates: the polaroid animates immediately while the upload finishes in the background, with retry if it fails
- Prefetching the next board page and nearby cafés

## v2 (after the MVP scope is done)
- **Groups with shared boards:** friends create a group (e.g., "Saigon study crew") and pin to one board together.
  - Backend: `Group`, `GroupMember` (roles: owner/member), invites by link, a shared board where each pin keeps its author, real-time updates when someone pins, and permission checks per group.
  - **Design for it now:** give `Board` its own table with an owner (a user for now) and a `BoardMember` table, instead of hanging pins directly off the user. Adding groups later is then a new feature, not a migration of every pin.
- Handwritten signature, drag-to-arrange, stickers/themes, share image for stories, yearly café recap.

## Where café data comes from
**Google Maps can't be your database.** Scraping Google Maps breaks its terms. The official Places API is allowed but restricted ([service terms](https://cloud.google.com/maps-platform/terms/maps-service-terms)):
- You may keep the **place ID** long-term.
- **Coordinates can be cached for at most 30 days.**
- Other content (names, photos, ratings) must be fetched live with Google attribution.
- Google content must **not be shown on a non-Google map**.
- You pay per request beyond the free monthly usage.

**So use a hybrid where the core data is yours:**
- **Your `Cafe` table:** OpenStreetMap seed (free, ODbL attribution) + cafés users add. Coordinates come from OSM or the user's pin/GPS, so you own them and can search them with PostGIS.
- **Add-a-café flow:** Google Places Autocomplete so users pick the right place quickly; store only its `place_id` next to your record.
- **Café page:** optionally fetch Google details (hours, photos) live by `place_id`, with attribution.
- **Map:** use Google Maps as the map provider in the app (`react-native-maps` with the Google provider), so showing Google content is allowed.
- **Your attributes** (wifi, outlets, noise, busyness, check-ins, lists) are 100% your data. That's the actual product.
- **Main way cafés get added: check-in-to-create.** When a user checks in, the app shows cafés within ~75 m ("Are you at one of these?"). If none match, they create the café right there: the location comes from their GPS, the name is typed (or picked via Google autocomplete, storing only the `place_id`), and their photos become the first photos. The creator gets a **"Discovered by"** badge on the café.
  - **Creating a café needs at least 3 photos**, one of them the storefront or sign. Photos must be taken with the in-app camera, or their EXIF time and location are checked against the check-in on the server before being stripped.
  - **Checking in at an existing café needs 1 photo**; extra photos are optional (cap around 10 per check-in for storage cost and abuse).
  - **Matching uses distance + name, not address alone.** Vietnamese addresses are messy, and one building can hold many cafés on different floors (e.g., the "café apartment" at 42 Nguyễn Huệ, HCMC). Allow several cafés at one address with a floor/unit field.
  - New cafés start **unverified**. Verification:
    1. **Phase 1, now:** an admin moderation queue in the app where you approve or reject new cafés yourself.
    2. **Phase 2, later:** an automated verifier tries an allowed lookup first (Google Places Text Search near the coordinates, or a web search API to find the café's Facebook/Instagram page). A confident match auto-verifies; anything unclear goes to your queue. No scraping of Google Maps.
    3. A check-in from a second, independent user also verifies it.
  - Indoor GPS is often off by 20–50 m (worse on upper floors and in alleys), so let the user drag the pin, and check for duplicates by distance + name similarity.
  - Photos: presigned S3 upload, strip EXIF location data, resize, basic moderation.
- **Check OpenStreetMap coverage** for Hanoi/HCMC early; it's likely incomplete, which is why seeding matters.
- **Cold start:** before launch, you + ~10 friends add or check in at 200 cafés in Hanoi and HCMC, plus your US town. An empty map kills apps like this.

## Data model (first version)
`User` (locale, home city) · `Friendship` (requested/accepted) · `Cafe` (name, normalized name, PostGIS point, address, city, country, source OSM/user, osm_id, opening hours, status) · `CheckIn` (user, cafe, time, busyness 1–5, note, photo) · `AttributeReport` (user, cafe, wifi Mbps, outlets, noise, seating, laptop-friendly) · `CafeAttributes` (computed aggregate + freshness) · `CafeList` + `CafeListItem` (shareable) · `Photo` (S3 key, moderation status) · `DuplicateCandidate` / `MergeLog`

## Architecture
```
Expo app / web ──HTTPS──> Spring Boot API (stateless, scales horizontally)
                              │── PostgreSQL + PostGIS (+ unaccent, pg_trgm)
                              │── Redis (live busyness windows, hot search cache, rate limits)
                              │── S3 (photos via presigned uploads)
                              │── Outbox → SQS → workers (same codebase, worker profile):
                              │      aggregate attributes, resize/moderate photos,
                              │      dedup candidates, feed fan-out, notifications
                              └── Spring Batch job: OpenStreetMap import (idempotent upserts)
CI/CD: GitHub Actions · Hosting: AWS (ECS/EC2 + RDS + ElastiCache) · Metrics: Micrometer → Prometheus/Grafana
```

## The hard backend problems (your resume bullets)
| Problem | Approach |
|---|---|
| "Near me" search with filters, fast | PostGIS `ST_DWithin` + GiST index, filter on aggregated attributes, cursor pagination, Redis cache for hot areas |
| Accent-insensitive, typo-tolerant search in Vietnamese and English | `unaccent` + `pg_trgm` trigram indexes; later OpenSearch with ICU folding |
| Trusting crowdsourced data | Time-decayed weighted aggregates, reporter reputation, median wifi speed with outlier rejection, "last confirmed X days ago" |
| Live "how busy right now" | Rolling 60-minute window of check-ins in Redis with TTLs; fall back to a typical-hour-of-week pattern |
| Duplicate cafés | Name similarity (trigram) + distance threshold → candidate queue → merge with an audit log |
| Importing OpenStreetMap | Spring Batch job, chunked, idempotent upserts by osm_id, incremental re-runs |
| Photos | Presigned S3 uploads, async resize, basic moderation, CDN |
| Friend feed | Fan-out on write (small friend graphs); explain the trade-off vs fan-out on read |
| Internationalization | Spring `MessageSource` bundles, locale-aware formatting; user content stays in its own language |
| Security and abuse | Spring Security + Google/Apple sign-in (JWT), rate limiting, spam detection on reports |
| Proof of scale | Gatling/k6: e.g. nearby-search at 2k req/s with p99 < 150 ms, published in the README |

## Roadmap (4–5 h/day ≈ 30 h/week, solo; starting Oct 20, 2026)
Estimate (you know Java; Spring, React Native and the animation libraries are new): **~5–6 weeks to a rough beta with 5 friends, ~11–12 weeks (early to mid January) to a polished beta with 30–50 users.** About 330–350 hours, including a ~20% buffer for school, finals and learning curves. The biggest unknown is the app side (React Native animation and Skia), not Spring.

| Weeks | Dates | Focus | Done when |
|---|---|---|---|
| 1–2 | Oct 20 – Nov 2 | **Spring foundations + backend core:** project setup, Docker Compose (Postgres+PostGIS, Redis), Flyway, JPA, cafés, near-me search, OSM import (Spring Batch), Google/Apple sign-in | API returns cafés near a point; logged-in user |
| 3–4 | Nov 3 – Nov 16 | **Check-ins + photos + pins:** check-in-to-create, duplicate matching, S3 presigned uploads, EXIF checks, pin + note, wifi/outlet reports. Start the Expo app: map + café page | Create a café and a pin from the API |
| 5–6 | Nov 17 – Nov 30 | **App core + design:** Figma for map/check-in/board, camera check-in flow, board grid, flip card, film filter. Deploy to AWS. (Thanksgiving week counts as half.) | **Rough beta: 5 friends use it on their phones** |
| 7–8 | Dec 1 – Dec 14 | **Signature motion + admin:** polaroid develops, pin drop, gray→color map; admin review queue; accent-insensitive search; blurhash + image sizes. (Finals season, so plan lighter weeks.) | The 4 signature moments feel good |
| 9–10 | Dec 15 – Dec 28 | **Friends + privacy + polish:** follow friends, friend feed, board privacy, Vietnamese/English, CI + tests (Testcontainers), monitoring | Ready for outsiders |
| 11–12 | Dec 29 – Jan 11 | **Seed + launch:** you + friends seed ~200 cafés (in person if you're in Vietnam over break), TestFlight + Android testing, load test, README with numbers | **Beta with 30–50 users** |
| 13+ | Jan 12 → | Iterate on feedback, live busyness, share-to-story image, then v2 (groups) | Weekly active users growing |

**If you want users sooner:** cut friends/feed and the OSM import from the first beta (seed by hand), which saves about 2 weeks.

## Launch plan
1. **Seed** 200 cafés with attributes in 2–3 cities with friends before anyone else sees it.
2. **Beta** with 30–50 friends in Vietnam and the US.
3. **Grow** through shared lists ("my 10 best study cafés in Hanoi"): each link brings new users. Post on TikTok/Instagram/Threads, where café review content already does well in Vietnam.
4. **Track from day 1:** signups, weekly active users, check-ins/week, cafés with fresh data, week-1 and week-4 retention.
