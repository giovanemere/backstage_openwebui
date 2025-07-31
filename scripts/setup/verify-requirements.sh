#!/bin/bash

# Script para verificar requisitos del sistema para Backstage + OpenWebUI Demo
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

# Variables de requisitos
MIN_RAM_GB=8
RECOMMENDED_RAM_GB=12
MIN_CPU_CORES=4
RECOMMENDED_CPU_CORES=6
MIN_DISK_GB=20
RECOMMENDED_DISK_GB=30

# Contadores
ERRORS=0
WARNINGS=0

print_info "Verificando requisitos del sistema para Backstage + OpenWebUI Demo..."
echo ""

# Verificar sistema operativo
print_info "Verificando sistema operativo..."
OS=$(uname -s)
case $OS in
    Linux*)
        print_success "Sistema operativo: Linux ✓"
        ;;
    Darwin*)
        print_success "Sistema operativo: macOS ✓"
        ;;
    CYGWIN*|MINGW*|MSYS*)
        print_success "Sistema operativo: Windows con WSL/Git Bash ✓"
        ;;
    *)
        print_error "Sistema operativo no soportado: $OS"
        ERRORS=$((ERRORS + 1))
        ;;
esac

# Verificar RAM
print_info "Verificando memoria RAM..."
if command -v free >/dev/null 2>&1; then
    # Linux
    TOTAL_RAM_KB=$(free | grep '^Mem:' | awk '{print $2}')
    TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
elif command -v vm_stat >/dev/null 2>&1; then
    # macOS
    TOTAL_RAM_BYTES=$(sysctl -n hw.memsize)
    TOTAL_RAM_GB=$((TOTAL_RAM_BYTES / 1024 / 1024 / 1024))
else
    print_warning "No se pudo determinar la cantidad de RAM automáticamente"
    TOTAL_RAM_GB=0
    WARNINGS=$((WARNINGS + 1))
fi

if [ $TOTAL_RAM_GB -ge $RECOMMENDED_RAM_GB ]; then
    print_success "RAM: ${TOTAL_RAM_GB}GB (Recomendado: ${RECOMMENDED_RAM_GB}GB+) ✓"
elif [ $TOTAL_RAM_GB -ge $MIN_RAM_GB ]; then
    print_warning "RAM: ${TOTAL_RAM_GB}GB (Mínimo: ${MIN_RAM_GB}GB, Recomendado: ${RECOMMENDED_RAM_GB}GB+)"
    WARNINGS=$((WARNINGS + 1))
elif [ $TOTAL_RAM_GB -gt 0 ]; then
    print_error "RAM insuficiente: ${TOTAL_RAM_GB}GB (Mínimo requerido: ${MIN_RAM_GB}GB)"
    ERRORS=$((ERRORS + 1))
fi

# Verificar CPU
print_info "Verificando CPU..."
if command -v nproc >/dev/null 2>&1; then
    # Linux
    CPU_CORES=$(nproc)
elif command -v sysctl >/dev/null 2>&1; then
    # macOS
    CPU_CORES=$(sysctl -n hw.ncpu)
else
    print_warning "No se pudo determinar el número de cores de CPU automáticamente"
    CPU_CORES=0
    WARNINGS=$((WARNINGS + 1))
fi

if [ $CPU_CORES -ge $RECOMMENDED_CPU_CORES ]; then
    print_success "CPU: ${CPU_CORES} cores (Recomendado: ${RECOMMENDED_CPU_CORES}+) ✓"
elif [ $CPU_CORES -ge $MIN_CPU_CORES ]; then
    print_warning "CPU: ${CPU_CORES} cores (Mínimo: ${MIN_CPU_CORES}, Recomendado: ${RECOMMENDED_CPU_CORES}+)"
    WARNINGS=$((WARNINGS + 1))
elif [ $CPU_CORES -gt 0 ]; then
    print_error "CPU insuficiente: ${CPU_CORES} cores (Mínimo requerido: ${MIN_CPU_CORES})"
    ERRORS=$((ERRORS + 1))
fi

# Verificar espacio en disco
print_info "Verificando espacio en disco..."
if command -v df >/dev/null 2>&1; then
    DISK_AVAILABLE_KB=$(df . | tail -1 | awk '{print $4}')
    DISK_AVAILABLE_GB=$((DISK_AVAILABLE_KB / 1024 / 1024))
    
    if [ $DISK_AVAILABLE_GB -ge $RECOMMENDED_DISK_GB ]; then
        print_success "Espacio en disco: ${DISK_AVAILABLE_GB}GB disponibles (Recomendado: ${RECOMMENDED_DISK_GB}GB+) ✓"
    elif [ $DISK_AVAILABLE_GB -ge $MIN_DISK_GB ]; then
        print_warning "Espacio en disco: ${DISK_AVAILABLE_GB}GB disponibles (Mínimo: ${MIN_DISK_GB}GB, Recomendado: ${RECOMMENDED_DISK_GB}GB+)"
        WARNINGS=$((WARNINGS + 1))
    else
        print_error "Espacio en disco insuficiente: ${DISK_AVAILABLE_GB}GB disponibles (Mínimo requerido: ${MIN_DISK_GB}GB)"
        ERRORS=$((ERRORS + 1))
    fi
else
    print_warning "No se pudo verificar el espacio en disco automáticamente"
    WARNINGS=$((WARNINGS + 1))
fi

# Verificar Docker
print_info "Verificando Docker..."
if command -v docker >/dev/null 2>&1; then
    if docker --version >/dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        print_success "Docker instalado: v${DOCKER_VERSION} ✓"
        
        # Verificar que Docker esté corriendo
        if docker info >/dev/null 2>&1; then
            print_success "Docker daemon está corriendo ✓"
        else
            print_error "Docker está instalado pero el daemon no está corriendo"
            ERRORS=$((ERRORS + 1))
        fi
    else
        print_error "Docker está instalado pero no funciona correctamente"
        ERRORS=$((ERRORS + 1))
    fi
else
    print_error "Docker no está instalado"
    ERRORS=$((ERRORS + 1))
fi

# Verificar kubectl
print_info "Verificando kubectl..."
if command -v kubectl >/dev/null 2>&1; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)
    print_success "kubectl instalado: ${KUBECTL_VERSION} ✓"
else
    print_warning "kubectl no está instalado (se instalará con Minikube)"
    WARNINGS=$((WARNINGS + 1))
fi

# Verificar Minikube
print_info "Verificando Minikube..."
if command -v minikube >/dev/null 2>&1; then
    MINIKUBE_VERSION=$(minikube version --short 2>/dev/null || echo "unknown")
    print_success "Minikube instalado: ${MINIKUBE_VERSION} ✓"
else
    print_warning "Minikube no está instalado (se instalará automáticamente)"
    WARNINGS=$((WARNINGS + 1))
fi

# Verificar Helm
print_info "Verificando Helm..."
if command -v helm >/dev/null 2>&1; then
    HELM_VERSION=$(helm version --short 2>/dev/null | cut -d'+' -f1)
    print_success "Helm instalado: ${HELM_VERSION} ✓"
else
    print_warning "Helm no está instalado (se instalará automáticamente)"
    WARNINGS=$((WARNINGS + 1))
fi

# Verificar Node.js (para desarrollo)
print_info "Verificando Node.js..."
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version)
    print_success "Node.js instalado: ${NODE_VERSION} ✓"
else
    print_warning "Node.js no está instalado (necesario solo para desarrollo local)"
    WARNINGS=$((WARNINGS + 1))
fi

# Verificar Python (para OpenWebUI)
print_info "Verificando Python..."
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    print_success "Python instalado: v${PYTHON_VERSION} ✓"
elif command -v python >/dev/null 2>&1; then
    PYTHON_VERSION=$(python --version | cut -d' ' -f2)
    print_success "Python instalado: v${PYTHON_VERSION} ✓"
else
    print_warning "Python no está instalado (necesario solo para desarrollo local)"
    WARNINGS=$((WARNINGS + 1))
fi

# Verificar Make
print_info "Verificando Make..."
if command -v make >/dev/null 2>&1; then
    MAKE_VERSION=$(make --version | head -1 | cut -d' ' -f3)
    print_success "Make instalado: v${MAKE_VERSION} ✓"
else
    print_warning "Make no está instalado (recomendado para usar Makefile)"
    WARNINGS=$((WARNINGS + 1))
fi

# Verificar Git
print_info "Verificando Git..."
if command -v git >/dev/null 2>&1; then
    GIT_VERSION=$(git --version | cut -d' ' -f3)
    print_success "Git instalado: v${GIT_VERSION} ✓"
else
    print_error "Git no está instalado (requerido)"
    ERRORS=$((ERRORS + 1))
fi

echo ""
print_info "=== RESUMEN DE VERIFICACIÓN ==="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    print_success "✅ Todos los requisitos están satisfechos. Sistema listo para la demo."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    print_warning "⚠️  Sistema funcional con ${WARNINGS} advertencia(s). La demo debería funcionar."
    echo ""
    print_info "Recomendaciones:"
    print_info "- Instalar herramientas faltantes para mejor experiencia"
    print_info "- Considerar upgrade de hardware si es posible"
    exit 0
else
    print_error "❌ Se encontraron ${ERRORS} error(es) crítico(s) y ${WARNINGS} advertencia(s)."
    echo ""
    print_info "Acciones requeridas:"
    if [ $ERRORS -gt 0 ]; then
        print_info "- Resolver errores críticos antes de continuar"
        print_info "- Instalar herramientas faltantes"
        print_info "- Verificar recursos de hardware"
    fi
    echo ""
    print_info "Para instalar herramientas faltantes, ejecutar:"
    print_info "  ./scripts/setup/install-minikube.sh"
    exit 1
fi
