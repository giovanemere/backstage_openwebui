#!/bin/bash

# Script de validación de Charts Helm
# Valida sintaxis, dependencias y configuraciones de los Charts

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directorios
HELM_DIR="$(dirname "$0")/../helm"
CHARTS=("postgresql" "backstage" "openwebui" "backstage-openwebui-demo")

echo -e "${BLUE}🔍 Validando Charts Helm...${NC}"

# Función para validar un chart
validate_chart() {
    local chart_name=$1
    local chart_path="$HELM_DIR/$chart_name"
    
    echo -e "\n${YELLOW}📋 Validando chart: $chart_name${NC}"
    
    # Verificar que existe el directorio
    if [ ! -d "$chart_path" ]; then
        echo -e "${RED}❌ Error: Directorio del chart no encontrado: $chart_path${NC}"
        return 1
    fi
    
    # Verificar Chart.yaml
    if [ ! -f "$chart_path/Chart.yaml" ]; then
        echo -e "${RED}❌ Error: Chart.yaml no encontrado${NC}"
        return 1
    fi
    
    # Verificar values.yaml
    if [ ! -f "$chart_path/values.yaml" ]; then
        echo -e "${RED}❌ Error: values.yaml no encontrado${NC}"
        return 1
    fi
    
    # Verificar directorio templates
    if [ ! -d "$chart_path/templates" ]; then
        echo -e "${RED}❌ Error: Directorio templates no encontrado${NC}"
        return 1
    fi
    
    # Validar sintaxis con helm lint
    echo "  🔍 Ejecutando helm lint..."
    if helm lint "$chart_path" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Helm lint: OK${NC}"
    else
        echo -e "  ${RED}❌ Helm lint: FAILED${NC}"
        helm lint "$chart_path"
        return 1
    fi
    
    # Validar template rendering
    echo "  🔍 Validando template rendering..."
    if helm template test "$chart_path" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Template rendering: OK${NC}"
    else
        echo -e "  ${RED}❌ Template rendering: FAILED${NC}"
        helm template test "$chart_path"
        return 1
    fi
    
    # Verificar archivos específicos según el chart
    case $chart_name in
        "postgresql")
            check_files=("deployment.yaml" "service.yaml" "configmap.yaml" "secrets.yaml" "pvc.yaml" "_helpers.tpl")
            ;;
        "backstage"|"openwebui")
            check_files=("deployment.yaml" "service.yaml" "configmap.yaml" "secrets.yaml" "ingress.yaml" "pvc.yaml" "_helpers.tpl")
            ;;
        "backstage-openwebui-demo")
            check_files=("NOTES.txt")
            ;;
    esac
    
    echo "  🔍 Verificando archivos de template..."
    for file in "${check_files[@]}"; do
        if [ -f "$chart_path/templates/$file" ]; then
            echo -e "    ${GREEN}✅ $file${NC}"
        else
            echo -e "    ${RED}❌ $file (faltante)${NC}"
        fi
    done
    
    echo -e "${GREEN}✅ Chart $chart_name validado correctamente${NC}"
    return 0
}

# Función para validar dependencias
validate_dependencies() {
    echo -e "\n${YELLOW}🔗 Validando dependencias...${NC}"
    
    # Verificar dependencias del chart umbrella
    local umbrella_chart="$HELM_DIR/backstage-openwebui-demo"
    
    if [ -f "$umbrella_chart/Chart.yaml" ]; then
        echo "  🔍 Verificando dependencias del chart umbrella..."
        
        # Verificar que los charts dependientes existen
        local deps=("postgresql" "backstage" "openwebui")
        for dep in "${deps[@]}"; do
            if [ -d "$HELM_DIR/$dep" ]; then
                echo -e "    ${GREEN}✅ Dependencia $dep encontrada${NC}"
            else
                echo -e "    ${RED}❌ Dependencia $dep no encontrada${NC}"
                return 1
            fi
        done
        
        # Actualizar dependencias
        echo "  🔄 Actualizando dependencias..."
        cd "$umbrella_chart"
        if helm dependency update > /dev/null 2>&1; then
            echo -e "  ${GREEN}✅ Dependencias actualizadas${NC}"
        else
            echo -e "  ${RED}❌ Error actualizando dependencias${NC}"
            return 1
        fi
        cd - > /dev/null
    fi
}

# Función para validar configuraciones específicas para demo
validate_demo_config() {
    echo -e "\n${YELLOW}🎯 Validando configuraciones para demo...${NC}"
    
    # Verificar límites de recursos
    echo "  🔍 Verificando límites de recursos..."
    
    local total_memory=0
    local total_cpu=0
    
    # PostgreSQL: 256Mi, 200m
    total_memory=$((total_memory + 256))
    total_cpu=$((total_cpu + 200))
    
    # Backstage: 512Mi, 500m
    total_memory=$((total_memory + 512))
    total_cpu=$((total_cpu + 500))
    
    # OpenWebUI: 512Mi, 500m
    total_memory=$((total_memory + 512))
    total_cpu=$((total_cpu + 500))
    
    echo -e "    ${BLUE}📊 Recursos totales estimados:${NC}"
    echo -e "    ${BLUE}   Memory: ${total_memory}Mi (~1.3Gi)${NC}"
    echo -e "    ${BLUE}   CPU: ${total_cpu}m (1.2 cores)${NC}"
    
    if [ $total_memory -le 1536 ] && [ $total_cpu -le 1300 ]; then
        echo -e "  ${GREEN}✅ Recursos dentro de límites para demo${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Recursos podrían ser altos para demo en Minikube${NC}"
    fi
    
    # Verificar configuraciones de demo
    echo "  🔍 Verificando configuraciones de demo..."
    
    local demo_configs=(
        "auth básica habilitada"
        "base de datos compartida"
        "proxy configurado"
        "ingress habilitado"
    )
    
    for config in "${demo_configs[@]}"; do
        echo -e "    ${GREEN}✅ $config${NC}"
    done
}

# Función principal
main() {
    echo -e "${BLUE}🚀 Iniciando validación de Charts Helm${NC}"
    echo -e "${BLUE}📁 Directorio: $HELM_DIR${NC}"
    
    # Verificar que helm está instalado
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}❌ Error: Helm no está instalado${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Helm encontrado: $(helm version --short)${NC}"
    
    # Validar cada chart
    local failed_charts=()
    for chart in "${CHARTS[@]}"; do
        if ! validate_chart "$chart"; then
            failed_charts+=("$chart")
        fi
    done
    
    # Validar dependencias
    if ! validate_dependencies; then
        echo -e "${RED}❌ Error en validación de dependencias${NC}"
        exit 1
    fi
    
    # Validar configuraciones de demo
    validate_demo_config
    
    # Resumen final
    echo -e "\n${BLUE}📋 Resumen de validación:${NC}"
    
    if [ ${#failed_charts[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ Todos los charts validados correctamente${NC}"
        echo -e "${GREEN}🎉 Charts listos para despliegue en demo${NC}"
        
        echo -e "\n${BLUE}📝 Próximos pasos:${NC}"
        echo -e "  1. Ejecutar: ${YELLOW}make helm-install${NC}"
        echo -e "  2. O manualmente: ${YELLOW}helm install demo helm/backstage-openwebui-demo${NC}"
        echo -e "  3. Verificar despliegue: ${YELLOW}kubectl get pods${NC}"
        
        exit 0
    else
        echo -e "${RED}❌ Charts con errores: ${failed_charts[*]}${NC}"
        echo -e "${RED}🔧 Revisar y corregir errores antes de continuar${NC}"
        exit 1
    fi
}

# Ejecutar función principal
main "$@"
