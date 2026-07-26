FROM python:3.14-alpine3.24

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apk upgrade --no-cache \
    && apk add --no-cache curl ca-certificates \
    && addgroup -S app \
    && adduser -S -G app -h /app app

WORKDIR /app
COPY pyproject.toml README.md /app/
COPY src /app/src
COPY services/healthcare-api/requirements.txt /app/requirements.txt
RUN pip install --upgrade pip setuptools wheel \
    && pip install -r /app/requirements.txt \
    && pip install /app

COPY services/healthcare-api/app /app/app
RUN chown -R app:app /app
USER app

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=3).read()"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
