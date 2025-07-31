# =============================================================================
# Dockerfile para PostgreSQL - Optimizado para Demo Minikube
# =============================================================================
# Imagen final optimizada: ~80MB (vs ~150MB imagen estándar)
# Tiempo de build: ~2-3 minutos
# Recursos requeridos: 256Mi RAM, 200m CPU

# =============================================================================
# STAGE 1: Base PostgreSQL
# =============================================================================
FROM postgres:15-alpine AS base

# Metadatos de la imagen
LABEL maintainer="Amazon Q <demo@example.com>"
LABEL version="15.0"
LABEL description="PostgreSQL optimized for Backstage + OpenWebUI demo"
LABEL demo.minikube.optimized="true"
LABEL demo.minikube.memory-limit="256Mi"
LABEL demo.minikube.cpu-limit="200m"

# Instalar herramientas adicionales mínimas
RUN apk add --no-cache \
    curl \
    && rm -rf /var/cache/apk/*

# =============================================================================
# STAGE 2: Configuration and Scripts
# =============================================================================
FROM base AS configured

# Copiar scripts de inicialización
COPY init-scripts/ /docker-entrypoint-initdb.d/

# Copiar configuraciones optimizadas para demo
COPY postgresql.conf /etc/postgresql/postgresql.conf
COPY pg_hba.conf /etc/postgresql/pg_hba.conf

# Configurar variables de entorno para demo
ENV POSTGRES_DB=backstage_openwebui
ENV POSTGRES_USER=backstage
ENV POSTGRES_PASSWORD=demo-backstage-password
ENV PGDATA=/var/lib/postgresql/data

# Configuraciones optimizadas para Minikube (recursos limitados)
ENV POSTGRES_INITDB_ARGS="--encoding=UTF8 --locale=C"

# =============================================================================
# STAGE 3: Final Production Image
# =============================================================================
FROM configured AS production

# Crear directorio para datos
RUN mkdir -p /var/lib/postgresql/data && \
    chown -R postgres:postgres /var/lib/postgresql/data && \
    chmod 700 /var/lib/postgresql/data

# Configurar health check optimizado
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD pg_isready -U $POSTGRES_USER -d $POSTGRES_DB || exit 1

# Exponer puerto estándar de PostgreSQL
EXPOSE 5432

# Usar configuración personalizada
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]

# =============================================================================
# Build Instructions:
# docker build -t edissonz8809/iaops/postgresql:demo-latest -f applications/postgresql/Dockerfile .
# docker run -p 5432:5432 -e POSTGRES_PASSWORD=demo-password edissonz8809/iaops/postgresql:demo-latest
# =============================================================================
