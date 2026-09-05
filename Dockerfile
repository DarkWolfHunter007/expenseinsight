# ExpenseInsight Backend - Lightweight Inference Container
# Python 3.11 slim base image
FROM python:3.11-slim

# Prevent Python from writing .pyc files and enable unbuffered logging
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    DATABASE_URL=sqlite:////app/data/expenseinsight.db \
    MODEL_PATH=/app/backend/ml/models/expense_classifier.joblib \
    METRICS_PATH=/app/backend/ml/models/model_metrics.json \
    UPLOADS_DIR=/app/data/uploads \
    SAMPLE_STATEMENTS_DIR=/app/backend/sample_statements \
    OFFLINE_TRAINING_MODE=true

WORKDIR /app

# Install system dependencies if required
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python backend dependencies
COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /app/backend/requirements.txt

# Create directories for persistent data storage and statement uploads
RUN mkdir -p /app/data /app/data/uploads

# Copy application source code and self-contained ML inference modules
COPY backend /app/backend

# Expose FastAPI server port
EXPOSE 8000

# Container healthcheck targeting the /health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Start FastAPI application using Uvicorn
CMD ["uvicorn", "backend.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
