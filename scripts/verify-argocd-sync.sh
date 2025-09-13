#!/bin/bash

# Script para verificar la sincronización de ArgoCD
# Este script puede ejecutarse después de un deployment para verificar el estado

set -e

# Variables de configuración
ARGOCD_APP="${ARGOCD_APP:-pedido-app}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
NAMESPACE="${NAMESPACE:-my-tech}"
TIMEOUT="${TIMEOUT:-300}" # 5 minutos por defecto

echo "🔍 Verificando sincronización de ArgoCD..."
echo "Aplicación: $ARGOCD_APP"
echo "Namespace ArgoCD: $ARGOCD_NAMESPACE"
echo "Namespace destino: $NAMESPACE"
echo "Timeout: ${TIMEOUT}s"
echo ""

# Función para verificar si kubectl está disponible
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo "❌ Error: kubectl no está instalado o no está en el PATH"
        exit 1
    fi
}

# Función para verificar la aplicación de ArgoCD
check_argocd_app() {
    echo "📊 Verificando estado de la aplicación ArgoCD..."
    
    if ! kubectl get application "$ARGOCD_APP" -n "$ARGOCD_NAMESPACE" &> /dev/null; then
        echo "❌ Error: La aplicación '$ARGOCD_APP' no existe en el namespace '$ARGOCD_NAMESPACE'"
        exit 1
    fi
    
    # Obtener estado de la aplicación
    local status=$(kubectl get application "$ARGOCD_APP" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.status.sync.status}')
    local health=$(kubectl get application "$ARGOCD_APP" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.status.health.status}')
    
    echo "Estado de sincronización: $status"
    echo "Estado de salud: $health"
    
    if [[ "$status" == "Synced" && "$health" == "Healthy" ]]; then
        echo "✅ ArgoCD está sincronizado y saludable"
        return 0
    else
        echo "⚠️  ArgoCD no está completamente sincronizado"
        return 1
    fi
}

# Función para verificar el deployment
check_deployment() {
    echo ""
    echo "🚀 Verificando deployment en Kubernetes..."
    
    # Verificar que el deployment existe
    if ! kubectl get deployment backend -n "$NAMESPACE" &> /dev/null; then
        echo "❌ Error: El deployment 'backend' no existe en el namespace '$NAMESPACE'"
        return 1
    fi
    
    # Esperar a que el deployment esté listo
    echo "⏳ Esperando a que el deployment esté listo..."
    if kubectl rollout status deployment/backend -n "$NAMESPACE" --timeout="${TIMEOUT}s"; then
        echo "✅ Deployment está listo"
    else
        echo "❌ Timeout: El deployment no se completó en ${TIMEOUT}s"
        return 1
    fi
    
    # Mostrar información del deployment
    echo ""
    echo "📋 Información del deployment:"
    kubectl get deployment backend -n "$NAMESPACE" -o wide
    
    echo ""
    echo "📋 Pods del deployment:"
    kubectl get pods -l app.kubernetes.io/name=backend -n "$NAMESPACE" -o wide
    
    # Verificar que los pods estén corriendo
    local ready_pods=$(kubectl get pods -l app.kubernetes.io/name=backend -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers | wc -l)
    local total_pods=$(kubectl get pods -l app.kubernetes.io/name=backend -n "$NAMESPACE" --no-headers | wc -l)
    
    echo ""
    echo "📊 Pods listos: $ready_pods/$total_pods"
    
    if [[ "$ready_pods" -gt 0 && "$ready_pods" -eq "$total_pods" ]]; then
        echo "✅ Todos los pods están corriendo"
        return 0
    else
        echo "❌ No todos los pods están corriendo"
        return 1
    fi
}

# Función para verificar los endpoints
check_endpoints() {
    echo ""
    echo "🔗 Verificando endpoints de la aplicación..."
    
    # Obtener la URL del servicio
    local service_ip=$(kubectl get service backend -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
    local service_port=$(kubectl get service backend -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
    
    if [[ -z "$service_ip" || -z "$service_port" ]]; then
        echo "❌ No se pudo obtener la información del servicio"
        return 1
    fi
    
    echo "Servicio: $service_ip:$service_port"
    
    # Verificar endpoint de health
    echo "🏥 Verificando endpoint /api/health..."
    if kubectl run test-pod --image=curlimages/curl --rm -i --restart=Never -- \
        curl -s "http://$service_ip:$service_port/api/health" | grep -q "ok"; then
        echo "✅ Endpoint /api/health responde correctamente"
    else
        echo "❌ Endpoint /api/health no responde correctamente"
        return 1
    fi
    
    # Verificar endpoint de ping
    echo "🏓 Verificando endpoint /api/ping..."
    if kubectl run test-pod --image=curlimages/curl --rm -i --restart=Never -- \
        curl -s "http://$service_ip:$service_port/api/ping" | grep -q "pong"; then
        echo "✅ Endpoint /api/ping responde correctamente"
    else
        echo "❌ Endpoint /api/ping no responde correctamente"
        return 1
    fi
}

# Función principal
main() {
    echo "🚀 Iniciando verificación de ArgoCD y deployment..."
    echo "=================================================="
    
    check_kubectl
    
    local argocd_ok=false
    local deployment_ok=false
    local endpoints_ok=false
    
    # Verificar ArgoCD
    if check_argocd_app; then
        argocd_ok=true
    fi
    
    # Verificar deployment
    if check_deployment; then
        deployment_ok=true
    fi
    
    # Verificar endpoints
    if check_endpoints; then
        endpoints_ok=true
    fi
    
    echo ""
    echo "=================================================="
    echo "📊 Resumen de verificación:"
    echo "ArgoCD sincronizado: $([ "$argocd_ok" = true ] && echo "✅ Sí" || echo "❌ No")"
    echo "Deployment listo: $([ "$deployment_ok" = true ] && echo "✅ Sí" || echo "❌ No")"
    echo "Endpoints funcionando: $([ "$endpoints_ok" = true ] && echo "✅ Sí" || echo "❌ No")"
    
    if [[ "$argocd_ok" = true && "$deployment_ok" = true && "$endpoints_ok" = true ]]; then
        echo ""
        echo "🎉 ¡Verificación completada exitosamente!"
        echo "🚀 La aplicación está desplegada y funcionando correctamente"
        exit 0
    else
        echo ""
        echo "❌ La verificación falló en algunos aspectos"
        echo "🔍 Revisa los logs y el estado de los recursos"
        exit 1
    fi
}

# Ejecutar función principal
main "$@"
