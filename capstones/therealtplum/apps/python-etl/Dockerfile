FROM python:3.12-slim

# Install OS libs if needed later
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements if it exists (recommended)
COPY requirements.txt ./

# Install Python deps
RUN pip install --no-cache-dir -r requirements.txt || true

# Copy ETL code
COPY etl ./etl

# Default command does nothing (we run modules explicitly)
CMD ["python", "-m", "etl"]