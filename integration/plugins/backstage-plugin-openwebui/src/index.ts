/**
 * Backstage Plugin for OpenWebUI Integration
 * 
 * Este plugin proporciona integración entre Backstage y OpenWebUI,
 * permitiendo chat contextual, generación de contenido y análisis de entidades.
 */

export { openwebuiPlugin, OpenWebuiPage } from './plugin';
export { OpenWebuiChatComponent } from './components/OpenWebuiChatComponent';
export { OpenWebuiEntityCard } from './components/OpenWebuiEntityCard';
export { OpenWebuiGenerateButton } from './components/OpenWebuiGenerateButton';
export { openwebuiApiRef } from './api';
export type { OpenWebuiApi, ChatMessage, EntityContext, GenerationRequest } from './api';
