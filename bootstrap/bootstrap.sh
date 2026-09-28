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

# ============================================================
# 1. BORRAR CLUSTER ANTERIOR
# ============================================================

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
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

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
# 8. INSTALAR NGINX INGRESS
# ============================================================

echo ""
echo "=== 8. Instalando Nginx Ingress ==="
echo ""

kubectl apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

echo ""
echo "Nginx Ingress instalado."

# ============================================================
# 9. ESPERAR NGINX INGRESS
# ============================================================

echo ""
echo "=== 9. Esperando Nginx Ingress ==="
echo ""

kubectl wait \
    --namespace "${INGRESS_NAMESPACE}" \
    --for=condition=available \
    deployment/ingress-nginx-controller \
    --timeout=300s

echo ""
echo "Nginx Ingress está listo."

# ============================================================
# 10. APLICAR ROOT APP
# ============================================================

echo ""
echo "=== 10. Iniciando GitOps ==="
echo ""

echo "Aplicando Root Application..."

kubectl apply \
    -f bootstrap/root-app.yaml

echo ""
echo "Root App creada."

# ============================================================
# 11. ESPERAR ROOT APP
# ============================================================

echo ""
echo "=== 11. Esperando sincronización de Root App ==="
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
# 12. ESPERAR APPLICATIONS HIJAS
# ============================================================

echo ""
echo "=== 12. Esperando Applications hijas ==="
echo ""

sleep 10

kubectl get applications \
    -n "${ARGOCD_NAMESPACE}"

# ============================================================
# 13. ESTADO FINAL
# ============================================================

echo ""
echo "============================================================"
echo " BOOTSTRAP COMPLETADO"
echo "============================================================"
echo ""

echo "=== NODOS ==="
kubectl get nodes

echo ""
echo "=== NAMESPACES ==="
kubectl get namespaces

echo ""
echo "=== ARGOCD PODS ==="
kubectl get pods \
    -n "${ARGOCD_NAMESPACE}"

echo ""
echo "=== NGINX INGRESS PODS ==="
kubectl get pods \
    -n "${INGRESS_NAMESPACE}"

echo ""
echo "=== ARGOCD APPLICATIONS ==="
kubectl get applications \
    -n "${ARGOCD_NAMESPACE}"

echo ""
echo "=== Instalando CRDs de Prometheus Operator ==="
echo ""

kubectl apply --server-side \
  -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml

kubectl apply --server-side \
  -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml

kubectl apply --server-side \
  -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml

kubectl apply --server-side \
  -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml

kubectl apply --server-side \
  -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusagents.yaml

kubectl apply --server-side \
  -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml

kubectl apply --server-side \
  -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml

kubectl apply --server-side \
  -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_scrapeconfigs.yaml

kubectl apply --server-side \
  -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml

kubectl apply --server-side \
  -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml
  
echo ""
echo "=== OBSERVABILITY PODS ==="
kubectl get pods \
    -n observability \
    2>/dev/null || true

echo ""
echo "=== APPLICATIONS PODS ==="
kubectl get pods \
    -n applications \
    2>/dev/null || true

# ============================================================
# 14. CONTRASEÑA ARGOCD
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