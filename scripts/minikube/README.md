# Automatización de Minikube - Demo Backstage + OpenWebUI

Scripts automatizados para configurar, gestionar y troubleshoot un cluster Minikube optimizado para el demo.

## 📋 Índice

- [Scripts Disponibles](#scripts-disponibles)
- [Requisitos del Sistema](#requisitos-del-sistema)
- [Guía de Uso](#guía-de-uso)
- [Troubleshooting](#troubleshooting)
- [Configuración Avanzada](#configuración-avanzada)

## 🛠️ Scripts Disponibles

### 1. `setup-minikube.sh` - Configuración Principal
Configura un cluster Minikube completo optimizado para el demo.

```bash
# Setup estándar
./scripts/minikube/setup-minikube.sh

# Setup con limpieza previa
./scripts/minikube/setup-minikube.sh --clean

# Setup rápido (sin imágenes)
./scripts/minikube/setup-minikube.sh --skip-images

# Setup con recursos personalizados
./scripts/minikube/setup-minikube.sh --memory 6144 --cpus 4
```

**Características:**
- ✅ Verificación automática de prerequisitos
- ✅ Configuración optimizada para recursos limitados
- ✅ Habilitación automática de addons necesarios
- ✅ Creación de namespaces para demo
- ✅ Precarga de imágenes Docker
- ✅ Validación completa del cluster

### 2. `check-resources.sh` - Verificación de Recursos
Verifica que el sistema tenga recursos suficientes para ejecutar el demo.

```bash
# Verificación completa
./scripts/minikube/check-resources.sh
```

**Verifica:**
- 💾 Memoria disponible (mínimo 3GB, recomendado 6GB)
- 💿 Espacio en disco (mínimo 15GB, recomendado 25GB)
- ⚡ CPUs disponibles (mínimo 2, recomendado 4)
- 🐳 Docker funcionando
- ☸️ Herramientas Kubernetes instaladas

### 3. `troubleshoot.sh` - Diagnóstico y Reparación
Diagnostica y repara problemas comunes del cluster.

```bash
# Diagnóstico completo
./scripts/minikube/troubleshoot.sh

# Reparar problemas comunes
./scripts/minikube/troubleshoot.sh fix-common

# Resetear cluster completamente
./scripts/minikube/troubleshoot.sh reset-cluster

# Ver logs detallados
./scripts/minikube/troubleshoot.sh logs --verbose
```

**Problemas que resuelve:**
- 🔧 Cluster no inicia
- 🔧 Pods en estado Pending/CrashLoopBackOff
- 🔧 Servicios no accesibles
- 🔧 Ingress no funciona
- 🔧 Problemas de DNS
- 🔧 Recursos insuficientes

### 4. `cleanup.sh` - Limpieza de Recursos
Limpia recursos para liberar espacio en el sistema.

```bash
# Limpieza interactiva
./scripts/minikube/cleanup.sh

# Limpieza completa
./scripts/minikube/cleanup.sh --all --force

# Solo limpiar cluster
./scripts/minikube/cleanup.sh --cluster-only

# Ver qué se eliminaría
./scripts/minikube/cleanup.sh --dry-run
```

**Limpia:**
- 🗑️ Cluster Minikube
- 🗑️ Imágenes Docker del demo
- 🗑️ Contenedores y volúmenes huérfanos
- 🗑️ Cache y archivos temporales

## 💻 Requisitos del Sistema

### Mínimos (Funcional)
- **RAM**: 3GB disponible
- **CPU**: 2 cores
- **Disco**: 15GB libres
- **SO**: Linux/macOS/Windows con WSL2

### Recomendados (Óptimo)
- **RAM**: 6GB disponible
- **CPU**: 4 cores
- **Disco**: 25GB libres
- **SSD**: Para mejor rendimiento I/O

### Software Requerido
- Docker (ejecutándose)
- Minikube >= 1.30.0
- kubectl >= 1.28.0
- Helm >= 3.12.0 (opcional)

## 🚀 Guía de Uso

### Setup Inicial Completo

```bash
# 1. Verificar recursos del sistema
make minikube-check

# 2. Configurar cluster Minikube
make minikube-setup

# 3. Verificar estado del cluster
make minikube-status

# 4. Construir y desplegar aplicaciones
make docker-build-all
make k8s-deploy-all
```

### Workflow de Desarrollo

```bash
# Desarrollo diario
make minikube-setup-fast    # Setup rápido
make docker-build-all       # Construir imágenes
make k8s-deploy-all        # Desplegar aplicaciones

# Al finalizar el día
make minikube-cleanup      # Limpiar recursos
```

### Resolución de Problemas

```bash
# Diagnóstico automático
make minikube-troubleshoot

# Reparación automática
make minikube-fix

# Si nada funciona
make minikube-reset
```

## 🔧 Troubleshooting

### Problemas Comunes y Soluciones

#### 1. "Cluster no inicia"
```bash
# Verificar recursos
./scripts/minikube/check-resources.sh

# Limpiar y recrear
./scripts/minikube/setup-minikube.sh --clean
```

#### 2. "Pods en Pending"
```bash
# Diagnosticar recursos
kubectl describe pod <pod-name> -n <namespace>

# Reparar automáticamente
./scripts/minikube/troubleshoot.sh fix-common
```

#### 3. "Imágenes no se descargan"
```bash
# Verificar conectividad
docker pull hello-world

# Precargar imágenes manualmente
./scripts/minikube/setup-minikube.sh --skip-addons
```

#### 4. "Memoria insuficiente"
```bash
# Verificar uso actual
kubectl top nodes
kubectl top pods --all-namespaces

# Ajustar recursos
./scripts/minikube/setup-minikube.sh --memory 3072 --cpus 2
```

#### 5. "Ingress no funciona"
```bash
# Verificar addon
minikube addons list -p backstage-demo

# Reparar ingress
./scripts/minikube/troubleshoot.sh check-ingress
```

### Logs Útiles

```bash
# Logs del cluster
make minikube-logs

# Logs de un pod específico
kubectl logs <pod-name> -n <namespace> --tail=50

# Eventos del cluster
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Estado detallado de un pod
kubectl describe pod <pod-name> -n <namespace>
```

## ⚙️ Configuración Avanzada

### Variables de Entorno

```bash
# Personalizar configuración
export MINIKUBE_MEMORY=6144
export MINIKUBE_CPUS=4
export MINIKUBE_DISK_SIZE=30g
export MINIKUBE_DRIVER=docker

./scripts/minikube/setup-minikube.sh
```

### Configuración de Red

```bash
# Para entornos corporativos con proxy
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
export NO_PROXY=localhost,127.0.0.1,10.96.0.0/12,192.168.0.0/16

./scripts/minikube/setup-minikube.sh
```

### Optimizaciones de Rendimiento

```bash
# Para sistemas con SSD
./scripts/minikube/setup-minikube.sh \
  --memory 8192 \
  --cpus 6 \
  --disk-size 40g

# Para sistemas con recursos limitados
./scripts/minikube/setup-minikube.sh \
  --memory 3072 \
  --cpus 2 \
  --skip-images
```

### Configuración Multi-Cluster

```bash
# Crear múltiples clusters para testing
minikube start -p demo-dev --memory 2048 --cpus 2
minikube start -p demo-staging --memory 4096 --cpus 3
minikube start -p demo-prod --memory 6144 --cpus 4

# Cambiar entre clusters
kubectl config use-context demo-dev
kubectl config use-context demo-staging
```

## 📊 Monitoreo y Métricas

### Dashboard de Minikube
```bash
# Abrir dashboard web
make minikube-dashboard

# Acceder via port-forward
kubectl proxy --port=8001
# http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/
```

### Métricas de Recursos
```bash
# Habilitar metrics server
minikube addons enable metrics-server -p backstage-demo

# Ver métricas
kubectl top nodes
kubectl top pods --all-namespaces
```

### Alertas Automáticas
```bash
# Script de monitoreo continuo
watch -n 30 'kubectl get pods --all-namespaces | grep -v Running'

# Verificación de salud automática
while true; do
  ./scripts/minikube/troubleshoot.sh diagnose
  sleep 300  # Cada 5 minutos
done
```

## 🔗 Integración con CI/CD

### GitHub Actions
```yaml
- name: Setup Minikube
  run: |
    ./scripts/minikube/check-resources.sh
    ./scripts/minikube/setup-minikube.sh --skip-images
    
- name: Deploy Applications
  run: |
    make docker-build-all
    make k8s-deploy-all
```

### Jenkins Pipeline
```groovy
stage('Setup Minikube') {
    steps {
        sh './scripts/minikube/setup-minikube.sh --clean'
    }
}
```

## 📚 Referencias

- [Documentación oficial de Minikube](https://minikube.sigs.k8s.io/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [Helm Documentation](https://helm.sh/docs/)

## 🤝 Contribución

Para reportar problemas o sugerir mejoras:

1. Ejecutar diagnóstico: `./scripts/minikube/troubleshoot.sh`
2. Recopilar logs: `make minikube-logs`
3. Crear issue con información detallada

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Ver archivo LICENSE para más detalles.
