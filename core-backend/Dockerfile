# ==========================================
# Stage 1: Build Dependencies & Compile Wheels
# ==========================================
FROM python:3.12-alpine AS builder

WORKDIR /usr/src/app

# Install OS utilities needed to compile C-bindings for MySQL
RUN apk add --no-cache gcc musl-dev mariadb-dev pkgconfig

COPY requirements.txt .

# Build wheels into a local cache directory
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels -r requirements.txt

# ==========================================
# Stage 2: Minimal Distroless-like Runtime
# ==========================================
FROM python:3.12-alpine

# Prevent Python from writing .pyc files to disk at runtime (Crucial for Read-Only Root Filesystems)
ENV PYTHONDONTWRITEBYTECODE=1
# Force unbuffered stdout/stderr logging for immediate CloudWatch ingestion
ENV PYTHONUNBUFFERED=1

WORKDIR /usr/src/app

# Install only the runtime C-library for MariaDB/MySQL (No compilers)
RUN apk add --no-cache mariadb-connector-c

# Secure User Assignment
RUN addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S appuser -G appgroup

# Retrieve pre-compiled python wheels from builder
COPY --from=builder /usr/src/app/wheels /images/wheels
COPY --from=builder /usr/src/app/requirements.txt .
RUN pip install --no-cache /images/wheels/*

# Copy code configuration
COPY --chown=appuser:appgroup . .

USER 10001

EXPOSE 8000

# Run with Gunicorn. 
# Note: EKS deployment manifests must provision an emptyDir volume mounted to /tmp 
# because Gunicorn uses /tmp for worker heartbeat synchronization.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "3", "--access-logfile", "-", "config.wsgi:application"]