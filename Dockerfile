# Flutter Web for Railway - Optimized Build
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy and get dependencies first (better caching)
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source
COPY . .

# Build web
RUN flutter build web --release

# Production stage - use a simple Python HTTP server instead of nginx
FROM python:3.11-slim

WORKDIR /app

# Copy built web app
COPY --from=build /app/build/web ./

# Use PORT env var with default 3000
ENV PORT=3000
EXPOSE 3000

# Simple Python HTTP server on Railway's PORT
CMD python -m http.server $PORT
