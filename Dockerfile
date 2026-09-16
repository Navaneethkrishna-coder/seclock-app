# Use a lightweight Python image
FROM python:3.11-slim

# Prevent Python from creating .pyc files
# and ensure logs are sent directly to stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Application directory inside the container
WORKDIR /app

# Install system dependencies
# Build tools are useful for Python packages that may need compilation
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        libffi-dev \
        && rm -rf /var/lib/apt/lists/*

# Copy dependency file first for Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY main.py .
COPY crypto_engine.py .
COPY ocr_engine.py .
COPY audit_ledger.py .
COPY static/ ./static/
COPY sample_certificates/ ./sample_certificates/

# Create a non-root user
RUN useradd --create-home --shell /bin/bash appuser && \
    chown -R appuser:appuser /app

# Run the application as non-root
USER appuser

# FastAPI port
EXPOSE 8000

# Start FastAPI
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
