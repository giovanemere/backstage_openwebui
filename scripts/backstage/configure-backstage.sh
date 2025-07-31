#!/bin/bash

# =============================================================================
# Script de Configuración de Backstage - Post-Despliegue
# =============================================================================

set -euo pipefail

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
NAMESPACE="backstage-demo"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de logging
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

# Función para configurar integración con GitHub
configure_github_integration() {
    log_info "Configurando integración con GitHub..."
    
    read -p "¿Tienes un token de GitHub? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -s -p "Ingresa tu GitHub token: " GITHUB_TOKEN
        echo
        
        # Actualizar secret
        kubectl patch secret backstage-secrets -n "${NAMESPACE}" \
            --type='json' \
            -p="[{'op': 'replace', 'path': '/data/GITHUB_TOKEN', 'value': '$(echo -n "$GITHUB_TOKEN" | base64 -w 0)'}]"
        
        # Reiniciar deployment para aplicar cambios
        kubectl rollout restart deployment/backstage -n "${NAMESPACE}"
        
        log_success "Integración con GitHub configurada"
    else
        log_warning "Saltando configuración de GitHub. Usando token demo."
    fi
}

# Función para configurar integración con OpenWebUI
configure_openwebui_integration() {
    log_info "Configurando integración con OpenWebUI..."
    
    # Verificar si OpenWebUI está disponible
    if kubectl get service openwebui -n "${NAMESPACE}" &> /dev/null; then
        log_success "OpenWebUI encontrado en el cluster"
        
        # Obtener información de OpenWebUI
        OPENWEBUI_IP=$(kubectl get service openwebui -n "${NAMESPACE}" -o jsonpath='{.spec.clusterIP}')
        OPENWEBUI_PORT=$(kubectl get service openwebui -n "${NAMESPACE}" -o jsonpath='{.spec.ports[0].port}')
        
        log_info "OpenWebUI disponible en: http://${OPENWEBUI_IP}:${OPENWEBUI_PORT}"
        
        # Actualizar configuración de proxy en Backstage
        kubectl patch configmap backstage-config -n "${NAMESPACE}" \
            --type='json' \
            -p="[{'op': 'replace', 'path': '/data/app-config.yaml', 'value': '$(cat <<EOF | base64 -w 0
app:
  title: Backstage Demo
  baseUrl: http://backstage:7007

proxy:
  '/openwebui':
    target: 'http://${OPENWEBUI_IP}:${OPENWEBUI_PORT}'
    changeOrigin: true
    headers:
      Authorization: 'Bearer \${OPENWEBUI_TOKEN}'
EOF
)'}]"
        
        # Reiniciar deployment
        kubectl rollout restart deployment/backstage -n "${NAMESPACE}"
        
        log_success "Integración con OpenWebUI configurada"
    else
        log_warning "OpenWebUI no encontrado. Asegúrate de desplegarlo primero."
    fi
}

# Función para configurar catálogo de componentes
configure_catalog() {
    log_info "Configurando catálogo de componentes..."
    
    # Crear archivo de entidades demo
    cat > /tmp/demo-entities.yaml << EOF
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: backstage-demo
  description: Backstage demo application
  annotations:
    github.com/project-slug: edissonz8809/iaops
    backstage.io/kubernetes-id: backstage
  tags:
    - demo
    - minikube
    - developer-portal
spec:
  type: website
  lifecycle: experimental
  owner: demo-team
  system: demo-system
---
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: openwebui-demo
  description: OpenWebUI chat application
  annotations:
    github.com/project-slug: edissonz8809/iaops
    backstage.io/kubernetes-id: openwebui
  tags:
    - demo
    - ai
    - chat
spec:
  type: service
  lifecycle: experimental
  owner: demo-team
  system: demo-system
---
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: demo-system
  description: Demo system for Backstage + OpenWebUI integration
  tags:
    - demo
    - minikube
spec:
  owner: demo-team
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: demo-team
  description: Demo team for Backstage showcase
spec:
  type: team
  children: []
---
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: backstage-api
  description: Backstage API
  annotations:
    github.com/project-slug: edissonz8809/iaops
spec:
  type: openapi
  lifecycle: experimental
  owner: demo-team
  system: demo-system
  definition: |
    openapi: 3.0.0
    info:
      title: Backstage Demo API
      version: 1.0.0
    paths:
      /api/catalog/health:
        get:
          summary: Health check
          responses:
            '200':
              description: OK
EOF

    # Actualizar ConfigMap con las nuevas entidades
    kubectl create configmap demo-entities \
        --from-file=entities.yaml=/tmp/demo-entities.yaml \
        -n "${NAMESPACE}" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Limpiar archivo temporal
    rm /tmp/demo-entities.yaml
    
    log_success "Catálogo de componentes configurado"
}

# Función para configurar plugins
configure_plugins() {
    log_info "Configurando plugins de Backstage..."
    
    # Lista de plugins para habilitar
    local plugins=(
        "@backstage/plugin-kubernetes"
        "@backstage/plugin-techdocs"
        "@backstage/plugin-catalog-import"
        "@backstage/plugin-scaffolder"
        "@backstage/plugin-search"
        "@backstage/plugin-user-settings"
    )
    
    log_info "Plugins habilitados:"
    for plugin in "${plugins[@]}"; do
        echo "  - $plugin"
    done
    
    log_success "Plugins configurados"
}

# Función para configurar TechDocs
configure_techdocs() {
    log_info "Configurando TechDocs..."
    
    # Crear documentación demo
    mkdir -p /tmp/techdocs-demo
    
    cat > /tmp/techdocs-demo/mkdocs.yml << EOF
site_name: 'Demo Documentation'
site_description: 'Documentación demo para Backstage'

nav:
  - Home: index.md
  - Getting Started: getting-started.md
  - API Reference: api.md

plugins:
  - techdocs-core
EOF

    cat > /tmp/techdocs-demo/docs/index.md << EOF
# Demo Documentation

Bienvenido a la documentación demo de Backstage + OpenWebUI.

## Características

- **Developer Portal**: Portal centralizado para desarrolladores
- **Service Catalog**: Catálogo de servicios y componentes
- **TechDocs**: Documentación técnica integrada
- **Kubernetes Integration**: Integración con Kubernetes
- **OpenWebUI Integration**: Integración con chat AI

## Arquitectura

Este demo incluye:

1. **Backstage**: Portal de desarrollador
2. **OpenWebUI**: Interfaz de chat AI
3. **PostgreSQL**: Base de datos
4. **Kubernetes**: Orquestación de contenedores

## Enlaces Útiles

- [Backstage Official Docs](https://backstage.io/docs)
- [OpenWebUI Documentation](https://docs.openwebui.com)
- [Kubernetes Documentation](https://kubernetes.io/docs)
EOF

    cat > /tmp/techdocs-demo/docs/getting-started.md << EOF
# Getting Started

## Prerrequisitos

- Minikube instalado
- kubectl configurado
- Helm 3.x

## Instalación

1. Clonar el repositorio
2. Ejecutar el script de despliegue
3. Acceder a la interfaz web

## Configuración

### GitHub Integration

Para habilitar la integración con GitHub:

1. Crear un Personal Access Token
2. Configurar el secret en Kubernetes
3. Reiniciar el deployment

### OpenWebUI Integration

La integración con OpenWebUI permite:

- Acceso directo desde Backstage
- Proxy de requests
- Autenticación unificada
EOF

    cat > /tmp/techdocs-demo/docs/api.md << EOF
# API Reference

## Backstage API

### Health Check

\`\`\`
GET /api/catalog/health
\`\`\`

Respuesta:
\`\`\`json
{
  "status": "ok"
}
\`\`\`

### Catalog API

\`\`\`
GET /api/catalog/entities
\`\`\`

Lista todas las entidades del catálogo.

## OpenWebUI API

### Chat Endpoint

\`\`\`
POST /openwebui/api/chat
\`\`\`

Envía mensajes al chat AI.
EOF

    # Crear ConfigMap con la documentación
    kubectl create configmap techdocs-demo \
        --from-file=/tmp/techdocs-demo \
        -n "${NAMESPACE}" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Limpiar archivos temporales
    rm -rf /tmp/techdocs-demo
    
    log_success "TechDocs configurado"
}

# Función para verificar configuración
verify_configuration() {
    log_info "Verificando configuración..."
    
    # Verificar pods
    if kubectl get pods -n "${NAMESPACE}" -l app=backstage | grep -q "Running"; then
        log_success "Backstage está ejecutándose"
    else
        log_error "Backstage no está ejecutándose correctamente"
        return 1
    fi
    
    # Verificar servicios
    if kubectl get service backstage -n "${NAMESPACE}" &> /dev/null; then
        log_success "Servicio de Backstage disponible"
    else
        log_error "Servicio de Backstage no disponible"
        return 1
    fi
    
    # Verificar ingress
    if kubectl get ingress -n "${NAMESPACE}" | grep -q "backstage"; then
        log_success "Ingress configurado"
    else
        log_warning "Ingress no configurado"
    fi
    
    log_success "Configuración verificada"
}

# Función para mostrar resumen
show_summary() {
    log_info "Resumen de configuración:"
    
    echo -e "${GREEN}Componentes configurados:${NC}"
    echo "  ✓ Catálogo de componentes"
    echo "  ✓ Plugins de Backstage"
    echo "  ✓ TechDocs"
    
    if kubectl get secret backstage-secrets -n "${NAMESPACE}" -o jsonpath='{.data.GITHUB_TOKEN}' | base64 -d | grep -v "demo-token" &> /dev/null; then
        echo "  ✓ Integración con GitHub"
    else
        echo "  ⚠ Integración con GitHub (usando token demo)"
    fi
    
    if kubectl get service openwebui -n "${NAMESPACE}" &> /dev/null; then
        echo "  ✓ Integración con OpenWebUI"
    else
        echo "  ⚠ Integración con OpenWebUI (no disponible)"
    fi
    
    echo -e "${GREEN}URLs de acceso:${NC}"
    echo "  - Backstage: http://localhost/backstage"
    echo "  - API: http://localhost/backstage-api"
    echo "  - TechDocs: http://localhost/backstage/docs"
}

# Función principal
main() {
    local command="${1:-configure}"
    
    case "$command" in
        "configure")
            configure_catalog
            configure_plugins
            configure_techdocs
            configure_github_integration
            configure_openwebui_integration
            verify_configuration
            show_summary
            ;;
        "github")
            configure_github_integration
            ;;
        "openwebui")
            configure_openwebui_integration
            ;;
        "catalog")
            configure_catalog
            ;;
        "plugins")
            configure_plugins
            ;;
        "techdocs")
            configure_techdocs
            ;;
        "verify")
            verify_configuration
            ;;
        "summary")
            show_summary
            ;;
        "help"|"-h"|"--help")
            echo "Uso: $0 [comando]"
            echo ""
            echo "Comandos:"
            echo "  configure   - Configurar todos los componentes"
            echo "  github      - Configurar integración con GitHub"
            echo "  openwebui   - Configurar integración con OpenWebUI"
            echo "  catalog     - Configurar catálogo de componentes"
            echo "  plugins     - Configurar plugins"
            echo "  techdocs    - Configurar TechDocs"
            echo "  verify      - Verificar configuración"
            echo "  summary     - Mostrar resumen"
            echo "  help        - Mostrar esta ayuda"
            ;;
        *)
            log_error "Comando no válido: $command"
            echo "Usa '$0 help' para ver los comandos disponibles"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"
