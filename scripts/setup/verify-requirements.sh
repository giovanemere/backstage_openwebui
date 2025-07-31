#!/bin/bash

# Script de verificación de requisitos del sistema
# Verifica que el sistema cumple con los requisitos mínimos para ejecutar el demo

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🔍 Verificando requisitos del sistema para Backstage + OpenWebUI...${NC}"
echo -e "${CYAN}   Plataforma de desarrollo con IA integrada${NC}"
echo

# Función para verificar comandos
check_command() {
    if command -v $1 &> /dev/null; then
        local version=""
        case $1 in
            "kubectl")
                version=$(kubectl version --client 2>/dev/null | grep "Client Version" | head -1 || echo "kubectl instalado")
                ;;
            "helm")
                version=$(helm version --short 2>/dev/null || helm version 2>/dev/null | head -1 || echo "helm instalado")
                ;;
            "docker")
                version=$(docker --version 2>/dev/null || echo "docker instalado")
                ;;
            "minikube")
                version=$(minikube version 2>/dev/null | head -1 || echo "minikube instalado")
                ;;
            *)
                version=$($1 --version 2>/dev/null | head -1 || echo "$1 instalado")
                ;;
        esac
        echo -e "${GREEN}✅ $1: $version${NC}"
        return 0
    else
        echo -e "${RED}❌ $1: No encontrado${NC}"
        return 1
    fi
}

# Función para verificar versión específica
check_version() {
    local cmd=$1
    local version_cmd=$2
    local min_version=$3
    
    if command -v $cmd &> /dev/null; then
        local current_version=""
        case $cmd in
            "kubectl")
                current_version=$(kubectl version --client 2>/dev/null | grep "Client Version" | head -1 || echo "kubectl - versión no detectada")
                ;;
            "helm")
                current_version=$(helm version --short 2>/dev/null || helm version 2>/dev/null | head -1 || echo "helm - versión no detectada")
                ;;
            "docker")
                current_version=$(docker --version 2>/dev/null || echo "docker - versión no detectada")
                ;;
            *)
                current_version=$($version_cmd 2>/dev/null | head -1 || echo "$cmd - versión no detectada")
                ;;
        esac
        echo -e "${GREEN}✅ $cmd: $current_version${NC}"
        return 0
    else
        echo -e "${RED}❌ $cmd: No encontrado (versión mínima: $min_version)${NC}"
        return 1
    fi
}

# Función para mostrar instrucciones de instalación
show_install_instructions() {
    echo -e "\n${YELLOW}📋 Instrucciones de instalación para herramientas faltantes:${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${CYAN}🐳 Docker:${NC}"
        echo "   Ubuntu/Debian: curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh"
        echo "   CentOS/RHEL:   sudo yum install -y docker-ce docker-ce-cli containerd.io"
        echo "   macOS:         brew install --cask docker"
    fi
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${CYAN}☸️  kubectl:${NC}"
        echo "   Linux:   curl -LO https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        echo "   macOS:   brew install kubectl"
    fi
    
    if ! command -v helm &> /dev/null; then
        echo -e "${CYAN}⛵ Helm:${NC}"
        echo "   Linux:   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
        echo "   macOS:   brew install helm"
    fi
    
    if ! command -v make &> /dev/null; then
        echo -e "${CYAN}🔨 Make:${NC}"
        echo "   Ubuntu/Debian: sudo apt-get install build-essential"
        echo "   CentOS/RHEL:   sudo yum groupinstall 'Development Tools'"
        echo "   macOS:         xcode-select --install"
    fi
}

# Verificar herramientas esenciales
echo -e "${YELLOW}📋 Verificando herramientas esenciales:${NC}"

TOOLS_OK=true

check_command "docker" || TOOLS_OK=false
check_command "kubectl" || TOOLS_OK=false
check_command "helm" || TOOLS_OK=false
check_command "make" || TOOLS_OK=false
check_command "git" || TOOLS_OK=false

# Verificar versiones específicas
echo -e "\n${YELLOW}🔢 Verificando versiones mínimas:${NC}"

check_version "docker" "docker --version" "20.10+" || TOOLS_OK=false
check_version "kubectl" "kubectl version --client --short" "1.24+" || TOOLS_OK=false
check_version "helm" "helm version --short" "3.8+" || TOOLS_OK=false

# Verificar recursos del sistema
echo -e "\n${YELLOW}💻 Verificando recursos del sistema:${NC}"

# RAM
if command -v free &> /dev/null; then
    TOTAL_RAM=$(free -m | awk 'NR==2{printf "%.0f", $2/1024}')
    AVAILABLE_RAM=$(free -m | awk 'NR==2{printf "%.0f", $7/1024}')
    
    if [ $TOTAL_RAM -ge 8 ]; then
        echo -e "${GREEN}✅ RAM Total: ${TOTAL_RAM}GB (mínimo: 8GB)${NC}"
        if [ $AVAILABLE_RAM -ge 4 ]; then
            echo -e "${GREEN}✅ RAM Disponible: ${AVAILABLE_RAM}GB (mínimo: 4GB)${NC}"
        else
            echo -e "${YELLOW}⚠️  RAM Disponible: ${AVAILABLE_RAM}GB (recomendado: 4GB+)${NC}"
        fi
    else
        echo -e "${RED}❌ RAM Total: ${TOTAL_RAM}GB (mínimo requerido: 8GB)${NC}"
        TOOLS_OK=false
    fi
else
    echo -e "${YELLOW}⚠️  No se puede verificar RAM en este sistema${NC}"
fi

# CPU
CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "unknown")
if [ "$CPU_CORES" != "unknown" ] && [ $CPU_CORES -ge 4 ]; then
    echo -e "${GREEN}✅ CPU: ${CPU_CORES} cores (mínimo: 4 cores)${NC}"
elif [ "$CPU_CORES" != "unknown" ]; then
    echo -e "${RED}❌ CPU: ${CPU_CORES} cores (mínimo requerido: 4 cores)${NC}"
    TOOLS_OK=false
else
    echo -e "${YELLOW}⚠️  No se puede verificar CPU en este sistema${NC}"
fi

# Espacio en disco
if command -v df &> /dev/null; then
    DISK_SPACE=$(df -BG . 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//' || echo "unknown")
    if [ "$DISK_SPACE" != "unknown" ] && [ $DISK_SPACE -ge 20 ]; then
        echo -e "${GREEN}✅ Disco: ${DISK_SPACE}GB disponibles (mínimo: 20GB)${NC}"
    elif [ "$DISK_SPACE" != "unknown" ]; then
        echo -e "${RED}❌ Disco: ${DISK_SPACE}GB disponibles (mínimo requerido: 20GB)${NC}"
        TOOLS_OK=false
    else
        echo -e "${YELLOW}⚠️  No se puede verificar espacio en disco${NC}"
    fi
fi

# Verificar Docker daemon
echo -e "\n${YELLOW}🐳 Verificando Docker:${NC}"
if docker ps &> /dev/null; then
    echo -e "${GREEN}✅ Docker daemon: Funcionando correctamente${NC}"
    
    # Verificar permisos de Docker
    if docker info &> /dev/null; then
        echo -e "${GREEN}✅ Docker permisos: OK${NC}"
    else
        echo -e "${YELLOW}⚠️  Docker permisos: Puede requerir sudo${NC}"
        echo -e "${CYAN}   Considera agregar tu usuario al grupo docker: sudo usermod -aG docker \$USER${NC}"
    fi
else
    echo -e "${RED}❌ Docker daemon: No está corriendo${NC}"
    echo -e "${CYAN}   Inicia Docker con: sudo systemctl start docker${NC}"
    TOOLS_OK=false
fi

# Verificar herramientas opcionales
echo -e "\n${YELLOW}🔧 Verificando herramientas opcionales:${NC}"

if check_command "jq"; then
    :
else
    echo -e "${YELLOW}⚠️  jq: Recomendado para procesamiento JSON${NC}"
    echo -e "${CYAN}   Instalar: sudo apt-get install jq (Ubuntu) | brew install jq (macOS)${NC}"
fi

if check_command "yq"; then
    :
else
    echo -e "${YELLOW}⚠️  yq: Recomendado para procesamiento YAML${NC}"
    echo -e "${CYAN}   Instalar: sudo snap install yq | brew install yq${NC}"
fi

if check_command "minikube"; then
    :
else
    echo -e "${YELLOW}⚠️  minikube: Se instalará automáticamente si es necesario${NC}"
fi

# Verificar conectividad de red
echo -e "\n${YELLOW}🌐 Verificando conectividad:${NC}"
if ping -c 1 google.com &> /dev/null; then
    echo -e "${GREEN}✅ Conectividad a Internet: OK${NC}"
else
    echo -e "${YELLOW}⚠️  Conectividad a Internet: Limitada${NC}"
    echo -e "${CYAN}   Algunas funcionalidades pueden requerir conexión a Internet${NC}"
fi

# Verificar puertos disponibles
echo -e "\n${YELLOW}🔌 Verificando puertos requeridos:${NC}"
REQUIRED_PORTS=(3000 8080 8081 8082)
PORTS_OK=true

for port in "${REQUIRED_PORTS[@]}"; do
    if netstat -tuln 2>/dev/null | grep ":$port " &> /dev/null; then
        echo -e "${YELLOW}⚠️  Puerto $port: En uso${NC}"
        echo -e "${CYAN}   Puede causar conflictos. Considera liberar el puerto.${NC}"
    else
        echo -e "${GREEN}✅ Puerto $port: Disponible${NC}"
    fi
done

# Resultado final
echo -e "\n${BLUE}📊 Resumen de verificación:${NC}"

if [ "$TOOLS_OK" = true ]; then
    echo -e "${GREEN}🎉 ¡Todos los requisitos esenciales están cumplidos!${NC}"
    echo -e "${GREEN}   Tu sistema está listo para ejecutar la plataforma${NC}"
    echo
    echo -e "${CYAN}📋 Próximos pasos:${NC}"
    echo -e "${CYAN}   1. make minikube-setup     # Configurar cluster${NC}"
    echo -e "${CYAN}   2. make deploy-demo        # Desplegar plataforma${NC}"
    echo -e "${CYAN}   3. make port-forward       # Configurar acceso${NC}"
    echo
    echo -e "${BLUE}🚀 Comando rápido para empezar:${NC}"
    echo -e "${CYAN}   make minikube-setup && make deploy-demo && make port-forward${NC}"
    exit 0
else
    echo -e "${RED}❌ Algunos requisitos esenciales no están cumplidos${NC}"
    echo -e "${YELLOW}   Instala las herramientas faltantes y vuelve a ejecutar este script${NC}"
    
    show_install_instructions
    
    echo -e "\n${CYAN}💡 Después de instalar las herramientas faltantes:${NC}"
    echo -e "${CYAN}   ./scripts/setup/verify-requirements.sh${NC}"
    exit 1
fi
