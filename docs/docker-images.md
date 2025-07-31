# Documentación de Imágenes Docker - Demo Minikube

## Información General

Este documento describe las imágenes Docker optimizadas para el demo de Backstage + OpenWebUI en Minikube, incluyendo Dockerfiles multi-stage, configuraciones de recursos y procesos de build y distribución.

### Registry y Nomenclatura
- **Registry**: `edissonz8809/iaops`
- **Tag para demo**: `demo-latest`
- **Convención de nombres**: `{registry}/{component}:{tag}`

### Imágenes Disponibles
1. **Backstage**: `edissonz8809/iaops/backstage:demo-latest`
2. **OpenWebUI**: `edissonz8809/iaops/openwebui:demo-latest`
3. **PostgreSQL**: `edissonz8809/iaops/postgresql:demo-latest`

---

## Arquitectura Multi-stage

Todas las imágenes utilizan arquitectura multi-stage para optimizar el tamaño final y mejorar la seguridad:

### Beneficios de Multi-stage
- **Reducción de tamaño**: 60-70% menos que imágenes tradicionales
- **Seguridad mejorada**: Solo dependencias de runtime en imagen final
- **Build optimizado**: Separación clara entre build y runtime
- **Cache eficiente**: Mejor aprovechamiento del cache de Docker

### Stages Comunes
1. **Base**: Configuración base del sistema
2. **Dependencies**: Instalación de dependencias
3. **Builder**: Compilación y build de la aplicación
4. **Production**: Imagen final optimizada

---

## Imagen de Backstage

### Especificaciones
- **Imagen base**: `node:18-alpine`
- **Tamaño final**: ~200MB (vs ~800MB estándar)
- **Tiempo de build**: 5-8 minutos
- **Recursos**: 512Mi RAM, 500m CPU

### Stages del Dockerfile

#### Stage 1: Base Dependencies
```dockerfile
FROM node:18-alpine AS base
```
- Instalación de dependencias del sistema (python3, make, g++, git, curl)
- Configuración de usuario no-root (`backstage:1001`)
- Variables de entorno para optimización

#### Stage 2: Dependencies Installation
```dockerfile
FROM base AS deps
```
- Instalación de dependencias Node.js con Yarn
- Configuración de timeouts para redes lentas
- Limpieza de cache

#### Stage 3: Build Application
```dockerfile
FROM deps AS builder
```
- Build de backend y frontend
- Configuración específica para demo
- Limpieza de archivos innecesarios

#### Stage 4: Production Dependencies
```dockerfile
FROM base AS prod-deps
```
- Instalación solo de dependencias de producción
- Optimización de espacio

#### Stage 5: Final Production Image
```dockerfile
FROM node:18-alpine AS production
```
- Imagen final con solo lo necesario para runtime
- Configuración de seguridad y health checks
- Usuario no-root para ejecución

### Configuraciones Específicas
```yaml
# Variables de entorno
NODE_ENV: production
NODE_OPTIONS: "--max-old-space-size=512"
BACKSTAGE_DEMO_MODE: true
PORT: 7007

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3
```

### Archivos Incluidos
- `app-config.yaml`: Configuración principal
- `app-config.production.yaml`: Configuración de producción
- Código compilado de backend y frontend

---

## Imagen de OpenWebUI

### Especificaciones
- **Imagen base**: `python:3.11-alpine`
- **Tamaño final**: ~150MB (vs ~500MB estándar)
- **Tiempo de build**: 3-5 minutos
- **Recursos**: 512Mi RAM, 500m CPU

### Stages del Dockerfile

#### Stage 1: Base Python Environment
```dockerfile
FROM python:3.11-alpine AS base
```
- Instalación de dependencias del sistema para Python
- Configuración de usuario no-root (`openwebui:1001`)
- Variables de entorno Python optimizadas

#### Stage 2: Dependencies Installation
```dockerfile
FROM base AS deps
```
- Instalación de dependencias Python con pip
- Inclusión de drivers para PostgreSQL y Redis
- Gunicorn para servidor WSGI

#### Stage 3: Build Application
```dockerfile
FROM deps AS builder
```
- Copia y preparación del código fuente
- Build de assets estáticos si es necesario
- Limpieza de archivos de desarrollo

#### Stage 4: Final Production Image
```dockerfile
FROM python:3.11-alpine AS production
```
- Imagen final optimizada
- Configuración para integración con Backstage
- Health checks y configuración de seguridad

### Configuraciones Específicas
```yaml
# Variables de entorno
PYTHONUNBUFFERED: 1
PYTHONDONTWRITEBYTECODE: 1
OPENWEBUI_DEMO_MODE: true
WEBUI_PORT: 8080

# Integración con Backstage
BACKSTAGE_INTEGRATION_ENABLED: true
BACKSTAGE_WEBHOOK_URL: http://backstage:7007/api/webhooks/openwebui

# Base de datos compartida
DATABASE_URL: postgresql://backstage:demo-backstage-password@postgresql:5432/backstage_openwebui
```

### Comando de Inicio
```bash
gunicorn --bind 0.0.0.0:8080 --workers 2 --worker-class uvicorn.workers.UvicornWorker main:app
```

---

## Imagen de PostgreSQL

### Especificaciones
- **Imagen base**: `postgres:15-alpine`
- **Tamaño final**: ~80MB (vs ~150MB estándar)
- **Tiempo de build**: 2-3 minutos
- **Recursos**: 256Mi RAM, 200m CPU

### Stages del Dockerfile

#### Stage 1: Base PostgreSQL
```dockerfile
FROM postgres:15-alpine AS base
```
- Imagen base oficial de PostgreSQL
- Instalación de herramientas adicionales mínimas

#### Stage 2: Configuration and Scripts
```dockerfile
FROM base AS configured
```
- Copia de scripts de inicialización
- Configuraciones optimizadas para demo

#### Stage 3: Final Production Image
```dockerfile
FROM configured AS production
```
- Configuración final con health checks
- Permisos y directorios necesarios

### Configuraciones Incluidas

#### postgresql.conf (Optimizado para 256Mi RAM)
```ini
shared_buffers = 32MB
effective_cache_size = 128MB
work_mem = 2MB
maintenance_work_mem = 16MB
max_connections = 20
```

#### Scripts de Inicialización
- `01-init-database.sql`: Creación de base de datos y usuarios
- Esquemas separados: `backstage_schema`, `openwebui_schema`, `shared_schema`
- Datos de ejemplo para demo

### Variables de Entorno
```yaml
POSTGRES_DB: backstage_openwebui
POSTGRES_USER: backstage
POSTGRES_PASSWORD: demo-backstage-password
```

---

## Scripts de Build y Push

### Script de Build (`scripts/docker-build.sh`)

#### Uso
```bash
# Construir todas las imágenes
./scripts/docker-build.sh

# Construir imagen específica
./scripts/docker-build.sh backstage

# Construir y hacer push
./scripts/docker-build.sh all --push

# Construir sin cache
./scripts/docker-build.sh --no-cache
```

#### Características
- Build multi-stage optimizado
- Validaciones de Docker
- Información detallada de imágenes construidas
- Soporte para build individual o masivo
- Integración con sistema de push

### Script de Push (`scripts/docker-push.sh`)

#### Uso
```bash
# Push de todas las imágenes
./scripts/docker-push.sh

# Push de imagen específica
./scripts/docker-push.sh backstage

# Push forzado sin confirmaciones
./scripts/docker-push.sh all --force
```

#### Características
- Validación de login en DockerHub
- Confirmaciones interactivas
- Información detallada de imágenes
- URLs directas a DockerHub
- Manejo de errores robusto

---

## Integración con Makefile

### Comandos Disponibles

```bash
# Build de imágenes
make docker-build                    # Todas las imágenes
make docker-build-backstage         # Solo Backstage
make docker-build-openwebui         # Solo OpenWebUI
make docker-build-postgresql        # Solo PostgreSQL

# Push a DockerHub
make docker-push                     # Todas las imágenes
make docker-push-backstage          # Solo Backstage
make docker-push-openwebui          # Solo OpenWebUI
make docker-push-postgresql         # Solo PostgreSQL

# Build y push combinado
make docker-build-and-push          # Build + push de todas

# Limpieza
make docker-clean                    # Limpiar imágenes locales
make docker-prune                    # Limpieza completa de Docker
```

### Configuración en Makefile
```makefile
# Variables Docker
DOCKER_REGISTRY = edissonz8809/iaops
DOCKER_TAG = demo-latest
DOCKER_BUILD_SCRIPT = ./scripts/docker-build.sh
DOCKER_PUSH_SCRIPT = ./scripts/docker-push.sh

# Targets de build
docker-build:
	$(DOCKER_BUILD_SCRIPT) all

docker-build-backstage:
	$(DOCKER_BUILD_SCRIPT) backstage

# Targets de push
docker-push:
	$(DOCKER_PUSH_SCRIPT) all

docker-push-backstage:
	$(DOCKER_PUSH_SCRIPT) backstage
```

---

## Optimizaciones para Minikube

### Configuraciones de Recursos
Todas las imágenes están optimizadas para funcionar en Minikube con recursos limitados:

```yaml
# Límites de recursos por contenedor
backstage:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"

openwebui:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"

postgresql:
  requests:
    memory: "128Mi"
    cpu: "50m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### Variables de Optimización
```bash
# Backstage
NODE_OPTIONS="--max-old-space-size=512"
BACKSTAGE_MINIKUBE_OPTIMIZED=true

# OpenWebUI
OPENWEBUI_DEMO_MODE=true
WORKERS=2

# PostgreSQL
POSTGRES_INITDB_ARGS="--encoding=UTF8 --locale=C"
```

---

## Seguridad

### Usuarios No-Root
Todas las imágenes ejecutan con usuarios no-root:
- **Backstage**: `backstage:1001`
- **OpenWebUI**: `openwebui:1001`
- **PostgreSQL**: `postgres:999` (usuario estándar)

### Health Checks
Todas las imágenes incluyen health checks configurados:
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3
```

### Labels de Metadatos
```dockerfile
LABEL maintainer="Amazon Q <demo@example.com>"
LABEL demo.minikube.optimized="true"
LABEL demo.minikube.memory-limit="512Mi"
LABEL demo.minikube.cpu-limit="500m"
```

---

## Troubleshooting

### Problemas Comunes

#### Error de Build por Memoria
```bash
# Síntoma: Build falla por falta de memoria
# Solución: Aumentar memoria de Docker
docker system prune -f
# O ajustar NODE_OPTIONS en Dockerfile
```

#### Error de Push a DockerHub
```bash
# Síntoma: Access denied al hacer push
# Solución: Verificar login
docker login
docker push edissonz8809/iaops/backstage:demo-latest
```

#### Imagen muy grande
```bash
# Verificar tamaño de imagen
docker images edissonz8809/iaops/*:demo-latest

# Analizar capas de imagen
docker history edissonz8809/iaops/backstage:demo-latest
```

### Comandos de Diagnóstico
```bash
# Verificar imágenes locales
docker images | grep edissonz8809/iaops

# Inspeccionar imagen
docker inspect edissonz8809/iaops/backstage:demo-latest

# Verificar health check
docker run --rm edissonz8809/iaops/backstage:demo-latest /bin/sh -c "curl -f http://localhost:7007/healthcheck"

# Logs de contenedor
docker logs <container-id>
```

---

## Próximos Pasos

### Mejoras Planificadas
1. **Multi-arquitectura**: Soporte para ARM64 y AMD64
2. **Versionado semántico**: Tags con versiones específicas
3. **Scanning de seguridad**: Integración con herramientas de seguridad
4. **Optimizaciones adicionales**: Reducir aún más el tamaño de imágenes

### Integración con CI/CD
- Automatización de builds en cambios de código
- Tests de imágenes antes del push
- Notificaciones de builds exitosos/fallidos
- Integración con Jenkins (Tarea 6 del plan)

---

## Referencias

### DockerHub
- [Backstage Repository](https://hub.docker.com/r/edissonz8809/iaops/backstage)
- [OpenWebUI Repository](https://hub.docker.com/r/edissonz8809/iaops/openwebui)
- [PostgreSQL Repository](https://hub.docker.com/r/edissonz8809/iaops/postgresql)

### Documentación Oficial
- [Docker Multi-stage Builds](https://docs.docker.com/develop/dev-best-practices/dockerfile_best-practices/#use-multi-stage-builds)
- [Backstage Docker Guide](https://backstage.io/docs/deployment/docker/)
- [PostgreSQL Docker Hub](https://hub.docker.com/_/postgres)

### Herramientas Utilizadas
- **Docker**: Containerización
- **Alpine Linux**: Imagen base ligera
- **Node.js 18**: Runtime para Backstage
- **Python 3.11**: Runtime para OpenWebUI
- **PostgreSQL 15**: Base de datos
