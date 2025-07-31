import {
  createPlugin,
  createRoutableExtension,
  createApiFactory,
  configApiRef,
  identityApiRef,
} from '@backstage/core-plugin-api';
import { rootRouteRef } from './routes';
import { openwebuiApiRef, OpenWebuiApiClient } from './api';

/**
 * Plugin principal de OpenWebUI para Backstage
 */
export const openwebuiPlugin = createPlugin({
  id: 'openwebui',
  routes: {
    root: rootRouteRef,
  },
  apis: [
    createApiFactory({
      api: openwebuiApiRef,
      deps: {
        configApi: configApiRef,
        identityApi: identityApiRef,
      },
      factory: ({ configApi, identityApi }) =>
        new OpenWebuiApiClient({
          configApi,
          identityApi,
        }),
    }),
  ],
});

/**
 * Página principal del plugin OpenWebUI
 */
export const OpenWebuiPage = openwebuiPlugin.provide(
  createRoutableExtension({
    name: 'OpenWebuiPage',
    component: () =>
      import('./components/OpenWebuiPage').then(m => m.OpenWebuiPage),
    mountPoint: rootRouteRef,
  }),
);
