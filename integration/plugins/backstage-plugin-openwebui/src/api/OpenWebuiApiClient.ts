import {
  ConfigApi,
  IdentityApi,
} from '@backstage/core-plugin-api';
import {
  OpenWebuiApi,
  ChatSession,
  ChatMessage,
  EntityContext,
  GenerationRequest,
  GenerationResponse,
  ModelInfo,
  UserContext,
} from './types';

/**
 * Cliente API para comunicación con OpenWebUI
 */
export class OpenWebuiApiClient implements OpenWebuiApi {
  private readonly configApi: ConfigApi;
  private readonly identityApi: IdentityApi;
  private readonly baseUrl: string;

  constructor(options: {
    configApi: ConfigApi;
    identityApi: IdentityApi;
  }) {
    this.configApi = options.configApi;
    this.identityApi = options.identityApi;
    
    // Obtener URL base de OpenWebUI desde configuración
    this.baseUrl = this.configApi.getOptionalString('openwebui.baseUrl') || 
                   'http://openwebui.openwebui-demo.svc.cluster.local:8080';
  }

  private async getAuthHeaders(): Promise<Record<string, string>> {
    const { token } = await this.identityApi.getCredentials();
    return {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  private async getUserContext(): Promise<UserContext> {
    const profile = await this.identityApi.getProfileInfo();
    return {
      userId: profile.email || 'anonymous',
      displayName: profile.displayName,
      email: profile.email,
    };
  }

  async startChatSession(
    entityContext: EntityContext,
    initialMessage?: string
  ): Promise<ChatSession> {
    const headers = await this.getAuthHeaders();
    const userContext = await this.getUserContext();

    const response = await fetch(`${this.baseUrl}/api/chat/start`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        entityContext,
        userContext,
        initialMessage,
      }),
    });

    if (!response.ok) {
      throw new Error(`Failed to start chat session: ${response.statusText}`);
    }

    const data = await response.json();
    return {
      ...data,
      createdAt: new Date(data.createdAt),
      updatedAt: new Date(data.updatedAt),
      messages: data.messages.map((msg: any) => ({
        ...msg,
        timestamp: new Date(msg.timestamp),
      })),
    };
  }

  async sendMessage(sessionId: string, message: string): Promise<ChatMessage> {
    const headers = await this.getAuthHeaders();

    const response = await fetch(`${this.baseUrl}/api/chat/${sessionId}/message`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        content: message,
      }),
    });

    if (!response.ok) {
      throw new Error(`Failed to send message: ${response.statusText}`);
    }

    const data = await response.json();
    return {
      ...data,
      timestamp: new Date(data.timestamp),
    };
  }

  async getChatHistory(entityRef: string): Promise<ChatSession[]> {
    const headers = await this.getAuthHeaders();

    const response = await fetch(
      `${this.baseUrl}/api/chat/history?entityRef=${encodeURIComponent(entityRef)}`,
      {
        method: 'GET',
        headers,
      }
    );

    if (!response.ok) {
      throw new Error(`Failed to get chat history: ${response.statusText}`);
    }

    const data = await response.json();
    return data.map((session: any) => ({
      ...session,
      createdAt: new Date(session.createdAt),
      updatedAt: new Date(session.updatedAt),
      messages: session.messages.map((msg: any) => ({
        ...msg,
        timestamp: new Date(msg.timestamp),
      })),
    }));
  }

  async generateContent(request: GenerationRequest): Promise<GenerationResponse> {
    const headers = await this.getAuthHeaders();

    const response = await fetch(`${this.baseUrl}/api/generate`, {
      method: 'POST',
      headers,
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      throw new Error(`Failed to generate content: ${response.statusText}`);
    }

    const data = await response.json();
    return {
      ...data,
      timestamp: new Date(data.timestamp),
    };
  }

  async getAvailableModels(): Promise<ModelInfo[]> {
    const headers = await this.getAuthHeaders();

    const response = await fetch(`${this.baseUrl}/api/models`, {
      method: 'GET',
      headers,
    });

    if (!response.ok) {
      throw new Error(`Failed to get models: ${response.statusText}`);
    }

    return response.json();
  }

  async getHealth(): Promise<{ status: string; timestamp: Date }> {
    const response = await fetch(`${this.baseUrl}/health`, {
      method: 'GET',
    });

    if (!response.ok) {
      throw new Error(`Health check failed: ${response.statusText}`);
    }

    const data = await response.json();
    return {
      ...data,
      timestamp: new Date(data.timestamp || Date.now()),
    };
  }

  async enrichEntity(entityContext: EntityContext): Promise<{
    description?: string;
    tags?: string[];
    documentation?: string;
    relationships?: Array<{
      type: string;
      description: string;
      confidence: number;
    }>;
  }> {
    const headers = await this.getAuthHeaders();

    const response = await fetch(`${this.baseUrl}/api/enrich`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        entityContext,
      }),
    });

    if (!response.ok) {
      throw new Error(`Failed to enrich entity: ${response.statusText}`);
    }

    return response.json();
  }
}
