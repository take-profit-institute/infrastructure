#!/usr/bin/env bash
# Dump the local Docker PostgreSQL schema into a single-DB, schema-separated
# bootstrap SQL file for AWS RDS.
#
# Default output:
#   database/init/candle-bootstrap-schema.sql
#
# The dump includes:
#   - schema/DDL for each local service database
#   - flyway_schema_history rows so services do not rerun existing migrations
#
# It does not include application table data by default. Set INCLUDE_DATA=true
# if a full data snapshot is intentionally needed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$ROOT/database/init/candle-bootstrap-schema.sql}"
CONTAINER="${POSTGRES_CONTAINER:-candle-local-v2-postgres-1}"
USER="${POSTGRES_USER:-postgres}"
INCLUDE_DATA="${INCLUDE_DATA:-false}"

mkdir -p "$(dirname "$OUT")"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "Postgres container '$CONTAINER' is not running." >&2
  echo "Start it first: docker compose up -d postgres" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat > "$OUT" <<'SQL'
-- Candle bootstrap schema dump.
-- Generated from local Docker PostgreSQL.
-- Target layout: one database named "candle", service isolation by schemas.
\set ON_ERROR_STOP on

CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS trading;
CREATE SCHEMA IF NOT EXISTS account;
CREATE SCHEMA IF NOT EXISTS order_svc;
CREATE SCHEMA IF NOT EXISTS reservation;
CREATE SCHEMA IF NOT EXISTS portfolio;
CREATE SCHEMA IF NOT EXISTS ranking;
CREATE SCHEMA IF NOT EXISTS mission;
CREATE SCHEMA IF NOT EXISTS learning;
CREATE SCHEMA IF NOT EXISTS batch;
CREATE SCHEMA IF NOT EXISTS stock;
CREATE SCHEMA IF NOT EXISTS wishlist;
CREATE SCHEMA IF NOT EXISTS news;
CREATE SCHEMA IF NOT EXISTS notification;

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;

SQL

dump_db() {
  local db="$1"
  local target_schema="$2"
  local raw="$tmpdir/${db}.sql"
  local hist="$tmpdir/${db}.history.sql"

  if ! docker exec "$CONTAINER" psql -U "$USER" -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname = '$db'" | grep -qx 1; then
    echo "skip missing database: $db" >&2
    return
  fi

  echo "dump $db -> schema $target_schema"
  {
    echo ""
    echo "-- ---- $db -> $target_schema ----"
    echo "SET search_path = $target_schema, public;"
  } >> "$OUT"

  docker exec "$CONTAINER" pg_dump \
    -U "$USER" \
    -d "$db" \
    --schema-only \
    --no-owner \
    --no-privileges \
    --exclude-schema='pg_*' \
    --exclude-schema='information_schema' \
    > "$raw"

  # Local service DBs mostly use public schema. In AWS, unqualified service
  # objects live in the service schema. Explicit domain schemas such as
  # trading's account/order_svc/reservation are preserved.
  perl -pe "s/\\bpublic\\./${target_schema}./g; s/SCHEMA public/SCHEMA ${target_schema}/g" "$raw" >> "$OUT"

  # Preserve Flyway history rows so Flyway validate can pass after bootstrapping
  # from a schema dump. Missing tables are fine for services without migrations.
  if docker exec "$CONTAINER" pg_dump \
      -U "$USER" \
      -d "$db" \
      --data-only \
      --inserts \
      --no-owner \
      --no-privileges \
      --table='*.flyway_schema_history' \
      > "$hist" 2>/dev/null; then
    perl -pe "s/\\bpublic\\./${target_schema}./g; s/SCHEMA public/SCHEMA ${target_schema}/g" "$hist" >> "$OUT"
  fi

  if [ "$INCLUDE_DATA" = "true" ]; then
    echo "-- data snapshot for $db" >> "$OUT"
    docker exec "$CONTAINER" pg_dump \
      -U "$USER" \
      -d "$db" \
      --data-only \
      --inserts \
      --no-owner \
      --no-privileges \
      --exclude-table='*.flyway_schema_history' \
      | perl -pe "s/\\bpublic\\./${target_schema}./g; s/SCHEMA public/SCHEMA ${target_schema}/g" >> "$OUT"
  fi
}

dump_db candle_auth auth
dump_db candle_users users
dump_db candle_trading trading
dump_db candle_portfolio portfolio
dump_db candle_ranking ranking
dump_db candle_mission mission
dump_db candle_learning learning
dump_db candle_batch batch
dump_db candle_stock stock
dump_db candle_wishlist wishlist
dump_db candle_news news
dump_db candle_notification notification

cat >> "$OUT" <<'SQL'

-- Runtime grants. Terraform postgres-init creates the roles; this dump may be
-- applied by the RDS master user, so grant service roles access to restored
-- objects explicitly.
GRANT USAGE, CREATE ON SCHEMA auth TO auth;
GRANT USAGE, CREATE ON SCHEMA users TO users;
GRANT USAGE, CREATE ON SCHEMA trading, account, order_svc, reservation TO trading;
GRANT USAGE, CREATE ON SCHEMA portfolio TO portfolio;
GRANT USAGE, CREATE ON SCHEMA ranking TO ranking;
GRANT USAGE, CREATE ON SCHEMA mission TO mission;
GRANT USAGE, CREATE ON SCHEMA learning TO learning;
GRANT USAGE, CREATE ON SCHEMA batch TO batch;
GRANT USAGE, CREATE ON SCHEMA stock TO stock;
GRANT USAGE, CREATE ON SCHEMA wishlist TO wishlist;
GRANT USAGE, CREATE ON SCHEMA news TO news;
GRANT USAGE, CREATE ON SCHEMA notification TO notification;

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA auth TO auth;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA users TO users;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA trading, account, order_svc, reservation TO trading;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA portfolio TO portfolio;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA ranking TO ranking;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA mission TO mission;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA learning TO learning;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA batch TO batch;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA stock TO stock;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA wishlist TO wishlist;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA news TO news;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA notification TO notification;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA auth TO auth;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA users TO users;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA trading, account, order_svc, reservation TO trading;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA portfolio TO portfolio;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA ranking TO ranking;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA mission TO mission;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA learning TO learning;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA batch TO batch;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA stock TO stock;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA wishlist TO wishlist;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA news TO news;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA notification TO notification;
SQL

echo "wrote $OUT"
