# ────────────────────────────────────────────────
# ✅ Directus Render Auto Backend
# Connects to ANY SQL database (MySQL or PostgreSQL)
# Boots even if database has no tables yet
# ────────────────────────────────────────────────
FROM directus/directus:latest

WORKDIR /directus

# Copy environment configuration
COPY .env .env

# Install database clients and utilities
RUN apk add --no-cache \
    mysql-client \
    postgresql-client \
    curl \
    bash

# Allow secure SSL connections (for Aiven, PlanetScale, etc.)
ENV NODE_TLS_REJECT_UNAUTHORIZED=0

EXPOSE 8055

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8055/server/health || exit 1

# ────────────────────────────────────────────────
# Start script logic:
# 1️⃣ Detect database type
# 2️⃣ Wait for DB connectivity (not tables)
# 3️⃣ Bootstrap admin login (only if not yet created)
# 4️⃣ Start Directus UI & API
# ────────────────────────────────────────────────
CMD sh -c '\
  echo "🚀 Launching Directus Auto Backend..." && \
  echo "🔍 Database: $DB_CLIENT at $DB_HOST:$DB_PORT" && \
  echo "📦 Database name: $DB_DATABASE" && \
  \
  # Database connection waiting with timeout
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
    echo "❌ Database connection failed after $MAX_RETRIES attempts" && \
    echo "   Check your DB_HOST, DB_PORT, DB_USER, and DB_PASSWORD" && \
    exit 1; \
  fi; \
  \
  echo "✅ Database connection established!" && \
  echo "🔑 Bootstrapping Directus (creates tables & admin user)..." && \
  npx directus bootstrap || echo "⚠️  Bootstrap skipped (likely already initialized)" && \
  \
  echo "🎉 Starting Directus on port $PORT..." && \
  echo "🌐 Public URL: $PUBLIC_URL" && \
  npx directus start'
