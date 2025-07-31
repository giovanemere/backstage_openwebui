#!/bin/bash

# =============================================================================
# Script de Limpieza para Minikube Demo
# =============================================================================
# Limpia recursos de Minikube y Docker para liberar espacio

set -euo pipefail

# Colores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuración
readonly CLUSTER_NAME="backstage-demo"

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
║                    🧹 LIMPIEZA - MINIKUBE DEMO                              ║
║                                                                              ║
║                        Liberación de Recursos del Sistema                   ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
}

show_usage() {
    cat << EOF
Script de Limpieza para Minikube Demo

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --all           Limpieza completa (cluster + Docker + cache)
    --cluster-only  Solo eliminar cluster Minikube
    --docker-only   Solo limpiar Docker
    --cache-only    Solo limpiar cache y archivos temporales
    --dry-run       Mostrar qué se eliminaría sin ejecutar
    --force         No pedir confirmación
    --help          Mostrar esta ayuda

EXAMPLES:
    $0                      # Limpieza interactiva
    $0 --all --force        # Limpieza completa sin confirmación
    $0 --cluster-only       # Solo eliminar cluster
    $0 --dry-run            # Ver qué se eliminaría

RECURSOS QUE LIMPIA:
    • Cluster Minikube '$CLUSTER_NAME'
    • Imágenes Docker del demo
    • Contenedores Docker detenidos
    • Volúmenes Docker huérfanos
    • Cache de Minikube
    • Archivos temporales del proyecto

ESPACIO ESTIMADO A LIBERAR: 2-5GB
EOF
}

calculate_space_usage() {
    log_step "Calculando Uso de Espacio"
    
    local total_space=0
    
    # Espacio de Minikube
    if minikube status -p "$CLUSTER_NAME" &> /dev/null; then
        local minikube_space
        minikube_space=$(minikube ssh -p "$CLUSTER_NAME" "df -h / | tail -1 | awk '{print \$3}'" 2>/dev/null | sed 's/G//' || echo "0")
        log_info "Espacio usado por cluster Minikube: ${minikube_space}GB"
        total_space=$((total_space + minikube_space))
    fi
    
    # Espacio de imágenes Docker
    local docker_images_space
    docker_images_space=$(docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep "edissonz8809/iaops" | awk '{sum += $2} END {print sum/1024/1024/1024}' 2>/dev/null || echo "0")
    log_info "Espacio usado por imágenes del demo: ${docker_images_space}GB"
    
    # Espacio de contenedores
    local containers_space
    containers_space=$(docker system df --format "table {{.Type}}\t{{.Size}}" | grep "Containers" | awk '{print $2}' | sed 's/GB//' 2>/dev/null || echo "0")
    log_info "Espacio usado por contenedores: ${containers_space}GB"
    
    # Espacio de volúmenes
    local volumes_space
    volumes_space=$(docker system df --format "table {{.Type}}\t{{.Size}}" | grep "Local Volumes" | awk '{print $3}' | sed 's/GB//' 2>/dev/null || echo "0")
    log_info "Espacio usado por volúmenes: ${volumes_space}GB"
    
    log_info "Espacio total estimado a liberar: ~${total_space}GB"
}

cleanup_minikube_cluster() {
    log_step "Limpiando Cluster Minikube"
    
    if minikube status -p "$CLUSTER_NAME" &> /dev/null; then
        log_info "Deteniendo cluster '$CLUSTER_NAME'..."
        minikube stop -p "$CLUSTER_NAME" || true
        
        log_info "Eliminando cluster '$CLUSTER_NAME'..."
        minikube delete -p "$CLUSTER_NAME" --purge
        
        log_success "Cluster Minikube eliminado"
    else
        log_info "No hay cluster '$CLUSTER_NAME' para eliminar"
    fi
    
    # Limpiar perfiles huérfanos
    log_info "Limpiando perfiles huérfanos de Minikube..."
    minikube delete --all --purge 2>/dev/null || true
}

cleanup_docker_images() {
    log_step "Limpiando Imágenes Docker del Demo"
    
    # Eliminar imágenes del demo
    local demo_images
    demo_images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "edissonz8809/iaops" || true)
    
    if [[ -n "$demo_images" ]]; then
        log_info "Eliminando imágenes del demo..."
        echo "$demo_images" | while read -r image; do
            log_info "Eliminando imagen: $image"
            docker rmi "$image" --force 2>/dev/null || true
        done
        log_success "Imágenes del demo eliminadas"
    else
        log_info "No hay imágenes del demo para eliminar"
    fi
    
    # Eliminar imágenes huérfanas
    log_info "Eliminando imágenes huérfanas..."
    docker image prune -f
    
    # Eliminar imágenes no utilizadas
    log_info "Eliminando imágenes no utilizadas..."
    docker image prune -a -f
}

cleanup_docker_containers() {
    log_step "Limpiando Contenedores Docker"
    
    # Detener contenedores relacionados con el demo
    local demo_containers
    demo_containers=$(docker ps -a --format "{{.Names}}" | grep -E "(backstage|openwebui|postgresql|jenkins|argocd)" || true)
    
    if [[ -n "$demo_containers" ]]; then
        log_info "Deteniendo contenedores del demo..."
        echo "$demo_containers" | while read -r container; do
            log_info "Deteniendo contenedor: $container"
            docker stop "$container" 2>/dev/null || true
            docker rm "$container" 2>/dev/null || true
        done
    fi
    
    # Limpiar contenedores detenidos
    log_info "Eliminando contenedores detenidos..."
    docker container prune -f
    
    log_success "Contenedores Docker limpiados"
}

cleanup_docker_volumes() {
    log_step "Limpiando Volúmenes Docker"
    
    # Eliminar volúmenes huérfanos
    log_info "Eliminando volúmenes huérfanos..."
    docker volume prune -f
    
    # Eliminar volúmenes específicos del demo
    local demo_volumes
    demo_volumes=$(docker volume ls --format "{{.Name}}" | grep -E "(backstage|openwebui|postgresql|jenkins|argocd)" || true)
    
    if [[ -n "$demo_volumes" ]]; then
        log_info "Eliminando volúmenes del demo..."
        echo "$demo_volumes" | while read -r volume; do
            log_info "Eliminando volumen: $volume"
            docker volume rm "$volume" 2>/dev/null || true
        done
    fi
    
    log_success "Volúmenes Docker limpiados"
}

cleanup_docker_networks() {
    log_step "Limpiando Redes Docker"
    
    # Eliminar redes huérfanas
    log_info "Eliminando redes huérfanas..."
    docker network prune -f
    
    log_success "Redes Docker limpiadas"
}

cleanup_cache_files() {
    log_step "Limpiando Archivos de Cache"
    
    # Cache de Minikube
    local minikube_cache="$HOME/.minikube/cache"
    if [[ -d "$minikube_cache" ]]; then
        log_info "Limpiando cache de Minikube..."
        rm -rf "$minikube_cache"/* 2>/dev/null || true
        log_success "Cache de Minikube limpiado"
    fi
    
    # Cache de Docker
    log_info "Limpiando cache de Docker..."
    docker system prune -f --volumes
    
    # Cache de kubectl
    local kubectl_cache="$HOME/.kube/cache"
    if [[ -d "$kubectl_cache" ]]; then
        log_info "Limpiando cache de kubectl..."
        rm -rf "$kubectl_cache"/* 2>/dev/null || true
        log_success "Cache de kubectl limpiado"
    fi
    
    # Archivos temporales del proyecto
    local project_root
    project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    log_info "Limpiando archivos temporales del proyecto..."
    find "$project_root" -name "*.tmp" -delete 2>/dev/null || true
    find "$project_root" -name "*.log" -delete 2>/dev/null || true
    find "$project_root" -name ".DS_Store" -delete 2>/dev/null || true
    
    log_success "Archivos de cache limpiados"
}

show_cleanup_summary() {
    log_step "Resumen de Limpieza"
    
    echo
    log_success "🎉 Limpieza completada exitosamente!"
    echo
    
    # Mostrar espacio liberado
    log_info "Verificando espacio liberado..."
    
    # Verificar que el cluster fue eliminado
    if ! minikube status -p "$CLUSTER_NAME" &> /dev/null; then
        echo -e "  ✅ Cluster Minikube eliminado"
    else
        echo -e "  ⚠️  Cluster Minikube aún existe"
    fi
    
    # Verificar imágenes Docker
    local remaining_images
    remaining_images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "edissonz8809/iaops" | wc -l || echo "0")
    echo -e "  ✅ Imágenes del demo eliminadas (${remaining_images} restantes)"
    
    # Verificar contenedores
    local remaining_containers
    remaining_containers=$(docker ps -a --format "{{.Names}}" | grep -E "(backstage|openwebui|postgresql|jenkins|argocd)" | wc -l || echo "0")
    echo -e "  ✅ Contenedores del demo eliminados (${remaining_containers} restantes)"
    
    echo
    cat << EOF
$(echo -e "${CYAN}Comandos para verificar limpieza:${NC}")
  # Verificar clusters Minikube
  minikube profile list
  
  # Verificar imágenes Docker
  docker images | grep edissonz8809
  
  # Verificar uso de espacio Docker
  docker system df
  
  # Verificar contenedores
  docker ps -a

$(echo -e "${CYAN}Para recrear el entorno:${NC}")
  # Verificar recursos del sistema
  ./scripts/minikube/check-resources.sh
  
  # Configurar nuevo cluster
  ./scripts/minikube/setup-minikube.sh
  
  # Construir imágenes Docker
  make docker-build-all

$(echo -e "${GREEN}¡Sistema limpio y listo para nuevo setup!${NC}")
EOF
}

dry_run_cleanup() {
    log_step "Simulación de Limpieza (Dry Run)"
    
    echo -e "${YELLOW}Los siguientes recursos serían eliminados:${NC}"
    echo
    
    # Cluster Minikube
    if minikube status -p "$CLUSTER_NAME" &> /dev/null; then
        echo -e "  🗑️  Cluster Minikube: $CLUSTER_NAME"
    fi
    
    # Imágenes Docker
    local demo_images
    demo_images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "edissonz8809/iaops" || true)
    if [[ -n "$demo_images" ]]; then
        echo -e "  🗑️  Imágenes Docker del demo:"
        echo "$demo_images" | sed 's/^/    /'
    fi
    
    # Contenedores
    local demo_containers
    demo_containers=$(docker ps -a --format "{{.Names}}" | grep -E "(backstage|openwebui|postgresql|jenkins|argocd)" || true)
    if [[ -n "$demo_containers" ]]; then
        echo -e "  🗑️  Contenedores del demo:"
        echo "$demo_containers" | sed 's/^/    /'
    fi
    
    # Volúmenes
    local demo_volumes
    demo_volumes=$(docker volume ls --format "{{.Name}}" | grep -E "(backstage|openwebui|postgresql|jenkins|argocd)" || true)
    if [[ -n "$demo_volumes" ]]; then
        echo -e "  🗑️  Volúmenes del demo:"
        echo "$demo_volumes" | sed 's/^/    /'
    fi
    
    # Cache
    echo -e "  🗑️  Archivos de cache:"
    echo "    ~/.minikube/cache/*"
    echo "    ~/.kube/cache/*"
    echo "    Archivos temporales del proyecto"
    
    echo
    log_info "Para ejecutar la limpieza real, ejecuta sin --dry-run"
}

main() {
    local cleanup_all=false
    local cluster_only=false
    local docker_only=false
    local cache_only=false
    local dry_run=false
    local force=false
    
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                cleanup_all=true
                shift
                ;;
            --cluster-only)
                cluster_only=true
                shift
                ;;
            --docker-only)
                docker_only=true
                shift
                ;;
            --cache-only)
                cache_only=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force=true
                shift
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
    
    show_banner
    echo
    
    # Dry run
    if [[ "$dry_run" == true ]]; then
        dry_run_cleanup
        exit 0
    fi
    
    # Calcular espacio
    calculate_space_usage
    
    # Confirmación
    if [[ "$force" != true ]]; then
        echo
        log_warning "Esta operación eliminará recursos del sistema"
        read -p "¿Continuar con la limpieza? (y/N): " -n 1 -r
        echo
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Operación cancelada"
            exit 0
        fi
    fi
    
    # Ejecutar limpieza según opciones
    local start_time
    start_time=$(date +%s)
    
    if [[ "$cleanup_all" == true ]]; then
        cleanup_minikube_cluster
        cleanup_docker_images
        cleanup_docker_containers
        cleanup_docker_volumes
        cleanup_docker_networks
        cleanup_cache_files
    elif [[ "$cluster_only" == true ]]; then
        cleanup_minikube_cluster
    elif [[ "$docker_only" == true ]]; then
        cleanup_docker_images
        cleanup_docker_containers
        cleanup_docker_volumes
        cleanup_docker_networks
    elif [[ "$cache_only" == true ]]; then
        cleanup_cache_files
    else
        # Limpieza interactiva
        log_info "Selecciona qué limpiar:"
        echo "1) Solo cluster Minikube"
        echo "2) Solo recursos Docker"
        echo "3) Solo cache y archivos temporales"
        echo "4) Todo (cluster + Docker + cache)"
        echo "5) Cancelar"
        
        read -p "Opción (1-5): " -n 1 -r
        echo
        
        case $REPLY in
            1)
                cleanup_minikube_cluster
                ;;
            2)
                cleanup_docker_images
                cleanup_docker_containers
                cleanup_docker_volumes
                cleanup_docker_networks
                ;;
            3)
                cleanup_cache_files
                ;;
            4)
                cleanup_minikube_cluster
                cleanup_docker_images
                cleanup_docker_containers
                cleanup_docker_volumes
                cleanup_docker_networks
                cleanup_cache_files
                ;;
            5)
                log_info "Operación cancelada"
                exit 0
                ;;
            *)
                log_error "Opción inválida"
                exit 1
                ;;
        esac
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    show_cleanup_summary
    
    echo
    log_success "Limpieza completada en ${duration} segundos"
}

# Ejecutar función principal si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
