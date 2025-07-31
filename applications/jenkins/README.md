# Jenkins Docker Image - Demo Minikube

Imagen Docker optimizada de Jenkins para el demo de Backstage + OpenWebUI en Minikube.

## Características

- **Imagen base**: jenkins/jenkins:2.426.1-lts-alpine
- **Tamaño optimizado**: ~300MB (vs ~600MB imagen estándar)
- **Arquitectura**: Multi-stage build
- **Recursos**: 512Mi RAM, 500m CPU
- **Configuración**: Jenkins Configuration as Code (JCasC)

## Plugins Incluidos

### Core Plugins
- Pipeline (workflow-aggregator)
- Git integration
- Docker workflow
- Kubernetes integration
- Blue Ocean UI

### Demo-specific
- Configuration as Code
- Job DSL
- Simple theme plugin
- Dashboard view

## Configuración

### Variables de Entorno
```bash
JENKINS_ADMIN_USER=admin
JENKINS_ADMIN_PASSWORD=demo-jenkins-password
JENKINS_DEMO_MODE=true
JENKINS_MINIKUBE_OPTIMIZED=true
JAVA_OPTS="-Xmx256m -Xms128m"
```

### Puertos
- **8080**: Interfaz web Jenkins
- **50000**: Agentes Jenkins (JNLP)

## Uso

### Build Local
```bash
# Desde la raíz del proyecto
make docker-build-jenkins

# O directamente
docker build -t edissonz8809/iaops/jenkins:demo-latest \
  -f applications/jenkins/Dockerfile applications/jenkins/
```

### Ejecutar Localmente
```bash
# Usando Makefile
make docker-test-jenkins

# O directamente
docker run -d --name jenkins-demo \
  -p 8080:8080 \
  edissonz8809/iaops/jenkins:demo-latest
```

### Acceso
- **URL**: http://localhost:8080/jenkins
- **Usuario**: admin
- **Password**: demo-jenkins-password

## Jobs Preconfigurados

### backstage-build
Pipeline para construir la aplicación Backstage desde el repositorio Git.

### openwebui-build
Pipeline para construir la aplicación OpenWebUI desde el repositorio Git.

## Configuración JCasC

La configuración se realiza automáticamente mediante Jenkins Configuration as Code:

- **Seguridad**: Usuario admin preconfigurado
- **Herramientas**: Git, Docker, kubectl, helm
- **Credenciales**: DockerHub y GitHub (requieren configuración)
- **Jobs**: Pipelines de demo precargados

## Health Check

```bash
# Verificar estado
curl -f http://localhost:8080/jenkins/login

# Logs del contenedor
docker logs jenkins-demo
```

## Troubleshooting

### Problema: Jenkins no inicia
```bash
# Verificar logs
docker logs jenkins-demo

# Verificar recursos
docker stats jenkins-demo
```

### Problema: Plugins no cargan
```bash
# Reconstruir imagen sin cache
make docker-build-jenkins DOCKER_BUILD_ARGS="--no-cache"
```

### Problema: Memoria insuficiente
```bash
# Ajustar límites de memoria
docker run -d --name jenkins-demo \
  -p 8080:8080 \
  -e JAVA_OPTS="-Xmx512m -Xms256m" \
  edissonz8809/iaops/jenkins:demo-latest
```

## Integración con Minikube

### Deployment
```bash
# Aplicar manifiestos Kubernetes
kubectl apply -f k8s/jenkins/

# Port forward para acceso local
kubectl port-forward svc/jenkins 8080:8080 -n jenkins
```

### Configuración de Agentes
Los agentes Jenkins se configuran automáticamente para ejecutar en pods de Kubernetes.

## Desarrollo

### Agregar Plugins
1. Editar `plugins.txt`
2. Reconstruir imagen
3. Probar localmente

### Modificar Configuración
1. Editar `jenkins.yaml` (JCasC)
2. Reconstruir imagen
3. Verificar configuración

## Registry

- **DockerHub**: edissonz8809/iaops/jenkins:demo-latest
- **Pull**: `docker pull edissonz8809/iaops/jenkins:demo-latest`

## Seguridad

- Usuario no-root (jenkins:jenkins)
- Credenciales por defecto solo para demo
- Configuración JCasC para reproducibilidad
- Health checks implementados
