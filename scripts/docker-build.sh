#!/bin/bash

# =============================================================================
# Docker Build Script - Optimizado para Demo Minikube
# =============================================================================
# Script para construir todas las imágenes Docker con optimizaciones multi-stage
# Uso: ./scripts/docker-build.sh [all|backstage|openwebui|postgresql] [--push]

set -euo pipefail

# =============================================================================
# CONFIGURACIÓN
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_REGISTRY="edissonz8809/iaops"
DEMO_TAG="demo-latest"
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

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
Docker Build Script para Demo Minikube

USAGE:
    $0 [COMPONENT] [OPTIONS]

COMPONENTS:
    all         Construir todas las imágenes (default)
    backstage   Construir solo imagen de Backstage
    openwebui   Construir solo imagen de OpenWebUI
    postgresql  Construir solo imagen de PostgreSQL
    jenkins     Construir solo imagen de Jenkins
    argocd      Construir solo imagen de ArgoCD

OPTIONS:
    --push      Push de imágenes a DockerHub después del build
    --no-cache  Construir sin usar cache de Docker
    --help      Mostrar esta ayuda

EXAMPLES:
    $0                          # Construir todas las imágenes
    $0 backstage               # Construir solo Backstage
    $0 all --push             # Construir todas y hacer push
    $0 jenkins --no-cache     # Construir Jenkins sin cache

REGISTRY: $DOCKER_REGISTRY
TAG: $DEMO_TAG
EOF
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker no está instalado o no está en el PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon no está ejecutándose"
        exit 1
    fi
}

build_image() {
    local component=$1
    local dockerfile_path=$2
    local context_path=$3
    local image_name="${DOCKER_REGISTRY}/${component}:${DEMO_TAG}"
    
    log_info "Construyendo imagen: $image_name"
    log_info "Dockerfile: $dockerfile_path"
    log_info "Context: $context_path"
    
    # Argumentos de build comunes
    local build_args=(
        --file "$dockerfile_path"
        --tag "$image_name"
        --label "build.date=$BUILD_DATE"
        --label "build.git-commit=$GIT_COMMIT"
        --label "build.component=$component"
        --label "build.registry=$DOCKER_REGISTRY"
        --label "demo.minikube=true"
    )
    
    # Agregar --no-cache si se especificó
    if [[ "${NO_CACHE:-false}" == "true" ]]; then
        build_args+=(--no-cache)
    fi
    
    # Construir imagen
    if docker build "${build_args[@]}" "$context_path"; then
        log_success "Imagen construida exitosamente: $image_name"
        
        # Mostrar información de la imagen
        local image_size=$(docker images --format "table {{.Size}}" "$image_name" | tail -n 1)
        log_info "Tamaño de imagen: $image_size"
        
        return 0
    else
        log_error "Error construyendo imagen: $image_name"
        return 1
    fi
}

push_image() {
    local component=$1
    local image_name="${DOCKER_REGISTRY}/${component}:${DEMO_TAG}"
    
    log_info "Haciendo push de imagen: $image_name"
    
    if docker push "$image_name"; then
        log_success "Push exitoso: $image_name"
        return 0
    else
        log_error "Error en push: $image_name"
        return 1
    fi
}

build_backstage() {
    log_info "=== Construyendo Backstage ==="
    build_image "backstage" \
        "$PROJECT_ROOT/applications/backstage/Dockerfile" \
        "$PROJECT_ROOT/applications/backstage"
}

build_openwebui() {
    log_info "=== Construyendo OpenWebUI ==="
    build_image "openwebui" \
        "$PROJECT_ROOT/applications/openwebui/Dockerfile" \
        "$PROJECT_ROOT/applications/openwebui"
}

build_jenkins() {
    log_info "=== Construyendo Jenkins ==="
    build_image "jenkins" \
        "$PROJECT_ROOT/applications/jenkins/Dockerfile" \
        "$PROJECT_ROOT/applications/jenkins"
}

build_argocd() {
    log_info "=== Construyendo ArgoCD ==="
    build_image "argocd" \
        "$PROJECT_ROOT/applications/argocd/Dockerfile" \
        "$PROJECT_ROOT/applications/argocd"
}

build_postgresql() {
    log_info "=== Construyendo PostgreSQL ==="
    build_image "postgresql" \
        "$PROJECT_ROOT/applications/postgresql/Dockerfile" \
        "$PROJECT_ROOT/applications/postgresql"
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================
main() {
    local component="${1:-all}"
    local push_images=false
    
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --push)
                push_images=true
                shift
                ;;
            --no-cache)
                NO_CACHE=true
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
    
    # Verificar Docker
    check_docker
    
    # Cambiar al directorio del proyecto
    cd "$PROJECT_ROOT"
    
    log_info "=== Iniciando build de imágenes Docker ==="
    log_info "Componente: $component"
    log_info "Registry: $DOCKER_REGISTRY"
    log_info "Tag: $DEMO_TAG"
    log_info "Push: $push_images"
    log_info "No Cache: ${NO_CACHE:-false}"
    echo
    
    # Variables para tracking
    local built_images=()
    local failed_builds=()
    
    # Construir según componente especificado
    case $component in
        "all")
            log_info "Construyendo todas las imágenes..."
            
            if build_postgresql; then
                built_images+=("postgresql")
            else
                failed_builds+=("postgresql")
            fi
            
            if build_backstage; then
                built_images+=("backstage")
            else
                failed_builds+=("backstage")
            fi
            
            if build_openwebui; then
                built_images+=("openwebui")
            else
                failed_builds+=("openwebui")
            fi
            
            if build_jenkins; then
                built_images+=("jenkins")
            else
                failed_builds+=("jenkins")
            fi
            
            if build_argocd; then
                built_images+=("argocd")
            else
                failed_builds+=("argocd")
            fi
            ;;
        "backstage")
            if build_backstage; then
                built_images+=("backstage")
            else
                failed_builds+=("backstage")
            fi
            ;;
        "openwebui")
            if build_openwebui; then
                built_images+=("openwebui")
            else
                failed_builds+=("openwebui")
            fi
            ;;
        "postgresql")
            if build_postgresql; then
                built_images+=("postgresql")
            else
                failed_builds+=("postgresql")
            fi
            ;;
        "jenkins")
            if build_jenkins; then
                built_images+=("jenkins")
            else
                failed_builds+=("jenkins")
            fi
            ;;
        "argocd")
            if build_argocd; then
                built_images+=("argocd")
            else
                failed_builds+=("argocd")
            fi
            ;;
        *)
            log_error "Componente desconocido: $component"
            show_usage
            exit 1
            ;;
    esac
    
    # Push de imágenes si se solicitó
    if [[ "$push_images" == "true" ]] && [[ ${#built_images[@]} -gt 0 ]]; then
        echo
        log_info "=== Haciendo push de imágenes ==="
        
        for img in "${built_images[@]}"; do
            if ! push_image "$img"; then
                log_warning "Error en push de $img, continuando..."
            fi
        done
    fi
    
    # Resumen final
    echo
    log_info "=== Resumen del Build ==="
    
    if [[ ${#built_images[@]} -gt 0 ]]; then
        log_success "Imágenes construidas exitosamente:"
        for img in "${built_images[@]}"; do
            echo "  ✓ ${DOCKER_REGISTRY}/${img}:${DEMO_TAG}"
        done
    fi
    
    if [[ ${#failed_builds[@]} -gt 0 ]]; then
        log_error "Imágenes que fallaron:"
        for img in "${failed_builds[@]}"; do
            echo "  ✗ ${DOCKER_REGISTRY}/${img}:${DEMO_TAG}"
        done
        exit 1
    fi
    
    log_success "Build completado exitosamente!"
    
    # Mostrar comandos útiles
    echo
    log_info "=== Comandos útiles ==="
    echo "Ver imágenes construidas:"
    echo "  docker images ${DOCKER_REGISTRY}/*:${DEMO_TAG}"
    echo
    echo "Ejecutar contenedores individualmente:"
    for img in "${built_images[@]}"; do
        case $img in
            "backstage")
                echo "  docker run -p 7007:7007 ${DOCKER_REGISTRY}/${img}:${DEMO_TAG}"
                ;;
            "openwebui")
                echo "  docker run -p 8080:8080 ${DOCKER_REGISTRY}/${img}:${DEMO_TAG}"
                ;;
            "postgresql")
                echo "  docker run -p 5432:5432 -e POSTGRES_PASSWORD=demo-password ${DOCKER_REGISTRY}/${img}:${DEMO_TAG}"
                ;;
            "jenkins")
                echo "  docker run -p 8080:8080 ${DOCKER_REGISTRY}/${img}:${DEMO_TAG}"
                ;;
            "argocd")
                echo "  docker run -p 8080:8080 ${DOCKER_REGISTRY}/${img}:${DEMO_TAG}"
                ;;
        esac
    done
    echo
    echo "Desplegar en Minikube:"
    echo "  make deploy-demo"
}

# Ejecutar función main con todos los argumentos
main "$@"
