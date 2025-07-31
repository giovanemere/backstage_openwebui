#!/bin/bash

# Script de prueba para verificar que la verificación de requisitos funciona correctamente

set -e

echo "🧪 Probando sistema de verificación de requisitos..."

echo
echo "1. Probando verificación rápida de herramientas:"
make verify-tools

echo
echo "2. Probando verificación completa de requisitos:"
make verify-requirements

echo
echo "3. Probando script directo:"
./scripts/setup/verify-requirements.sh

echo
echo "✅ Todas las pruebas de verificación completadas exitosamente!"
echo "🎉 El sistema de verificación está funcionando correctamente."
