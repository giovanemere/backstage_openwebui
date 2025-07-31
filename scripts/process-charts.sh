#!/bin/bash

# Script para procesar variables de entorno en Chart.yaml
# Uso: ./scripts/process-charts.sh

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔄 Procesando Charts con variables de entorno...${NC}"

# Verificar si existe .env
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo -e "${YELLOW}⚠️  Archivo .env no encontrado. Copiando desde .env.example...${NC}"
        cp .env.example .env
    else
        echo -e "${RED}❌ No se encontró .env ni .env.example${NC}"
        exit 1
    fi
fi

# Cargar variables de entorno
echo -e "${GREEN}📋 Cargando variables de entorno...${NC}"
set -a  # Exportar automáticamente todas las variables
source .env
set +a

# Función para procesar un Chart.yaml
process_chart() {
    local chart_dir="$1"
    local chart_name=$(basename "$chart_dir")
    
    echo -e "${GREEN}🔧 Procesando chart: ${chart_name}${NC}"
    
    # Verificar si existe Chart.yaml
    if [ ! -f "${chart_dir}/Chart.yaml" ]; then
        echo -e "${RED}❌ No se encontró Chart.yaml en ${chart_dir}${NC}"
        return 1
    fi
    
    # Crear backup del Chart.yaml original
    if [ ! -f "${chart_dir}/Chart.yaml.backup" ]; then
        cp "${chart_dir}/Chart.yaml" "${chart_dir}/Chart.yaml.backup"
        echo -e "${YELLOW}💾 Backup creado: ${chart_dir}/Chart.yaml.backup${NC}"
    fi
    
    # Procesar variables usando envsubst
    envsubst < "${chart_dir}/Chart.yaml.backup" > "${chart_dir}/Chart.yaml.tmp"
    
    # Verificar que el archivo procesado es válido YAML
    if command -v yq >/dev/null 2>&1; then
        if yq eval '.' "${chart_dir}/Chart.yaml.tmp" >/dev/null 2>&1; then
            mv "${chart_dir}/Chart.yaml.tmp" "${chart_dir}/Chart.yaml"
            echo -e "${GREEN}✅ Chart procesado exitosamente: ${chart_name}${NC}"
        else
            echo -e "${RED}❌ Error: YAML inválido generado para ${chart_name}${NC}"
            rm "${chart_dir}/Chart.yaml.tmp"
            return 1
        fi
    else
        # Si no hay yq, asumir que está bien
        mv "${chart_dir}/Chart.yaml.tmp" "${chart_dir}/Chart.yaml"
        echo -e "${YELLOW}⚠️  Chart procesado (sin validación YAML): ${chart_name}${NC}"
    fi
}

# Función para restaurar backups
restore_backups() {
    echo -e "${YELLOW}🔄 Restaurando backups originales...${NC}"
    for chart_dir in helm/*/; do
        if [ -f "${chart_dir}/Chart.yaml.backup" ]; then
            cp "${chart_dir}/Chart.yaml.backup" "${chart_dir}/Chart.yaml"
            echo -e "${GREEN}✅ Restaurado: $(basename "$chart_dir")${NC}"
        fi
    done
}

# Función para limpiar backups
clean_backups() {
    echo -e "${YELLOW}🧹 Limpiando archivos de backup...${NC}"
    for chart_dir in helm/*/; do
        if [ -f "${chart_dir}/Chart.yaml.backup" ]; then
            rm "${chart_dir}/Chart.yaml.backup"
            echo -e "${GREEN}🗑️  Eliminado backup: $(basename "$chart_dir")${NC}"
        fi
    done
}

# Procesar argumentos de línea de comandos
case "${1:-process}" in
    "process")
        echo -e "${GREEN}🚀 Iniciando procesamiento de charts...${NC}"
        
        # Procesar cada directorio de chart
        for chart_dir in helm/*/; do
            if [ -d "$chart_dir" ] && [ -f "${chart_dir}/Chart.yaml" ]; then
                process_chart "$chart_dir"
            fi
        done
        
        echo -e "${GREEN}🎉 Procesamiento completado!${NC}"
        echo -e "${YELLOW}💡 Para restaurar los originales, ejecuta: $0 restore${NC}"
        ;;
        
    "restore")
        restore_backups
        echo -e "${GREEN}🎉 Restauración completada!${NC}"
        ;;
        
    "clean")
        clean_backups
        echo -e "${GREEN}🎉 Limpieza completada!${NC}"
        ;;
        
    "validate")
        echo -e "${GREEN}🔍 Validando charts procesados...${NC}"
        
        # Validar cada chart con helm lint
        for chart_dir in helm/*/; do
            if [ -d "$chart_dir" ] && [ -f "${chart_dir}/Chart.yaml" ]; then
                chart_name=$(basename "$chart_dir")
                echo -e "${GREEN}🔍 Validando: ${chart_name}${NC}"
                
                if helm lint "$chart_dir" >/dev/null 2>&1; then
                    echo -e "${GREEN}✅ Válido: ${chart_name}${NC}"
                else
                    echo -e "${RED}❌ Error en: ${chart_name}${NC}"
                    helm lint "$chart_dir"
                fi
            fi
        done
        ;;
        
    "help"|"-h"|"--help")
        echo -e "${GREEN}📖 Uso del script process-charts.sh${NC}"
        echo ""
        echo -e "${YELLOW}Comandos disponibles:${NC}"
        echo "  process   - Procesar charts con variables de entorno (default)"
        echo "  restore   - Restaurar charts originales desde backups"
        echo "  clean     - Limpiar archivos de backup"
        echo "  validate  - Validar charts procesados con helm lint"
        echo "  help      - Mostrar esta ayuda"
        echo ""
        echo -e "${YELLOW}Ejemplos:${NC}"
        echo "  $0                    # Procesar charts"
        echo "  $0 process            # Procesar charts"
        echo "  $0 restore            # Restaurar originales"
        echo "  $0 validate           # Validar charts"
        echo ""
        echo -e "${YELLOW}Variables utilizadas (desde .env):${NC}"
        echo "  - BACKSTAGE_CHART_VERSION, BACKSTAGE_APP_VERSION"
        echo "  - OPENWEBUI_CHART_VERSION, OPENWEBUI_APP_VERSION"
        echo "  - POSTGRESQL_CHART_VERSION, POSTGRESQL_APP_VERSION"
        echo "  - DEMO_CHART_VERSION, DEMO_APP_VERSION"
        echo "  - CHART_MAINTAINER_NAME, CHART_MAINTAINER_EMAIL"
        echo "  - CHART_HOME_URL, CHART_SOURCE_URL"
        echo "  - Y muchas más..."
        ;;
        
    *)
        echo -e "${RED}❌ Comando desconocido: $1${NC}"
        echo -e "${YELLOW}💡 Usa '$0 help' para ver los comandos disponibles${NC}"
        exit 1
        ;;
esac
