#!/bin/bash

# =============================================================================
# Docker Push Script - DockerHub Registry (edissonz8809/iaops)
# =============================================================================
# Script para hacer push de imágenes Docker a DockerHub con validaciones
# Uso: ./scripts/docker-push.sh [all|backstage|openwebui|postgresql] [--force]

set -euo pipefail

# =============================================================================
# CONFIGURACIÓN
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_REGISTRY="edissonz8809/iaops"
DEMO_TAG="demo-latest"
DOCKERHUB_USERNAME="edissonz8809"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# FUNCIONES AUXILIARES
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

show_usage() {
    cat << EOF
Docker Push Script para DockerHub

USAGE:
    $0 [COMPONENT] [OPTIONS]

COMPONENTS:
    all         Push de todas las imágenes (default)
    backstage   Push solo imagen de Backstage
    openwebui   Push solo imagen de OpenWebUI
    postgresql  Push solo imagen de PostgreSQL
    jenkins     Push solo imagen de Jenkins
    argocd      Push solo imagen de ArgoCD

OPTIONS:
    --force     Forzar push sin validaciones adicionales
    --help      Mostrar esta ayuda

EXAMPLES:
    $0                    # Push de todas las imágenes
    $0 backstage         # Push solo de Backstage
    $0 all --force       # Push forzado de todas las imágenes

REGISTRY: $DOCKER_REGISTRY
USERNAME: $DOCKERHUB_USERNAME
TAG: $DEMO_TAG

PREREQUISITOS:
    - Docker login realizado: docker login
    - Imágenes construidas localmente
    - Acceso de escritura al registry $DOCKERHUB_USERNAME
EOF
}

check_prerequisites() {
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker no está instalado o no está en el PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon no está ejecutándose"
        exit 1
    fi
    
    # Verificar login de Docker
    if ! docker system info | grep -q "Username: $DOCKERHUB_USERNAME" 2>/dev/null; then
        log_warning "No estás logueado en DockerHub como $DOCKERHUB_USERNAME"
        log_info "Ejecuta: docker login"
        
        if [[ "${FORCE_PUSH:-false}" != "true" ]]; then
            read -p "¿Continuar de todas formas? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Push cancelado por el usuario"
                exit 0
            fi
        fi
    fi
}

check_image_exists() {
    local image_name=$1
    
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image_name}$"; then
        return 0
    else
        return 1
    fi
}

get_image_info() {
    local image_name=$1
    
    log_info "Información de imagen: $image_name"
    
    # Tamaño de imagen
    local size=$(docker images --format "{{.Size}}" "$image_name" 2>/dev/null || echo "unknown")
    log_info "  Tamaño: $size"
    
    # Fecha de creación
    local created=$(docker images --format "{{.CreatedAt}}" "$image_name" 2>/dev/null || echo "unknown")
    log_info "  Creada: $created"
    
    # Labels de demo
    local labels=$(docker inspect --format='{{range $k, $v := .Config.Labels}}{{if eq $k "demo.minikube"}}{{$k}}={{$v}} {{end}}{{end}}' "$image_name" 2>/dev/null || echo "")
    if [[ -n "$labels" ]]; then
        log_info "  Labels: $labels"
    fi
}

push_image() {
    local component=$1
    local image_name="${DOCKER_REGISTRY}/${component}:${DEMO_TAG}"
    
    log_info "=== Procesando imagen: $component ==="
    
    # Verificar que la imagen existe localmente
    if ! check_image_exists "$image_name"; then
        log_error "Imagen no encontrada localmente: $image_name"
        log_info "Ejecuta primero: ./scripts/docker-build.sh $component"
        return 1
    fi
    
    # Mostrar información de la imagen
    get_image_info "$image_name"
    
    # Confirmar push si no es forzado
    if [[ "${FORCE_PUSH:-false}" != "true" ]]; then
        echo
        read -p "¿Hacer push de $image_name? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Push de $component cancelado por el usuario"
            return 0
        fi
    fi
    
    # Realizar push
    log_info "Haciendo push de: $image_name"
    
    if docker push "$image_name"; then
        log_success "Push exitoso: $image_name"
        
        # Mostrar URL de DockerHub
        local dockerhub_url="https://hub.docker.com/r/${DOCKER_REGISTRY}/${component}/tags"
        log_info "Ver en DockerHub: $dockerhub_url"
        
        return 0
    else
        log_error "Error en push: $image_name"
        return 1
    fi
}

push_all_images() {
    local components=("postgresql" "backstage" "openwebui" "jenkins" "argocd")
    local pushed_images=()
    local failed_pushes=()
    
    log_info "=== Push de todas las imágenes ==="
    
    for component in "${components[@]}"; do
        echo
        if push_image "$component"; then
            pushed_images+=("$component")
        else
            failed_pushes+=("$component")
        fi
    done
    
    # Resumen
    echo
    log_info "=== Resumen del Push ==="
    
    if [[ ${#pushed_images[@]} -gt 0 ]]; then
        log_success "Imágenes enviadas exitosamente:"
        for img in "${pushed_images[@]}"; do
            echo "  ✓ ${DOCKER_REGISTRY}/${img}:${DEMO_TAG}"
        done
    fi
    
    if [[ ${#failed_pushes[@]} -gt 0 ]]; then
        log_error "Imágenes que fallaron:"
        for img in "${failed_pushes[@]}"; do
            echo "  ✗ ${DOCKER_REGISTRY}/${img}:${DEMO_TAG}"
        done
        return 1
    fi
    
    return 0
}

show_dockerhub_info() {
    cat << EOF

=== Información de DockerHub ===
Registry: $DOCKER_REGISTRY
Username: $DOCKERHUB_USERNAME

URLs de repositorios:
  • Backstage:   https://hub.docker.com/r/${DOCKER_REGISTRY}/backstage
  • OpenWebUI:   https://hub.docker.com/r/${DOCKER_REGISTRY}/openwebui
  • PostgreSQL:  https://hub.docker.com/r/${DOCKER_REGISTRY}/postgresql
  • Jenkins:     https://hub.docker.com/r/${DOCKER_REGISTRY}/jenkins
  • ArgoCD:      https://hub.docker.com/r/${DOCKER_REGISTRY}/argocd

Comandos para usar las imágenes:
  docker pull ${DOCKER_REGISTRY}/backstage:${DEMO_TAG}
  docker pull ${DOCKER_REGISTRY}/openwebui:${DEMO_TAG}
  docker pull ${DOCKER_REGISTRY}/postgresql:${DEMO_TAG}
  docker pull ${DOCKER_REGISTRY}/jenkins:${DEMO_TAG}
  docker pull ${DOCKER_REGISTRY}/argocd:${DEMO_TAG}

EOF
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================
main() {
    local component="${1:-all}"
    
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_PUSH=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            all|backstage|openwebui|postgresql|jenkins|argocd)
                component=$1
                shift
                ;;
            *)
                log_error "Argumento desconocido: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Verificar prerequisitos
    check_prerequisites
    
    # Cambiar al directorio del proyecto
    cd "$PROJECT_ROOT"
    
    log_info "=== Iniciando push a DockerHub ==="
    log_info "Componente: $component"
    log_info "Registry: $DOCKER_REGISTRY"
    log_info "Tag: $DEMO_TAG"
    log_info "Force: ${FORCE_PUSH:-false}"
    echo
    
    # Ejecutar push según componente
    case $component in
        "all")
            if push_all_images; then
                log_success "Push de todas las imágenes completado exitosamente!"
            else
                log_error "Algunos pushes fallaron"
                exit 1
            fi
            ;;
        "backstage"|"openwebui"|"postgresql"|"jenkins"|"argocd")
            if push_image "$component"; then
                log_success "Push de $component completado exitosamente!"
            else
                log_error "Push de $component falló"
                exit 1
            fi
            ;;
        *)
            log_error "Componente desconocido: $component"
            show_usage
            exit 1
            ;;
    esac
    
    # Mostrar información de DockerHub
    show_dockerhub_info
    
    log_success "¡Push completado exitosamente!"
}

# Ejecutar función main con todos los argumentos
main "$@"
