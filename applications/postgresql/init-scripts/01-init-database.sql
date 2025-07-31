-- =============================================================================
-- PostgreSQL Initialization Script - Backstage + OpenWebUI Demo
-- =============================================================================
-- Script para inicializar la base de datos compartida para demo en Minikube

-- =============================================================================
-- DATABASE CREATION
-- =============================================================================
-- La base de datos principal ya se crea con POSTGRES_DB
-- Crear base de datos adicional si es necesario
-- CREATE DATABASE backstage_openwebui_test;

-- =============================================================================
-- USER CREATION AND PERMISSIONS
-- =============================================================================
-- Crear usuario para OpenWebUI (si no existe)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'openwebui') THEN
        CREATE USER openwebui WITH PASSWORD 'demo-openwebui-password';
    END IF;
END
$$;

-- Otorgar permisos al usuario backstage (ya existe por POSTGRES_USER)
GRANT ALL PRIVILEGES ON DATABASE backstage_openwebui TO backstage;
GRANT ALL PRIVILEGES ON DATABASE backstage_openwebui TO openwebui;

-- =============================================================================
-- SCHEMA CREATION
-- =============================================================================
\c backstage_openwebui;

-- Crear esquemas separados para cada aplicación
CREATE SCHEMA IF NOT EXISTS backstage_schema;
CREATE SCHEMA IF NOT EXISTS openwebui_schema;
CREATE SCHEMA IF NOT EXISTS shared_schema;

-- Otorgar permisos en los esquemas
GRANT ALL ON SCHEMA backstage_schema TO backstage;
GRANT ALL ON SCHEMA openwebui_schema TO openwebui;
GRANT ALL ON SCHEMA shared_schema TO backstage, openwebui;

-- =============================================================================
-- EXTENSIONS (si son necesarias)
-- =============================================================================
-- Crear extensiones comunes que podrían necesitar las aplicaciones
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- INITIAL TABLES FOR DEMO
-- =============================================================================

-- Tabla para configuración compartida
CREATE TABLE IF NOT EXISTS shared_schema.demo_config (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) UNIQUE NOT NULL,
    value TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertar configuración inicial para demo
INSERT INTO shared_schema.demo_config (key, value, description) VALUES
    ('demo_mode', 'true', 'Indica que está en modo demo'),
    ('minikube_optimized', 'true', 'Configuración optimizada para Minikube'),
    ('backstage_integration', 'enabled', 'Integración con Backstage habilitada'),
    ('openwebui_integration', 'enabled', 'Integración con OpenWebUI habilitada'),
    ('shared_database', 'true', 'Base de datos compartida entre servicios')
ON CONFLICT (key) DO NOTHING;

-- Tabla para logs de integración (demo)
CREATE TABLE IF NOT EXISTS shared_schema.integration_logs (
    id SERIAL PRIMARY KEY,
    service VARCHAR(50) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    message TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- DEMO DATA
-- =============================================================================

-- Insertar datos de ejemplo para la demo
INSERT INTO shared_schema.integration_logs (service, event_type, message, metadata) VALUES
    ('backstage', 'startup', 'Backstage service initialized', '{"version": "1.20.0", "demo": true}'),
    ('openwebui', 'startup', 'OpenWebUI service initialized', '{"version": "0.1.124", "demo": true}'),
    ('postgresql', 'startup', 'Database initialized for demo', '{"version": "15.0", "shared": true}')
ON CONFLICT DO NOTHING;

-- =============================================================================
-- PERFORMANCE OPTIMIZATIONS FOR DEMO
-- =============================================================================

-- Crear índices básicos para mejorar performance en demo
CREATE INDEX IF NOT EXISTS idx_demo_config_key ON shared_schema.demo_config(key);
CREATE INDEX IF NOT EXISTS idx_integration_logs_service ON shared_schema.integration_logs(service);
CREATE INDEX IF NOT EXISTS idx_integration_logs_created_at ON shared_schema.integration_logs(created_at);

-- =============================================================================
-- DEMO COMPLETION MESSAGE
-- =============================================================================
DO $$
BEGIN
    RAISE NOTICE 'PostgreSQL database initialized successfully for Backstage + OpenWebUI demo';
    RAISE NOTICE 'Database: backstage_openwebui';
    RAISE NOTICE 'Schemas: backstage_schema, openwebui_schema, shared_schema';
    RAISE NOTICE 'Users: backstage, openwebui';
    RAISE NOTICE 'Demo mode: ENABLED';
END
$$;
