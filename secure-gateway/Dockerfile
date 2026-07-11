# ==========================================
# Stage 1: Build & Dependency Isolation
# ==========================================
FROM node:22-alpine AS builder

WORKDIR /usr/src/app

# Copy dependency manifests first to leverage Docker layer caching
COPY package*.json ./

# Install only production dependencies. Eliminates development tools and vulnerabilities.
RUN npm ci --omit=dev

# ==========================================
# Stage 2: Minimal Production Runtime
# ==========================================
FROM node:22-alpine

ENV NODE_ENV=production
WORKDIR /usr/src/app

# Security: Create an explicit system user/group with static IDs. 
# Do NOT reuse default IDs to avoid collision with the EKS host OS.
RUN addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S appuser -G appgroup

# Pull production node_modules and code from the builder stage
COPY --from=builder --chown=appuser:appgroup /usr/src/app/node_modules ./node_modules
COPY --chown=appuser:appgroup . .

# Explicitly switch execution context to the non-privileged user
USER 10001

EXPOSE 3000

# Use node directly. Avoid 'npm start' in production containers as npm doesn't forward OS signals (SIGTERM) correctly to the process.
CMD ["node", "src/server.js"]