#!/bin/bash

# Script para instalar Minikube y herramientas necesarias
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

# Detectar sistema operativo
OS=$(uname -s)
ARCH=$(uname -m)

print_info "Instalando herramientas necesarias para Backstage + OpenWebUI Demo..."
print_info "Sistema operativo detectado: $OS ($ARCH)"
echo ""

# Función para instalar en Linux
install_linux() {
    print_info "Instalando herramientas para Linux..."
    
    # Detectar distribución
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        DISTRO="unknown"
    fi
    
    print_info "Distribución detectada: $DISTRO"
    
    # Instalar kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        print_info "Instalando kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
        print_success "kubectl instalado ✓"
    else
        print_success "kubectl ya está instalado ✓"
    fi
    
    # Instalar Minikube
    if ! command -v minikube >/dev/null 2>&1; then
        print_info "Instalando Minikube..."
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        chmod +x minikube-linux-amd64
        sudo mv minikube-linux-amd64 /usr/local/bin/minikube
        print_success "Minikube instalado ✓"
    else
        print_success "Minikube ya está instalado ✓"
    fi
    
    # Instalar Helm
    if ! command -v helm >/dev/null 2>&1; then
        print_info "Instalando Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        print_success "Helm instalado ✓"
    else
        print_success "Helm ya está instalado ✓"
    fi
    
    # Instalar Docker si no está presente
    if ! command -v docker >/dev/null 2>&1; then
        print_warning "Docker no está instalado. Instalando Docker..."
        case $DISTRO in
            ubuntu|debian)
                sudo apt-get update
                sudo apt-get install -y docker.io
                sudo systemctl start docker
                sudo systemctl enable docker
                sudo usermod -aG docker $USER
                ;;
            centos|rhel|fedora)
                sudo yum install -y docker
                sudo systemctl start docker
                sudo systemctl enable docker
                sudo usermod -aG docker $USER
                ;;
            *)
                print_error "Distribución no soportada para instalación automática de Docker"
                print_info "Por favor instalar Docker manualmente desde: https://docs.docker.com/engine/install/"
                ;;
        esac
        print_success "Docker instalado ✓"
        print_warning "Nota: Es necesario reiniciar la sesión para usar Docker sin sudo"
    else
        print_success "Docker ya está instalado ✓"
    fi
}

# Función para instalar en macOS
install_macos() {
    print_info "Instalando herramientas para macOS..."
    
    # Verificar si Homebrew está instalado
    if ! command -v brew >/dev/null 2>&1; then
        print_info "Instalando Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        print_success "Homebrew instalado ✓"
    else
        print_success "Homebrew ya está instalado ✓"
    fi
    
    # Instalar herramientas con Homebrew
    print_info "Instalando herramientas con Homebrew..."
    
    if ! command -v kubectl >/dev/null 2>&1; then
        brew install kubectl
        print_success "kubectl instalado ✓"
    else
        print_success "kubectl ya está instalado ✓"
    fi
    
    if ! command -v minikube >/dev/null 2>&1; then
        brew install minikube
        print_success "Minikube instalado ✓"
    else
        print_success "Minikube ya está instalado ✓"
    fi
    
    if ! command -v helm >/dev/null 2>&1; then
        brew install helm
        print_success "Helm instalado ✓"
    else
        print_success "Helm ya está instalado ✓"
    fi
    
    if ! command -v docker >/dev/null 2>&1; then
        print_info "Instalando Docker Desktop..."
        brew install --cask docker
        print_success "Docker Desktop instalado ✓"
        print_warning "Nota: Es necesario iniciar Docker Desktop manualmente"
    else
        print_success "Docker ya está instalado ✓"
    fi
}

# Función para instalar en Windows (WSL/Git Bash)
install_windows() {
    print_info "Instalando herramientas para Windows..."
    print_warning "Para Windows, se recomienda usar WSL2 o instalar manualmente"
    
    print_info "Enlaces de descarga manual:"
    print_info "- kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
    print_info "- Minikube: https://minikube.sigs.k8s.io/docs/start/"
    print_info "- Helm: https://helm.sh/docs/intro/install/"
    print_info "- Docker Desktop: https://docs.docker.com/desktop/install/windows-install/"
    
    # Intentar instalación con chocolatey si está disponible
    if command -v choco >/dev/null 2>&1; then
        print_info "Chocolatey detectado. Instalando herramientas..."
        choco install kubernetes-cli minikube kubernetes-helm docker-desktop -y
        print_success "Herramientas instaladas con Chocolatey ✓"
    fi
}

# Ejecutar instalación según el sistema operativo
case $OS in
    Linux*)
        install_linux
        ;;
    Darwin*)
        install_macos
        ;;
    CYGWIN*|MINGW*|MSYS*)
        install_windows
        ;;
    *)
        print_error "Sistema operativo no soportado: $OS"
        exit 1
        ;;
esac

echo ""
print_info "=== VERIFICACIÓN POST-INSTALACIÓN ==="

# Verificar instalaciones
TOOLS=("kubectl" "minikube" "helm" "docker")
ALL_INSTALLED=true

for tool in "${TOOLS[@]}"; do
    if command -v $tool >/dev/null 2>&1; then
        VERSION=$($tool version --short 2>/dev/null || $tool --version 2>/dev/null || echo "installed")
        print_success "$tool: $VERSION ✓"
    else
        print_error "$tool: No instalado ❌"
        ALL_INSTALLED=false
    fi
done

echo ""
if $ALL_INSTALLED; then
    print_success "✅ Todas las herramientas instaladas correctamente"
    print_info "Próximos pasos:"
    print_info "1. Ejecutar: ./scripts/setup/setup-cluster.sh"
    print_info "2. O usar: make setup-minikube"
else
    print_error "❌ Algunas herramientas no se instalaron correctamente"
    print_info "Por favor instalar manualmente las herramientas faltantes"
    exit 1
fi

echo ""
print_info "=== NOTAS IMPORTANTES ==="
print_warning "- Si instalaste Docker, es posible que necesites reiniciar tu sesión"
print_warning "- En macOS, asegúrate de iniciar Docker Desktop"
print_warning "- En Windows, asegúrate de que WSL2 esté habilitado para Docker"
print_info "- Para verificar que todo funciona: ./scripts/setup/verify-requirements.sh"
