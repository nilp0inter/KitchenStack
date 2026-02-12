# Multi-stage build for Elm client
# Stage 1: Build (amd64 only - Elm output is platform-independent JS)
FROM --platform=linux/amd64 node:20-alpine AS builder

WORKDIR /app

# Install Elm compiler (amd64 binary)
RUN apk add --no-cache curl && \
    curl -L -o elm.gz https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz && \
    gunzip elm.gz && chmod +x elm && mv elm /usr/local/bin/

# Copy package files and install dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Copy source and build
COPY . .
RUN npm run build

# Stage 2: Final image (minimal Alpine with static files)
FROM alpine:latest
COPY --from=builder /app/dist /dist
CMD ["echo", "Static files available in /dist"]
