#!/bin/bash

# Script para configurar webhook de GitHub para Jenkins
# Este script debe ejecutarse en el servidor donde está Jenkins

set -e

# Variables de configuración
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
GITHUB_REPO="${GITHUB_REPO:-cristianb96/kubernetes_project}"
GITHUB_TOKEN="${GITHUB_TOKEN:-your_github_token_here}"
WEBHOOK_URL="${JENKINS_URL}/github-webhook/"

echo "🔧 Configurando webhook de GitHub para Jenkins..."
echo "Jenkins URL: $JENKINS_URL"
echo "GitHub Repo: $GITHUB_REPO"
echo "Webhook URL: $WEBHOOK_URL"

# Verificar que curl esté disponible
if ! command -v curl &> /dev/null; then
    echo "❌ Error: curl no está instalado"
    exit 1
fi

# Verificar que jq esté disponible
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq no está instalado"
    exit 1
fi

# Crear webhook en GitHub
echo "📡 Creando webhook en GitHub..."

WEBHOOK_DATA=$(cat <<EOF
{
  "name": "web",
  "active": true,
  "events": [
    "push",
    "pull_request"
  ],
  "config": {
    "url": "$WEBHOOK_URL",
    "content_type": "json",
    "insecure_ssl": "0"
  }
}
EOF
)

# Crear el webhook
RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "$WEBHOOK_DATA" \
  "https://api.github.com/repos/$GITHUB_REPO/hooks")

# Verificar respuesta
if echo "$RESPONSE" | jq -e '.id' > /dev/null; then
    WEBHOOK_ID=$(echo "$RESPONSE" | jq -r '.id')
    echo "✅ Webhook creado exitosamente con ID: $WEBHOOK_ID"
else
    echo "❌ Error al crear webhook:"
    echo "$RESPONSE" | jq -r '.message // .'
    exit 1
fi

echo ""
echo "🎉 Configuración completada!"
echo ""
echo "📋 Pasos adicionales necesarios:"
echo "1. Asegúrate de que Jenkins tenga el plugin 'GitHub' instalado"
echo "2. Configura las credenciales de GitHub en Jenkins:"
echo "   - Ve a Jenkins > Manage Jenkins > Manage Credentials"
echo "   - Agrega credenciales de tipo 'Secret text' con tu GitHub token"
echo "3. En la configuración del job de Jenkins:"
echo "   - Habilita 'GitHub hook trigger for GITScm polling'"
echo "   - O usa 'Build when a change is pushed to GitHub'"
echo ""
echo "🔍 Para verificar que el webhook funciona:"
echo "   - Haz un push a tu repositorio"
echo "   - Verifica en Jenkins que se ejecute automáticamente"
echo "   - O ve a GitHub > Settings > Webhooks y verifica el estado"
