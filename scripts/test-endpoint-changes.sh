#!/bin/bash

# Script para probar el flujo completo de CI/CD
# Este script agrega un endpoint de prueba, hace commit y verifica el deployment

set -e

echo "🧪 Script de prueba para el flujo CI/CD"
echo "======================================"
echo ""

# Variables
BACKEND_FILE="backend/main.py"
COMMIT_MESSAGE="test: add example endpoint for CI/CD testing"
TEST_ENDPOINT="/api/example"

# Función para verificar que estamos en el directorio correcto
check_directory() {
    if [[ ! -f "backend/main.py" ]]; then
        echo "❌ Error: Este script debe ejecutarse desde la raíz del proyecto"
        echo "   Asegúrate de estar en el directorio que contiene la carpeta 'backend'"
        exit 1
    fi
}

# Función para hacer backup del archivo original
backup_file() {
    echo "📋 Creando backup del archivo original..."
    cp "$BACKEND_FILE" "${BACKEND_FILE}.backup"
    echo "✅ Backup creado: ${BACKEND_FILE}.backup"
}

# Función para agregar endpoint de prueba
add_test_endpoint() {
    echo "➕ Agregando endpoint de prueba..."
    
    # Verificar si el endpoint ya existe
    if grep -q "def example" "$BACKEND_FILE"; then
        echo "⚠️  El endpoint de prueba ya existe, actualizando..."
    fi
    
    # Crear contenido del endpoint
    local endpoint_content=$(cat <<'EOF'

@app.get("/api/example")
def example():
    """Endpoint de prueba para CI/CD"""
    return {
        "message": "¡Endpoint de prueba funcionando!",
        "timestamp": "2024-01-01T00:00:00Z",
        "version": "test-version",
        "status": "success"
    }
EOF
)
    
    # Agregar el endpoint al final del archivo (antes de la última línea si hay algo)
    echo "$endpoint_content" >> "$BACKEND_FILE"
    
    echo "✅ Endpoint agregado: $TEST_ENDPOINT"
}

# Función para hacer commit y push
commit_and_push() {
    echo "📤 Haciendo commit y push..."
    
    # Verificar estado de git
    if [[ -n $(git status --porcelain) ]]; then
        echo "📝 Archivos modificados detectados:"
        git status --short
        
        # Agregar archivos
        git add "$BACKEND_FILE"
        
        # Hacer commit
        git commit -m "$COMMIT_MESSAGE"
        
        # Hacer push
        echo "🚀 Enviando cambios al repositorio..."
        git push origin main
        
        echo "✅ Commit y push completados"
    else
        echo "ℹ️  No hay cambios para hacer commit"
    fi
}

# Función para monitorear el pipeline
monitor_pipeline() {
    echo ""
    echo "⏳ Monitoreando el pipeline de Jenkins..."
    echo "   - El webhook debería haber activado el pipeline automáticamente"
    echo "   - Revisa Jenkins para ver el progreso del build"
    echo "   - ArgoCD debería sincronizar automáticamente después del build"
    echo ""
    echo "🔍 Comandos útiles para monitorear:"
    echo "   kubectl get application pedido-app -n argocd"
    echo "   kubectl get pods -l app.kubernetes.io/name=backend -n my-tech"
    echo "   kubectl logs -l app.kubernetes.io/name=backend -n my-tech"
}

# Función para verificar el endpoint
verify_endpoint() {
    echo ""
    echo "🔍 Verificando el nuevo endpoint..."
    echo "   Esperando 2 minutos para que el deployment se complete..."
    
    # Esperar 2 minutos
    sleep 120
    
    # Obtener información del servicio
    local service_ip=$(kubectl get service backend -n my-tech -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
    local service_port=$(kubectl get service backend -n my-tech -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "")
    
    if [[ -n "$service_ip" && -n "$service_port" ]]; then
        echo "🌐 Probando endpoint: http://$service_ip:$service_port$TEST_ENDPOINT"
        
        # Probar el endpoint
        if kubectl run test-endpoint --image=curlimages/curl --rm -i --restart=Never -- \
            curl -s "http://$service_ip:$service_port$TEST_ENDPOINT" 2>/dev/null | grep -q "success"; then
            echo "✅ ¡Endpoint funcionando correctamente!"
        else
            echo "❌ El endpoint no responde correctamente"
            echo "   Verifica los logs del pod para más detalles"
        fi
    else
        echo "⚠️  No se pudo obtener la información del servicio"
        echo "   Verifica que el deployment esté funcionando"
    fi
}

# Función para limpiar (opcional)
cleanup() {
    echo ""
    echo "🧹 ¿Deseas restaurar el archivo original? (y/N)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if [[ -f "${BACKEND_FILE}.backup" ]]; then
            mv "${BACKEND_FILE}.backup" "$BACKEND_FILE"
            echo "✅ Archivo original restaurado"
            
            # Hacer commit de la limpieza
            git add "$BACKEND_FILE"
            git commit -m "test: remove example endpoint after testing"
            git push origin main
            echo "✅ Cambios de limpieza enviados al repositorio"
        else
            echo "⚠️  No se encontró el archivo de backup"
        fi
    else
        echo "ℹ️  Archivo de prueba mantenido"
    fi
}

# Función principal
main() {
    echo "🚀 Iniciando prueba del flujo CI/CD..."
    echo ""
    
    check_directory
    backup_file
    add_test_endpoint
    commit_and_push
    monitor_pipeline
    verify_endpoint
    cleanup
    
    echo ""
    echo "🎉 ¡Prueba completada!"
    echo "   - Se agregó un endpoint de prueba"
    echo "   - Se hizo commit y push automáticamente"
    echo "   - Jenkins debería haber ejecutado el pipeline"
    echo "   - ArgoCD debería haber sincronizado automáticamente"
    echo ""
    echo "📊 Para verificar el estado completo:"
    echo "   ./scripts/verify-argocd-sync.sh"
}

# Ejecutar función principal
main "$@"
