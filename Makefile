# Makefile para Backstage + OpenWebUI Demo
.PHONY: help build-all deploy-demo clean logs test port-forward charts-process charts-restore charts-validate

# Variables
MINIKUBE_MEMORY ?= 4096
MINIKUBE_CPUS ?= 2
MINIKUBE_DISK_SIZE ?= 20g
DOCKER_REGISTRY ?= edissonz8809/iaops
DOCKER_TAG ?= demo-latest
DOCKER_BUILD_SCRIPT = ./scripts/docker-build.sh
DOCKER_PUSH_SCRIPT = ./scripts/docker-push.sh

# Colores para output
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
NC=\033[0m # No Color

help: ## Mostrar ayuda
	@echo "$(BLUE)Backstage + OpenWebUI Demo - Comandos Disponibles$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Variables de configuración:$(NC)"
	@echo "  MINIKUBE_MEMORY=$(MINIKUBE_MEMORY)"
	@echo "  MINIKUBE_CPUS=$(MINIKUBE_CPUS)"
	@echo "  DOCKER_REGISTRY=$(DOCKER_REGISTRY)"
	@echo "  DOCKER_TAG=$(DOCKER_TAG)"

# Setup y verificación
verify-requirements: ## Verificar requisitos del sistema
	@echo "$(BLUE)Verificando requisitos del sistema...$(NC)"
	@./scripts/setup/verify-requirements.sh

setup-minikube: ## Instalar y configurar Minikube
	@echo "$(BLUE)Configurando Minikube...$(NC)"
	@./scripts/setup/install-minikube.sh
	@./scripts/setup/setup-cluster.sh

# Build
build-all: build-backstage build-openwebui ## Build de todas las imágenes Docker
	@echo "$(GREEN)Build completo finalizado$(NC)"

build-backstage: ## Build de imagen Backstage
	@echo "$(BLUE)Building Backstage image...$(NC)"
	@./scripts/build/build-backstage.sh

build-openwebui: ## Build de imagen OpenWebUI
	@echo "$(BLUE)Building OpenWebUI image...$(NC)"
	@./scripts/build/build-openwebui.sh

# =============================================================================
# DOCKER COMMANDS - Multi-stage optimized builds
# =============================================================================

# Docker Build Commands
docker-build: ## Build de todas las imágenes Docker (multi-stage optimizado)
	@echo "$(BLUE)Construyendo todas las imágenes Docker...$(NC)"
	@$(DOCKER_BUILD_SCRIPT) all

docker-build-backstage: ## Build solo de imagen Backstage
	@echo "$(BLUE)Construyendo imagen Backstage...$(NC)"
	@$(DOCKER_BUILD_SCRIPT) backstage

docker-build-openwebui: ## Build solo de imagen OpenWebUI
	@echo "$(BLUE)Construyendo imagen OpenWebUI...$(NC)"
	@$(DOCKER_BUILD_SCRIPT) openwebui

docker-build-postgresql: ## Build solo de imagen PostgreSQL
	@echo "$(BLUE)Construyendo imagen PostgreSQL...$(NC)"
	@$(DOCKER_BUILD_SCRIPT) postgresql

docker-build-jenkins: ## Build solo de imagen Jenkins
	@echo "$(BLUE)Construyendo imagen Jenkins...$(NC)"
	@$(DOCKER_BUILD_SCRIPT) jenkins

docker-build-argocd: ## Build solo de imagen ArgoCD
	@echo "$(BLUE)Construyendo imagen ArgoCD...$(NC)"
	@$(DOCKER_BUILD_SCRIPT) argocd

docker-build-no-cache: ## Build de todas las imágenes sin cache
	@echo "$(BLUE)Construyendo todas las imágenes sin cache...$(NC)"
	@$(DOCKER_BUILD_SCRIPT) all --no-cache

# Docker Push Commands
docker-push: ## Push de todas las imágenes a DockerHub
	@echo "$(BLUE)Haciendo push de todas las imágenes...$(NC)"
	@$(DOCKER_PUSH_SCRIPT) all

docker-push-backstage: ## Push solo de imagen Backstage
	@echo "$(BLUE)Haciendo push de imagen Backstage...$(NC)"
	@$(DOCKER_PUSH_SCRIPT) backstage

docker-push-openwebui: ## Push solo de imagen OpenWebUI
	@echo "$(BLUE)Haciendo push de imagen OpenWebUI...$(NC)"
	@$(DOCKER_PUSH_SCRIPT) openwebui

docker-push-postgresql: ## Push solo de imagen PostgreSQL
	@echo "$(BLUE)Haciendo push de imagen PostgreSQL...$(NC)"
	@$(DOCKER_PUSH_SCRIPT) postgresql

docker-push-jenkins: ## Push solo de imagen Jenkins
	@echo "$(BLUE)Haciendo push de imagen Jenkins...$(NC)"
	@$(DOCKER_PUSH_SCRIPT) jenkins

docker-push-argocd: ## Push solo de imagen ArgoCD
	@echo "$(BLUE)Haciendo push de imagen ArgoCD...$(NC)"
	@$(DOCKER_PUSH_SCRIPT) argocd

docker-push-force: ## Push forzado de todas las imágenes (sin confirmaciones)
	@echo "$(BLUE)Haciendo push forzado de todas las imágenes...$(NC)"
	@$(DOCKER_PUSH_SCRIPT) all --force

# Docker Combined Commands
docker-build-and-push: docker-build docker-push ## Build y push de todas las imágenes
	@echo "$(GREEN)Build y push completado exitosamente$(NC)"

docker-build-and-push-backstage: docker-build-backstage docker-push-backstage ## Build y push solo de Backstage
	@echo "$(GREEN)Build y push de Backstage completado$(NC)"

docker-build-and-push-openwebui: docker-build-openwebui docker-push-openwebui ## Build y push solo de OpenWebUI
	@echo "$(GREEN)Build y push de OpenWebUI completado$(NC)"

docker-build-and-push-postgresql: docker-build-postgresql docker-push-postgresql ## Build y push solo de PostgreSQL
	@echo "$(GREEN)Build y push de PostgreSQL completado$(NC)"

docker-build-and-push-jenkins: docker-build-jenkins docker-push-jenkins ## Build y push solo de Jenkins
	@echo "$(GREEN)Build y push de Jenkins completado$(NC)"

docker-build-and-push-argocd: docker-build-argocd docker-push-argocd ## Build y push solo de ArgoCD
	@echo "$(GREEN)Build y push de ArgoCD completado$(NC)"

# Docker Utility Commands
docker-images: ## Mostrar imágenes Docker construidas
	@echo "$(BLUE)Imágenes Docker construidas:$(NC)"
	@docker images | grep -E "($(DOCKER_REGISTRY)|REPOSITORY)" || echo "No hay imágenes del registry $(DOCKER_REGISTRY)"

docker-clean: ## Limpiar imágenes Docker locales del proyecto
	@echo "$(YELLOW)Limpiando imágenes Docker locales...$(NC)"
	@docker images | grep "$(DOCKER_REGISTRY)" | awk '{print $$3}' | xargs -r docker rmi -f || true
	@echo "$(GREEN)Limpieza completada$(NC)"

docker-prune: ## Limpieza completa de Docker (cuidado: elimina todo lo no usado)
	@echo "$(RED)ADVERTENCIA: Esto eliminará todas las imágenes, contenedores y volúmenes no utilizados$(NC)"
	@read -p "¿Continuar? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@docker system prune -af --volumes
	@echo "$(GREEN)Limpieza completa de Docker finalizada$(NC)"

docker-info: ## Mostrar información de imágenes construidas
	@echo "$(BLUE)Información de imágenes Docker:$(NC)"
	@echo ""
	@echo "$(YELLOW)Registry:$(NC) $(DOCKER_REGISTRY)"
	@echo "$(YELLOW)Tag:$(NC) $(DOCKER_TAG)"
	@echo ""
	@echo "$(YELLOW)Imágenes disponibles:$(NC)"
	@for img in backstage openwebui postgresql; do \
		if docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep -q "$(DOCKER_REGISTRY)/$$img:$(DOCKER_TAG)"; then \
			echo "  ✓ $(DOCKER_REGISTRY)/$$img:$(DOCKER_TAG)"; \
			docker images --format "    Tamaño: {{.Size}}, Creada: {{.CreatedAt}}" "$(DOCKER_REGISTRY)/$$img:$(DOCKER_TAG)"; \
		else \
			echo "  ✗ $(DOCKER_REGISTRY)/$$img:$(DOCKER_TAG) (no construida)"; \
		fi; \
	done
	@echo ""
	@echo "$(YELLOW)Comandos útiles:$(NC)"
	@echo "  make docker-build          # Construir todas las imágenes"
	@echo "  make docker-push           # Push a DockerHub"
	@echo "  make docker-build-and-push # Build + push"

# Docker Test Commands
docker-test-backstage: ## Probar imagen Backstage localmente
	@echo "$(BLUE)Probando imagen Backstage...$(NC)"
	@docker run --rm -d --name backstage-test -p 7007:7007 $(DOCKER_REGISTRY)/backstage:$(DOCKER_TAG) || \
		(echo "$(RED)Error: Imagen no encontrada. Ejecuta 'make docker-build-backstage' primero$(NC)" && exit 1)
	@echo "$(GREEN)Backstage ejecutándose en http://localhost:7007$(NC)"
	@echo "$(YELLOW)Para detener: docker stop backstage-test$(NC)"

docker-test-openwebui: ## Probar imagen OpenWebUI localmente
	@echo "$(BLUE)Probando imagen OpenWebUI...$(NC)"
	@docker run --rm -d --name openwebui-test -p 8080:8080 $(DOCKER_REGISTRY)/openwebui:$(DOCKER_TAG) || \
		(echo "$(RED)Error: Imagen no encontrada. Ejecuta 'make docker-build-openwebui' primero$(NC)" && exit 1)
	@echo "$(GREEN)OpenWebUI ejecutándose en http://localhost:8080$(NC)"
	@echo "$(YELLOW)Para detener: docker stop openwebui-test$(NC)"

docker-test-postgresql: ## Probar imagen PostgreSQL localmente
	@echo "$(BLUE)Probando imagen PostgreSQL...$(NC)"
	@docker run --rm -d --name postgresql-test -p 5432:5432 -e POSTGRES_PASSWORD=demo-password $(DOCKER_REGISTRY)/postgresql:$(DOCKER_TAG) || \
		(echo "$(RED)Error: Imagen no encontrada. Ejecuta 'make docker-build-postgresql' primero$(NC)" && exit 1)
	@echo "$(GREEN)PostgreSQL ejecutándose en localhost:5432$(NC)"
	@echo "$(YELLOW)Usuario: postgres, Password: demo-password$(NC)"
	@echo "$(YELLOW)Para detener: docker stop postgresql-test$(NC)"

docker-test-jenkins: ## Probar imagen Jenkins localmente
	@echo "$(BLUE)Probando imagen Jenkins...$(NC)"
	@docker run --rm -d --name jenkins-test -p 8080:8080 $(DOCKER_REGISTRY)/jenkins:$(DOCKER_TAG) || \
		(echo "$(RED)Error: Imagen no encontrada. Ejecuta 'make docker-build-jenkins' primero$(NC)" && exit 1)
	@echo "$(GREEN)Jenkins ejecutándose en http://localhost:8080/jenkins$(NC)"
	@echo "$(YELLOW)Usuario: admin, Password: demo-jenkins-password$(NC)"
	@echo "$(YELLOW)Para detener: docker stop jenkins-test$(NC)"

docker-test-argocd: ## Probar imagen ArgoCD localmente
	@echo "$(BLUE)Probando imagen ArgoCD...$(NC)"
	@docker run --rm -d --name argocd-test -p 8080:8080 $(DOCKER_REGISTRY)/argocd:$(DOCKER_TAG) || \
		(echo "$(RED)Error: Imagen no encontrada. Ejecuta 'make docker-build-argocd' primero$(NC)" && exit 1)
	@echo "$(GREEN)ArgoCD ejecutándose en http://localhost:8080/argocd$(NC)"
	@echo "$(YELLOW)Usuario: admin, Password: (ver logs del contenedor)$(NC)"
	@echo "$(YELLOW)Para detener: docker stop argocd-test$(NC)"

docker-stop-tests: ## Detener todos los contenedores de prueba
	@echo "$(BLUE)Deteniendo contenedores de prueba...$(NC)"
	@docker stop backstage-test openwebui-test postgresql-test 2>/dev/null || true
	@echo "$(GREEN)Contenedores de prueba detenidos$(NC)"

# Comandos de Helm
helm-validate: ## Validar Charts Helm
	@echo "$(BLUE)🔍 Validando Charts Helm...$(NC)"
	@$(SCRIPTS_DIR)/helm-validate.sh

helm-install: ## Instalar Charts Helm en Minikube
	@echo "$(BLUE)🚀 Instalando Charts Helm...$(NC)"
	@$(SCRIPTS_DIR)/helm-deploy.sh

helm-upgrade: ## Actualizar Charts Helm existentes
	@echo "$(BLUE)⬆️ Actualizando Charts Helm...$(NC)"
	@$(SCRIPTS_DIR)/helm-deploy.sh --upgrade

helm-uninstall: ## Desinstalar Charts Helm
	@echo "$(BLUE)🗑️ Desinstalando Charts Helm...$(NC)"
	@$(SCRIPTS_DIR)/helm-deploy.sh --uninstall

helm-status: ## Mostrar estado de Charts Helm
	@echo "$(BLUE)📊 Estado de Charts Helm...$(NC)"
	@$(SCRIPTS_DIR)/helm-deploy.sh --status

helm-dry-run: ## Simular instalación de Charts Helm
	@echo "$(BLUE)🔍 Simulando instalación...$(NC)"
	@$(SCRIPTS_DIR)/helm-deploy.sh --dry-run

# Comandos para procesamiento de Chart.yaml con variables
charts-process: ## Procesar Chart.yaml con variables de entorno
	@echo "$(BLUE)🔄 Procesando Chart.yaml con variables...$(NC)"
	@./scripts/process-charts.sh process

charts-restore: ## Restaurar Chart.yaml originales desde backups
	@echo "$(BLUE)🔄 Restaurando Chart.yaml originales...$(NC)"
	@./scripts/process-charts.sh restore

charts-validate: ## Validar Chart.yaml procesados con helm lint
	@echo "$(BLUE)🔍 Validando Chart.yaml procesados...$(NC)"
	@./scripts/process-charts.sh validate

# ============================================================================
# COMANDOS OPENWEBUI
# ============================================================================

# Comandos de despliegue OpenWebUI
openwebui-deploy: ## Desplegar OpenWebUI con Helm (demo)
	@echo "$(BLUE)🚀 Desplegando OpenWebUI (demo)...$(NC)"
	@./scripts/deploy-openwebui.sh --environment demo

openwebui-deploy-dev: ## Desplegar OpenWebUI en entorno desarrollo
	@echo "$(BLUE)🚀 Desplegando OpenWebUI (desarrollo)...$(NC)"
	@./scripts/deploy-openwebui.sh --environment dev

openwebui-deploy-prod: ## Desplegar OpenWebUI en entorno producción
	@echo "$(BLUE)🚀 Desplegando OpenWebUI (producción)...$(NC)"
	@./scripts/deploy-openwebui.sh --environment prod

openwebui-deploy-kubectl: ## Desplegar OpenWebUI con kubectl
	@echo "$(BLUE)🚀 Desplegando OpenWebUI con kubectl...$(NC)"
	@./scripts/deploy-openwebui.sh --method kubectl

openwebui-deploy-dry-run: ## Simular despliegue de OpenWebUI
	@echo "$(BLUE)🔍 Simulando despliegue de OpenWebUI...$(NC)"
	@./scripts/deploy-openwebui.sh --dry-run

openwebui-deploy-force: ## Forzar redespliegue de OpenWebUI
	@echo "$(BLUE)🔄 Forzando redespliegue de OpenWebUI...$(NC)"
	@./scripts/deploy-openwebui.sh --force

# Comandos de configuración OpenWebUI
openwebui-configure: ## Configurar OpenWebUI después del despliegue
	@echo "$(BLUE)⚙️ Configurando OpenWebUI...$(NC)"
	@./scripts/configure-openwebui.sh

openwebui-configure-verbose: ## Configurar OpenWebUI con output detallado
	@echo "$(BLUE)⚙️ Configurando OpenWebUI (verbose)...$(NC)"
	@./scripts/configure-openwebui.sh --verbose

# Comandos de gestión OpenWebUI
openwebui-status: ## Mostrar estado de OpenWebUI
	@echo "$(BLUE)📊 Estado de OpenWebUI...$(NC)"
	@kubectl get all -n openwebui-demo -l app.kubernetes.io/name=openwebui
	@echo ""
	@kubectl get pvc -n openwebui-demo
	@echo ""
	@kubectl get ingress -n openwebui-demo

openwebui-logs: ## Mostrar logs de OpenWebUI
	@echo "$(BLUE)📋 Logs de OpenWebUI...$(NC)"
	@kubectl logs -n openwebui-demo deployment/openwebui -f

openwebui-logs-all: ## Mostrar logs de todos los containers de OpenWebUI
	@echo "$(BLUE)📋 Logs de todos los containers...$(NC)"
	@kubectl logs -n openwebui-demo deployment/openwebui --all-containers=true -f

openwebui-shell: ## Acceder al shell del pod OpenWebUI
	@echo "$(BLUE)🐚 Accediendo al shell de OpenWebUI...$(NC)"
	@kubectl exec -it -n openwebui-demo deployment/openwebui -- /bin/bash

openwebui-port-forward: ## Port forward para acceso local a OpenWebUI
	@echo "$(BLUE)🔗 Port forward OpenWebUI (http://localhost:8080)...$(NC)"
	@kubectl port-forward -n openwebui-demo service/openwebui 8080:8080

# Comandos de troubleshooting OpenWebUI
openwebui-describe: ## Describir recursos de OpenWebUI
	@echo "$(BLUE)🔍 Describiendo recursos de OpenWebUI...$(NC)"
	@kubectl describe deployment -n openwebui-demo openwebui
	@echo ""
	@kubectl describe service -n openwebui-demo openwebui
	@echo ""
	@kubectl describe ingress -n openwebui-demo openwebui

openwebui-events: ## Mostrar eventos de OpenWebUI
	@echo "$(BLUE)📅 Eventos de OpenWebUI...$(NC)"
	@kubectl get events -n openwebui-demo --sort-by='.lastTimestamp'

openwebui-health: ## Verificar health de OpenWebUI
	@echo "$(BLUE)🏥 Verificando health de OpenWebUI...$(NC)"
	@kubectl exec -n openwebui-demo deployment/openwebui -- curl -f http://localhost:8080/health || \
		echo "$(RED)Health check falló$(NC)"

openwebui-metrics: ## Mostrar métricas de OpenWebUI
	@echo "$(BLUE)📊 Métricas de OpenWebUI...$(NC)"
	@kubectl top pods -n openwebui-demo
	@echo ""
	@kubectl get hpa -n openwebui-demo

# Comandos de limpieza OpenWebUI
openwebui-uninstall: ## Desinstalar OpenWebUI (Helm)
	@echo "$(BLUE)🗑️ Desinstalando OpenWebUI...$(NC)"
	@helm uninstall openwebui --namespace openwebui-demo || true

openwebui-delete: ## Eliminar recursos de OpenWebUI (kubectl)
	@echo "$(BLUE)🗑️ Eliminando recursos de OpenWebUI...$(NC)"
	@kubectl delete -f k8s/openwebui/ --ignore-not-found=true

openwebui-clean: ## Limpiar completamente OpenWebUI (namespace incluido)
	@echo "$(BLUE)🧹 Limpieza completa de OpenWebUI...$(NC)"
	@kubectl delete namespace openwebui-demo --ignore-not-found=true

# Comandos de backup y restore OpenWebUI
openwebui-backup: ## Backup de datos de OpenWebUI
	@echo "$(BLUE)💾 Creando backup de OpenWebUI...$(NC)"
	@kubectl exec -n openwebui-demo deployment/openwebui -- tar -czf /tmp/openwebui-backup-$(shell date +%Y%m%d-%H%M%S).tar.gz /app/data
	@echo "$(GREEN)Backup creado en el pod$(NC)"

openwebui-access-info: ## Mostrar información de acceso a OpenWebUI
	@echo "$(BLUE)🔗 Información de acceso a OpenWebUI...$(NC)"
	@echo "$(GREEN)Métodos de acceso:$(NC)"
	@echo "1. Port Forward: make openwebui-port-forward"
	@echo "2. Ingress: http://openwebui.local (agregar a /etc/hosts: $$(minikube ip) openwebui.local)"
	@echo ""
	@echo "$(GREEN)Credenciales por defecto:$(NC)"
	@echo "Email: demo@example.com"
	@echo "Password: demo123"
	@echo ""
	@echo "$(GREEN)Estado actual:$(NC)"
	@kubectl get pods -n openwebui-demo -l app.kubernetes.io/name=openwebui --no-headers | head -1

# Comandos combinados OpenWebUI
openwebui-full-deploy: ## Despliegue completo de OpenWebUI (deploy + configure)
	@echo "$(BLUE)🚀 Despliegue completo de OpenWebUI...$(NC)"
	@$(MAKE) openwebui-deploy
	@sleep 30
	@$(MAKE) openwebui-configure
	@$(MAKE) openwebui-access-info

openwebui-redeploy: ## Redesplegar OpenWebUI completamente
	@echo "$(BLUE)🔄 Redesplegando OpenWebUI...$(NC)"
	@$(MAKE) openwebui-uninstall
	@sleep 10
	@$(MAKE) openwebui-full-deploy
	@./scripts/process-charts.sh validate

charts-clean: ## Limpiar archivos de backup de Chart.yaml
	@echo "$(BLUE)🧹 Limpiando backups de Chart.yaml...$(NC)"
	@./scripts/process-charts.sh clean

# Deploy con charts procesados
deploy-demo-processed: charts-process ## Despliegue completo con Chart.yaml procesados
	@echo "$(BLUE)🚀 Desplegando con Chart.yaml procesados...$(NC)"
	@$(MAKE) helm-install
	@echo "$(YELLOW)💡 Para restaurar originales: make charts-restore$(NC)"

# Deploy
deploy-demo: ## Despliegue completo para demo (usando Helm)
	@echo "$(BLUE)Desplegando aplicación completa...$(NC)"
	@$(MAKE) helm-install

deploy-backstage: ## Desplegar solo Backstage
	@echo "$(BLUE)Desplegando Backstage...$(NC)"
	@./scripts/deploy/deploy-backstage.sh

deploy-openwebui: ## Desplegar solo OpenWebUI
	@echo "$(BLUE)Desplegando OpenWebUI...$(NC)"
	@./scripts/deploy/deploy-openwebui.sh

deploy-database: ## Desplegar solo base de datos
	@echo "$(BLUE)Desplegando PostgreSQL...$(NC)"
	@./scripts/deploy/deploy-database.sh

# Utilidades
logs: ## Mostrar logs de todos los servicios
	@echo "$(BLUE)Mostrando logs de todos los servicios...$(NC)"
	@./scripts/utils/logs.sh

port-forward: ## Configurar port forwarding para acceso local
	@echo "$(BLUE)Configurando port forwarding...$(NC)"
	@./scripts/utils/port-forward.sh

clean: ## Limpiar entorno de desarrollo
	@echo "$(YELLOW)Limpiando entorno...$(NC)"
	@./scripts/utils/cleanup.sh

# Testing
test: test-unit test-integration ## Ejecutar todos los tests
	@echo "$(GREEN)Todos los tests completados$(NC)"

test-unit: ## Ejecutar tests unitarios
	@echo "$(BLUE)Ejecutando tests unitarios...$(NC)"
	@cd tests/unit && npm test

test-integration: ## Ejecutar tests de integración
	@echo "$(BLUE)Ejecutando tests de integración...$(NC)"
	@cd tests/integration && npm test

test-e2e: ## Ejecutar tests end-to-end
	@echo "$(BLUE)Ejecutando tests E2E...$(NC)"
	@cd tests/e2e && npm test

# Monitoreo
status: ## Mostrar estado de todos los pods
	@echo "$(BLUE)Estado de los pods:$(NC)"
	@kubectl get pods -o wide
	@echo ""
	@echo "$(BLUE)Estado de los servicios:$(NC)"
	@kubectl get services
	@echo ""
	@echo "$(BLUE)Uso de recursos:$(NC)"
	@kubectl top pods 2>/dev/null || echo "Metrics server no disponible"

dashboard: ## Abrir dashboard de Kubernetes
	@echo "$(BLUE)Abriendo dashboard de Kubernetes...$(NC)"
	@minikube dashboard

# Desarrollo
dev-setup: ## Configurar entorno de desarrollo
	@echo "$(BLUE)Configurando entorno de desarrollo...$(NC)"
	@./tools/dev-setup/install-deps.sh

dev-start: ## Iniciar desarrollo local con Docker Compose
	@echo "$(BLUE)Iniciando entorno de desarrollo...$(NC)"
	@docker-compose -f docker-compose.dev.yml up -d

dev-stop: ## Detener desarrollo local
	@echo "$(BLUE)Deteniendo entorno de desarrollo...$(NC)"
	@docker-compose -f docker-compose.dev.yml down

# Backup y restore
backup-db: ## Backup de la base de datos
	@echo "$(BLUE)Creando backup de la base de datos...$(NC)"
	@./tools/database/backup-restore.sh backup

restore-db: ## Restaurar base de datos desde backup
	@echo "$(BLUE)Restaurando base de datos...$(NC)"
	@./tools/database/backup-restore.sh restore

# Documentación
docs-generate: ## Generar documentación con MkDocs
	@echo "$(BLUE)Generando documentación...$(NC)"
	@./tools/documentation/generate-docs.sh

docs-serve: ## Servir documentación localmente
	@echo "$(BLUE)Sirviendo documentación en http://localhost:8000$(NC)"
	@cd tools/documentation/mkdocs && mkdocs serve

# Troubleshooting
debug-backstage: ## Debug de Backstage
	@echo "$(BLUE)Información de debug para Backstage:$(NC)"
	@kubectl describe pod -l app=backstage
	@echo ""
	@kubectl logs -l app=backstage --tail=50

debug-openwebui: ## Debug de OpenWebUI
	@echo "$(BLUE)Información de debug para OpenWebUI:$(NC)"
	@kubectl describe pod -l app=openwebui
	@echo ""
	@kubectl logs -l app=openwebui --tail=50

debug-database: ## Debug de PostgreSQL
	@echo "$(BLUE)Información de debug para PostgreSQL:$(NC)"
	@kubectl describe pod -l app=postgresql
	@echo ""
	@kubectl logs -l app=postgresql --tail=50

# Información del sistema
info: ## Mostrar información del sistema
	@echo "$(BLUE)Información del sistema:$(NC)"
	@echo "Minikube status:"
	@minikube status
	@echo ""
	@echo "Kubernetes version:"
	@kubectl version --short
	@echo ""
	@echo "Docker version:"
	@docker version --format 'Client: {{.Client.Version}} | Server: {{.Server.Version}}'
	@echo ""
	@echo "Recursos disponibles:"
	@kubectl describe node minikube | grep -A 5 "Allocated resources"

# Comandos de emergencia
emergency-restart: ## Reinicio de emergencia de Minikube
	@echo "$(RED)Reinicio de emergencia de Minikube...$(NC)"
	@minikube stop
	@minikube start --memory=$(MINIKUBE_MEMORY) --cpus=$(MINIKUBE_CPUS) --disk-size=$(MINIKUBE_DISK_SIZE)
	@make deploy-demo

force-clean: ## Limpieza forzada (elimina todo)
	@echo "$(RED)ADVERTENCIA: Esto eliminará todo el entorno$(NC)"
	@read -p "¿Estás seguro? (y/N): " confirm && [ "$$confirm" = "y" ]
	@minikube delete
	@docker system prune -af
	@echo "$(GREEN)Limpieza completa finalizada$(NC)"
# Helm Charts con procesamiento de variables de entorno
helm-process-env: ## Procesar variables de entorno en values.yaml
	@echo "$(BLUE)Procesando variables de entorno en Helm Charts...$(NC)"
	@./scripts/helm-envsubst.sh all

helm-process-env-chart: ## Procesar variables de entorno para un chart específico (uso: make helm-process-env-chart CHART=backstage)
	@echo "$(BLUE)Procesando variables de entorno para chart: $(CHART)$(NC)"
	@./scripts/helm-envsubst.sh $(CHART)

helm-validate-processed: ## Validar charts con variables procesadas
	@echo "$(BLUE)Validando charts con variables procesadas...$(NC)"
	@./scripts/helm-envsubst.sh --validate all

helm-install-processed: helm-process-env ## Instalar usando values.yaml procesados
	@echo "$(BLUE)Instalando charts con variables procesadas...$(NC)"
	@helm install backstage-openwebui-demo helm/backstage-openwebui-demo \
		-f /tmp/helm-processed/backstage-openwebui-demo/values.yaml \
		--create-namespace --namespace $(NAMESPACE)

helm-upgrade-processed: helm-process-env ## Actualizar usando values.yaml procesados
	@echo "$(BLUE)Actualizando charts con variables procesadas...$(NC)"
	@helm upgrade backstage-openwebui-demo helm/backstage-openwebui-demo \
		-f /tmp/helm-processed/backstage-openwebui-demo/values.yaml \
		--namespace $(NAMESPACE)

helm-dry-run-processed: helm-process-env ## Dry run con variables procesadas
	@echo "$(BLUE)Dry run con variables procesadas...$(NC)"
	@helm install backstage-openwebui-demo helm/backstage-openwebui-demo \
		-f /tmp/helm-processed/backstage-openwebui-demo/values.yaml \
		--dry-run --debug --namespace $(NAMESPACE)

# =============================================================================
# MINIKUBE MANAGEMENT
# =============================================================================

minikube-check: ## Verificar recursos del sistema para Minikube
	@echo "$(BLUE)Verificando recursos del sistema...$(NC)"
	@./scripts/minikube/check-resources.sh

minikube-setup: ## Configurar cluster Minikube para demo
	@echo "$(BLUE)Configurando cluster Minikube...$(NC)"
	@./scripts/minikube/setup-minikube.sh

minikube-setup-clean: ## Configurar cluster Minikube (limpio)
	@echo "$(BLUE)Configurando cluster Minikube (limpio)...$(NC)"
	@./scripts/minikube/setup-minikube.sh --clean

minikube-setup-fast: ## Configurar cluster Minikube (sin imágenes)
	@echo "$(BLUE)Configurando cluster Minikube (rápido)...$(NC)"
	@./scripts/minikube/setup-minikube.sh --skip-images

minikube-troubleshoot: ## Diagnosticar problemas del cluster
	@echo "$(BLUE)Diagnosticando cluster Minikube...$(NC)"
	@./scripts/minikube/troubleshoot.sh

minikube-fix: ## Reparar problemas comunes del cluster
	@echo "$(BLUE)Reparando problemas del cluster...$(NC)"
	@./scripts/minikube/troubleshoot.sh fix-common

minikube-reset: ## Resetear cluster completamente
	@echo "$(BLUE)Reseteando cluster Minikube...$(NC)"
	@./scripts/minikube/troubleshoot.sh reset-cluster

minikube-cleanup: ## Limpiar recursos de Minikube y Docker
	@echo "$(BLUE)Limpiando recursos...$(NC)"
	@./scripts/minikube/cleanup.sh

minikube-cleanup-all: ## Limpiar todos los recursos (forzado)
	@echo "$(BLUE)Limpieza completa de recursos...$(NC)"
	@./scripts/minikube/cleanup.sh --all --force

minikube-status: ## Mostrar estado del cluster
	@echo "$(BLUE)Estado del cluster Minikube:$(NC)"
	@minikube status -p backstage-demo || echo "$(YELLOW)Cluster no está ejecutándose$(NC)"
	@echo
	@echo "$(BLUE)Nodos del cluster:$(NC)"
	@kubectl get nodes 2>/dev/null || echo "$(YELLOW)kubectl no está configurado$(NC)"

minikube-dashboard: ## Abrir dashboard de Minikube
	@echo "$(BLUE)Abriendo dashboard de Minikube...$(NC)"
	@minikube dashboard -p backstage-demo

minikube-logs: ## Mostrar logs del cluster
	@echo "$(BLUE)Logs del cluster Minikube:$(NC)"
	@minikube logs -p backstage-demo

minikube-ssh: ## SSH al nodo de Minikube
	@echo "$(BLUE)Conectando por SSH al nodo...$(NC)"
	@minikube ssh -p backstage-demo
# =============================================================================
# JENKINS MANAGEMENT
# =============================================================================

jenkins-build: ## Construir imagen Docker de Jenkins
	@echo "$(BLUE)Construyendo imagen Docker de Jenkins...$(NC)"
	@cd docker/jenkins && docker build -t edissonz8809/iaops/jenkins:demo-latest .
	@minikube image load edissonz8809/iaops/jenkins:demo-latest -p backstage-demo

jenkins-setup: ## Configurar Jenkins completo
	@echo "$(BLUE)Configurando Jenkins para demo...$(NC)"
	@./scripts/jenkins/setup-jenkins.sh

jenkins-setup-clean: ## Configurar Jenkins (limpio)
	@echo "$(BLUE)Configurando Jenkins (limpio)...$(NC)"
	@./scripts/jenkins/setup-jenkins.sh --clean

jenkins-deploy: ## Solo desplegar Jenkins (sin construir imagen)
	@echo "$(BLUE)Desplegando Jenkins...$(NC)"
	@./scripts/jenkins/setup-jenkins.sh --deploy-only

jenkins-status: ## Mostrar estado de Jenkins
	@echo "$(BLUE)Estado de Jenkins:$(NC)"
	@kubectl get pods -n jenkins -l app.kubernetes.io/name=jenkins 2>/dev/null || echo "$(YELLOW)Jenkins no está desplegado$(NC)"
	@echo
	@echo "$(BLUE)Servicios de Jenkins:$(NC)"
	@kubectl get services -n jenkins 2>/dev/null || echo "$(YELLOW)No hay servicios de Jenkins$(NC)"

jenkins-logs: ## Mostrar logs de Jenkins
	@echo "$(BLUE)Logs de Jenkins:$(NC)"
	@kubectl logs -n jenkins -l app.kubernetes.io/name=jenkins --tail=50

jenkins-port-forward: ## Port-forward a Jenkins (puerto 8080)
	@echo "$(BLUE)Port-forward a Jenkins en http://localhost:8080/jenkins$(NC)"
	@kubectl port-forward -n jenkins svc/jenkins 8080:8080

jenkins-shell: ## Acceder al shell de Jenkins
	@echo "$(BLUE)Accediendo al shell de Jenkins...$(NC)"
	@kubectl exec -it -n jenkins -l app.kubernetes.io/name=jenkins -- bash

jenkins-cleanup: ## Limpiar instalación de Jenkins
	@echo "$(BLUE)Limpiando Jenkins...$(NC)"
	@helm uninstall jenkins -n jenkins 2>/dev/null || true
	@kubectl delete namespace jenkins --ignore-not-found=true

jenkins-url: ## Mostrar URL de acceso a Jenkins
	@echo "$(BLUE)URL de acceso a Jenkins:$(NC)"
	@echo "http://$(shell minikube ip -p backstage-demo)/jenkins"
	@echo "Usuario: admin / Contraseña: demo123"

# ============================================================================
# COMANDOS DE MKDOCS
# ============================================================================

.PHONY: mkdocs-setup mkdocs-deploy mkdocs-build mkdocs-push mkdocs-status mkdocs-logs mkdocs-clean mkdocs-process mkdocs-serve mkdocs-validate mkdocs-backup mkdocs-restore mkdocs-troubleshoot mkdocs-update

mkdocs-setup: ## Configurar MkDocs completo
	@echo "📚 Configurando MkDocs..."
	cd mkdocs && ./scripts/deploy-mkdocs.sh deploy

mkdocs-deploy: ## Desplegar MkDocs con Helm
	@echo "📦 Desplegando MkDocs..."
	cd mkdocs && ./scripts/deploy-mkdocs.sh deploy

mkdocs-build: ## Construir imágenes Docker de MkDocs
	@echo "🔨 Construyendo imágenes MkDocs..."
	cd mkdocs && ./scripts/deploy-mkdocs.sh build

mkdocs-push: ## Subir imágenes Docker de MkDocs
	@echo "📤 Subiendo imágenes MkDocs..."
	cd mkdocs && PUSH_IMAGES=true ./scripts/deploy-mkdocs.sh build

mkdocs-status: ## Ver estado de MkDocs
	@echo "📊 Estado de MkDocs:"
	cd mkdocs && ./scripts/deploy-mkdocs.sh status

mkdocs-logs: ## Ver logs de MkDocs
	@echo "📋 Logs de MkDocs:"
	kubectl logs -f deployment/mkdocs -n mkdocs-demo

mkdocs-clean: ## Limpiar MkDocs
	@echo "🧹 Limpiando MkDocs..."
	cd mkdocs && ./scripts/deploy-mkdocs.sh cleanup

mkdocs-process: ## Ejecutar procesamiento manual de conversaciones
	@echo "🔄 Procesando conversaciones..."
	cd mkdocs && ./scripts/deploy-mkdocs.sh process

mkdocs-serve: ## Servir MkDocs localmente (port-forward)
	@echo "🌐 Sirviendo MkDocs localmente..."
	kubectl port-forward -n mkdocs-demo service/mkdocs 8000:8000

mkdocs-validate: ## Validar configuración de MkDocs
	@echo "✅ Validando MkDocs..."
	helm lint mkdocs/charts/mkdocs
	kubectl get configmap mkdocs-config -n mkdocs-demo -o yaml

mkdocs-backup: ## Backup de documentación generada
	@echo "💾 Creando backup de documentación..."
	kubectl exec -n mkdocs-demo deployment/mkdocs -- tar -czf /tmp/docs-backup-$(shell date +%Y%m%d-%H%M%S).tar.gz /app/docs-source /app/data

mkdocs-restore: ## Restaurar documentación desde backup
	@echo "🔄 Restaurando documentación..."
	@echo "Especifica el archivo de backup a restaurar"

mkdocs-troubleshoot: ## Troubleshooting MkDocs
	@echo "🔧 Troubleshooting MkDocs..."
	@echo "=== Pods ==="
	kubectl get pods -n mkdocs-demo
	@echo "=== Services ==="
	kubectl get services -n mkdocs-demo
	@echo "=== ConfigMaps ==="
	kubectl get configmaps -n mkdocs-demo
	@echo "=== CronJobs ==="
	kubectl get cronjobs -n mkdocs-demo
	@echo "=== Logs del procesador ==="
	kubectl logs -l app.kubernetes.io/component=processor -n mkdocs-demo --tail=50

mkdocs-update: ## Actualizar documentación (forzar procesamiento)
	@echo "🔄 Actualizando documentación..."
	kubectl create job --from=cronjob/mkdocs-processor mkdocs-manual-$(shell date +%s) -n mkdocs-demo

# Comandos específicos para desarrollo de MkDocs
mkdocs-dev-serve: ## Servir MkDocs en modo desarrollo
	@echo "🛠️ Sirviendo MkDocs en modo desarrollo..."
	cd mkdocs && mkdocs serve --config-file=configs/mkdocs.yml --dev-addr=0.0.0.0:8000

mkdocs-dev-build: ## Construir sitio MkDocs localmente
	@echo "🔨 Construyendo sitio MkDocs..."
	cd mkdocs && mkdocs build --config-file=configs/mkdocs.yml

mkdocs-dev-clean: ## Limpiar archivos de construcción local
	@echo "🧹 Limpiando archivos locales..."
	cd mkdocs && rm -rf site/ docs-source/ data/

mkdocs-processor-test: ## Probar procesador de conversaciones localmente
	@echo "🧪 Probando procesador..."
	cd mkdocs && python3 processors/conversation_processor.py

mkdocs-templates-validate: ## Validar templates de Jinja2
	@echo "✅ Validando templates..."
	cd mkdocs && python3 -c "from jinja2 import Environment, FileSystemLoader; env = Environment(loader=FileSystemLoader('templates')); [env.get_template(t) for t in ['index.md.j2', 'conversations_summary.md.j2', 'catalog_entities.md.j2']]"
