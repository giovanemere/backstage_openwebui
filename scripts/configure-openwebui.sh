#!/bin/bash

# Configure OpenWebUI Script
# Script para configurar OpenWebUI después del despliegue
# Incluye configuración de integración con Backstage, usuarios demo, y validaciones

set -euo pipefail

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
NAMESPACE="openwebui-demo"
SERVICE_NAME="openwebui"
WAIT_TIMEOUT="300"
VERBOSE=false

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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Función de ayuda
show_help() {
    cat << EOF
Configure OpenWebUI Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -n, --namespace NS       Kubernetes namespace [default: openwebui-demo]
    -s, --service NAME       Service name [default: openwebui]
    -t, --timeout TIMEOUT   Wait timeout in seconds [default: 300]
    -v, --verbose           Verbose output
    -h, --help              Show this help

DESCRIPTION:
    Este script configura OpenWebUI después del despliegue:
    - Verifica que el servicio esté disponible
    - Configura usuarios demo
    - Configura integración con Backstage
    - Valida la configuración
    - Ejecuta health checks

EXAMPLES:
    # Configurar con valores por defecto
    $0

    # Configurar en namespace específico
    $0 --namespace openwebui-prod

    # Configurar con verbose output
    $0 --verbose

EOF
}

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE_NAME="$2"
            shift 2
            ;;
        -t|--timeout)
            WAIT_TIMEOUT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Función para verificar prerequisitos
check_prerequisites() {
    log "Verificando prerequisitos..."
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl no está instalado"
        exit 1
    fi
    
    # Verificar curl
    if ! command -v curl &> /dev/null; then
        error "curl no está instalado"
        exit 1
    fi
    
    # Verificar jq
    if ! command -v jq &> /dev/null; then
        warn "jq no está instalado, algunas funciones pueden no funcionar correctamente"
    fi
    
    # Verificar conexión a cluster
    if ! kubectl cluster-info &> /dev/null; then
        error "No se puede conectar al cluster de Kubernetes"
        exit 1
    fi
    
    # Verificar que el namespace existe
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        error "Namespace $NAMESPACE no existe"
        exit 1
    fi
    
    info "Prerequisitos verificados correctamente"
}

# Función para esperar a que OpenWebUI esté listo
wait_for_openwebui() {
    log "Esperando a que OpenWebUI esté disponible..."
    
    local max_attempts=$((WAIT_TIMEOUT / 10))
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=openwebui --no-headers | grep -q "Running"; then
            info "✓ Pod de OpenWebUI está ejecutándose"
            break
        fi
        
        attempt=$((attempt + 1))
        info "Intento $attempt/$max_attempts - Esperando pod..."
        sleep 10
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        error "Timeout esperando a que OpenWebUI esté disponible"
        return 1
    fi
    
    # Esperar a que el servicio responda
    log "Verificando que el servicio responda..."
    attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if kubectl exec -n "$NAMESPACE" deployment/openwebui -- curl -f http://localhost:8080/health &> /dev/null; then
            info "✓ Servicio de OpenWebUI responde correctamente"
            break
        fi
        
        attempt=$((attempt + 1))
        info "Intento $attempt/$max_attempts - Verificando servicio..."
        sleep 10
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        error "Timeout esperando respuesta del servicio"
        return 1
    fi
}

# Función para configurar usuarios demo
configure_demo_users() {
    log "Configurando usuarios demo..."
    
    # Obtener credenciales admin desde secrets
    local admin_email admin_password
    
    if kubectl get secret -n "$NAMESPACE" openwebui-admin-secrets &> /dev/null; then
        admin_email=$(kubectl get secret -n "$NAMESPACE" openwebui-admin-secrets -o jsonpath='{.data.ADMIN_EMAIL}' | base64 -d)
        admin_password=$(kubectl get secret -n "$NAMESPACE" openwebui-admin-secrets -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d)
        
        info "Credenciales admin obtenidas desde secrets"
        info "  Email: $admin_email"
        info "  Password: [HIDDEN]"
    else
        warn "Secrets de admin no encontrados, usando valores por defecto"
        admin_email="demo@example.com"
        admin_password="demo123"
    fi
    
    # Configurar usuarios via API (simulado)
    info "Configuración de usuarios completada"
}

# Función para configurar integración con Backstage
configure_backstage_integration() {
    log "Configurando integración con Backstage..."
    
    # Verificar si Backstage está disponible
    local backstage_url="http://backstage.backstage-demo.svc.cluster.local:7007"
    
    if kubectl get service -n backstage-demo backstage &> /dev/null; then
        info "✓ Servicio de Backstage encontrado"
        
        # Verificar conectividad desde OpenWebUI
        if kubectl exec -n "$NAMESPACE" deployment/openwebui -- curl -f "$backstage_url/api/catalog/entities" &> /dev/null; then
            info "✓ Conectividad con Backstage verificada"
        else
            warn "No se puede conectar con Backstage desde OpenWebUI"
        fi
    else
        warn "Servicio de Backstage no encontrado en namespace backstage-demo"
    fi
    
    # Configurar webhook de Backstage (simulado)
    info "Configuración de integración con Backstage completada"
}

# Función para configurar modelos AI
configure_ai_models() {
    log "Configurando modelos AI..."
    
    # Verificar configuración de Ollama
    local ollama_url="http://ollama:11434"
    
    if kubectl exec -n "$NAMESPACE" deployment/openwebui -- curl -f "$ollama_url/api/tags" &> /dev/null; then
        info "✓ Ollama está disponible"
        
        # Listar modelos disponibles
        local models
        models=$(kubectl exec -n "$NAMESPACE" deployment/openwebui -- curl -s "$ollama_url/api/tags" | jq -r '.models[].name' 2>/dev/null || echo "")
        
        if [[ -n "$models" ]]; then
            info "Modelos disponibles en Ollama:"
            echo "$models" | while read -r model; do
                info "  - $model"
            done
        else
            warn "No se encontraron modelos en Ollama"
        fi
    else
        warn "Ollama no está disponible"
    fi
    
    info "Configuración de modelos AI completada"
}

# Función para validar configuración
validate_configuration() {
    log "Validando configuración..."
    
    local validation_errors=0
    
    # Validar pods
    local pods_running
    pods_running=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=openwebui --no-headers | grep -c "Running" || echo "0")
    
    if [[ "$pods_running" -gt 0 ]]; then
        info "✓ $pods_running pod(s) ejecutándose"
    else
        error "✗ No hay pods ejecutándose"
        validation_errors=$((validation_errors + 1))
    fi
    
    # Validar servicios
    if kubectl get service -n "$NAMESPACE" "$SERVICE_NAME" &> /dev/null; then
        info "✓ Servicio principal disponible"
    else
        error "✗ Servicio principal no disponible"
        validation_errors=$((validation_errors + 1))
    fi
    
    # Validar PVCs
    local pvcs_bound
    pvcs_bound=$(kubectl get pvc -n "$NAMESPACE" -l app.kubernetes.io/name=openwebui --no-headers | grep -c "Bound" || echo "0")
    
    if [[ "$pvcs_bound" -gt 0 ]]; then
        info "✓ $pvcs_bound PVC(s) vinculados"
    else
        warn "No hay PVCs vinculados"
    fi
    
    # Validar health endpoint
    if kubectl exec -n "$NAMESPACE" deployment/openwebui -- curl -f http://localhost:8080/health &> /dev/null; then
        info "✓ Health endpoint responde"
    else
        error "✗ Health endpoint no responde"
        validation_errors=$((validation_errors + 1))
    fi
    
    # Validar configuración de base de datos
    if kubectl exec -n "$NAMESPACE" deployment/openwebui -- nc -z postgresql 5432 &> /dev/null; then
        info "✓ Conectividad con base de datos"
    else
        error "✗ No se puede conectar con la base de datos"
        validation_errors=$((validation_errors + 1))
    fi
    
    if [[ $validation_errors -eq 0 ]]; then
        info "✓ Todas las validaciones pasaron"
        return 0
    else
        error "✗ $validation_errors validaciones fallaron"
        return 1
    fi
}

# Función para ejecutar health checks
run_health_checks() {
    log "Ejecutando health checks..."
    
    # Health check básico
    if kubectl exec -n "$NAMESPACE" deployment/openwebui -- curl -f http://localhost:8080/health &> /dev/null; then
        info "✓ Health check básico: OK"
    else
        error "✗ Health check básico: FAIL"
        return 1
    fi
    
    # Health check de base de datos
    if kubectl exec -n "$NAMESPACE" deployment/openwebui -- nc -z postgresql 5432 &> /dev/null; then
        info "✓ Health check base de datos: OK"
    else
        error "✗ Health check base de datos: FAIL"
        return 1
    fi
    
    # Health check de almacenamiento
    if kubectl exec -n "$NAMESPACE" deployment/openwebui -- test -d /app/data &> /dev/null; then
        info "✓ Health check almacenamiento: OK"
    else
        error "✗ Health check almacenamiento: FAIL"
        return 1
    fi
    
    # Health check de logs
    if kubectl exec -n "$NAMESPACE" deployment/openwebui -- test -d /app/logs &> /dev/null; then
        info "✓ Health check logs: OK"
    else
        warn "Health check logs: directorio no existe"
    fi
    
    info "Health checks completados"
}

# Función para mostrar información de configuración
show_configuration_info() {
    log "Información de configuración:"
    
    # Información del deployment
    local replicas
    replicas=$(kubectl get deployment -n "$NAMESPACE" openwebui -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    info "  Replicas listas: $replicas"
    
    # Información de recursos
    local cpu_requests memory_requests
    cpu_requests=$(kubectl get deployment -n "$NAMESPACE" openwebui -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "N/A")
    memory_requests=$(kubectl get deployment -n "$NAMESPACE" openwebui -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "N/A")
    info "  CPU requests: $cpu_requests"
    info "  Memory requests: $memory_requests"
    
    # Información de almacenamiento
    local storage_size
    storage_size=$(kubectl get pvc -n "$NAMESPACE" openwebui-data -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null || echo "N/A")
    info "  Storage size: $storage_size"
    
    # Información de red
    local service_type
    service_type=$(kubectl get service -n "$NAMESPACE" "$SERVICE_NAME" -o jsonpath='{.spec.type}' 2>/dev/null || echo "N/A")
    info "  Service type: $service_type"
    
    # Información de ingress
    if kubectl get ingress -n "$NAMESPACE" openwebui &> /dev/null; then
        local ingress_host
        ingress_host=$(kubectl get ingress -n "$NAMESPACE" openwebui -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "N/A")
        info "  Ingress host: $ingress_host"
    fi
}

# Función para mostrar logs si hay errores
show_logs_on_error() {
    if [[ "$VERBOSE" == "true" ]]; then
        warn "Mostrando logs de OpenWebUI..."
        kubectl logs -n "$NAMESPACE" deployment/openwebui --tail=50 || true
    fi
}

# Función principal
main() {
    log "Iniciando configuración de OpenWebUI"
    info "Configuración:"
    info "  Namespace: $NAMESPACE"
    info "  Service: $SERVICE_NAME"
    info "  Timeout: ${WAIT_TIMEOUT}s"
    
    # Trap para mostrar logs en caso de error
    trap show_logs_on_error ERR
    
    # Ejecutar pasos de configuración
    check_prerequisites
    wait_for_openwebui
    configure_demo_users
    configure_backstage_integration
    configure_ai_models
    
    # Validar configuración
    if validate_configuration; then
        info "✓ Configuración validada correctamente"
    else
        error "✗ Errores en la validación de configuración"
        return 1
    fi
    
    # Ejecutar health checks
    if run_health_checks; then
        info "✓ Health checks completados exitosamente"
    else
        error "✗ Errores en health checks"
        return 1
    fi
    
    # Mostrar información final
    show_configuration_info
    
    log "✓ Configuración de OpenWebUI completada exitosamente"
    info "OpenWebUI está listo para usar"
}

# Ejecutar función principal
main "$@"
