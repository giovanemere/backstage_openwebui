#!/usr/bin/env python3
"""
API de Integración OpenWebUI-Backstage
Proporciona endpoints para la comunicación entre OpenWebUI y Backstage
"""

from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime
import uuid
import json
import httpx
import os
import logging
from contextlib import asynccontextmanager

# Configuración de logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Modelos de datos
class EntityContext(BaseModel):
    kind: str
    namespace: str = "default"
    name: str
    metadata: Dict[str, Any]
    spec: Optional[Dict[str, Any]] = None
    relations: Optional[List[Dict[str, str]]] = None

class UserContext(BaseModel):
    user_id: str
    display_name: Optional[str] = None
    email: Optional[str] = None
    groups: Optional[List[str]] = None

class ChatMessage(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    role: str = Field(..., regex="^(user|assistant|system)$")
    content: str
    timestamp: datetime = Field(default_factory=datetime.now)
    entity_context: Optional[EntityContext] = None
    metadata: Optional[Dict[str, Any]] = None

class ChatSession(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    title: str
    messages: List[ChatMessage] = []
    entity_context: Optional[EntityContext] = None
    user_context: UserContext
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: datetime = Field(default_factory=datetime.now)

class StartChatRequest(BaseModel):
    entity_context: EntityContext
    user_context: UserContext
    initial_message: Optional[str] = None

class SendMessageRequest(BaseModel):
    content: str

class GenerationRequest(BaseModel):
    template: str
    entity_context: EntityContext
    user_context: UserContext
    parameters: Optional[Dict[str, Any]] = None

class GenerationResponse(BaseModel):
    content: str
    model: str
    timestamp: datetime = Field(default_factory=datetime.now)
    metadata: Optional[Dict[str, Any]] = None

class ModelInfo(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    capabilities: List[str]
    parameters: Optional[Dict[str, Any]] = None

class HealthResponse(BaseModel):
    status: str
    timestamp: datetime = Field(default_factory=datetime.now)
    services: Dict[str, str]

class EntityEnrichmentResponse(BaseModel):
    description: Optional[str] = None
    tags: Optional[List[str]] = None
    documentation: Optional[str] = None
    relationships: Optional[List[Dict[str, Any]]] = None

# Configuración
class Config:
    BACKSTAGE_BASE_URL = os.getenv("BACKSTAGE_BASE_URL", "http://backstage.backstage-demo.svc.cluster.local:7007")
    OPENWEBUI_BASE_URL = os.getenv("OPENWEBUI_BASE_URL", "http://openwebui.openwebui-demo.svc.cluster.local:8080")
    INTEGRATION_TOKEN = os.getenv("INTEGRATION_TOKEN", "demo-integration-token")
    WEBHOOK_SECRET = os.getenv("WEBHOOK_SECRET", "demo-webhook-secret")

config = Config()

# Storage en memoria para demo (en producción usar base de datos)
chat_sessions: Dict[str, ChatSession] = {}
user_sessions: Dict[str, List[str]] = {}

# Cliente HTTP
http_client = httpx.AsyncClient(timeout=30.0)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Gestión del ciclo de vida de la aplicación"""
    logger.info("Starting OpenWebUI Integration API")
    yield
    logger.info("Shutting down OpenWebUI Integration API")
    await http_client.aclose()

# Crear aplicación FastAPI
app = FastAPI(
    title="OpenWebUI-Backstage Integration API",
    description="API para integración entre OpenWebUI y Backstage",
    version="1.0.0",
    lifespan=lifespan
)

# Configurar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En producción, especificar orígenes exactos
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Dependencias
async def verify_token(authorization: str = Header(None)):
    """Verificar token de autorización"""
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header required")
    
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization format")
    
    token = authorization.split(" ")[1]
    if token != config.INTEGRATION_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    return token

async def get_backstage_entity(entity_ref: str) -> Optional[Dict[str, Any]]:
    """Obtener entidad de Backstage"""
    try:
        response = await http_client.get(
            f"{config.BACKSTAGE_BASE_URL}/api/catalog/entities/by-name/{entity_ref}",
            headers={"Authorization": f"Bearer {config.INTEGRATION_TOKEN}"}
        )
        if response.status_code == 200:
            return response.json()
        return None
    except Exception as e:
        logger.error(f"Error fetching Backstage entity: {e}")
        return None

async def call_openwebui_api(endpoint: str, method: str = "GET", data: Dict = None) -> Optional[Dict]:
    """Llamar API de OpenWebUI"""
    try:
        url = f"{config.OPENWEBUI_BASE_URL}{endpoint}"
        headers = {"Authorization": f"Bearer {config.INTEGRATION_TOKEN}"}
        
        if method == "GET":
            response = await http_client.get(url, headers=headers)
        elif method == "POST":
            response = await http_client.post(url, headers=headers, json=data)
        else:
            raise ValueError(f"Unsupported method: {method}")
        
        if response.status_code in [200, 201]:
            return response.json()
        return None
    except Exception as e:
        logger.error(f"Error calling OpenWebUI API: {e}")
        return None

# Endpoints principales

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Verificar estado de salud del servicio"""
    services = {}
    
    # Verificar Backstage
    try:
        response = await http_client.get(f"{config.BACKSTAGE_BASE_URL}/api/catalog/health")
        services["backstage"] = "ok" if response.status_code == 200 else "error"
    except:
        services["backstage"] = "error"
    
    # Verificar OpenWebUI
    try:
        response = await http_client.get(f"{config.OPENWEBUI_BASE_URL}/health")
        services["openwebui"] = "ok" if response.status_code == 200 else "error"
    except:
        services["openwebui"] = "error"
    
    overall_status = "ok" if all(status == "ok" for status in services.values()) else "degraded"
    
    return HealthResponse(
        status=overall_status,
        services=services
    )

@app.post("/api/chat/start", response_model=ChatSession)
async def start_chat_session(
    request: StartChatRequest,
    token: str = Depends(verify_token)
):
    """Iniciar nueva sesión de chat con contexto de entidad"""
    
    # Crear sesión de chat
    session = ChatSession(
        title=f"Chat sobre {request.entity_context.kind}: {request.entity_context.name}",
        entity_context=request.entity_context,
        user_context=request.user_context
    )
    
    # Agregar mensaje inicial del sistema
    system_message = ChatMessage(
        role="system",
        content=f"Eres un asistente de IA especializado en ayudar con entidades de Backstage. "
                f"Actualmente estás ayudando con {request.entity_context.kind} '{request.entity_context.name}' "
                f"en el namespace '{request.entity_context.namespace}'. "
                f"Proporciona información útil, precisa y contextual sobre esta entidad."
    )
    session.messages.append(system_message)
    
    # Agregar mensaje inicial si se proporciona
    if request.initial_message:
        user_message = ChatMessage(
            role="user",
            content=request.initial_message,
            entity_context=request.entity_context
        )
        session.messages.append(user_message)
        
        # Generar respuesta inicial (simulada para demo)
        assistant_response = await generate_ai_response(
            request.initial_message,
            request.entity_context,
            request.user_context
        )
        
        assistant_message = ChatMessage(
            role="assistant",
            content=assistant_response,
            entity_context=request.entity_context
        )
        session.messages.append(assistant_message)
    
    # Guardar sesión
    chat_sessions[session.id] = session
    
    # Asociar sesión con usuario
    if request.user_context.user_id not in user_sessions:
        user_sessions[request.user_context.user_id] = []
    user_sessions[request.user_context.user_id].append(session.id)
    
    logger.info(f"Started chat session {session.id} for user {request.user_context.user_id}")
    
    return session

@app.post("/api/chat/{session_id}/message", response_model=ChatMessage)
async def send_message(
    session_id: str,
    request: SendMessageRequest,
    token: str = Depends(verify_token)
):
    """Enviar mensaje en sesión de chat existente"""
    
    if session_id not in chat_sessions:
        raise HTTPException(status_code=404, detail="Chat session not found")
    
    session = chat_sessions[session_id]
    
    # Agregar mensaje del usuario
    user_message = ChatMessage(
        role="user",
        content=request.content,
        entity_context=session.entity_context
    )
    session.messages.append(user_message)
    
    # Generar respuesta de IA
    ai_response = await generate_ai_response(
        request.content,
        session.entity_context,
        session.user_context
    )
    
    assistant_message = ChatMessage(
        role="assistant",
        content=ai_response,
        entity_context=session.entity_context
    )
    session.messages.append(assistant_message)
    
    # Actualizar timestamp de sesión
    session.updated_at = datetime.now()
    
    logger.info(f"Message sent in session {session_id}")
    
    return assistant_message

@app.get("/api/chat/history", response_model=List[ChatSession])
async def get_chat_history(
    entity_ref: Optional[str] = None,
    token: str = Depends(verify_token)
):
    """Obtener historial de chat"""
    
    sessions = list(chat_sessions.values())
    
    if entity_ref:
        # Filtrar por entidad específica
        sessions = [
            session for session in sessions
            if session.entity_context and 
            f"{session.entity_context.kind}:{session.entity_context.namespace}/{session.entity_context.name}" == entity_ref
        ]
    
    # Ordenar por fecha de actualización (más reciente primero)
    sessions.sort(key=lambda x: x.updated_at, reverse=True)
    
    return sessions

@app.post("/api/generate", response_model=GenerationResponse)
async def generate_content(
    request: GenerationRequest,
    token: str = Depends(verify_token)
):
    """Generar contenido basado en plantilla y contexto"""
    
    # Generar contenido usando la plantilla y contexto
    content = await generate_templated_content(
        request.template,
        request.entity_context,
        request.user_context,
        request.parameters or {}
    )
    
    return GenerationResponse(
        content=content,
        model="demo-model",
        metadata={
            "template": request.template,
            "entity": f"{request.entity_context.kind}:{request.entity_context.name}",
            "parameters": request.parameters
        }
    )

@app.get("/api/models", response_model=List[ModelInfo])
async def get_available_models(token: str = Depends(verify_token)):
    """Obtener modelos disponibles"""
    
    # Para demo, devolver modelos simulados
    return [
        ModelInfo(
            id="demo-chat-model",
            name="Demo Chat Model",
            description="Modelo de chat para demostración",
            capabilities=["chat", "context-aware", "entity-analysis"]
        ),
        ModelInfo(
            id="demo-generation-model",
            name="Demo Generation Model",
            description="Modelo de generación de contenido",
            capabilities=["content-generation", "documentation", "templates"]
        )
    ]

@app.post("/api/enrich", response_model=EntityEnrichmentResponse)
async def enrich_entity(
    request: Dict[str, Any],
    token: str = Depends(verify_token)
):
    """Enriquecer entidad con información generada por IA"""
    
    entity_context = EntityContext(**request["entityContext"])
    
    # Generar enriquecimiento (simulado para demo)
    enrichment = await generate_entity_enrichment(entity_context)
    
    return enrichment

@app.post("/api/webhooks/backstage")
async def backstage_webhook(
    request: Dict[str, Any],
    x_webhook_secret: str = Header(None)
):
    """Webhook para recibir eventos de Backstage"""
    
    if x_webhook_secret != config.WEBHOOK_SECRET:
        raise HTTPException(status_code=401, detail="Invalid webhook secret")
    
    event_type = request.get("event_type")
    entity = request.get("entity")
    
    logger.info(f"Received Backstage webhook: {event_type} for entity {entity}")
    
    # Procesar evento según tipo
    if event_type == "entity_created":
        await handle_entity_created(entity)
    elif event_type == "entity_updated":
        await handle_entity_updated(entity)
    elif event_type == "entity_deleted":
        await handle_entity_deleted(entity)
    
    return {"status": "processed"}

# Funciones auxiliares

async def generate_ai_response(
    message: str,
    entity_context: Optional[EntityContext],
    user_context: UserContext
) -> str:
    """Generar respuesta de IA (simulada para demo)"""
    
    if not entity_context:
        return "Hola! ¿En qué puedo ayudarte hoy?"
    
    entity_info = f"{entity_context.kind} '{entity_context.name}'"
    
    # Respuestas contextuales simuladas
    if "información" in message.lower() or "info" in message.lower():
        return f"Te puedo ayudar con información sobre {entity_info}. " \
               f"Esta entidad está en el namespace '{entity_context.namespace}' " \
               f"y tiene las siguientes características: {json.dumps(entity_context.metadata, indent=2)}"
    
    elif "documentación" in message.lower() or "docs" in message.lower():
        return f"Para {entity_info}, puedo ayudarte a generar documentación técnica, " \
               f"explicar su propósito, describir sus dependencias y proporcionar ejemplos de uso."
    
    elif "relaciones" in message.lower() or "dependencias" in message.lower():
        relations_info = ""
        if entity_context.relations:
            relations_info = f"Esta entidad tiene {len(entity_context.relations)} relaciones: " + \
                           ", ".join([f"{rel['type']} -> {rel['targetRef']}" for rel in entity_context.relations])
        else:
            relations_info = "No se encontraron relaciones definidas para esta entidad."
        
        return f"Respecto a las relaciones de {entity_info}: {relations_info}"
    
    else:
        return f"Entiendo que quieres saber sobre {entity_info}. " \
               f"Puedo ayudarte con información general, documentación, relaciones, " \
               f"mejores prácticas y análisis de esta entidad. ¿Qué te interesa específicamente?"

async def generate_templated_content(
    template: str,
    entity_context: EntityContext,
    user_context: UserContext,
    parameters: Dict[str, Any]
) -> str:
    """Generar contenido usando plantilla"""
    
    # Plantillas simuladas para demo
    if template == "documentation":
        return f"""# {entity_context.name}

## Descripción
{entity_context.metadata.get('description', 'Descripción generada automáticamente')}

## Tipo
{entity_context.kind}

## Namespace
{entity_context.namespace}

## Metadatos
{json.dumps(entity_context.metadata, indent=2)}

## Especificación
{json.dumps(entity_context.spec or {}, indent=2)}

---
*Documentación generada automáticamente por OpenWebUI Integration*
"""
    
    elif template == "readme":
        return f"""# {entity_context.name}

{entity_context.metadata.get('description', 'Componente de la arquitectura')}

## Información General
- **Tipo**: {entity_context.kind}
- **Namespace**: {entity_context.namespace}
- **Owner**: {entity_context.metadata.get('owner', 'No especificado')}

## Tags
{', '.join(entity_context.metadata.get('tags', []))}

## Enlaces
{json.dumps(entity_context.metadata.get('links', []), indent=2)}
"""
    
    else:
        return f"Contenido generado para {entity_context.name} usando plantilla '{template}'"

async def generate_entity_enrichment(entity_context: EntityContext) -> EntityEnrichmentResponse:
    """Generar enriquecimiento de entidad"""
    
    # Simulación de enriquecimiento con IA
    return EntityEnrichmentResponse(
        description=f"Descripción mejorada para {entity_context.kind} {entity_context.name}",
        tags=["ai-enhanced", "auto-generated", entity_context.kind.lower()],
        documentation=f"Documentación automática generada para {entity_context.name}",
        relationships=[
            {
                "type": "depends-on",
                "description": "Dependencia inferida por análisis de IA",
                "confidence": 0.8
            }
        ]
    )

async def handle_entity_created(entity: Dict[str, Any]):
    """Manejar evento de entidad creada"""
    logger.info(f"Entity created: {entity}")

async def handle_entity_updated(entity: Dict[str, Any]):
    """Manejar evento de entidad actualizada"""
    logger.info(f"Entity updated: {entity}")

async def handle_entity_deleted(entity: Dict[str, Any]):
    """Manejar evento de entidad eliminada"""
    logger.info(f"Entity deleted: {entity}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "openwebui-integration-api:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
