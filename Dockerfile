# syntax=docker/dockerfile:1.7
############################
# Docker build environment #
############################

FROM node:22.19-bookworm-slim AS build

# Upgrade all packages and install dependencies
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        python3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /build
# Install dependencies first to leverage Docker layer caching
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
# Now copy the rest of the source
COPY . .
# Build
RUN npm run build
RUN npm prune --omit=dev

############################
# Docker final environment #
############################

FROM node:22.19-bookworm-slim
LABEL org.opencontainers.image.title="public-pool-api" \
      org.opencontainers.image.description="Public Pool Backend" \
      org.opencontainers.image.source="https://github.com/benjamin-wilson/public-pool" \
      org.opencontainers.image.licenses="GPL-3.0"

ENV NODE_ENV=production

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*


# Expose ports for Stratum & API
EXPOSE 3333 3334

WORKDIR /public-pool

# Copy only what the runtime needs
COPY --from=build --chown=node:node /build/dist ./dist
COPY --from=build --chown=node:node /build/node_modules ./node_modules
COPY --from=build --chown=node:node /build/package*.json ./

USER node
STOPSIGNAL SIGTERM

CMD ["node", "dist/main"]
