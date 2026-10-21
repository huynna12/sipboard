-- PostGIS: geography types and "near me" queries (ST_DWithin, ST_Distance)
CREATE EXTENSION IF NOT EXISTS postgis;
-- unaccent: search "ca phe" and match "cà phê"
CREATE EXTENSION IF NOT EXISTS unaccent;
-- pg_trgm: typo-tolerant name search and duplicate detection (similarity)
CREATE EXTENSION IF NOT EXISTS pg_trgm;
