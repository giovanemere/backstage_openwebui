#!/bin/bash

# =============================================================================
# Setup Automatizado de Minikube para Demo Backstage + OpenWebUI
# =============================================================================
# Este script configura un entorno Minikube optimizado para el demo
# Recursos requeridos: 4GB RAM, 2 CPU, 20GB disco
# Tiempo estimado: 5-8 minutos

set -euo pipefail

# =============================================================================
# CONFIGURACIÓN Y VARIABLES
# =============================================================================

# Colores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Configuración del cluster
readonly CLUSTER_NAME="backstage-demo"
readonly KUBERNETES_VERSION="v1.28.3"
readonly DRIVER="docker"
readonly MEMORY="4096"
readonly CPUS="2"
readonly DISK_SIZE="20g"
readonly CONTAINER_RUNTIME="containerd"

# Configuración de addons
readonly REQUIRED_ADDONS=(
    "ingress"
    "dashboard"
    "metrics-server"
    "storage-provisioner"
    "default-storageclass"
)

# Configuración de namespaces
readonly DEMO_NAMESPACES=(
    "backstage-demo"
    "jenkins"
    "argocd"
    "monitoring"
)

# Directorio del proyecto
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly SCRIPTS_DIR="$PROJECT_ROOT/scripts"
readonly K8S_DIR="$PROJECT_ROOT/k8s"

# =============================================================================
# FUNCIONES DE UTILIDAD
# =============================================================================

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

log_step() {
    echo -e "\n${PURPLE}=== $1 ===${NC}"
}

show_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                    🚀 MINIKUBE SETUP - DEMO AUTOMATION                      ║
║                                                                              ║
║                        Backstage + OpenWebUI Demo                           ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
}

show_usage() {
    cat << EOF
Setup Automatizado de Minikube para Demo

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --clean         Limpiar cluster existente antes de crear
    --skip-addons   Omitir instalación de addons
    --skip-images   Omitir precarga de imágenes Docker
    --memory SIZE   Memoria para Minikube (default: ${MEMORY}Mi)
    --cpus NUM      CPUs para Minikube (default: ${CPUS})
    --driver NAME   Driver para Minikube (default: ${DRIVER})
    --help          Mostrar esta ayuda

EXAMPLES:
    $0                          # Setup estándar
    $0 --clean                  # Limpiar y recrear cluster
    $0 --memory 6144 --cpus 3   # Más recursos
    $0 --skip-images            # Setup rápido sin imágenes

RECURSOS REQUERIDOS:
    - RAM: ${MEMORY}Mi (mínimo 3GB disponible)
    - CPU: ${CPUS} cores (mínimo 2 cores)
    - Disco: ${DISK_SIZE} (mínimo 15GB disponible)
    - Docker: Ejecutándose y accesible

TIEMPO ESTIMADO: 5-8 minutos
EOF
}

# =============================================================================
# FUNCIONES DE VALIDACIÓN
# =============================================================================

check_prerequisites() {
    log_step "Verificando Prerequisitos"
    
    local missing_tools=()
    
    # Verificar herramientas requeridas
    local required_tools=("minikube" "kubectl" "docker" "helm")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        else
            log_info "✓ $tool encontrado: $(command -v "$tool")"
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Herramientas faltantes: ${missing_tools[*]}"
        log_error "Instala las herramientas faltantes antes de continuar"
        exit 1
    fi
    
    # Verificar Docker
    if ! docker info &> /dev/null; then
        log_error "Docker no está ejecutándose o no es accesible"
        log_error "Inicia Docker y asegúrate de tener permisos"
        exit 1
    fi
    
    # Verificar recursos del sistema
    check_system_resources
    
    log_success "Todos los prerequisitos verificados"
}

check_system_resources() {
    log_info "Verificando recursos del sistema..."
    
    # Verificar memoria disponible (Linux)
    if [[ -f /proc/meminfo ]]; then
        local available_memory_kb
        available_memory_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        local available_memory_mb=$((available_memory_kb / 1024))
        local required_memory_mb=$((MEMORY + 1024)) # +1GB para el sistema
        
        log_info "Memoria disponible: ${available_memory_mb}MB"
        log_info "Memoria requerida: ${required_memory_mb}MB"
        
        if [[ $available_memory_mb -lt $required_memory_mb ]]; then
            log_warning "Memoria disponible podría ser insuficiente"
            log_warning "Recomendado: Cerrar aplicaciones innecesarias"
        fi
    fi
    
    # Verificar espacio en disco
    local available_disk_gb
    available_disk_gb=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    local required_disk_gb=25
    
    log_info "Espacio disponible: ${available_disk_gb}GB"
    log_info "Espacio requerido: ${required_disk_gb}GB"
    
    if [[ $available_disk_gb -lt $required_disk_gb ]]; then
        log_warning "Espacio en disco podría ser insuficiente"
        log_warning "Recomendado: Liberar espacio en disco"
    fi
}

# =============================================================================
# FUNCIONES DE MINIKUBE
# =============================================================================

cleanup_existing_cluster() {
    log_step "Limpiando Cluster Existente"
    
    if minikube status -p "$CLUSTER_NAME" &> /dev/null; then
        log_info "Deteniendo cluster existente: $CLUSTER_NAME"
        minikube stop -p "$CLUSTER_NAME" || true
        
        log_info "Eliminando cluster existente: $CLUSTER_NAME"
        minikube delete -p "$CLUSTER_NAME" || true
        
        log_success "Cluster existente eliminado"
    else
        log_info "No hay cluster existente para limpiar"
    fi
}

create_minikube_cluster() {
    log_step "Creando Cluster Minikube"
    
    log_info "Configuración del cluster:"
    log_info "  Nombre: $CLUSTER_NAME"
    log_info "  Kubernetes: $KUBERNETES_VERSION"
    log_info "  Driver: $DRIVER"
    log_info "  Memoria: ${MEMORY}Mi"
    log_info "  CPUs: $CPUS"
    log_info "  Disco: $DISK_SIZE"
    log_info "  Runtime: $CONTAINER_RUNTIME"
    
    log_info "Iniciando creación del cluster..."
    
    minikube start \
        --profile="$CLUSTER_NAME" \
        --kubernetes-version="$KUBERNETES_VERSION" \
        --driver="$DRIVER" \
        --memory="$MEMORY" \
        --cpus="$CPUS" \
        --disk-size="$DISK_SIZE" \
        --container-runtime="$CONTAINER_RUNTIME" \
        --extra-config=kubelet.housekeeping-interval=10s \
        --extra-config=kubelet.max-pods=110 \
        --extra-config=controller-manager.horizontal-pod-autoscaler-upscale-delay=1m \
        --extra-config=controller-manager.horizontal-pod-autoscaler-downscale-delay=2m \
        --extra-config=controller-manager.horizontal-pod-autoscaler-sync-period=10s
    
    log_success "Cluster Minikube creado exitosamente"
    
    # Configurar kubectl context
    log_info "Configurando contexto kubectl..."
    minikube update-context -p "$CLUSTER_NAME"
    
    # Verificar cluster
    verify_cluster_health
}

verify_cluster_health() {
    log_info "Verificando salud del cluster..."
    
    # Esperar a que el cluster esté listo
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if kubectl get nodes --no-headers | grep -q "Ready"; then
            log_success "Cluster está listo"
            break
        fi
        
        log_info "Esperando cluster... (intento $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        log_error "Cluster no está listo después de $max_attempts intentos"
        exit 1
    fi
    
    # Mostrar información del cluster
    log_info "Información del cluster:"
    kubectl cluster-info
    kubectl get nodes -o wide
}

# =============================================================================
# FUNCIONES DE ADDONS
# =============================================================================

enable_minikube_addons() {
    log_step "Habilitando Addons de Minikube"
    
    for addon in "${REQUIRED_ADDONS[@]}"; do
        log_info "Habilitando addon: $addon"
        
        if minikube addons enable "$addon" -p "$CLUSTER_NAME"; then
            log_success "✓ $addon habilitado"
        else
            log_warning "⚠ Error habilitando $addon"
        fi
    done
    
    # Verificar addons
    log_info "Addons habilitados:"
    minikube addons list -p "$CLUSTER_NAME" | grep enabled
    
    # Esperar a que los addons estén listos
    wait_for_addons_ready
}

wait_for_addons_ready() {
    log_info "Esperando a que los addons estén listos..."
    
    # Esperar ingress controller
    log_info "Esperando Ingress Controller..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    # Esperar metrics server
    log_info "Esperando Metrics Server..."
    kubectl wait --namespace kube-system \
        --for=condition=ready pod \
        --selector=k8s-app=metrics-server \
        --timeout=300s
    
    log_success "Todos los addons están listos"
}

# =============================================================================
# FUNCIONES DE CONFIGURACIÓN
# =============================================================================

create_demo_namespaces() {
    log_step "Creando Namespaces para Demo"
    
    for namespace in "${DEMO_NAMESPACES[@]}"; do
        log_info "Creando namespace: $namespace"
        
        kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
        
        # Agregar labels para demo
        kubectl label namespace "$namespace" \
            demo.minikube=true \
            demo.component="$namespace" \
            --overwrite
        
        log_success "✓ Namespace $namespace creado"
    done
    
    log_info "Namespaces creados:"
    kubectl get namespaces -l demo.minikube=true
}

configure_storage_classes() {
    log_step "Configurando Storage Classes"
    
    # Verificar storage class por defecto
    local default_sc
    default_sc=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
    
    if [[ -n "$default_sc" ]]; then
        log_success "Storage class por defecto: $default_sc"
    else
        log_warning "No hay storage class por defecto configurado"
        
        # Configurar standard como default
        kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
        log_success "Storage class 'standard' configurado como default"
    fi
    
    # Mostrar storage classes disponibles
    log_info "Storage classes disponibles:"
    kubectl get storageclass
}

setup_resource_quotas() {
    log_step "Configurando Resource Quotas para Demo"
    
    # Resource quota para namespace backstage-demo
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: demo-resource-quota
  namespace: backstage-demo
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 3Gi
    limits.cpu: "3"
    limits.memory: 4Gi
    persistentvolumeclaims: "5"
    pods: "10"
    services: "10"
    secrets: "20"
    configmaps: "20"
EOF
    
    log_success "Resource quota configurado para backstage-demo"
    
    # Mostrar resource quotas
    kubectl get resourcequota -n backstage-demo
}

# =============================================================================
# FUNCIONES DE IMÁGENES DOCKER
# =============================================================================

preload_docker_images() {
    log_step "Precargando Imágenes Docker"
    
    local images=(
        "edissonz8809/iaops/backstage:demo-latest"
        "edissonz8809/iaops/openwebui:demo-latest"
        "edissonz8809/iaops/postgresql:demo-latest"
        "edissonz8809/iaops/jenkins:demo-latest"
        "edissonz8809/iaops/argocd:demo-latest"
    )
    
    log_info "Precargando ${#images[@]} imágenes Docker..."
    
    for image in "${images[@]}"; do
        log_info "Precargando: $image"
        
        # Pull imagen si no existe localmente
        if ! docker image inspect "$image" &> /dev/null; then
            log_info "Descargando imagen: $image"
            docker pull "$image" || {
                log_warning "No se pudo descargar $image, omitiendo..."
                continue
            }
        fi
        
        # Cargar imagen en Minikube
        log_info "Cargando en Minikube: $image"
        minikube image load "$image" -p "$CLUSTER_NAME" || {
            log_warning "No se pudo cargar $image en Minikube"
        }
    done
    
    log_success "Imágenes Docker precargadas"
    
    # Mostrar imágenes en Minikube
    log_info "Imágenes disponibles en Minikube:"
    minikube image ls -p "$CLUSTER_NAME" | grep "edissonz8809/iaops" || true
}

# =============================================================================
# FUNCIONES DE VALIDACIÓN FINAL
# =============================================================================

run_cluster_validation() {
    log_step "Validación Final del Cluster"
    
    # Test básico de conectividad
    log_info "Probando conectividad básica..."
    kubectl get nodes
    kubectl get pods --all-namespaces
    
    # Test de DNS
    log_info "Probando resolución DNS..."
    kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default || true
    
    # Test de storage
    log_info "Probando storage..."
    kubectl get storageclass
    kubectl get pv
    
    # Test de ingress
    log_info "Probando ingress controller..."
    kubectl get pods -n ingress-nginx
    
    log_success "Validación del cluster completada"
}

show_cluster_info() {
    log_step "Información del Cluster"
    
    echo
    log_info "🎉 Cluster Minikube configurado exitosamente!"
    echo
    
    # Información básica
    cat << EOF
$(echo -e "${CYAN}Información del Cluster:${NC}")
  Nombre: $CLUSTER_NAME
  Kubernetes: $(kubectl version --short --client | grep Client)
  Nodos: $(kubectl get nodes --no-headers | wc -l)
  Namespaces: $(kubectl get namespaces --no-headers | wc -l)
  
$(echo -e "${CYAN}Recursos Configurados:${NC}")
  Memoria: ${MEMORY}Mi
  CPUs: $CPUS
  Disco: $DISK_SIZE
  
$(echo -e "${CYAN}Addons Habilitados:${NC}")
$(minikube addons list -p "$CLUSTER_NAME" | grep enabled | sed 's/^/  /')

$(echo -e "${CYAN}Namespaces Demo:${NC}")
$(kubectl get namespaces -l demo.minikube=true --no-headers | awk '{print "  " $1}')

$(echo -e "${CYAN}Comandos Útiles:${NC}")
  # Acceder al dashboard
  minikube dashboard -p $CLUSTER_NAME
  
  # Ver logs del cluster
  minikube logs -p $CLUSTER_NAME
  
  # SSH al nodo
  minikube ssh -p $CLUSTER_NAME
  
  # Detener cluster
  minikube stop -p $CLUSTER_NAME
  
  # Eliminar cluster
  minikube delete -p $CLUSTER_NAME

$(echo -e "${CYAN}Próximos Pasos:${NC}")
  1. Desplegar aplicaciones: make k8s-deploy-all
  2. Configurar port-forwarding: make k8s-port-forward
  3. Acceder a las aplicaciones via browser
  
$(echo -e "${GREEN}¡Cluster listo para el demo!${NC}")
EOF
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================

main() {
    local clean_cluster=false
    local skip_addons=false
    local skip_images=false
    local custom_memory="$MEMORY"
    local custom_cpus="$CPUS"
    local custom_driver="$DRIVER"
    
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                clean_cluster=true
                shift
                ;;
            --skip-addons)
                skip_addons=true
                shift
                ;;
            --skip-images)
                skip_images=true
                shift
                ;;
            --memory)
                custom_memory="$2"
                shift 2
                ;;
            --cpus)
                custom_cpus="$2"
                shift 2
                ;;
            --driver)
                custom_driver="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Argumento desconocido: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Actualizar variables con valores personalizados
    MEMORY="$custom_memory"
    CPUS="$custom_cpus"
    DRIVER="$custom_driver"
    
    # Mostrar banner
    show_banner
    
    # Ejecutar setup
    local start_time
    start_time=$(date +%s)
    
    check_prerequisites
    
    if [[ "$clean_cluster" == true ]]; then
        cleanup_existing_cluster
    fi
    
    create_minikube_cluster
    
    if [[ "$skip_addons" != true ]]; then
        enable_minikube_addons
    fi
    
    create_demo_namespaces
    configure_storage_classes
    setup_resource_quotas
    
    if [[ "$skip_images" != true ]]; then
        preload_docker_images
    fi
    
    run_cluster_validation
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    show_cluster_info
    
    echo
    log_success "Setup completado en ${duration} segundos"
    log_success "Cluster '$CLUSTER_NAME' listo para usar!"
}

# Ejecutar función principal si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
