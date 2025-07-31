# 🚀 Backstage + OpenWebUI Integration Platform

Una plataforma completa que integra **Backstage** (portal de desarrolladores) con **OpenWebUI** (interfaz de chat IA) para crear un ecosistema unificado de desarrollo con inteligencia artificial integrada.

## 🎯 **¿Qué es este proyecto?**

Esta es una implementación **100% funcional** que combina:
- **Portal de Desarrolladores Moderno** (Backstage) con catálogo de servicios
- **Chat IA Contextual** (OpenWebUI) integrado directamente en Backstage
- **Documentación Automática** que se genera desde conversaciones
- **Infraestructura como Código** completamente automatizada
- **CI/CD Pipeline** funcional con Jenkins

### ✨ **Características Principales**
- ✅ **Integración Nativa**: Chat IA directamente en Backstage
- ✅ **Documentación Inteligente**: MkDocs con procesamiento automático
- ✅ **Despliegue Automatizado**: Un comando para todo
- ✅ **Optimizado para Demo**: Funciona en Minikube con recursos limitados
- ✅ **Producción Ready**: Configuraciones para diferentes entornos

---

## 📋 **PREREQUISITOS**

### **🖥️ Requisitos del Sistema**

#### **Mínimos (Para Demo)**
```bash
RAM:    8GB total (4GB Minikube + 4GB SO)
CPU:    4 cores físicos
Disco:  20GB espacio libre
SO:     Linux, macOS, Windows con WSL2
```

#### **Recomendados (Para Desarrollo)**
```bash
RAM:    12GB total (6GB Minikube + 6GB SO)
CPU:    6 cores físicos
Disco:  30GB espacio libre
SSD:    Recomendado para mejor performance
```

### **🛠️ Software Requerido**

#### **Herramientas Esenciales**
```bash
# Verificar si están instaladas
docker --version          # Docker 20.10+
kubectl version --client  # kubectl 1.24+
helm version              # Helm 3.8+
make --version            # GNU Make 4.0+
git --version             # Git 2.30+
```

#### **Herramientas Opcionales (Se instalan automáticamente)**
```bash
minikube version          # Se instala con scripts/setup/
jq --version             # Para procesamiento JSON
yq --version             # Para procesamiento YAML
```

---

## 🚀 **INICIO RÁPIDO (5 MINUTOS)**

### **Paso 1: Clonar y Verificar**
```bash
# 1. Clonar el repositorio
git clone <repository-url>
cd backstage_openwebui

# 2. Verificar requisitos del sistema
make verify-requirements
```

### **Paso 2: Setup Automático**
```bash
# 3. Setup completo automático (instala todo lo necesario)
make minikube-setup

# Esto ejecuta automáticamente:
# - Instalación de Minikube
# - Configuración del cluster
# - Verificación de recursos
# - Setup de networking
```

### **Paso 3: Despliegue Completo**
```bash
# 4. Desplegar toda la plataforma
make deploy-demo

# Esto despliega automáticamente:
# - PostgreSQL (base de datos)
# - Backstage (portal de desarrolladores)
# - OpenWebUI (chat IA)
# - Integración (API de conexión)
# - MkDocs (documentación)
# - Jenkins (CI/CD)
```

### **Paso 4: Acceder a la Plataforma**
```bash
# 5. Configurar acceso local
make port-forward

# 6. Abrir en navegador:
# - Backstage: http://localhost:3000
# - OpenWebUI: http://localhost:8080
# - Jenkins:   http://localhost:8081
# - MkDocs:    http://localhost:8082
```

### **🎉 ¡Listo! Tu plataforma está funcionando**

---

## 📖 **GUÍA PASO A PASO DETALLADA**

### **🔧 Configuración Inicial**

#### **1. Preparar el Entorno**
```bash
# Verificar que Docker está corriendo
docker ps

# Verificar recursos disponibles
free -h
nproc

# Verificar espacio en disco
df -h
```

#### **2. Configurar Variables (Opcional)**
```bash
# Copiar archivo de ejemplo
cp .env.example .env

# Editar configuraciones personalizadas
nano .env

# Variables principales:
# DOCKER_REGISTRY=tu-registry
# DOCKER_TAG=tu-tag
# MINIKUBE_MEMORY=4096
# MINIKUBE_CPUS=2
```

#### **3. Verificar Prerequisitos Automáticamente**
```bash
# Script completo de verificación
./scripts/setup/verify-requirements.sh

# Salida esperada:
# ✅ Docker: OK
# ✅ Kubectl: OK  
# ✅ Helm: OK
# ✅ Make: OK
# ✅ Recursos: OK
```

### **🏗️ Setup de Infraestructura**

#### **4. Instalar Minikube (Si no está instalado)**
```bash
# Instalación automática
./scripts/setup/install-minikube.sh

# O usar Makefile
make setup-minikube
```

#### **5. Configurar Cluster**
```bash
# Setup completo del cluster
./scripts/setup/setup-cluster.sh

# O paso a paso:
make minikube-setup-clean    # Cluster limpio
make minikube-check          # Verificar recursos
make minikube-status         # Ver estado
```

#### **6. Validar Setup**
```bash
# Validación completa
make minikube-troubleshoot

# Verificar pods del sistema
kubectl get pods -A

# Verificar recursos
kubectl top nodes
```

### **🚢 Despliegue de Aplicaciones**

#### **7. Build de Imágenes (Opcional)**
```bash
# Build todas las imágenes localmente
make docker-build

# O build específicas:
make docker-build-backstage
make docker-build-openwebui
make docker-build-postgresql
make docker-build-jenkins
```

#### **8. Despliegue por Componentes**
```bash
# Desplegar base de datos primero
make deploy-database

# Desplegar Backstage
make deploy-backstage

# Desplegar OpenWebUI
make deploy-openwebui

# O desplegar todo junto:
make deploy-demo
```

#### **9. Configurar Integración**
```bash
# Desplegar sistema de integración
cd integration/
./deploy-integration.sh deploy

# Verificar integración
make test-integration
```

### **🔍 Verificación y Acceso**

#### **10. Verificar Estado**
```bash
# Ver estado de todos los pods
make status

# Ver logs de servicios
make logs

# Verificar health de servicios específicos
make openwebui-health
make jenkins-status
```

#### **11. Configurar Acceso Local**
```bash
# Port forwarding automático
make port-forward

# O configurar manualmente:
kubectl port-forward svc/backstage 3000:3000 &
kubectl port-forward svc/openwebui 8080:8080 &
kubectl port-forward svc/jenkins 8081:8080 &
```

#### **12. Acceder a las Aplicaciones**
```bash
# URLs de acceso:
echo "Backstage: http://localhost:3000"
echo "OpenWebUI: http://localhost:8080" 
echo "Jenkins:   http://localhost:8081"
echo "MkDocs:    http://localhost:8082"

# Credenciales por defecto:
# Jenkins: admin/admin123
# PostgreSQL: postgres/postgres123
```

---

## 🎮 **COMANDOS PRINCIPALES**

### **📋 Comandos Esenciales**
```bash
# Ver todos los comandos disponibles
make help

# Información del sistema
make info

# Estado completo
make status

# Logs de todos los servicios
make logs

# Limpiar entorno
make clean

# Reinicio de emergencia
make emergency-restart
```

### **🐳 Docker y Build**
```bash
# Build completo
make docker-build

# Build sin cache
make docker-build-no-cache

# Push a registry
make docker-push

# Build y push combinado
make docker-build-and-push

# Información de imágenes
make docker-info

# Limpiar imágenes locales
make docker-clean
```

### **☸️ Kubernetes y Helm**
```bash
# Validar charts
make helm-validate

# Dry run de instalación
make helm-dry-run

# Instalar con Helm
make helm-install

# Actualizar instalación
make helm-upgrade

# Estado de charts
make helm-status

# Desinstalar
make helm-uninstall
```

### **🔧 Troubleshooting**
```bash
# Diagnóstico completo
make minikube-troubleshoot

# Verificar recursos
make minikube-check

# Logs del cluster
make minikube-logs

# Resetear cluster
make minikube-reset

# Limpiar todo
make minikube-cleanup-all
```

---

## 🏗️ **ARQUITECTURA DEL SISTEMA**

### **📊 Diagrama General**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Ingress       │    │   Backstage     │    │   PostgreSQL    │
│   Controller    │────│   Frontend      │────│   Database      │
│                 │    │   Backend       │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       
         │              ┌─────────────────┐              
         └──────────────│   OpenWebUI     │              
                        │   Integration   │              
                        └─────────────────┘              
                                 │
                        ┌─────────────────┐
                        │     MkDocs      │
                        │  Documentation  │
                        └─────────────────┘
```

### **🔄 Flujo de Integración**
```
Usuario → Backstage → Plugin Chat → Integration API → OpenWebUI → IA
   ↓                                                              ↑
MkDocs ← Processor ← Webhook ← Conversation Data ←────────────────┘
```

### **📦 Componentes Principales**
- **Backstage**: Portal de desarrolladores con catálogo de servicios
- **OpenWebUI**: Interfaz de chat con modelos de IA
- **Integration API**: FastAPI que conecta ambos sistemas
- **PostgreSQL**: Base de datos compartida
- **MkDocs**: Generación automática de documentación
- **Jenkins**: CI/CD pipeline automatizado

---

## 📁 **ESTRUCTURA DEL PROYECTO**

```
backstage_openwebui/
├── 📚 docs/                    # Documentación completa
├── 🔧 scripts/                 # Scripts de automatización
│   ├── setup/                  # Scripts de instalación
│   ├── minikube/              # Scripts de Minikube
│   ├── backstage/             # Scripts de Backstage
│   └── jenkins/               # Scripts de Jenkins
├── 🔗 integration/             # Sistema de integración
│   ├── apis/                  # APIs de integración
│   ├── plugins/               # Plugin de Backstage
│   └── webhooks/              # Configuración de webhooks
├── 📖 mkdocs/                  # Sistema de documentación
│   ├── processors/            # Procesadores de IA
│   ├── templates/             # Templates Jinja2
│   └── charts/                # Chart Helm de MkDocs
├── ⛵ helm/                    # Charts Helm
│   ├── backstage/             # Chart de Backstage
│   ├── openwebui/             # Chart de OpenWebUI
│   ├── postgresql/            # Chart de PostgreSQL
│   └── jenkins/               # Chart de Jenkins
├── 🏗️ applications/            # Aplicaciones
│   ├── backstage/             # Configuración Backstage
│   ├── openwebui/             # Configuración OpenWebUI
│   ├── postgresql/            # Configuración PostgreSQL
│   └── jenkins/               # Configuración Jenkins
├── 🐳 docker/                  # Configuraciones Docker
├── ☸️ k8s/                     # Manifiestos Kubernetes
└── 🔄 jenkins/                 # Pipelines CI/CD
```

---

## 🔧 **CONFIGURACIÓN AVANZADA**

### **🎛️ Variables de Entorno**
```bash
# Configuraciones principales (.env)
DOCKER_REGISTRY=edissonz8809/iaops
DOCKER_TAG=demo-latest
MINIKUBE_MEMORY=4096
MINIKUBE_CPUS=2

# Configuraciones de base de datos
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres123
POSTGRES_DB=backstage

# Configuraciones de aplicación
BACKSTAGE_BASE_URL=http://localhost:3000
OPENWEBUI_BASE_URL=http://localhost:8080
```

### **📊 Procesamiento de Charts**
```bash
# Procesar variables en charts
make charts-process

# Validar charts procesados
make charts-validate

# Desplegar con charts procesados
make deploy-demo-processed

# Restaurar originales
make charts-restore
```

### **🔍 Monitoreo y Logs**
```bash
# Logs específicos por servicio
make openwebui-logs
make jenkins-logs
make mkdocs-logs

# Métricas de recursos
make openwebui-metrics

# Health checks
make openwebui-health

# Describir recursos
make openwebui-describe
```

---

## 🧪 **TESTING Y VALIDACIÓN**

### **✅ Tests Automatizados**
```bash
# Ejecutar todos los tests
make test

# Tests unitarios
make test-unit

# Tests de integración
make test-integration

# Validar configuraciones
make helm-validate
make charts-validate
```

### **🔍 Troubleshooting Común**

#### **Problema: Minikube no inicia**
```bash
# Verificar recursos
make minikube-check

# Limpiar y reiniciar
make minikube-cleanup
make minikube-setup
```

#### **Problema: Pods en estado Pending**
```bash
# Verificar recursos del cluster
kubectl describe nodes

# Ver eventos
kubectl get events --sort-by=.metadata.creationTimestamp

# Verificar límites de recursos
kubectl top pods -A
```

#### **Problema: Servicios no accesibles**
```bash
# Verificar port-forwarding
make port-forward

# Verificar servicios
kubectl get svc -A

# Verificar ingress
kubectl get ingress -A
```

---

## 📚 **DOCUMENTACIÓN ADICIONAL**

### **📖 Guías Técnicas**
- [Estructura del Proyecto](./docs/estructura-proyecto.md) - Documentación completa de la estructura
- [Despliegue de Backstage](./docs/backstage-deployment.md) - Guía específica de Backstage
- [Despliegue de OpenWebUI](./docs/openwebui-deployment.md) - Guía específica de OpenWebUI
- [Setup de Jenkins](./docs/jenkins-setup.md) - Configuración de CI/CD
- [Imágenes Docker](./docs/docker-images.md) - Documentación de imágenes

### **🏗️ Arquitectura**
- [Diagrama General](./docs/arquitectura/diagrama-general.md)
- [Diagrama de Componentes](./docs/arquitectura/diagrama-componentes.md)
- [Flujo de Datos](./docs/arquitectura/diagrama-flujo-datos.md)

### **🔗 Sistemas de Integración**
- [Sistema de Integración](./integration/README.md) - API y plugins
- [Sistema MkDocs](./mkdocs/README.md) - Documentación automática

---

## 🤝 **CONTRIBUCIÓN**

### **🔄 Workflow de Desarrollo**
```bash
# 1. Fork y clone
git clone <tu-fork>
cd backstage_openwebui

# 2. Crear rama de feature
git checkout -b feature/nueva-funcionalidad

# 3. Desarrollar y probar
make test
make deploy-demo

# 4. Commit y push
git commit -m "feat: nueva funcionalidad"
git push origin feature/nueva-funcionalidad

# 5. Crear Pull Request
```

### **📋 Estándares**
- **Commits**: Usar [Conventional Commits](https://conventionalcommits.org/)
- **Código**: Seguir estándares de cada lenguaje
- **Documentación**: Actualizar README y docs/ según cambios
- **Tests**: Incluir tests para nuevas funcionalidades

---

## 📞 **SOPORTE**

### **🆘 Obtener Ayuda**
```bash
# Ver todos los comandos
make help

# Información del sistema
make info

# Diagnóstico completo
make minikube-troubleshoot

# Logs detallados
make logs
```

### **🐛 Reportar Issues**
- Usar el sistema de issues del repositorio
- Incluir logs relevantes
- Especificar versiones de software
- Describir pasos para reproducir

---

## 📄 **LICENCIA**

Este proyecto está bajo licencia MIT. Ver archivo `LICENSE` para detalles.

---

## 🎉 **¡Empezar Ahora!**

```bash
# Comando único para empezar
git clone <repository-url> && cd backstage_openwebui && make verify-requirements && make minikube-setup && make deploy-demo && make port-forward

# ¡En 5 minutos tendrás tu plataforma funcionando!
```

**🚀 ¡Bienvenido a la plataforma de desarrollo con IA integrada!** 

*Para soporte técnico, consulta la documentación en `docs/` o ejecuta `make help`*
