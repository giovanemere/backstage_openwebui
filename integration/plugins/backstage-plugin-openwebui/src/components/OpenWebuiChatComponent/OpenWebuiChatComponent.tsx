import React, { useState, useEffect, useRef } from 'react';
import {
  Box,
  TextField,
  Button,
  Paper,
  Typography,
  List,
  ListItem,
  ListItemText,
  Avatar,
  Chip,
  CircularProgress,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
} from '@material-ui/core';
import { makeStyles } from '@material-ui/core/styles';
import { Send as SendIcon, Person as PersonIcon, SmartToy as BotIcon } from '@material-ui/icons';
import { useApi } from '@backstage/core-plugin-api';
import { catalogApiRef } from '@backstage/plugin-catalog-react';
import { openwebuiApiRef } from '../../api';
import { ChatMessage, EntityContext, ChatSession } from '../../api/types';

const useStyles = makeStyles(theme => ({
  chatContainer: {
    height: '600px',
    display: 'flex',
    flexDirection: 'column',
  },
  messagesContainer: {
    flex: 1,
    overflow: 'auto',
    padding: theme.spacing(1),
    backgroundColor: theme.palette.background.default,
  },
  messageItem: {
    marginBottom: theme.spacing(1),
  },
  userMessage: {
    display: 'flex',
    justifyContent: 'flex-end',
  },
  assistantMessage: {
    display: 'flex',
    justifyContent: 'flex-start',
  },
  messageBubble: {
    maxWidth: '70%',
    padding: theme.spacing(1, 2),
    borderRadius: theme.spacing(2),
  },
  userBubble: {
    backgroundColor: theme.palette.primary.main,
    color: theme.palette.primary.contrastText,
  },
  assistantBubble: {
    backgroundColor: theme.palette.grey[200],
    color: theme.palette.text.primary,
  },
  inputContainer: {
    padding: theme.spacing(2),
    borderTop: `1px solid ${theme.palette.divider}`,
  },
  inputRow: {
    display: 'flex',
    gap: theme.spacing(1),
    alignItems: 'flex-end',
  },
  messageInput: {
    flex: 1,
  },
  entitySelector: {
    minWidth: 200,
    marginBottom: theme.spacing(2),
  },
  contextChip: {
    margin: theme.spacing(0.5),
  },
}));

/**
 * Componente de chat contextual con OpenWebUI
 */
export const OpenWebuiChatComponent = () => {
  const classes = useStyles();
  const openwebuiApi = useApi(openwebuiApiRef);
  const catalogApi = useApi(catalogApiRef);
  
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [currentMessage, setCurrentMessage] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [currentSession, setCurrentSession] = useState<ChatSession | null>(null);
  const [selectedEntity, setSelectedEntity] = useState<EntityContext | null>(null);
  const [availableEntities, setAvailableEntities] = useState<EntityContext[]>([]);
  
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // Cargar entidades disponibles del catálogo
    loadAvailableEntities();
  }, []);

  useEffect(() => {
    // Scroll automático al final de los mensajes
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const loadAvailableEntities = async () => {
    try {
      const { items } = await catalogApi.getEntities({
        filter: {
          kind: ['Component', 'API', 'Resource', 'System'],
        },
      });

      const entities: EntityContext[] = items.map(entity => ({
        kind: entity.kind,
        namespace: entity.metadata.namespace || 'default',
        name: entity.metadata.name,
        metadata: entity.metadata,
        spec: entity.spec,
        relations: entity.relations?.map(rel => ({
          type: rel.type,
          targetRef: rel.targetRef,
        })),
      }));

      setAvailableEntities(entities);
    } catch (error) {
      console.error('Error loading entities:', error);
    }
  };

  const startNewSession = async (entity: EntityContext) => {
    try {
      setIsLoading(true);
      const session = await openwebuiApi.startChatSession(
        entity,
        `Hola! Me gustaría obtener información sobre ${entity.kind} "${entity.name}".`
      );
      
      setCurrentSession(session);
      setMessages(session.messages);
      setSelectedEntity(entity);
    } catch (error) {
      console.error('Error starting chat session:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const sendMessage = async () => {
    if (!currentMessage.trim() || !currentSession || isLoading) {
      return;
    }

    const userMessage: ChatMessage = {
      id: `temp-${Date.now()}`,
      role: 'user',
      content: currentMessage,
      timestamp: new Date(),
      entityContext: selectedEntity || undefined,
    };

    setMessages(prev => [...prev, userMessage]);
    setCurrentMessage('');
    setIsLoading(true);

    try {
      const response = await openwebuiApi.sendMessage(currentSession.id, currentMessage);
      setMessages(prev => [...prev.slice(0, -1), userMessage, response]);
    } catch (error) {
      console.error('Error sending message:', error);
      // Remover mensaje temporal en caso de error
      setMessages(prev => prev.slice(0, -1));
    } finally {
      setIsLoading(false);
    }
  };

  const handleKeyPress = (event: React.KeyboardEvent) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  };

  const renderMessage = (message: ChatMessage) => {
    const isUser = message.role === 'user';
    
    return (
      <ListItem
        key={message.id}
        className={`${classes.messageItem} ${isUser ? classes.userMessage : classes.assistantMessage}`}
      >
        <Box display="flex" alignItems="flex-start" gap={1}>
          <Avatar>
            {isUser ? <PersonIcon /> : <BotIcon />}
          </Avatar>
          <Paper
            className={`${classes.messageBubble} ${isUser ? classes.userBubble : classes.assistantBubble}`}
          >
            <Typography variant="body1">
              {message.content}
            </Typography>
            <Typography variant="caption" display="block" style={{ marginTop: 8, opacity: 0.7 }}>
              {message.timestamp.toLocaleTimeString()}
            </Typography>
          </Paper>
        </Box>
      </ListItem>
    );
  };

  return (
    <Box>
      {/* Selector de entidad */}
      <FormControl className={classes.entitySelector}>
        <InputLabel>Seleccionar Entidad</InputLabel>
        <Select
          value={selectedEntity?.name || ''}
          onChange={(e) => {
            const entity = availableEntities.find(ent => ent.name === e.target.value);
            if (entity) {
              startNewSession(entity);
            }
          }}
        >
          {availableEntities.map(entity => (
            <MenuItem key={`${entity.kind}-${entity.name}`} value={entity.name}>
              {entity.kind}: {entity.name}
            </MenuItem>
          ))}
        </Select>
      </FormControl>

      {/* Contexto actual */}
      {selectedEntity && (
        <Box mb={2}>
          <Typography variant="subtitle2" gutterBottom>
            Contexto actual:
          </Typography>
          <Chip
            label={`${selectedEntity.kind}: ${selectedEntity.name}`}
            className={classes.contextChip}
            color="primary"
            size="small"
          />
          {selectedEntity.metadata.tags?.map(tag => (
            <Chip
              key={tag}
              label={tag}
              className={classes.contextChip}
              size="small"
              variant="outlined"
            />
          ))}
        </Box>
      )}

      {/* Contenedor de chat */}
      <Paper className={classes.chatContainer}>
        {/* Mensajes */}
        <Box className={classes.messagesContainer}>
          {messages.length === 0 ? (
            <Box textAlign="center" py={4}>
              <Typography variant="body2" color="textSecondary">
                Selecciona una entidad para comenzar a chatear
              </Typography>
            </Box>
          ) : (
            <List>
              {messages.map(renderMessage)}
              {isLoading && (
                <ListItem className={classes.assistantMessage}>
                  <Box display="flex" alignItems="center" gap={1}>
                    <Avatar>
                      <BotIcon />
                    </Avatar>
                    <Box display="flex" alignItems="center" gap={1}>
                      <CircularProgress size={20} />
                      <Typography variant="body2" color="textSecondary">
                        Escribiendo...
                      </Typography>
                    </Box>
                  </Box>
                </ListItem>
              )}
              <div ref={messagesEndRef} />
            </List>
          )}
        </Box>

        {/* Input de mensaje */}
        <Box className={classes.inputContainer}>
          <Box className={classes.inputRow}>
            <TextField
              className={classes.messageInput}
              multiline
              maxRows={4}
              placeholder="Escribe tu mensaje..."
              value={currentMessage}
              onChange={(e) => setCurrentMessage(e.target.value)}
              onKeyPress={handleKeyPress}
              disabled={!currentSession || isLoading}
              variant="outlined"
              size="small"
            />
            <Button
              variant="contained"
              color="primary"
              onClick={sendMessage}
              disabled={!currentMessage.trim() || !currentSession || isLoading}
              startIcon={<SendIcon />}
            >
              Enviar
            </Button>
          </Box>
        </Box>
      </Paper>
    </Box>
  );
};
