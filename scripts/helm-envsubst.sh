#!/bin/bash

# Script para procesar variables de entorno en valores de Helm
# Uso: ./scripts/helm-envsubst.sh [chart-name] [values-file]

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Función para mostrar ayuda
show_help() {
    cat << EOF
Uso: $0 [OPCIONES] [CHART_NAME]

Procesa variables de entorno en archivos values.yaml de Helm Charts.

OPCIONES:
    -h, --help          Mostrar esta ayuda
    -e, --env-file      Archivo .env a cargar (default: .env)
    -v, --values-file   Archivo values.yaml específico
    -o, --output        Directorio de salida (default: /tmp/helm-processed)
    -d, --dry-run       Solo mostrar qué se procesaría
    --validate          Validar sintaxis después del procesamiento

CHART_NAME:
    backstage           Procesar chart de Backstage
    openwebui           Procesar chart de OpenWebUI
    postgresql          Procesar chart de PostgreSQL
    umbrella            Procesar chart umbrella
    all                 Procesar todos los charts (default)

EJEMPLOS:
    $0                                  # Procesar todos los charts
    $0 backstage                        # Procesar solo Backstage
    $0 -e .env.prod umbrella           # Usar archivo .env.prod
    $0 --dry-run all                   # Ver qué se procesaría
    $0 --validate backstage            # Procesar y validar

VARIABLES DE ENTORNO REQUERIDAS:
    Las variables se cargan desde el archivo .env especificado.
    Ver .env.example para la lista completa de variables disponibles.

EOF
}

# Valores por defecto
ENV_FILE=".env"
OUTPUT_DIR="/tmp/helm-processed"
DRY_RUN=false
VALIDATE=false
CHART_NAME="all"
VALUES_FILE=""

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -e|--env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        -v|--values-file)
            VALUES_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --validate)
            VALIDATE=true
            shift
            ;;
        backstage|openwebui|postgresql|umbrella|all)
            CHART_NAME="$1"
            shift
            ;;
        *)
            error "Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Verificar que existe el archivo .env
if [[ ! -f "$ENV_FILE" ]]; then
    error "Archivo de entorno no encontrado: $ENV_FILE"
    echo "Crea el archivo copiando desde .env.example:"
    echo "cp .env.example $ENV_FILE"
    exit 1
fi

# Cargar variables de entorno
log "Cargando variables de entorno desde: $ENV_FILE"
set -a  # Exportar automáticamente todas las variables
source "$ENV_FILE"
set +a

# Función para procesar un archivo values.yaml
process_values_file() {
    local chart_path="$1"
    local values_file="$2"
    local output_file="$3"
    
    if [[ ! -f "$values_file" ]]; then
        warn "Archivo values.yaml no encontrado: $values_file"
        return 1
    fi
    
    log "Procesando: $values_file -> $output_file"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] Se procesaría: $values_file"
        return 0
    fi
    
    # Crear directorio de salida si no existe
    mkdir -p "$(dirname "$output_file")"
    
    # Procesar variables de entorno usando envsubst
    envsubst < "$values_file" > "$output_file"
    
    # Validar sintaxis YAML si se solicita
    if [[ "$VALIDATE" == "true" ]]; then
        if command -v yq >/dev/null 2>&1; then
            if yq eval '.' "$output_file" >/dev/null 2>&1; then
                log "✓ Sintaxis YAML válida: $output_file"
            else
                error "✗ Sintaxis YAML inválida: $output_file"
                return 1
            fi
        else
            warn "yq no está instalado, saltando validación YAML"
        fi
    fi
    
    log "✓ Procesado exitosamente: $output_file"
}

# Función para procesar un chart específico
process_chart() {
    local chart="$1"
    local chart_path="helm/$chart"
    
    if [[ ! -d "$chart_path" ]]; then
        warn "Chart no encontrado: $chart_path"
        return 1
    fi
    
    log "Procesando chart: $chart"
    
    # Determinar archivo values.yaml
    local values_file
    if [[ -n "$VALUES_FILE" ]]; then
        values_file="$VALUES_FILE"
    else
        values_file="$chart_path/values.yaml"
    fi
    
    # Archivo de salida
    local output_file="$OUTPUT_DIR/$chart/values.yaml"
    
    # Procesar el archivo
    process_values_file "$chart_path" "$values_file" "$output_file"
}

# Función principal
main() {
    log "Iniciando procesamiento de variables de entorno en Helm Charts"
    log "Chart: $CHART_NAME"
    log "Archivo .env: $ENV_FILE"
    log "Directorio de salida: $OUTPUT_DIR"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        warn "Modo DRY-RUN activado - no se realizarán cambios"
    fi
    
    # Procesar charts según la selección
    case "$CHART_NAME" in
        "all")
            log "Procesando todos los charts..."
            process_chart "postgresql"
            process_chart "backstage"
            process_chart "openwebui"
            process_chart "backstage-openwebui-demo"
            ;;
        "umbrella")
            process_chart "backstage-openwebui-demo"
            ;;
        *)
            process_chart "$CHART_NAME"
            ;;
    esac
    
    if [[ "$DRY_RUN" == "false" ]]; then
        log "✓ Procesamiento completado"
        log "Archivos procesados disponibles en: $OUTPUT_DIR"
        echo
        echo "Para usar los archivos procesados con Helm:"
        echo "  helm install my-release helm/backstage-openwebui-demo -f $OUTPUT_DIR/backstage-openwebui-demo/values.yaml"
        echo
        echo "Para validar los charts procesados:"
        echo "  helm lint $OUTPUT_DIR/backstage-openwebui-demo"
    fi
}

# Verificar dependencias
check_dependencies() {
    local missing_deps=()
    
    if ! command -v envsubst >/dev/null 2>&1; then
        missing_deps+=("envsubst (gettext)")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Dependencias faltantes:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo
        echo "En Ubuntu/Debian: sudo apt-get install gettext-base"
        echo "En macOS: brew install gettext"
        exit 1
    fi
}

# Ejecutar verificaciones y función principal
check_dependencies
main

log "Script completado exitosamente"
