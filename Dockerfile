### Build stage
FROM python:3.11-slim as build
#  slim version of Python 3.11, has a size of 121 MB. Alpine is useless for ML systems.
ENV PIP_DEFAULT_TIMEOUT=100 \
    # Increased 100 the default timeout value for pip
    PYTHONUNBUFFERED=1 \
    # Allow statements and log messages to appear immediately
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    # disable a pip version check to reduce run-time & log-spam
    PIP_NO_CACHE_DIR=1 \
    # cache is useless in a docker image, so disable it to reduce image size
ARG POETRY_VERSION=1.3.2

WORKDIR /app
COPY pyproject.toml poetry.lock ./

RUN pip install "poetry==$POETRY_VERSION" \
    && poetry install --no-root --no-ansi --no-interaction \
    && poetry export -f requirements.txt -o requirements.txt


### Final stage
FROM python:3.11-slim as final

WORKDIR /app

COPY --from=build /app/requirements.txt .
## Sec session: user permissions and access control
RUN set -ex \
    # Create a non-root user
    && addgroup --system --gid 1001 appgroup \
    && adduser --system --uid 1001 --gid 1001 --no-create-home appuser \
    # RUN chown -R appuser:appuser /your-subdirectory
    # Upgrade the package index and install security upgrades
    && apt-get update \
    && apt-get upgrade -y \
    # Install dependencies
    && pip install -r requirements.txt \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

COPY ./artifacts artifacts
COPY ./api api

EXPOSE 8000

CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]

# Set the user to run the application
USER appuser
