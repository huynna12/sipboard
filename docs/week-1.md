# Week 1: Cafés near me

**Goal by the end of the week:** `GET /api/v1/cafes/nearby?lat=21.0285&lng=105.8542&radius=1000` returns real cafés sorted by distance, with tests.
**How we work:** you write the code on a branch, open a pull request, and I review it. Each day is about 4–5 hours. Hints are below, but try first and peek second.

---

## Day 1: Setup and a tour of the skeleton
1. Install **JDK 21**, **Docker Desktop**, and **IntelliJ IDEA Community**.
2. Run it (see README): `docker compose up -d`, then `cd backend && ./mvnw spring-boot:run`, then open http://localhost:8080/actuator/health.
3. Run the tests: `./mvnw verify`. Watch Testcontainers start a real Postgres in Docker.
4. Read every file in the skeleton and be able to explain:
   - What `@SpringBootApplication` does (component scanning + auto-configuration)
   - What `application.yml` configures, and what `${DB_URL:...}` means (env var with a default)
   - Why `ddl-auto: validate` and why Flyway owns the schema
   - What `V1__extensions.sql` enables and why each extension matters for this app
5. Read: [Building a RESTful Web Service](https://spring.io/guides/gs/rest-service) and [Accessing Data with JPA](https://spring.io/guides/gs/accessing-data-jpa).

## Day 2: The `cafes` table and the `Cafe` entity
- Create `V2__cafes.sql`. Columns: `id` (BIGINT identity), `name`, `location`, `address`, `city`, `country_code`, `status` (default `'UNVERIFIED'`), `created_at` (default `now()`).
- `location` is `GEOGRAPHY(Point, 4326)`. Add a **GIST index** on it; this is what makes "near me" fast.
- Create `com.sipboard.cafe.Cafe` as a JPA entity.

<details><summary>Hints</summary>

- Map `location` as `org.locationtech.jts.geom.Point` with `@Column(columnDefinition = "geography(Point,4326)")`. Hibernate Spatial is already on the classpath.
- **Classic bug:** a JTS `Coordinate` is `(x, y)` = **(longitude, latitude)**, not (lat, lng).
  `new GeometryFactory(new PrecisionModel(), 4326).createPoint(new Coordinate(lng, lat))`
- Use `TEXT` for string columns, not `CHAR(n)`: Hibernate's `validate` rejects `CHAR(2)` mapped to a `String`.
- JPA needs a no-args constructor (it can be `protected`).
</details>

## Day 3: The "near me" query
- Create `CafeRepository extends JpaRepository<Cafe, Long>`.
- Add a method that returns cafés within `radius` meters of a point, nearest first, with their distance.

<details><summary>Hints</summary>

- Use a native query (`@Query(value = "...", nativeQuery = true)`) with PostGIS:
  `ST_DWithin(location, ST_MakePoint(:lng, :lat)::geography, :radius)` to filter (uses the GIST index),
  `ST_Distance(...)` to compute meters, `ORDER BY` distance, `LIMIT`.
- For the result, an **interface projection** (`interface NearbyCafe { Long getId(); String getName(); Double getDistanceMeters(); }`) works with native queries. Name the SQL column alias to match the getter.
</details>

## Day 4: The controller and DTOs
- `GET /api/v1/cafes/nearby?lat=&lng=&radius=` (radius default 1000, min 50, max 5000).
- `POST /api/v1/cafes` to create a café (temporary, for seeding; it gets locked down once we add login).
- Return **response records**, never the entity itself. Ask yourself why.

<details><summary>Hints</summary>

- Put constraints directly on parameters: `@RequestParam @DecimalMin("-90") @DecimalMax("90") double lat`. Spring validates them automatically and returns 400 when they fail.
- For the POST body, use a `record CreateCafeRequest(@NotBlank String name, ...)` and `@Valid @RequestBody`.
- Keep logic in a `CafeService`; the controller only translates HTTP ↔ Java.
</details>

## Day 5: Errors that clients can understand
- Make every error return a consistent JSON body. Spring supports **ProblemDetail** (RFC 9457).
- Add a `@RestControllerAdvice` that turns "café not found" into 404 and validation errors into 400 with the field names.
- Add `GET /api/v1/cafes/{id}` (404 when missing).

## Day 6: Tests
- **Repository test:** `@DataJpaTest` + `@AutoConfigureTestDatabase(replace = NONE)` + `@Import(TestcontainersConfiguration.class)`. Insert 3 cafés in Hanoi at known coordinates and assert that only the 2 within 1 km come back, nearest first.
- **Controller test:** `@WebMvcTest(CafeController.class)` with `@MockitoBean` for the service. Assert that `lat=200` gives 400 and a valid request gives 200.

<details><summary>Spring Boot 4 import paths (they moved from Boot 3)</summary>

- `org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest`
- `org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase`
- `org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest`
- `org.springframework.test.context.bean.override.mockito.MockitoBean` (replaces `@MockBean`)
</details>

## Day 7: Seed real data and ship
- Add 10–20 real cafés you know in Hanoi or Saigon (name + coordinates from your phone's map) using your POST endpoint, or a dev-only SQL file.
- Try the nearby endpoint from your browser.
- Open a pull request for the week. I'll review it like a teammate would.

---

## Concepts to be able to explain after this week (interview prep)
- Dependency injection and why constructor injection is preferred
- Entity vs DTO, and why you never return entities from controllers
- What a GIST index is and why `ST_DWithin` uses it but `ST_Distance < r` in a `WHERE` doesn't
- Geography vs geometry in PostGIS (meters on the globe vs flat coordinates)
- Why schema migrations (Flyway) instead of `ddl-auto: update`
- `@DataJpaTest` vs `@WebMvcTest` vs `@SpringBootTest`
