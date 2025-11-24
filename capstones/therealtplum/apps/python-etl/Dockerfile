FROM python:3.12-slim

WORKDIR /app

# No heavy deps yet; we just need a valid image that starts.
COPY etl ./etl

ENV PYTHONUNBUFFERED=1

CMD ["python", "-m", "etl.polygon_news"]