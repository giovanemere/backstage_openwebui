# Jenkins para Demo Backstage + OpenWebUI

Implementación de Jenkins optimizada para CI/CD en el demo de Minikube.

## 📋 Índice

- [Características](#características)
- [Arquitectura](#arquitectura)
- [Instalación](#instalación)
- [Configuración](#configuración)
- [Pipelines](#pipelines)
- [Troubleshooting](#troubleshooting)

## 🚀 Características

### Optimizaciones para Demo
- **Imagen Multi-stage**: Reducción del 50% en tamaño (~300MB vs ~600MB)
- **Recursos Limitados**: 512Mi RAM, 500m CPU (optimizado para Minikube)
- **Configuración JCasC**: Configuration as Code para setup automático
- **Plugins Mínimos**: Solo plugins esenciales para reducir overhead
- **Integración Kubernetes**: Agentes dinámicos en Minikube

### Funcionalidades Incluidas
- ✅ Autenticación básica (admin/demo123)
- ✅ Integración con Kubernetes (agentes dinámicos)
- ✅ Soporte para Docker builds
- ✅ Pipelines predefinidos para el demo
- ✅ Configuración de credenciales automática
- ✅ Ingress configurado para acceso web
- ✅ Persistencia con PVC (2Gi)

## 🏗️ Arquitectura

### Componentes
```
┌─────────────────────────────────────────────────────────────┐
│                    Jenkins Architecture                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────┐    │
│  │   Jenkins   │    │  Kubernetes  │    │   Docker    │    │
│  │   Master    │◄──►│   Agents     │◄──►│   Builds    │    │
│  │             │    │              │    │             │    │
│  └─────────────┘    └──────────────┘    └─────────────┘    │
│         │                   │                   │          │
│         ▼                   ▼                   ▼          │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────┐    │
│  │    JCasC    │    │     RBAC     │    │  DockerHub  │    │
│  │   Config    │    │  Permissions │    │  Registry   │    │
│  └─────────────┘    └──────────────┘    └─────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Recursos Configurados
- **Namespace**: `jenkins`
- **Memoria**: 512Mi (límite), 256Mi (request)
- **CPU**: 500m (límite), 100m (request)
- **Storage**: 2Gi PVC
- **Réplicas**: 1 (optimizado para demo)

## 📦 Instalación

### Instalación Rápida
```bash
# Setup completo (recomendado)
make jenkins-setup

# Solo construir imagen
make jenkins-build

# Solo desplegar
make jenkins-deploy
```

### Instalación Manual
```bash
# 1. Construir imagen Docker
cd docker/jenkins
docker build -t edissonz8809/iaops/jenkins:demo-latest .
minikube image load edissonz8809/iaops/jenkins:demo-latest -p backstage-demo

# 2. Desplegar con Helm
helm upgrade --install jenkins helm/jenkins \
  --namespace jenkins \
  --create-namespace \
  --wait

# 3. Verificar instalación
kubectl get pods -n jenkins
```

### Instalación con Limpieza
```bash
# Limpiar instalación anterior y reinstalar
make jenkins-setup-clean
```

## ⚙️ Configuración

### Usuarios Predefinidos
| Usuario | Contraseña | Permisos |
|---------|------------|----------|
| admin   | demo123    | Administrador completo |
| demo    | demo123    | Usuario estándar |

### Credenciales Configuradas
- **DockerHub**: `dockerhub-credentials` (edissonz8809/demo-password)
- **Minikube**: `minikube-token` (token de servicio)

### Configuración JCasC
La configuración se gestiona automáticamente via Jenkins Configuration as Code:

```yaml
jenkins:
  systemMessage: "Jenkins para Demo Backstage + OpenWebUI"
  numExecutors: 2
  clouds:
    - kubernetes:
        name: "minikube"
        namespace: "jenkins"
        templates:
          - name: "jenkins-agent"
            containers:
              - name: "jnlp"
                image: "jenkins/inbound-agent:latest"
                resourceLimitMemory: "512Mi"
                resourceLimitCpu: "500m"
```

### Plugins Instalados
- **Core**: configuration-as-code, git, workflow-aggregator
- **Kubernetes**: kubernetes, kubernetes-cli, kubernetes-credentials
- **Docker**: docker-workflow, docker-plugin
- **Pipeline**: pipeline-model-definition, pipeline-stage-view
- **UI**: dark-theme, simple-theme-plugin

## 🔄 Pipelines

### Pipelines Predefinidos

#### 1. Demo/backstage-build
Pipeline para construir y desplegar Backstage:
```groovy
pipeline {
    agent { kubernetes { label 'jenkins-agent' } }
    stages {
        stage('Build') { /* Construir imagen Docker */ }
        stage('Test') { /* Probar imagen */ }
        stage('Deploy') { /* Desplegar en Kubernetes */ }
    }
}
```

#### 2. Demo/openwebui-build
Pipeline para construir y desplegar OpenWebUI:
```groovy
pipeline {
    agent { kubernetes { label 'jenkins-agent' } }
    stages {
        stage('Build') { /* Construir imagen Docker */ }
        stage('Test') { /* Probar imagen */ }
        stage('Deploy') { /* Desplegar en Kubernetes */ }
    }
}
```

#### 3. Demo/full-deploy
Pipeline completo para desplegar todo el demo:
```groovy
pipeline {
    parameters {
        choice(name: 'DEPLOY_ENVIRONMENT', choices: ['demo', 'staging'])
        booleanParam(name: 'CLEAN_DEPLOY', defaultValue: false)
    }
    stages {
        stage('Build All') { /* Construir todas las imágenes */ }
        stage('Deploy Infrastructure') { /* PostgreSQL */ }
        stage('Deploy Applications') { /* Backstage + OpenWebUI */ }
        stage('Verify') { /* Pruebas de integración */ }
    }
}
```

### Ejecutar Pipelines
```bash
# Via interfaz web
http://$(minikube ip -p backstage-demo)/jenkins

# Via CLI (requiere jenkins-cli)
java -jar jenkins-cli.jar -s http://jenkins:8080/jenkins build Demo/full-deploy
```

## 🌐 Acceso

### URL de Acceso
```bash
# Obtener URL
make jenkins-url

# Port-forward directo
make jenkins-port-forward
# Acceder a: http://localhost:8080/jenkins
```

### Ingress Configuration
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jenkins
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
    - http:
        paths:
          - path: /jenkins(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: jenkins
                port:
                  number: 8080
```

## 🔧 Gestión

### Comandos Útiles
```bash
# Ver estado
make jenkins-status

# Ver logs
make jenkins-logs

# Acceder al shell
make jenkins-shell

# Limpiar instalación
make jenkins-cleanup
```

### Monitoreo
```bash
# Ver recursos utilizados
kubectl top pods -n jenkins

# Ver eventos
kubectl get events -n jenkins --sort-by='.lastTimestamp'

# Verificar configuración
kubectl describe pod -n jenkins -l app.kubernetes.io/name=jenkins
```

## 🐛 Troubleshooting

### Problemas Comunes

#### 1. Jenkins no inicia
```bash
# Verificar logs
kubectl logs -n jenkins -l app.kubernetes.io/name=jenkins

# Verificar recursos
kubectl describe pod -n jenkins -l app.kubernetes.io/name=jenkins

# Verificar PVC
kubectl get pvc -n jenkins
```

**Solución**:
```bash
# Reiniciar pod
kubectl delete pod -n jenkins -l app.kubernetes.io/name=jenkins

# Si persiste, limpiar y reinstalar
make jenkins-setup-clean
```

#### 2. Agentes Kubernetes no se conectan
```bash
# Verificar RBAC
kubectl get rolebinding -n jenkins

# Verificar ServiceAccount
kubectl get serviceaccount -n jenkins
```

**Solución**:
```bash
# Verificar configuración de cloud
kubectl exec -n jenkins -l app.kubernetes.io/name=jenkins -- cat /var/jenkins_home/casc_configs/jenkins.yaml
```

#### 3. Builds fallan por permisos Docker
```bash
# Verificar socket Docker
kubectl exec -n jenkins -l app.kubernetes.io/name=jenkins -- ls -la /var/run/docker.sock
```

**Solución**:
```bash
# Verificar que el usuario jenkins esté en grupo docker
kubectl exec -n jenkins -l app.kubernetes.io/name=jenkins -- groups jenkins
```

#### 4. Ingress no funciona
```bash
# Verificar ingress controller
kubectl get pods -n ingress-nginx

# Verificar ingress
kubectl get ingress -n jenkins
kubectl describe ingress -n jenkins jenkins
```

**Solución**:
```bash
# Habilitar ingress addon
minikube addons enable ingress -p backstage-demo

# Esperar a que esté listo
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s
```

### Logs de Debug
```bash
# Logs detallados de Jenkins
kubectl logs -n jenkins -l app.kubernetes.io/name=jenkins --tail=100

# Logs de inicialización
kubectl logs -n jenkins -l app.kubernetes.io/name=jenkins -c init-jenkins

# Eventos del namespace
kubectl get events -n jenkins --sort-by='.lastTimestamp'
```

### Verificación de Salud
```bash
# Health check manual
kubectl exec -n jenkins -l app.kubernetes.io/name=jenkins -- curl -f http://localhost:8080/jenkins/login

# Verificar plugins
kubectl exec -n jenkins -l app.kubernetes.io/name=jenkins -- java -jar /usr/share/jenkins/jenkins.war --version
```

## 🔄 Integración con Demo

### Workflow Completo
1. **Setup Minikube**: `make minikube-setup`
2. **Setup Jenkins**: `make jenkins-setup`
3. **Ejecutar Pipeline**: Acceder a Jenkins y ejecutar `Demo/full-deploy`
4. **Verificar Despliegue**: Los pipelines despliegan automáticamente Backstage y OpenWebUI

### Variables de Entorno
Los pipelines utilizan estas variables automáticamente:
- `DOCKER_REGISTRY=edissonz8809/iaops`
- `MINIKUBE_PROFILE=backstage-demo`
- `NAMESPACE=backstage-demo`

### Integración con Makefile
```bash
# Workflow completo de demo
make minikube-setup     # 1. Setup Minikube
make jenkins-setup      # 2. Setup Jenkins
make docker-build-all   # 3. Construir imágenes
# 4. Ejecutar pipelines via Jenkins UI
```

## 📚 Referencias

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Jenkins Configuration as Code](https://github.com/jenkinsci/configuration-as-code-plugin)
- [Kubernetes Plugin](https://github.com/jenkinsci/kubernetes-plugin)
- [Docker Pipeline Plugin](https://github.com/jenkinsci/docker-workflow-plugin)

## 🤝 Contribución

Para reportar problemas o sugerir mejoras:
1. Verificar logs: `make jenkins-logs`
2. Revisar configuración: `kubectl describe pod -n jenkins`
3. Crear issue con información detallada
