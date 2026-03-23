# Flutter Web for Railway - Optimized Build
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy and get dependencies first (better caching)
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source
COPY . .

# Build web with HTML renderer and correct base href
RUN flutter build web --release --web-renderer html --base-href "/"

# Production stage - use a simple Python HTTP server
FROM python:3.11-slim

WORKDIR /app

# Copy built web app contents (trailing slash ensures contents are copied)
COPY --from=build /app/build/web/ ./

# Verify the build output exists
RUN ls -la

# Use PORT env var with default 3000
ENV PORT=3000
EXPOSE 3000

# Simple Python HTTP server on Railway's PORT
CMD python -m http.server $PORT
