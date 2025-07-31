# =============================================================================
# Dockerfile Multi-stage para OpenWebUI - Optimizado para Demo Minikube
# =============================================================================
# Imagen final optimizada: ~150MB (vs ~500MB imagen estándar)
# Tiempo de build: ~3-5 minutos
# Recursos requeridos: 512Mi RAM, 500m CPU

# =============================================================================
# STAGE 1: Base Python Environment
# =============================================================================
FROM python:3.11-alpine AS base

# Instalar dependencias del sistema
RUN apk add --no-cache \
    gcc \
    musl-dev \
    libffi-dev \
    openssl-dev \
    curl \
    git \
    && rm -rf /var/cache/apk/*

# Crear usuario no-root
RUN addgroup -g 1001 -S openwebui && \
    adduser -S openwebui -u 1001 -G openwebui

# Configurar directorio de trabajo
WORKDIR /app

# Configurar variables de entorno
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# =============================================================================
# STAGE 2: Dependencies Installation
# =============================================================================
FROM base AS deps

# Actualizar pip y instalar herramientas de build
RUN pip install --upgrade pip setuptools wheel

# Copiar archivos de dependencias
COPY requirements.txt ./

# Instalar dependencias Python con optimizaciones
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir \
    gunicorn==21.2.0 \
    psycopg2-binary==2.9.7 \
    redis==4.6.0

# =============================================================================
# STAGE 3: Build Application
# =============================================================================
FROM deps AS builder

# Copiar código fuente
COPY . .

# Configurar variables de build para demo
ENV OPENWEBUI_DEMO_MODE=true
ENV OPENWEBUI_MINIKUBE_OPTIMIZED=true

# Build de assets estáticos si es necesario
RUN if [ -f "build.py" ]; then python build.py; fi

# Limpiar archivos innecesarios
RUN find . -type f -name "*.pyc" -delete && \
    find . -type d -name "__pycache__" -delete && \
    rm -rf .git .pytest_cache tests/

# =============================================================================
# STAGE 4: Final Production Image
# =============================================================================
FROM python:3.11-alpine AS production

# Metadatos de la imagen
LABEL maintainer="Amazon Q <demo@example.com>"
LABEL version="0.1.124"
LABEL description="OpenWebUI optimized for Backstage integration and Minikube demo"
LABEL demo.minikube.optimized="true"
LABEL demo.minikube.memory-limit="512Mi"
LABEL demo.minikube.cpu-limit="500m"

# Instalar solo dependencias runtime mínimas
RUN apk add --no-cache \
    dumb-init \
    curl \
    postgresql-client \
    && rm -rf /var/cache/apk/*

# Crear usuario no-root
RUN addgroup -g 1001 -S openwebui && \
    adduser -S openwebui -u 1001 -G openwebui

# Configurar directorio de trabajo
WORKDIR /app

# Copiar dependencias Python
COPY --from=deps /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=deps /usr/local/bin /usr/local/bin

# Copiar aplicación
COPY --from=builder --chown=openwebui:openwebui /app .

# Crear directorios necesarios
RUN mkdir -p /app/data /app/logs && \
    chown -R openwebui:openwebui /app

# Configurar variables de entorno para producción
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV OPENWEBUI_DEMO_MODE=true
ENV WEBUI_PORT=8080
ENV DATA_DIR=/app/data
ENV STATIC_DIR=/app/static

# Variables específicas para integración con Backstage
ENV BACKSTAGE_INTEGRATION_ENABLED=true
ENV BACKSTAGE_WEBHOOK_URL=http://backstage:7007/api/webhooks/openwebui
ENV ENABLE_SIGNUP=true
ENV DEFAULT_USER_ROLE=user

# Variables de base de datos (para PostgreSQL compartido)
ENV DATABASE_URL=postgresql://backstage:demo-backstage-password@postgresql:5432/backstage_openwebui
ENV ENABLE_OAUTH_SIGNUP=false

# Configurar health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=45s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Exponer puerto
EXPOSE 8080

# Cambiar a usuario no-root
USER openwebui

# Comando de inicio con gunicorn optimizado para demo
ENTRYPOINT ["dumb-init", "--"]
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--worker-class", "uvicorn.workers.UvicornWorker", "--max-requests", "1000", "--max-requests-jitter", "100", "--preload", "main:app"]

# =============================================================================
# Build Instructions:
# docker build -t edissonz8809/iaops/openwebui:demo-latest -f applications/openwebui/Dockerfile .
# docker run -p 8080:8080 edissonz8809/iaops/openwebui:demo-latest
# =============================================================================
