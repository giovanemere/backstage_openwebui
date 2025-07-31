# Charts Helm - Backstage + OpenWebUI Demo

Este directorio contiene los Charts Helm optimizados para desplegar Backstage + OpenWebUI en Minikube como demo.

## 📁 Estructura de Charts

```
helm/
├── postgresql/                 # Base de datos compartida
├── backstage/                  # Developer Portal
├── openwebui/                  # AI Chat Interface
└── backstage-openwebui-demo/   # Chart umbrella (principal)
```

## 🎯 Características Principales

### ✅ Optimizado para Demo
- **Recursos limitados**: Configurado para Minikube con 4GB RAM
- **Arquitectura simplificada**: Sin componentes innecesarios
- **Setup rápido**: Instalación en menos de 5 minutos
- **Base de datos compartida**: PostgreSQL único para ambos servicios

### ✅ Integración Completa
- **Proxy configurado**: Backstage → OpenWebUI
- **Autenticación básica**: Usuarios demo preconfigurados
- **Chat integrado**: Plugin de chat en Backstage
- **Documentación automática**: Export de chats a TechDocs

### ✅ Configuración de Recursos

| Componente | Memory Limit | CPU Limit | Memory Request | CPU Request |
|------------|--------------|-----------|----------------|-------------|
| PostgreSQL | 256Mi        | 200m      | 128Mi          | 100m        |
| Backstage  | 512Mi        | 500m      | 256Mi          | 200m        |
| OpenWebUI  | 512Mi        | 500m      | 256Mi          | 200m        |
| **Total**  | **~1.3Gi**   | **1.2 cores** | **640Mi**  | **500m**    |

## ⚙️ Configuración de Variables

### Variables de Entorno (.env.example)

Los charts utilizan variables configurables definidas en `.env.example`:

#### Variables de Versiones
```bash
# Versiones de charts
BACKSTAGE_CHART_VERSION=0.1.0
OPENWEBUI_CHART_VERSION=0.1.0
POSTGRESQL_CHART_VERSION=0.1.0
DEMO_CHART_VERSION=0.1.0

# Versiones de aplicaciones
BACKSTAGE_APP_VERSION=1.20.0
OPENWEBUI_APP_VERSION=0.1.124
POSTGRESQL_APP_VERSION=15.0
DEMO_APP_VERSION=1.0.0
```

#### Variables de Configuración
```bash
# Información de mantenedores
CHART_MAINTAINER_NAME=Amazon Q
CHART_MAINTAINER_EMAIL=demo@example.com

# URLs del proyecto
CHART_HOME_URL=https://github.com/edissonz8809/iaops
CHART_SOURCE_URL=https://github.com/edissonz8809/iaops
```

#### Variables de Recursos
```bash
# Límites de memoria y CPU
BACKSTAGE_MEMORY_LIMIT=512Mi
BACKSTAGE_CPU_LIMIT=500m
OPENWEBUI_MEMORY_LIMIT=512Mi
OPENWEBUI_CPU_LIMIT=500m
POSTGRES_MEMORY_LIMIT=256Mi
POSTGRES_CPU_LIMIT=200m

# Configuración del demo completo
DEMO_MINIKUBE_TOTAL_MEMORY=1.4Gi
DEMO_MINIKUBE_TOTAL_CPU=1.3
```

#### Variables de Características
```bash
# Features específicas de cada chart
BACKSTAGE_CHART_FEATURES=chat-integration,proxy-enabled,basic-auth
OPENWEBUI_CHART_FEATURES=backstage-integration,shared-database
POSTGRESQL_CHART_FEATURES=shared-database,optimized-config
DEMO_CHART_FEATURES=chat-integration,shared-database,proxy-enabled
```

#### Variables de Dependencias
```bash
# Control de dependencias
POSTGRESQL_DEPENDENCY_ENABLED=postgresql.enabled
BACKSTAGE_DEPENDENCY_ENABLED=backstage.enabled
OPENWEBUI_DEPENDENCY_ENABLED=openwebui.enabled
```

### Uso de Variables

Las variables se utilizan en los archivos `Chart.yaml` con sintaxis de template:

```yaml
version: "${BACKSTAGE_CHART_VERSION:-0.1.0}"
appVersion: "${BACKSTAGE_APP_VERSION:-1.20.0}"
maintainers:
  - name: "${CHART_MAINTAINER_NAME:-Amazon Q}"
    email: "${CHART_MAINTAINER_EMAIL:-demo@example.com}"
```

**Nota**: Helm no resuelve variables de entorno directamente en Chart.yaml. Las variables están documentadas para referencia y futuro uso con herramientas de pre-procesamiento.

## 🚀 Instalación Rápida

### Prerrequisitos
```bash
# Verificar Minikube
minikube status

# Habilitar ingress
minikube addons enable ingress

# Verificar Helm
helm version

# Configurar variables (opcional)
cp .env.example .env
# Editar .env con tus valores personalizados
```

### Instalación con Make
```bash
# Validar charts
make helm-validate

# Instalar (recomendado)
make helm-install

# Ver estado
make helm-status
```

### Instalación Manual
```bash
# Validar charts
./scripts/helm-validate.sh

# Instalar
helm install demo helm/backstage-openwebui-demo \
  --namespace backstage-demo \
  --create-namespace \
  --wait

# Configurar acceso
echo "$(minikube ip) backstage.local openwebui.local" | sudo tee -a /etc/hosts
```

## 🌐 Acceso a la Aplicación

### URLs
- **Backstage**: http://backstage.local
- **OpenWebUI**: http://openwebui.local

### Credenciales Demo
- **Usuario**: `demo`
- **Contraseña**: `demo123`

### Port-Forward (alternativo)
```bash
# Backstage
kubectl port-forward -n backstage-demo svc/backstage 3000:3000

# OpenWebUI
kubectl port-forward -n backstage-demo svc/openwebui 8080:8080
```

## 📋 Charts Individuales

### 1. PostgreSQL Chart
**Propósito**: Base de datos compartida optimizada para demo

**Características**:
- PostgreSQL 15 Alpine (imagen ligera)
- Configuración de memoria optimizada
- Scripts de inicialización para múltiples bases de datos
- Persistencia habilitada (2Gi)

**Configuración clave**:
```yaml
resources:
  limits:
    memory: 256Mi
    cpu: 200m
  requests:
    memory: 128Mi
    cpu: 100m

auth:
  postgresPassword: "demo-postgres-password"
  username: "backstage"
  password: "demo-backstage-password"
  database: "backstage_openwebui"
```

### 2. Backstage Chart
**Propósito**: Developer Portal con integración de chat

**Características**:
- Backstage 1.20.0 con plugins personalizados
- Proxy configurado hacia OpenWebUI
- Autenticación básica y guest
- Catálogo de servicios preconfigurado
- TechDocs habilitado

**Configuración clave**:
```yaml
proxy:
  enabled: true
  endpoints:
    "/api/openwebui":
      target: "http://openwebui:8080"
      changeOrigin: true

plugins:
  chat:
    enabled: true
    openwebuiUrl: "http://openwebui:8080"
  techdocs:
    enabled: true
```

### 3. OpenWebUI Chart
**Propósito**: Interfaz de chat AI integrada

**Características**:
- OpenWebUI 0.1.124 optimizada
- Integración con Backstage via webhooks
- Soporte para múltiples proveedores AI
- Configuración de demo con usuarios de prueba

**Configuración clave**:
```yaml
ai:
  models:
    default: "gpt-3.5-turbo"
  providers:
    openai:
      enabled: true

backstage:
  integration:
    enabled: true
    webhookUrl: "http://backstage:7007/api/webhooks/openwebui"
```

### 4. Umbrella Chart
**Propósito**: Orquestación completa del sistema

**Características**:
- Gestión unificada de dependencias
- Configuración global compartida
- Valores optimizados para demo
- NOTES.txt con instrucciones de acceso

## 🛠️ Comandos Útiles

### Gestión de Charts
```bash
# Validar todos los charts
make helm-validate

# Instalar/actualizar
make helm-install
make helm-upgrade

# Ver estado
make helm-status

# Simular instalación
make helm-dry-run

# Desinstalar
make helm-uninstall
```

### Debugging
```bash
# Ver pods
kubectl get pods -n backstage-demo

# Logs de Backstage
kubectl logs -f -n backstage-demo deployment/backstage

# Logs de OpenWebUI
kubectl logs -f -n backstage-demo deployment/openwebui

# Logs de PostgreSQL
kubectl logs -f -n backstage-demo deployment/postgresql

# Describir pod con problemas
kubectl describe pod -n backstage-demo <pod-name>
```

### Acceso a Base de Datos
```bash
# Conectar a PostgreSQL
kubectl exec -it -n backstage-demo deployment/postgresql -- \
  psql -U backstage -d backstage_openwebui

# Ver tablas
kubectl exec -it -n backstage-demo deployment/postgresql -- \
  psql -U backstage -d backstage_openwebui -c "\dt"
```

### Personalización Avanzada con Variables

#### Script de Pre-procesamiento (Recomendado)
Para usar las variables de entorno en Chart.yaml, crear un script de pre-procesamiento:

```bash
#!/bin/bash
# scripts/process-charts.sh

# Cargar variables
source .env

# Procesar cada Chart.yaml
for chart_dir in helm/*/; do
    if [ -f "${chart_dir}Chart.yaml.template" ]; then
        envsubst < "${chart_dir}Chart.yaml.template" > "${chart_dir}Chart.yaml"
        echo "Procesado: ${chart_dir}Chart.yaml"
    fi
done
```

#### Uso con Helmfile (Alternativo)
```yaml
# helmfile.yaml
environments:
  demo:
    values:
      - .env

releases:
  - name: backstage-demo
    chart: ./helm/backstage-openwebui-demo
    values:
      - backstage:
          image:
            tag: {{ env "BACKSTAGE_APP_VERSION" | default "1.20.0" }}
      - openwebui:
          image:
            tag: {{ env "OPENWEBUI_APP_VERSION" | default "0.1.124" }}
```

#### Variables por Chart

##### PostgreSQL Chart
```bash
POSTGRESQL_CHART_VERSION=0.1.0
POSTGRESQL_APP_VERSION=15.0
POSTGRES_MEMORY_LIMIT=256Mi
POSTGRES_CPU_LIMIT=200m
POSTGRESQL_CHART_FEATURES=shared-database,optimized-config
```

##### Backstage Chart
```bash
BACKSTAGE_CHART_VERSION=0.1.0
BACKSTAGE_APP_VERSION=1.20.0
BACKSTAGE_MEMORY_LIMIT=512Mi
BACKSTAGE_CPU_LIMIT=500m
BACKSTAGE_CHART_FEATURES=chat-integration,proxy-enabled,basic-auth
```

##### OpenWebUI Chart
```bash
OPENWEBUI_CHART_VERSION=0.1.0
OPENWEBUI_APP_VERSION=0.1.124
OPENWEBUI_MEMORY_LIMIT=512Mi
OPENWEBUI_CPU_LIMIT=500m
OPENWEBUI_CHART_FEATURES=backstage-integration,shared-database
```

##### Demo Chart (Umbrella)
```bash
DEMO_CHART_VERSION=0.1.0
DEMO_APP_VERSION=1.0.0
DEMO_MINIKUBE_TOTAL_MEMORY=1.4Gi
DEMO_MINIKUBE_TOTAL_CPU=1.3
DEMO_CHART_COMPONENTS=postgresql,backstage,openwebui
DEMO_CHART_FEATURES=chat-integration,shared-database,proxy-enabled
```

## 🔧 Personalización

### Modificar Recursos
Editar `helm/backstage-openwebui-demo/values.yaml`:

```yaml
backstage:
  resources:
    limits:
      memory: 1Gi  # Aumentar memoria
      cpu: 1000m   # Aumentar CPU

openwebui:
  resources:
    limits:
      memory: 1Gi
      cpu: 1000m
```

### Configurar API Keys
Crear secret con API keys reales:

```bash
kubectl create secret generic openwebui-secrets \
  --namespace backstage-demo \
  --from-literal=openai-api-key="sk-..." \
  --from-literal=anthropic-api-key="sk-ant-..."
```

### Habilitar TLS
Modificar ingress en values.yaml:

```yaml
backstage:
  ingress:
    tls:
      - secretName: backstage-tls
        hosts:
          - backstage.local

openwebui:
  ingress:
    tls:
      - secretName: openwebui-tls
        hosts:
          - openwebui.local
```

## 📊 Monitoreo

### Health Checks
```bash
# Verificar health endpoints
curl http://backstage.local/healthcheck
curl http://openwebui.local/health
```

### Métricas de Recursos
```bash
# Ver uso de recursos
kubectl top pods -n backstage-demo
kubectl top nodes
```

### Eventos
```bash
# Ver eventos del namespace
kubectl get events -n backstage-demo --sort-by='.lastTimestamp'
```

## 🚨 Troubleshooting

### Problemas Comunes

#### 1. Pods en estado Pending
```bash
# Verificar recursos del nodo
kubectl describe nodes

# Verificar eventos
kubectl get events -n backstage-demo
```

**Solución**: Aumentar recursos de Minikube
```bash
minikube stop
minikube start --memory=6144 --cpus=4
```

#### 2. Ingress no funciona
```bash
# Verificar ingress controller
kubectl get pods -n ingress-nginx

# Habilitar addon
minikube addons enable ingress
```

#### 3. Base de datos no conecta
```bash
# Verificar PostgreSQL
kubectl logs -n backstage-demo deployment/postgresql

# Verificar secrets
kubectl get secrets -n backstage-demo
```

#### 4. Imágenes no se descargan
```bash
# Verificar pull policy
kubectl describe pod -n backstage-demo <pod-name>

# Usar imágenes locales en Minikube
eval $(minikube docker-env)
docker build -t edissonz8809/iaops/backstage:demo-latest .
```

### Logs Detallados
```bash
# Habilitar debug en Backstage
kubectl set env -n backstage-demo deployment/backstage LOG_LEVEL=debug

# Ver logs en tiempo real
kubectl logs -f -n backstage-demo deployment/backstage --tail=100
```

## 📚 Referencias

- [Helm Documentation](https://helm.sh/docs/)
- [Backstage Documentation](https://backstage.io/docs/)
- [OpenWebUI Documentation](https://docs.openwebui.com/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)

## 🤝 Contribución

Para contribuir a los Charts:

1. Modificar charts en `helm/`
2. Validar cambios: `make helm-validate`
3. Probar en demo: `make helm-dry-run`
4. Documentar cambios en este README
5. Actualizar versiones en Chart.yaml

## 📝 Notas de Versión

### v0.1.0
- ✅ Charts iniciales para PostgreSQL, Backstage, OpenWebUI
- ✅ Chart umbrella para despliegue unificado
- ✅ Optimización para recursos limitados de Minikube
- ✅ Integración completa entre componentes
- ✅ Scripts de validación y despliegue
- ✅ Documentación completa
