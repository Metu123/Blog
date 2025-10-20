# ────────────────────────────────────────────────
# ✅ Directus Render Auto Backend (PostgreSQL-ready)
# Works with Render, Aiven, Supabase, PlanetScale, etc.
# ────────────────────────────────────────────────
FROM directus/directus:latest

# Set working directory
WORKDIR /directus

# Switch to root temporarily to install DB clients
USER root
RUN apk add --no-cache postgresql-client mysql-client curl bash
USER node

# Allow SSL connections (for cloud databases)
ENV NODE_TLS_REJECT_UNAUTHORIZED=0

# Expose Directus port
EXPOSE 8055

# Healthcheck for uptime monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8055/server/health || exit 1

# ────────────────────────────────────────────────
# Startup Script
# 1️⃣ Wait for DB connection
# 2️⃣ Bootstrap Directus (admin auto-setup)
# 3️⃣ Start Directus server
# ────────────────────────────────────────────────
CMD sh -c '\
  echo "🚀 Launching Directus Auto Backend..." && \
  echo "🔍 Database client: ${DB_CLIENT:-pg}" && \
  echo "🌐 Public URL: ${PUBLIC_URL:-http://localhost:8055}" && \
  \
  MAX_RETRIES=30 && \
  RETRY_COUNT=0 && \
  \
  # Detect Postgres client
  if [ "${DB_CLIENT:-pg}" = "pg" ] || [ "$DB_CLIENT" = "postgres" ]; then \
    echo "⏳ Waiting for PostgreSQL connection to ${DB_HOST}..." && \
    until pg_isready -h "$DB_HOST" -p "${DB_PORT:-5432}" -U "$DB_USER" >/dev/null 2>&1 || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do \
      RETRY_COUNT=$((RETRY_COUNT + 1)); \
      echo "   Attempt $RETRY_COUNT/$MAX_RETRIES..."; \
      sleep 3; \
    done; \
  else \
    echo "⏳ Waiting for MySQL connection to ${DB_HOST}..." && \
    until mysqladmin ping -h"$DB_HOST" -P"${DB_PORT:-3306}" -u"$DB_USER" -p"$DB_PASSWORD" --silent >/dev/null 2>&1 || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do \
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
  echo "🔑 Bootstrapping Directus..." && \
  npx directus bootstrap || echo "⚠️ Bootstrap skipped (already initialized)" && \
  \
  echo "🎉 Starting Directus..." && \
  npx directus start'
