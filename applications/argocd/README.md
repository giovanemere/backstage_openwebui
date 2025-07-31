# ArgoCD Docker Image - Demo Minikube

Imagen Docker optimizada de ArgoCD para el demo de Backstage + OpenWebUI en Minikube.

## Características

- **Imagen base**: argoproj/argocd:v2.9.3
- **Tamaño optimizado**: ~120MB (vs ~200MB imagen estándar)
- **Arquitectura**: Multi-stage build
- **Recursos**: 256Mi RAM, 200m CPU
- **Configuración**: GitOps ready

## Componentes

### ArgoCD Server
- Interfaz web y API
- Puerto 8080 (HTTP) / 8443 (HTTPS)
- Configuración insegura para demo

### ArgoCD Application Controller
- Reconciliación de aplicaciones
- Monitoreo de repositorios Git
- Sincronización automática

### ArgoCD Repo Server
- Gestión de repositorios
- Renderizado de manifiestos
- Cache de artefactos

## Configuración

### Variables de Entorno
```bash
ARGOCD_DEMO_MODE=true
ARGOCD_MINIKUBE_OPTIMIZED=true
ARGOCD_SERVER_INSECURE=true
ARGOCD_SERVER_ROOTPATH=/argocd
ARGOCD_EXEC_TIMEOUT=60s
```

### Puertos
- **8080**: Interfaz web ArgoCD (HTTP)
- **8443**: Interfaz web ArgoCD (HTTPS)

## Uso

### Build Local
```bash
# Desde la raíz del proyecto
make docker-build-argocd

# O directamente
docker build -t edissonz8809/iaops/argocd:demo-latest \
  -f applications/argocd/Dockerfile applications/argocd/
```

### Ejecutar Localmente
```bash
# Usando Makefile
make docker-test-argocd

# O directamente
docker run -d --name argocd-demo \
  -p 8080:8080 \
  edissonz8809/iaops/argocd:demo-latest
```

### Acceso
- **URL**: http://localhost:8080/argocd
- **Usuario**: admin
- **Password**: (obtener de logs del pod)

```bash
# Obtener password inicial
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

## Aplicaciones Preconfiguradas

### backstage-demo
Aplicación ArgoCD que despliega el stack completo:
- Backstage
- OpenWebUI  
- PostgreSQL

**Configuración:**
- **Repo**: https://github.com/edissonz8809/iaops
- **Path**: helm/backstage-openwebui-demo
- **Sync**: Automático con self-heal
- **Namespace**: backstage-demo

## Configuración RBAC

### Roles Disponibles
- **admin**: Acceso completo
- **developer**: Sync y logs
- **readonly**: Solo lectura

### Usuarios Demo
- **admin**: Administrador completo
- **developer**: Desarrollador con permisos limitados
- **guest**: Solo lectura

## Repositorios Configurados

### Git Repositories
- **demo-repo**: https://github.com/edissonz8809/iaops
- **bitnami**: https://charts.bitnami.com/bitnami (Helm)

## Health Check

```bash
# Verificar estado
curl -f http://localhost:8080/argocd/healthz

# Logs del contenedor
docker logs argocd-demo
```

## CLI de ArgoCD

### Instalación
```bash
# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
```

### Login
```bash
# Login al servidor
argocd login localhost:8080 --username admin --password <password> --insecure

# Listar aplicaciones
argocd app list

# Sincronizar aplicación
argocd app sync backstage-demo
```

## Troubleshooting

### Problema: ArgoCD no inicia
```bash
# Verificar logs
docker logs argocd-demo

# Verificar recursos
docker stats argocd-demo
```

### Problema: Aplicaciones no sincronizan
```bash
# Verificar conectividad a repositorio
argocd repo list

# Forzar sincronización
argocd app sync backstage-demo --force
```

### Problema: Memoria insuficiente
```bash
# Ajustar límites de memoria
docker run -d --name argocd-demo \
  -p 8080:8080 \
  -e ARGOCD_SERVER_REPO_SERVER_TIMEOUT_SECONDS=120 \
  edissonz8809/iaops/argocd:demo-latest
```

## Integración con Minikube

### Deployment
```bash
# Aplicar manifiestos Kubernetes
kubectl apply -f k8s/argocd/

# Port forward para acceso local
kubectl port-forward svc/argocd-server 8080:80 -n argocd
```

### Configuración de Cluster
ArgoCD se configura automáticamente para gestionar el cluster local de Minikube.

## Desarrollo

### Agregar Repositorio
```bash
# Via CLI
argocd repo add https://github.com/tu-usuario/tu-repo

# Via UI
Settings > Repositories > Connect Repo
```

### Crear Aplicación
```bash
# Via CLI
argocd app create mi-app \
  --repo https://github.com/tu-usuario/tu-repo \
  --path manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default
```

## Registry

- **DockerHub**: edissonz8809/iaops/argocd:demo-latest
- **Pull**: `docker pull edissonz8809/iaops/argocd:demo-latest`

## Seguridad

- Usuario no-root (argocd:999)
- Configuración insegura solo para demo
- RBAC configurado con roles específicos
- Health checks implementados
- Timeouts optimizados para recursos limitados

## Personalización UI

- **Banner**: "🚀 ArgoCD Demo - Backstage + OpenWebUI Integration"
- **Help URL**: Enlace a OpenWebUI para soporte
- **Tema**: Configuración optimizada para demo
