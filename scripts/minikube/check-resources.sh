#!/bin/bash

# =============================================================================
# Script de Verificación de Recursos para Minikube Demo
# =============================================================================
# Verifica que el sistema tenga recursos suficientes para ejecutar el demo

set -euo pipefail

# Colores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Requisitos mínimos
readonly MIN_MEMORY_GB=3
readonly MIN_DISK_GB=15
readonly MIN_CPUS=2
readonly RECOMMENDED_MEMORY_GB=6
readonly RECOMMENDED_DISK_GB=25
readonly RECOMMENDED_CPUS=4

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

show_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                    🔍 VERIFICACIÓN DE RECURSOS DEL SISTEMA                  ║
║                                                                              ║
║                        Backstage + OpenWebUI Demo                           ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
}

check_memory() {
    log_info "Verificando memoria del sistema..."
    
    local total_memory_gb=0
    local available_memory_gb=0
    
    if [[ -f /proc/meminfo ]]; then
        # Linux
        local total_memory_kb
        local available_memory_kb
        
        total_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        available_memory_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        
        total_memory_gb=$((total_memory_kb / 1024 / 1024))
        available_memory_gb=$((available_memory_kb / 1024 / 1024))
        
    elif command -v vm_stat &> /dev/null; then
        # macOS
        local page_size
        local free_pages
        local inactive_pages
        
        page_size=$(vm_stat | grep "page size" | awk '{print $8}')
        free_pages=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
        inactive_pages=$(vm_stat | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
        
        local available_bytes=$(( (free_pages + inactive_pages) * page_size ))
        available_memory_gb=$((available_bytes / 1024 / 1024 / 1024))
        
        # Obtener memoria total
        total_memory_gb=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
    else
        log_warning "No se puede determinar la memoria del sistema"
        return 1
    fi
    
    echo -e "  ${CYAN}Memoria Total:${NC} ${total_memory_gb}GB"
    echo -e "  ${CYAN}Memoria Disponible:${NC} ${available_memory_gb}GB"
    echo -e "  ${CYAN}Mínimo Requerido:${NC} ${MIN_MEMORY_GB}GB"
    echo -e "  ${CYAN}Recomendado:${NC} ${RECOMMENDED_MEMORY_GB}GB"
    
    if [[ $available_memory_gb -lt $MIN_MEMORY_GB ]]; then
        log_error "❌ Memoria insuficiente (${available_memory_gb}GB < ${MIN_MEMORY_GB}GB)"
        return 1
    elif [[ $available_memory_gb -lt $RECOMMENDED_MEMORY_GB ]]; then
        log_warning "⚠️  Memoria por debajo de lo recomendado (${available_memory_gb}GB < ${RECOMMENDED_MEMORY_GB}GB)"
        return 2
    else
        log_success "✅ Memoria suficiente (${available_memory_gb}GB >= ${RECOMMENDED_MEMORY_GB}GB)"
        return 0
    fi
}

check_disk_space() {
    log_info "Verificando espacio en disco..."
    
    local available_disk_gb
    local total_disk_gb
    
    if command -v df &> /dev/null; then
        # Obtener espacio disponible en el directorio actual
        local disk_info
        disk_info=$(df -BG . | tail -n 1)
        
        total_disk_gb=$(echo "$disk_info" | awk '{print $2}' | sed 's/G//')
        available_disk_gb=$(echo "$disk_info" | awk '{print $4}' | sed 's/G//')
    else
        log_warning "No se puede determinar el espacio en disco"
        return 1
    fi
    
    echo -e "  ${CYAN}Espacio Total:${NC} ${total_disk_gb}GB"
    echo -e "  ${CYAN}Espacio Disponible:${NC} ${available_disk_gb}GB"
    echo -e "  ${CYAN}Mínimo Requerido:${NC} ${MIN_DISK_GB}GB"
    echo -e "  ${CYAN}Recomendado:${NC} ${RECOMMENDED_DISK_GB}GB"
    
    if [[ $available_disk_gb -lt $MIN_DISK_GB ]]; then
        log_error "❌ Espacio en disco insuficiente (${available_disk_gb}GB < ${MIN_DISK_GB}GB)"
        return 1
    elif [[ $available_disk_gb -lt $RECOMMENDED_DISK_GB ]]; then
        log_warning "⚠️  Espacio en disco por debajo de lo recomendado (${available_disk_gb}GB < ${RECOMMENDED_DISK_GB}GB)"
        return 2
    else
        log_success "✅ Espacio en disco suficiente (${available_disk_gb}GB >= ${RECOMMENDED_DISK_GB}GB)"
        return 0
    fi
}

check_cpu() {
    log_info "Verificando CPUs del sistema..."
    
    local cpu_count=0
    
    if [[ -f /proc/cpuinfo ]]; then
        # Linux
        cpu_count=$(grep -c ^processor /proc/cpuinfo)
    elif command -v sysctl &> /dev/null; then
        # macOS
        cpu_count=$(sysctl -n hw.ncpu)
    else
        log_warning "No se puede determinar el número de CPUs"
        return 1
    fi
    
    echo -e "  ${CYAN}CPUs Disponibles:${NC} ${cpu_count}"
    echo -e "  ${CYAN}Mínimo Requerido:${NC} ${MIN_CPUS}"
    echo -e "  ${CYAN}Recomendado:${NC} ${RECOMMENDED_CPUS}"
    
    if [[ $cpu_count -lt $MIN_CPUS ]]; then
        log_error "❌ CPUs insuficientes (${cpu_count} < ${MIN_CPUS})"
        return 1
    elif [[ $cpu_count -lt $RECOMMENDED_CPUS ]]; then
        log_warning "⚠️  CPUs por debajo de lo recomendado (${cpu_count} < ${RECOMMENDED_CPUS})"
        return 2
    else
        log_success "✅ CPUs suficientes (${cpu_count} >= ${RECOMMENDED_CPUS})"
        return 0
    fi
}

check_docker() {
    log_info "Verificando Docker..."
    
    if ! command -v docker &> /dev/null; then
        log_error "❌ Docker no está instalado"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "❌ Docker no está ejecutándose o no es accesible"
        echo -e "  ${YELLOW}Solución:${NC} Inicia Docker y asegúrate de tener permisos"
        return 1
    fi
    
    local docker_version
    docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
    
    echo -e "  ${CYAN}Docker Version:${NC} ${docker_version}"
    log_success "✅ Docker está funcionando correctamente"
    return 0
}

check_minikube() {
    log_info "Verificando Minikube..."
    
    if ! command -v minikube &> /dev/null; then
        log_error "❌ Minikube no está instalado"
        echo -e "  ${YELLOW}Instalación:${NC} https://minikube.sigs.k8s.io/docs/start/"
        return 1
    fi
    
    local minikube_version
    minikube_version=$(minikube version --short)
    
    echo -e "  ${CYAN}Minikube Version:${NC} ${minikube_version}"
    log_success "✅ Minikube está instalado"
    return 0
}

check_kubectl() {
    log_info "Verificando kubectl..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "❌ kubectl no está instalado"
        echo -e "  ${YELLOW}Instalación:${NC} https://kubernetes.io/docs/tasks/tools/"
        return 1
    fi
    
    local kubectl_version
    kubectl_version=$(kubectl version --client --short 2>/dev/null | awk '{print $3}')
    
    echo -e "  ${CYAN}kubectl Version:${NC} ${kubectl_version}"
    log_success "✅ kubectl está instalado"
    return 0
}

check_helm() {
    log_info "Verificando Helm..."
    
    if ! command -v helm &> /dev/null; then
        log_warning "⚠️  Helm no está instalado (opcional)"
        echo -e "  ${YELLOW}Instalación:${NC} https://helm.sh/docs/intro/install/"
        return 2
    fi
    
    local helm_version
    helm_version=$(helm version --short | awk '{print $1}')
    
    echo -e "  ${CYAN}Helm Version:${NC} ${helm_version}"
    log_success "✅ Helm está instalado"
    return 0
}

show_recommendations() {
    echo
    log_info "💡 Recomendaciones para optimizar el rendimiento:"
    echo
    
    cat << EOF
$(echo -e "${CYAN}Antes de ejecutar el demo:${NC}")
  • Cierra aplicaciones innecesarias para liberar memoria
  • Asegúrate de tener una conexión estable a internet
  • Considera usar SSD para mejor rendimiento de I/O
  
$(echo -e "${CYAN}Configuración recomendada de Minikube:${NC}")
  • Memoria: 4-6GB (--memory=4096 o --memory=6144)
  • CPUs: 2-4 cores (--cpus=2 o --cpus=4)
  • Disco: 20-30GB (--disk-size=20g o --disk-size=30g)
  • Driver: docker (mejor compatibilidad)
  
$(echo -e "${CYAN}Si tienes recursos limitados:${NC}")
  • Usa --memory=3072 --cpus=2 como mínimo
  • Considera usar --skip-images para setup más rápido
  • Monitorea el uso de recursos con 'minikube addons enable metrics-server'
  
$(echo -e "${CYAN}Comandos útiles:${NC}")
  # Verificar recursos del sistema
  ./scripts/minikube/check-resources.sh
  
  # Setup con recursos personalizados
  ./scripts/minikube/setup-minikube.sh --memory 4096 --cpus 3
  
  # Setup rápido (sin imágenes)
  ./scripts/minikube/setup-minikube.sh --skip-images
EOF
}

show_summary() {
    local memory_status=$1
    local disk_status=$2
    local cpu_status=$3
    local docker_status=$4
    local minikube_status=$5
    local kubectl_status=$6
    local helm_status=$7
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                              RESUMEN DE VERIFICACIÓN                           ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo
    
    # Determinar estado general
    local overall_status="✅ LISTO"
    local can_proceed=true
    
    if [[ $memory_status -eq 1 || $disk_status -eq 1 || $cpu_status -eq 1 || 
          $docker_status -eq 1 || $minikube_status -eq 1 || $kubectl_status -eq 1 ]]; then
        overall_status="❌ NO LISTO"
        can_proceed=false
    elif [[ $memory_status -eq 2 || $disk_status -eq 2 || $cpu_status -eq 2 ]]; then
        overall_status="⚠️  LISTO CON LIMITACIONES"
    fi
    
    echo -e "$(echo -e "${CYAN}Estado General:${NC}") $overall_status"
    echo
    
    # Mostrar detalles
    echo -e "${CYAN}Componentes:${NC}"
    [[ $memory_status -eq 0 ]] && echo "  ✅ Memoria" || [[ $memory_status -eq 1 ]] && echo "  ❌ Memoria" || echo "  ⚠️  Memoria"
    [[ $disk_status -eq 0 ]] && echo "  ✅ Disco" || [[ $disk_status -eq 1 ]] && echo "  ❌ Disco" || echo "  ⚠️  Disco"
    [[ $cpu_status -eq 0 ]] && echo "  ✅ CPU" || [[ $cpu_status -eq 1 ]] && echo "  ❌ CPU" || echo "  ⚠️  CPU"
    [[ $docker_status -eq 0 ]] && echo "  ✅ Docker" || echo "  ❌ Docker"
    [[ $minikube_status -eq 0 ]] && echo "  ✅ Minikube" || echo "  ❌ Minikube"
    [[ $kubectl_status -eq 0 ]] && echo "  ✅ kubectl" || echo "  ❌ kubectl"
    [[ $helm_status -eq 0 ]] && echo "  ✅ Helm" || [[ $helm_status -eq 2 ]] && echo "  ⚠️  Helm (opcional)" || echo "  ❌ Helm"
    
    echo
    
    if [[ "$can_proceed" == true ]]; then
        log_success "🚀 El sistema está listo para ejecutar el demo!"
        echo
        echo -e "${CYAN}Próximo paso:${NC}"
        echo "  ./scripts/minikube/setup-minikube.sh"
    else
        log_error "🛑 El sistema NO está listo para ejecutar el demo"
        echo
        echo -e "${CYAN}Acciones requeridas:${NC}"
        [[ $memory_status -eq 1 ]] && echo "  • Liberar memoria o agregar más RAM"
        [[ $disk_status -eq 1 ]] && echo "  • Liberar espacio en disco"
        [[ $cpu_status -eq 1 ]] && echo "  • Usar un sistema con más CPUs"
        [[ $docker_status -eq 1 ]] && echo "  • Instalar y configurar Docker"
        [[ $minikube_status -eq 1 ]] && echo "  • Instalar Minikube"
        [[ $kubectl_status -eq 1 ]] && echo "  • Instalar kubectl"
    fi
    
    echo
}

main() {
    show_banner
    echo
    
    # Ejecutar verificaciones
    local memory_status=0
    local disk_status=0
    local cpu_status=0
    local docker_status=0
    local minikube_status=0
    local kubectl_status=0
    local helm_status=0
    
    check_memory || memory_status=$?
    echo
    
    check_disk_space || disk_status=$?
    echo
    
    check_cpu || cpu_status=$?
    echo
    
    check_docker || docker_status=$?
    echo
    
    check_minikube || minikube_status=$?
    echo
    
    check_kubectl || kubectl_status=$?
    echo
    
    check_helm || helm_status=$?
    echo
    
    show_summary $memory_status $disk_status $cpu_status $docker_status $minikube_status $kubectl_status $helm_status
    
    show_recommendations
    
    # Exit code basado en el estado general
    if [[ $memory_status -eq 1 || $disk_status -eq 1 || $cpu_status -eq 1 || 
          $docker_status -eq 1 || $minikube_status -eq 1 || $kubectl_status -eq 1 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
