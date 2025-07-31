# =============================================================================
# Dockerfile Multi-stage para Backstage - Optimizado para Demo Minikube
# =============================================================================
# Imagen final optimizada: ~200MB (vs ~800MB imagen estándar)
# Tiempo de build: ~5-8 minutos
# Recursos requeridos: 512Mi RAM, 500m CPU

# =============================================================================
# STAGE 1: Base Dependencies
# =============================================================================
FROM node:18-alpine AS base

# Instalar dependencias del sistema necesarias
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    git \
    curl \
    && rm -rf /var/cache/apk/*

# Configurar usuario no-root para seguridad
RUN addgroup -g 1001 -S nodejs && \
    adduser -S backstage -u 1001 -G nodejs

# Configurar directorio de trabajo
WORKDIR /app

# Configurar variables de entorno para optimización
ENV NODE_ENV=production
ENV NODE_OPTIONS="--max-old-space-size=1024"
ENV YARN_CACHE_FOLDER=/tmp/.yarn-cache

# =============================================================================
# STAGE 2: Dependencies Installation
# =============================================================================
FROM base AS deps

# Copiar archivos de configuración de dependencias
COPY package.json yarn.lock* ./
COPY packages/backend/package.json ./packages/backend/
COPY packages/app/package.json ./packages/app/

# Instalar dependencias con optimizaciones para demo
RUN yarn config set network-timeout 300000 && \
    yarn install --frozen-lockfile --production=false --network-timeout 300000 && \
    yarn cache clean && \
    rm -rf /tmp/.yarn-cache

# =============================================================================
# STAGE 3: Build Application
# =============================================================================
FROM deps AS builder

# Copiar código fuente
COPY . .

# Configurar variables de build para demo
ENV NODE_ENV=production
ENV BACKSTAGE_DEMO_MODE=true
ENV BACKSTAGE_MINIKUBE_OPTIMIZED=true

# Build de la aplicación con optimizaciones
RUN yarn build:backend --config ../../app-config.yaml && \
    yarn build:app --config ../../app-config.yaml

# Limpiar archivos innecesarios después del build
RUN rm -rf node_modules/.cache && \
    rm -rf packages/*/node_modules/.cache && \
    rm -rf packages/*/dist/static/*.map

# =============================================================================
# STAGE 4: Production Dependencies
# =============================================================================
FROM base AS prod-deps

# Copiar archivos de configuración
COPY package.json yarn.lock* ./
COPY packages/backend/package.json ./packages/backend/

# Instalar solo dependencias de producción
RUN yarn install --frozen-lockfile --production=true --network-timeout 300000 && \
    yarn cache clean && \
    rm -rf /tmp/.yarn-cache

# =============================================================================
# STAGE 5: Final Production Image
# =============================================================================
FROM node:18-alpine AS production

# Metadatos de la imagen
LABEL maintainer="Amazon Q <demo@example.com>"
LABEL version="1.20.0"
LABEL description="Backstage Developer Portal optimized for Minikube demo"
LABEL demo.minikube.optimized="true"
LABEL demo.minikube.memory-limit="512Mi"
LABEL demo.minikube.cpu-limit="500m"

# Instalar solo dependencias runtime mínimas
RUN apk add --no-cache \
    dumb-init \
    curl \
    && rm -rf /var/cache/apk/*

# Crear usuario no-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S backstage -u 1001 -G nodejs

# Configurar directorio de trabajo
WORKDIR /app

# Copiar dependencias de producción
COPY --from=prod-deps --chown=backstage:nodejs /app/node_modules ./node_modules
COPY --from=prod-deps --chown=backstage:nodejs /app/package.json ./

# Copiar aplicación construida
COPY --from=builder --chown=backstage:nodejs /app/packages/backend/dist ./packages/backend/dist
COPY --from=builder --chown=backstage:nodejs /app/packages/app/dist ./packages/app/dist

# Copiar configuraciones necesarias
COPY --chown=backstage:nodejs app-config.yaml ./
COPY --chown=backstage:nodejs app-config.production.yaml ./

# Configurar variables de entorno para producción
ENV NODE_ENV=production
ENV NODE_OPTIONS="--max-old-space-size=512"
ENV BACKSTAGE_DEMO_MODE=true
ENV PORT=7007

# Configurar health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:7007/healthcheck || exit 1

# Exponer puerto
EXPOSE 7007

# Cambiar a usuario no-root
USER backstage

# Comando de inicio con dumb-init para manejo correcto de señales
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "packages/backend/dist/index.js"]

# =============================================================================
# Build Instructions:
# docker build -t edissonz8809/iaops/backstage:demo-latest -f applications/backstage/Dockerfile .
# docker run -p 7007:7007 edissonz8809/iaops/backstage:demo-latest
# =============================================================================
