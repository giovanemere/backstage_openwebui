#!/bin/bash

# Script para configurar cluster Minikube para Backstage + OpenWebUI Demo
# Autor: Amazon Q
# Fecha: 2025-07-30

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuración por defecto
MINIKUBE_MEMORY=${MINIKUBE_MEMORY:-4096}
MINIKUBE_CPUS=${MINIKUBE_CPUS:-2}
MINIKUBE_DISK_SIZE=${MINIKUBE_DISK_SIZE:-20g}
MINIKUBE_DRIVER=${MINIKUBE_DRIVER:-docker}

print_info "Configurando cluster Minikube para Backstage + OpenWebUI Demo..."
print_info "Configuración:"
print_info "  - Memoria: ${MINIKUBE_MEMORY}MB"
print_info "  - CPUs: ${MINIKUBE_CPUS}"
print_info "  - Disco: ${MINIKUBE_DISK_SIZE}"
print_info "  - Driver: ${MINIKUBE_DRIVER}"
echo ""

# Verificar si Minikube ya está corriendo
if minikube status >/dev/null 2>&1; then
    print_warning "Minikube ya está corriendo. Deteniendo cluster existente..."
    minikube stop
    print_info "Eliminando cluster existente para configuración limpia..."
    minikube delete
fi

# Iniciar Minikube con configuración optimizada
print_info "Iniciando Minikube con configuración optimizada..."
minikube start \
    --memory=$MINIKUBE_MEMORY \
    --cpus=$MINIKUBE_CPUS \
    --disk-size=$MINIKUBE_DISK_SIZE \
    --driver=$MINIKUBE_DRIVER \
    --kubernetes-version=stable \
    --extra-config=kubelet.housekeeping-interval=10s

print_success "Minikube iniciado correctamente ✓"

# Verificar estado del cluster
print_info "Verificando estado del cluster..."
minikube status

# Configurar kubectl para usar el contexto de Minikube
print_info "Configurando kubectl..."
kubectl config use-context minikube
print_success "kubectl configurado para usar Minikube ✓"

# Habilitar addons necesarios
print_info "Habilitando addons necesarios..."

# Ingress controller
print_info "Habilitando ingress controller..."
minikube addons enable ingress
print_success "Ingress controller habilitado ✓"

# Dashboard (opcional pero útil para debugging)
print_info "Habilitando dashboard..."
minikube addons enable dashboard
print_success "Dashboard habilitado ✓"

# Metrics server (para kubectl top)
print_info "Habilitando metrics server..."
minikube addons enable metrics-server
print_success "Metrics server habilitado ✓"

# Registry (para desarrollo local)
print_info "Habilitando registry local..."
minikube addons enable registry
print_success "Registry local habilitado ✓"

# Configurar Docker environment para usar Minikube registry
print_info "Configurando Docker environment..."
eval $(minikube docker-env)
print_success "Docker environment configurado ✓"

# Crear namespace por defecto si no existe
print_info "Verificando namespace por defecto..."
if ! kubectl get namespace default >/dev/null 2>&1; then
    kubectl create namespace default
    print_success "Namespace 'default' creado ✓"
else
    print_success "Namespace 'default' ya existe ✓"
fi

# Aplicar configuraciones básicas de Kubernetes
print_info "Aplicando configuraciones básicas..."

# Resource quotas para limitar uso de recursos
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: demo-resource-quota
  namespace: default
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 3Gi
    limits.cpu: "4"
    limits.memory: 6Gi
    pods: "10"
    services: "10"
    persistentvolumeclaims: "5"
EOF

print_success "Resource quota aplicado ✓"

# Network policy básica (opcional, para seguridad)
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: demo-network-policy
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}
  egress:
  - {}
EOF

print_success "Network policy aplicado ✓"

# Verificar que todos los pods del sistema estén corriendo
print_info "Verificando pods del sistema..."
kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=300s

# Mostrar información del cluster
print_info "Información del cluster:"
echo ""
print_info "Nodos:"
kubectl get nodes -o wide

echo ""
print_info "Pods del sistema:"
kubectl get pods -n kube-system

echo ""
print_info "Addons habilitados:"
minikube addons list | grep enabled

echo ""
print_info "Recursos disponibles:"
kubectl describe node minikube | grep -A 5 "Allocated resources" || true

# Configurar Helm
print_info "Configurando Helm..."
if ! helm repo list | grep -q stable; then
    helm repo add stable https://charts.helm.sh/stable
    print_success "Repositorio stable de Helm agregado ✓"
fi

if ! helm repo list | grep -q bitnami; then
    helm repo add bitnami https://charts.bitnami.com/bitnami
    print_success "Repositorio bitnami de Helm agregado ✓"
fi

helm repo update
print_success "Repositorios de Helm actualizados ✓"

# Crear directorio para persistent volumes si no existe
print_info "Configurando almacenamiento persistente..."
minikube ssh 'sudo mkdir -p /mnt/data/postgres /mnt/data/docs /mnt/data/backups'
print_success "Directorios de almacenamiento creados ✓"

echo ""
print_info "=== RESUMEN DE CONFIGURACIÓN ==="
print_success "✅ Cluster Minikube configurado correctamente"
print_info "Configuración aplicada:"
print_info "  - Memoria asignada: ${MINIKUBE_MEMORY}MB"
print_info "  - CPUs asignados: ${MINIKUBE_CPUS}"
print_info "  - Espacio en disco: ${MINIKUBE_DISK_SIZE}"
print_info "  - Ingress controller: Habilitado"
print_info "  - Dashboard: Habilitado"
print_info "  - Metrics server: Habilitado"
print_info "  - Registry local: Habilitado"
print_info "  - Resource quotas: Aplicados"
print_info "  - Network policies: Aplicadas"

echo ""
print_info "=== PRÓXIMOS PASOS ==="
print_info "1. Verificar que todo funciona:"
print_info "   kubectl get pods --all-namespaces"
print_info ""
print_info "2. Acceder al dashboard (opcional):"
print_info "   minikube dashboard"
print_info ""
print_info "3. Desplegar la aplicación:"
print_info "   make deploy-demo"
print_info ""
print_info "4. Ver logs del cluster:"
print_info "   make logs"

echo ""
print_info "=== COMANDOS ÚTILES ==="
print_info "- Estado del cluster: minikube status"
print_info "- Detener cluster: minikube stop"
print_info "- Eliminar cluster: minikube delete"
print_info "- IP del cluster: minikube ip"
print_info "- SSH al nodo: minikube ssh"
print_info "- Ver recursos: kubectl top nodes && kubectl top pods"

echo ""
print_success "🎉 Cluster Minikube listo para Backstage + OpenWebUI Demo!"
