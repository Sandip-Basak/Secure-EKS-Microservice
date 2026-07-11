# ==========================================
# Stage 1: Build Phase
# ==========================================
FROM python:3.12-alpine AS builder

WORKDIR /usr/src/app

RUN apk add --no-cache gcc musl-dev linux-headers

COPY requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels -r requirements.txt

# ==========================================
# Stage 2: Hardened Runtime Context
# ==========================================
FROM python:3.12-alpine

# Guarantee Python processes outputs immediately to stdout streams without caching
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /usr/src/app

RUN addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S appuser -G appgroup

COPY --from=builder /usr/src/app/wheels /images/wheels
COPY --from=builder /usr/src/app/requirements.txt .
RUN pip install --no-cache /images/wheels/*

COPY --chown=appuser:appgroup . .

USER 10001

EXPOSE 5000

# Default fallback command (Can be completely overridden by Kubernetes Args)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]