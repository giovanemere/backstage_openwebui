# Backstage + OpenWebUI Integration (Demo Minikube)

Una implementación optimizada para demo que integra **Backstage** (portal de desarrolladores) con **OpenWebUI** (interfaz de chat IA) en un entorno Minikube con recursos limitados.

## 🎯 Objetivo

Crear una plataforma unificada donde los desarrolladores puedan:
- Acceder al catálogo de servicios y documentación en Backstage
- Usar funcionalidades de chat IA directamente desde Backstage
- Generar documentación automáticamente desde las conversaciones
- Todo funcionando en un entorno local con recursos limitados

## 🏗️ Arquitectura

- **Frontend**: Backstage UI con plugin de chat integrado
- **Backend**: Backstage Backend con proxy hacia OpenWebUI
- **Base de datos**: PostgreSQL compartido para ambos servicios
- **Documentación**: MkDocs para generación automática
- **Infraestructura**: Minikube con configuración optimizada

## 📋 Requisitos del Sistema

### Mínimos
- **RAM**: 8GB total (4GB para Minikube + 4GB para SO)
- **CPU**: 4 cores físicos
- **Disco**: 20GB espacio libre
- **SO**: Linux, macOS, o Windows con WSL2

### Recomendados
- **RAM**: 12GB total (6GB para Minikube + 6GB para SO)
- **CPU**: 6 cores físicos
- **Disco**: 30GB espacio libre
- **SSD**: Para mejor performance

## 🚀 Quick Start

### 1. Verificar Requisitos
```bash
./scripts/setup/verify-requirements.sh
```

### 2. Instalar y Configurar Minikube
```bash
./scripts/setup/install-minikube.sh
./scripts/setup/setup-cluster.sh
```

### 3. Desplegar la Aplicación
```bash
make deploy-demo
```

### 4. Acceder a la Aplicación
```bash
# Port forwarding automático
make port-forward

# Acceder a:
# - Backstage: http://localhost:3000
# - OpenWebUI: http://localhost:8080 (directo, opcional)
```

### 5. Comandos Principales

```bash
# Ver todos los comandos disponibles
make help

# Build de todas las imágenes
make build-all

# Desplegar completo
make deploy-demo

# Ver logs de todos los servicios
make logs

# Limpiar entorno
make clean

# Ejecutar tests
make test
```

### 6. Cómo Usar

```bash
# 1. Configurar variables (opcional)
cp .env.example .env
# Editar .env con tus valores

# 2. Procesar charts con variables
make charts-process

# 3. Validar charts procesados
make charts-validate

# 4. Desplegar con charts procesados
make deploy-demo-processed

# 5. Restaurar originales si es necesario
make charts-restore
```

### 7. Integración con Makefile**

```bash
make docker-build                    # Build todas las imágenes
make docker-build-backstage         # Build solo Backstage
make docker-push                     # Push a DockerHub
make docker-build-and-push          # Build + push combinado
make docker-test-backstage          # Probar imagen localmente
make docker-info                     # Información de imágenes
```
### 8. Para usar la automatización:**

```bash
Para usar la automatización:

# Verificar recursos
./scripts/minikube/check-resources.sh

# Setup completo
./scripts/minikube/setup-minikube.sh

# Validar setup
./scripts/minikube/validate-setup.sh

# Si hay problemas
./scripts/minikube/troubleshoot.sh

# Limpiar recursos
./scripts/minikube/cleanup.sh
```

### 🚀 Comandos Disponibles

```bash
# Despliegue
make openwebui-deploy              # Demo environment
make openwebui-deploy-dev          # Development
make openwebui-deploy-prod         # Production
make openwebui-deploy-kubectl      # Con kubectl
make openwebui-deploy-dry-run      # Simulación

# Configuración
make openwebui-configure           # Post-deploy config
make openwebui-configure-verbose   # Con detalles

# Gestión
make openwebui-status              # Estado actual
make openwebui-logs                # Logs en tiempo real
make openwebui-shell               # Acceso al pod
make openwebui-port-forward        # Acceso local

# Troubleshooting
make openwebui-describe            # Describir recursos
make openwebui-health              # Health checks
make openwebui-metrics             # Métricas

# Limpieza
make openwebui-uninstall           # Desinstalar
make openwebui-clean               # Limpieza completa

# Combinados
make openwebui-full-deploy         # Deploy + configure
make openwebui-redeploy            # Redespliegue completo

```

### 🚀 Despliegue  Integración Técnica Backstage-OpenWebUI

```bash
cd integration/
./deploy-integration.sh deploy
```

### 📊 Arquitectura Implementada

```bash
Backstage ◄──► Integration API ◄──► OpenWebUI
(Plugin)       (FastAPI)           (Chat/AI)
```
### Uso Rápido backstage

```bash
# Despliegue con Helm (recomendado)
./scripts/backstage/deploy-backstage.sh deploy helm

# Configuración post-despliegue
./scripts/backstage/configure-backstage.sh configure
```

# Acceso: http://localhost/backstage

## 📁 Estructura del Proyecto

Ver [Estructura del Proyecto](./docs/estructura-proyecto.md) para detalles completos.

## 📖 Documentación

- [Plan de Implementación](./docs/plan-implementacion.md)
- [Seguimiento de Progreso](./docs/seguimiento-progreso.md)
- [Estructura del Proyecto](./docs/estructura-proyecto.md)
- [Arquitectura](./docs/arquitectura/README.md)

---

**Nota**: Este proyecto está optimizado para demos y desarrollo local.
