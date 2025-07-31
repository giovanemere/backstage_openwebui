#!/bin/bash

# Script de Despliegue de Integración Backstage-OpenWebUI
# Implementa la Tarea 9: Integración Técnica

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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Verificar prerrequisitos
check_prerequisites() {
    log "Verificando prerrequisitos..."
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl no está instalado"
        exit 1
    fi
    
    # Verificar conexión a cluster
    if ! kubectl cluster-info &> /dev/null; then
        error "No se puede conectar al cluster de Kubernetes"
        exit 1
    fi
    
    # Verificar minikube (si aplica)
    if command -v minikube &> /dev/null; then
        if minikube status | grep -q "Running"; then
            info "Minikube está ejecutándose"
        else
            warn "Minikube no está ejecutándose"
        fi
    fi
    
    log "Prerrequisitos verificados ✓"
}

# Crear namespace de integración
create_namespace() {
    log "Creando namespace de integración..."
    
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: integration-demo
  labels:
    app.kubernetes.io/name: integration-demo
    app.kubernetes.io/part-of: backstage-openwebui-demo
    integration.demo/purpose: integration
  annotations:
    demo.minikube/optimized: "true"
    demo.minikube/description: "Namespace para integración Backstage-OpenWebUI"
EOF
    
    log "Namespace integration-demo creado ✓"
}

# Desplegar configuraciones de integración
deploy_integration_configs() {
    log "Desplegando configuraciones de integración..."
    
    # Aplicar configuración principal
    kubectl apply -f configs/integration-config.yaml
    
    # Verificar que los ConfigMaps se crearon
    kubectl wait --for=condition=Ready configmap/backstage-openwebui-integration -n integration-demo --timeout=60s
    
    log "Configuraciones de integración desplegadas ✓"
}

# Desplegar API de integración
deploy_integration_api() {
    log "Desplegando API de integración..."
    
    # Aplicar servicio de integración
    kubectl apply -f apis/integration-service.yaml
    
    # Esperar a que el deployment esté listo
    kubectl wait --for=condition=Available deployment/backstage-openwebui-integration -n integration-demo --timeout=300s
    
    # Verificar que el servicio está funcionando
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=integration-api -n integration-demo --timeout=180s
    
    log "API de integración desplegada ✓"
}

# Configurar webhooks
setup_webhooks() {
    log "Configurando webhooks..."
    
    # Aplicar configuración de webhooks de Backstage
    kubectl apply -f webhooks/backstage-webhook-config.yaml
    
    # Aplicar configuración de webhooks de OpenWebUI
    kubectl apply -f webhooks/openwebui-webhook-config.yaml
    
    log "Webhooks configurados ✓"
}

# Verificar conectividad entre servicios
verify_connectivity() {
    log "Verificando conectividad entre servicios..."
    
    # Verificar que los servicios están ejecutándose
    local services=(
        "backstage.backstage-demo"
        "openwebui.openwebui-demo"
        "backstage-openwebui-integration.integration-demo"
    )
    
    for service in "${services[@]}"; do
        if kubectl get service "${service%.*}" -n "${service#*.}" &> /dev/null; then
            info "Servicio $service encontrado ✓"
        else
            warn "Servicio $service no encontrado"
        fi
    done
    
    # Test de conectividad de la API de integración
    log "Probando API de integración..."
    
    # Port-forward temporal para test
    kubectl port-forward -n integration-demo service/backstage-openwebui-integration 8000:8000 &
    local pf_pid=$!
    
    sleep 5
    
    # Test health endpoint
    if curl -s http://localhost:8000/health | grep -q '"status":"ok"'; then
        log "API de integración respondiendo correctamente ✓"
    else
        warn "API de integración no responde correctamente"
    fi
    
    # Limpiar port-forward
    kill $pf_pid 2>/dev/null || true
    
    log "Verificación de conectividad completada ✓"
}

# Configurar acceso externo (opcional)
setup_external_access() {
    log "Configurando acceso externo..."
    
    # Verificar si hay ingress controller
    if kubectl get ingressclass &> /dev/null; then
        info "Ingress controller detectado, configurando ingress..."
        
        # El ingress ya está incluido en integration-service.yaml
        # Verificar que se creó correctamente
        if kubectl get ingress backstage-openwebui-integration -n integration-demo &> /dev/null; then
            log "Ingress configurado ✓"
            
            # Si es minikube, habilitar ingress addon
            if command -v minikube &> /dev/null; then
                minikube addons enable ingress 2>/dev/null || true
                info "Para acceder externamente: minikube tunnel"
            fi
        fi
    else
        info "No hay ingress controller, usando port-forward para acceso externo"
        info "Ejecutar: kubectl port-forward -n integration-demo service/backstage-openwebui-integration 8000:8000"
    fi
}

# Mostrar información de despliegue
show_deployment_info() {
    log "Información del despliegue:"
    
    echo ""
    echo "=== SERVICIOS DESPLEGADOS ==="
    kubectl get services -n integration-demo -o wide
    
    echo ""
    echo "=== PODS ==="
    kubectl get pods -n integration-demo -o wide
    
    echo ""
    echo "=== CONFIGMAPS ==="
    kubectl get configmaps -n integration-demo
    
    echo ""
    echo "=== SECRETS ==="
    kubectl get secrets -n integration-demo
    
    echo ""
    echo "=== ENDPOINTS DE INTEGRACIÓN ==="
    echo "• API de Integración: http://backstage-openwebui-integration.integration-demo.svc.cluster.local:8000"
    echo "• Health Check: http://localhost:8000/health (con port-forward)"
    echo "• Swagger UI: http://localhost:8000/docs (con port-forward)"
    
    echo ""
    echo "=== COMANDOS ÚTILES ==="
    echo "• Ver logs de integración: kubectl logs -f deployment/backstage-openwebui-integration -n integration-demo"
    echo "• Port-forward API: kubectl port-forward -n integration-demo service/backstage-openwebui-integration 8000:8000"
    echo "• Test health: curl http://localhost:8000/health"
    echo "• Ver configuración: kubectl get configmap backstage-openwebui-integration -n integration-demo -o yaml"
}

# Función de limpieza
cleanup() {
    log "Limpiando recursos de integración..."
    
    # Eliminar recursos en orden inverso
    kubectl delete -f webhooks/openwebui-webhook-config.yaml --ignore-not-found=true
    kubectl delete -f webhooks/backstage-webhook-config.yaml --ignore-not-found=true
    kubectl delete -f apis/integration-service.yaml --ignore-not-found=true
    kubectl delete -f configs/integration-config.yaml --ignore-not-found=true
    
    # Eliminar namespace (esto eliminará todo lo que quede)
    kubectl delete namespace integration-demo --ignore-not-found=true
    
    log "Limpieza completada ✓"
}

# Función principal
main() {
    local action="${1:-deploy}"
    
    case $action in
        "deploy")
            log "=== INICIANDO DESPLIEGUE DE INTEGRACIÓN BACKSTAGE-OPENWEBUI ==="
            check_prerequisites
            create_namespace
            deploy_integration_configs
            deploy_integration_api
            setup_webhooks
            verify_connectivity
            setup_external_access
            show_deployment_info
            log "=== DESPLIEGUE DE INTEGRACIÓN COMPLETADO ✓ ==="
            ;;
        "cleanup")
            log "=== INICIANDO LIMPIEZA DE INTEGRACIÓN ==="
            cleanup
            log "=== LIMPIEZA COMPLETADA ✓ ==="
            ;;
        "status")
            log "=== ESTADO DE LA INTEGRACIÓN ==="
            show_deployment_info
            ;;
        "test")
            log "=== PROBANDO INTEGRACIÓN ==="
            verify_connectivity
            ;;
        *)
            echo "Uso: $0 {deploy|cleanup|status|test}"
            echo ""
            echo "Comandos:"
            echo "  deploy  - Desplegar integración completa"
            echo "  cleanup - Limpiar todos los recursos"
            echo "  status  - Mostrar estado actual"
            echo "  test    - Probar conectividad"
            exit 1
            ;;
    esac
}

# Ejecutar función principal con argumentos
main "$@"
