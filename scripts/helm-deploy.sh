#!/bin/bash

# Script de despliegue de Charts Helm
# Despliega Backstage + OpenWebUI en Minikube

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
NAMESPACE="backstage-demo"
RELEASE_NAME="backstage-openwebui-demo"
HELM_DIR="$(dirname "$0")/../helm"
CHART_PATH="$HELM_DIR/backstage-openwebui-demo"

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [OPCIONES]"
    echo ""
    echo "Opciones:"
    echo "  -n, --namespace NAMESPACE    Namespace de Kubernetes (default: backstage-demo)"
    echo "  -r, --release RELEASE        Nombre del release (default: backstage-openwebui-demo)"
    echo "  --dry-run                    Solo mostrar lo que se haría"
    echo "  --upgrade                    Actualizar release existente"
    echo "  --uninstall                  Desinstalar release"
    echo "  --status                     Mostrar estado del release"
    echo "  -h, --help                   Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0                           Instalar con configuración por defecto"
    echo "  $0 --dry-run                 Ver qué se instalaría"
    echo "  $0 --upgrade                 Actualizar instalación existente"
    echo "  $0 --uninstall               Desinstalar completamente"
}

# Función para verificar prerrequisitos
check_prerequisites() {
    echo -e "${BLUE}🔍 Verificando prerrequisitos...${NC}"
    
    # Verificar Helm
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}❌ Error: Helm no está instalado${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Helm: $(helm version --short)${NC}"
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ Error: kubectl no está instalado${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ kubectl encontrado${NC}"
    
    # Verificar conexión a cluster
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}❌ Error: No se puede conectar al cluster de Kubernetes${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Conexión al cluster OK${NC}"
    
    # Verificar Minikube (opcional)
    if command -v minikube &> /dev/null; then
        local minikube_status=$(minikube status --format='{{.Host}}' 2>/dev/null || echo "Unknown")
        if [ "$minikube_status" = "Running" ]; then
            echo -e "${GREEN}✅ Minikube: Running${NC}"
            
            # Mostrar recursos disponibles
            local memory=$(minikube config get memory 2>/dev/null || echo "Unknown")
            local cpus=$(minikube config get cpus 2>/dev/null || echo "Unknown")
            echo -e "${BLUE}📊 Recursos Minikube: ${memory}MB RAM, ${cpus} CPUs${NC}"
        else
            echo -e "${YELLOW}⚠️  Minikube no está ejecutándose${NC}"
        fi
    fi
    
    # Verificar ingress controller
    if kubectl get ingressclass nginx &> /dev/null; then
        echo -e "${GREEN}✅ Nginx Ingress Controller encontrado${NC}"
    else
        echo -e "${YELLOW}⚠️  Nginx Ingress Controller no encontrado${NC}"
        echo -e "${YELLOW}   Ejecutar: minikube addons enable ingress${NC}"
    fi
}

# Función para crear namespace
create_namespace() {
    echo -e "${BLUE}📁 Configurando namespace: $NAMESPACE${NC}"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        echo -e "${GREEN}✅ Namespace $NAMESPACE ya existe${NC}"
    else
        kubectl create namespace "$NAMESPACE"
        echo -e "${GREEN}✅ Namespace $NAMESPACE creado${NC}"
    fi
    
    # Etiquetar namespace para demo
    kubectl label namespace "$NAMESPACE" \
        demo.minikube/managed=true \
        app.kubernetes.io/part-of=backstage-openwebui-demo \
        --overwrite
}

# Función para actualizar dependencias
update_dependencies() {
    echo -e "${BLUE}🔄 Actualizando dependencias de Helm...${NC}"
    
    cd "$CHART_PATH"
    if helm dependency update; then
        echo -e "${GREEN}✅ Dependencias actualizadas${NC}"
    else
        echo -e "${RED}❌ Error actualizando dependencias${NC}"
        exit 1
    fi
    cd - > /dev/null
}

# Función para instalar/actualizar
install_or_upgrade() {
    local action=$1
    local dry_run_flag=""
    
    if [ "$DRY_RUN" = "true" ]; then
        dry_run_flag="--dry-run"
        echo -e "${YELLOW}🔍 Modo dry-run activado${NC}"
    fi
    
    echo -e "${BLUE}🚀 ${action^} release: $RELEASE_NAME${NC}"
    
    # Comando base
    local helm_cmd="helm $action $RELEASE_NAME $CHART_PATH"
    helm_cmd="$helm_cmd --namespace $NAMESPACE"
    helm_cmd="$helm_cmd --create-namespace"
    helm_cmd="$helm_cmd --wait"
    helm_cmd="$helm_cmd --timeout 10m"
    
    if [ "$dry_run_flag" != "" ]; then
        helm_cmd="$helm_cmd $dry_run_flag"
    fi
    
    # Valores personalizados para demo
    helm_cmd="$helm_cmd --set global.demo.enabled=true"
    helm_cmd="$helm_cmd --set global.demo.environment=minikube"
    
    echo -e "${BLUE}📝 Ejecutando: $helm_cmd${NC}"
    
    if eval "$helm_cmd"; then
        if [ "$DRY_RUN" != "true" ]; then
            echo -e "${GREEN}✅ Release $action exitoso${NC}"
            show_access_info
        else
            echo -e "${GREEN}✅ Dry-run completado sin errores${NC}"
        fi
    else
        echo -e "${RED}❌ Error en $action del release${NC}"
        exit 1
    fi
}

# Función para desinstalar
uninstall() {
    echo -e "${YELLOW}🗑️  Desinstalando release: $RELEASE_NAME${NC}"
    
    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        if helm uninstall "$RELEASE_NAME" --namespace "$NAMESPACE"; then
            echo -e "${GREEN}✅ Release desinstalado${NC}"
        else
            echo -e "${RED}❌ Error desinstalando release${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠️  Release $RELEASE_NAME no encontrado${NC}"
    fi
    
    # Preguntar si eliminar namespace
    read -p "¿Eliminar namespace $NAMESPACE? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete namespace "$NAMESPACE" --ignore-not-found
        echo -e "${GREEN}✅ Namespace eliminado${NC}"
    fi
}

# Función para mostrar estado
show_status() {
    echo -e "${BLUE}📊 Estado del release: $RELEASE_NAME${NC}"
    
    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        helm status "$RELEASE_NAME" --namespace "$NAMESPACE"
        
        echo -e "\n${BLUE}📋 Pods en el namespace:${NC}"
        kubectl get pods -n "$NAMESPACE"
        
        echo -e "\n${BLUE}🌐 Servicios:${NC}"
        kubectl get services -n "$NAMESPACE"
        
        echo -e "\n${BLUE}🔗 Ingress:${NC}"
        kubectl get ingress -n "$NAMESPACE"
        
    else
        echo -e "${YELLOW}⚠️  Release $RELEASE_NAME no encontrado en namespace $NAMESPACE${NC}"
    fi
}

# Función para mostrar información de acceso
show_access_info() {
    echo -e "\n${GREEN}🎉 ¡Despliegue completado exitosamente!${NC}"
    echo -e "\n${BLUE}📝 Información de acceso:${NC}"
    
    # Obtener IP de Minikube
    local minikube_ip=""
    if command -v minikube &> /dev/null; then
        minikube_ip=$(minikube ip 2>/dev/null || echo "")
    fi
    
    if [ -n "$minikube_ip" ]; then
        echo -e "${BLUE}🌐 IP de Minikube: $minikube_ip${NC}"
        echo -e "\n${YELLOW}📝 Agregar a /etc/hosts:${NC}"
        echo -e "${YELLOW}echo '$minikube_ip backstage.local openwebui.local' | sudo tee -a /etc/hosts${NC}"
        
        echo -e "\n${BLUE}🔗 URLs de acceso:${NC}"
        echo -e "  • Backstage: ${GREEN}http://backstage.local${NC}"
        echo -e "  • OpenWebUI: ${GREEN}http://openwebui.local${NC}"
    else
        echo -e "\n${BLUE}🔗 Port-forward para acceso local:${NC}"
        echo -e "  • Backstage: ${YELLOW}kubectl port-forward -n $NAMESPACE svc/backstage 3000:3000${NC}"
        echo -e "  • OpenWebUI: ${YELLOW}kubectl port-forward -n $NAMESPACE svc/openwebui 8080:8080${NC}"
    fi
    
    echo -e "\n${BLUE}🔐 Credenciales de demo:${NC}"
    echo -e "  • Usuario: ${GREEN}demo${NC}"
    echo -e "  • Contraseña: ${GREEN}demo123${NC}"
    
    echo -e "\n${BLUE}🛠️  Comandos útiles:${NC}"
    echo -e "  • Ver pods: ${YELLOW}kubectl get pods -n $NAMESPACE${NC}"
    echo -e "  • Ver logs: ${YELLOW}kubectl logs -f -n $NAMESPACE deployment/backstage${NC}"
    echo -e "  • Estado del release: ${YELLOW}$0 --status${NC}"
}

# Función principal
main() {
    local action="install"
    
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -r|--release)
                RELEASE_NAME="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --upgrade)
                action="upgrade"
                shift
                ;;
            --uninstall)
                action="uninstall"
                shift
                ;;
            --status)
                action="status"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Opción desconocida: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo -e "${BLUE}🚀 Helm Deploy Script - Backstage + OpenWebUI Demo${NC}"
    echo -e "${BLUE}📦 Release: $RELEASE_NAME${NC}"
    echo -e "${BLUE}📁 Namespace: $NAMESPACE${NC}"
    echo -e "${BLUE}🎯 Acción: $action${NC}"
    
    case $action in
        "install"|"upgrade")
            check_prerequisites
            create_namespace
            update_dependencies
            
            # Verificar si ya existe para decidir install vs upgrade
            if [ "$action" = "install" ] && helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
                echo -e "${YELLOW}⚠️  Release ya existe, cambiando a upgrade${NC}"
                action="upgrade"
            fi
            
            install_or_upgrade "$action"
            ;;
        "uninstall")
            uninstall
            ;;
        "status")
            show_status
            ;;
    esac
}

# Ejecutar función principal
main "$@"
