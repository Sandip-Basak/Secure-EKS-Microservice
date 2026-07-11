# ==========================================
# Stage 1: Build Phase
# ==========================================
FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# ==========================================
# Stage 2: Hardened Static Assets Engine
# ==========================================
FROM nginx:1.27-alpine

# Overwrite default master config with our zero-root / read-only compliant build
COPY nginx.conf /etc/nginx/nginx.conf

# Clear out default placeholder assets
RUN rm -rf /usr/share/nginx/html/*

# Pull optimized bundle from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Establish dedicated system runtime privileges
RUN touch /tmp/nginx.pid && \
    chown -R 10001:10001 /tmp /var/cache/nginx /usr/share/nginx/html

USER 10001

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]