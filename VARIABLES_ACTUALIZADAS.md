# Variables Actualizadas - Resumen de Cambios

## Variables Agregadas al .env.example

### Configuración General
- `BACKSTAGE_APP_TITLE`: Título de la aplicación Backstage
- `OPENWEBUI_APP_NAME`: Nombre de la aplicación OpenWebUI
- `BACKSTAGE_BACKEND_BASE_URL`: URL base del backend de Backstage
- `BACKSTAGE_BACKEND_PORT`: Puerto del backend de Backstage

### Configuración de Proxy
- `PROXY_TARGET_OPENWEBUI`: Target del proxy para OpenWebUI
- `PROXY_PATH_REWRITE_OPENWEBUI`: Regla de reescritura del path
- `PROXY_FORWARDED_PROTO`: Protocolo forwarded
- `PROXY_FORWARDED_HOST`: Host forwarded

### Configuración de Ingress
- `INGRESS_REWRITE_TARGET`: Target de reescritura del ingress
- `INGRESS_PROXY_BODY_SIZE`: Tamaño máximo del body
- `INGRESS_CORS_ALLOW_ORIGIN`: Origen permitido para CORS

### Configuración de Base de Datos
- `POSTGRES_INITDB_ARGS`: Argumentos de inicialización de PostgreSQL
- `POSTGRES_HOST_AUTH_METHOD`: Método de autenticación
- `POSTGRES_SHARED_PRELOAD_LIBRARIES`: Librerías precargas
- `POSTGRES_MULTIPLE_DATABASES`: Múltiples bases de datos
- `POSTGRES_DATA_DIR`: Directorio de datos
- `DATABASE_CLIENT`: Cliente de base de datos
- `DATABASE_SSL_REQUIRE`: Requerimiento de SSL

### Configuración de OpenWebUI
- `OPENWEBUI_ENABLE_SIGNUP`: Habilitar registro
- `OPENWEBUI_DEFAULT_USER_ROLE`: Rol por defecto
- `OPENWEBUI_ENABLE_LOGIN_FORM`: Habilitar formulario de login
- `OPENWEBUI_HEALTH_CHECK_PATH`: Path de health check
- `OPENWEBUI_SECRETS_NAME`: Nombre del secret
- `OPENWEBUI_PERSISTENCE_MOUNT_PATH`: Path de montaje de persistencia

### Configuración de Backstage
- `BACKSTAGE_HEALTH_CHECK_PATH`: Path de health check
- `BACKSTAGE_SECRETS_NAME`: Nombre del secret

### Configuración de Storage
- `STORAGE_CLASS_NAME`: Clase de storage
- `STORAGE_ACCESS_MODE`: Modo de acceso
- `BACKSTAGE_STORAGE_SIZE`: Tamaño de storage para Backstage
- `OPENWEBUI_STORAGE_SIZE`: Tamaño de storage para OpenWebUI
- `POSTGRESQL_STORAGE_SIZE`: Tamaño de storage para PostgreSQL

### Configuración de Recursos
- `BACKSTAGE_MEMORY_LIMIT/REQUEST`: Límites de memoria para Backstage
- `BACKSTAGE_CPU_LIMIT/REQUEST`: Límites de CPU para Backstage
- `OPENWEBUI_MEMORY_LIMIT/REQUEST`: Límites de memoria para OpenWebUI
- `OPENWEBUI_CPU_LIMIT/REQUEST`: Límites de CPU para OpenWebUI
- `POSTGRES_MEMORY_LIMIT/REQUEST`: Límites de memoria para PostgreSQL
- `POSTGRES_CPU_LIMIT/REQUEST`: Límites de CPU para PostgreSQL

### Configuración de Health Checks
- `HEALTH_CHECK_ENABLED`: Habilitar health checks
- `LIVENESS_PROBE_*`: Configuración de liveness probe
- `READINESS_PROBE_*`: Configuración de readiness probe

### Configuración de Demo Minikube
- `DEMO_MINIKUBE_OPTIMIZED`: Optimización para Minikube
- `DEMO_MINIKUBE_RESOURCE_PROFILE`: Perfil de recursos
- `DEMO_MINIKUBE_FEATURES`: Características habilitadas
- `DEMO_MINIKUBE_TOTAL_MEMORY`: Memoria total
- `DEMO_MINIKUBE_TOTAL_CPU`: CPU total
- `DEMO_MINIKUBE_SETUP_TIME`: Tiempo de setup
- `DEMO_MINIKUBE_VERSION`: Versión del demo

## Archivos Actualizados

### 1. `/helm/backstage/values.yaml`
- Reemplazadas URLs hardcodeadas con variables
- Actualizadas configuraciones de proxy
- Parametrizadas configuraciones de ingress
- Variables de base de datos
- Configuración de health checks
- Configuración de persistencia

### 2. `/helm/openwebui/values.yaml`
- URLs base parametrizadas
- Configuración de base de datos
- Configuración de ingress
- Variables de autenticación
- Health checks
- Persistencia

### 3. `/helm/postgresql/values.yaml`
- Variables de configuración de PostgreSQL
- Configuración de persistencia
- Variables de entorno

### 4. `/helm/backstage-openwebui-demo/values.yaml`
- Configuración de recursos parametrizada
- URLs y configuraciones de aplicación
- Configuración de proxy
- Variables de integración
- Annotations y labels

## Variables Eliminadas (Hardcodeadas)

### Backstage
- `title: "Backstage + OpenWebUI Demo"` → `"${BACKSTAGE_APP_TITLE:-Backstage + OpenWebUI Demo}"`
- `baseUrl: "http://localhost:3000"` → `"${BACKSTAGE_BASE_URL:-http://localhost:3000}"`
- `target: "http://openwebui:8080"` → `"${PROXY_TARGET_OPENWEBUI:-http://openwebui:8080}"`
- `path: /healthcheck` → `"${BACKSTAGE_HEALTH_CHECK_PATH:-/healthcheck}"`
- `port: 7007` → `"${BACKSTAGE_BACKEND_PORT:-7007}"`

### OpenWebUI
- `baseUrl: "http://openwebui:8080"` → `"${OPENWEBUI_BASE_URL:-http://openwebui:8080}"`
- `host: "postgresql"` → `"${POSTGRES_HOST:-postgresql}"`
- `port: 5432` → `"${POSTGRES_PORT:-5432}"`
- `path: /health` → `"${OPENWEBUI_HEALTH_CHECK_PATH:-/health}"`

### PostgreSQL
- `size: 2Gi` → `"${POSTGRESQL_STORAGE_SIZE:-2Gi}"`
- `storageClass: ""` → `"${STORAGE_CLASS_NAME:-}"`

### Recursos
- `memory: 512Mi` → `"${BACKSTAGE_MEMORY_LIMIT:-512Mi}"`
- `cpu: 500m` → `"${BACKSTAGE_CPU_LIMIT:-500m}"`

### Annotations
- `demo.minikube/optimized: "true"` → `"${DEMO_MINIKUBE_OPTIMIZED:-true}"`
- `demo.minikube/resource-profile: "standard"` → `"${DEMO_MINIKUBE_RESOURCE_PROFILE:-standard}"`

## Beneficios de los Cambios

1. **Flexibilidad**: Todas las configuraciones pueden ser modificadas desde el archivo `.env`
2. **Mantenibilidad**: Centralización de configuraciones
3. **Seguridad**: Separación de valores sensibles
4. **Escalabilidad**: Fácil adaptación a diferentes entornos
5. **Consistencia**: Uso uniforme de variables en todos los charts

## Próximos Pasos

1. Revisar y ajustar valores por defecto según necesidades
2. Crear archivos `.env` específicos para cada entorno (dev, staging, prod)
3. Documentar variables obligatorias vs opcionales
4. Implementar validación de variables requeridas
