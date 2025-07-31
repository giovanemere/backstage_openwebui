#!/bin/bash

# =============================================================================
# Script de Validación Final para Setup de Minikube
# =============================================================================
# Valida que el cluster esté completamente configurado y listo para el demo

set -euo pipefail

# Colores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuración
readonly CLUSTER_NAME="backstage-demo"
readonly REQUIRED_NAMESPACES=("backstage-demo" "jenkins" "argocd" "monitoring")
readonly REQUIRED_ADDONS=("ingress" "dashboard" "metrics-server" "storage-provisioner")

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

log_step() {
    echo -e "\n${PURPLE}=== $1 ===${NC}"
}

show_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                    ✅ VALIDACIÓN FINAL - MINIKUBE SETUP                     ║
║                                                                              ║
║                        Verificación Completa del Demo                       ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
}

validate_cluster_running() {
    log_step "Validando Estado del Cluster"
    
    if ! minikube status -p "$CLUSTER_NAME" &> /dev/null; then
        log_error "❌ Cluster '$CLUSTER_NAME' no está ejecutándose"
        return 1
    fi
    
    log_success "✅ Cluster '$CLUSTER_NAME' está ejecutándose"
    
    # Verificar nodos
    local node_status
    node_status=$(kubectl get nodes --no-headers | awk '{print $2}' | head -1)
    
    if [[ "$node_status" != "Ready" ]]; then
        log_error "❌ Nodo no está en estado Ready: $node_status"
        return 1
    fi
    
    log_success "✅ Nodo está en estado Ready"
    return 0
}

validate_system_pods() {
    log_step "Validando Pods del Sistema"
    
    local failed_pods=0
    
    # Verificar pods críticos del sistema
    local system_pods
    system_pods=$(kubectl get pods -n kube-system --no-headers)
    
    echo "$system_pods" | while read -r line; do
        local pod_name
        local status
        pod_name=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $3}')
        
        if [[ "$status" == "Running" ]]; then
            echo -e "  ✅ $pod_name"
        else
            echo -e "  ❌ $pod_name ($status)"
            ((failed_pods++))
        fi
    done
    
    if [[ $failed_pods -gt 0 ]]; then
        log_error "❌ $failed_pods pods del sistema no están funcionando"
        return 1
    fi
    
    log_success "✅ Todos los pods del sistema están funcionando"
    return 0
}

validate_addons() {
    log_step "Validando Addons de Minikube"
    
    local failed_addons=0
    
    for addon in "${REQUIRED_ADDONS[@]}"; do
        if minikube addons list -p "$CLUSTER_NAME" | grep "$addon" | grep -q "enabled"; then
            log_success "✅ Addon $addon habilitado"
        else
            log_error "❌ Addon $addon no está habilitado"
            ((failed_addons++))
        fi
    done
    
    if [[ $failed_addons -gt 0 ]]; then
        log_error "❌ $failed_addons addons requeridos no están habilitados"
        return 1
    fi
    
    log_success "✅ Todos los addons requeridos están habilitados"
    return 0
}

validate_namespaces() {
    log_step "Validando Namespaces del Demo"
    
    local missing_namespaces=0
    
    for namespace in "${REQUIRED_NAMESPACES[@]}"; do
        if kubectl get namespace "$namespace" &> /dev/null; then
            log_success "✅ Namespace $namespace existe"
        else
            log_error "❌ Namespace $namespace no existe"
            ((missing_namespaces++))
        fi
    done
    
    if [[ $missing_namespaces -gt 0 ]]; then
        log_error "❌ $missing_namespaces namespaces requeridos no existen"
        return 1
    fi
    
    log_success "✅ Todos los namespaces requeridos existen"
    return 0
}

validate_ingress_controller() {
    log_step "Validando Ingress Controller"
    
    # Verificar pods del ingress controller
    local ingress_pods
    ingress_pods=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null || echo "")
    
    if [[ -z "$ingress_pods" ]]; then
        log_error "❌ No se encontraron pods del ingress controller"
        return 1
    fi
    
    local running_pods=0
    local total_pods=0
    
    echo "$ingress_pods" | while read -r line; do
        local pod_name
        local status
        pod_name=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $3}')
        ((total_pods++))
        
        if [[ "$status" == "Running" ]]; then
            echo -e "  ✅ $pod_name"
            ((running_pods++))
        else
            echo -e "  ❌ $pod_name ($status)"
        fi
    done
    
    if [[ $running_pods -eq $total_pods ]]; then
        log_success "✅ Ingress controller está funcionando"
        return 0
    else
        log_error "❌ Ingress controller tiene problemas"
        return 1
    fi
}

validate_storage() {
    log_step "Validando Configuración de Storage"
    
    # Verificar storage class por defecto
    local default_sc
    default_sc=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
    
    if [[ -n "$default_sc" ]]; then
        log_success "✅ Storage class por defecto: $default_sc"
    else
        log_error "❌ No hay storage class por defecto configurado"
        return 1
    fi
    
    # Probar creación de PVC
    log_info "Probando creación de PVC..."
    
    cat << EOF | kubectl apply -f - &> /dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
    
    # Esperar a que el PVC esté bound
    local pvc_status
    for i in {1..30}; do
        pvc_status=$(kubectl get pvc test-pvc -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [[ "$pvc_status" == "Bound" ]]; then
            break
        fi
        sleep 2
    done
    
    # Limpiar PVC de prueba
    kubectl delete pvc test-pvc &> /dev/null || true
    
    if [[ "$pvc_status" == "Bound" ]]; then
        log_success "✅ Storage está funcionando correctamente"
        return 0
    else
        log_error "❌ Storage no está funcionando (PVC status: $pvc_status)"
        return 1
    fi
}

validate_dns() {
    log_step "Validando Resolución DNS"
    
    # Probar DNS con un pod temporal
    log_info "Probando resolución DNS..."
    
    local dns_test_result
    dns_test_result=$(kubectl run dns-test --image=busybox --rm -it --restart=Never --timeout=30s -- nslookup kubernetes.default 2>/dev/null || echo "FAILED")
    
    if [[ "$dns_test_result" != "FAILED" ]] && echo "$dns_test_result" | grep -q "kubernetes.default"; then
        log_success "✅ DNS está funcionando correctamente"
        return 0
    else
        log_error "❌ DNS no está funcionando correctamente"
        return 1
    fi
}

validate_metrics_server() {
    log_step "Validando Metrics Server"
    
    # Verificar que metrics server esté ejecutándose
    local metrics_pods
    metrics_pods=$(kubectl get pods -n kube-system -l k8s-app=metrics-server --no-headers 2>/dev/null || echo "")
    
    if [[ -z "$metrics_pods" ]]; then
        log_error "❌ Metrics server no está desplegado"
        return 1
    fi
    
    local metrics_status
    metrics_status=$(echo "$metrics_pods" | awk '{print $3}' | head -1)
    
    if [[ "$metrics_status" != "Running" ]]; then
        log_error "❌ Metrics server no está ejecutándose: $metrics_status"
        return 1
    fi
    
    # Probar métricas
    log_info "Probando métricas de nodos..."
    if kubectl top nodes &> /dev/null; then
        log_success "✅ Metrics server está funcionando"
        return 0
    else
        log_warning "⚠️  Metrics server está ejecutándose pero las métricas no están disponibles aún"
        return 2
    fi
}

validate_docker_images() {
    log_step "Validando Imágenes Docker Precargadas"
    
    local demo_images
    demo_images=$(minikube image ls -p "$CLUSTER_NAME" | grep "edissonz8809/iaops" || echo "")
    
    if [[ -n "$demo_images" ]]; then
        log_success "✅ Imágenes del demo están precargadas:"
        echo "$demo_images" | sed 's/^/  /'
        return 0
    else
        log_warning "⚠️  No hay imágenes del demo precargadas"
        log_info "Esto no es crítico, las imágenes se descargarán cuando sea necesario"
        return 2
    fi
}

validate_resource_quotas() {
    log_step "Validando Resource Quotas"
    
    # Verificar resource quota en namespace backstage-demo
    if kubectl get resourcequota -n backstage-demo &> /dev/null; then
        log_success "✅ Resource quotas configurados"
        
        # Mostrar información de quotas
        log_info "Resource quotas activos:"
        kubectl get resourcequota -n backstage-demo -o wide | sed 's/^/  /'
        return 0
    else
        log_warning "⚠️  No hay resource quotas configurados"
        return 2
    fi
}

show_cluster_summary() {
    log_step "Resumen del Cluster"
    
    echo
    log_info "📊 Información del cluster:"
    
    # Información básica
    local k8s_version
    local node_count
    local namespace_count
    
    k8s_version=$(kubectl version --short --client | grep Client | awk '{print $3}')
    node_count=$(kubectl get nodes --no-headers | wc -l)
    namespace_count=$(kubectl get namespaces --no-headers | wc -l)
    
    echo -e "  ${CYAN}Kubernetes Version:${NC} $k8s_version"
    echo -e "  ${CYAN}Nodos:${NC} $node_count"
    echo -e "  ${CYAN}Namespaces:${NC} $namespace_count"
    
    # Recursos del cluster
    echo
    log_info "💾 Recursos del cluster:"
    if kubectl top nodes &> /dev/null; then
        kubectl top nodes | sed 's/^/  /'
    else
        echo -e "  ${YELLOW}Métricas no disponibles aún${NC}"
    fi
    
    # URLs útiles
    echo
    log_info "🔗 URLs útiles:"
    echo -e "  ${CYAN}Dashboard:${NC} minikube dashboard -p $CLUSTER_NAME"
    echo -e "  ${CYAN}Cluster IP:${NC} $(minikube ip -p "$CLUSTER_NAME" 2>/dev/null || echo "N/A")"
    
    # Comandos siguientes
    echo
    log_info "🚀 Próximos pasos:"
    echo -e "  ${CYAN}1.${NC} Construir imágenes: make docker-build-all"
    echo -e "  ${CYAN}2.${NC} Desplegar aplicaciones: make k8s-deploy-all"
    echo -e "  ${CYAN}3.${NC} Configurar port-forwarding: make k8s-port-forward"
    echo -e "  ${CYAN}4.${NC} Acceder a las aplicaciones via browser"
}

main() {
    show_banner
    echo
    
    local validation_errors=0
    local validation_warnings=0
    local start_time
    start_time=$(date +%s)
    
    # Ejecutar validaciones
    validate_cluster_running || ((validation_errors++))
    validate_system_pods || ((validation_errors++))
    validate_addons || ((validation_errors++))
    validate_namespaces || ((validation_errors++))
    validate_ingress_controller || ((validation_errors++))
    validate_storage || ((validation_errors++))
    validate_dns || ((validation_errors++))
    
    # Validaciones no críticas
    validate_metrics_server || {
        local result=$?
        if [[ $result -eq 2 ]]; then
            ((validation_warnings++))
        else
            ((validation_errors++))
        fi
    }
    
    validate_docker_images || {
        local result=$?
        if [[ $result -eq 2 ]]; then
            ((validation_warnings++))
        else
            ((validation_errors++))
        fi
    }
    
    validate_resource_quotas || {
        local result=$?
        if [[ $result -eq 2 ]]; then
            ((validation_warnings++))
        else
            ((validation_errors++))
        fi
    }
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Mostrar resumen
    show_cluster_summary
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                              RESULTADO DE VALIDACIÓN                          ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo
    
    if [[ $validation_errors -eq 0 ]]; then
        if [[ $validation_warnings -eq 0 ]]; then
            log_success "🎉 ¡VALIDACIÓN EXITOSA! El cluster está completamente listo para el demo"
        else
            log_success "✅ VALIDACIÓN EXITOSA con $validation_warnings advertencias menores"
            log_info "El cluster está listo para el demo, las advertencias no son críticas"
        fi
        echo
        log_success "Tiempo de validación: ${duration} segundos"
        log_success "¡Puedes proceder con el despliegue de aplicaciones!"
        exit 0
    else
        log_error "❌ VALIDACIÓN FALLIDA con $validation_errors errores críticos"
        if [[ $validation_warnings -gt 0 ]]; then
            log_warning "También hay $validation_warnings advertencias"
        fi
        echo
        log_error "El cluster NO está listo para el demo"
        echo
        log_info "💡 Para reparar los problemas:"
        echo -e "  ${CYAN}•${NC} Ejecutar troubleshooting: ./scripts/minikube/troubleshoot.sh"
        echo -e "  ${CYAN}•${NC} Reparar automáticamente: ./scripts/minikube/troubleshoot.sh fix-common"
        echo -e "  ${CYAN}•${NC} Resetear cluster: ./scripts/minikube/troubleshoot.sh reset-cluster"
        exit 1
    fi
}

# Ejecutar función principal si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
