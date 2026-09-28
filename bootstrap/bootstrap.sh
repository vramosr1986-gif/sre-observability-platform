#!/bin/bash
set -e

echo "=== Bootstrap de SRE Observability Platform ==="
echo ""

# ============================================================
# 1. BORRAR CLUSTER ANTERIOR
# ============================================================

echo "=== 1. Limpiando cluster anterior ==="

if k3d cluster list | grep -q "sre-lab"; then
    echo "El cluster ya existe. Borrándolo..."
    k3d cluster delete sre-lab
else
    echo "No hay cluster previo."
fi


# ============================================================
# 2. CREAR CLUSTER
# ============================================================

echo ""
echo "=== 2. Creando cluster ==="

k3d cluster create --config k3d-config.yaml


# ============================================================
# 3. NAMESPACES
# ============================================================

echo ""
echo "=== 3. Aplicando namespaces ==="

kubectl apply -f bootstrap/namespaces.yaml


# ============================================================
# 4. INSTALAR ARGOCD
# ============================================================

echo ""
echo "=== 4. Instalando ArgoCD ==="

kubectl apply \
  --server-side \
  -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


# ============================================================
# 5. ESPERAR A QUE ARGOCD ESTÉ LISTO
# ============================================================

echo ""
echo "=== 5. Esperando a que ArgoCD esté listo ==="

kubectl wait \
  --for=condition=Established \
  crd/applications.argoproj.io \
  --timeout=300s

kubectl wait \
  --for=condition=ready \
  pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd \
  --timeout=300s


# ============================================================
# 6. INSTALAR NGINX INGRESS
# ============================================================

echo ""
echo "=== 6. Instalando Nginx Ingress ==="

kubectl apply \
  -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml


# ============================================================
# 7. ESPERAR A QUE INGRESS ESTÉ LISTO
# ============================================================

echo ""
echo "=== 7. Esperando a Nginx Ingress ==="

kubectl wait \
  --namespace ingress-nginx \
  --for=condition=available \
  deployment/ingress-nginx-controller \
  --timeout=300s


# ============================================================
# 8. APLICAR APPLICATIONS DE ARGOCD
# ============================================================

echo ""
echo "=== 8. Aplicando Applications de ArgoCD ==="

kubectl apply -f bootstrap/argocd-apps.yaml


# ============================================================
# 9. ESPERAR A LAS APPLICATIONS
# ============================================================

echo ""
echo "=== 9. Esperando a que ArgoCD sincronice ==="

sleep 10

kubectl get applications -n argocd


# ============================================================
# 10. ESTADO FINAL
# ============================================================

echo ""
echo "=== Bootstrap completado ==="
echo ""

echo "=== Nodos ==="
kubectl get nodes

echo ""
echo "=== Namespaces ==="
kubectl get namespaces

echo ""
echo "=== Pods de ArgoCD ==="
kubectl get pods -n argocd

echo ""
echo "=== Pods de Nginx Ingress ==="
kubectl get pods -n ingress-nginx

echo ""
echo "=== Applications ==="
kubectl get applications -n argocd

echo ""
echo "=== Pods de Observability ==="
kubectl get pods -n observability


# ============================================================
# 11. CONTRASEÑA ARGOCD
# ============================================================

echo ""
echo "=== Contraseña de ArgoCD ==="

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

echo ""
echo ""

echo "=== Accede a ArgoCD con: ==="
echo ""
echo "kubectl port-forward svc/argocd-server -n argocd 9090:443"
echo ""
echo "URL: https://localhost:9090"
echo "Usuario: admin"