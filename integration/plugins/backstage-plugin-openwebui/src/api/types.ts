/**
 * Tipos para la API de OpenWebUI
 */

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: Date;
  entityContext?: EntityContext;
  metadata?: Record<string, any>;
}

export interface EntityContext {
  kind: string;
  namespace: string;
  name: string;
  metadata: Record<string, any>;
  spec?: Record<string, any>;
  relations?: Array<{
    type: string;
    targetRef: string;
  }>;
}

export interface UserContext {
  userId: string;
  displayName?: string;
  email?: string;
  groups?: string[];
}

export interface ChatSession {
  id: string;
  title: string;
  messages: ChatMessage[];
  entityContext?: EntityContext;
  userContext: UserContext;
  createdAt: Date;
  updatedAt: Date;
}

export interface GenerationRequest {
  template: string;
  entityContext: EntityContext;
  userContext: UserContext;
  parameters?: Record<string, any>;
}

export interface GenerationResponse {
  content: string;
  model: string;
  timestamp: Date;
  metadata?: Record<string, any>;
}

export interface ModelInfo {
  id: string;
  name: string;
  description?: string;
  capabilities: string[];
  parameters?: Record<string, any>;
}

export interface OpenWebuiApi {
  /**
   * Iniciar una nueva sesión de chat con contexto de entidad
   */
  startChatSession(entityContext: EntityContext, initialMessage?: string): Promise<ChatSession>;

  /**
   * Enviar mensaje en una sesión de chat existente
   */
  sendMessage(sessionId: string, message: string): Promise<ChatMessage>;

  /**
   * Obtener historial de chat para una entidad
   */
  getChatHistory(entityRef: string): Promise<ChatSession[]>;

  /**
   * Generar contenido basado en plantilla y contexto
   */
  generateContent(request: GenerationRequest): Promise<GenerationResponse>;

  /**
   * Obtener modelos disponibles
   */
  getAvailableModels(): Promise<ModelInfo[]>;

  /**
   * Obtener información de salud del servicio
   */
  getHealth(): Promise<{ status: string; timestamp: Date }>;

  /**
   * Enriquecer entidad con información generada por IA
   */
  enrichEntity(entityContext: EntityContext): Promise<{
    description?: string;
    tags?: string[];
    documentation?: string;
    relationships?: Array<{
      type: string;
      description: string;
      confidence: number;
    }>;
  }>;
}
