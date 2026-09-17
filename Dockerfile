# ============================================================
# Seclock — FastAPI app image
# Multi-stage build: compile deps in "builder", copy only the
# installed packages + app source into a slim runtime image.
# ============================================================

# ---------- Build stage ----------
FROM python:3.12-slim AS builder

WORKDIR /build

# Build tools needed to compile any deps without prebuilt wheels
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc \
        libjpeg-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ---------- Runtime stage ----------
FROM python:3.12-slim

WORKDIR /app

# Runtime shared libs required by Pillow
RUN apt-get update && apt-get install -y --no-install-recommends \
        libjpeg62-turbo \
        zlib1g \
        curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -u 1000 appuser

# Bring in the packages installed in the builder stage
COPY --from=builder /root/.local /home/appuser/.local

# App source (explicit list keeps __pycache__/tests out of the image)
COPY main.py crypto_engine.py ocr_engine.py audit_ledger.py generate_certificates.py ./
COPY static ./static
COPY sample_certificates ./sample_certificates

ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://127.0.0.1:8080/api/state || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
