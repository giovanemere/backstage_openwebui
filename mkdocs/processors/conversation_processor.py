#!/usr/bin/env python3
"""
Procesador de Conversaciones para MkDocs
Procesa conversaciones de chat de OpenWebUI y genera documentación automática
"""

import json
import yaml
import os
import re
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict
from pathlib import Path
import logging
import asyncio
import aiohttp
import markdown
from jinja2 import Environment, FileSystemLoader
import sqlite3
from collections import defaultdict, Counter

# Configuración de logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class ChatMessage:
    """Estructura de mensaje de chat"""
    id: str
    role: str
    content: str
    timestamp: datetime
    entity_context: Optional[Dict[str, Any]] = None
    metadata: Optional[Dict[str, Any]] = None

@dataclass
class ChatSession:
    """Estructura de sesión de chat"""
    id: str
    title: str
    messages: List[ChatMessage]
    entity_context: Optional[Dict[str, Any]] = None
    user_context: Dict[str, Any] = None
    created_at: datetime = None
    updated_at: datetime = None
    summary: Optional[str] = None
    insights: List[str] = None
    tags: List[str] = None

@dataclass
class EntityDocumentation:
    """Documentación generada para una entidad"""
    entity_ref: str
    kind: str
    name: str
    namespace: str
    description: str
    generated_content: str
    conversations_count: int
    last_updated: datetime
    insights: List[str]
    related_entities: List[str]

class ConversationProcessor:
    """Procesador principal de conversaciones"""
    
    def __init__(self, config_path: str = "/app/config"):
        self.config_path = Path(config_path)
        self.docs_output_path = Path("/app/docs-source")
        self.data_path = Path("/app/data")
        self.templates_path = Path("/app/templates")
        
        # Configuración
        self.config = self._load_config()
        
        # Base de datos SQLite para cache
        self.db_path = self.data_path / "conversations.db"
        self._init_database()
        
        # Jinja2 environment
        self.jinja_env = Environment(
            loader=FileSystemLoader(str(self.templates_path)),
            autoescape=True
        )
        
        # URLs de APIs
        self.integration_api_url = self.config.get(
            'integration_api_url',
            'http://backstage-openwebui-integration.integration-demo.svc.cluster.local:8000'
        )
        self.backstage_api_url = self.config.get(
            'backstage_api_url',
            'http://backstage.backstage-demo.svc.cluster.local:7007'
        )
        
        # Cliente HTTP
        self.session = None
    
    def _load_config(self) -> Dict[str, Any]:
        """Cargar configuración"""
        config_file = self.config_path / "processor_config.yaml"
        if config_file.exists():
            with open(config_file, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f)
        return {}
    
    def _init_database(self):
        """Inicializar base de datos SQLite"""
        self.data_path.mkdir(parents=True, exist_ok=True)
        
        with sqlite3.connect(self.db_path) as conn:
            conn.execute('''
                CREATE TABLE IF NOT EXISTS chat_sessions (
                    id TEXT PRIMARY KEY,
                    title TEXT,
                    entity_ref TEXT,
                    entity_kind TEXT,
                    entity_name TEXT,
                    entity_namespace TEXT,
                    user_id TEXT,
                    created_at TIMESTAMP,
                    updated_at TIMESTAMP,
                    message_count INTEGER,
                    summary TEXT,
                    insights TEXT,
                    tags TEXT
                )
            ''')
            
            conn.execute('''
                CREATE TABLE IF NOT EXISTS chat_messages (
                    id TEXT PRIMARY KEY,
                    session_id TEXT,
                    role TEXT,
                    content TEXT,
                    timestamp TIMESTAMP,
                    entity_context TEXT,
                    metadata TEXT,
                    FOREIGN KEY (session_id) REFERENCES chat_sessions (id)
                )
            ''')
            
            conn.execute('''
                CREATE TABLE IF NOT EXISTS entity_docs (
                    entity_ref TEXT PRIMARY KEY,
                    kind TEXT,
                    name TEXT,
                    namespace TEXT,
                    description TEXT,
                    generated_content TEXT,
                    conversations_count INTEGER,
                    last_updated TIMESTAMP,
                    insights TEXT,
                    related_entities TEXT
                )
            ''')
            
            conn.commit()
    
    async def __aenter__(self):
        """Async context manager entry"""
        self.session = aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=30)
        )
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        if self.session:
            await self.session.close()
    
    async def fetch_conversations(self) -> List[ChatSession]:
        """Obtener conversaciones desde la API de integración"""
        try:
            async with self.session.get(f"{self.integration_api_url}/api/chat/history") as response:
                if response.status == 200:
                    data = await response.json()
                    sessions = []
                    
                    for session_data in data:
                        messages = []
                        for msg_data in session_data.get('messages', []):
                            message = ChatMessage(
                                id=msg_data['id'],
                                role=msg_data['role'],
                                content=msg_data['content'],
                                timestamp=datetime.fromisoformat(msg_data['timestamp'].replace('Z', '+00:00')),
                                entity_context=msg_data.get('entity_context'),
                                metadata=msg_data.get('metadata')
                            )
                            messages.append(message)
                        
                        session = ChatSession(
                            id=session_data['id'],
                            title=session_data['title'],
                            messages=messages,
                            entity_context=session_data.get('entity_context'),
                            user_context=session_data.get('user_context'),
                            created_at=datetime.fromisoformat(session_data['created_at'].replace('Z', '+00:00')),
                            updated_at=datetime.fromisoformat(session_data['updated_at'].replace('Z', '+00:00'))
                        )
                        sessions.append(session)
                    
                    return sessions
                else:
                    logger.error(f"Error fetching conversations: {response.status}")
                    return []
        except Exception as e:
            logger.error(f"Error fetching conversations: {e}")
            return []
    
    async def fetch_catalog_entities(self) -> List[Dict[str, Any]]:
        """Obtener entidades del catálogo de Backstage"""
        try:
            async with self.session.get(f"{self.backstage_api_url}/api/catalog/entities") as response:
                if response.status == 200:
                    data = await response.json()
                    return data.get('items', [])
                else:
                    logger.error(f"Error fetching catalog entities: {response.status}")
                    return []
        except Exception as e:
            logger.error(f"Error fetching catalog entities: {e}")
            return []
    
    def _store_sessions(self, sessions: List[ChatSession]):
        """Almacenar sesiones en base de datos"""
        with sqlite3.connect(self.db_path) as conn:
            for session in sessions:
                # Generar resumen e insights
                session.summary = self._generate_session_summary(session)
                session.insights = self._extract_insights(session)
                session.tags = self._generate_tags(session)
                
                # Insertar sesión
                entity_ref = None
                entity_kind = None
                entity_name = None
                entity_namespace = None
                
                if session.entity_context:
                    entity_kind = session.entity_context.get('kind')
                    entity_name = session.entity_context.get('name')
                    entity_namespace = session.entity_context.get('namespace', 'default')
                    entity_ref = f"{entity_kind}:{entity_namespace}/{entity_name}"
                
                conn.execute('''
                    INSERT OR REPLACE INTO chat_sessions 
                    (id, title, entity_ref, entity_kind, entity_name, entity_namespace,
                     user_id, created_at, updated_at, message_count, summary, insights, tags)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    session.id,
                    session.title,
                    entity_ref,
                    entity_kind,
                    entity_name,
                    entity_namespace,
                    session.user_context.get('user_id') if session.user_context else None,
                    session.created_at,
                    session.updated_at,
                    len(session.messages),
                    session.summary,
                    json.dumps(session.insights),
                    json.dumps(session.tags)
                ))
                
                # Insertar mensajes
                for message in session.messages:
                    conn.execute('''
                        INSERT OR REPLACE INTO chat_messages
                        (id, session_id, role, content, timestamp, entity_context, metadata)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        message.id,
                        session.id,
                        message.role,
                        message.content,
                        message.timestamp,
                        json.dumps(message.entity_context) if message.entity_context else None,
                        json.dumps(message.metadata) if message.metadata else None
                    ))
            
            conn.commit()
    
    def _generate_session_summary(self, session: ChatSession) -> str:
        """Generar resumen de sesión"""
        if not session.messages:
            return "Sesión sin mensajes"
        
        # Contar mensajes por rol
        user_messages = [msg for msg in session.messages if msg.role == 'user']
        assistant_messages = [msg for msg in session.messages if msg.role == 'assistant']
        
        # Obtener temas principales
        topics = self._extract_topics(session.messages)
        
        entity_info = ""
        if session.entity_context:
            entity_info = f" sobre {session.entity_context.get('kind')} '{session.entity_context.get('name')}'"
        
        summary = f"Conversación{entity_info} con {len(user_messages)} preguntas del usuario y {len(assistant_messages)} respuestas del asistente."
        
        if topics:
            summary += f" Temas principales: {', '.join(topics[:3])}."
        
        return summary
    
    def _extract_insights(self, session: ChatSession) -> List[str]:
        """Extraer insights de la sesión"""
        insights = []
        
        # Analizar patrones en las preguntas
        user_messages = [msg.content.lower() for msg in session.messages if msg.role == 'user']
        
        # Insights sobre tipos de preguntas
        if any('documentación' in msg or 'docs' in msg for msg in user_messages):
            insights.append("Usuario interesado en documentación")
        
        if any('error' in msg or 'problema' in msg for msg in user_messages):
            insights.append("Sesión de troubleshooting")
        
        if any('cómo' in msg or 'como' in msg for msg in user_messages):
            insights.append("Preguntas de procedimiento")
        
        if any('qué es' in msg or 'que es' in msg for msg in user_messages):
            insights.append("Preguntas conceptuales")
        
        # Insights sobre duración
        if session.created_at and session.updated_at:
            duration = session.updated_at - session.created_at
            if duration > timedelta(hours=1):
                insights.append("Sesión extensa (>1 hora)")
            elif duration < timedelta(minutes=5):
                insights.append("Sesión rápida (<5 minutos)")
        
        # Insights sobre entidad
        if session.entity_context:
            entity_kind = session.entity_context.get('kind')
            if entity_kind == 'Component':
                insights.append("Consulta sobre componente")
            elif entity_kind == 'API':
                insights.append("Consulta sobre API")
            elif entity_kind == 'Resource':
                insights.append("Consulta sobre recurso")
        
        return insights
    
    def _generate_tags(self, session: ChatSession) -> List[str]:
        """Generar tags para la sesión"""
        tags = []
        
        # Tags basados en entidad
        if session.entity_context:
            tags.append(session.entity_context.get('kind', '').lower())
            tags.append(session.entity_context.get('namespace', 'default'))
        
        # Tags basados en contenido
        all_content = ' '.join([msg.content.lower() for msg in session.messages])
        
        if 'kubernetes' in all_content or 'k8s' in all_content:
            tags.append('kubernetes')
        if 'docker' in all_content:
            tags.append('docker')
        if 'api' in all_content:
            tags.append('api')
        if 'database' in all_content or 'db' in all_content:
            tags.append('database')
        if 'deployment' in all_content or 'deploy' in all_content:
            tags.append('deployment')
        if 'error' in all_content or 'problema' in all_content:
            tags.append('troubleshooting')
        if 'documentación' in all_content or 'docs' in all_content:
            tags.append('documentation')
        
        # Tags basados en insights
        if session.insights:
            for insight in session.insights:
                if 'troubleshooting' in insight.lower():
                    tags.append('support')
                if 'documentación' in insight.lower():
                    tags.append('docs')
        
        return list(set(tags))  # Remover duplicados
    
    def _extract_topics(self, messages: List[ChatMessage]) -> List[str]:
        """Extraer temas principales de los mensajes"""
        # Palabras clave técnicas comunes
        technical_keywords = {
            'kubernetes', 'docker', 'api', 'database', 'deployment', 'service',
            'pod', 'container', 'helm', 'yaml', 'json', 'rest', 'graphql',
            'microservice', 'backend', 'frontend', 'auth', 'security',
            'monitoring', 'logging', 'metrics', 'ci/cd', 'pipeline'
        }
        
        # Contar menciones de palabras clave
        keyword_counts = Counter()
        
        for message in messages:
            words = re.findall(r'\b\w+\b', message.content.lower())
            for word in words:
                if word in technical_keywords:
                    keyword_counts[word] += 1
        
        # Retornar los temas más mencionados
        return [topic for topic, count in keyword_counts.most_common(5)]
    
    async def generate_documentation(self):
        """Generar documentación completa"""
        logger.info("Iniciando generación de documentación...")
        
        # Obtener datos
        sessions = await self.fetch_conversations()
        entities = await self.fetch_catalog_entities()
        
        # Almacenar en base de datos
        self._store_sessions(sessions)
        
        # Generar diferentes tipos de documentación
        await self._generate_index_page()
        await self._generate_conversations_docs(sessions)
        await self._generate_entities_docs(entities, sessions)
        await self._generate_insights_docs(sessions)
        await self._generate_api_docs()
        await self._generate_guides()
        
        # Generar datos para templates
        await self._generate_data_files(sessions, entities)
        
        logger.info("Documentación generada exitosamente")
    
    async def _generate_index_page(self):
        """Generar página de inicio"""
        template = self.jinja_env.get_template('index.md.j2')
        
        # Obtener estadísticas
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            
            # Estadísticas generales
            cursor.execute("SELECT COUNT(*) FROM chat_sessions")
            total_sessions = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(*) FROM chat_messages")
            total_messages = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(DISTINCT entity_ref) FROM chat_sessions WHERE entity_ref IS NOT NULL")
            entities_with_conversations = cursor.fetchone()[0]
            
            # Sesiones recientes
            cursor.execute("""
                SELECT title, entity_name, entity_kind, created_at 
                FROM chat_sessions 
                ORDER BY created_at DESC 
                LIMIT 5
            """)
            recent_sessions = cursor.fetchall()
        
        content = template.render(
            total_sessions=total_sessions,
            total_messages=total_messages,
            entities_with_conversations=entities_with_conversations,
            recent_sessions=recent_sessions,
            generated_at=datetime.now()
        )
        
        output_file = self.docs_output_path / "index.md"
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(content)
    
    async def _generate_conversations_docs(self, sessions: List[ChatSession]):
        """Generar documentación de conversaciones"""
        # Crear directorio
        conv_dir = self.docs_output_path / "conversations"
        conv_dir.mkdir(parents=True, exist_ok=True)
        
        # Página de resúmenes
        template = self.jinja_env.get_template('conversations_summary.md.j2')
        content = template.render(sessions=sessions, generated_at=datetime.now())
        
        with open(conv_dir / "summaries.md", 'w', encoding='utf-8') as f:
            f.write(content)
        
        # Conversaciones por entidad
        entity_sessions = defaultdict(list)
        for session in sessions:
            if session.entity_context:
                entity_ref = f"{session.entity_context.get('kind')}:{session.entity_context.get('namespace', 'default')}/{session.entity_context.get('name')}"
                entity_sessions[entity_ref].append(session)
        
        template = self.jinja_env.get_template('conversations_by_entity.md.j2')
        content = template.render(entity_sessions=dict(entity_sessions), generated_at=datetime.now())
        
        with open(conv_dir / "by-entity.md", 'w', encoding='utf-8') as f:
            f.write(content)
        
        # Análisis e insights
        template = self.jinja_env.get_template('conversations_insights.md.j2')
        content = template.render(sessions=sessions, generated_at=datetime.now())
        
        with open(conv_dir / "insights.md", 'w', encoding='utf-8') as f:
            f.write(content)
    
    async def _generate_entities_docs(self, entities: List[Dict[str, Any]], sessions: List[ChatSession]):
        """Generar documentación de entidades"""
        # Crear directorios por tipo de entidad
        catalog_dir = self.docs_output_path / "catalog"
        catalog_dir.mkdir(parents=True, exist_ok=True)
        
        # Agrupar entidades por tipo
        entities_by_kind = defaultdict(list)
        for entity in entities:
            kind = entity.get('kind', 'Unknown')
            entities_by_kind[kind].append(entity)
        
        # Mapear sesiones por entidad
        sessions_by_entity = defaultdict(list)
        for session in sessions:
            if session.entity_context:
                entity_ref = f"{session.entity_context.get('kind')}:{session.entity_context.get('namespace', 'default')}/{session.entity_context.get('name')}"
                sessions_by_entity[entity_ref].append(session)
        
        # Generar documentación por tipo
        for kind, kind_entities in entities_by_kind.items():
            template = self.jinja_env.get_template('catalog_entities.md.j2')
            content = template.render(
                kind=kind,
                entities=kind_entities,
                sessions_by_entity=dict(sessions_by_entity),
                generated_at=datetime.now()
            )
            
            filename = f"{kind.lower()}s.md"
            with open(catalog_dir / filename, 'w', encoding='utf-8') as f:
                f.write(content)
    
    async def _generate_insights_docs(self, sessions: List[ChatSession]):
        """Generar documentación de insights"""
        template = self.jinja_env.get_template('analysis.md.j2')
        
        # Análisis de patrones
        all_insights = []
        all_tags = []
        
        for session in sessions:
            if session.insights:
                all_insights.extend(session.insights)
            if session.tags:
                all_tags.extend(session.tags)
        
        insight_counts = Counter(all_insights)
        tag_counts = Counter(all_tags)
        
        # Análisis temporal
        sessions_by_date = defaultdict(int)
        for session in sessions:
            if session.created_at:
                date_key = session.created_at.strftime('%Y-%m-%d')
                sessions_by_date[date_key] += 1
        
        content = template.render(
            sessions=sessions,
            insight_counts=dict(insight_counts.most_common(10)),
            tag_counts=dict(tag_counts.most_common(10)),
            sessions_by_date=dict(sessions_by_date),
            generated_at=datetime.now()
        )
        
        analysis_dir = self.docs_output_path / "conversations"
        analysis_dir.mkdir(parents=True, exist_ok=True)
        
        with open(analysis_dir / "analysis.md", 'w', encoding='utf-8') as f:
            f.write(content)
    
    async def _generate_api_docs(self):
        """Generar documentación de API"""
        api_dir = self.docs_output_path / "api"
        api_dir.mkdir(parents=True, exist_ok=True)
        
        # Documentación de endpoints
        template = self.jinja_env.get_template('api_endpoints.md.j2')
        content = template.render(generated_at=datetime.now())
        
        with open(api_dir / "endpoints.md", 'w', encoding='utf-8') as f:
            f.write(content)
        
        # Documentación de webhooks
        template = self.jinja_env.get_template('api_webhooks.md.j2')
        content = template.render(generated_at=datetime.now())
        
        with open(api_dir / "webhooks.md", 'w', encoding='utf-8') as f:
            f.write(content)
    
    async def _generate_guides(self):
        """Generar guías de usuario"""
        guides_dir = self.docs_output_path / "guides"
        guides_dir.mkdir(parents=True, exist_ok=True)
        
        # Lista de guías a generar
        guides = [
            'quick-start.md.j2',
            'contextual-chat.md.j2',
            'content-generation.md.j2',
            'troubleshooting.md.j2'
        ]
        
        for guide_template in guides:
            template = self.jinja_env.get_template(guide_template)
            content = template.render(generated_at=datetime.now())
            
            output_file = guides_dir / guide_template.replace('.j2', '')
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(content)
    
    async def _generate_data_files(self, sessions: List[ChatSession], entities: List[Dict[str, Any]]):
        """Generar archivos de datos para templates"""
        data_dir = self.data_path
        data_dir.mkdir(parents=True, exist_ok=True)
        
        # Datos de conversaciones
        conversations_data = {
            'total_sessions': len(sessions),
            'sessions_by_entity': {},
            'recent_sessions': [],
            'top_insights': [],
            'top_tags': []
        }
        
        # Procesar sesiones
        entity_sessions = defaultdict(int)
        all_insights = []
        all_tags = []
        
        for session in sessions:
            if session.entity_context:
                entity_ref = f"{session.entity_context.get('kind')}:{session.entity_context.get('name')}"
                entity_sessions[entity_ref] += 1
            
            if session.insights:
                all_insights.extend(session.insights)
            if session.tags:
                all_tags.extend(session.tags)
        
        conversations_data['sessions_by_entity'] = dict(entity_sessions)
        conversations_data['top_insights'] = [item for item, count in Counter(all_insights).most_common(5)]
        conversations_data['top_tags'] = [item for item, count in Counter(all_tags).most_common(10)]
        
        # Sesiones recientes
        recent_sessions = sorted(sessions, key=lambda x: x.updated_at or x.created_at, reverse=True)[:5]
        conversations_data['recent_sessions'] = [
            {
                'title': session.title,
                'entity': session.entity_context.get('name') if session.entity_context else None,
                'updated_at': session.updated_at.isoformat() if session.updated_at else None
            }
            for session in recent_sessions
        ]
        
        with open(data_dir / "conversations.yml", 'w', encoding='utf-8') as f:
            yaml.dump(conversations_data, f, default_flow_style=False, allow_unicode=True)
        
        # Datos de entidades
        entities_data = {
            'total_entities': len(entities),
            'entities_by_kind': {},
            'entities_with_conversations': 0
        }
        
        entities_by_kind = defaultdict(int)
        entities_with_conversations = 0
        
        for entity in entities:
            kind = entity.get('kind', 'Unknown')
            entities_by_kind[kind] += 1
            
            # Verificar si tiene conversaciones
            entity_ref = f"{kind}:{entity.get('metadata', {}).get('name')}"
            if entity_ref in entity_sessions:
                entities_with_conversations += 1
        
        entities_data['entities_by_kind'] = dict(entities_by_kind)
        entities_data['entities_with_conversations'] = entities_with_conversations
        
        with open(data_dir / "entities.yml", 'w', encoding='utf-8') as f:
            yaml.dump(entities_data, f, default_flow_style=False, allow_unicode=True)
        
        # Métricas generales
        metrics_data = {
            'last_updated': datetime.now().isoformat(),
            'total_conversations': len(sessions),
            'total_entities': len(entities),
            'total_messages': sum(len(session.messages) for session in sessions),
            'avg_messages_per_session': sum(len(session.messages) for session in sessions) / len(sessions) if sessions else 0,
            'entities_with_conversations': entities_with_conversations,
            'conversation_coverage': (entities_with_conversations / len(entities) * 100) if entities else 0
        }
        
        with open(data_dir / "metrics.yml", 'w', encoding='utf-8') as f:
            yaml.dump(metrics_data, f, default_flow_style=False, allow_unicode=True)

async def main():
    """Función principal"""
    processor = ConversationProcessor()
    
    async with processor:
        await processor.generate_documentation()

if __name__ == "__main__":
    asyncio.run(main())
