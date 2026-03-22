# ============================================
# FILE: Dockerfile
# PURPOSE: Multi-stage build for Flutter Web to be deployed on Railway
# DEPENDENCIES: nginx:alpine, flutter[stable]
# ============================================

# STAGE 1: The Heavy Lifter (Flutter Build)
FROM debian:stable-slim AS build

# No-interaction frontend to avoid hanging
ENV DEBIAN_FRONTEND=noninteractive

# Essential packages for Flutter and Web deployment
RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils libglu1-mesa python3 libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter stable channel
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Audit and verify Flutter environment
RUN flutter doctor -v
RUN flutter config --enable-web

# Setup working directory and build the app
WORKDIR /app
COPY . .

# Fetch dependencies
RUN flutter pub get

# Build production web release (optimized)
RUN flutter build web --release --no-tree-shake-icons --source-maps

# STAGE 2: The Slim Runner (Nginx Runtime)
FROM nginx:alpine

# Clear default static files
RUN rm -rf /usr/share/nginx/html/*

# Copy build artifacts from previous stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy optimized Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Use Railway's PORT env var (defaults to 3000)
ENV PORT=3000
EXPOSE 3000

# Dynamically replace nginx port and start
CMD sh -c "sed -i 's/listen 80/listen '$PORT'/g' /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
