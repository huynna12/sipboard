# SipBoard

- **Backend:** Java 21, Spring Boot 4.1, PostgreSQL + PostGIS, Redis, Flyway
- **App:** Expo (React Native, TypeScript), coming in a later step
- **Plan:** [docs/plan.md](docs/plan.md) · **This week:** [docs/week-1.md](docs/week-1.md)

## Repository layout
```
backend/             Spring Boot API
  src/main/java/com/sipboard/      code, organized by feature (cafe/, checkin/, board/, user/ ...)
  src/main/resources/db/migration/  Flyway SQL migrations (the database schema lives here)
docker-compose.yml   local Postgres/PostGIS + Redis
docs/                plan and weekly guides
```

## Run it locally
Prerequisites: JDK 21, Docker Desktop.

```bash
docker compose up -d          # start Postgres/PostGIS and Redis
cd backend
./mvnw spring-boot:run        # start the API on http://localhost:8080
curl localhost:8080/actuator/health   # → {"status":"UP", ...}
```

## Run the tests
```bash
cd backend
./mvnw verify                 # starts throwaway Postgres + Redis containers with Testcontainers
```
