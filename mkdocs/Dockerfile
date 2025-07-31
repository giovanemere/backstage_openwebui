# Dockerfile multi-stage para MkDocs con procesamiento de conversaciones
# Optimizado para demo en Minikube

# Stage 1: Base con Python y dependencias del sistema
FROM python:3.11-slim as base

# Metadatos
LABEL maintainer="Amazon Q <demo@example.com>"
LABEL description="MkDocs con procesamiento automático de conversaciones Backstage-OpenWebUI"
LABEL version="1.0.0"
LABEL demo.minikube/optimized="true"
LABEL demo.minikube/component="mkdocs"

# Variables de entorno
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: Instalación de dependencias Python
FROM base as dependencies

# Copiar requirements
COPY requirements.txt /tmp/requirements.txt

# Instalar dependencias Python
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Stage 3: Construcción de la aplicación
FROM dependencies as builder

# Crear usuario no-root
RUN groupadd -r mkdocs && useradd -r -g mkdocs -u 1000 mkdocs

# Crear directorios de trabajo
RUN mkdir -p /app/{docs-source,site,templates,processors,data,config} && \
    chown -R mkdocs:mkdocs /app

# Copiar archivos de configuración
COPY --chown=mkdocs:mkdocs configs/mkdocs.yml /app/mkdocs.yml
COPY --chown=mkdocs:mkdocs processors/ /app/processors/
COPY --chown=mkdocs:mkdocs templates/ /app/templates/

# Stage 4: Imagen final optimizada
FROM dependencies as final

# Copiar usuario y directorios desde builder
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group
COPY --from=builder --chown=mkdocs:mkdocs /app /app

# Configurar directorio de trabajo
WORKDIR /app

# Cambiar a usuario no-root
USER mkdocs

# Exponer puerto
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

# Comando por defecto
CMD ["mkdocs", "serve", "--config-file=/app/mkdocs.yml", "--dev-addr=0.0.0.0:8000"]
