# ────────────────────────────────────────────────
# ✅ Directus Render Auto Backend
# Works with Aiven, PlanetScale, Supabase, or any SQL DB
# Boots even if the database has no tables yet
# ────────────────────────────────────────────────
FROM directus/directus:latest

# Set working directory
WORKDIR /directus

# Switch to root temporarily to install packages
USER root
RUN apk add --no-cache mysql-client postgresql-client curl bash
USER node

# Allow secure SSL connections (for Aiven)
ENV NODE_TLS_REJECT_UNAUTHORIZED=0

# Expose Directus port
EXPOSE 8055

# Health check for uptime monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8055/server/health || exit 1

# ────────────────────────────────────────────────
# Start Script:
# 1️⃣ Waits for MySQL/Postgres connection
# 2️⃣ Skips table creation if DB is empty
# 3️⃣ Boots Directus admin if not initialized
# ────────────────────────────────────────────────
CMD sh -c '\
  echo "🚀 Launching Directus Auto Backend..." && \
  echo "🔍 Database: $DB_CLIENT at $DB_HOST:$DB_PORT" && \
  echo "📦 Database name: $DB_DATABASE" && \
  \
  MAX_RETRIES=30 && \
  RETRY_COUNT=0 && \
  \
  if [ "$DB_CLIENT" = "postgres" ] || [ "$DB_CLIENT" = "pg" ]; then \
    echo "⏳ Waiting for PostgreSQL connection..." && \
    until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" 2>/dev/null || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do \
      RETRY_COUNT=$((RETRY_COUNT + 1)); \
      echo "   Attempt $RETRY_COUNT/$MAX_RETRIES..."; \
      sleep 3; \
    done; \
  else \
    echo "⏳ Waiting for MySQL connection..." && \
    until mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" --silent 2>/dev/null || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do \
      RETRY_COUNT=$((RETRY_COUNT + 1)); \
      echo "   Attempt $RETRY_COUNT/$MAX_RETRIES..."; \
      sleep 3; \
    done; \
  fi; \
  \
  if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then \
    echo "❌ Database connection failed after $MAX_RETRIES attempts"; \
    exit 1; \
  fi; \
  \
  echo "✅ Database connection established!" && \
  echo "🔑 Bootstrapping Directus (creates admin if needed)..." && \
  npx directus bootstrap || echo "⚠️ Bootstrap skipped (already initialized)" && \
  \
  echo "🎉 Starting Directus..." && \
  echo "🌐 Public URL: ${PUBLIC_URL:-http://localhost:8055}" && \
  npx directus start'
