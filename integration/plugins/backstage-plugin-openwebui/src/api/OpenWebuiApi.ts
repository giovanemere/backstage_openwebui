import { createApiRef } from '@backstage/core-plugin-api';
import { OpenWebuiApi } from './types';

/**
 * API Reference para OpenWebUI
 */
export const openwebuiApiRef = createApiRef<OpenWebuiApi>({
  id: 'plugin.openwebui.service',
});
