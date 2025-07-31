#!/bin/bash

# =============================================================================
# Script de Despliegue de Backstage - Optimizado para Demo Minikube
# =============================================================================

set -euo pipefail

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
NAMESPACE="backstage-demo"
RELEASE_NAME="backstage"
CHART_PATH="${PROJECT_ROOT}/helm/backstage"
K8S_PATH="${PROJECT_ROOT}/k8s/backstage"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Función para verificar prerrequisitos
check_prerequisites() {
    log_info "Verificando prerrequisitos..."
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl no está instalado"
        exit 1
    fi
    
    # Verificar helm
    if ! command -v helm &> /dev/null; then
        log_error "helm no está instalado"
        exit 1
    fi
    
    # Verificar conexión a cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "No se puede conectar al cluster de Kubernetes"
        exit 1
    fi
    
    # Verificar Minikube
    if command -v minikube &> /dev/null; then
        MINIKUBE_STATUS=$(minikube status --format='{{.Host}}' 2>/dev/null || echo "Stopped")
        if [[ "$MINIKUBE_STATUS" != "Running" ]]; then
            log_warning "Minikube no está ejecutándose. Iniciando..."
            minikube start --profile=backstage-demo --memory=4096 --cpus=2
        fi
    fi
    
    log_success "Prerrequisitos verificados"
}

# Función para crear namespace
create_namespace() {
    log_info "Creando namespace ${NAMESPACE}..."
    
    if kubectl get namespace "${NAMESPACE}" &> /dev/null; then
        log_warning "Namespace ${NAMESPACE} ya existe"
    else
        kubectl apply -f "${K8S_PATH}/namespace.yaml"
        log_success "Namespace ${NAMESPACE} creado"
    fi
}

# Función para verificar dependencias
check_dependencies() {
    log_info "Verificando dependencias..."
    
    # Verificar PostgreSQL
    if ! kubectl get deployment postgresql -n "${NAMESPACE}" &> /dev/null; then
        log_warning "PostgreSQL no encontrado. Se desplegará con Helm"
    fi
    
    # Verificar OpenWebUI
    if ! kubectl get service openwebui -n "${NAMESPACE}" &> /dev/null; then
        log_warning "OpenWebUI no encontrado. Asegúrate de desplegarlo primero"
    fi
    
    # Verificar Ingress Controller
    if ! kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx &> /dev/null; then
        log_warning "Ingress Controller no encontrado. Habilitando en Minikube..."
        if command -v minikube &> /dev/null; then
            minikube addons enable ingress --profile=backstage-demo
        fi
    fi
}

# Función para desplegar con Helm
deploy_with_helm() {
    log_info "Desplegando Backstage con Helm..."
    
    # Agregar repositorio de Bitnami para PostgreSQL
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
    
    # Instalar o actualizar
    if helm list -n "${NAMESPACE}" | grep -q "${RELEASE_NAME}"; then
        log_info "Actualizando release existente..."
        helm upgrade "${RELEASE_NAME}" "${CHART_PATH}" \
            --namespace "${NAMESPACE}" \
            --values "${CHART_PATH}/values.yaml" \
            --wait \
            --timeout=10m
    else
        log_info "Instalando nuevo release..."
        helm install "${RELEASE_NAME}" "${CHART_PATH}" \
            --namespace "${NAMESPACE}" \
            --create-namespace \
            --values "${CHART_PATH}/values.yaml" \
            --wait \
            --timeout=10m
    fi
    
    log_success "Backstage desplegado con Helm"
}

# Función para desplegar con manifiestos K8s
deploy_with_kubectl() {
    log_info "Desplegando Backstage con kubectl..."
    
    # Aplicar manifiestos en orden
    kubectl apply -f "${K8S_PATH}/namespace.yaml"
    kubectl apply -f "${K8S_PATH}/serviceaccount.yaml"
    kubectl apply -f "${K8S_PATH}/secret.yaml"
    kubectl apply -f "${K8S_PATH}/configmap.yaml"
    kubectl apply -f "${K8S_PATH}/service.yaml"
    kubectl apply -f "${K8S_PATH}/deployment.yaml"
    kubectl apply -f "${K8S_PATH}/ingress.yaml"
    kubectl apply -f "${K8S_PATH}/networkpolicy.yaml"
    
    # HPA es opcional para demo
    if [[ "${ENABLE_HPA:-false}" == "true" ]]; then
        kubectl apply -f "${K8S_PATH}/hpa.yaml"
    fi
    
    log_success "Backstage desplegado con kubectl"
}

# Función para verificar despliegue
verify_deployment() {
    log_info "Verificando despliegue..."
    
    # Esperar a que los pods estén listos
    log_info "Esperando a que los pods estén listos..."
    kubectl wait --for=condition=ready pod -l app=backstage -n "${NAMESPACE}" --timeout=300s
    
    # Verificar servicios
    log_info "Verificando servicios..."
    kubectl get services -n "${NAMESPACE}"
    
    # Verificar ingress
    log_info "Verificando ingress..."
    kubectl get ingress -n "${NAMESPACE}"
    
    # Health check
    log_info "Realizando health check..."
    if kubectl get pods -n "${NAMESPACE}" -l app=backstage | grep -q "Running"; then
        log_success "Backstage está ejecutándose correctamente"
    else
        log_error "Backstage no está ejecutándose correctamente"
        kubectl get pods -n "${NAMESPACE}" -l app=backstage
        return 1
    fi
}

# Función para mostrar información de acceso
show_access_info() {
    log_info "Información de acceso:"
    
    # Obtener IP de Minikube
    if command -v minikube &> /dev/null; then
        MINIKUBE_IP=$(minikube ip --profile=backstage-demo 2>/dev/null || echo "localhost")
        echo -e "${GREEN}Minikube IP:${NC} ${MINIKUBE_IP}"
    fi
    
    # Mostrar URLs
    echo -e "${GREEN}URLs de acceso:${NC}"
    echo -e "  - Backstage: http://localhost/backstage"
    echo -e "  - API: http://localhost/backstage-api"
    
    # Mostrar comandos útiles
    echo -e "${GREEN}Comandos útiles:${NC}"
    echo -e "  - Ver pods: kubectl get pods -n ${NAMESPACE}"
    echo -e "  - Ver logs: kubectl logs -f deployment/backstage -n ${NAMESPACE}"
    echo -e "  - Port forward: kubectl port-forward svc/backstage 7007:7007 -n ${NAMESPACE}"
    
    # Tunnel para Minikube
    if command -v minikube &> /dev/null; then
        echo -e "${YELLOW}Para acceder desde el navegador, ejecuta en otra terminal:${NC}"
        echo -e "  minikube tunnel --profile=backstage-demo"
    fi
}

# Función para limpiar recursos
cleanup() {
    log_info "Limpiando recursos..."
    
    if [[ "${1:-}" == "--force" ]]; then
        # Eliminar con Helm si existe
        if helm list -n "${NAMESPACE}" | grep -q "${RELEASE_NAME}"; then
            helm uninstall "${RELEASE_NAME}" -n "${NAMESPACE}"
        fi
        
        # Eliminar namespace
        kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true
        
        log_success "Recursos eliminados"
    else
        log_warning "Para eliminar todos los recursos, usa: $0 cleanup --force"
    fi
}

# Función principal
main() {
    local command="${1:-deploy}"
    
    case "$command" in
        "deploy")
            local method="${2:-helm}"
            check_prerequisites
            create_namespace
            check_dependencies
            
            if [[ "$method" == "helm" ]]; then
                deploy_with_helm
            elif [[ "$method" == "kubectl" ]]; then
                deploy_with_kubectl
            else
                log_error "Método de despliegue no válido: $method (usa 'helm' o 'kubectl')"
                exit 1
            fi
            
            verify_deployment
            show_access_info
            ;;
        "verify")
            verify_deployment
            ;;
        "info")
            show_access_info
            ;;
        "cleanup")
            cleanup "${2:-}"
            ;;
        "help"|"-h"|"--help")
            echo "Uso: $0 [comando] [opciones]"
            echo ""
            echo "Comandos:"
            echo "  deploy [helm|kubectl]  - Desplegar Backstage (por defecto: helm)"
            echo "  verify                 - Verificar despliegue"
            echo "  info                   - Mostrar información de acceso"
            echo "  cleanup [--force]      - Limpiar recursos"
            echo "  help                   - Mostrar esta ayuda"
            echo ""
            echo "Ejemplos:"
            echo "  $0 deploy helm         - Desplegar con Helm"
            echo "  $0 deploy kubectl      - Desplegar con kubectl"
            echo "  $0 verify              - Verificar despliegue"
            echo "  $0 cleanup --force     - Eliminar todos los recursos"
            ;;
        *)
            log_error "Comando no válido: $command"
            echo "Usa '$0 help' para ver los comandos disponibles"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"
