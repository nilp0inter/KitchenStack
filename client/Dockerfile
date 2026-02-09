# Build stage: compile Elm and build static assets
FROM --platform=linux/amd64 node:20-alpine AS builder

WORKDIR /app

# Install Elm compiler
RUN apk add --no-cache curl && \
    curl -L -o elm.gz https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz && \
    gunzip elm.gz && \
    chmod +x elm && \
    mv elm /usr/local/bin/

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci

# Copy source files
COPY . .

# Build the application
RUN npm run build

# Production stage: minimal image with just the static files
FROM alpine:latest

# Copy built assets from builder
COPY --from=builder /app/dist /dist

# This image just holds the files - they'll be mounted as a volume
CMD ["echo", "Static files available in /dist"]
