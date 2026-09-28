#!/bin/bash
set -e

echo "============================================================"
echo " SRE OBSERVABILITY PLATFORM - BOOTSTRAP"
echo "============================================================"
echo ""

# ============================================================
# CONFIGURACIÓN
# ============================================================

CLUSTER_NAME="sre-lab"
ARGOCD_NAMESPACE="argocd"
INGRESS_NAMESPACE="ingress-nginx"
PROMETHEUS_CHART_VERSION="55.0.0"

# Versiones fijadas a propósito.
# No usar ramas móviles (stable/main): si upstream avanza, un rebuild trae versiones
# distintas y el esquema del CRD de Application puede cambiar por debajo, lo que
# reintroduce errores de pruning como el de spec.syncOptions.
ARGOCD_VERSION="v3.5.3"
INGRESS_NGINX_VERSION="controller-v1.15.1"

# ============================================================
# DEPENDENCIAS
# ============================================================

echo "=== Comprobando dependencias ==="
echo ""

command -v k3d >/dev/null 2>&1 || {
    echo "ERROR: k3d no está instalado."
    exit 1
}

command -v kubectl >/dev/null 2>&1 || {
    echo "ERROR: kubectl no está instalado."
    exit 1
}

command -v helm >/dev/null 2>&1 || {
    echo "ERROR: Helm no está instalado."
    exit 1
}

echo "k3d:     OK"
echo "kubectl: OK"
echo "helm:    OK"

# ============================================================
# 1. BORRAR CLUSTER ANTERIOR
# ============================================================

echo ""
echo "=== 1. Limpiando cluster anterior ==="
echo ""

if k3d cluster list 2>/dev/null | grep -q "${CLUSTER_NAME}"; then
    echo "El cluster ${CLUSTER_NAME} ya existe."
    echo "Borrándolo..."

    k3d cluster delete "${CLUSTER_NAME}"

    echo "Cluster eliminado."
else
    echo "No hay cluster previo."
fi

# ============================================================
# 2. CREAR CLUSTER
# ============================================================

echo ""
echo "=== 2. Creando cluster ==="
echo ""

k3d cluster create \
    --config k3d-config.yaml

echo ""
echo "Cluster creado correctamente."

# ============================================================
# 3. COMPROBAR KUBERNETES
# ============================================================

echo ""
echo "=== 3. Comprobando Kubernetes ==="
echo ""

kubectl cluster-info

echo ""
kubectl get nodes

# ============================================================
# 4. CREAR NAMESPACES
# ============================================================

echo ""
echo "=== 4. Aplicando namespaces ==="
echo ""

kubectl apply \
    -f bootstrap/namespaces.yaml

# ============================================================
# 5. INSTALAR ARGOCD
# ============================================================

echo ""
echo "=== 5. Instalando ArgoCD ==="
echo ""

kubectl apply \
    --server-side \
    -n "${ARGOCD_NAMESPACE}" \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo ""
echo "ArgoCD instalado."

# ============================================================
# 6. ESPERAR CRD DE ARGOCD
# ============================================================

echo ""
echo "=== 6. Esperando CRDs de ArgoCD ==="
echo ""

kubectl wait \
    --for=condition=Established \
    crd/applications.argoproj.io \
    --timeout=300s

# ============================================================
# 7. ESPERAR ARGOCD SERVER
# ============================================================

echo ""
echo "=== 7. Esperando ArgoCD Server ==="
echo ""

kubectl wait \
    --for=condition=ready \
    pod \
    -l app.kubernetes.io/name=argocd-server \
    -n "${ARGOCD_NAMESPACE}" \
    --timeout=300s

echo ""
echo "ArgoCD está listo."

# ============================================================
# 8. INSTALAR CRDs DE PROMETHEUS OPERATOR
# ============================================================

echo ""
echo "=== 8. Instalando CRDs de kube-prometheus-stack ${PROMETHEUS_CHART_VERSION} ==="
echo ""

PROMETHEUS_CRDS_DIR="/tmp/kube-prometheus-stack-${PROMETHEUS_CHART_VERSION}"

rm -rf "${PROMETHEUS_CRDS_DIR}"
mkdir -p "${PROMETHEUS_CRDS_DIR}"

echo "Añadiendo repositorio prometheus-community..."

helm repo add prometheus-community \
    https://prometheus-community.github.io/helm-charts \
    2>/dev/null || true

helm repo update

echo ""
echo "Descargando kube-prometheus-stack ${PROMETHEUS_CHART_VERSION}..."

helm pull prometheus-community/kube-prometheus-stack \
    --version "${PROMETHEUS_CHART_VERSION}" \
    --untar \
    --untardir "${PROMETHEUS_CRDS_DIR}"

echo ""
echo "Aplicando CRDs con Server-Side Apply..."

# No se usa una ruta fija a proposito: segun la version del chart las CRDs pueden
# estar en <chart>/crds/ o en <chart>/charts/<subchart>/crds/ (en 55.x es
# charts/crds/crds/, porque "crds" es un subchart). Buscar por nombre sobrevive
# a esos cambios de layout.
CRD_FILES=$(find "${PROMETHEUS_CRDS_DIR}" -type f -name 'crd-*.yaml' | sort)

if [ -z "${CRD_FILES}" ]; then
    echo "ERROR: no se encontro ningun CRD bajo ${PROMETHEUS_CRDS_DIR}"
    echo "       Layout encontrado:"
    find "${PROMETHEUS_CRDS_DIR}" -maxdepth 4 -type d | sed 's/^/         /'
    exit 1
fi

echo "  CRDs encontradas: $(echo "${CRD_FILES}" | wc -l)"

# kubectl apply solo admite un valor por -f, asi que se repite la flag.
CRD_ARGS=()
while IFS= read -r CRD_FILE; do
    CRD_ARGS+=(-f "${CRD_FILE}")
done <<< "${CRD_FILES}"

kubectl apply \
    --server-side \
    --force-conflicts \
    "${CRD_ARGS[@]}"

echo ""
echo "CRDs de Prometheus Operator instalados correctamente."

# ============================================================
# 9. INSTALAR NGINX INGRESS
# ============================================================

echo ""
echo "=== 9. Instalando Nginx Ingress ==="
echo ""

kubectl apply \
    -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_NGINX_VERSION}/deploy/static/provider/cloud/deploy.yaml"

echo ""
echo "Nginx Ingress instalado."

# ============================================================
# 10. ESPERAR NGINX INGRESS
# ============================================================

echo ""
echo "=== 10. Esperando Nginx Ingress ==="
echo ""

kubectl wait \
    --namespace "${INGRESS_NAMESPACE}" \
    --for=condition=available \
    deployment/ingress-nginx-controller \
    --timeout=300s

echo ""
echo "Nginx Ingress está listo."

# ============================================================
# 11. APLICAR ROOT APP
# ============================================================

echo ""
echo "=== 11. Iniciando GitOps ==="
echo ""

echo "Aplicando Root Application..."

kubectl apply \
    -f bootstrap/root-app.yaml

echo ""
echo "Root App creada."

# ============================================================
# 12. ESPERAR ROOT APP
# ============================================================

echo ""
echo "=== 12. Esperando sincronización de Root App ==="
echo ""

for i in {1..60}; do

    STATUS=$(kubectl get application root-app \
        -n "${ARGOCD_NAMESPACE}" \
        -o jsonpath='{.status.sync.status}' \
        2>/dev/null || true)

    HEALTH=$(kubectl get application root-app \
        -n "${ARGOCD_NAMESPACE}" \
        -o jsonpath='{.status.health.status}' \
        2>/dev/null || true)

    echo "Intento ${i}/60 -> Sync: ${STATUS:-Unknown} | Health: ${HEALTH:-Unknown}"

    if [ "${STATUS}" = "Synced" ]; then
        break
    fi

    sleep 5
done

# ============================================================
# 13. ESPERAR APPLICATIONS HIJAS
# ============================================================

echo ""
echo "=== 13. Esperando Applications hijas ==="
echo ""

# root-app puede quedar Synced antes de que las hijas terminen. Sin esta espera el
# script miente: declara exito mientras Prometheus sigue OutOfSync o Degraded.
EXPECTED_APPS="prometheus grafana demo-app root-app"
MAX_WAIT=180
ELAPSED=0

while true; do

    PENDING=""

    for APP in ${EXPECTED_APPS}; do

        SYNC=$(kubectl get application "${APP}" \
            -n "${ARGOCD_NAMESPACE}" \
            -o jsonpath='{.status.sync.status}' \
            2>/dev/null || true)

        HEALTH=$(kubectl get application "${APP}" \
            -n "${ARGOCD_NAMESPACE}" \
            -o jsonpath='{.status.health.status}' \
            2>/dev/null || true)

        if [ "${SYNC}" != "Synced" ] || [ "${HEALTH}" != "Healthy" ]; then
            PENDING="${PENDING} ${APP}(${SYNC:-?} / ${HEALTH:-?})"
        fi

    done

    if [ -z "${PENDING}" ]; then
        echo "Todas las Applications están Synced y Healthy."
        break
    fi

    if [ "${ELAPSED}" -ge "${MAX_WAIT}" ]; then
        echo "AVISO: tras ${MAX_WAIT}s siguen sin converger:${PENDING}"
        echo "       Es normal que Prometheus tarde varios minutos en el primer despliegue."
        echo "       Revisa el progreso con: kubectl get applications -n ${ARGOCD_NAMESPACE}"
        break
    fi

    printf "  [%3ds] pendiente:%s\n" "${ELAPSED}" "${PENDING}"
    sleep 15
    ELAPSED=$((ELAPSED + 15))

done

echo ""
kubectl get applications \
    -n "${ARGOCD_NAMESPACE}"

# ============================================================
# 14. ESTADO FINAL
# ============================================================

echo ""
echo "============================================================"
echo " ESTADO DEL CLUSTER"
echo "============================================================"
echo ""

echo "=== NODOS ==="
kubectl get nodes

echo ""
echo "=== NAMESPACES ==="
kubectl get namespaces

echo ""
echo "=== ARGOCD PODS ==="
kubectl get pods -n "${ARGOCD_NAMESPACE}"

echo ""
echo "=== NGINX INGRESS PODS ==="
kubectl get pods -n "${INGRESS_NAMESPACE}"

echo ""
echo "=== ARGOCD APPLICATIONS ==="
kubectl get applications -n "${ARGOCD_NAMESPACE}"

echo ""
echo "=== OBSERVABILITY PODS ==="
kubectl get pods -n observability 2>/dev/null || true

echo ""
echo "=== APPLICATIONS PODS ==="
kubectl get pods -n applications 2>/dev/null || true

# ============================================================
# 15. CREDENCIALES ARGOCD
# ============================================================

echo ""
echo "============================================================"
echo " CREDENCIALES ARGOCD"
echo "============================================================"
echo ""

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d)

echo "Usuario:"
echo "admin"
echo ""

echo "Contraseña:"
echo "${ARGOCD_PASSWORD}"

# ============================================================
# 16. ACCESO A ARGOCD
# ============================================================

echo ""
echo "============================================================"
echo " ACCESO A ARGOCD"
echo "============================================================"
echo ""

echo "Ejecuta:"
echo ""
echo "kubectl port-forward svc/argocd-server -n argocd 9090:443"
echo ""
echo "Después abre:"
echo ""
echo "https://localhost:9090"
echo ""
echo "============================================================"
echo " BOOTSTRAP COMPLETADO"
echo "============================================================"