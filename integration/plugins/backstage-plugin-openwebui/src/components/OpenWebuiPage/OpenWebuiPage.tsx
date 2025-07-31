import React, { useState, useEffect } from 'react';
import {
  Grid,
  Card,
  CardContent,
  Typography,
  Box,
  Tabs,
  Tab,
  Paper,
} from '@material-ui/core';
import {
  Page,
  Header,
  Content,
  HeaderLabel,
  SupportButton,
} from '@backstage/core-components';
import { useApi } from '@backstage/core-plugin-api';
import { openwebuiApiRef } from '../../api';
import { OpenWebuiChatComponent } from '../OpenWebuiChatComponent';
import { OpenWebuiModelsComponent } from '../OpenWebuiModelsComponent';
import { OpenWebuiHistoryComponent } from '../OpenWebuiHistoryComponent';

interface TabPanelProps {
  children?: React.ReactNode;
  index: number;
  value: number;
}

function TabPanel(props: TabPanelProps) {
  const { children, value, index, ...other } = props;

  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`openwebui-tabpanel-${index}`}
      aria-labelledby={`openwebui-tab-${index}`}
      {...other}
    >
      {value === index && <Box p={3}>{children}</Box>}
    </div>
  );
}

/**
 * Página principal del plugin OpenWebUI
 */
export const OpenWebuiPage = () => {
  const openwebuiApi = useApi(openwebuiApiRef);
  const [currentTab, setCurrentTab] = useState(0);
  const [healthStatus, setHealthStatus] = useState<string>('checking');

  useEffect(() => {
    // Verificar estado de salud de OpenWebUI
    openwebuiApi
      .getHealth()
      .then(health => setHealthStatus(health.status))
      .catch(() => setHealthStatus('error'));
  }, [openwebuiApi]);

  const handleTabChange = (event: React.ChangeEvent<{}>, newValue: number) => {
    setCurrentTab(newValue);
  };

  return (
    <Page themeId="tool">
      <Header
        title="OpenWebUI Integration"
        subtitle="Chat inteligente y generación de contenido para Backstage"
      >
        <HeaderLabel
          label="Status"
          value={healthStatus === 'ok' ? 'Connected' : 'Disconnected'}
          color={healthStatus === 'ok' ? 'green' : 'red'}
        />
        <SupportButton>
          Integración entre Backstage y OpenWebUI para proporcionar capacidades
          de IA contextual, chat inteligente y generación de contenido basado
          en las entidades del catálogo.
        </SupportButton>
      </Header>
      
      <Content>
        <Grid container spacing={3}>
          <Grid item xs={12}>
            <Card>
              <CardContent>
                <Typography variant="h5" component="h2" gutterBottom>
                  OpenWebUI Integration Dashboard
                </Typography>
                <Typography variant="body2" color="textSecondary">
                  Accede a funcionalidades de IA para tus entidades de Backstage
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12}>
            <Paper>
              <Tabs
                value={currentTab}
                onChange={handleTabChange}
                indicatorColor="primary"
                textColor="primary"
                variant="fullWidth"
              >
                <Tab label="Chat Contextual" />
                <Tab label="Modelos Disponibles" />
                <Tab label="Historial" />
              </Tabs>

              <TabPanel value={currentTab} index={0}>
                <OpenWebuiChatComponent />
              </TabPanel>

              <TabPanel value={currentTab} index={1}>
                <OpenWebuiModelsComponent />
              </TabPanel>

              <TabPanel value={currentTab} index={2}>
                <OpenWebuiHistoryComponent />
              </TabPanel>
            </Paper>
          </Grid>
        </Grid>
      </Content>
    </Page>
  );
};
