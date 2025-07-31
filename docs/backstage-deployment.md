# Guía de Despliegue de Backstage

## Descripción General

Esta guía describe cómo desplegar Backstage en Minikube como parte del demo de integración con OpenWebUI. El despliegue está optimizado para entornos de desarrollo y demostración.

## Arquitectura

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
```

## Componentes

### 1. Backstage Core
- **Frontend**: Interfaz web del portal de desarrollador
- **Backend**: API y servicios de backend
- **Plugins**: Kubernetes, TechDocs, Catalog, Scaffolder

### 2. Base de Datos
- **PostgreSQL**: Base de datos principal
- **Configuración**: Optimizada para demo (1GB storage)

### 3. Integración
- **GitHub**: Integración con repositorios
- **OpenWebUI**: Proxy y autenticación
- **Kubernetes**: Plugin para visualizar recursos

## Prerrequisitos

### Software Requerido
- Minikube >= 1.25.0
- kubectl >= 1.24.0
- Helm >= 3.8.0
- Docker >= 20.10.0

### Recursos Mínimos
- **CPU**: 2 cores
- **Memoria**: 4GB RAM
- **Almacenamiento**: 10GB disponible

### Verificación
```bash
# Verificar Minikube
minikube version

# Verificar kubectl
kubectl version --client

# Verificar Helm
helm version

# Verificar Docker
docker --version
```

## Métodos de Despliegue

### Opción 1: Despliegue con Helm (Recomendado)

#### 1. Preparar el entorno
```bash
# Iniciar Minikube con perfil específico
minikube start --profile=backstage-demo --memory=4096 --cpus=2

# Habilitar addons necesarios
minikube addons enable ingress --profile=backstage-demo
minikube addons enable metrics-server --profile=backstage-demo
```

#### 2. Desplegar con script automatizado
```bash
# Ejecutar script de despliegue
./scripts/backstage/deploy-backstage.sh deploy helm

# Verificar despliegue
./scripts/backstage/deploy-backstage.sh verify
```

#### 3. Configuración post-despliegue
```bash
# Configurar integraciones
./scripts/backstage/configure-backstage.sh configure

# Verificar configuración
./scripts/backstage/configure-backstage.sh verify
```

### Opción 2: Despliegue con kubectl

#### 1. Aplicar manifiestos
```bash
# Desplegar con kubectl
./scripts/backstage/deploy-backstage.sh deploy kubectl
```

#### 2. Verificar recursos
```bash
# Ver todos los recursos
kubectl get all -n backstage-demo

# Ver logs
kubectl logs -f deployment/backstage -n backstage-demo
```

## Configuración Detallada

### 1. Variables de Entorno

#### Backstage Core
```yaml
NODE_ENV: production
APP_CONFIG_app_baseUrl: http://backstage:7007
APP_CONFIG_backend_baseUrl: http://backstage:7007
```

#### Base de Datos
```yaml
POSTGRES_HOST: postgresql
POSTGRES_PORT: 5432
POSTGRES_USER: backstage
POSTGRES_PASSWORD: backstage123
POSTGRES_DB: backstage
```

#### Integraciones
```yaml
GITHUB_TOKEN: <tu-github-token>
OPENWEBUI_TOKEN: <tu-openwebui-token>
```

### 2. Configuración de Helm

#### values.yaml principales
```yaml
# Recursos optimizados para demo
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 256Mi

# PostgreSQL integrado
postgresql:
  enabled: true
  auth:
    username: backstage
    password: backstage123
    database: backstage

# Ingress habilitado
ingress:
  enabled: true
  className: nginx
  hosts:
    - paths:
        - path: /backstage(/|$)(.*)
          pathType: Prefix
```

### 3. Plugins Habilitados

#### Kubernetes Plugin
```yaml
kubernetes:
  enabled: true
  serviceLocatorMethod:
    type: multiTenant
  clusterLocatorMethods:
    - type: config
      clusters:
        - url: https://kubernetes.default.svc.cluster.local
          name: minikube-demo
          authProvider: serviceAccount
```

#### TechDocs Plugin
```yaml
techdocs:
  builder: local
  generator:
    runIn: local
  publisher:
    type: local
```

## Acceso y URLs

### URLs Principales
- **Backstage UI**: http://localhost/backstage
- **API**: http://localhost/backstage-api
- **Health Check**: http://localhost/backstage-api/catalog/health

### Port Forwarding (Alternativo)
```bash
# Port forward directo
kubectl port-forward svc/backstage 7007:7007 -n backstage-demo

# Acceder en: http://localhost:7007
```

### Minikube Tunnel
```bash
# Habilitar tunnel para acceso externo
minikube tunnel --profile=backstage-demo
```

## Monitoreo y Troubleshooting

### Comandos de Diagnóstico

#### Ver estado de pods
```bash
kubectl get pods -n backstage-demo -w
```

#### Ver logs en tiempo real
```bash
kubectl logs -f deployment/backstage -n backstage-demo
```

#### Describir recursos
```bash
kubectl describe deployment backstage -n backstage-demo
kubectl describe service backstage -n backstage-demo
kubectl describe ingress backstage-ingress -n backstage-demo
```

### Problemas Comunes

#### 1. Pod en estado Pending
**Causa**: Recursos insuficientes
**Solución**:
```bash
# Verificar recursos del nodo
kubectl describe nodes

# Ajustar recursos en values.yaml
resources:
  requests:
    cpu: 50m
    memory: 128Mi
```

#### 2. Error de conexión a base de datos
**Causa**: PostgreSQL no está listo
**Solución**:
```bash
# Verificar PostgreSQL
kubectl get pods -n backstage-demo -l app=postgresql

# Ver logs de PostgreSQL
kubectl logs -f deployment/postgresql -n backstage-demo
```

#### 3. Ingress no funciona
**Causa**: Ingress controller no habilitado
**Solución**:
```bash
# Habilitar ingress en Minikube
minikube addons enable ingress --profile=backstage-demo

# Verificar ingress controller
kubectl get pods -n ingress-nginx
```

## Personalización

### 1. Configuración de App
Editar `helm/backstage/values.yaml`:
```yaml
backstage:
  app:
    title: "Mi Portal de Desarrollador"
    baseUrl: "https://mi-dominio.com"
  organization:
    name: "Mi Organización"
```

### 2. Agregar Plugins
Editar `k8s/backstage/configmap.yaml`:
```yaml
plugins:
  - name: '@backstage/plugin-custom'
    version: latest
```

### 3. Configurar Integraciones
```bash
# Configurar GitHub
./scripts/backstage/configure-backstage.sh github

# Configurar OpenWebUI
./scripts/backstage/configure-backstage.sh openwebui
```

## Seguridad

### 1. Network Policies
```yaml
# Aplicar políticas de red restrictivas
kubectl apply -f k8s/backstage/networkpolicy.yaml
```

### 2. RBAC
```yaml
# Permisos mínimos necesarios
rules:
  - apiGroups: [""]
    resources: ["pods", "services"]
    verbs: ["get", "list", "watch"]
```

### 3. Secrets Management
```bash
# Rotar secrets
kubectl create secret generic backstage-secrets \
  --from-literal=GITHUB_TOKEN=nuevo-token \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Backup y Restauración

### 1. Backup de Base de Datos
```bash
# Backup de PostgreSQL
kubectl exec -n backstage-demo deployment/postgresql -- \
  pg_dump -U backstage backstage > backstage-backup.sql
```

### 2. Backup de Configuración
```bash
# Exportar configuración
kubectl get configmap backstage-config -n backstage-demo -o yaml > backstage-config-backup.yaml
```

### 3. Restauración
```bash
# Restaurar base de datos
kubectl exec -i -n backstage-demo deployment/postgresql -- \
  psql -U backstage backstage < backstage-backup.sql
```

## Escalado

### 1. Horizontal Pod Autoscaler
```yaml
# Habilitar HPA
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 70
```

### 2. Vertical Scaling
```bash
# Aumentar recursos
kubectl patch deployment backstage -n backstage-demo -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"backstage","resources":{"limits":{"memory":"1Gi","cpu":"1000m"}}}]}}}}'
```

## Limpieza

### Eliminar Despliegue
```bash
# Eliminar con script
./scripts/backstage/deploy-backstage.sh cleanup --force

# O eliminar manualmente
helm uninstall backstage -n backstage-demo
kubectl delete namespace backstage-demo
```

### Limpiar Minikube
```bash
# Eliminar perfil completo
minikube delete --profile=backstage-demo
```

## Referencias

- [Backstage Official Documentation](https://backstage.io/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs)
- [Helm Documentation](https://helm.sh/docs)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs)

## Soporte

Para problemas específicos del demo:
1. Verificar logs: `kubectl logs -f deployment/backstage -n backstage-demo`
2. Revisar eventos: `kubectl get events -n backstage-demo --sort-by='.lastTimestamp'`
3. Ejecutar diagnósticos: `./scripts/backstage/deploy-backstage.sh verify`
