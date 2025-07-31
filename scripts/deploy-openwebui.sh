#!/bin/bash

# Deploy OpenWebUI Script
# Script automatizado para desplegar OpenWebUI en Kubernetes usando Helm o kubectl
# Optimizado para demo en Minikube con integración Backstage

set -euo pipefail

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
NAMESPACE="openwebui-demo"
RELEASE_NAME="openwebui"
ENVIRONMENT="demo"
DEPLOYMENT_METHOD="helm"  # helm o kubectl
WAIT_TIMEOUT="600s"
DRY_RUN=false
VERBOSE=false
FORCE=false

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Función de ayuda
show_help() {
    cat << EOF
Deploy OpenWebUI Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -e, --environment ENV    Environment (dev|demo|prod) [default: demo]
    -m, --method METHOD      Deployment method (helm|kubectl) [default: helm]
    -n, --namespace NS       Kubernetes namespace [default: openwebui-demo]
    -r, --release NAME       Helm release name [default: openwebui]
    -t, --timeout TIMEOUT   Wait timeout [default: 600s]
    --dry-run               Show what would be deployed without applying
    --force                 Force deployment even if already exists
    -v, --verbose           Verbose output
    -h, --help              Show this help

EXAMPLES:
    # Deploy with default settings (demo environment, helm)
    $0

    # Deploy to development environment
    $0 --environment dev

    # Deploy using kubectl manifests
    $0 --method kubectl

    # Dry run to see what would be deployed
    $0 --dry-run

    # Force redeploy
    $0 --force

    # Deploy to production with custom namespace
    $0 --environment prod --namespace openwebui-prod

ENVIRONMENTS:
    dev     - Development environment (more resources, debug enabled)
    demo    - Demo environment (optimized for Minikube)
    prod    - Production environment (high availability, security)

DEPLOYMENT METHODS:
    helm    - Use Helm chart (recommended)
    kubectl - Use raw Kubernetes manifests

EOF
}

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -m|--method)
            DEPLOYMENT_METHOD="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -t|--timeout)
            WAIT_TIMEOUT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validar argumentos
if [[ ! "$ENVIRONMENT" =~ ^(dev|demo|prod)$ ]]; then
    error "Invalid environment: $ENVIRONMENT. Must be dev, demo, or prod"
    exit 1
fi

if [[ ! "$DEPLOYMENT_METHOD" =~ ^(helm|kubectl)$ ]]; then
    error "Invalid deployment method: $DEPLOYMENT_METHOD. Must be helm or kubectl"
    exit 1
fi

# Función para verificar prerequisitos
check_prerequisites() {
    log "Verificando prerequisitos..."
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl no está instalado"
        exit 1
    fi
    
    # Verificar conexión a cluster
    if ! kubectl cluster-info &> /dev/null; then
        error "No se puede conectar al cluster de Kubernetes"
        exit 1
    fi
    
    # Verificar Helm si es necesario
    if [[ "$DEPLOYMENT_METHOD" == "helm" ]]; then
        if ! command -v helm &> /dev/null; then
            error "Helm no está instalado"
            exit 1
        fi
    fi
    
    # Verificar archivos necesarios
    if [[ "$DEPLOYMENT_METHOD" == "helm" ]]; then
        if [[ ! -f "$PROJECT_ROOT/helm/openwebui/Chart.yaml" ]]; then
            error "Chart de Helm no encontrado en $PROJECT_ROOT/helm/openwebui/"
            exit 1
        fi
    else
        if [[ ! -d "$PROJECT_ROOT/k8s/openwebui" ]]; then
            error "Manifiestos de Kubernetes no encontrados en $PROJECT_ROOT/k8s/openwebui/"
            exit 1
        fi
    fi
    
    info "Prerequisitos verificados correctamente"
}

# Función para procesar variables de entorno
process_environment_variables() {
    log "Procesando variables de entorno para $ENVIRONMENT..."
    
    # Cargar variables del archivo .env si existe
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        source "$PROJECT_ROOT/.env"
        info "Variables cargadas desde .env"
    fi
    
    # Procesar charts si es necesario
    if [[ "$DEPLOYMENT_METHOD" == "helm" ]] && [[ -f "$PROJECT_ROOT/scripts/process-charts.sh" ]]; then
        log "Procesando variables en Chart Helm..."
        bash "$PROJECT_ROOT/scripts/process-charts.sh" --chart openwebui
    fi
}

# Función para crear namespace
create_namespace() {
    log "Verificando namespace $NAMESPACE..."
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        info "Namespace $NAMESPACE ya existe"
    else
        log "Creando namespace $NAMESPACE..."
        if [[ "$DRY_RUN" == "true" ]]; then
            info "[DRY RUN] Se crearía el namespace $NAMESPACE"
        else
            kubectl create namespace "$NAMESPACE"
            kubectl label namespace "$NAMESPACE" demo.minikube=true --overwrite
            kubectl label namespace "$NAMESPACE" name="$NAMESPACE" --overwrite
        fi
    fi
}

# Función para desplegar con Helm
deploy_with_helm() {
    log "Desplegando OpenWebUI con Helm..."
    
    local values_file="$PROJECT_ROOT/helm/openwebui/values-${ENVIRONMENT}.yaml"
    local helm_args=(
        "upgrade" "--install"
        "$RELEASE_NAME"
        "$PROJECT_ROOT/helm/openwebui"
        "--namespace" "$NAMESPACE"
        "--create-namespace"
        "--wait"
        "--timeout" "$WAIT_TIMEOUT"
    )
    
    # Agregar archivo de valores si existe
    if [[ -f "$values_file" ]]; then
        helm_args+=("--values" "$values_file")
        info "Usando archivo de valores: $values_file"
    else
        warn "Archivo de valores no encontrado: $values_file"
        helm_args+=("--values" "$PROJECT_ROOT/helm/openwebui/values.yaml")
    fi
    
    # Configuraciones específicas por entorno
    case "$ENVIRONMENT" in
        "dev")
            helm_args+=("--set" "replicaCount=1")
            helm_args+=("--set" "autoscaling.enabled=false")
            helm_args+=("--set" "networkPolicy.enabled=false")
            ;;
        "demo")
            helm_args+=("--set" "demo.enabled=true")
            helm_args+=("--set" "demo.minikube.optimized=true")
            ;;
        "prod")
            helm_args+=("--set" "replicaCount=2")
            helm_args+=("--set" "autoscaling.enabled=true")
            helm_args+=("--set" "networkPolicy.enabled=true")
            ;;
    esac
    
    # Agregar dry-run si es necesario
    if [[ "$DRY_RUN" == "true" ]]; then
        helm_args+=("--dry-run" "--debug")
    fi
    
    # Agregar verbose si es necesario
    if [[ "$VERBOSE" == "true" ]]; then
        helm_args+=("--debug")
    fi
    
    # Ejecutar Helm
    info "Ejecutando: helm ${helm_args[*]}"
    helm "${helm_args[@]}"
}

# Función para desplegar con kubectl
deploy_with_kubectl() {
    log "Desplegando OpenWebUI con kubectl..."
    
    local manifests_dir="$PROJECT_ROOT/k8s/openwebui"
    local kubectl_args=("apply" "-f" "$manifests_dir")
    
    # Agregar dry-run si es necesario
    if [[ "$DRY_RUN" == "true" ]]; then
        kubectl_args+=("--dry-run=client")
    fi
    
    # Ejecutar kubectl
    info "Ejecutando: kubectl ${kubectl_args[*]}"
    kubectl "${kubectl_args[@]}"
    
    # Esperar a que esté listo si no es dry-run
    if [[ "$DRY_RUN" == "false" ]]; then
        log "Esperando a que OpenWebUI esté listo..."
        kubectl wait --for=condition=available deployment/openwebui \
            --namespace="$NAMESPACE" \
            --timeout="$WAIT_TIMEOUT"
    fi
}

# Función para verificar despliegue
verify_deployment() {
    if [[ "$DRY_RUN" == "true" ]]; then
        info "Verificación omitida en modo dry-run"
        return 0
    fi
    
    log "Verificando despliegue..."
    
    # Verificar pods
    local pods_ready
    pods_ready=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=openwebui --no-headers | grep -c "Running" || echo "0")
    
    if [[ "$pods_ready" -gt 0 ]]; then
        info "✓ $pods_ready pod(s) de OpenWebUI ejecutándose"
    else
        error "✗ No hay pods de OpenWebUI ejecutándose"
        return 1
    fi
    
    # Verificar servicios
    if kubectl get service -n "$NAMESPACE" openwebui &> /dev/null; then
        info "✓ Servicio de OpenWebUI creado"
    else
        error "✗ Servicio de OpenWebUI no encontrado"
        return 1
    fi
    
    # Verificar ingress si está habilitado
    if kubectl get ingress -n "$NAMESPACE" openwebui &> /dev/null; then
        info "✓ Ingress de OpenWebUI creado"
        local ingress_host
        ingress_host=$(kubectl get ingress -n "$NAMESPACE" openwebui -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "")
        if [[ -n "$ingress_host" ]]; then
            info "  Host: $ingress_host"
        fi
    fi
    
    # Verificar PVCs
    local pvcs_bound
    pvcs_bound=$(kubectl get pvc -n "$NAMESPACE" -l app.kubernetes.io/name=openwebui --no-headers | grep -c "Bound" || echo "0")
    if [[ "$pvcs_bound" -gt 0 ]]; then
        info "✓ $pvcs_bound PVC(s) vinculados"
    fi
}

# Función para mostrar información de acceso
show_access_info() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    log "Información de acceso a OpenWebUI:"
    
    # Obtener información del servicio
    local service_type
    service_type=$(kubectl get service -n "$NAMESPACE" openwebui -o jsonpath='{.spec.type}' 2>/dev/null || echo "")
    
    case "$service_type" in
        "NodePort")
            local node_port
            node_port=$(kubectl get service -n "$NAMESPACE" openwebui -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
            if [[ -n "$node_port" ]]; then
                info "  NodePort: http://$(minikube ip):$node_port"
            fi
            ;;
        "LoadBalancer")
            local external_ip
            external_ip=$(kubectl get service -n "$NAMESPACE" openwebui -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
            if [[ -n "$external_ip" ]]; then
                info "  LoadBalancer: http://$external_ip:8080"
            fi
            ;;
        *)
            info "  Port Forward: kubectl port-forward -n $NAMESPACE service/openwebui 8080:8080"
            ;;
    esac
    
    # Información de Ingress
    if kubectl get ingress -n "$NAMESPACE" openwebui &> /dev/null; then
        local ingress_host
        ingress_host=$(kubectl get ingress -n "$NAMESPACE" openwebui -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "")
        if [[ -n "$ingress_host" ]]; then
            info "  Ingress: http://$ingress_host"
            info "  Agregar a /etc/hosts: $(minikube ip) $ingress_host"
        fi
    fi
    
    # Información de credenciales por defecto
    if [[ "$ENVIRONMENT" == "demo" ]]; then
        info "Credenciales por defecto:"
        info "  Email: demo@example.com"
        info "  Password: demo123"
    fi
}

# Función para limpiar en caso de error
cleanup_on_error() {
    if [[ "$FORCE" == "true" ]] && [[ "$DRY_RUN" == "false" ]]; then
        warn "Limpiando despliegue fallido..."
        if [[ "$DEPLOYMENT_METHOD" == "helm" ]]; then
            helm uninstall "$RELEASE_NAME" --namespace "$NAMESPACE" || true
        else
            kubectl delete -f "$PROJECT_ROOT/k8s/openwebui" --ignore-not-found=true || true
        fi
    fi
}

# Función principal
main() {
    log "Iniciando despliegue de OpenWebUI"
    info "Configuración:"
    info "  Environment: $ENVIRONMENT"
    info "  Method: $DEPLOYMENT_METHOD"
    info "  Namespace: $NAMESPACE"
    info "  Release: $RELEASE_NAME"
    info "  Dry Run: $DRY_RUN"
    
    # Trap para cleanup en caso de error
    trap cleanup_on_error ERR
    
    # Ejecutar pasos
    check_prerequisites
    process_environment_variables
    create_namespace
    
    # Desplegar según el método
    case "$DEPLOYMENT_METHOD" in
        "helm")
            deploy_with_helm
            ;;
        "kubectl")
            deploy_with_kubectl
            ;;
    esac
    
    # Verificar y mostrar información
    verify_deployment
    show_access_info
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "Dry run completado. No se realizaron cambios."
    else
        log "✓ Despliegue de OpenWebUI completado exitosamente"
    fi
}

# Ejecutar función principal
main "$@"
