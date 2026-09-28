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

# GitHub devuelve 500 de forma intermitente al servir los assets de release, asi que
# se reintenta con backoff en lugar de morir y dejar el cluster a medias.
PULL_OK=false
for ATTEMPT in 1 2 3 4 5; do

    if helm pull prometheus-community/kube-prometheus-stack \
        --version "${PROMETHEUS_CHART_VERSION}" \
        --untar \
        --untardir "${PROMETHEUS_CRDS_DIR}"; then

        PULL_OK=true
        break

    fi

    echo "  Intento ${ATTEMPT}/5 fallido. Reintentando en $((ATTEMPT * 5))s..."
    rm -rf "${PROMETHEUS_CRDS_DIR:?}"/*
    sleep $((ATTEMPT * 5))

done

if [ "${PULL_OK}" != "true" ]; then
    echo "ERROR: no se pudo descargar el chart tras 5 intentos."
    exit 1
fi

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
# ============================================================
# 16. PUERTOS Y NAVEGADOR
# ============================================================

echo ""
echo "============================================================"
echo " ACCESO A LAS APLICACIONES"
echo "============================================================"
echo ""

# Los port-forward se lanzan en segundo plano con nohup para no bloquear esta
# terminal. Los PIDs quedan en un fichero para poder pararlos despues.
PORTFORWARD_PIDFILE="/tmp/sre-lab-portforwards.pid"
PORTFORWARD_LOGDIR="/tmp/sre-lab-portforwards"
PORT_MAP_FILE="/tmp/sre-lab-portforwards.map"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Si una ejecucion anterior dejo forwards vivos, se limpian.
if [ -f "${PORTFORWARD_PIDFILE}" ]; then
    while read -r OLD_PID; do
        [ -n "${OLD_PID}" ] && kill "${OLD_PID}" 2>/dev/null || true
    done < "${PORTFORWARD_PIDFILE}"
    rm -f "${PORTFORWARD_PIDFILE}"
fi

mkdir -p "${PORTFORWARD_LOGDIR}"
: > "${PORTFORWARD_PIDFILE}"
: > "${PORT_MAP_FILE}"

port_is_free() {
    ! ss -ltn 2>/dev/null | grep -q ":${1} "
}

# Busca el primer puerto libre a partir del preferido.
find_free_port() {
    local PORT="${1}"
    local ATTEMPT=0
    while [ "${ATTEMPT}" -lt 20 ]; do
        if port_is_free "${PORT}"; then
            echo "${PORT}"
            return 0
        fi
        PORT=$((PORT + 1))
        ATTEMPT=$((ATTEMPT + 1))
    done
    echo "${1}"
    return 1
}

# start_forward <nombre> <ns> <svc> <puerto-remoto> <puerto-preferido>
start_forward() {
    local NAME="${1}"
    local NS="${2}"
    local SVC="${3}"
    local REMOTE_PORT="${4}"
    local PREFERRED="${5}"

    if ! kubectl get svc "${SVC}" -n "${NS}" >/dev/null 2>&1; then
        printf "  %-12s omitido (no existe el service %s)\n" "${NAME}" "${SVC}"
        return 0
    fi

    local PORT
    PORT=$(find_free_port "${PREFERRED}")

    if [ "${PORT}" != "${PREFERRED}" ]; then
        printf "  %-12s puerto %s ocupado, usando %s\n" "${NAME}" "${PREFERRED}" "${PORT}"
    fi

    nohup kubectl port-forward "svc/${SVC}" -n "${NS}" "${PORT}:${REMOTE_PORT}" \
        > "${PORTFORWARD_LOGDIR}/${NAME}.log" 2>&1 &

    local PID=$!
    echo "${PID}" >> "${PORTFORWARD_PIDFILE}"
    echo "${NAME} ${PORT}" >> "${PORT_MAP_FILE}"

    sleep 1

    if kill -0 "${PID}" 2>/dev/null; then
        printf "  %-12s http://localhost:%s\n" "${NAME}" "${PORT}"
    else
        printf "  %-12s FALLO (ver %s)\n" "${NAME}" "${PORTFORWARD_LOGDIR}/${NAME}.log"
        sed -i "/^${PID}$/d" "${PORTFORWARD_PIDFILE}"
        sed -i "/^${NAME} /d" "${PORT_MAP_FILE}"
    fi
}

echo "Levantando port-forwards en segundo plano..."
echo ""

# 8080 y 8443 los usa k3d para el loadbalancer, por eso se esquivan.
start_forward "argocd"     "${ARGOCD_NAMESPACE}" "argocd-server"                          443  9090
start_forward "grafana"    "observability"      "grafana"                                  80  3000
start_forward "prometheus" "observability"      "prometheus-kube-prometheus-prometheus"  9090  9091
start_forward "alertmgr"   "observability"      "prometheus-kube-prometheus-alertmanager" 9093 9093
start_forward "demo-app"   "applications"       "demo-app"                                 80  8082

echo ""

ARGOCD_PORT=$(awk '$1=="argocd" {print $2}' "${PORT_MAP_FILE}" 2>/dev/null || true)

if [ -n "${ARGOCD_PORT}" ]; then
    echo "Abriendo ArgoCD en el navegador..."
    # WSL no trae xdg-open ni wslview; explorer.exe abre el navegador de Windows.
    if command -v explorer.exe >/dev/null 2>&1; then
        explorer.exe "https://localhost:${ARGOCD_PORT}" >/dev/null 2>&1 || true
    elif command -v wslview >/dev/null 2>&1; then
        wslview "https://localhost:${ARGOCD_PORT}" >/dev/null 2>&1 || true
    else
        echo "  (no se pudo abrir el navegador; abre la URL a mano)"
    fi
    echo ""
    echo "  ArgoCD usa certificado autofirmado: el navegador mostrara un aviso."
    echo "  Es esperado. Pulsa Advanced -> Proceed."
fi

echo "============================================================"
echo " BOOTSTRAP COMPLETADO"
echo "============================================================"
echo ""
echo "Esta terminal sigue libre: los port-forwards corren en segundo plano."
echo ""
echo "  Ver puertos sirviendo:   cat ${PORT_MAP_FILE}"
echo "  Parar los forwards:     bash ${SCRIPT_DIR}/stop-portforwards.sh"
echo ""
echo "Acceso por ingress (k3d ya mapea 8080 y 8443 del loadbalancer):"
echo ""
kubectl get ingress -A 2>/dev/null || echo "  (sin ingress)"
