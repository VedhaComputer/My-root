# Stage 1: Build TypeScript source
FROM node:20-alpine@sha256:fb4cd12c85ee03686f6af5362a0b0d56d50c58a04632e6c0fb8363f609372293 AS builder

WORKDIR /app

# Install build dependencies
COPY package*.json ./
RUN npm ci

# Copy TypeScript config and sources
COPY tsconfig.json ./
COPY src/ ./src/

# Compile TypeScript to dist/
RUN npm run build

# Remove development dependencies
RUN npm prune --production

# Stage 2: Production runtime image
FROM node:20-alpine@sha256:fb4cd12c85ee03686f6af5362a0b0d56d50c58a04632e6c0fb8363f609372293 AS runner

# Install signal supervisor (dumb-init) and curl for container healthcheck
RUN apk add --no-cache dumb-init curl

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3001

# Copy compiled artifacts and production dependencies from builder with node user ownership
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/package*.json ./

# Switch to unprivileged non-root user
USER node

# Expose backend application port
EXPOSE 3001

# Container healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3001/health || exit 1

# Signal forwarding and graceful shutdown
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server.js"]
