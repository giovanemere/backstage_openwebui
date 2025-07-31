# Sistema de Integración Backstage-OpenWebUI

## 🎯 **Propósito**

Sistema completo de integración que permite la comunicación bidireccional entre Backstage y OpenWebUI, proporcionando chat contextual y funcionalidades de IA integradas.

---

## 📁 **Estructura del Directorio**

```
integration/
├── apis/                           # API FastAPI de integración
│   ├── main.py                     # API principal con 8 endpoints
│   ├── models.py                   # Modelos de datos
│   ├── webhooks.py                 # Sistema de webhooks bidireccional
│   └── requirements.txt            # Dependencias Python
├── plugins/                        # Plugins de Backstage
│   └── backstage-plugin-openwebui/ # Plugin principal
│       ├── src/
│       │   ├── api/                # API del plugin
│       │   └── components/         # Componentes React
│       ├── package.json            # Configuración del plugin
│       └── README.md               # Documentación del plugin
├── webhooks/                       # Configuraciones de webhooks
│   ├── backstage-webhooks.py       # Webhooks de Backstage
│   └── openwebui-webhooks.py       # Webhooks de OpenWebUI
└── configs/                        # Configuraciones de integración
    ├── integration-config.yaml     # Configuración principal
    └── api-endpoints.yaml          # Definición de endpoints
```

---

## 🚀 **Componentes Principales**

### **1. API FastAPI (apis/)**

**Funcionalidad:**
- 8 endpoints funcionales para comunicación entre servicios
- Autenticación con tokens JWT
- Manejo de errores y validación de datos
- Health checks integrados

**Endpoints Principales:**
- `POST /chat/send` - Enviar mensaje de chat
- `GET /chat/history/{entity_id}` - Obtener historial de chat
- `POST /entities/enrich` - Enriquecer entidades con IA
- `GET /entities/{entity_id}` - Obtener información de entidad
- `POST /webhooks/backstage` - Webhook de Backstage
- `POST /webhooks/openwebui` - Webhook de OpenWebUI
- `GET /health` - Health check
- `GET /metrics` - Métricas de la API

### **2. Plugin de Backstage (plugins/)**

**Funcionalidad:**
- Componentes React para chat contextual
- Integración con el catálogo de Backstage
- Selección automática de entidades
- Interfaz de usuario integrada

**Componentes:**
- `OpenWebuiChatComponent` - Componente principal de chat
- `OpenWebuiPage` - Página dedicada de OpenWebUI
- `OpenWebuiApi` - Cliente API para comunicación

### **3. Sistema de Webhooks (webhooks/)**

**Funcionalidad:**
- Eventos en tiempo real entre servicios
- Comunicación asíncrona
- Manejo de errores y reintentos
- Logging de eventos

---

## ⚙️ **Configuración**

### **Variables de Entorno**

```bash
# API Configuration
INTEGRATION_API_HOST=localhost
INTEGRATION_API_PORT=8000
INTEGRATION_API_SECRET=your-secret-key

# Backstage Configuration
BACKSTAGE_URL=http://backstage:7007
BACKSTAGE_TOKEN=your-backstage-token

# OpenWebUI Configuration
OPENWEBUI_URL=http://openwebui:8080
OPENWEBUI_TOKEN=your-openwebui-token

# Database Configuration
DATABASE_URL=postgresql://user:pass@postgres:5432/integration
```

### **Configuración de Integración (configs/integration-config.yaml)**

```yaml
integration:
  api:
    host: "0.0.0.0"
    port: 8000
    debug: false
  
  backstage:
    url: "http://backstage:7007"
    api_token: "${BACKSTAGE_TOKEN}"
    webhook_secret: "${WEBHOOK_SECRET}"
  
  openwebui:
    url: "http://openwebui:8080"
    api_token: "${OPENWEBUI_TOKEN}"
    webhook_secret: "${WEBHOOK_SECRET}"
  
  database:
    url: "${DATABASE_URL}"
    pool_size: 10
    max_overflow: 20
```

---

## 🛠️ **Instalación y Despliegue**

### **1. Desarrollo Local**

```bash
# Instalar dependencias
cd integration/apis/
pip install -r requirements.txt

# Ejecutar API
python main.py

# En otra terminal, instalar plugin de Backstage
cd integration/plugins/backstage-plugin-openwebui/
npm install
npm run build
```

### **2. Despliegue en Kubernetes**

```bash
# Desplegar API de integración
kubectl apply -f k8s/integration/

# Verificar despliegue
kubectl get pods -l app=integration-api
kubectl logs -l app=integration-api
```

### **3. Usando Makefile**

```bash
# Desplegar integración completa
make deploy-integration

# Ver logs de integración
make logs-integration

# Probar endpoints
make test-integration
```

---

## 🔧 **Uso**

### **Chat Contextual en Backstage**

1. **Navegar a una entidad** en el catálogo de Backstage
2. **Abrir el chat** desde el componente integrado
3. **El contexto se carga automáticamente** con información de la entidad
4. **Hacer preguntas** relacionadas con la entidad
5. **Las respuestas se guardan** en el historial por entidad

### **API Directa**

```bash
# Enviar mensaje de chat
curl -X POST http://localhost:8000/chat/send \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-token" \
  -d '{
    "message": "¿Cómo funciona este servicio?",
    "entity_id": "component:default/my-service",
    "user_id": "user123"
  }'

# Obtener historial
curl -X GET http://localhost:8000/chat/history/component:default/my-service \
  -H "Authorization: Bearer your-token"
```

---

## 📊 **Monitoreo y Métricas**

### **Health Checks**

```bash
# Verificar salud de la API
curl http://localhost:8000/health

# Respuesta esperada:
{
  "status": "healthy",
  "timestamp": "2025-07-30T23:00:00Z",
  "services": {
    "database": "healthy",
    "backstage": "healthy",
    "openwebui": "healthy"
  }
}
```

### **Métricas**

```bash
# Obtener métricas
curl http://localhost:8000/metrics

# Métricas disponibles:
- integration_api_requests_total
- integration_api_request_duration_seconds
- integration_chat_messages_total
- integration_webhook_events_total
```

---

## 🐛 **Troubleshooting**

### **Problemas Comunes**

1. **Error de Conexión a Backstage**
   ```bash
   # Verificar conectividad
   kubectl exec -it integration-api-pod -- curl http://backstage:7007/api/catalog/entities
   ```

2. **Error de Conexión a OpenWebUI**
   ```bash
   # Verificar conectividad
   kubectl exec -it integration-api-pod -- curl http://openwebui:8080/api/v1/chats
   ```

3. **Error de Base de Datos**
   ```bash
   # Verificar conexión a PostgreSQL
   kubectl exec -it integration-api-pod -- pg_isready -h postgres -p 5432
   ```

### **Logs Útiles**

```bash
# Logs de la API
kubectl logs -l app=integration-api -f

# Logs del plugin en Backstage
kubectl logs -l app=backstage -f | grep "openwebui-plugin"

# Logs de webhooks
kubectl logs -l app=integration-api -f | grep "webhook"
```

---

## 🔄 **Flujo de Datos**

```mermaid
graph TD
    A[Usuario en Backstage] --> B[Plugin OpenWebUI]
    B --> C[API de Integración]
    C --> D[OpenWebUI API]
    D --> E[Modelo de IA]
    E --> D
    D --> C
    C --> F[Base de Datos]
    C --> B
    B --> A
    
    G[Webhook Backstage] --> C
    C --> H[Webhook OpenWebUI]
    H --> I[Procesamiento Asíncrono]
    I --> C
```

---

## 📚 **Documentación Adicional**

- [Plugin de Backstage](plugins/backstage-plugin-openwebui/README.md)
- [API Endpoints](configs/api-endpoints.yaml)
- [Configuración de Webhooks](webhooks/README.md)
- [Guía de Desarrollo](../docs/desarrollo-integracion.md)

---

## 🎯 **Estado del Componente**

- ✅ **API FastAPI**: 8 endpoints implementados y funcionales
- ✅ **Plugin Backstage**: Componentes React completamente integrados
- ✅ **Sistema de Webhooks**: Eventos bidireccionales funcionando
- ✅ **Configuraciones**: Todas las configuraciones implementadas
- ✅ **Documentación**: Documentación completa disponible
- ✅ **Testing**: Endpoints probados y validados
- ✅ **Monitoreo**: Health checks y métricas configurados

**¡Sistema de integración completamente funcional y listo para uso!** 🚀
