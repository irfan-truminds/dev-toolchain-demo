FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install minimal OS dependencies for Git hooks & security tooling
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    && rm -rf /var/lib/apt-get/lists/*

# Install Python dependencies first for optimal Docker layer caching
COPY pyproject.toml .
RUN pip install --upgrade pip setuptools wheel && \
    pip install -e .[dev]

# Copy application source code and scripts
COPY . .

CMD ["bash"]
