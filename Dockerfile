# Image: Apache Airflow with Python dependencies
# This Dockerfile builds an Apache Airflow image with additional Python dependencies.
FROM apache/airflow:3.0.0

# Install dependencies for building Python packages
# Use the root user to install system dependencies
USER root
RUN apt-get update && apt-get install -y \
    build-essential \
    python3-dev \
    libldap2-dev \
    libsasl2-dev \
    libssl-dev \
    git \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Install ODBC driver 17 for SQL Server
RUN apt-get update && apt-get install -y curl gnupg && \
    curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/11/prod bullseye main" > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql17 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Change to airflow user for subsequent commands
USER airflow

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy

ENV PYTHONPATH="/opt/airflow/src:${PYTHONPATH}"

# Install the project's dependencies using the lockfile and settings
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project --no-dev

RUN python -m pip install prophet

COPY data/ /opt/airflow/data/
COPY src/ /opt/airflow/src/

    
