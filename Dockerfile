# ============================================
# FILE: Dockerfile
# PURPOSE: Multi-stage build for Flutter Web on Railway
# FEATURES: Env-var injection, CanvasKit renderer, Nginx SPA routing
# ============================================

# STAGE 1: Build Stage
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy dependencies first for better caching
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source code
COPY . .

# Build Arguments for Supabase (Passed from Railway Variables)
ARG SUPABASE_URL
ARG SUPABASE_ANON_KEY

# Build the web application
# --web-renderer canvaskit: ensures visual consistency
# --dart-define: injects keys at build time
RUN flutter build web --release \
    --web-renderer canvaskit \
    --dart-define=SUPABASE_URL=$SUPABASE_URL \
    --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
    --no-tree-shake-icons

# STAGE 2: Runtime Stage
FROM nginx:alpine

# Copy built artifacts
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy our optimized Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port (Internal for Nginx, Railway proxy maps it)
EXPOSE 80

# Keep Nginx running
CMD ["nginx", "-g", "daemon off;"]
