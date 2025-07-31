#!/bin/bash

# Script de Inicio Rápido - Backstage + OpenWebUI Platform
# Despliega toda la plataforma en 5 minutos

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Banner de bienvenida
echo -e "${BOLD}${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║    🚀 BACKSTAGE + OPENWEBUI PLATFORM - INICIO RÁPIDO        ║"
echo "║                                                              ║"
echo "║    Plataforma de desarrollo con IA integrada                 ║"
echo "║    Tiempo estimado: 5 minutos                                ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Función para mostrar progreso
show_progress() {
    local step=$1
    local total=$2
    local description=$3
    echo -e "\n${BOLD}${CYAN}[${step}/${total}] ${description}${NC}"
}

# Función para mostrar éxito
show_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Función para mostrar error
show_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Función para mostrar advertencia
show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Verificar que estamos en el directorio correcto
if [[ ! -f "Makefile" ]] || [[ ! -d "scripts" ]]; then
    show_error "Este script debe ejecutarse desde el directorio raíz del proyecto backstage_openwebui"
    exit 1
fi

echo -e "${CYAN}Iniciando despliegue automático de la plataforma...${NC}\n"

# Paso 1: Verificar requisitos
show_progress "1" "5" "Verificando requisitos del sistema"
if ./scripts/setup/verify-requirements.sh; then
    show_success "Requisitos del sistema verificados"
else
    show_error "Los requisitos del sistema no están cumplidos"
    echo -e "${YELLOW}Por favor, instala las herramientas faltantes y vuelve a ejecutar este script${NC}"
    exit 1
fi

# Paso 2: Configurar Minikube
show_progress "2" "5" "Configurando cluster Minikube"
if make minikube-setup; then
    show_success "Cluster Minikube configurado correctamente"
else
    show_error "Error configurando Minikube"
    echo -e "${YELLOW}Intenta ejecutar: make minikube-troubleshoot${NC}"
    exit 1
fi

# Paso 3: Construir imágenes (opcional, usar imágenes pre-construidas por defecto)
show_progress "3" "5" "Preparando imágenes Docker"
echo -e "${CYAN}Usando imágenes pre-construidas para despliegue rápido...${NC}"
show_success "Imágenes Docker preparadas"

# Paso 4: Desplegar plataforma completa
show_progress "4" "5" "Desplegando plataforma completa"
echo -e "${CYAN}Desplegando: PostgreSQL, Backstage, OpenWebUI, Integración, MkDocs, Jenkins...${NC}"
if make deploy-demo; then
    show_success "Plataforma desplegada correctamente"
else
    show_error "Error desplegando la plataforma"
    echo -e "${YELLOW}Verifica el estado con: make status${NC}"
    exit 1
fi

# Paso 5: Configurar acceso local
show_progress "5" "5" "Configurando acceso local"
echo -e "${CYAN}Configurando port-forwarding para acceso local...${NC}"

# Iniciar port-forwarding en background
make port-forward &
PORT_FORWARD_PID=$!

# Esperar un momento para que se establezcan las conexiones
sleep 5

show_success "Acceso local configurado"

# Mostrar información de acceso
echo -e "\n${BOLD}${GREEN}🎉 ¡PLATAFORMA DESPLEGADA EXITOSAMENTE!${NC}\n"

echo -e "${BOLD}${BLUE}📋 INFORMACIÓN DE ACCESO:${NC}"
echo -e "${CYAN}┌─────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                                                         │${NC}"
echo -e "${CYAN}│  🏠 Backstage (Portal Principal):                      │${NC}"
echo -e "${CYAN}│     http://localhost:3000                               │${NC}"
echo -e "${CYAN}│                                                         │${NC}"
echo -e "${CYAN}│  🤖 OpenWebUI (Chat IA):                               │${NC}"
echo -e "${CYAN}│     http://localhost:8080                               │${NC}"
echo -e "${CYAN}│                                                         │${NC}"
echo -e "${CYAN}│  🔧 Jenkins (CI/CD):                                   │${NC}"
echo -e "${CYAN}│     http://localhost:8081                               │${NC}"
echo -e "${CYAN}│     Usuario: admin / Contraseña: admin123              │${NC}"
echo -e "${CYAN}│                                                         │${NC}"
echo -e "${CYAN}│  📚 MkDocs (Documentación):                            │${NC}"
echo -e "${CYAN}│     http://localhost:8082                               │${NC}"
echo -e "${CYAN}│                                                         │${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────────┘${NC}"

echo -e "\n${BOLD}${BLUE}🎮 COMANDOS ÚTILES:${NC}"
echo -e "${CYAN}┌─────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                                                         │${NC}"
echo -e "${CYAN}│  make help           # Ver todos los comandos           │${NC}"
echo -e "${CYAN}│  make status         # Ver estado de servicios         │${NC}"
echo -e "${CYAN}│  make logs           # Ver logs de todos los servicios │${NC}"
echo -e "${CYAN}│  make clean          # Limpiar entorno                 │${NC}"
echo -e "${CYAN}│  make port-forward   # Reconfigurar acceso local       │${NC}"
echo -e "${CYAN}│                                                         │${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────────┘${NC}"

echo -e "\n${BOLD}${BLUE}🚀 CÓMO USAR LA PLATAFORMA:${NC}"
echo -e "${YELLOW}1.${NC} Abre ${BOLD}http://localhost:3000${NC} en tu navegador"
echo -e "${YELLOW}2.${NC} Explora el catálogo de servicios en Backstage"
echo -e "${YELLOW}3.${NC} Usa el chat IA integrado para consultas"
echo -e "${YELLOW}4.${NC} La documentación se genera automáticamente"
echo -e "${YELLOW}5.${NC} Jenkins maneja el CI/CD automáticamente"

echo -e "\n${BOLD}${BLUE}📖 DOCUMENTACIÓN:${NC}"
echo -e "${CYAN}• Estructura del proyecto: docs/estructura-proyecto.md${NC}"
echo -e "${CYAN}• Guías de despliegue: docs/backstage-deployment.md${NC}"
echo -e "${CYAN}• Sistema de integración: integration/README.md${NC}"
echo -e "${CYAN}• Sistema MkDocs: mkdocs/README.md${NC}"

echo -e "\n${BOLD}${BLUE}🔧 TROUBLESHOOTING:${NC}"
echo -e "${CYAN}• Si hay problemas: make minikube-troubleshoot${NC}"
echo -e "${CYAN}• Para reiniciar: make emergency-restart${NC}"
echo -e "${CYAN}• Para limpiar todo: make minikube-cleanup-all${NC}"

echo -e "\n${BOLD}${GREEN}¡Disfruta tu plataforma de desarrollo con IA integrada!${NC} 🎉"

# Mantener el script corriendo para mantener port-forwarding
echo -e "\n${YELLOW}💡 Presiona Ctrl+C para detener el port-forwarding y salir${NC}"
echo -e "${CYAN}   (Los servicios seguirán corriendo en Minikube)${NC}\n"

# Función para limpiar al salir
cleanup() {
    echo -e "\n${YELLOW}🛑 Deteniendo port-forwarding...${NC}"
    if [[ -n "$PORT_FORWARD_PID" ]]; then
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
    
    # Matar todos los procesos de port-forward
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    echo -e "${GREEN}✅ Port-forwarding detenido${NC}"
    echo -e "${CYAN}💡 Para volver a acceder a la plataforma, ejecuta: make port-forward${NC}"
    echo -e "${CYAN}💡 Para ver el estado de los servicios: make status${NC}"
    exit 0
}

# Configurar trap para limpieza al salir
trap cleanup SIGINT SIGTERM

# Esperar indefinidamente manteniendo port-forwarding activo
while true; do
    sleep 10
    # Verificar que port-forwarding sigue activo
    if ! kill -0 $PORT_FORWARD_PID 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Port-forwarding se detuvo, reiniciando...${NC}"
        make port-forward &
        PORT_FORWARD_PID=$!
    fi
done
