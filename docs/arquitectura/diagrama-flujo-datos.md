# Diagrama de Flujo de Datos - Backstage + OpenWebUI (Demo Simplificado)

## Flujo de Datos Simplificado

```mermaid
sequenceDiagram
    participant U as 👤 Usuario
    participant BS as 🎭 Backstage UI
    participant BSB as 📚 Backstage Backend<br/>(+ Proxy + Auth)
    participant OWB as 🤖 OpenWebUI Backend
    participant PG as 🗄️ PostgreSQL<br/>(Shared DB)
    participant MK as 📖 MkDocs

    %% Flujo de Autenticación Simplificado
    Note over U,PG: 1. Autenticación Básica Integrada
    U->>BS: 1.1 Acceso a Backstage
    BS->>BSB: 1.2 Request de login
    BSB->>PG: 1.3 Verificar credenciales
    PG-->>BSB: 1.4 Usuario válido
    BSB-->>BS: 1.5 Sesión establecida
    BS-->>U: 1.6 Acceso autorizado

    %% Flujo de Chat Directo
    Note over U,PG: 2. Chat Integrado (Sin API Gateway)
    U->>BS: 2.1 Abrir chat plugin
    BS->>BSB: 2.2 Request de chat
    BSB->>BSB: 2.3 Validar sesión
    BSB->>OWB: 2.4 Proxy directo a OpenWebUI
    OWB->>PG: 2.5 Guardar mensaje
    OWB->>OWB: 2.6 Procesar con IA
    OWB-->>BSB: 2.7 Respuesta generada
    BSB-->>BS: 2.8 Respuesta via proxy
    BS-->>U: 2.9 Mostrar en chat plugin

    %% Flujo de Documentación Simplificado
    Note over OWB,MK: 3. Generación de Docs Automática
    OWB->>PG: 3.1 Conversación completada
    PG->>MK: 3.2 Trigger via webhook
    MK->>PG: 3.3 Leer conversaciones
    MK->>MK: 3.4 Generar markdown
    MK->>BSB: 3.5 Notificar docs actualizadas
    BSB->>PG: 3.6 Actualizar catálogo

    %% Flujo de Consulta de Documentación
    Note over U,MK: 4. Búsqueda de Documentación
    U->>BS: 4.1 Buscar en TechDocs
    BS->>BSB: 4.2 Query de búsqueda
    BSB->>MK: 4.3 Buscar en docs generadas
    MK-->>BSB: 4.4 Resultados
    BSB-->>BS: 4.5 Mostrar resultados
    BS-->>U: 4.6 Documentación encontrada
```

## Flujo de Despliegue Simplificado

```mermaid
flowchart TD
    subgraph "Development"
        DEV[👨‍💻 Developer]
        GIT[📚 Git Repository]
    end
    
    subgraph "Build Process"
        BUILD[🔨 Local Build]
        DOCKER[🐳 Docker Build]
        PUSH[📤 Push to DockerHub]
    end
    
    subgraph "Container Registry"
        DH[🐳 DockerHub<br/>edissonz8809/iaops]
    end
    
    subgraph "Minikube Deployment"
        HELM[⚓ Helm Install/Upgrade]
        PODS[🎯 Application Pods]
    end
    
    subgraph "Optional CI/CD"
        JEN[🏗️ Jenkins<br/>Si hay recursos]
        AUTO[🤖 Auto Deploy]
    end
    
    %% Manual Development Flow
    DEV -->|1. Code & Test| BUILD
    BUILD --> DOCKER
    DOCKER --> PUSH
    PUSH --> DH
    DH -->|2. Manual Deploy| HELM
    HELM --> PODS
    
    %% Optional Automated Flow
    GIT -.->|3. Optional| JEN
    JEN -.-> AUTO
    AUTO -.-> HELM
    
    %% Feedback
    PODS -->|4. Logs & Status| DEV
    
    classDef devClass fill:#e1f5fe
    classDef buildClass fill:#fff3e0
    classDef registryClass fill:#e8f5e8
    classDef deployClass fill:#fce4ec
    classDef optionalClass fill:#f1f8e9,stroke-dasharray: 5 5
    
    class DEV,GIT devClass
    class BUILD,DOCKER,PUSH buildClass
    class DH registryClass
    class HELM,PODS deployClass
    class JEN,AUTO optionalClass
```

## Flujo de Integración Chat-Documentación Optimizado

```mermaid
flowchart LR
    subgraph "Chat Flow"
        USER[👤 Usuario]
        CHAT_UI[💬 Chat Plugin<br/>en Backstage]
        CHAT_ENGINE[🤖 OpenWebUI<br/>Engine]
    end
    
    subgraph "Data Processing"
        SHARED_DB[(🗄️ PostgreSQL<br/>Shared)]
        PROCESSOR[⚙️ Simple<br/>Processor]
    end
    
    subgraph "Documentation"
        MKDOCS[📖 MkDocs<br/>Sidecar]
        STATIC_DOCS[📄 Static Docs]
    end
    
    subgraph "Integration"
        BACKSTAGE_CORE[🎭 Backstage<br/>TechDocs]
        SEARCH[🔍 Built-in<br/>Search]
    end
    
    %% Simplified Flow
    USER --> CHAT_UI
    CHAT_UI --> CHAT_ENGINE
    CHAT_ENGINE --> SHARED_DB
    
    %% Documentation Generation
    SHARED_DB --> PROCESSOR
    PROCESSOR --> MKDOCS
    MKDOCS --> STATIC_DOCS
    
    %% Integration with Backstage
    STATIC_DOCS --> BACKSTAGE_CORE
    BACKSTAGE_CORE --> SEARCH
    
    %% Feedback Loop
    SEARCH --> CHAT_ENGINE
    
    classDef chatClass fill:#e3f2fd
    classDef dataClass fill:#f3e5f5
    classDef docClass fill:#e8f5e8
    classDef integrationClass fill:#fff3e0
    
    class USER,CHAT_UI,CHAT_ENGINE chatClass
    class SHARED_DB,PROCESSOR dataClass
    class MKDOCS,STATIC_DOCS docClass
    class BACKSTAGE_CORE,SEARCH integrationClass
```

## Descripción de Flujos Optimizados

### 1. Flujo de Autenticación Básica Integrada
- **Simplificación**: Autenticación manejada directamente por Backstage Backend
- **Sin tokens JWT**: Sesiones simples para demo
- **Base de datos compartida**: Un solo punto de verificación de usuarios

### 2. Flujo de Chat Directo (Sin API Gateway)
- **Proxy integrado**: Backstage Backend actúa como proxy hacia OpenWebUI
- **Comunicación directa**: Menos latencia y overhead
- **Validación de sesión**: Verificación simple antes del proxy

### 3. Flujo de Documentación Automática
- **Webhook simple**: Trigger directo desde base de datos
- **MkDocs como sidecar**: Contenedor auxiliar para generación
- **Integración nativa**: Uso de TechDocs de Backstage

### 4. Flujo de Búsqueda Integrada
- **Búsqueda nativa**: Uso del motor de búsqueda integrado de Backstage
- **Sin servicios externos**: Todo dentro del ecosistema de Backstage

## Ventajas de los Flujos Simplificados

### Performance
- **Menos saltos de red**: Comunicación directa entre componentes
- **Menor latencia**: Sin API Gateway intermedio
- **Cache opcional**: Redis solo si hay recursos disponibles

### Simplicidad
- **Menos configuración**: Menor complejidad de setup
- **Debugging más fácil**: Menos componentes en la cadena
- **Logs centralizados**: Más fácil seguimiento de requests

### Recursos
- **Menor uso de memoria**: Menos servicios ejecutándose
- **Menor uso de CPU**: Menos overhead de comunicación
- **Startup más rápido**: Menos dependencias entre servicios

## Configuración de Recursos por Flujo

### Flujo de Chat (Crítico)
- **Backstage Backend**: 512Mi RAM, 0.5 CPU
- **OpenWebUI Backend**: 512Mi RAM, 0.5 CPU
- **PostgreSQL**: 256Mi RAM, 0.2 CPU

### Flujo de Documentación (Importante)
- **MkDocs Sidecar**: 128Mi RAM, 0.1 CPU
- **Procesamiento**: Compartido con PostgreSQL

### Flujo de Autenticación (Básico)
- **Integrado en Backstage**: Sin recursos adicionales
- **Sesiones**: Almacenadas en PostgreSQL compartida

## Monitoreo Simplificado

### Logs Nativos de Kubernetes
```bash
# Ver logs de Backstage
kubectl logs -f deployment/backstage

# Ver logs de OpenWebUI
kubectl logs -f deployment/openwebui

# Ver logs de PostgreSQL
kubectl logs -f deployment/postgresql
```

### Métricas Básicas
- **Resource usage**: `kubectl top pods`
- **Status**: `kubectl get pods`
- **Events**: `kubectl get events`

## Troubleshooting de Flujos

### Problemas Comunes
1. **Chat no responde**: Verificar conectividad Backstage → OpenWebUI
2. **Docs no se generan**: Verificar webhook de PostgreSQL → MkDocs
3. **Autenticación falla**: Verificar configuración de base de datos
4. **Performance lenta**: Verificar recursos disponibles en Minikube

### Comandos de Diagnóstico
```bash
# Verificar conectividad interna
kubectl exec -it backstage-pod -- curl http://openwebui-service:8080/health

# Verificar base de datos
kubectl exec -it postgresql-pod -- psql -U postgres -c "\l"

# Verificar recursos
kubectl describe node minikube
```
